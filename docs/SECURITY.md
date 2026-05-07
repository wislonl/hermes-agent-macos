# Security Model

Hermes Agent.app delegates all sensitive work — running shell commands, writing files, making network requests, accessing credentials — to the upstream `hermes` binary. The app's security responsibilities are narrow: render the agent's permission requests faithfully, and never bypass them.

## Trust Boundary

| Concern | Where it lives |
|---|---|
| Model output (untrusted text) | Rendered by the app, executed only via Hermes tools. |
| API keys, OAuth tokens | Owned by Hermes (`~/.hermes/auth.json`, `~/.hermes/.env`). The app does not read or store them. |
| Tool execution | Hermes runtime. The app does not exec shell commands, write files, or make HTTP requests on the user's behalf. |
| Approval policy | Hermes decides what requires approval. The app shows the resulting `session/request_permission` prompts. |

## Permission Prompts

When Hermes calls `session/request_permission`, the app:

1. Pauses any other interaction with the agent.
2. Shows a sheet with the title supplied by Hermes and one button per option.
3. Sends the chosen `optionId` back as the response.
4. If the user dismisses the sheet, responds with `outcome: "cancelled"` (treated by Hermes as a deny).

The app never auto-approves. There is no "always allow" toggle in the app — those policies live inside Hermes (`hermes hooks`, `hermes config`).

## Subprocess Hygiene

- The `hermes acp` child inherits the user's environment. The app does not inject secrets into its environment.
- stderr from `hermes acp` is drained but not surfaced in the UI yet. Future versions may route it to a diagnostics panel.
- On app exit the subprocess is terminated.

## Out of Scope (for now)

- Sandboxing the `hermes` subprocess. Hermes itself supports sandboxes (Docker, Daytona, Modal); configure those through `hermes`.
- Audit logging from the app. Hermes' own session log is the system of record.

## Reporting Vulnerabilities

Until a private channel is published, do not file exploit details on public issue trackers. Reach out to the maintainers directly.
