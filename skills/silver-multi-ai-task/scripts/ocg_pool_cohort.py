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
    _merged_output,
    _run_cli,
    _worker_sandbox,
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


def _argv_safe(prompt: str) -> str:
    """A prompt that starts with '-' could be parsed as an option; a leading newline prevents it."""
    return "\n" + prompt if prompt.startswith("-") else prompt


def run_profile(
    *,
    logical_model_id: str,
    prompt: str,
    work_dir: Path,
    timeout_sec: int,
    progress_path: Path | None,
) -> dict[str, Any]:
    """Run one OCG profile least-privileged: no --auto, in a fresh empty sandbox directory."""
    model = ocg_model_for(logical_model_id)
    _log(progress_path, f"START {logical_model_id} model={model} timeout={timeout_sec}s")
    started = time.monotonic()
    base = {"logical_model_id": logical_model_id, "backend": "ocg", "effective_model_id": model}
    try:
        with _worker_sandbox("ocg") as sandbox:
            cmd = [OPENCODE_BIN, "run", "--dir", str(sandbox), "-m", model, _argv_safe(prompt)]
            proc = _run_cli(cmd, timeout=timeout_sec, cwd=str(sandbox))
    except subprocess.TimeoutExpired:
        elapsed = int(time.monotonic() - started)
        _log(progress_path, f"TIMEOUT {logical_model_id} after {elapsed}s")
        return {**base, "status": "partial", "payload": {}, "raw_output_path": "", "error": "timeout", "elapsed_sec": elapsed}
    except OSError as exc:
        error = "opencode CLI not found" if isinstance(exc, FileNotFoundError) else f"opencode launch failed: {exc}"
        _log(progress_path, f"FAIL {logical_model_id} {error}")
        return {**base, "status": "failed", "payload": {}, "raw_output_path": "", "error": error, "elapsed_sec": 0}
    elapsed = int(time.monotonic() - started)
    raw = _merged_output(proc)
    status = "completed" if proc.returncode == 0 else "failed"
    payload = extract_json_payload(raw) if status == "completed" else {}
    if status == "completed" and not payload:
        status = "failed"
    out_path = work_dir / f"{logical_model_id}-{model.replace('/', '-')}.raw.txt"
    out_path.write_text(raw[:50000], encoding="utf-8")
    _log(progress_path, f"DONE {logical_model_id} status={status} elapsed={elapsed}s exit={proc.returncode}")
    return {
        **base,
        "status": status,
        "payload": payload,
        "raw_output_path": str(out_path.name),
        "error": None if status == "completed" else f"exit {proc.returncode}",
        "elapsed_sec": elapsed,
    }


def run_cohort(request: dict[str, Any], *, base_dir: Path | None = None) -> dict[str, Any]:
    """Run every profile in the request; a relative work_dir resolves against ``base_dir``."""
    phase_id = str(request["phase_id"])
    query = str(request["query"])
    context = sanitize_phase_context(str(request.get("context", "")))
    logical_ids = list(request["logical_model_ids"])
    work_dir = ((base_dir or Path.cwd()) / str(request["work_dir"])).resolve()
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
    # The request stores work_dir relative to its own directory (no local paths in artifacts).
    result = run_cohort(load_request(request_path), base_dir=request_path.resolve().parent)
    body = json.dumps(result, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(body, encoding="utf-8")
    else:
        print(body, end="")
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
