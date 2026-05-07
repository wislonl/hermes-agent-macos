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
    MessageDelta {
        #[serde(rename = "runId")]
        run_id: String,
        delta: String,
    },
    #[serde(rename = "run.completed")]
    RunCompleted {
        #[serde(rename = "runId")]
        run_id: String,
        status: String,
    },
}
