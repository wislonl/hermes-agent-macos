use serde_json::{json, Value};
use uuid::Uuid;

use crate::protocol::{JsonRpcError, RuntimeEvent};
use crate::tools::ToolOperation;

pub enum HandlerOutput {
    Response(Value),
    ResponseWithEvents {
        response: Value,
        events: Vec<RuntimeEvent>,
    },
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
            let mut events = vec![RuntimeEvent::MessageDelta {
                run_id: run_id.clone(),
                delta: format!("Hermes received: {}", prompt),
            }];

            if is_shell_command_prompt(prompt) {
                let tool_call_id = format!("tool_shell_preview_{}", run_id);
                let approval_id = format!("approval_shell_preview_{}", run_id);
                events.push(RuntimeEvent::ToolRequested {
                    run_id: run_id.clone(),
                    tool_call_id: tool_call_id.clone(),
                    tool: "shell".to_string(),
                    summary: "Preview shell command".to_string(),
                });
                events.push(RuntimeEvent::ApprovalRequired {
                    run_id: run_id.clone(),
                    approval_id,
                    tool_call_id,
                    operation: ToolOperation {
                        tool: "shell".to_string(),
                        command: Some("pwd && ls".to_string()),
                        working_directory: Some(".".to_string()),
                        path: None,
                        risk: "executes-command".to_string(),
                    },
                });
            } else {
                events.push(RuntimeEvent::RunCompleted {
                    run_id: run_id.clone(),
                    status: "completed".to_string(),
                });
            }

            Ok(HandlerOutput::ResponseWithEvents {
                response: json!({ "runId": run_id, "status": "running" }),
                events,
            })
        }
        _ => Err(JsonRpcError {
            code: -32601,
            message: format!("Unknown method: {}", method),
        }),
    }
}

fn is_shell_command_prompt(prompt: &str) -> bool {
    let trimmed = prompt.trim();

    if trimmed == "/shell" {
        return true;
    }

    trimmed
        .strip_prefix("/shell")
        .and_then(|remaining| remaining.chars().next())
        .is_some_and(char::is_whitespace)
}
