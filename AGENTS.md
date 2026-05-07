# Project Instructions

## Project Goal

Hermes Agent.app is a native macOS chat client that wraps the upstream [Hermes Agent](https://hermes-agent.nousresearch.com/) Python CLI. The app's job is to provide a great Mac UX over `hermes acp` — nothing more.

## Hard Boundary

If the work belongs to the agent itself — provider configuration, model adapters, tool execution, memory, skills, MCP, sessions persistence, the agent loop — it does **not** go in this repo. Either:

- Configure it through the existing `hermes` CLI (`hermes setup`, `hermes model`, `hermes skills`, `hermes config`, `hermes hooks`, `hermes auth`, etc.), or
- Propose it upstream at <https://github.com/NousResearch/hermes-agent>.

Things that *do* belong here:

- SwiftUI views, navigation, keyboard shortcuts, menus.
- ACP wire types and the bidirectional JSON-RPC transport.
- The `ACPClient` that turns ACP events into UI state.
- Subprocess lifecycle and recovery.

## Repository Layout

- `apps/macos/Sources/HermesAgent/` — the Swift app.
  - `ACP/` — wire types, JSON-RPC transport, ACP client.
  - `Views/` — three-pane workbench.
  - `AppState.swift` — observable state, owns the ACP client.
- `docs/` — architecture, roadmap, security, contributing notes.
- `scripts/` — build / bundling helpers.

## Technical Direction

- SwiftUI first; AppKit only when macOS integration requires it.
- Talk to Hermes via ACP (newline-delimited JSON-RPC 2.0 over stdio). Do not invent a parallel protocol.
- Keep the app stateless across launches. Persistence belongs to Hermes (`~/.hermes/`).

## Safety Rules

- Never auto-approve a `session/request_permission`. Show the prompt; let the user decide.
- Never read or store API keys, OAuth tokens, or other secrets. Hermes owns those.
- Do not silently swallow errors from the ACP transport. Surface them in the status footer or chat.

## Coding Rules

- Keep files focused. The transport, the client, and the schema are intentionally separate files.
- Verify protocol assumptions against the running `hermes acp` process when in doubt; the upstream Python source is in `/Users/jw/.hermes/hermes-agent/acp_adapter/` on dev machines that have Hermes installed.
- Avoid broad refactors unrelated to the current task.

## Build and Run

```bash
swift run --package-path apps/macos HermesAgent           # dev
./scripts/run-macos-app.sh                                # bundled .app
./scripts/check.sh                                        # checks (currently swift build only)
```

If a command does not yet pass, say so explicitly. Do not pretend.
