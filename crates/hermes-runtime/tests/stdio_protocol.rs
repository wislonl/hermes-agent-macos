use assert_cmd::Command;
use serde_json::{json, Value};

fn run_runtime(stdin: &str) -> Vec<Value> {
    let mut cmd = Command::cargo_bin("hermes-runtime").unwrap();
    let assert = cmd.write_stdin(stdin).assert().success();
    let stdout = String::from_utf8(assert.get_output().stdout.clone()).unwrap();

    stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect()
}

#[test]
fn handshake_returns_runtime_capabilities() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"req_1","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}}}"#,
    );

    assert_eq!(
        output,
        vec![json!({
            "jsonrpc": "2.0",
            "id": "req_1",
            "result": {
                "protocolVersion": "0.1.0",
                "runtime": {
                    "name": "hermes-runtime",
                    "version": "0.1.0"
                },
                "capabilities": ["runs", "tools", "approvals"]
            }
        })]
    );
}

#[test]
fn run_create_returns_running_response_and_mock_events() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"req_2","method":"run.create","params":{"sessionId":"session_123","agentProfileId":"agent_hermes","input":{"type":"text","text":"Summarize this repository."},"workspace":{"path":"/Users/example/project"}}}"#,
    );

    assert_eq!(output.len(), 3);
    assert_eq!(output[0]["jsonrpc"], "2.0");
    assert_eq!(output[0]["id"], "req_2");
    assert_eq!(output[0]["result"]["status"], "running");

    let run_id = output[0]["result"]["runId"].as_str().unwrap();
    assert!(run_id.starts_with("run_"));

    assert_eq!(
        output[1],
        json!({
            "event": "message.delta",
            "runId": run_id,
            "delta": "Hermes received: Summarize this repository."
        })
    );
    assert_eq!(
        output[2],
        json!({
            "event": "run.completed",
            "runId": run_id,
            "status": "completed"
        })
    );
}

#[test]
fn malformed_json_returns_parse_error_and_continues() {
    let output = run_runtime(
        r#"not json
{"jsonrpc":"2.0","id":"req_after_parse_error","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}}}"#,
    );

    assert_eq!(output.len(), 2);
    assert_eq!(
        output[0],
        json!({
            "jsonrpc": "2.0",
            "id": null,
            "error": {
                "code": -32700,
                "message": "Parse error"
            }
        })
    );
    assert_eq!(output[1]["id"], "req_after_parse_error");
    assert_eq!(output[1]["result"]["runtime"]["name"], "hermes-runtime");
}

#[test]
fn wrong_json_rpc_version_returns_invalid_request() {
    let output = run_runtime(
        r#"{"jsonrpc":"1.0","id":"bad_version","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}}}"#,
    );

    assert_eq!(
        output,
        vec![json!({
            "jsonrpc": "2.0",
            "id": "bad_version",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        })]
    );
}

#[test]
fn invalid_envelope_shape_returns_invalid_request() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":null,"method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}}}
{"jsonrpc":"2.0","id":"bad_params","method":"runtime.handshake","params":[]}"#,
    );

    assert_eq!(
        output,
        vec![
            json!({
                "jsonrpc": "2.0",
                "id": null,
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            }),
            json!({
                "jsonrpc": "2.0",
                "id": "bad_params",
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            })
        ]
    );
}

#[test]
fn unknown_method_returns_method_not_found() {
    let output = run_runtime(r#"{"jsonrpc":"2.0","id":42,"method":"runtime.unknown","params":{}}"#);

    assert_eq!(
        output,
        vec![json!({
            "jsonrpc": "2.0",
            "id": 42,
            "error": {
                "code": -32601,
                "message": "Unknown method: runtime.unknown"
            }
        })]
    );
}

#[test]
fn invalid_method_params_return_invalid_request() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"bad_handshake","method":"runtime.handshake","params":{}}
{"jsonrpc":"2.0","id":"bad_run","method":"run.create","params":{"sessionId":"session_123","agentProfileId":"agent_hermes","input":{"type":"text","text":"Summarize this repository."},"workspace":{}}}"#,
    );

    assert_eq!(output.len(), 2);
    assert_eq!(
        output[0],
        json!({
            "jsonrpc": "2.0",
            "id": "bad_handshake",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        })
    );
    assert_eq!(
        output[1],
        json!({
            "jsonrpc": "2.0",
            "id": "bad_run",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        })
    );
}

#[test]
fn handshake_without_client_returns_invalid_request() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"missing_client","method":"runtime.handshake","params":{"protocolVersion":"0.1.0"}}"#,
    );

    assert_eq!(
        output,
        vec![json!({
            "jsonrpc": "2.0",
            "id": "missing_client",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        })]
    );
}
