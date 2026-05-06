# Hermes Agent MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable Hermes Agent macOS workbench with a SwiftUI app, Rust runtime, typed JSON-RPC boundary, visible run events, and approval-gated tool calls.

**Architecture:** The macOS app owns the user experience, local settings, Keychain access, and approval UI. The Rust runtime runs as a child process over newline-delimited JSON-RPC on stdio, emits structured run events, and refuses sensitive tool calls until the app approves the exact operation.

**Tech Stack:** SwiftUI/AppKit, Swift Package Manager, Rust 2021, Cargo, Serde, Tokio, newline-delimited JSON-RPC, macOS Keychain, XCTest, Rust unit tests.

---

## File Structure

Create these implementation areas:

- `apps/macos/Package.swift` - Swift package for the macOS app and app tests.
- `apps/macos/Sources/HermesAgent/` - SwiftUI app, view models, protocol client, persistence adapters, Keychain adapter.
- `apps/macos/Tests/HermesAgentTests/` - Swift tests for protocol decoding, view-model state transitions, approval handling, and redaction.
- `crates/hermes-runtime/Cargo.toml` - Rust runtime crate manifest.
- `crates/hermes-runtime/src/` - runtime entrypoint, JSON-RPC transport, protocol types, runs, tools, approvals, provider abstraction.
- `crates/hermes-runtime/tests/` - runtime integration tests for stdio protocol and approval policy.
- `packages/hermes-protocol/schemas/` - JSON schema and examples for the app/runtime boundary.
- `scripts/` - local validation scripts that run all available checks.
- `docs/` - documentation updates for setup, protocol, and release.

Keep generated build outputs out of git. Keep `.superpowers/`, `.build/`, `target/`, and Xcode derived data ignored.

---

### Task 1: Repository Scaffolding and License

**Files:**
- Create: `LICENSE`
- Create: `scripts/check.sh`
- Modify: `README.md`
- Modify: `docs/CONTRIBUTING.md`

- [ ] **Step 1: Add Apache-2.0 license file**

Use the standard Apache License 2.0 text in `LICENSE` with copyright holder:

```text
Copyright 2026 Hermes Agent contributors
```

- [ ] **Step 2: Add the first validation script**

Create `scripts/check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT_DIR/crates/hermes-runtime/Cargo.toml" ]; then
  cargo test --manifest-path "$ROOT_DIR/crates/hermes-runtime/Cargo.toml"
fi

if [ -f "$ROOT_DIR/apps/macos/Package.swift" ]; then
  swift test --package-path "$ROOT_DIR/apps/macos"
fi
```

- [ ] **Step 3: Make the script executable**

Run:

```bash
chmod +x scripts/check.sh
```

Expected: command exits with status 0.

- [ ] **Step 4: Update README license and development sections**

Replace the README license section with:

```markdown
## License

Hermes Agent is licensed under the Apache License 2.0. See `LICENSE`.
```

Add this development command:

````markdown
Run all available local checks:

```bash
./scripts/check.sh
```
````

- [ ] **Step 5: Verify repository checks**

Run:

```bash
./scripts/check.sh
```

Expected: exits with status 0. At this stage it may run no component tests because implementation packages do not exist yet.

- [ ] **Step 6: Commit**

```bash
git add LICENSE scripts/check.sh README.md docs/CONTRIBUTING.md
git commit -m "chore: add project scaffolding metadata"
```

---

### Task 2: Protocol Schemas and Examples

**Files:**
- Create: `packages/hermes-protocol/schemas/hermes-protocol.schema.json`
- Create: `packages/hermes-protocol/examples/runtime-handshake.request.json`
- Create: `packages/hermes-protocol/examples/runtime-handshake.response.json`
- Create: `packages/hermes-protocol/examples/run-create.request.json`
- Create: `packages/hermes-protocol/examples/approval-required.event.json`
- Modify: `docs/PROTOCOL.md`

- [ ] **Step 1: Create the protocol schema**

Create `packages/hermes-protocol/schemas/hermes-protocol.schema.json` with JSON-RPC request, response, and event definitions:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://hermes-agent.dev/schemas/hermes-protocol.schema.json",
  "title": "Hermes Protocol",
  "type": "object",
  "oneOf": [
    { "$ref": "#/$defs/jsonRpcRequest" },
    { "$ref": "#/$defs/jsonRpcResponse" },
    { "$ref": "#/$defs/runtimeEvent" }
  ],
  "$defs": {
    "jsonRpcRequest": {
      "type": "object",
      "required": ["jsonrpc", "id", "method", "params"],
      "properties": {
        "jsonrpc": { "const": "2.0" },
        "id": { "type": ["string", "integer"] },
        "method": {
          "enum": ["runtime.handshake", "run.create", "run.cancel", "approval.resolve"]
        },
        "params": { "type": "object" }
      },
      "additionalProperties": false
    },
    "jsonRpcResponse": {
      "type": "object",
      "required": ["jsonrpc", "id"],
      "properties": {
        "jsonrpc": { "const": "2.0" },
        "id": { "type": ["string", "integer"] },
        "result": { "type": "object" },
        "error": { "$ref": "#/$defs/jsonRpcError" }
      },
      "oneOf": [
        { "required": ["result"] },
        { "required": ["error"] }
      ],
      "additionalProperties": false
    },
    "jsonRpcError": {
      "type": "object",
      "required": ["code", "message"],
      "properties": {
        "code": { "type": "integer" },
        "message": { "type": "string" },
        "data": { "type": "object" }
      },
      "additionalProperties": false
    },
    "runtimeEvent": {
      "type": "object",
      "required": ["event", "runId"],
      "properties": {
        "event": {
          "enum": ["message.delta", "tool.requested", "approval.required", "tool.result", "run.completed", "run.failed"]
        },
        "runId": { "type": "string" },
        "messageId": { "type": "string" },
        "toolCallId": { "type": "string" },
        "approvalId": { "type": "string" },
        "delta": { "type": "string" },
        "status": { "type": "string" },
        "summary": { "type": "string" },
        "operation": { "$ref": "#/$defs/toolOperation" },
        "outputPreview": { "type": "string" },
        "error": { "$ref": "#/$defs/jsonRpcError" }
      },
      "additionalProperties": false
    },
    "toolOperation": {
      "type": "object",
      "required": ["tool", "risk"],
      "properties": {
        "tool": { "enum": ["shell", "file.read", "file.write"] },
        "command": { "type": "string" },
        "workingDirectory": { "type": "string" },
        "path": { "type": "string" },
        "risk": { "enum": ["read-only", "writes-files", "executes-command", "network-side-effect"] }
      },
      "additionalProperties": false
    }
  }
}
```

- [ ] **Step 2: Add protocol examples**

Create example files matching `docs/PROTOCOL.md`. Use JSON-RPC envelopes for requests:

```json
{
  "jsonrpc": "2.0",
  "id": "req_1",
  "method": "runtime.handshake",
  "params": {
    "protocolVersion": "0.1.0",
    "client": {
      "name": "Hermes.app",
      "version": "0.1.0"
    }
  }
}
```

For `approval-required.event.json`, use:

```json
{
  "event": "approval.required",
  "runId": "run_123",
  "approvalId": "approval_123",
  "toolCallId": "tool_123",
  "operation": {
    "tool": "shell",
    "command": "ls -la",
    "workingDirectory": "/Users/example/project",
    "risk": "executes-command"
  }
}
```

- [ ] **Step 3: Update protocol docs**

Add a "Transport" section to `docs/PROTOCOL.md`:

```markdown
## Transport

The first runtime transport is newline-delimited JSON-RPC 2.0 over stdio. Every request, response, and runtime event is encoded as one JSON object followed by a newline.
```

- [ ] **Step 4: Verify examples are valid JSON**

Run:

```bash
for file in packages/hermes-protocol/examples/*.json packages/hermes-protocol/schemas/*.json; do
  python3 -m json.tool "$file" >/dev/null
done
```

Expected: no output and exit status 0.

- [ ] **Step 5: Commit**

```bash
git add packages/hermes-protocol docs/PROTOCOL.md
git commit -m "feat: define hermes protocol schema"
```

---

### Task 3: Rust Runtime Handshake and Mock Runs

**Files:**
- Create: `crates/hermes-runtime/Cargo.toml`
- Create: `crates/hermes-runtime/src/lib.rs`
- Create: `crates/hermes-runtime/src/main.rs`
- Create: `crates/hermes-runtime/src/protocol.rs`
- Create: `crates/hermes-runtime/src/runtime.rs`
- Create: `crates/hermes-runtime/tests/stdio_protocol.rs`

- [ ] **Step 1: Scaffold the Rust crate**

Create `crates/hermes-runtime/Cargo.toml`:

```toml
[package]
name = "hermes-runtime"
version = "0.1.0"
edition = "2021"

[dependencies]
anyhow = "1.0"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.38", features = ["io-std", "io-util", "macros", "process", "rt-multi-thread", "time"] }
uuid = { version = "1.8", features = ["v4"] }

[dev-dependencies]
assert_cmd = "2.0"
predicates = "3.1"
```

- [ ] **Step 2: Write protocol types**

Create `crates/hermes-runtime/src/protocol.rs`:

```rust
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub id: Value,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Serialize)]
pub struct JsonRpcResponse<T: Serialize> {
    pub jsonrpc: &'static str,
    pub id: Value,
    pub result: T,
}

#[derive(Debug, Serialize)]
pub struct JsonRpcErrorResponse {
    pub jsonrpc: &'static str,
    pub id: Value,
    pub error: JsonRpcError,
}

#[derive(Debug, Serialize)]
pub struct JsonRpcError {
    pub code: i64,
    pub message: String,
}

#[derive(Debug, Serialize)]
#[serde(tag = "event")]
pub enum RuntimeEvent {
    #[serde(rename = "message.delta")]
    MessageDelta { runId: String, delta: String },
    #[serde(rename = "run.completed")]
    RunCompleted { runId: String, status: String },
}
```

- [ ] **Step 3: Implement runtime handlers**

Create `crates/hermes-runtime/src/runtime.rs`:

```rust
use serde_json::{json, Value};
use uuid::Uuid;

use crate::protocol::{JsonRpcError, RuntimeEvent};

pub enum HandlerOutput {
    Response(Value),
    ResponseWithEvents { response: Value, events: Vec<RuntimeEvent> },
}

pub fn handle(method: &str, params: Value) -> Result<HandlerOutput, JsonRpcError> {
    match method {
        "runtime.handshake" => Ok(HandlerOutput::Response(json!({
            "protocolVersion": "0.1.0",
            "runtime": {
                "name": "hermes-runtime",
                "version": "0.1.0"
            },
            "capabilities": ["runs", "tools", "approvals"]
        }))),
        "run.create" => {
            let run_id = format!("run_{}", Uuid::new_v4().simple());
            let prompt = params
                .pointer("/input/text")
                .and_then(Value::as_str)
                .unwrap_or("Start Hermes run.");
            Ok(HandlerOutput::ResponseWithEvents {
                response: json!({ "runId": run_id, "status": "running" }),
                events: vec![
                    RuntimeEvent::MessageDelta {
                        runId: run_id.clone(),
                        delta: format!("Hermes received: {}", prompt),
                    },
                    RuntimeEvent::RunCompleted {
                        runId: run_id,
                        status: "completed".to_string(),
                    },
                ],
            })
        }
        _ => Err(JsonRpcError {
            code: -32601,
            message: format!("Unknown method: {}", method),
        }),
    }
}
```

- [ ] **Step 4: Implement stdio loop**

Create `crates/hermes-runtime/src/lib.rs`:

```rust
pub mod protocol;
pub mod runtime;
```

Create `crates/hermes-runtime/src/main.rs`:

```rust
use anyhow::Result;
use hermes_runtime::protocol::{JsonRpcErrorResponse, JsonRpcRequest, JsonRpcResponse};
use hermes_runtime::runtime::{self, HandlerOutput};
use tokio::io::{self, AsyncBufReadExt, AsyncWriteExt, BufReader};

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = BufReader::new(io::stdin());
    let mut lines = stdin.lines();
    let mut stdout = io::stdout();

    while let Some(line) = lines.next_line().await? {
        if line.trim().is_empty() {
            continue;
        }

        let request: JsonRpcRequest = serde_json::from_str(&line)?;
        let id = request.id.clone();

        match runtime::handle(&request.method, request.params) {
            Ok(HandlerOutput::Response(result)) => {
                let response = JsonRpcResponse { jsonrpc: "2.0", id, result };
                stdout.write_all(serde_json::to_string(&response)?.as_bytes()).await?;
                stdout.write_all(b"\n").await?;
            }
            Ok(HandlerOutput::ResponseWithEvents { response, events }) => {
                let response = JsonRpcResponse { jsonrpc: "2.0", id, result: response };
                stdout.write_all(serde_json::to_string(&response)?.as_bytes()).await?;
                stdout.write_all(b"\n").await?;
                for event in events {
                    stdout.write_all(serde_json::to_string(&event)?.as_bytes()).await?;
                    stdout.write_all(b"\n").await?;
                }
            }
            Err(error) => {
                let response = JsonRpcErrorResponse { jsonrpc: "2.0", id, error };
                stdout.write_all(serde_json::to_string(&response)?.as_bytes()).await?;
                stdout.write_all(b"\n").await?;
            }
        }
    }

    Ok(())
}
```

- [ ] **Step 5: Add integration test**

Create `crates/hermes-runtime/tests/stdio_protocol.rs`:

```rust
use assert_cmd::Command;
use predicates::str::contains;

#[test]
fn handshake_returns_runtime_capabilities() {
    let mut cmd = Command::cargo_bin("hermes-runtime").unwrap();
    cmd.write_stdin(
        r#"{"jsonrpc":"2.0","id":"req_1","method":"runtime.handshake","params":{"protocolVersion":"0.1.0"}}"#,
    )
    .assert()
    .success()
    .stdout(contains("\"name\":\"hermes-runtime\""))
    .stdout(contains("\"approvals\""));
}
```

- [ ] **Step 6: Run Rust tests**

Run:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add crates/hermes-runtime
git commit -m "feat: add hermes runtime handshake"
```

---

### Task 4: Runtime Approval Policy and Tool Events

**Files:**
- Create: `crates/hermes-runtime/src/approval.rs`
- Create: `crates/hermes-runtime/src/tools.rs`
- Modify: `crates/hermes-runtime/src/protocol.rs`
- Modify: `crates/hermes-runtime/src/runtime.rs`
- Create: `crates/hermes-runtime/tests/approval_policy.rs`

- [ ] **Step 1: Add approval model**

Create `crates/hermes-runtime/src/approval.rs`:

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Risk {
    ReadOnly,
    WritesFiles,
    ExecutesCommand,
    NetworkSideEffect,
}

pub fn requires_approval(risk: &Risk) -> bool {
    matches!(risk, Risk::WritesFiles | Risk::ExecutesCommand | Risk::NetworkSideEffect)
}
```

- [ ] **Step 2: Add tool operation types**

Create `crates/hermes-runtime/src/tools.rs`:

```rust
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct ToolOperation {
    pub tool: String,
    pub command: Option<String>,
    pub workingDirectory: Option<String>,
    pub path: Option<String>,
    pub risk: String,
}
```

- [ ] **Step 3: Extend runtime events**

Modify `RuntimeEvent` in `protocol.rs` to include:

```rust
#[serde(rename = "tool.requested")]
ToolRequested {
    runId: String,
    toolCallId: String,
    tool: String,
    summary: String,
},
#[serde(rename = "approval.required")]
ApprovalRequired {
    runId: String,
    approvalId: String,
    toolCallId: String,
    operation: crate::tools::ToolOperation,
},
```

- [ ] **Step 4: Emit approval event for shell requests in mock run**

In `runtime.rs`, when `params.input.text` contains `/shell`, add `tool.requested` and `approval.required` before `run.completed`. Use:

```rust
RuntimeEvent::ToolRequested {
    runId: run_id.clone(),
    toolCallId: "tool_shell_preview".to_string(),
    tool: "shell".to_string(),
    summary: "Preview shell command".to_string(),
}
```

and:

```rust
RuntimeEvent::ApprovalRequired {
    runId: run_id.clone(),
    approvalId: "approval_shell_preview".to_string(),
    toolCallId: "tool_shell_preview".to_string(),
    operation: crate::tools::ToolOperation {
        tool: "shell".to_string(),
        command: Some("pwd && ls".to_string()),
        workingDirectory: Some(".".to_string()),
        path: None,
        risk: "executes-command".to_string(),
    },
}
```

- [ ] **Step 5: Add approval unit tests**

Create `crates/hermes-runtime/tests/approval_policy.rs`:

```rust
use hermes_runtime::approval::{requires_approval, Risk};

#[test]
fn read_only_operations_do_not_require_approval() {
    assert!(!requires_approval(&Risk::ReadOnly));
}

#[test]
fn shell_and_write_operations_require_approval() {
    assert!(requires_approval(&Risk::ExecutesCommand));
    assert!(requires_approval(&Risk::WritesFiles));
}
```

Update `crates/hermes-runtime/src/lib.rs`:

```rust
pub mod approval;
pub mod protocol;
pub mod runtime;
pub mod tools;
```

- [ ] **Step 6: Run Rust tests**

Run:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add crates/hermes-runtime
git commit -m "feat: add runtime approval events"
```

---

### Task 5: SwiftUI macOS Static Workbench

**Files:**
- Create: `apps/macos/Package.swift`
- Create: `apps/macos/Sources/HermesAgent/HermesAgentApp.swift`
- Create: `apps/macos/Sources/HermesAgent/AppState.swift`
- Create: `apps/macos/Sources/HermesAgent/Models.swift`
- Create: `apps/macos/Sources/HermesAgent/Views/WorkbenchView.swift`
- Create: `apps/macos/Sources/HermesAgent/Views/SidebarView.swift`
- Create: `apps/macos/Sources/HermesAgent/Views/ConversationView.swift`
- Create: `apps/macos/Sources/HermesAgent/Views/InspectorView.swift`
- Create: `apps/macos/Tests/HermesAgentTests/AppStateTests.swift`

- [ ] **Step 1: Create Swift package**

Create `apps/macos/Package.swift`:

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HermesAgent",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HermesAgent", targets: ["HermesAgent"])
    ],
    targets: [
        .executableTarget(name: "HermesAgent"),
        .testTarget(name: "HermesAgentTests", dependencies: ["HermesAgent"])
    ]
)
```

- [ ] **Step 2: Add core models**

Create `apps/macos/Sources/HermesAgent/Models.swift`:

```swift
import Foundation

struct AgentProfile: Identifiable, Equatable {
    let id: String
    var name: String
    var role: String
}

struct ChatMessage: Identifiable, Equatable {
    enum Author { case user, assistant, system }
    let id: UUID
    var author: Author
    var text: String
}

struct ToolCall: Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var requiresApproval: Bool
}
```

- [ ] **Step 3: Add app state**

Create `apps/macos/Sources/HermesAgent/AppState.swift`:

```swift
import Foundation
import Observation

@Observable
final class AppState {
    var agents: [AgentProfile] = [
        AgentProfile(id: "agent_hermes", name: "Hermes", role: "General desktop agent"),
        AgentProfile(id: "agent_research", name: "Research", role: "Research profile"),
        AgentProfile(id: "agent_coding", name: "Coding", role: "Coding profile")
    ]
    var selectedAgentId = "agent_hermes"
    var messages: [ChatMessage] = [
        ChatMessage(id: UUID(), author: .assistant, text: "Hermes is ready.")
    ]
    var toolCalls: [ToolCall] = []
    var draft = ""

    func submitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(id: UUID(), author: .user, text: trimmed))
        draft = ""
    }
}
```

- [ ] **Step 4: Add SwiftUI app entrypoint**

Create `apps/macos/Sources/HermesAgent/HermesAgentApp.swift`:

```swift
import SwiftUI

@main
struct HermesAgentApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            WorkbenchView(state: state)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}
```

- [ ] **Step 5: Add workbench views**

Create `WorkbenchView.swift`:

```swift
import SwiftUI

struct WorkbenchView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
        } content: {
            ConversationView(state: state)
        } detail: {
            InspectorView(state: state)
        }
    }
}
```

Create `SidebarView.swift`:

```swift
import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        List(selection: $state.selectedAgentId) {
            Section("Agents") {
                ForEach(state.agents) { agent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name).font(.headline)
                        Text(agent.role).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(agent.id)
                }
            }
        }
        .navigationTitle("Hermes")
    }
}
```

Create `ConversationView.swift`:

```swift
import SwiftUI

struct ConversationView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.messages) { message in
                        Text(message.text)
                            .frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading)
                            .padding(10)
                            .background(message.author == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            HStack {
                TextField("Ask Hermes", text: $state.draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.submitDraft() }
                Button("Send") { state.submitDraft() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Conversation")
    }
}
```

Create `InspectorView.swift`:

```swift
import SwiftUI

struct InspectorView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Inspector").font(.title3).bold()

            if state.toolCalls.isEmpty {
                ContentUnavailableView("No tool calls yet", systemImage: "wrench.and.screwdriver")
            } else {
                List(state.toolCalls) { call in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(call.title).font(.headline)
                        Text(call.detail).font(.caption).foregroundStyle(.secondary)
                        if call.requiresApproval {
                            Label("Approval required", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(minWidth: 280)
    }
}
```

- [ ] **Step 6: Add AppState test**

Create `apps/macos/Tests/HermesAgentTests/AppStateTests.swift`:

```swift
import XCTest
@testable import HermesAgent

final class AppStateTests: XCTestCase {
    func testSubmitDraftAddsUserMessageAndClearsDraft() {
        let state = AppState()
        state.draft = "Hello Hermes"

        state.submitDraft()

        XCTAssertEqual(state.messages.last?.text, "Hello Hermes")
        XCTAssertEqual(state.messages.last?.author, .user)
        XCTAssertEqual(state.draft, "")
    }
}
```

- [ ] **Step 7: Run Swift tests**

Run:

```bash
swift test --package-path apps/macos
```

Expected: `AppStateTests` passes.

- [ ] **Step 8: Commit**

```bash
git add apps/macos
git commit -m "feat: add macos workbench shell"
```

---

### Task 6: Swift JSON-RPC Client and Runtime Process Adapter

**Files:**
- Create: `apps/macos/Sources/HermesAgent/Runtime/JsonRpcModels.swift`
- Create: `apps/macos/Sources/HermesAgent/Runtime/RuntimeClient.swift`
- Create: `apps/macos/Sources/HermesAgent/Runtime/ProcessRuntimeClient.swift`
- Create: `apps/macos/Tests/HermesAgentTests/JsonRpcModelsTests.swift`
- Create: `apps/macos/Tests/HermesAgentTests/RuntimeClientTests.swift`

- [ ] **Step 1: Add Swift JSON-RPC models**

Create `JsonRpcModels.swift` with codable envelopes:

```swift
import Foundation

struct JsonRpcRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: Params
}

struct JsonRpcResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: String
    let result: Result?
    let error: JsonRpcError?
}

struct JsonRpcError: Decodable, Equatable {
    let code: Int
    let message: String
}

struct RuntimeHandshakeParams: Encodable {
    let protocolVersion: String
    let client: RuntimeClientInfo
}

struct RuntimeClientInfo: Encodable {
    let name: String
    let version: String
}

struct RuntimeHandshakeResult: Decodable, Equatable {
    let protocolVersion: String
    let runtime: RuntimeInfo
    let capabilities: [String]
}

struct RuntimeInfo: Decodable, Equatable {
    let name: String
    let version: String
}
```

- [ ] **Step 2: Define runtime client protocol**

Create `RuntimeClient.swift`:

```swift
import Foundation

protocol RuntimeClient {
    func handshake() async throws -> RuntimeHandshakeResult
    func createRun(input: String, workspacePath: String?) async throws
}
```

- [ ] **Step 3: Implement process adapter skeleton**

Create `ProcessRuntimeClient.swift`:

```swift
import Foundation

final class ProcessRuntimeClient: RuntimeClient {
    private let runtimeURL: URL

    init(runtimeURL: URL) {
        self.runtimeURL = runtimeURL
    }

    func handshake() async throws -> RuntimeHandshakeResult {
        let request = JsonRpcRequest(
            id: "req_handshake",
            method: "runtime.handshake",
            params: RuntimeHandshakeParams(
                protocolVersion: "0.1.0",
                client: RuntimeClientInfo(name: "Hermes.app", version: "0.1.0")
            )
        )
        _ = try JSONEncoder().encode(request)

        return RuntimeHandshakeResult(
            protocolVersion: "0.1.0",
            runtime: RuntimeInfo(name: runtimeURL.lastPathComponent, version: "0.1.0"),
            capabilities: ["runs", "tools", "approvals"]
        )
    }

    func createRun(input: String, workspacePath: String?) async throws {
        _ = input
        _ = workspacePath
    }
}
```

- [ ] **Step 4: Add JSON-RPC encoding test**

Create `JsonRpcModelsTests.swift`:

```swift
import XCTest
@testable import HermesAgent

final class JsonRpcModelsTests: XCTestCase {
    func testHandshakeRequestEncodesJsonRpcEnvelope() throws {
        let request = JsonRpcRequest(
            id: "req_1",
            method: "runtime.handshake",
            params: RuntimeHandshakeParams(
                protocolVersion: "0.1.0",
                client: RuntimeClientInfo(name: "Hermes.app", version: "0.1.0")
            )
        )

        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"method\":\"runtime.handshake\""))
    }
}
```

- [ ] **Step 5: Run Swift tests**

Run:

```bash
swift test --package-path apps/macos
```

Expected: all Swift tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/macos
git commit -m "feat: add swift runtime client models"
```

---

### Task 7: Wire App State to Runtime Events

**Files:**
- Modify: `apps/macos/Sources/HermesAgent/AppState.swift`
- Modify: `apps/macos/Sources/HermesAgent/Views/ConversationView.swift`
- Modify: `apps/macos/Sources/HermesAgent/Views/InspectorView.swift`
- Create: `apps/macos/Sources/HermesAgent/Runtime/RuntimeEvent.swift`
- Create: `apps/macos/Tests/HermesAgentTests/RuntimeEventStateTests.swift`

- [ ] **Step 1: Add runtime event model**

Create `RuntimeEvent.swift`:

```swift
import Foundation

enum RuntimeEvent: Equatable {
    case messageDelta(runId: String, delta: String)
    case toolRequested(runId: String, toolCallId: String, tool: String, summary: String)
    case approvalRequired(runId: String, approvalId: String, toolCallId: String, command: String)
    case runCompleted(runId: String, status: String)
}
```

- [ ] **Step 2: Add event reducer to AppState**

Add this method to `AppState`:

```swift
func apply(event: RuntimeEvent) {
    switch event {
    case .messageDelta(_, let delta):
        messages.append(ChatMessage(id: UUID(), author: .assistant, text: delta))
    case .toolRequested(_, let toolCallId, let tool, let summary):
        toolCalls.append(ToolCall(id: toolCallId, title: tool, detail: summary, requiresApproval: false))
    case .approvalRequired(_, let approvalId, _, let command):
        toolCalls.append(ToolCall(id: approvalId, title: "Approval required", detail: command, requiresApproval: true))
    case .runCompleted:
        break
    }
}
```

- [ ] **Step 3: Update submit flow**

Change `submitDraft()` so it appends the user message and then appends a mock assistant event through `apply(event:)`:

```swift
apply(event: .messageDelta(runId: "run_preview", delta: "Hermes is connected to the workbench."))
```

- [ ] **Step 4: Add reducer tests**

Create `RuntimeEventStateTests.swift`:

```swift
import XCTest
@testable import HermesAgent

final class RuntimeEventStateTests: XCTestCase {
    func testApprovalEventAddsApprovalToolCall() {
        let state = AppState()

        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "pwd && ls"
        ))

        XCTAssertEqual(state.toolCalls.last?.title, "Approval required")
        XCTAssertEqual(state.toolCalls.last?.requiresApproval, true)
    }
}
```

- [ ] **Step 5: Run Swift tests**

Run:

```bash
swift test --package-path apps/macos
```

Expected: all Swift tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/macos
git commit -m "feat: render runtime events in workbench"
```

---

### Task 8: Local Session Storage and Keychain Adapter

**Files:**
- Create: `apps/macos/Sources/HermesAgent/Storage/SessionStore.swift`
- Create: `apps/macos/Sources/HermesAgent/Storage/FileSessionStore.swift`
- Create: `apps/macos/Sources/HermesAgent/Security/KeychainStore.swift`
- Create: `apps/macos/Tests/HermesAgentTests/FileSessionStoreTests.swift`
- Create: `apps/macos/Tests/HermesAgentTests/KeychainStoreTests.swift`

- [ ] **Step 1: Define session store protocol**

Create `SessionStore.swift`:

```swift
import Foundation

struct StoredSession: Codable, Equatable {
    let id: String
    var title: String
    var messages: [String]
}

protocol SessionStore {
    func loadSessions() throws -> [StoredSession]
    func saveSessions(_ sessions: [StoredSession]) throws
}
```

- [ ] **Step 2: Add file-backed session store**

Create `FileSessionStore.swift`:

```swift
import Foundation

final class FileSessionStore: SessionStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func loadSessions() throws -> [StoredSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([StoredSession].self, from: data)
    }

    func saveSessions(_ sessions: [StoredSession]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: fileURL, options: [.atomic])
    }
}
```

- [ ] **Step 3: Add Keychain interface**

Create `KeychainStore.swift` with a minimal interface:

```swift
import Foundation

protocol SecretStore {
    func setSecret(_ value: String, account: String) throws
    func getSecret(account: String) throws -> String?
    func deleteSecret(account: String) throws
}

enum KeychainStoreError: Error {
    case unimplemented
}

final class KeychainStore: SecretStore {
    func setSecret(_ value: String, account: String) throws {
        _ = value
        _ = account
        throw KeychainStoreError.unimplemented
    }

    func getSecret(account: String) throws -> String? {
        _ = account
        throw KeychainStoreError.unimplemented
    }

    func deleteSecret(account: String) throws {
        _ = account
        throw KeychainStoreError.unimplemented
    }
}
```

This step intentionally defines the boundary first. The next implementation step replaces the throwing stub with Security.framework calls.

- [ ] **Step 4: Add file session store test**

Create `FileSessionStoreTests.swift`:

```swift
import XCTest
@testable import HermesAgent

final class FileSessionStoreTests: XCTestCase {
    func testRoundTripSessions() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("sessions.json")
        let store = FileSessionStore(fileURL: url)
        let sessions = [StoredSession(id: "session_1", title: "First", messages: ["Hello"])]

        try store.saveSessions(sessions)

        XCTAssertEqual(try store.loadSessions(), sessions)
    }
}
```

- [ ] **Step 5: Run Swift tests**

Run:

```bash
swift test --package-path apps/macos
```

Expected: all Swift tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/macos
git commit -m "feat: add local session storage boundary"
```

---

### Task 9: Real Keychain Storage

**Files:**
- Modify: `apps/macos/Package.swift`
- Modify: `apps/macos/Sources/HermesAgent/Security/KeychainStore.swift`
- Modify: `apps/macos/Tests/HermesAgentTests/KeychainStoreTests.swift`

- [ ] **Step 1: Link Security framework**

In `apps/macos/Package.swift`, add linker settings to the executable target:

```swift
.executableTarget(
    name: "HermesAgent",
    linkerSettings: [.linkedFramework("Security")]
)
```

- [ ] **Step 2: Implement Keychain set/get/delete**

Replace the throwing stub with Security.framework calls using service name `dev.hermes-agent.app`. Store secrets as UTF-8 data and use `kSecClassGenericPassword`.

For `setSecret`, delete any existing item for the account before adding the replacement. For `getSecret`, return `nil` on `errSecItemNotFound` and throw for other non-success statuses.

- [ ] **Step 3: Add Keychain round-trip test**

Use a unique account:

```swift
func testKeychainRoundTrip() throws {
    let store = KeychainStore()
    let account = "test-\(UUID().uuidString)"

    try store.setSecret("sk-test-value", account: account)
    XCTAssertEqual(try store.getSecret(account: account), "sk-test-value")

    try store.deleteSecret(account: account)
    XCTAssertNil(try store.getSecret(account: account))
}
```

- [ ] **Step 4: Run Swift tests**

Run:

```bash
swift test --package-path apps/macos
```

Expected: all Swift tests pass on macOS with Keychain access available.

- [ ] **Step 5: Commit**

```bash
git add apps/macos
git commit -m "feat: store provider secrets in keychain"
```

---

### Task 10: Shell Tool Approval End-to-End Slice

**Files:**
- Modify: `crates/hermes-runtime/src/tools.rs`
- Modify: `crates/hermes-runtime/src/runtime.rs`
- Modify: `apps/macos/Sources/HermesAgent/Views/InspectorView.swift`
- Modify: `apps/macos/Sources/HermesAgent/AppState.swift`
- Create: `apps/macos/Tests/HermesAgentTests/ApprovalDecisionTests.swift`
- Create: `crates/hermes-runtime/tests/shell_tool_events.rs`

- [ ] **Step 1: Runtime emits shell approval for `/shell` prompts**

When `run.create` receives text beginning with `/shell `, parse the rest as the requested command and emit an `approval.required` event with risk `executes-command`. Do not execute the command in this task.

- [ ] **Step 2: App state tracks approval decisions**

Add:

```swift
enum ApprovalDecision: Equatable {
    case approved
    case denied
}

struct ApprovalRequest: Identifiable, Equatable {
    let id: String
    let command: String
    var decision: ApprovalDecision?
}
```

Store `[ApprovalRequest]` in `AppState`.

- [ ] **Step 3: Inspector shows approve and deny buttons**

For approval-required tool calls, `InspectorView` must show the command plus `Approve` and `Deny` buttons. Button actions update `AppState` with the decision. The UI must not imply the command has executed until runtime execution is implemented.

- [ ] **Step 4: Add approval decision test**

Create `ApprovalDecisionTests.swift`:

```swift
import XCTest
@testable import HermesAgent

final class ApprovalDecisionTests: XCTestCase {
    func testDenyApprovalRecordsDecision() {
        let state = AppState()
        state.apply(event: .approvalRequired(
            runId: "run_1",
            approvalId: "approval_1",
            toolCallId: "tool_1",
            command: "rm -rf build"
        ))

        state.resolveApproval(id: "approval_1", decision: .denied)

        XCTAssertEqual(state.approvals.first?.decision, .denied)
    }
}
```

- [ ] **Step 5: Run all checks**

Run:

```bash
./scripts/check.sh
```

Expected: Rust and Swift tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/macos crates/hermes-runtime
git commit -m "feat: add shell approval slice"
```

---

### Task 11: Provider Adapter Boundary

**Files:**
- Create: `crates/hermes-runtime/src/provider.rs`
- Modify: `crates/hermes-runtime/src/runtime.rs`
- Create: `crates/hermes-runtime/tests/provider_adapter.rs`
- Modify: `docs/SECURITY.md`

- [ ] **Step 1: Define provider trait**

Create `provider.rs`:

```rust
use anyhow::Result;

pub struct ProviderRequest {
    pub input: String,
}

pub struct ProviderDelta {
    pub text: String,
}

pub trait ModelProvider {
    fn stream(&self, request: ProviderRequest) -> Result<Vec<ProviderDelta>>;
}

pub struct EchoProvider;

impl ModelProvider for EchoProvider {
    fn stream(&self, request: ProviderRequest) -> Result<Vec<ProviderDelta>> {
        Ok(vec![ProviderDelta {
            text: format!("Hermes received: {}", request.input),
        }])
    }
}
```

- [ ] **Step 2: Use EchoProvider in mock runs**

Replace direct message formatting in `runtime.rs` with `EchoProvider`. Keep provider behavior deterministic for tests.

- [ ] **Step 3: Add provider test**

Create `provider_adapter.rs`:

```rust
use hermes_runtime::provider::{EchoProvider, ModelProvider, ProviderRequest};

#[test]
fn echo_provider_returns_deterministic_delta() {
    let provider = EchoProvider;
    let deltas = provider.stream(ProviderRequest { input: "hello".to_string() }).unwrap();
    assert_eq!(deltas[0].text, "Hermes received: hello");
}
```

- [ ] **Step 4: Document provider secret rule**

Add to `docs/SECURITY.md`:

```markdown
Provider adapters must receive secrets through explicit configuration paths and must never include secret values in runtime events. Provider request logs must redact authorization headers and API keys.
```

- [ ] **Step 5: Run all checks**

Run:

```bash
./scripts/check.sh
```

Expected: all available checks pass.

- [ ] **Step 6: Commit**

```bash
git add crates/hermes-runtime docs/SECURITY.md
git commit -m "feat: add provider adapter boundary"
```

---

### Task 12: Documentation and Release Readiness Pass

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/PROTOCOL.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/CONTRIBUTING.md`
- Create: `docs/RELEASE.md`

- [ ] **Step 1: Update README with current run commands**

Add:

````markdown
Run the runtime tests:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
```

Run the macOS app tests:

```bash
swift test --package-path apps/macos
```
````

- [ ] **Step 2: Add release notes draft**

Create `docs/RELEASE.md`:

````markdown
# Release Process

Hermes Agent does not have a signed app release yet.

For early local testing:

```bash
swift run --package-path apps/macos HermesAgent
```

Before the first public release:

- Add a signed macOS app bundle workflow.
- Produce a `.zip` or `.dmg` artifact.
- Verify Keychain access in the packaged app.
- Verify runtime child-process startup from the app bundle.
- Add screenshots and a short demo GIF to the README.
```
````

- [ ] **Step 3: Update roadmap statuses**

Mark completed MVP infrastructure items in `docs/ROADMAP.md` as done using markdown checkboxes. Leave unimplemented items unchecked.

- [ ] **Step 4: Run documentation scan**

Run:

```bash
rg -n "TBD|TODO|fill in|implement later|not scaffolded yet" README.md AGENTS.md docs || true
```

Expected: no output except intentional prose in historical design notes if present.

- [ ] **Step 5: Run all checks**

Run:

```bash
./scripts/check.sh
```

Expected: all available checks pass.

- [ ] **Step 6: Commit**

```bash
git add README.md docs
git commit -m "docs: document mvp development workflow"
```

---

## Final Verification

After all tasks complete, run:

```bash
./scripts/check.sh
git status --short
```

Expected:

- Rust runtime tests pass.
- Swift app tests pass.
- `git status --short` shows no uncommitted implementation changes.

Then open the macOS app locally:

```bash
swift run --package-path apps/macos HermesAgent
```

Manual verification:

- The app opens a native macOS window.
- The three-pane workbench is visible.
- The default Hermes, Research, and Coding profiles are listed.
- Submitting a message appends it to the conversation.
- A mock Hermes response appears.
- Entering a `/shell pwd && ls` style prompt produces an approval-required item.
- The right inspector displays approve and deny controls.
