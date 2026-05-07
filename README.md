# Hermes Agent

Hermes Agent is a macOS-first AI agent desktop app for local, inspectable, user-approved agent work.

The project is planned as an open-source app with a native SwiftUI interface, a local Rust runtime, and a typed JSON-RPC protocol between them.

## Status

Hermes Agent is an early MVP. The repository now includes a SwiftUI macOS workbench, a Rust runtime, a typed JSON-RPC protocol schema, local session storage, Keychain-backed secret storage, shell approval previews, app-to-runtime JSON-RPC wiring, and Echo/OpenAI-compatible provider adapters.

## MVP

The first version will provide:

- Native macOS three-pane workbench.
- Chat-first Hermes agent session.
- Lightweight agent profiles.
- Local session history and run logs.
- Tool-call visibility.
- Approval before shell commands, file writes, and sensitive actions.
- API key storage in macOS Keychain.
- Provider presets for Echo, DeepSeek, OpenAI, OpenRouter, Together, Fireworks, Groq, Moonshot/Kimi, Qwen/Bailian, Zhipu/GLM, MiniMax, Volcengine Ark, Ollama, and custom OpenAI-compatible endpoints. API keys are stored in Keychain.

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

Run all available local checks:

```bash
./scripts/check.sh
```

Run the runtime tests:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
```

Run the macOS app tests:

```bash
swift test --package-path apps/macos
```

Run the macOS app locally:

```bash
swift run --package-path apps/macos HermesAgent
```

From Finder, double-click `Open Hermes Agent.command` in the repository root to build and launch the packaged app with the runtime bundled.

## License

Hermes Agent is licensed under the Apache License 2.0. See `LICENSE`.
