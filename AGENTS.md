# Hermes Agent Project Instructions

## Project Goal

Hermes Agent is a macOS-first, open-source AI agent desktop app. It should feel like a native Mac workbench while keeping local tool execution transparent, auditable, and user-approved.

## Product Scope

Build a native macOS app with:

- A three-pane workbench: sessions and agent profiles on the left, chat/task stream in the center, tool calls and approvals on the right.
- A default Hermes agent plus lightweight agent profiles for research and coding workflows.
- Local-first session history and run logs.
- Explicit approval before commands, file writes, or other sensitive actions.
- API keys stored in macOS Keychain.

Do not turn the first version into a large cross-platform orchestration platform. Keep multi-agent support lightweight until the core assistant workflow is solid.

## Repository Layout

Current structure:

- `apps/macos/` - SwiftUI macOS app.
- `crates/hermes-runtime/` - Rust local runtime for tool execution, provider calls, logs, and process boundaries.
- `packages/hermes-protocol/` - Shared JSON-RPC protocol schemas and generated types.
- `docs/` - Architecture, security, roadmap, protocol, and contributor documentation.

## Technical Direction

- Prefer SwiftUI for UI and AppKit only where macOS integration requires it.
- Prefer Rust for the local runtime where process control, safety boundaries, and structured logging matter.
- Communicate between the app and runtime through JSON-RPC over local process stdio.
- Keep provider integration behind an adapter so OpenAI-compatible providers can be added without changing UI code.
- Keep tool definitions explicit, typed, and auditable.

## Safety Rules

- Never bypass the approval flow for command execution, file writes, network actions with side effects, or credential access.
- Never log API keys, tokens, environment secrets, or full credential-bearing request headers.
- Store secrets only in Keychain or local ignored configuration files during development.
- Default new tools to read-only until their write behavior and approval model are documented.
- Treat shell execution as high risk. Commands must be displayed to the user before execution.

## Coding Rules

- Keep files focused and boundaries clear.
- Prefer protocol/schema changes before wiring UI behavior that depends on them.
- Add tests around protocol parsing, approval decisions, and runtime tool behavior.
- Use existing project patterns once they exist. Do not introduce a new framework or state-management layer without a concrete need.
- Avoid broad refactors unrelated to the current task.

## Build and Test Commands

Run all available checks:

```bash
./scripts/check.sh
```

Run component checks directly:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
swift test --package-path apps/macos
```

Run the macOS app locally:

```bash
swift run --package-path apps/macos HermesAgent
```

If a command is not yet available, say that clearly instead of inventing passing results.
