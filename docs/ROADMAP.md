# Roadmap

## MVP

- [x] Native macOS three-pane SwiftUI app.
- [x] Spawn and supervise `hermes acp` subprocess.
- [x] ACP `initialize` handshake.
- [x] `session/new` and chat streaming via `agent_message_chunk`.
- [x] `session/list` + `session/load` for the sidebar.
- [x] Tool-call visibility via `tool_call` and `tool_call_update`.
- [x] Approval prompts via `session/request_permission`.
- [x] Model switching via `session/set_model`.
- [ ] Cancel button wired through `session/cancel` (basic version present, needs UI polish).
- [ ] Reconnect path when `hermes acp` exits unexpectedly.

## Near Term

- [ ] Markdown rendering for agent messages and tool output.
- [ ] Slash command palette driven by `available_commands_update`.
- [ ] Session search filter in the sidebar.
- [ ] Workspace picker (currently uses the app's current directory).
- [ ] Stable status indicator with link to `hermes doctor` output on failures.
- [ ] Signed and notarised `.app` release.

## Later

- [ ] Image / file attachments (ACP supports image and resource content blocks).
- [ ] Multi-window sessions.
- [ ] Embed the `hermes dashboard` web UI as a fallback view.
- [ ] Quick-action menu bar item that wakes Hermes from anywhere.
