#!/usr/bin/env python3
"""
Capability scorer — scores completed runs or SKILL.md against SB rubric.

Does NOT use stars, installs, recency, or external popularity signals.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SKILL_ROOT = Path(__file__).resolve().parent.parent

DIMENSIONS = [
    "phases_modes",
    "citation_evidence",
    "search_providers",
    "multilingual",
    "report_formats",
    "validation_eval",
    "portability",
    "human_in_loop",
    "composability",
    "source_catalogs",
    "adversarial",
]


def _exists(rel: str) -> bool:
    return (SKILL_ROOT / rel).exists()


def score_skill_tree() -> dict[str, Any]:
    scores: dict[str, int] = {}

    scores["phases_modes"] = 5 if _exists("phases.json") and _exists("scripts/phase_gate.py") else 3
    scores["citation_evidence"] = 5 if _exists("scripts/source_evaluator.py") else 4
    scores["search_providers"] = 5 if _exists("scripts/search_orchestrator.py") else 3
    scores["multilingual"] = 5 if _exists("reference/report_profiles.json") else 2
    scores["report_formats"] = 4 if _exists("reference/report-blocks") else 3
    scores["validation_eval"] = 5 if _exists("eval/validate_structure.py") else 4
    scores["portability"] = 5
    scores["human_in_loop"] = 4 if _exists("reference/human-checkpoints.md") else 3
    scores["composability"] = 5
    scores["source_catalogs"] = 5 if _exists("reference/catalogs/intent_classes.json") else 3
    scores["adversarial"] = 5 if _exists("reference/adversarial-review.md") else 3

    total = sum(scores.values())
    return {"dimensions": scores, "total": total, "max": 55}


def score_run(out_dir: Path) -> dict[str, Any]:
    behavioral: dict[str, Any] = {
        "source_count": 0,
        "unsupported_claims": 0,
        "validation_failures": 0,
        "fallback_recorded": False,
        "human_checkpoint_count": 0,
    }

    sources = out_dir / "sources.jsonl"
    if sources.exists():
        behavioral["source_count"] = sum(1 for _ in sources.read_text().splitlines() if _.strip())

    manifest_path = out_dir / "run_manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        behavioral["fallback_recorded"] = bool(manifest.get("fallback_reason"))

    handoff = out_dir / "handoff.md"
    if handoff.exists():
        behavioral["human_checkpoint_count"] = len(
            re.findall(r"checkpoint_type", handoff.read_text(encoding="utf-8"), re.I)
        )

    skill = score_skill_tree()
    return {
        "behavioral": behavioral,
        "capability": skill,
        "note": "Capability total is observational, not pass/fail",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="SB deep-research capability scorer")
    parser.add_argument("--dir", help="Completed run directory")
    parser.add_argument("--skill-only", action="store_true")
    args = parser.parse_args()

    if args.skill_only or not args.dir:
        result = score_skill_tree()
    else:
        result = score_run(Path(args.dir))

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
