function safeJsonParse(value, fallback = {}) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function toInputMessage(role, text) {
  return {
    role,
    content: [
      {
        type: "input_text",
        text,
      },
    ],
  };
}

function buildSystemPrompt(config) {
  const roots = config.workspaceRoots
    .map((root) => `${root.alias}: ${root.absolutePath}`)
    .join("\n");

  return [
    `你是${config.botName}，服务对象只有一个用户。`,
    "你的工作目标是帮助用户在白名单目录内完成常规文件任务。",
    "你必须遵守这些规则：",
    "1. 只能操作白名单目录，严禁假设任何目录可访问。",
    "2. 涉及写入、追加、移动、重命名时，直接调用对应工具，系统会决定是否需要确认。",
    "3. 如果没有足够信息完成任务，先用一句简短中文追问。",
    "4. 不要编造文件内容、路径或执行结果。",
    "5. 输出简洁、明确，优先告诉用户你做了什么或还缺什么。",
    "当前白名单目录：",
    roots,
  ].join("\n");
}

function buildTools() {
  return [
    {
      type: "function",
      name: "list_roots",
      description: "列出所有允许访问的白名单目录。",
      parameters: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "list_files",
      description: "列出某个白名单目录内指定相对路径下的文件和子目录。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
        },
        required: ["root_alias"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "read_text_file",
      description: "读取文本文件内容。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
        },
        required: ["root_alias", "relative_path"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "search_text",
      description: "在白名单目录内搜索文本。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
          query: { type: "string" },
        },
        required: ["root_alias", "query"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "write_text_file",
      description: "覆盖写入文本文件。通常用于生成新文档或重写现有文档。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
          content: { type: "string" },
        },
        required: ["root_alias", "relative_path", "content"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "append_text_file",
      description: "追加写入文本文件。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
          content: { type: "string" },
        },
        required: ["root_alias", "relative_path", "content"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "rename_file",
      description: "重命名文件或目录，但不改变父目录。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          relative_path: { type: "string" },
          new_name: { type: "string" },
        },
        required: ["root_alias", "relative_path", "new_name"],
        additionalProperties: false,
      },
    },
    {
      type: "function",
      name: "move_file",
      description: "在同一个白名单目录内移动文件或目录。",
      parameters: {
        type: "object",
        properties: {
          root_alias: { type: "string" },
          source_relative_path: { type: "string" },
          destination_relative_path: { type: "string" },
        },
        required: ["root_alias", "source_relative_path", "destination_relative_path"],
        additionalProperties: false,
      },
    },
  ];
}

function isWriteAction(name) {
  return new Set([
    "write_text_file",
    "append_text_file",
    "rename_file",
    "move_file",
  ]).has(name);
}

function formatExecutionResult(result) {
  switch (result.action) {
    case "write_text_file":
      return `已写入 ${result.rootAlias}:${result.relativePath}，写入长度 ${result.length} 字符。`;
    case "append_text_file":
      return `已追加到 ${result.rootAlias}:${result.relativePath}，追加长度 ${result.length} 字符。`;
    case "rename_file":
      return `已重命名 ${result.rootAlias}:${result.from} -> ${result.to}。`;
    case "move_file":
      return `已移动 ${result.rootAlias}:${result.from} -> ${result.to}。`;
    default:
      return "操作已完成。";
  }
}

export class AssistantService {
  constructor({ config, store, fileTools, openaiClient }) {
    this.config = config;
    this.store = store;
    this.fileTools = fileTools;
    this.openaiClient = openaiClient;
  }

  ensureUserAllowed(userId) {
    if (this.config.allowedUsers.size === 0) {
      return;
    }
    if (!this.config.allowedUsers.has(userId)) {
      throw new Error(`当前用户未在 ALLOWED_USERS 白名单内: ${userId}`);
    }
  }

  isConfirmText(text) {
    return this.config.confirmationKeywords.has(text.trim().toLowerCase());
  }

  isCancelText(text) {
    return this.config.cancelKeywords.has(text.trim().toLowerCase());
  }

  async handleMessage({ sessionId, userId, text }) {
    this.ensureUserAllowed(userId);

    const pendingAction = this.store.getPendingAction(sessionId);
    if (pendingAction && this.isConfirmText(text)) {
      const result = this.fileTools.executePendingAction(pendingAction);
      const replyText = formatExecutionResult(result);
      this.store.clearPendingAction(sessionId);
      this.store.appendTurn(sessionId, "user", text);
      this.store.appendTurn(sessionId, "assistant", replyText);
      return { replyText, pendingAction: null };
    }

    if (pendingAction && this.isCancelText(text)) {
      const replyText = `已取消操作：${this.fileTools.previewPendingAction(pendingAction)}`;
      this.store.clearPendingAction(sessionId);
      this.store.appendTurn(sessionId, "user", text);
      this.store.appendTurn(sessionId, "assistant", replyText);
      return { replyText, pendingAction: null };
    }

    const history = this.store.get(sessionId, userId).history;
    const messages = [
      toInputMessage("system", buildSystemPrompt(this.config)),
      ...history.map((entry) => toInputMessage(entry.role, entry.text)),
      toInputMessage("user", text),
    ];

    let response = await this.openaiClient.runConversation({
      messages,
      tools: buildTools(),
    });

    while (response.toolCalls && response.toolCalls.length > 0) {
      const toolOutputs = [];

      for (const toolCall of response.toolCalls) {
        const args = safeJsonParse(toolCall.arguments, {});

        if (this.config.requireConfirmationForWrite && isWriteAction(toolCall.name)) {
          const pending = this.fileTools.buildPendingAction(toolCall.name, args);
          const replyText = `${this.fileTools.previewPendingAction(
            pending,
          )}。\n回复“确认”执行，回复“取消”放弃。`;
          this.store.setPendingAction(sessionId, pending);
          this.store.appendTurn(sessionId, "user", text);
          this.store.appendTurn(sessionId, "assistant", replyText);
          return { replyText, pendingAction: pending };
        }

        let output;
        switch (toolCall.name) {
          case "list_roots":
            output = this.fileTools.listRoots();
            break;
          case "list_files":
            output = this.fileTools.listFiles(args);
            break;
          case "read_text_file":
            output = this.fileTools.readTextFile(args);
            break;
          case "search_text":
            output = this.fileTools.searchText(args);
            break;
          case "write_text_file":
            output = this.fileTools.writeTextFile(args);
            break;
          case "append_text_file":
            output = this.fileTools.appendTextFile(args);
            break;
          case "rename_file":
            output = this.fileTools.renameFile(args);
            break;
          case "move_file":
            output = this.fileTools.moveFile(args);
            break;
          default:
            throw new Error(`未知工具调用: ${toolCall.name}`);
        }

        toolOutputs.push({
          type: "function_call_output",
          call_id: toolCall.call_id,
          output: JSON.stringify(output),
        });
      }

      response = await this.openaiClient.continueWithToolOutputs(
        response.responseId,
        toolOutputs,
      );

      if (!response.toolCalls.length && !response.text) {
        response.text = "操作已完成。";
      }
    }

    const replyText = response.text || "我已经处理好了。";
    this.store.appendTurn(sessionId, "user", text);
    this.store.appendTurn(sessionId, "assistant", replyText);
    return { replyText, pendingAction: null };
  }
}
