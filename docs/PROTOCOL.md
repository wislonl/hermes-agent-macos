# Hermes Protocol

## Overview

Hermes Protocol defines communication between the macOS app and the local runtime. The transport for the first version is JSON-RPC over stdio.

## Principles

- The app controls user approval.
- The runtime emits structured events for every run.
- Sensitive tool calls pause until approval is resolved.
- Protocol messages are versioned.
- Errors are explicit and machine-readable.

## Core Methods

### `runtime.handshake`

The app calls this after starting the runtime.

Request:

```json
{
  "protocolVersion": "0.1.0",
  "client": {
    "name": "Hermes.app",
    "version": "0.1.0"
  }
}
```

Response:

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

Request:

```json
{
  "sessionId": "session_123",
  "agentProfileId": "agent_hermes",
  "input": {
    "type": "text",
    "text": "Summarize this repository."
  },
  "workspace": {
    "path": "/Users/example/project"
  }
}
```

Response:

```json
{
  "runId": "run_123",
  "status": "running"
}
```

### `approval.resolve`

Resolves a pending approval request.

Request:

```json
{
  "approvalId": "approval_123",
  "decision": "approved"
}
```

Response:

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
    "risk": "read-only"
  }
}
```

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

