# Hermes Agent Design

## Summary

Hermes Agent is a macOS-first, open-source AI agent desktop app. The first version should deliver a useful native desktop assistant with visible tool calls, local session history, and explicit approval for sensitive actions.

## Product Direction

Hermes Agent should be both a real app and a credible open-source project. The app is the primary product surface. GitHub is the trust, distribution, and contributor surface.

The first version should not attempt to become a full multi-agent orchestration platform. Multi-agent functionality starts as lightweight agent profiles and session management.

## User Experience

The recommended UI is a three-pane workbench:

- Left pane: sessions and agent profiles.
- Center pane: chat, task stream, and assistant responses.
- Right pane: tool calls, approvals, run timeline, and diagnostics.

This layout keeps the assistant interaction central while making local actions inspectable.

## Architecture

Hermes Agent is split into three major units:

- `apps/macos/` - SwiftUI macOS app with AppKit bridges when needed.
- `crates/hermes-runtime/` - Rust runtime for model calls, tool execution, approval checks, and logs.
- `packages/hermes-protocol/` - JSON-RPC schemas and shared generated types.

The app launches the runtime as a child process and communicates over JSON-RPC through stdio. The runtime streams run events back to the app.

## Data Flow

1. User submits a task in the macOS app.
2. The app sends `run.create` to the runtime.
3. The runtime calls the configured model provider.
4. The runtime emits message and tool events.
5. Sensitive tool calls emit `approval.required`.
6. The app asks the user for a decision.
7. The runtime continues, cancels, or fails the run.
8. The app stores the session, messages, approvals, and redacted logs locally.

## Security Model

Model output is untrusted. The runtime must not execute sensitive actions without explicit approval from the app.

Sensitive actions include shell commands, file writes, deletes, network mutations, credential access, and external app launches.

API keys and provider credentials must be stored in macOS Keychain. Logs must be redacted.

## MVP Scope

The MVP includes:

- Native macOS app shell.
- Three-pane workbench.
- Default Hermes agent profile.
- Lightweight additional agent profiles.
- Local session history.
- Runtime process startup and lifecycle handling.
- JSON-RPC protocol over stdio.
- OpenAI-compatible provider adapter.
- Tool-call stream.
- Approval UI for shell commands and file writes.
- Keychain-backed provider credentials.

## Out of Scope for MVP

- Full autonomous multi-agent delegation.
- Marketplace or plugin registry.
- Team policy management.
- Remote runtime.
- Windows/Linux apps.
- Complex workflow builder.

## Testing Strategy

Testing should focus first on boundaries that affect trust and correctness:

- Protocol schema parsing and version handling.
- Runtime approval policy decisions.
- Tool execution behavior.
- Secret redaction.
- App/runtime lifecycle failures.
- UI behavior for approval prompts and cancelled runs.

## Documentation Strategy

The project should begin with:

- `AGENTS.md` for coding-agent rules.
- `README.md` for product positioning and setup.
- `docs/ARCHITECTURE.md` for component boundaries.
- `docs/SECURITY.md` for trust and approval policy.
- `docs/PROTOCOL.md` for app/runtime communication.
- `docs/ROADMAP.md` for scope control.
- `docs/CONTRIBUTING.md` for contributor expectations.

## Initial Implementation Phases

1. Create repository docs and design spec.
2. Scaffold SwiftUI app and static three-pane UI.
3. Scaffold Rust runtime with handshake and mock run events.
4. Wire app/runtime JSON-RPC communication.
5. Add local session storage.
6. Add provider adapter and streaming replies.
7. Add shell/file tool visibility and approval flow.
8. Add packaging and release documentation.

