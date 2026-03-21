import fs from "node:fs";
import path from "node:path";

const TRUE_VALUES = new Set(["1", "true", "yes", "on"]);

function loadDotEnv() {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) {
    return;
  }

  const content = fs.readFileSync(envPath, "utf8");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }
    const equalIndex = line.indexOf("=");
    if (equalIndex === -1) {
      continue;
    }
    const key = line.slice(0, equalIndex).trim();
    let value = line.slice(equalIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

function parseBoolean(value, fallback = false) {
  if (value == null || value === "") {
    return fallback;
  }
  return TRUE_VALUES.has(String(value).trim().toLowerCase());
}

function parseList(value) {
  if (!value) {
    return [];
  }
  return value
    .split(/[;,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeRoot(alias, absolutePath) {
  return {
    alias,
    absolutePath: path.resolve(absolutePath),
  };
}

function parseWorkspaceRoots(value) {
  const entries = parseList(value);
  if (entries.length === 0) {
    return [normalizeRoot("workspace", process.cwd())];
  }

  return entries.map((entry, index) => {
    const equalIndex = entry.indexOf("=");
    if (equalIndex === -1) {
      return normalizeRoot(`root${index + 1}`, entry);
    }
    const alias = entry.slice(0, equalIndex).trim() || `root${index + 1}`;
    const absolutePath = entry.slice(equalIndex + 1).trim();
    return normalizeRoot(alias, absolutePath);
  });
}

loadDotEnv();

export const config = {
  port: parseInteger(process.env.PORT, 8787),
  botName: process.env.BOT_NAME || "个人Codex助手",
  logLevel: process.env.LOG_LEVEL || "info",
  openaiApiKey: process.env.OPENAI_API_KEY || "",
  openaiBaseUrl: process.env.OPENAI_BASE_URL || "https://api.openai.com/v1",
  openaiModel: process.env.OPENAI_MODEL || "gpt-5.3-codex",
  allowedUsers: new Set(parseList(process.env.ALLOWED_USERS)),
  workspaceRoots: parseWorkspaceRoots(process.env.WORKSPACE_ROOTS),
  requireConfirmationForWrite: parseBoolean(
    process.env.REQUIRE_CONFIRMATION_FOR_WRITE,
    true,
  ),
  maxHistoryTurns: parseInteger(process.env.MAX_HISTORY_TURNS, 12),
  maxDirectoryItems: parseInteger(process.env.MAX_DIRECTORY_ITEMS, 200),
  maxSearchResults: parseInteger(process.env.MAX_SEARCH_RESULTS, 20),
  maxReadChars: parseInteger(process.env.MAX_READ_CHARS, 20000),
  wpsVerifyToken: process.env.WPS_VERIFY_TOKEN || "",
  wpsSharedSecret: process.env.WPS_SHARED_SECRET || "",
  wpsReplyMode: process.env.WPS_REPLY_MODE || "none",
  wpsReplyWebhookUrl: process.env.WPS_REPLY_WEBHOOK_URL || "",
  wpsReplyBearerToken: process.env.WPS_REPLY_BEARER_TOKEN || "",
  sessionStorePath: path.resolve(process.cwd(), "data", "sessions.json"),
  confirmationKeywords: new Set(["确认", "确认执行", "继续", "继续执行", "yes"]),
  cancelKeywords: new Set(["取消", "停止", "不用了", "no"]),
};

export function validateConfig() {
  const problems = [];

  if (config.workspaceRoots.length === 0) {
    problems.push("至少需要配置一个 WORKSPACE_ROOTS 白名单目录");
  }

  for (const root of config.workspaceRoots) {
    if (!root.alias) {
      problems.push("存在缺少 alias 的白名单目录");
    }
    if (!path.isAbsolute(root.absolutePath)) {
      problems.push(`白名单目录不是绝对路径: ${root.absolutePath}`);
    }
  }

  return problems;
}
