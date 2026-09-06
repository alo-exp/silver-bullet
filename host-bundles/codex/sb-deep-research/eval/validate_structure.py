#!/usr/bin/env python3
"""Validate completed research artifact tree structure."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SKILL_ROOT / "scripts"))

from phase_gate import check_mode_complete  # noqa: E402

REQUIRED_ROOT = [
    "run_manifest.json",
    "scope.md",
    "vloop-rollup.json",
]

MODE_EXTRA = {
    "quick": ["sources.jsonl", "evidence.jsonl", "decision-record.md", "handoff.md"],
    "standard": [
        "research-plan.md", "triangulation.md", "outline.md",
        "research_report.md", "claims.jsonl",
        "decision-record.md", "handoff.md",
    ],
    "deep": [
        "research-plan.md", "triangulation.md", "outline.md",
        "research_report.md", "claims.jsonl", "critique.md",
        "decision-record.md", "handoff.md",
    ],
    "ultradeep": [
        "research-plan.md", "triangulation.md", "outline.md",
        "research_report.md", "claims.jsonl", "critique.md",
        "decision-record.md", "handoff.md",
    ],
}


def validate_structure(out_dir: Path, mode: str | None = None) -> dict:
    if not out_dir.is_dir():
        return {"status": "fail", "reason": f"not a directory: {out_dir}"}

    manifest_path = out_dir / "run_manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        mode = mode or manifest.get("mode", "standard")
    else:
        mode = mode or "standard"

    required = list(REQUIRED_ROOT) + MODE_EXTRA.get(mode, MODE_EXTRA["standard"])
    missing = [f for f in required if not (out_dir / f).exists()]

    gate = check_mode_complete(out_dir, mode)
    status = "pass" if not missing and gate.get("status") == "pass" else "fail"
    return {
        "status": status,
        "mode": mode,
        "missing": missing,
        "phase_gate": gate,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate research artifact tree")
    parser.add_argument("--dir", required=True)
    parser.add_argument("--mode", default=None)
    args = parser.parse_args()
    result = validate_structure(Path(args.dir), args.mode)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
