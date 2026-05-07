# Architecture

## Overview

Hermes Agent.app is a SwiftUI macOS shell over the [Hermes Agent](https://hermes-agent.nousresearch.com/) Python CLI. The app owns the window, the chat surface, and the approval prompts. Everything that makes Hermes an agent — provider adapters, the agent loop, tool execution, memory, skills, sessions — lives in the upstream `hermes` binary and is reached over ACP.

```
Hermes.app (SwiftUI)
    │
    │  Agent Client Protocol (newline-delimited JSON-RPC 2.0 over stdio)
    │
    ▼
hermes acp (child process, Nous Research Hermes Agent)
    ├── model providers (200+ models)
    ├── tools, skills, MCP servers
    ├── memory, sessions, FTS5 search
    └── permission system (request_permission ↔ app)
```

## Components

### macOS App

`apps/macos/` is a Swift Package with a single executable target.

Responsibilities:

- Window lifecycle, menus, keyboard shortcuts, three-pane workbench.
- Spawning and supervising `hermes acp` as a child process.
- Translating ACP wire messages into SwiftUI state.
- Presenting permission prompts as modal sheets.
- Letting the user pick a session and switch the active model.

Non-responsibilities (delegated entirely to Hermes):

- Provider, model, or API-key configuration. Use `hermes setup` / `hermes model`.
- Tool execution, sandboxing, or shell command running.
- Persistent storage of sessions, memory, or skills.

### Hermes Runtime

The agent is the upstream `hermes` Python binary, located via `$HERMES_EXECUTABLE` or by searching `PATH`. The app launches it as `hermes acp`. See the [ACP server source](https://github.com/NousResearch/hermes-agent/tree/main/acp_adapter) for the authoritative protocol surface Hermes implements.

### Agent Client Protocol

ACP is the open protocol used by Zed, VS Code, JetBrains, and other editors to drive agents. It is bidirectional newline-delimited JSON-RPC 2.0 over stdio.

The app uses the following methods:

| Direction | Method | Purpose |
|---|---|---|
| client → agent | `initialize` | Handshake, capability exchange |
| client → agent | `session/new` | Create a session in a workspace |
| client → agent | `session/load` | Reopen an existing session |
| client → agent | `session/list` | List sessions for the sidebar |
| client → agent | `session/prompt` | Send a user message |
| client → agent | `session/cancel` | Interrupt the running turn |
| client → agent | `session/set_model` | Switch the model |
| agent → client | `session/update` | Stream chunks: `agent_message_chunk`, `agent_thought_chunk`, `tool_call`, `tool_call_update`, `available_commands_update` |
| agent → client | `session/request_permission` | Synchronously ask the user before a sensitive action |

## Trust Boundaries

The app is the user-facing authority for any action that needs human approval. ACP routes those approvals through `session/request_permission`: Hermes pauses the run, the app shows a sheet with the proposed action and option list, and the chosen `optionId` is sent back as the response. Hermes only proceeds after that response.

API keys, OAuth tokens, and other secrets are stored by Hermes (`~/.hermes/auth.json` and `~/.hermes/.env`). The app never touches those files.

## Storage

The app is stateless across launches. All session history, memory, and skill state lives under `~/.hermes/` and is queried back through ACP each time the app starts.

## Error Handling

- `hermes` not found: app refuses to start and shows an actionable status message.
- Subprocess crash mid-run: pending requests fail with `processNotRunning`; the inspector shows the disconnected state.
- Decode failure on a session update: the event is dropped silently (logged in future versions); other updates continue.
- Permission request abandoned (sheet dismissed): the app responds with `outcome: "cancelled"`, which Hermes treats as a deny.
