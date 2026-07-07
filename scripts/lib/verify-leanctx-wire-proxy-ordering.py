#!/usr/bin/env python3
"""Validate Codex wire-proxy evidence JSON preserves message ordering (conflict #13).

Schema: sb/leanctx-wire-proxy-ordering/v1

Expected top-level shape::

    {
      "schema": "sb/leanctx-wire-proxy-ordering/v1",
      "host": "codex",
      "messages": [
        {"index": 0, "role": "system", "id": "msg-0"},
        {"index": 1, "role": "user", "id": "msg-1"}
      ]
    }

Rules enforced:
  - schema and messages are required
  - messages is a non-empty array
  - index fields are contiguous 0..n-1 (no gaps, no reorder)
  - role is one of system|user|assistant|tool|developer
  - if a system message exists it must be first
  - id values, when present, must be unique
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

SCHEMA_ID = "sb/leanctx-wire-proxy-ordering/v1"
VALID_ROLES = frozenset({"system", "user", "assistant", "tool", "developer"})


def _load_payload(path: Path | None) -> dict[str, Any]:
    if path is None or str(path) == "-":
        raw = sys.stdin.read()
    else:
        raw = path.read_text(encoding="utf-8")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("root must be a JSON object")
    return data


def validate_wire_proxy_ordering(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    schema = data.get("schema")
    if schema != SCHEMA_ID:
        errors.append(f"schema must be {SCHEMA_ID!r}, got {schema!r}")

    messages = data.get("messages")
    if not isinstance(messages, list):
        errors.append("messages must be an array")
        return errors
    if not messages:
        errors.append("messages must be non-empty")
        return errors

    seen_indices: set[int] = set()
    seen_ids: set[str] = set()
    roles: list[str] = []

    for pos, entry in enumerate(messages):
        if not isinstance(entry, dict):
            errors.append(f"messages[{pos}] must be an object")
            continue

        idx = entry.get("index")
        if not isinstance(idx, int):
            errors.append(f"messages[{pos}].index must be an integer")
            continue
        if idx != pos:
            errors.append(
                f"messages[{pos}].index={idx} does not match array position {pos} "
                "(wire proxy must preserve stream order)"
            )
        if idx in seen_indices:
            errors.append(f"duplicate message index {idx}")
        seen_indices.add(idx)

        role = entry.get("role")
        if not isinstance(role, str) or role not in VALID_ROLES:
            errors.append(
                f"messages[{pos}].role must be one of {sorted(VALID_ROLES)}, got {role!r}"
            )
        else:
            roles.append(role)

        msg_id = entry.get("id")
        if msg_id is not None:
            if not isinstance(msg_id, str) or not msg_id.strip():
                errors.append(f"messages[{pos}].id must be a non-empty string when set")
            elif msg_id in seen_ids:
                errors.append(f"duplicate message id {msg_id!r}")
            else:
                seen_ids.add(msg_id)

    expected = set(range(len(messages)))
    if seen_indices != expected:
        missing = sorted(expected - seen_indices)
        extra = sorted(seen_indices - expected)
        if missing:
            errors.append(f"missing message indices: {missing}")
        if extra:
            errors.append(f"unexpected message indices: {extra}")

    if roles and "system" in roles and roles[0] != "system":
        errors.append("system message must be first when present (prefix-cache contract)")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate LeanCTX Codex wire-proxy message ordering evidence"
    )
    parser.add_argument(
        "evidence",
        nargs="?",
        default="-",
        help="Evidence JSON file (default: stdin)",
    )
    parser.add_argument(
        "--generate-fixture",
        action="store_true",
        help="Print a minimal valid fixture to stdout and exit 0",
    )
    args = parser.parse_args()

    if args.generate_fixture:
        fixture = {
            "schema": SCHEMA_ID,
            "host": "codex",
            "messages": [
                {"index": 0, "role": "system", "id": "sys-1"},
                {"index": 1, "role": "user", "id": "usr-1"},
                {"index": 2, "role": "assistant", "id": "asst-1"},
            ],
        }
        print(json.dumps(fixture, indent=2))
        return 0

    try:
        path = None if args.evidence == "-" else Path(args.evidence)
        payload = _load_payload(path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    errors = validate_wire_proxy_ordering(payload)
    if errors:
        for err in errors:
            print(f"INVALID: {err}", file=sys.stderr)
        return 1

    print(json.dumps({"status": "ok", "schema": SCHEMA_ID, "message_count": len(payload["messages"])}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
