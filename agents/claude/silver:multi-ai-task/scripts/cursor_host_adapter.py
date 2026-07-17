#!/usr/bin/env python3
"""Cursor host adapter stub for multi-ai-task-v2 (not-live until host wiring lands)."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from typing import Any

ADAPTER_ID = "cursor-host-adapter-v1"
ADAPTER_VERSION = "1.0.0"
LIVE_STATUS = "not-live"


@dataclass
class LaunchRequest:
    idempotency_key: str
    run_id: str
    work_item_id: str
    logical_model_id: str
    attempt_id: str
    requested_model_id: str
    effective_model_id: str
    output_root: str
    deadline: str
    hard_token_ceiling: int
    phase_id: str | None = None


def launch(request: LaunchRequest) -> dict[str, Any]:
    """Return a not-live acknowledgement envelope (no host dispatch)."""
    return {
        "schema_id": ADAPTER_ID,
        "version": ADAPTER_VERSION,
        "live_status": LIVE_STATUS,
        "ok": False,
        "error_code": "CURSOR_HOST_ADAPTER_NOT_LIVE",
        "message": "Cursor host adapter is stubbed; live launch is not available in v1 scaffold",
        "launch": {
            "idempotency_key": request.idempotency_key,
            "run_id": request.run_id,
            "work_item_id": request.work_item_id,
            "phase_id": request.phase_id,
            "logical_model_id": request.logical_model_id,
            "attempt_id": request.attempt_id,
            "requested_model_id": request.requested_model_id,
            "effective_model_id": request.effective_model_id,
            "output_root": request.output_root,
            "deadline": request.deadline,
            "hard_token_ceiling": request.hard_token_ceiling,
        },
        "handles": {},
    }


def cancel(_attempt_id: str, _idempotency_key: str) -> dict[str, Any]:
    """Idempotent cancel stub — acknowledges without live child termination."""
    return {
        "schema_id": ADAPTER_ID,
        "version": ADAPTER_VERSION,
        "live_status": LIVE_STATUS,
        "ok": True,
        "cancellation_acknowledged": True,
        "child_liveness_verified": False,
    }


def cas_select_authoritative_attempt(
    current_generation: int,
    expected_generation: int,
    authoritative_attempt_id: str | None,
) -> dict[str, Any]:
    """Compare-and-swap stub for authoritative attempt selection."""
    if current_generation != expected_generation:
        return {
            "ok": False,
            "live_status": LIVE_STATUS,
            "error_code": "CAS_GENERATION_CONFLICT",
            "current_generation": current_generation,
            "expected_generation": expected_generation,
        }
    return {
        "ok": True,
        "live_status": LIVE_STATUS,
        "generation": current_generation + 1,
        "authoritative_attempt_id": authoritative_attempt_id,
    }


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Cursor host adapter stub (not-live)")
    sub = parser.add_subparsers(dest="command", required=True)

    launch_p = sub.add_parser("launch")
    launch_p.add_argument("--request-json", required=True)

    cancel_p = sub.add_parser("cancel")
    cancel_p.add_argument("--attempt-id", required=True)
    cancel_p.add_argument("--idempotency-key", required=True)

    cas_p = sub.add_parser("cas")
    cas_p.add_argument("--current-generation", type=int, required=True)
    cas_p.add_argument("--expected-generation", type=int, required=True)
    cas_p.add_argument("--authoritative-attempt-id", default="")

    args = parser.parse_args(argv)

    if args.command == "launch":
        payload = json.loads(args.request_json)
        req = LaunchRequest(**payload)
        print(json.dumps(launch(req), indent=2))
        return 0
    if args.command == "cancel":
        print(json.dumps(cancel(args.attempt_id, args.idempotency_key), indent=2))
        return 0
    if args.command == "cas":
        aid = args.authoritative_attempt_id or None
        print(json.dumps(cas_select_authoritative_attempt(args.current_generation, args.expected_generation, aid), indent=2))
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
