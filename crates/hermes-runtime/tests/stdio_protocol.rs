use assert_cmd::Command;
use serde_json::{json, Value};

fn run_runtime_bytes(stdin: impl Into<Vec<u8>>) -> Vec<Value> {
    let mut cmd = Command::cargo_bin("hermes-runtime").unwrap();
    let assert = cmd.write_stdin(stdin).assert().success();
    let stdout = String::from_utf8(assert.get_output().stdout.clone()).unwrap();

    stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect()
}

fn run_runtime(stdin: &str) -> Vec<Value> {
    run_runtime_bytes(stdin)
}

fn run_create_request(id: &str, prompt: &str) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "method": "run.create",
        "params": {
            "sessionId": "session_123",
            "agentProfileId": "agent_hermes",
            "input": {
                "type": "text",
                "text": prompt
            },
            "workspace": {
                "path": "/Users/example/project"
            }
        }
    })
}

fn run_create_prompt(id: &str, prompt: &str) -> Vec<Value> {
    run_runtime(&run_create_request(id, prompt).to_string())
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
fn run_create_with_shell_prompt_emits_tool_approval_events_in_order() {
    let output = run_create_prompt("req_shell", "/shell pwd");

    assert_eq!(output.len(), 4);
    assert_eq!(output[0]["jsonrpc"], "2.0");
    assert_eq!(output[0]["id"], "req_shell");
    assert_eq!(output[0]["result"]["status"], "running");

    let run_id = output[0]["result"]["runId"].as_str().unwrap();
    assert!(run_id.starts_with("run_"));
    let tool_call_id = format!("tool_shell_preview_{}", run_id);
    let approval_id = format!("approval_shell_preview_{}", run_id);

    assert_eq!(
        output[1],
        json!({
            "event": "message.delta",
            "runId": run_id,
            "delta": "Hermes received: /shell pwd"
        })
    );
    assert_eq!(
        output[2],
        json!({
            "event": "tool.requested",
            "runId": run_id,
            "toolCallId": tool_call_id,
            "tool": "shell",
            "summary": "Preview shell command"
        })
    );
    assert_eq!(
        output[3],
        json!({
            "event": "approval.required",
            "runId": run_id,
            "approvalId": approval_id,
            "toolCallId": tool_call_id,
            "operation": {
                "tool": "shell",
                "command": "pwd && ls",
                "workingDirectory": ".",
                "risk": "executes-command"
            }
        })
    );

    let operation = output[3]["operation"].as_object().unwrap();
    assert!(!operation.contains_key("path"));

    assert!(!output
        .iter()
        .any(|message| message["event"] == "run.completed"));
}

#[test]
fn run_create_with_exact_shell_command_requests_approval() {
    let output = run_create_prompt("req_exact_shell", "/shell");

    assert_eq!(output.len(), 4);
    assert_eq!(output[2]["event"], "tool.requested");
    assert_eq!(output[3]["event"], "approval.required");
}

#[test]
fn run_create_with_leading_whitespace_shell_command_requests_approval() {
    let output = run_create_prompt("req_spaced_shell", "   /shell pwd");

    assert_eq!(output.len(), 4);
    assert_eq!(output[2]["event"], "tool.requested");
    assert_eq!(output[3]["event"], "approval.required");
}

#[test]
fn run_create_with_tab_after_shell_command_requests_approval() {
    let output = run_create_prompt("req_tab_shell", "/shell\tpwd");

    assert_eq!(output.len(), 4);
    assert_eq!(output[2]["event"], "tool.requested");
    assert_eq!(output[3]["event"], "approval.required");
    assert!(!output
        .iter()
        .any(|message| message["event"] == "run.completed"));
}

#[test]
fn run_create_with_newline_after_shell_command_requests_approval() {
    let output = run_create_prompt("req_newline_shell", "/shell\npwd");

    assert_eq!(output.len(), 4);
    assert_eq!(output[2]["event"], "tool.requested");
    assert_eq!(output[3]["event"], "approval.required");
    assert!(!output
        .iter()
        .any(|message| message["event"] == "run.completed"));
}

#[test]
fn run_create_with_shell_mentioned_later_does_not_request_approval() {
    let output = run_create_prompt("req_shell_text", "Explain why /shell needs approval.");

    assert_eq!(output.len(), 3);
    assert_eq!(output[0]["jsonrpc"], "2.0");
    assert_eq!(output[0]["id"], "req_shell_text");
    assert_eq!(output[0]["result"]["status"], "running");

    let run_id = output[0]["result"]["runId"].as_str().unwrap();
    assert!(run_id.starts_with("run_"));

    assert_eq!(
        output[1],
        json!({
            "event": "message.delta",
            "runId": run_id,
            "delta": "Hermes received: Explain why /shell needs approval."
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
    assert!(!output
        .iter()
        .any(|message| message["event"] == "approval.required"));
}

#[test]
fn run_create_with_shellfish_prefix_does_not_request_approval() {
    let output = run_create_prompt("req_shellfish", "/shellfish");

    assert_eq!(output.len(), 3);
    assert_eq!(output[2]["event"], "run.completed");
    assert!(!output
        .iter()
        .any(|message| message["event"] == "approval.required"));
}

#[test]
fn run_create_with_shellscript_prefix_does_not_request_approval() {
    let output = run_create_prompt("req_shellscript", "/shellscript");

    assert_eq!(output.len(), 3);
    assert_eq!(output[2]["event"], "run.completed");
    assert!(!output
        .iter()
        .any(|message| message["event"] == "approval.required"));
}

#[test]
fn two_shell_requests_in_one_stdio_session_use_per_run_approval_and_tool_call_ids() {
    let first_request = run_create_request("req_shell_first", "/shell pwd");
    let second_request = run_create_request("req_shell_second", "/shell pwd");
    let input = format!("{}\n{}", first_request, second_request);
    let output = run_runtime(&input);

    assert_eq!(output.len(), 8);

    let first_run_id = output[0]["result"]["runId"].as_str().unwrap();
    let second_run_id = output[4]["result"]["runId"].as_str().unwrap();
    assert_ne!(first_run_id, second_run_id);

    let first_tool_call_id = output[2]["toolCallId"].as_str().unwrap();
    let first_approval_tool_call_id = output[3]["toolCallId"].as_str().unwrap();
    let first_approval_id = output[3]["approvalId"].as_str().unwrap();
    let second_tool_call_id = output[6]["toolCallId"].as_str().unwrap();
    let second_approval_tool_call_id = output[7]["toolCallId"].as_str().unwrap();
    let second_approval_id = output[7]["approvalId"].as_str().unwrap();

    assert_eq!(first_tool_call_id, first_approval_tool_call_id);
    assert_eq!(second_tool_call_id, second_approval_tool_call_id);
    assert_ne!(first_tool_call_id, second_tool_call_id);
    assert_ne!(first_approval_id, second_approval_id);
    assert_eq!(
        first_tool_call_id,
        format!("tool_shell_preview_{}", first_run_id)
    );
    assert_eq!(
        first_approval_id,
        format!("approval_shell_preview_{}", first_run_id)
    );
    assert_eq!(
        second_tool_call_id,
        format!("tool_shell_preview_{}", second_run_id)
    );
    assert_eq!(
        second_approval_id,
        format!("approval_shell_preview_{}", second_run_id)
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
fn invalid_utf8_returns_parse_error_and_continues() {
    let mut stdin = vec![0xff, b'\n'];
    stdin.extend_from_slice(
        br#"{"jsonrpc":"2.0","id":"req_after_utf8_error","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}}}"#,
    );

    let output = run_runtime_bytes(stdin);

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
    assert_eq!(output[1]["id"], "req_after_utf8_error");
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
fn extra_top_level_request_fields_return_invalid_request() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"extra_top","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"}},"extra":true}"#,
    );

    assert_eq!(
        output,
        vec![json!({
            "jsonrpc": "2.0",
            "id": "extra_top",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        })]
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
fn handshake_rejects_extra_params() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"extra_handshake_param","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0"},"extra":true}}
{"jsonrpc":"2.0","id":"extra_handshake_client_param","method":"runtime.handshake","params":{"protocolVersion":"0.1.0","client":{"name":"Hermes.app","version":"0.1.0","extra":true}}}"#,
    );

    assert_eq!(
        output,
        vec![
            json!({
                "jsonrpc": "2.0",
                "id": "extra_handshake_param",
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            }),
            json!({
                "jsonrpc": "2.0",
                "id": "extra_handshake_client_param",
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            })
        ]
    );
}

#[test]
fn run_create_rejects_extra_nested_params() {
    let output = run_runtime(
        r#"{"jsonrpc":"2.0","id":"extra_run_input_param","method":"run.create","params":{"sessionId":"session_123","agentProfileId":"agent_hermes","input":{"type":"text","text":"Summarize this repository.","extra":true},"workspace":{"path":"/Users/example/project"}}}
{"jsonrpc":"2.0","id":"extra_run_workspace_param","method":"run.create","params":{"sessionId":"session_123","agentProfileId":"agent_hermes","input":{"type":"text","text":"Summarize this repository."},"workspace":{"path":"/Users/example/project","extra":true}}}"#,
    );

    assert_eq!(
        output,
        vec![
            json!({
                "jsonrpc": "2.0",
                "id": "extra_run_input_param",
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            }),
            json!({
                "jsonrpc": "2.0",
                "id": "extra_run_workspace_param",
                "error": {
                    "code": -32600,
                    "message": "Invalid request"
                }
            })
        ]
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
