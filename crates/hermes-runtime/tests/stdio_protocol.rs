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

#[test]
fn run_create_returns_running_response_and_mock_events() {
    let mut cmd = Command::cargo_bin("hermes-runtime").unwrap();
    cmd.write_stdin(
        r#"{"jsonrpc":"2.0","id":"req_2","method":"run.create","params":{"sessionId":"session_123","agentProfileId":"agent_hermes","input":{"type":"text","text":"Summarize this repository."},"workspace":{"path":"/Users/example/project"}}}"#,
    )
    .assert()
    .success()
    .stdout(contains("\"result\":{\"runId\":\"run_"))
    .stdout(contains("\"status\":\"running\""))
    .stdout(contains("\"event\":\"message.delta\""))
    .stdout(contains("\"delta\":\"Hermes received: Summarize this repository.\""))
    .stdout(contains("\"event\":\"run.completed\""))
    .stdout(contains("\"status\":\"completed\""));
}
