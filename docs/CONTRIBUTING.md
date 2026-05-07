# Contributing

Hermes Agent.app is a thin native shell over the upstream Hermes Agent. Contributions should preserve that direction: ship a great Mac UX, and let Hermes own the agent behaviour.

## Development Setup

Requirements:

- Xcode 15 or newer for Swift Package Manager and SwiftUI.
- A working `hermes` install on `PATH` (see the README).

Run the app from source:

```bash
swift run --package-path apps/macos HermesAgent
```

Build a bundled `.app`:

```bash
./scripts/run-macos-app.sh
```

Run the project checks (currently a no-op until tests come back):

```bash
./scripts/check.sh
```

## Pull Request Expectations

- Keep changes focused on the app surface (UI, ACP wiring, lifecycle).
- New behaviour that belongs in the agent — providers, tools, memory, skills — should be proposed upstream at <https://github.com/NousResearch/hermes-agent>, not added here.
- When you add a new ACP method or session update kind, document it in `docs/ARCHITECTURE.md`.

## Probing the ACP Wire

The fastest way to verify a protocol assumption is to talk to `hermes acp` directly. The Python snippet in `docs/ARCHITECTURE.md` history (or any small subprocess harness with bidirectional pipes) works well; pure shell pipes do not, because Hermes' ACP transport requires real pipe file descriptors on stdout.
