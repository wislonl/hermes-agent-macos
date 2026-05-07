# Hermes Protocol

## Overview

Hermes Protocol defines communication between the macOS app and the local runtime. The first transport uses stdio with JSON-RPC 2.0 envelopes for requests and responses, plus Hermes event objects for runtime events.

## Transport

The first runtime transport uses newline-delimited JSON over stdio. App-to-runtime requests and runtime-to-app responses are JSON-RPC 2.0 envelopes with `jsonrpc`, `id`, `method`, and `params` for requests, and `jsonrpc`, `id`, plus `result` or `error` for responses.

Runtime events are newline-delimited Hermes event objects, not JSON-RPC envelopes. Events always include `event` and `runId`, then event-specific fields.

## Principles

- The app controls user approval.
- The runtime emits structured events for every run.
- Sensitive tool calls pause until approval is resolved.
- Protocol messages are versioned.
- Errors are explicit and machine-readable.

## Core Methods

### `runtime.handshake`

The app calls this after starting the runtime.

Request params:

```json
{
  "protocolVersion": "0.1.0",
  "client": {
    "name": "Hermes.app",
    "version": "0.1.0"
  }
}
```

Response result:

```json
{
  "protocolVersion": "0.1.0",
  "runtime": {
    "name": "hermes-runtime",
    "version": "0.1.0"
  },
  "capabilities": ["runs", "tools", "approvals"]
}
```

### `run.create`

Starts an agent run.

Request params:

```json
{
  "sessionId": "session_123",
  "agentProfileId": "agent_hermes",
  "input": {
    "type": "text",
    "text": "Summarize this repository."
  },
  "history": [
    {
      "role": "assistant",
      "content": "I can help inspect this workspace."
    },
    {
      "role": "user",
      "content": "Summarize this repository."
    }
  ],
  "workspace": {
    "path": "/Users/example/project"
  }
}
```

`history` is optional and carries recent conversation messages as `user`, `assistant`, or `system` roles. The app sends recent visible chat turns so the runtime can call providers with a real conversation instead of a single prompt.

For MVP shell previews, text that trims to `/shell` or begins with `/shell` followed by whitespace requests shell approval. The runtime emits `tool.requested` and `approval.required` events and does not execute the command until a later execution slice implements approval resolution.

Response result:

```json
{
  "runId": "run_123",
  "status": "running"
}
```

### `provider.test`

Tests the currently configured model provider by sending a lightweight provider request through the same adapter used by normal runs.

Request params:

```json
{}
```

Response result:

```json
{
  "status": "ok",
  "provider": "MiniMax (China)",
  "model": "MiniMax-M2.7-highspeed"
}
```

### `approval.resolve`

Target method for resolving a pending approval request. This method is part of the protocol direction, but the current MVP runtime does not implement it yet.

Request params:

```json
{
  "approvalId": "approval_123",
  "decision": "approved"
}
```

`decision` is either `approved` or `denied`.

Response result:

```json
{
  "approvalId": "approval_123",
  "status": "resolved"
}
```

## Runtime Events

### `message.delta`

```json
{
  "event": "message.delta",
  "runId": "run_123",
  "delta": "The repository contains"
}
```

### `tool.requested`

```json
{
  "event": "tool.requested",
  "runId": "run_123",
  "toolCallId": "tool_123",
  "tool": "shell",
  "summary": "List repository files"
}
```

### `approval.required`

Shell command approval:

```json
{
  "event": "approval.required",
  "runId": "run_123",
  "approvalId": "approval_123",
  "toolCallId": "tool_123",
  "operation": {
    "tool": "shell",
    "command": "find . -maxdepth 2 -type f",
    "workingDirectory": "/Users/example/project",
    "risk": "executes-command"
  }
}
```

File write approval:

```json
{
  "event": "approval.required",
  "runId": "run_123",
  "approvalId": "approval_456",
  "toolCallId": "tool_456",
  "operation": {
    "tool": "file.write",
    "path": "/Users/example/project/README.md",
    "mode": "overwrite",
    "contentPreview": "# Hermes Agent\n\nUpdated project overview.\n",
    "byteCount": 42,
    "contentSha256": "216a644f66fe4058dbf318c2e06b68ad25ebafc62617e6b538163736b6c1d005",
    "risk": "writes-files"
  }
}
```

`file.write` approvals must include the target path, write mode, content preview, byte count, lowercase SHA-256 content hash (`contentSha256`), and `writes-files` risk so the app can show and audit the exact requested write before the user decides.

### `tool.result`

```json
{
  "event": "tool.result",
  "runId": "run_123",
  "toolCallId": "tool_123",
  "status": "completed",
  "outputPreview": "README.md\nAGENTS.md"
}
```

### `run.completed`

```json
{
  "event": "run.completed",
  "runId": "run_123",
  "status": "completed"
}
```

### `run.failed`

```json
{
  "event": "run.failed",
  "runId": "run_123",
  "status": "failed",
  "error": {
    "code": 5000,
    "message": "Provider request failed"
  }
}
```

Provider failures must be reported with stable, redacted error messages. Raw provider error strings can contain request metadata or credentials and must not be copied into protocol responses or runtime events.
