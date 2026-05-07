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
                let response = JsonRpcResponse {
                    jsonrpc: "2.0",
                    id,
                    result,
                };
                stdout
                    .write_all(serde_json::to_string(&response)?.as_bytes())
                    .await?;
                stdout.write_all(b"\n").await?;
            }
            Ok(HandlerOutput::ResponseWithEvents { response, events }) => {
                let response = JsonRpcResponse {
                    jsonrpc: "2.0",
                    id,
                    result: response,
                };
                stdout
                    .write_all(serde_json::to_string(&response)?.as_bytes())
                    .await?;
                stdout.write_all(b"\n").await?;
                for event in events {
                    stdout
                        .write_all(serde_json::to_string(&event)?.as_bytes())
                        .await?;
                    stdout.write_all(b"\n").await?;
                }
            }
            Err(error) => {
                let response = JsonRpcErrorResponse {
                    jsonrpc: "2.0",
                    id,
                    error,
                };
                stdout
                    .write_all(serde_json::to_string(&response)?.as_bytes())
                    .await?;
                stdout.write_all(b"\n").await?;
            }
        }
    }

    Ok(())
}
