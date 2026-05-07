# Release Process

Hermes Agent does not have a signed app release yet.

For early local testing:

```bash
swift run --package-path apps/macos HermesAgent
```

Before the first public release:

- Add a signed macOS app bundle workflow.
- Produce a `.zip` or `.dmg` artifact.
- Verify Keychain access in the packaged app.
- Verify runtime child-process startup from the app bundle.
- Add screenshots and a short demo GIF to the README.
