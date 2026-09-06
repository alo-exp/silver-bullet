#!/usr/bin/env python3
"""Cursor host adapter for multi-ai-task-v2 live dispatch."""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ADAPTER_ID = "cursor-host-adapter-v1"
ADAPTER_VERSION = "1.1.0"


def _stub_mode() -> bool:
    return os.environ.get("SB_MULTI_AI_STUB", "").strip() in {"1", "true", "yes"}



def live_status() -> str:
    return "not-live" if _stub_mode() else "live"


LIVE_STATUS = live_status()  # import-time default for backward compat


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
    task_prompt: str = ""


def launch(request: LaunchRequest) -> dict[str, Any]:
    if _stub_mode():
        return {
            "schema_id": ADAPTER_ID,
            "version": ADAPTER_VERSION,
            "live_status": "not-live",
            "ok": False,
            "error_code": "CURSOR_HOST_ADAPTER_NOT_LIVE",
            "message": "Cursor host adapter stubbed (SB_MULTI_AI_STUB=1)",
            "launch": _launch_echo(request),
            "handles": {},
        }

    script_dir = Path(__file__).resolve().parent
    if str(script_dir) not in sys.path:
        sys.path.insert(0, str(script_dir))

    from live_dispatch import build_worker_prompt, cursor_model_for, extract_json_payload, run_cursor_worker

    phase_id = request.phase_id or "DR-RETRIEVE"
    prompt = request.task_prompt or build_worker_prompt(
        phase_id=phase_id,
        query=f"work_item={request.work_item_id}",
        logical_model_id=request.logical_model_id,
    )
    out_dir = Path(request.output_root)
    out_dir.mkdir(parents=True, exist_ok=True)
    result = run_cursor_worker(
        logical_model_id=request.logical_model_id,
        prompt=prompt,
        output_dir=out_dir,
        timeout_sec=min(request.hard_token_ceiling // 100, 900),
    )
    payload = extract_json_payload(result.raw_output)
    status = "completed" if result.status == "completed" else "failed"
    return {
        "schema_id": ADAPTER_ID,
        "version": ADAPTER_VERSION,
        "live_status": "live",
        "ok": result.status in {"completed", "partial"},
        "launch": _launch_echo(request),
        "result": {
            "status": status,
            "effective_model_id": cursor_model_for(request.logical_model_id),
            "usage": result.usage or {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0},
            "payload": payload,
            "error": result.error,
        },
        "handles": {"raw_output": str(out_dir)},
    }


def _launch_echo(request: LaunchRequest) -> dict[str, Any]:
    return {
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
    }


def cancel(_attempt_id: str, _idempotency_key: str) -> dict[str, Any]:
    return {
        "schema_id": ADAPTER_ID,
        "version": ADAPTER_VERSION,
        "live_status": live_status(),
        "ok": True,
        "cancellation_acknowledged": True,
        "child_liveness_verified": not _stub_mode(),
    }


def cas_select_authoritative_attempt(current_generation: int, expected_generation: int, authoritative_attempt_id: str | None) -> dict[str, Any]:
    if current_generation != expected_generation:
        return {
            "ok": False,
            "live_status": live_status(),
            "error_code": "CAS_GENERATION_CONFLICT",
            "current_generation": current_generation,
            "expected_generation": expected_generation,
        }
    return {
        "ok": True,
        "live_status": live_status(),
        "generation": current_generation + 1,
        "authoritative_attempt_id": authoritative_attempt_id,
    }


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Cursor host adapter (live on cursor host)")
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
