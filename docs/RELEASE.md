# Release

Hermes Agent.app does not have a signed release yet.

For local use:

```bash
swift run --package-path apps/macos HermesAgent
```

For a bundled `.app`:

```bash
./scripts/run-macos-app.sh
```

Before the first public release:

- Sign and notarise the `.app` bundle.
- Decide whether to ship `hermes` itself with the app, or keep requiring an existing install. Bundling needs a Python runtime story.
- Add screenshots and a short demo GIF to the README.
- Document the minimum supported Hermes version.
