use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

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

impl JsonRpcError {
    pub fn parse_error() -> Self {
        Self {
            code: -32700,
            message: "Parse error".to_string(),
        }
    }

    pub fn invalid_request() -> Self {
        Self {
            code: -32600,
            message: "Invalid request".to_string(),
        }
    }
}

pub fn validate_request(value: Value) -> Result<JsonRpcRequest, JsonRpcErrorResponse> {
    let response_id = valid_response_id(&value);
    let Some(request) = value.as_object() else {
        return Err(invalid_request(response_id));
    };

    if !has_exact_fields(request, &["jsonrpc", "id", "method", "params"]) {
        return Err(invalid_request(response_id));
    }

    if request.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
        return Err(invalid_request(response_id));
    }

    if !request.get("id").is_some_and(is_valid_request_id) {
        return Err(invalid_request(Value::Null));
    }

    let method = match request.get("method").and_then(Value::as_str) {
        Some(method) => method,
        None => return Err(invalid_request(response_id)),
    };

    let Some(params) = request.get("params").and_then(Value::as_object) else {
        return Err(invalid_request(response_id));
    };

    if !has_valid_method_params(method, params) {
        return Err(invalid_request(response_id));
    }

    serde_json::from_value(Value::Object(request.clone())).map_err(|_| invalid_request(response_id))
}

fn invalid_request(id: Value) -> JsonRpcErrorResponse {
    JsonRpcErrorResponse {
        jsonrpc: "2.0",
        id,
        error: JsonRpcError::invalid_request(),
    }
}

fn valid_response_id(value: &Value) -> Value {
    value
        .as_object()
        .and_then(|request| request.get("id"))
        .filter(|id| is_valid_request_id(id))
        .cloned()
        .unwrap_or(Value::Null)
}

fn is_valid_request_id(id: &Value) -> bool {
    match id {
        Value::String(_) => true,
        Value::Number(number) => number.is_i64() || number.is_u64(),
        _ => false,
    }
}

fn has_valid_method_params(method: &str, params: &Map<String, Value>) -> bool {
    match method {
        "runtime.handshake" => {
            let Some(client) = params.get("client").and_then(Value::as_object) else {
                return false;
            };

            has_exact_fields(params, &["protocolVersion", "client"])
                && params
                    .get("protocolVersion")
                    .and_then(Value::as_str)
                    .is_some()
                && has_exact_fields(client, &["name", "version"])
                && params
                    .get("client")
                    .and_then(|client| client.get("name"))
                    .and_then(Value::as_str)
                    .is_some()
                && params
                    .get("client")
                    .and_then(|client| client.get("version"))
                    .and_then(Value::as_str)
                    .is_some()
        }
        "run.create" => {
            let Some(input) = params.get("input").and_then(Value::as_object) else {
                return false;
            };
            let Some(workspace) = params.get("workspace").and_then(Value::as_object) else {
                return false;
            };
            let history_is_valid = params
                .get("history")
                .is_none_or(|history| {
                    history.as_array().is_some_and(|messages| {
                        messages.iter().all(|message| {
                            let Some(message) = message.as_object() else {
                                return false;
                            };
                            has_exact_fields(message, &["role", "content"])
                                && message
                                    .get("role")
                                    .and_then(Value::as_str)
                                    .is_some_and(|role| matches!(role, "user" | "assistant" | "system"))
                                && message.get("content").and_then(Value::as_str).is_some()
                        })
                    })
                });

            has_only_fields(
                params,
                &["sessionId", "agentProfileId", "input", "history", "workspace"],
            ) && history_is_valid
                && params.get("sessionId").and_then(Value::as_str).is_some()
                && params
                    .get("agentProfileId")
                    .and_then(Value::as_str)
                    .is_some()
                && has_exact_fields(input, &["type", "text"])
                && params
                    .get("input")
                    .and_then(|input| input.get("type"))
                    .and_then(Value::as_str)
                    == Some("text")
                && params
                    .get("input")
                    .and_then(|input| input.get("text"))
                    .and_then(Value::as_str)
                    .is_some()
                && has_exact_fields(workspace, &["path"])
                && params
                    .get("workspace")
                    .and_then(|workspace| workspace.get("path"))
                    .and_then(Value::as_str)
                    .is_some()
        }
        "provider.test" => params.is_empty(),
        _ => true,
    }
}

fn has_exact_fields(object: &Map<String, Value>, fields: &[&str]) -> bool {
    object.len() == fields.len() && fields.iter().all(|field| object.contains_key(*field))
}

fn has_only_fields(object: &Map<String, Value>, fields: &[&str]) -> bool {
    object.keys().all(|key| fields.contains(&key.as_str()))
        && fields
            .iter()
            .filter(|field| **field != "history")
            .all(|field| object.contains_key(*field))
}

#[derive(Debug, Serialize)]
#[serde(tag = "event")]
pub enum RuntimeEvent {
    #[serde(rename = "message.delta")]
    MessageDelta {
        #[serde(rename = "runId")]
        run_id: String,
        delta: String,
    },
    #[serde(rename = "tool.requested")]
    ToolRequested {
        #[serde(rename = "runId")]
        run_id: String,
        #[serde(rename = "toolCallId")]
        tool_call_id: String,
        tool: String,
        summary: String,
    },
    #[serde(rename = "approval.required")]
    ApprovalRequired {
        #[serde(rename = "runId")]
        run_id: String,
        #[serde(rename = "approvalId")]
        approval_id: String,
        #[serde(rename = "toolCallId")]
        tool_call_id: String,
        operation: crate::tools::ToolOperation,
    },
    #[serde(rename = "run.completed")]
    RunCompleted {
        #[serde(rename = "runId")]
        run_id: String,
        status: String,
    },
}
