import http from "node:http";

import { AssistantService } from "./assistant.js";
import { config, validateConfig } from "./config.js";
import { FileTools } from "./file-tools.js";
import { OpenAIClient } from "./openai-client.js";
import { SessionStore } from "./session-store.js";
import {
  deliverReply,
  extractMessageFromWpsEvent,
  verifyWpsSignatureIfNeeded,
} from "./wps-adapter.js";

function log(level, message, extra = undefined) {
  const line = `[${new Date().toISOString()}] [${level}] ${message}`;
  if (extra === undefined) {
    console.log(line);
    return;
  }
  console.log(line, extra);
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(data, null, 2));
}

function sendText(res, statusCode, text) {
  res.writeHead(statusCode, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(text);
}

const configProblems = validateConfig();
if (configProblems.length > 0) {
  for (const problem of configProblems) {
    log("warn", problem);
  }
}

const store = new SessionStore(config.sessionStorePath, config.maxHistoryTurns);
const fileTools = new FileTools(config);
const openaiClient = new OpenAIClient(config);
const assistant = new AssistantService({
  config,
  store,
  fileTools,
  openaiClient,
});

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "GET" && req.url === "/health") {
      return sendJson(res, 200, {
        ok: true,
        service: "wps-codex-assistant",
        roots: config.workspaceRoots,
        openaiConfigured: Boolean(config.openaiApiKey),
      });
    }

    if (req.method === "POST" && req.url === "/chat") {
      const rawBody = await readRawBody(req);
      const body = rawBody ? JSON.parse(rawBody) : {};
      const result = await assistant.handleMessage({
        sessionId: body.sessionId || "local-default",
        userId: body.userId || "local-user",
        text: body.text || "",
      });
      return sendJson(res, 200, {
        ok: true,
        ...result,
      });
    }

    if (req.method === "POST" && req.url === "/wps/callback") {
      const rawBody = await readRawBody(req);
      verifyWpsSignatureIfNeeded(
        config,
        rawBody,
        req.headers["x-wps-signature"] || req.headers["x-signature"],
      );

      const body = rawBody ? JSON.parse(rawBody) : {};

      if (body.challenge) {
        return sendJson(res, 200, {
          challenge: body.challenge,
        });
      }

      if (config.wpsVerifyToken && body.token && body.token !== config.wpsVerifyToken) {
        return sendJson(res, 403, {
          ok: false,
          error: "WPS verify token 不匹配",
        });
      }

      const message = extractMessageFromWpsEvent(body);
      if (!message.sessionId || !message.userId || !message.text) {
        return sendJson(res, 400, {
          ok: false,
          error: "无法从 WPS 事件中提取 sessionId / userId / text，请调整 wps-adapter.js",
          extracted: message,
        });
      }

      const result = await assistant.handleMessage(message);
      await deliverReply(config, {
        sessionId: message.sessionId,
        userId: message.userId,
        replyText: result.replyText,
        pendingAction: result.pendingAction,
        rawEvent: body,
      });

      return sendJson(res, 200, {
        ok: true,
        ...result,
      });
    }

    return sendText(res, 404, "Not Found");
  } catch (error) {
    log("error", error.message);
    return sendJson(res, 500, {
      ok: false,
      error: error.message,
    });
  }
});

server.listen(config.port, () => {
  log("info", `服务已启动: http://127.0.0.1:${config.port}`);
  log("info", "白名单目录", config.workspaceRoots);
});
