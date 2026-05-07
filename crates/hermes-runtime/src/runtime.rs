use serde_json::{json, Value};
use uuid::Uuid;

use crate::provider::{
    redacted_provider_error_message, EchoProvider, ModelProvider, OpenAICompatibleProvider,
    ProviderMessage, ProviderRequest,
};
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
        "provider.test" => {
            if let Some(provider) = OpenAICompatibleProvider::from_env() {
                test_provider(&provider)
            } else {
                let provider = EchoProvider;
                test_provider(&provider)
            }
        }
        "run.create" => {
            if let Some(provider) = OpenAICompatibleProvider::from_env() {
                create_run(params, &provider)
            } else {
                let provider = EchoProvider;
                create_run(params, &provider)
            }
        }
        _ => Err(JsonRpcError {
            code: -32601,
            message: format!("Unknown method: {}", method),
        }),
    }
}

pub fn test_provider(provider: &impl ModelProvider) -> Result<HandlerOutput, JsonRpcError> {
    provider
        .stream(ProviderRequest {
            input: "Reply with exactly: OK".to_string(),
            messages: vec![ProviderMessage {
                role: "user".to_string(),
                content: "Reply with exactly: OK".to_string(),
            }],
        })
        .map_err(|error| JsonRpcError {
            code: -32603,
            message: redacted_provider_error_message(&error),
        })?;

    Ok(HandlerOutput::Response(json!({
        "status": "ok",
        "provider": provider.name(),
        "model": provider.model(),
    })))
}

pub fn create_run(
    params: Value,
    provider: &impl ModelProvider,
) -> Result<HandlerOutput, JsonRpcError> {
    let run_id = format!("run_{}", Uuid::new_v4().simple());
    let prompt = params
        .pointer("/input/text")
        .and_then(Value::as_str)
        .unwrap_or("Start Hermes run.");
    let messages = history_messages(&params);
    let deltas = provider
        .stream(ProviderRequest {
            input: prompt.to_string(),
            messages,
        })
        .map_err(|error| JsonRpcError {
            code: -32603,
            message: redacted_provider_error_message(&error),
        })?;
    let mut events = deltas
        .into_iter()
        .map(|delta| RuntimeEvent::MessageDelta {
            run_id: run_id.clone(),
            delta: delta.text,
        })
        .collect::<Vec<_>>();

    if let Some(command) = shell_command_from_prompt(prompt) {
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
                command: Some(command),
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

fn history_messages(params: &Value) -> Vec<ProviderMessage> {
    params
        .get("history")
        .and_then(Value::as_array)
        .map(|messages| {
            messages
                .iter()
                .filter_map(|message| {
                    Some(ProviderMessage {
                        role: message.get("role")?.as_str()?.to_string(),
                        content: message.get("content")?.as_str()?.to_string(),
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

fn shell_command_from_prompt(prompt: &str) -> Option<String> {
    let trimmed = prompt.trim();

    if trimmed == "/shell" {
        return Some("pwd && ls".to_string());
    }

    let remaining = trimmed.strip_prefix("/shell")?;
    if !remaining.chars().next().is_some_and(char::is_whitespace) {
        return None;
    }

    let command = remaining.trim();
    if command.is_empty() {
        Some("pwd && ls".to_string())
    } else {
        Some(command.to_string())
    }
}
