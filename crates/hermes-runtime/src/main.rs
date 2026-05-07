use anyhow::Result;
use hermes_runtime::protocol::{
    validate_request, JsonRpcError, JsonRpcErrorResponse, JsonRpcResponse,
};
use hermes_runtime::runtime::{self, HandlerOutput};
use serde::Serialize;
use serde_json::Value;
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

        let request_value = match serde_json::from_str::<Value>(&line) {
            Ok(value) => value,
            Err(_) => {
                write_json(
                    &mut stdout,
                    &JsonRpcErrorResponse {
                        jsonrpc: "2.0",
                        id: Value::Null,
                        error: JsonRpcError::parse_error(),
                    },
                )
                .await?;
                continue;
            }
        };

        let request = match validate_request(request_value) {
            Ok(request) => request,
            Err(response) => {
                write_json(&mut stdout, &response).await?;
                continue;
            }
        };
        let id = request.id.clone();

        match runtime::handle(&request.method, request.params) {
            Ok(HandlerOutput::Response(result)) => {
                let response = JsonRpcResponse {
                    jsonrpc: "2.0",
                    id,
                    result,
                };
                write_json(&mut stdout, &response).await?;
            }
            Ok(HandlerOutput::ResponseWithEvents { response, events }) => {
                let response = JsonRpcResponse {
                    jsonrpc: "2.0",
                    id,
                    result: response,
                };
                write_json(&mut stdout, &response).await?;
                for event in events {
                    write_json(&mut stdout, &event).await?;
                }
            }
            Err(error) => {
                let response = JsonRpcErrorResponse {
                    jsonrpc: "2.0",
                    id,
                    error,
                };
                write_json(&mut stdout, &response).await?;
            }
        }
    }

    Ok(())
}

async fn write_json<T: Serialize>(stdout: &mut io::Stdout, value: &T) -> Result<()> {
    stdout
        .write_all(serde_json::to_string(value)?.as_bytes())
        .await?;
    stdout.write_all(b"\n").await?;
    Ok(())
}
