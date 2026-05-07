# Hermes Agent Security Model

## Security Goals

Hermes Agent should make local agent work inspectable and user-controlled. The app must treat model output as untrusted and must require approval before sensitive local actions.

## Secret Handling

- Store API keys and provider credentials in macOS Keychain.
- Never print secrets to logs.
- Never include secrets in crash reports, run logs, prompt exports, or issue templates.
- Redact credential-like values before rendering runtime diagnostics.
- Provider adapters must receive secrets through explicit configuration paths and must never include secret values in runtime events. Provider request logs must redact authorization headers and API keys.

## Tool Approval Policy

The runtime must request approval before:

- Executing shell commands.
- Writing, deleting, moving, or overwriting files.
- Sending network requests with side effects.
- Accessing credentials.
- Launching external apps.

Approval prompts must show:

- The tool name.
- The exact command or operation.
- The working directory or target path.
- The expected side effect.
- Whether the action is one-time or part of a repeated run.

The approval decision must apply only to the exact requested action. Broad approval modes can be added later, but they must be explicit, time-bounded, and visible in the UI.

## File Access

Read access should be scoped to the selected workspace when possible. Write access should default to approval-required. The app should make the active workspace visible so users know what the agent can inspect.

## Shell Execution

Shell execution is high risk. Commands should be displayed exactly before execution. The runtime should avoid shell interpolation when a structured process API is available.

Destructive commands require especially clear approval text. Examples include:

- Recursive deletion.
- Force pushes.
- Database drops.
- Permission changes.
- Credential or keychain commands.

## Network Access

Provider calls are expected. Other network tools should be visible and categorized. Requests that mutate remote state require approval.

## Logging

Runtime logs should be structured and redacted. Logs should include enough information to debug protocol and tool behavior without exposing private prompts, credentials, or full file contents unless the user explicitly exports them.

## Vulnerability Reporting

Before public release, the project should define a private vulnerability reporting channel in this document. Until then, security issues should not be reported with secrets or exploit details in public GitHub issues.
