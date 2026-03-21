function extractTextFromResponse(responseJson) {
  if (typeof responseJson.output_text === "string" && responseJson.output_text.trim()) {
    return responseJson.output_text.trim();
  }

  const messageParts = [];
  for (const item of responseJson.output || []) {
    if (item.type !== "message") {
      continue;
    }
    for (const content of item.content || []) {
      if (content.type === "output_text" && content.text) {
        messageParts.push(content.text);
      }
    }
  }

  return messageParts.join("\n").trim();
}

export class OpenAIClient {
  constructor(config) {
    this.config = config;
  }

  async createResponse(body) {
    if (!this.config.openaiApiKey) {
      throw new Error("尚未配置 OPENAI_API_KEY");
    }

    const response = await fetch(`${this.config.openaiBaseUrl}/responses`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.config.openaiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`OpenAI API 调用失败: ${response.status} ${text}`);
    }

    return response.json();
  }

  async runConversation({ messages, tools }) {
    const response = await this.createResponse({
      model: this.config.openaiModel,
      input: messages,
      tools,
    });

    return {
      text: extractTextFromResponse(response),
      toolCalls: (response.output || []).filter((item) => item.type === "function_call"),
      responseId: response.id,
    };
  }

  async continueWithToolOutputs(responseId, toolOutputs) {
    const response = await this.createResponse({
      model: this.config.openaiModel,
      previous_response_id: responseId,
      input: toolOutputs,
    });

    return {
      text: extractTextFromResponse(response),
      toolCalls: (response.output || []).filter((item) => item.type === "function_call"),
      responseId: response.id,
    };
  }
}
