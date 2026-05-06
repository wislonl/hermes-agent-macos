#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT_DIR/crates/hermes-runtime/Cargo.toml" ]; then
  cargo test --manifest-path "$ROOT_DIR/crates/hermes-runtime/Cargo.toml"
fi

if [ -f "$ROOT_DIR/apps/macos/Package.swift" ]; then
  swift test --package-path "$ROOT_DIR/apps/macos"
fi
