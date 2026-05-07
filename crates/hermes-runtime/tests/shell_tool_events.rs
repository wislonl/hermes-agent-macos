use hermes_runtime::runtime::{handle, HandlerOutput};
use serde_json::json;

#[test]
fn run_create_shell_prompt_requires_approval_without_completion() {
    let output = handle(
        "run.create",
        json!({
            "sessionId": "session_123",
            "agentProfileId": "agent_hermes",
            "input": {
                "type": "text",
                "text": "/shell pwd && ls"
            },
            "workspace": {
                "path": "/Users/example/project"
            }
        }),
    )
    .unwrap();

    let HandlerOutput::ResponseWithEvents { response, events } = output else {
        panic!("expected run.create to return events");
    };

    let run_id = response["runId"].as_str().unwrap();
    let events: Vec<_> = events
        .into_iter()
        .map(|event| serde_json::to_value(event).unwrap())
        .collect();

    assert_eq!(response["status"], "running");
    assert_eq!(events.len(), 3);
    assert_eq!(
        events[1],
        json!({
            "event": "tool.requested",
            "runId": run_id,
            "toolCallId": format!("tool_shell_preview_{}", run_id),
            "tool": "shell",
            "summary": "Preview shell command"
        })
    );
    assert_eq!(
        events[2],
        json!({
            "event": "approval.required",
            "runId": run_id,
            "approvalId": format!("approval_shell_preview_{}", run_id),
            "toolCallId": format!("tool_shell_preview_{}", run_id),
            "operation": {
                "tool": "shell",
                "command": "pwd && ls",
                "workingDirectory": ".",
                "risk": "executes-command"
            }
        })
    );
    assert!(!events.iter().any(|event| event["event"] == "tool.result"));
    assert!(!events.iter().any(|event| event["event"] == "run.completed"));
}

#[test]
fn run_create_non_shell_prompt_completes_without_approval() {
    let output = handle(
        "run.create",
        json!({
            "sessionId": "session_123",
            "agentProfileId": "agent_hermes",
            "input": {
                "type": "text",
                "text": "Summarize the project"
            },
            "workspace": {
                "path": "/Users/example/project"
            }
        }),
    )
    .unwrap();

    let HandlerOutput::ResponseWithEvents { events, .. } = output else {
        panic!("expected run.create to return events");
    };
    let events: Vec<_> = events
        .into_iter()
        .map(|event| serde_json::to_value(event).unwrap())
        .collect();

    assert!(events.iter().any(|event| event["event"] == "run.completed"));
    assert!(!events
        .iter()
        .any(|event| event["event"] == "approval.required"));
}
