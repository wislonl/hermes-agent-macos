# Hermes Agent Architecture

## Overview

Hermes Agent is split into a native macOS app, a local runtime, and a shared protocol. The app owns the user experience and approval surfaces. The runtime owns model calls, tool execution, and structured run events. The protocol keeps the boundary explicit and testable.

## Components

### macOS App

The macOS app lives in `apps/macos/` and is built with SwiftUI, with AppKit bridges where native macOS integration requires them.

Responsibilities:

- Window, navigation, menus, and keyboard shortcuts.
- Three-pane workbench UI.
- Session and message presentation.
- Tool-call and approval UI.
- Local settings and Keychain access.
- Starting, stopping, and monitoring the local runtime process.

### Hermes Runtime

The runtime lives in `crates/hermes-runtime/` and is implemented in Rust.

Responsibilities:

- JSON-RPC server over stdio.
- Model provider adapters.
- Tool registry and tool execution.
- Approval policy enforcement before sensitive work.
- Structured event streaming back to the app.
- Runtime logs that can be inspected without exposing secrets.

The current MVP runtime falls back to `EchoProvider` when no provider is configured. The app exposes provider presets for common OpenAI-compatible services, stores non-secret provider settings in app preferences, and stores API keys in Keychain. When a run starts, the app passes only the selected provider's base URL, model, and secret environment to the runtime, which uses the shared OpenAI-compatible adapter. Provider errors and secrets must not leak into runtime events.

### Hermes Protocol

The shared protocol lives in `packages/hermes-protocol/`.

Responsibilities:

- Define request, response, event, error, and tool-call schemas.
- Keep app/runtime communication stable.
- Support generated Swift and Rust types when practical.
- Version breaking changes explicitly.

## Data Flow

1. The user sends a task from the macOS app.
2. The app sends a `run.create` request to the runtime.
3. The runtime emits events such as `message.delta`, `tool.requested`, `approval.required`, `tool.result`, and `run.completed`.
4. The app renders the stream in the center pane and tool details in the right pane.
5. If approval is required, the app asks the user and records the decision.
6. The target protocol flow will send `approval.resolve` so the runtime can continue, cancel, or fail the run based on the exact approval decision.

The current MVP implements shell approval preview and local decision recording. It does not execute shell commands or send approval decisions back to the runtime yet.

## Trust Boundaries

The app is the user-facing authority for approvals. The runtime must not execute sensitive actions until it has received an explicit approval decision for the exact action being performed.

Sensitive actions include:

- Shell command execution.
- File writes, deletes, and moves.
- Network requests with side effects.
- Credential access.
- Launching external apps or opening URLs that cause side effects.

## Storage

Local storage should include:

- Agent profiles.
- Sessions.
- Messages.
- Tool calls.
- Approval decisions.
- Redacted run logs.

Secrets must not be stored in the normal app database. API keys and provider credentials belong in macOS Keychain.

## Runtime Lifecycle

The app should launch the runtime as a child process and communicate through stdio. If the runtime exits unexpectedly, the app should show a recoverable error and preserve the current session state.

The current macOS workbench includes a deterministic in-app preview path for `/shell` prompts while process-runtime wiring continues to mature. The preview path creates approval requests and does not execute commands.

## Error Handling

Errors should be classified into:

- User-correctable errors, such as missing API keys or denied permissions.
- Runtime errors, such as provider failures or invalid tool arguments.
- Internal protocol errors, such as malformed messages.

The app should present concise user-facing messages while retaining redacted diagnostic logs for debugging.
