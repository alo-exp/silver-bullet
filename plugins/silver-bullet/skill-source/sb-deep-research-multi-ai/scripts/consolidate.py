#!/usr/bin/env python3
"""Deterministic consolidation for /sb:deep-research-multi-ai."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from generated_files import atomic_write_text, json_safe, strict_json_dumps
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


def index_pool_size(index: dict[str, Any]) -> int:
    """Distinct agents in the result index: the pool the consensus threshold is measured on."""
    return len({str(e.get("logical_model_id")) for e in index.get("entries", []) if e.get("logical_model_id")})


_NEGATION_RE = re.compile(
    r"\b(?:not|no|never|without|lacks?|lacking|cannot|can't|doesn't|don't|isn't|aren't|won't|fails? to)\b",
    re.IGNORECASE,
)


_AUXILIARIES = frozenset({"does", "do", "did", "is", "are", "was", "were"})


def _polarity(text: str) -> tuple[str, bool]:
    """(claim with negation cues removed, whether it was negated): pairs 'X supports Y' with 'X does not support Y'."""
    negated = bool(_NEGATION_RE.search(text))
    words = normalize_claim(_NEGATION_RE.sub(" ", text)).split()
    # light normalisation so "supports" / "does not support" meet: drop auxiliaries, singularise
    stems = [w[:-1] if len(w) > 3 and w.endswith("s") else w for w in words if w not in _AUXILIARIES]
    return " ".join(stems), negated


def _candidate_text(candidate: Any) -> tuple[str, bool]:
    """(text, malformed). Model output is untrusted: only {text|claim: str} counts."""
    if not isinstance(candidate, dict):
        return "", True
    text = candidate.get("text") or candidate.get("claim", "")
    if not text:
        return "", False
    if not isinstance(text, str):
        return "", True
    return text, False


def consolidate(envelopes: list[dict[str, Any]], index: dict[str, Any], resolved_pool: int) -> dict[str, Any]:
    """Merge DR-TRIANGULATE claim candidates into consensus / divergence records.

    The consensus threshold uses the result index's agent count (a caller-supplied
    `resolved_pool` is only the fallback for an index without entries). Malformed model
    output (non-dict payloads, non-list candidates, non-string text) is counted in
    coverage.malformed_items and skipped rather than failing the run.
    """
    validate_inputs(envelopes, index)
    pool = index_pool_size(index) or resolved_pool
    claims: dict[str, dict[str, Any]] = {}
    families_seen: set[str] = set()
    malformed = 0

    for env in envelopes:
        if env.get("phase_id") != "DR-TRIANGULATE":
            continue
        family = env.get("model_family_id")
        if not family:
            raise ValueError("model_family_id required on DR-TRIANGULATE envelope")
        families_seen.add(family)
        payload = env.get("payload", {})
        candidates = payload.get("claim_candidates", []) if isinstance(payload, dict) else None
        if not isinstance(candidates, list):
            malformed += 1
            continue
        for candidate in candidates:
            text, bad = _candidate_text(candidate)
            malformed += bad
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

    # Opposite claims about the same thing are a dispute, never agreement: a claim is "contested"
    # when the same statement (negation aside) is also asserted with the opposite polarity.
    polarities: dict[str, set[bool]] = {}
    for key, entry in claims.items():
        base, negated = _polarity(entry["text"])
        entry["base"], entry["negated"] = base, negated
        polarities.setdefault(base, set()).add(negated)

    consensus = []
    divergence = []
    strong_threshold = max(2, (pool + 1) // 2)
    for key, entry in sorted(claims.items()):
        families = entry["families"]
        support = len(entry["supporting_agents"])
        label = "divergent"
        contested = len(polarities.get(entry["base"], ())) > 1
        if contested:
            label = "contested"
        elif support >= 2 and len(families) >= 2:
            label = "consensus" if support >= strong_threshold else "weak_consensus"
        record = {
            "claim_key": key,
            "text": entry["text"],
            "support_count": support,
            "resolved_pool": pool,
            "supporting_agents": sorted(entry["supporting_agents"]),
            "model_families": sorted(families),
            "label": label,
        }
        if label in {"divergent", "contested"}:
            if contested:
                record["stance"] = "negated" if entry["negated"] else "affirmed"
            divergence.append(record)
        else:
            consensus.append(record)

    return {
        "schema_id": "consolidation-output-v1",
        "version": "1.0.0",
        "resolved_pool": pool,
        "coverage": {
            "resolved": pool,
            "indexed": len(index.get("entries", [])),
            "envelopes": len(envelopes),
            "families_seen": sorted(families_seen),
            "malformed_items": malformed,
        },
        "consensus": consensus,
        "divergence": divergence,
        "content_hash": "",
    }


def finalize(out: dict[str, Any]) -> dict[str, Any]:
    """Strict-JSON copy with content_hash set over everything else."""
    out = json_safe(out)
    out["content_hash"] = sha256_json({k: v for k, v in out.items() if k != "content_hash"})
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="DR-multi-AI deterministic consolidation")
    parser.add_argument("--envelopes", required=True, help="JSON file with contribution envelopes")
    parser.add_argument("--index", required=True, help="multi-ai-result-index-v1 JSON path")
    parser.add_argument("--output", required=True, help="Output consolidation JSON path")
    parser.add_argument(
        "--resolved-pool",
        type=int,
        help="Expected agent count; must match the result index (it is derived from the index)",
    )
    args = parser.parse_args()

    envelopes = json.loads(Path(args.envelopes).read_text(encoding="utf-8"))
    index = json.loads(Path(args.index).read_text(encoding="utf-8"))
    if not isinstance(envelopes, list):
        raise SystemExit("envelopes file must be a JSON array")
    pool = index_pool_size(index)
    if args.resolved_pool is not None and args.resolved_pool != pool:
        raise SystemExit(
            f"--resolved-pool {args.resolved_pool} disagrees with the result index ({pool} distinct agents)"
        )

    out = finalize(consolidate(envelopes, index, pool))
    atomic_write_text(Path(args.output), strict_json_dumps(out, indent=2) + "\n")
    print(json.dumps({"ok": True, "output": args.output, "content_hash": out["content_hash"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
