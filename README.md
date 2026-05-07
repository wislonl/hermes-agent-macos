# Hermes Agent.app

A native macOS chat client for [Hermes Agent](https://hermes-agent.nousresearch.com/) by Nous Research.

The app is a thin SwiftUI shell. All agent work — model calls, tool execution, memory, skills, sessions — runs inside `hermes acp`, the official Agent Client Protocol server bundled with Hermes Agent. The app speaks ACP over stdio to that subprocess and renders its events into a native three-pane workbench.

## Status

Early MVP. The app:

- Launches `hermes acp` as a child process and completes the ACP `initialize` handshake.
- Creates new sessions and lists / loads prior sessions through ACP.
- Streams agent message chunks into a chat view as they arrive.
- Renders tool calls and their progress in the inspector pane.
- Surfaces ACP `session/request_permission` prompts as native sheets.
- Switches models through the ACP `session/set_model` flow.

The app does not implement provider configuration, memory, skills, or tool execution itself. Configure those through Hermes directly (`hermes setup`, `hermes model`, `hermes skills`, etc.).

## Requirements

- macOS 14 or later.
- A working `hermes` install on `PATH`. See <https://hermes-agent.nousresearch.com/docs/getting-started/quickstart>.

The app finds `hermes` by searching, in order: `$HERMES_EXECUTABLE`, `~/.local/bin/hermes`, `/usr/local/bin/hermes`, `/opt/homebrew/bin/hermes`, and finally `command -v hermes` in your login shell.

## Run from source

```bash
swift run --package-path apps/macos HermesAgent
```

## Build a bundled .app

```bash
./scripts/run-macos-app.sh
```

This produces `apps/macos/.build/HermesAgent.app` and opens it.

From Finder, double-click `Open Hermes Agent.command` to do the same.

## Repository layout

```text
apps/macos/                                macOS SwiftUI app
  Sources/HermesAgent/
    HermesAgentApp.swift                   App entry, menu commands
    AppState.swift                         Observable state, ACP client owner
    Models.swift                           UI value types
    Views/                                 Three-pane workbench
    ACP/
      ACPSchema.swift                      ACP wire types
      JsonRpcTransport.swift               Bidirectional newline-delimited JSON-RPC
      ACPClient.swift                      High-level ACP client
docs/                                      Project documentation
scripts/                                   Build and bundling scripts
```

## License

Apache License 2.0. See `LICENSE`.
