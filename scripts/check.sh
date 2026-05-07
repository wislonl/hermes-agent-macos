#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTOCOL_SCHEMA="$ROOT_DIR/packages/hermes-protocol/schemas/hermes-protocol.schema.json"

if [ -f "$PROTOCOL_SCHEMA" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 is required for protocol JSON syntax validation" >&2
    exit 1
  fi

  python3 - "$ROOT_DIR" <<'PY'
import json
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema_path = root / "packages/hermes-protocol/schemas/hermes-protocol.schema.json"
examples_dir = root / "packages/hermes-protocol/examples"


def load_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


schema = load_json(schema_path)
example_paths = sorted(examples_dir.glob("*.json")) if examples_dir.exists() else []
examples = [(path, load_json(path)) for path in example_paths]
print(f"Protocol JSON syntax valid: schema and {len(examples)} example(s)")

try:
    import jsonschema
except ImportError:
    print(
        "error: Python package jsonschema is required for protocol schema validation; "
        "install with python3 -m pip install jsonschema",
        file=sys.stderr,
    )
    raise SystemExit(1)

jsonschema.Draft202012Validator.check_schema(schema)
validator = jsonschema.Draft202012Validator(schema)

for path, payload in examples:
    errors = sorted(validator.iter_errors(payload), key=lambda error: list(error.path))
    if errors:
        location = "/".join(str(part) for part in errors[0].path) or "<root>"
        raise SystemExit(f"{path}: schema validation failed at {location}: {errors[0].message}")

file_write_example_path = examples_dir / "approval-required-file-write.event.json"
file_write_examples = [
    payload for path, payload in examples if path == file_write_example_path
]
if file_write_examples:
    operation = file_write_examples[0]["operation"]
    content_bytes = operation["contentPreview"].encode("utf-8")
    actual_byte_count = len(content_bytes)
    actual_sha256 = hashlib.sha256(content_bytes).hexdigest()
    if operation["byteCount"] != actual_byte_count:
        raise SystemExit(
            f"{file_write_example_path}: byteCount {operation['byteCount']} "
            f"does not match UTF-8 contentPreview length {actual_byte_count}"
        )
    if operation["contentSha256"] != actual_sha256:
        raise SystemExit(
            f"{file_write_example_path}: contentSha256 {operation['contentSha256']} "
            f"does not match contentPreview SHA-256 {actual_sha256}"
        )

error_response = {
    "jsonrpc": "2.0",
    "id": "req_error",
    "error": {
        "code": -32602,
        "message": "Invalid params"
    }
}
errors = list(validator.iter_errors(error_response))
if errors:
    raise SystemExit(f"JSON-RPC error response should validate: {errors[0].message}")

null_id_error_response = {
    "jsonrpc": "2.0",
    "id": None,
    "error": {
        "code": -32700,
        "message": "Parse error"
    }
}
errors = list(validator.iter_errors(null_id_error_response))
if errors:
    raise SystemExit(f"JSON-RPC null-id error response should validate: {errors[0].message}")

negative_cases = {
    "malformed run.create": {
        "jsonrpc": "2.0",
        "id": "req_bad_run",
        "method": "run.create",
        "params": {
            "sessionId": "session_123",
            "agentProfileId": "agent_hermes",
            "input": {
                "type": "text",
                "text": "Missing workspace."
            }
        }
    },
    "malformed approval.required": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "shell",
            "command": "ls -la"
        }
    },
    "shell approval without command": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "shell",
            "workingDirectory": "/Users/example/project",
            "risk": "executes-command"
        }
    },
    "file.write approval without path": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "file.write",
            "risk": "writes-files"
        }
    },
    "file.write approval missing audit metadata": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "file.write",
            "path": "/Users/example/project/README.md",
            "risk": "writes-files"
        }
    },
    "file.write approval with wrong risk": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "file.write",
            "path": "/Users/example/project/README.md",
            "mode": "overwrite",
            "contentPreview": "# Hermes Agent\n",
            "byteCount": 15,
            "contentSha256": "d28b70d0f453279afdd8a611d70dfd134fc4734507026b17c98102db0ac7df5d",
            "risk": "read-only"
        }
    },
    "file.write approval missing content hash": {
        "event": "approval.required",
        "runId": "run_123",
        "approvalId": "approval_123",
        "toolCallId": "tool_123",
        "operation": {
            "tool": "file.write",
            "path": "/Users/example/project/README.md",
            "mode": "overwrite",
            "contentPreview": "# Hermes Agent\n",
            "byteCount": 15,
            "risk": "writes-files"
        }
    },
    "failed tool.result without error": {
        "event": "tool.result",
        "runId": "run_123",
        "toolCallId": "tool_123",
        "status": "failed"
    },
    "completed tool.result with error": {
        "event": "tool.result",
        "runId": "run_123",
        "toolCallId": "tool_123",
        "status": "completed",
        "error": {
            "code": -32000,
            "message": "Unexpected error"
        }
    },
    "unsupported run.cancel": {
        "jsonrpc": "2.0",
        "id": "req_cancel",
        "method": "run.cancel",
        "params": {
            "runId": "run_123"
        }
    },
    "unexpected response result": {
        "jsonrpc": "2.0",
        "id": "req_unexpected",
        "result": {
            "unexpected": True
        }
    },
    "successful response with null id": {
        "jsonrpc": "2.0",
        "id": None,
        "result": {
            "protocolVersion": "0.1.0",
            "runtime": {
                "name": "hermes-runtime",
                "version": "0.1.0"
            },
            "capabilities": ["runs", "tools", "approvals"]
        }
    }
}

for name, payload in negative_cases.items():
    if not list(validator.iter_errors(payload)):
        raise SystemExit(f"negative protocol validation failed: {name} was accepted")

print(f"Protocol schema validation passed: {len(examples)} example(s), {len(negative_cases)} negative case(s)")
PY
fi

if [ -f "$ROOT_DIR/crates/hermes-runtime/Cargo.toml" ]; then
  cargo test --manifest-path "$ROOT_DIR/crates/hermes-runtime/Cargo.toml"
fi

if [ -f "$ROOT_DIR/apps/macos/Package.swift" ]; then
  swift test --package-path "$ROOT_DIR/apps/macos"
fi
