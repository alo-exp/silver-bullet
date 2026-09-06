#!/usr/bin/env python3
"""Core library for /sb:multi-ai-task (multi-ai-task-v2 spine)."""

from __future__ import annotations

import json
import os
import secrets
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any

from json_hash import sha256_bytes, sha256_file, sha256_json  # noqa: E402


SKILL_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = SKILL_ROOT / "reference" / "model-family-registry-v1.json"
HOST_MATRIX_PATH = SKILL_ROOT / "reference" / "host-matrix-v1.json"

DEFAULT_MAX_COST_USD = Decimal("25.00")
DEFAULT_MAX_TOTAL_TOKENS = 2_000_000
DEFAULT_MAX_AGENTS = 11
DEFAULT_CONCURRENCY = 6
DEFAULT_CACHE_TTL_SECONDS = 86400

SPINE = "multi-ai-task-v2"
UNSUPPORTED_HOST_ERROR = "SB_MULTI_AI_UNSUPPORTED_HOST"

# Host-delegate backends (SB router: GPT→agent-codex, Opus→agent-claude).
CODEX_DELEGATE_LOGICAL_IDS = frozenset({"gpt-5.6-luna-medium"})
CLAUDE_DELEGATE_LOGICAL_IDS = frozenset({"claude-opus-4.8-medium"})


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def new_run_id() -> str:
    return f"run-{secrets.token_hex(16)}"


def new_work_item_id() -> str:
    return f"work-{secrets.token_hex(16)}"


def new_attempt_id() -> str:
    return f"attempt-{uuid.uuid4()}"


def usd_to_micro_usd(value: str | Decimal) -> int:
    dec = Decimal(str(value)).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
    return int(dec * 1_000_000)


def load_registry() -> dict[str, Any]:
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def registry_sha256(registry: dict[str, Any] | None = None) -> str:
    reg = registry if registry is not None else load_registry()
    body = {k: reg[k] for k in ("schema_id", "version", "logical_to_family", "aliases") if k in reg}
    return sha256_json(body)


def normalize_logical_id(raw: str, registry: dict[str, Any] | None = None) -> str:
    reg = registry if registry is not None else load_registry()
    aliases = reg.get("aliases", {})
    return aliases.get(raw, raw)


def family_for_logical(logical_id: str, registry: dict[str, Any] | None = None) -> str:
    reg = registry if registry is not None else load_registry()
    canonical = normalize_logical_id(logical_id, reg)
    mapping = reg.get("logical_to_family", {})
    if canonical not in mapping:
        raise ValueError(f"unknown logical model id: {logical_id}")
    return mapping[canonical]


def detect_host() -> str:
    explicit = os.environ.get("SB_HOST", "").strip().lower()
    # Ambient fail-closed hosts win over a more permissive SB_HOST override.
    if os.environ.get("CLAUDECODE") or os.environ.get("CLAUDE_CODE"):
        return "claude-code"
    if os.environ.get("CODEX_SANDBOX") or os.environ.get("SB_AGENT_CODEX_DELEGATE"):
        return "codex"
    if explicit in {"claude", "claude-code"}:
        return "claude-code"
    if explicit == "codex":
        return "codex"
    if explicit == "cursor":
        return "cursor"
    if os.environ.get("CURSOR_AGENT") or os.environ.get("CURSOR_TRACE_ID"):
        return "cursor"
    if explicit:
        return explicit
    return "unknown"


def host_gate() -> dict[str, Any]:
    matrix = json.loads(HOST_MATRIX_PATH.read_text(encoding="utf-8"))
    host = detect_host()
    entry = matrix["hosts"].get(host)
    if entry is None:
        return {
            "ok": False,
            "host": host,
            "error_code": UNSUPPORTED_HOST_ERROR,
            "message": f"Host {host!r} is unsupported for multi-ai-task v1",
        }
    if entry["status"] != "supported":
        return {
            "ok": False,
            "host": host,
            "error_code": entry.get("error_code", UNSUPPORTED_HOST_ERROR),
            "message": f"Host {host!r} is packaged-fail-closed for multi-ai-task v1",
        }
    return {"ok": True, "host": host}


@dataclass
class PoolSelection:
    ocg_pool: str = "lite"
    cursor_pool: str = "default"
    include_only: list[str] = field(default_factory=list)
    exclude: list[str] = field(default_factory=list)
    cursor_subscription: str = "auto"


@dataclass
class BudgetPolicy:
    max_cost_micro_usd: int = field(default_factory=lambda: usd_to_micro_usd(DEFAULT_MAX_COST_USD))
    max_total_tokens: int = DEFAULT_MAX_TOTAL_TOKENS
    max_agents: int = DEFAULT_MAX_AGENTS
    concurrency: int = DEFAULT_CONCURRENCY
    allow_unknown_cost: bool = False


def resolve_pool(selection: PoolSelection, subscription: str | None = None) -> list[dict[str, Any]]:
    registry = load_registry()
    if selection.ocg_pool not in {"none", "lite", "regular"}:
        raise ValueError(f"invalid ocg pool: {selection.ocg_pool}")
    if selection.cursor_pool not in {"none", "default"}:
        raise ValueError(f"invalid cursor pool: {selection.cursor_pool}")

    sub = selection.cursor_subscription if subscription is None else subscription
    if sub not in {"subscribed", "unsubscribed", "unknown", "auto"}:
        raise ValueError(f"invalid cursor subscription: {sub!r}")

    ocg_raw: list[str] = []
    if selection.ocg_pool == "lite":
        ocg_raw = list(registry.get("ocg_lite_pool", []))
    elif selection.ocg_pool == "regular":
        ocg_raw = list(registry.get("ocg_regular_pool", []))

    cursor_raw: list[str] = []
    if selection.cursor_pool == "default":
        cursor_raw = list(registry.get("cursor_default_pool", []))

    if selection.include_only:
        raw_candidates = list(selection.include_only)
    else:
        raw_candidates = ocg_raw + cursor_raw

    normalized: list[str] = []
    seen: set[str] = set()
    for raw in raw_candidates:
        canon = normalize_logical_id(raw, registry)
        if canon in seen:
            continue
        seen.add(canon)
        normalized.append(canon)

    exclude = {normalize_logical_id(x, registry) for x in selection.exclude}
    normalized = [x for x in normalized if x not in exclude]
    glm_excluded = "glm-5.2" in exclude
    glm_surviving_before_strip = "glm-5.2" in normalized

    if sub == "unknown" and glm_surviving_before_strip:
        raise ValueError("cursor subscription unknown; declare, exclude glm-5.2, or abort")

    def without_glm(ids: list[str]) -> list[str]:
        return [item for item in ids if item != "glm-5.2"]

    def glm_requested_in_include_only() -> bool:
        return any(normalize_logical_id(x, registry) == "glm-5.2" for x in selection.include_only)

    def want_glm_for_subscription() -> bool:
        if glm_excluded:
            return False
        if selection.include_only:
            return glm_requested_in_include_only()
        if sub == "unsubscribed":
            # Route surviving GLM slots only; do not invent glm for lite-only OCG pools.
            return selection.cursor_pool == "default" or glm_surviving_before_strip
        # subscribed and auto (unknown handled before strip)
        return selection.cursor_pool == "default"

    normalized = without_glm(normalized)
    if want_glm_for_subscription():
        normalized.append("glm-5.2")
        normalized = list(dict.fromkeys(normalized))

    if not normalized:
        raise ValueError("resolved agent set is empty")

    reg_hash = registry_sha256(registry)
    resolved: list[dict[str, Any]] = []
    for logical_id in normalized:
        family = family_for_logical(logical_id, registry)
        if logical_id == "glm-5.2" and sub == "unsubscribed":
            backend = "ocg"
            effective = "ocg-glm-5.2"
        elif logical_id.startswith("ocg-"):
            backend = "ocg"
            effective = logical_id
        elif logical_id in CODEX_DELEGATE_LOGICAL_IDS:
            backend = "codex"
            effective = logical_id
        elif logical_id in CLAUDE_DELEGATE_LOGICAL_IDS:
            backend = "claude"
            effective = logical_id
        else:
            backend = "cursor"
            effective = logical_id
        resolved.append(
            {
                "logical_model_id": logical_id,
                "model_family_id": family,
                "requested_model_id": logical_id,
                "effective_model_id": effective,
                "backend": backend,
                "model_family_registry_version": registry["version"],
                "model_family_registry_sha256": reg_hash,
            }
        )
    return resolved


def empty_ledger(run_id: str) -> dict[str, Any]:
    body = {
        "schema_id": "multi-ai-dispatch-ledger-v1",
        "version": "1.0.0",
        "spine": SPINE,
        "run_id": run_id,
        "generation": 0,
        "head_hash": sha256_json([]),
        "entries": [],
    }
    body["head_hash"] = sha256_json(body["entries"])
    return body


def build_work_item_manifest(
    run_id: str,
    work_item_id: str,
    input_hash: str,
    resolved: list[dict[str, Any]],
    budget: BudgetPolicy,
) -> dict[str, Any]:
    return {
        "schema_id": "multi-ai-work-item-manifest-v1",
        "version": "1.0.0",
        "spine": SPINE,
        "run_id": run_id,
        "work_item_id": work_item_id,
        "input_hash": input_hash,
        "resolved_logical_ids": resolved,
        "attempts": [],
        "budget": {
            "currency_micro_usd_cap": budget.max_cost_micro_usd,
            "total_tokens_cap": budget.max_total_tokens,
            "currency_micro_usd_actual": 0,
            "total_tokens_actual": 0,
            "price_known": not budget.allow_unknown_cost,
            "usage_metered": True,
            "budget_stop_reason": None,
        },
        "outputs": [],
    }


def build_result_index(run_id: str, ledger: dict[str, Any], resolved: list[dict[str, Any]], work_item_id: str) -> dict[str, Any]:
    entries = []
    for item in sorted(resolved, key=lambda x: (work_item_id, x["logical_model_id"])):
        entries.append(
            {
                "work_item_id": work_item_id,
                "logical_model_id": item["logical_model_id"],
                "status": "pending",
                "authoritative_attempt_id": None,
                "validation_outcome": None,
                "terminal_reason": None,
            }
        )
    return {
        "schema_id": "multi-ai-result-index-v1",
        "version": "1.0.0",
        "spine": SPINE,
        "run_id": run_id,
        "ledger_generation": ledger.get("generation", 0),
        "ledger_head_hash": ledger.get("head_hash", sha256_json([])),
        "entries": entries,
    }


def dry_run_report(selection: PoolSelection, subscription: str | None = None, max_agents: int = DEFAULT_MAX_AGENTS) -> dict[str, Any]:
    host = detect_host()
    resolved = resolve_pool(selection, subscription=subscription)
    unique = len({x["logical_model_id"] for x in resolved})
    if unique > max_agents:
        return {
            "ok": False,
            "error_code": "MAX_AGENTS_EXCEEDED",
            "resolved_count": unique,
            "max_agents": max_agents,
        }
    return {
        "ok": True,
        "host": host,
        "host_gate_enforced": False,
        "spine": SPINE,
        "resolved_count": len(resolved),
        "resolved_pool": resolved,
        "dry_run": True,
    }
