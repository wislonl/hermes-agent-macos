# Contributing to Hermes Agent

Hermes Agent is early-stage. Contributions should preserve the core direction: native macOS experience, local-first data, explicit approval, and auditable tool execution.

## Development Setup

No buildable app or runtime exists in this repository yet. The first scaffolding PR must add exact setup commands for:

- Xcode and the macOS app.
- Rust toolchain and runtime tests.
- Protocol schema validation.

## Pull Request Expectations

- Keep changes focused.
- Include tests for runtime logic, protocol parsing, and approval behavior.
- Document new tools in the security model if they can affect local or remote state.
- Do not introduce new external services without explaining the privacy and security impact.

## Security-Sensitive Changes

Changes involving shell execution, file writes, credentials, logging, provider requests, or approval policy require extra care. PRs in these areas should explain:

- What new capability is added.
- What the risk is.
- Where user approval happens.
- How secrets are protected.
- What tests cover the behavior.
