use serde_json::{json, Value};
use uuid::Uuid;

use crate::protocol::{JsonRpcError, RuntimeEvent};

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
            Ok(HandlerOutput::ResponseWithEvents {
                response: json!({ "runId": run_id, "status": "running" }),
                events: vec![
                    RuntimeEvent::MessageDelta {
                        run_id: run_id.clone(),
                        delta: format!("Hermes received: {}", prompt),
                    },
                    RuntimeEvent::RunCompleted {
                        run_id,
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
