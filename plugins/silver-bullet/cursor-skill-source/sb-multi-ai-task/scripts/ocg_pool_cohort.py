#!/usr/bin/env python3
"""Fan out OCG pool profiles inside a single agent-opencode delegation (pool-v1)."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from live_dispatch import (  # noqa: E402
    OCG_MODEL_MAP,
    build_worker_prompt,
    extract_json_payload,
    ocg_model_for,
    sanitize_phase_context,
)

OPENCODE_BIN = os.environ.get("SB_OPENCODE_BIN", os.path.expanduser("~/.opencode/bin/opencode"))
DEFAULT_PER_MODEL_TIMEOUT = int(os.environ.get("SB_OCG_PER_MODEL_TIMEOUT_SEC", "240"))


def _log(progress_path: Path | None, message: str) -> None:
    line = f"[{datetime.now(timezone.utc).isoformat()}] {message}"
    print(line, file=sys.stderr, flush=True)
    if progress_path:
        with progress_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")


def load_request(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def run_profile(
    *,
    logical_model_id: str,
    prompt: str,
    work_dir: Path,
    timeout_sec: int,
    progress_path: Path | None,
) -> dict[str, Any]:
    model = ocg_model_for(logical_model_id)
    cmd = [OPENCODE_BIN, "run", "--dir", str(work_dir), "-m", model, "--auto", prompt]
    _log(progress_path, f"START {logical_model_id} model={model} timeout={timeout_sec}s")
    started = time.monotonic()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_sec, cwd=str(work_dir))
        elapsed = int(time.monotonic() - started)
        raw = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        status = "completed" if proc.returncode == 0 else "failed"
        payload = extract_json_payload(raw) if status == "completed" else {}
        if status == "completed" and not payload:
            status = "failed"
        out_path = work_dir / f"{logical_model_id}-{model.replace('/', '-')}.raw.txt"
        out_path.write_text(raw[:50000], encoding="utf-8")
        _log(progress_path, f"DONE {logical_model_id} status={status} elapsed={elapsed}s exit={proc.returncode}")
        return {
            "logical_model_id": logical_model_id,
            "backend": "ocg",
            "status": status,
            "payload": payload,
            "raw_output_path": str(out_path.name),
            "error": None if status == "completed" else f"exit {proc.returncode}",
            "effective_model_id": model,
            "elapsed_sec": elapsed,
        }
    except subprocess.TimeoutExpired:
        elapsed = int(time.monotonic() - started)
        _log(progress_path, f"TIMEOUT {logical_model_id} after {elapsed}s")
        return {
            "logical_model_id": logical_model_id,
            "backend": "ocg",
            "status": "partial",
            "payload": {},
            "raw_output_path": "",
            "error": "timeout",
            "effective_model_id": model,
            "elapsed_sec": elapsed,
        }
    except FileNotFoundError:
        _log(progress_path, f"FAIL {logical_model_id} opencode CLI not found")
        return {
            "logical_model_id": logical_model_id,
            "backend": "ocg",
            "status": "failed",
            "payload": {},
            "raw_output_path": "",
            "error": "opencode CLI not found",
            "effective_model_id": model,
            "elapsed_sec": 0,
        }


def run_cohort(request: dict[str, Any]) -> dict[str, Any]:
    phase_id = str(request["phase_id"])
    query = str(request["query"])
    context = sanitize_phase_context(str(request.get("context", "")))
    logical_ids = list(request["logical_model_ids"])
    work_dir = Path(request["work_dir"]).resolve()
    per_model_timeout = min(int(request.get("timeout_sec", DEFAULT_PER_MODEL_TIMEOUT)), DEFAULT_PER_MODEL_TIMEOUT)
    progress_path = work_dir / f"ocg-cohort-progress-{request.get('attempt_id', 'run')}.log"
    work_dir.mkdir(parents=True, exist_ok=True)

    _log(progress_path, f"COHORT_START phase={phase_id} models={len(logical_ids)} per_model_timeout={per_model_timeout}s")

    contributions: list[dict[str, Any]] = []
    for logical_model_id in logical_ids:
        prompt = build_worker_prompt(
            phase_id=phase_id,
            query=query,
            logical_model_id=logical_model_id,
            context=context,
            backend="ocg",
        )
        contributions.append(
            run_profile(
                logical_model_id=logical_model_id,
                prompt=prompt,
                work_dir=work_dir,
                timeout_sec=per_model_timeout,
                progress_path=progress_path,
            )
        )

    ok = all(c["status"] in {"completed", "partial"} and c.get("payload") for c in contributions)
    _log(progress_path, f"COHORT_END ok={ok} completed={sum(1 for c in contributions if c['status']=='completed')}/{len(contributions)}")
    return {
        "schema_id": "ocg-pool-cohort-result-v1",
        "version": "1.0.0",
        "ok": ok,
        "phase_id": phase_id,
        "pool": request.get("pool", "lite"),
        "contributions": contributions,
        "progress_log": str(progress_path.name),
        "model_map_keys": sorted(OCG_MODEL_MAP.keys()),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="OCG pool cohort runner (single agent-opencode delegation)")
    parser.add_argument("--request", required=True, help="JSON request file path")
    parser.add_argument("--output", help="Optional output JSON path (default stdout)")
    args = parser.parse_args(argv)

    request_path = Path(args.request)
    result = run_cohort(load_request(request_path))
    body = json.dumps(result, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(body, encoding="utf-8")
    else:
        print(body, end="")
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
