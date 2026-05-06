# Hermes Agent

Hermes Agent is a macOS-first AI agent desktop app for local, inspectable, user-approved agent work.

The project is planned as an open-source app with a native SwiftUI interface, a local Rust runtime, and a typed JSON-RPC protocol between them.

## Status

Hermes Agent is in initial design and scaffolding. The current focus is the product architecture, safety model, and first macOS app MVP.

## MVP

The first version will provide:

- Native macOS three-pane workbench.
- Chat-first Hermes agent session.
- Lightweight agent profiles.
- Local session history and run logs.
- Tool-call visibility.
- Approval before shell commands, file writes, and sensitive actions.
- API key storage in macOS Keychain.

## Planned Architecture

```text
Hermes.app (SwiftUI)
        |
        | JSON-RPC over local process stdio
        v
hermes-runtime (Rust)
        |
        +-- model provider adapters
        +-- local tools
        +-- approval policy checks
        +-- structured run logs
```

## Repository Layout

```text
apps/macos/                 macOS SwiftUI application
crates/hermes-runtime/      Rust local runtime
packages/hermes-protocol/   shared protocol schemas and generated types
docs/                       project documentation
```

## Design Principles

- Native Mac experience first.
- Local-first data and logs.
- Explicit trust boundaries.
- Tool calls must be visible and auditable.
- Sensitive actions require user approval.
- Multi-agent support starts as lightweight profiles, not a full orchestration platform.

## Development

The implementation has not been scaffolded yet. Build and test commands will be added with the first app/runtime commits.

## License

Hermes Agent should use a permissive open-source license. The recommended license is Apache-2.0 because it is common for infrastructure-oriented developer tools and includes an explicit patent grant.
