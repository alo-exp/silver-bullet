#!/usr/bin/env python3
"""Deterministic consolidation for /silver:deep-research-multi-ai."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from skill_paths import ensure_scripts_on_path

ensure_scripts_on_path("silver-multi-ai-task", marker="json_hash.py")

from json_hash import sha256_json  # noqa: E402


FORBIDDEN_INPUT_PREFIXES = (
    "report",
    "synthesis",
    "vloop",
    "canonical_claim",
    "worker_state",
)


def validate_inputs(envelopes: list[dict[str, Any]], index: dict[str, Any]) -> None:
    allowed_phases = {"DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"}
    index_keys: set[tuple[str, str]] = set()
    for e in index.get("entries", []):
        wid = e.get("work_item_id")
        lid = e.get("logical_model_id")
        if not wid or not lid:
            raise ValueError("result index entry missing work_item_id or logical_model_id")
        index_keys.add((wid, lid))
    for env in envelopes:
        phase = env.get("phase_id")
        if phase not in allowed_phases:
            raise ValueError(f"forbidden or unknown phase_id: {phase}")
        key = (env.get("work_item_id"), env.get("logical_model_id"))
        if key not in index_keys:
            raise ValueError(f"envelope not referenced by result index: {key}")
        for field in env:
            for forbidden in FORBIDDEN_INPUT_PREFIXES:
                if field == forbidden or field.startswith(f"{forbidden}_"):
                    raise ValueError(f"forbidden input class present: {field}")


def normalize_claim(text: str) -> str:
    return " ".join(text.lower().split())


def consolidate(envelopes: list[dict[str, Any]], index: dict[str, Any], resolved_pool: int) -> dict[str, Any]:
    validate_inputs(envelopes, index)
    claims: dict[str, dict[str, Any]] = {}
    families_seen: set[str] = set()

    for env in envelopes:
        if env.get("phase_id") != "DR-TRIANGULATE":
            continue
        family = env.get("model_family_id")
        if not family:
            raise ValueError("model_family_id required on DR-TRIANGULATE envelope")
        families_seen.add(family)
        payload = env.get("payload", {})
        for candidate in payload.get("claim_candidates", []):
            text = candidate.get("text") or candidate.get("claim", "")
            if not text:
                continue
            key = normalize_claim(text)
            entry = claims.setdefault(
                key,
                {
                    "text": text,
                    "supporting_agents": set(),
                    "families": set(),
                },
            )
            agent = env.get("logical_model_id")
            if agent:
                entry["supporting_agents"].add(agent)
            entry["families"].add(family)

    consensus = []
    divergence = []
    for key, entry in sorted(claims.items()):
        families = entry["families"]
        support = len(entry["supporting_agents"])
        entry_support_agents = sorted(entry["supporting_agents"])
        strong_threshold = max(2, (resolved_pool + 1) // 2)
        label = "divergent"
        if support >= 2 and len(families) >= 2:
            label = "consensus" if support >= strong_threshold else "weak_consensus"
        record = {
            "claim_key": key,
            "text": entry["text"],
            "support_count": support,
            "resolved_pool": resolved_pool,
            "supporting_agents": entry_support_agents,
            "model_families": sorted(families),
            "label": label,
        }
        if label == "divergent":
            divergence.append(record)
        else:
            consensus.append(record)

    return {
        "schema_id": "consolidation-output-v1",
        "version": "1.0.0",
        "resolved_pool": resolved_pool,
        "coverage": {
            "resolved": resolved_pool,
            "indexed": len(index.get("entries", [])),
            "envelopes": len(envelopes),
            "families_seen": sorted(families_seen),
        },
        "consensus": consensus,
        "divergence": divergence,
        "content_hash": "",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="DR-multi-AI deterministic consolidation")
    parser.add_argument("--envelopes", required=True, help="JSON file with contribution envelopes")
    parser.add_argument("--index", required=True, help="multi-ai-result-index-v1 JSON path")
    parser.add_argument("--output", required=True, help="Output consolidation JSON path")
    parser.add_argument("--resolved-pool", type=int, required=True)
    args = parser.parse_args()

    envelopes = json.loads(Path(args.envelopes).read_text(encoding="utf-8"))
    index = json.loads(Path(args.index).read_text(encoding="utf-8"))
    if not isinstance(envelopes, list):
        raise SystemExit("envelopes file must be a JSON array")

    out = consolidate(envelopes, index, args.resolved_pool)
    out["content_hash"] = sha256_json({k: v for k, v in out.items() if k != "content_hash"})
    Path(args.output).write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "output": args.output, "content_hash": out["content_hash"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
