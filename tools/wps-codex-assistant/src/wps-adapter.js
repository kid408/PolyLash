import crypto from "node:crypto";

function pickFirst(values) {
  return values.find((value) => value != null && value !== "");
}

export function verifyWpsSignatureIfNeeded(config, rawBody, signatureHeader) {
  if (!config.wpsSharedSecret) {
    return true;
  }
  if (!signatureHeader) {
    throw new Error("缺少 WPS 签名头");
  }

  const expected = crypto
    .createHmac("sha256", config.wpsSharedSecret)
    .update(rawBody)
    .digest("hex");

  if (expected !== signatureHeader) {
    throw new Error("WPS 签名校验失败");
  }
  return true;
}

export function extractMessageFromWpsEvent(body) {
  const sessionId = pickFirst([
    body.sessionId,
    body.chatId,
    body.chat_id,
    body.conversationId,
    body.conversation_id,
    body?.event?.chatId,
    body?.event?.chat_id,
    body?.event?.conversationId,
    body?.event?.conversation_id,
  ]);

  const userId = pickFirst([
    body.userId,
    body.user_id,
    body.open_id,
    body.senderId,
    body.sender_id,
    body?.event?.userId,
    body?.event?.user_id,
    body?.event?.open_id,
    body?.event?.senderId,
    body?.event?.sender_id,
  ]);

  const text = pickFirst([
    body.text,
    body?.content?.text,
    body?.message?.text,
    body?.event?.text,
    body?.event?.content?.text,
    body?.event?.message?.text,
  ]);

  return {
    sessionId,
    userId,
    text,
  };
}

export async function deliverReply(config, payload) {
  if (config.wpsReplyMode === "none") {
    return { delivered: false, mode: "none" };
  }

  if (config.wpsReplyMode === "custom_webhook") {
    if (!config.wpsReplyWebhookUrl) {
      throw new Error("WPS_REPLY_MODE=custom_webhook 时必须配置 WPS_REPLY_WEBHOOK_URL");
    }

    const headers = {
      "Content-Type": "application/json",
    };
    if (config.wpsReplyBearerToken) {
      headers.Authorization = `Bearer ${config.wpsReplyBearerToken}`;
    }

    const response = await fetch(config.wpsReplyWebhookUrl, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`回传消息失败: ${response.status} ${text}`);
    }

    return { delivered: true, mode: "custom_webhook" };
  }

  throw new Error(`未知的 WPS_REPLY_MODE: ${config.wpsReplyMode}`);
}
