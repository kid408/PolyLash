# WPS Codex Personal Assistant

这是一个面向单人使用的最小代理服务，让你可以把 `WPS协作` 会话接到一个受限目录内的 `Codex/OpenAI` 助手上。

## 当前能力

- 单用户模式
- 白名单目录访问
- 只开放受控文件操作
- 写入类动作二次确认
- 本地调试接口
- 预留 WPS webhook 接入口

## 目录结构

```text
tools/wps-codex-assistant
├─ .env.example
├─ package.json
└─ src
   ├─ assistant.js
   ├─ config.js
   ├─ file-tools.js
   ├─ openai-client.js
   ├─ server.js
   ├─ session-store.js
   └─ wps-adapter.js
```

## 快速开始

1. 复制配置模板。

```powershell
Copy-Item .env.example .env
```

2. 修改 `.env` 里的至少这几项：

- `OPENAI_API_KEY`
- `WORKSPACE_ROOTS`
- `ALLOWED_USERS`，等你拿到自己的 WPS `user_id` 后再补

3. 启动服务。

```powershell
node src/server.js
```

4. 本地调试。

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8787/chat -ContentType 'application/json' -Body '{"sessionId":"local-demo","userId":"me","text":"列出可用目录"}'
```

## 本地接口

### `GET /health`

健康检查。

### `POST /chat`

用于本地联调，示例：

```json
{
  "sessionId": "local-demo",
  "userId": "me",
  "text": "读取 workspace 根目录下的 README.md"
}
```

### `POST /wps/callback`

WPS 侧 webhook 的占位接入口。当前版本会尝试从常见字段里提取：

- `sessionId/chatId/chat_id`
- `userId/user_id/open_id`
- `text/content.text/message.text`

如果你的 WPS 事件体字段和这里不同，只需要调整 `src/wps-adapter.js`。

## 已开放工具

- `list_roots`
- `list_files`
- `read_text_file`
- `search_text`
- `write_text_file`
- `append_text_file`
- `rename_file`
- `move_file`

其中后四个默认需要确认，确认口令：

- 执行：`确认`
- 取消：`取消`

## WPS 侧建议配置

根据 WPS 开放平台公开文档，推荐你走：

1. `企业自建应用`
2. 开启 `WPS协作机器人`
3. 配置 `事件订阅 URL`
4. 订阅 `接收消息`
5. 申请 `消息与会话` 相关权限

公开文档入口：

- [开放平台概述](https://open.wps.cn/documents/app-integration-dev/guide/start/overview.html)
- [开发应用](https://open.wps.cn/documents/app-integration-dev/guide/isv-app/develop-app.html)
- [开发者能力地图](https://open.wps.cn/documents/app-integration-dev/start/developer.html)

## 建议的第一版权限边界

- 只绑定一个 `ALLOWED_USERS`
- 只开放 1 到 3 个 `WORKSPACE_ROOTS`
- 不开放任意 shell
- 覆盖、追加、移动、重命名统一先确认

## 你还需要补的东西

这套服务已经把本地代理骨架搭好，但要真正打通 WPS，还需要你补充以下真实配置：

- WPS 应用的 webhook 地址
- WPS 实际消息事件体字段
- WPS 回消息方式

如果 WPS 最终要求你通过官方 `发送消息` API 回推消息，那么我们下一步只需要在 `src/wps-adapter.js` 里补一个正式的发送器即可。
