#!/usr/bin/env python3
"""
Phase gate — validates required artifacts exist before phase rollup.

Pattern adapted from lingzhi227 file-gate (idea-derived; see reference/provenance.md).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


def _skill_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_phases_config() -> dict[str, Any]:
    root = _skill_root()
    json_path = root / "phases.json"
    if json_path.exists():
        with open(json_path, encoding="utf-8") as f:
            return json.load(f)
    yaml_path = root / "phases.yaml"
    if yaml_path.exists():
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise RuntimeError("phases.json missing and PyYAML not installed") from exc
        with open(yaml_path, encoding="utf-8") as f:
            return yaml.safe_load(f)
    raise FileNotFoundError("Neither phases.json nor phases.yaml found")


def artifact_satisfied(out_dir: Path, artifact: str) -> tuple[bool, str]:
    path = out_dir / artifact
    if not path.exists():
        return False, f"missing: {artifact}"

    if artifact.endswith(".jsonl"):
        if path.stat().st_size == 0:
            return False, f"empty: {artifact}"
        return True, "ok"

    if artifact.endswith(".md"):
        text = path.read_text(encoding="utf-8").strip()
        if len(text) < 20:
            return False, f"too short: {artifact}"
        return True, "ok"

    if artifact.endswith(".json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return False, f"invalid json: {artifact}"
        if not data:
            return False, f"empty: {artifact}"
        return True, "ok"

    if path.stat().st_size == 0:
        return False, f"empty: {artifact}"
    return True, "ok"


def check_phase(out_dir: Path, phase_key: str, config: dict[str, Any] | None = None) -> dict[str, Any]:
    config = config or load_phases_config()
    phases = config.get("phases", {})
    if phase_key not in phases:
        return {"phase": phase_key, "status": "error", "reason": f"unknown phase: {phase_key}"}

    phase = phases[phase_key]
    results: list[dict[str, str]] = []
    all_ok = True
    for artifact in phase.get("required_artifacts", []):
        ok, detail = artifact_satisfied(out_dir, artifact)
        results.append({"artifact": artifact, "ok": ok, "detail": detail})
        if not ok:
            all_ok = False

    return {
        "phase": phase_key,
        "phase_id": phase.get("id"),
        "status": "pass" if all_ok else "fail",
        "artifacts": results,
    }


def check_mode_complete(out_dir: Path, mode: str, config: dict[str, Any] | None = None) -> dict[str, Any]:
    config = config or load_phases_config()
    modes = config.get("modes", {})
    if mode not in modes:
        return {"mode": mode, "status": "error", "reason": f"unknown mode: {mode}"}

    phase_results = []
    all_ok = True
    for phase_key in modes[mode].get("phases", []):
        result = check_phase(out_dir, phase_key, config)
        phase_results.append(result)
        if result["status"] != "pass":
            all_ok = False

    return {
        "mode": mode,
        "status": "pass" if all_ok else "fail",
        "phases": phase_results,
    }


def cmd_check(args: argparse.Namespace) -> int:
    out_dir = Path(args.dir).resolve()
    if not out_dir.is_dir():
        print(json.dumps({"status": "error", "reason": f"not a directory: {out_dir}"}))
        return 1

    if args.phase:
        result = check_phase(out_dir, args.phase)
    else:
        mode = args.mode
        if not mode:
            manifest_path = out_dir / "run_manifest.json"
            if manifest_path.exists():
                mode = json.loads(manifest_path.read_text()).get("mode", "standard")
            else:
                mode = "standard"
        result = check_mode_complete(out_dir, mode)

    print(json.dumps(result, indent=2))
    return 0 if result.get("status") == "pass" else 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate phase artifacts before rollup")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--phase", help="Single phase key (e.g. retrieve)")
    parser.add_argument("--mode", help="Mode for full gate (quick|standard|deep|ultradeep)")
    args = parser.parse_args()
    sys.exit(cmd_check(args))


if __name__ == "__main__":
    main()
