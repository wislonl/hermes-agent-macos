# Hermes Agent for macOS

A native macOS chat client for [Hermes Agent](https://hermes-agent.nousresearch.com/) by Nous Research.

Built with SwiftUI. All agent work — model calls, tool execution, memory, skills, sessions — runs inside `hermes acp`. This app speaks the Agent Client Protocol (ACP) over stdio to that subprocess and renders its events into a native three-pane workbench.

## Features

- **Stream chat** — agent responses render token by token as they arrive
- **Markdown rendering** — code blocks, bold, italic, inline code
- **Session management** — create, switch, rename, delete sessions; history persists across restarts
- **Tool call inspector** — see every tool call and its result in real time
- **Permission prompts** — ACP permission requests surface as native approval sheets
- **Model switching** — change models mid-session via the inspector picker
- **Collapsible inspector** — toggle the right panel to focus on the conversation

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 14 (Sonoma) or later |
| Xcode command-line tools | 15 or later |
| Hermes Agent | latest |

## Installation

### 1. Install Hermes Agent

Follow the [Hermes quickstart](https://hermes-agent.nousresearch.com/docs/getting-started/quickstart) to install `hermes` and complete initial setup (API key, model, etc.).

Verify it works:

```bash
hermes --version
```

### 2. Clone this repository

```bash
git clone https://github.com/YOUR_USERNAME/hermes-agent-macos.git
cd hermes-agent-macos
```

### 3. Build and run

```bash
./scripts/run-macos-app.sh
```

This compiles the app, creates `apps/macos/.build/HermesAgent.app`, and opens it automatically.

Alternatively you can run directly without creating a .app bundle:

```bash
swift run --package-path apps/macos HermesAgent
```

## How the app finds `hermes`

The app searches for the `hermes` executable in this order:

1. `$HERMES_EXECUTABLE` environment variable (set this for a custom path)
2. `~/.local/bin/hermes`
3. `/usr/local/bin/hermes`
4. `/opt/homebrew/bin/hermes`
5. `command -v hermes` via your login shell (zsh)

If the app shows "Hermes not found" on launch, set the environment variable before running:

```bash
HERMES_EXECUTABLE=/path/to/hermes ./scripts/run-macos-app.sh
```

## Usage tips

| Action | How |
|--------|-----|
| Send message | Press **Return** |
| New line in input | Press **Shift + Return** |
| New session | Click **⎋** icon in the sidebar, or **⌘N** |
| Switch session | Click any session in the sidebar |
| Rename session | Click **⋯** → Rename |
| Delete session | Click **⋯** → Delete (asks for confirmation) |
| Toggle inspector | Click the **sidebar.trailing** button in the toolbar |
| Change model | Use the picker at the top of the inspector panel |

## Troubleshooting

**"Hermes not found" on launch**  
`hermes` is not in any of the searched paths. Set `HERMES_EXECUTABLE` to its full path and relaunch.

**Messages not sending / input disabled**  
The connection status dot (bottom of the inspector) is red — hermes failed to start. Check that `hermes acp` runs without errors in your terminal.

**Session history missing after restart**  
History is read from `~/.hermes/sessions/`. Make sure hermes wrote the session file (it only saves sessions that have at least one message).

**App can't be opened (Gatekeeper warning)**  
The binary is unsigned. Right-click `HermesAgent.app` → Open, then click Open in the dialog. You only need to do this once.

## Repository layout

```
apps/macos/                     macOS SwiftUI app (Swift Package)
  Sources/HermesAgent/
    HermesAgentApp.swift        App entry point, menu commands
    AppState.swift              Observable state, ACP lifecycle
    Models.swift                UI value types, markdown helpers
    Views/
      WorkbenchView.swift       Three-pane window layout
      SidebarView.swift         Session list
      ConversationView.swift    Chat view with markdown rendering
      InspectorView.swift       Tool calls, model picker, status
    ACP/
      ACPSchema.swift           ACP wire types (JSON-RPC structs)
      JsonRpcTransport.swift    Newline-delimited JSON-RPC over stdio
      ACPClient.swift           High-level ACP client
scripts/
  run-macos-app.sh              Build + bundle + launch script
docs/                           Additional documentation
```

## Contributing

Pull requests are welcome. For larger changes, open an issue first to discuss what you'd like to change.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
