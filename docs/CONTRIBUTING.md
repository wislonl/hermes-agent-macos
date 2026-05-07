# Contributing to Hermes Agent

Hermes Agent is early-stage. Contributions should preserve the core direction: native macOS experience, local-first data, explicit approval, and auditable tool execution.

## Development Setup

Install the macOS and Rust toolchains:

- Xcode 15 or newer for Swift Package Manager and SwiftUI.
- Rust stable for the local runtime.
- Python 3 with `jsonschema` for protocol schema validation.

Run all available local checks:

```bash
./scripts/check.sh
```

Protocol schema validation requires Python and `jsonschema`:

```bash
python3 -m pip install jsonschema
```

Run component tests directly:

```bash
cargo test --manifest-path crates/hermes-runtime/Cargo.toml
swift test --package-path apps/macos
```

Run the macOS app locally:

```bash
swift run --package-path apps/macos HermesAgent
```

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
