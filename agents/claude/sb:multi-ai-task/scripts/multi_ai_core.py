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


_CLAUDE_MARKERS = ("CLAUDECODE", "CLAUDE_CODE")
_CODEX_MARKERS = (
    "CODEX_SANDBOX",
    "SB_AGENT_CODEX_DELEGATE",
    "CODEX_CI",
    "CODEX_THREAD_ID",
    "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
)
_CURSOR_MARKERS = ("CURSOR_AGENT", "CURSOR_TRACE_ID")
_EXPLICIT_HOSTS = {"claude": "claude-code", "claude-code": "claude-code", "codex": "codex"}
_SUPPORTED_HOSTS_TEXT = "Claude Code or Codex"


def _any_set(names: tuple[str, ...]) -> bool:
    return any(os.environ.get(name) for name in names)


def detect_host() -> str:
    """Name the host this process runs under: ``claude-code``, ``codex``, ``cursor``, ``unknown`` or another name.

    An explicit ``SB_HOST`` that is not Claude Code or Codex (``cursor``, or anything unrecognised) is
    returned as is, whatever else is in the environment, so no override can hide an unsupported host
    or name a different one. Real process markers (``CLAUDECODE``, ``CODEX_*``) beat a supported
    ``SB_HOST``. A supported ``SB_HOST`` is the user's own statement and outranks the ``CURSOR_*``
    markers, which are weak (a Claude Code or Codex session started from a Cursor terminal inherits
    them); those markers alone are refused.
    """
    explicit = os.environ.get("SB_HOST", "").strip().lower()
    if explicit and explicit not in _EXPLICIT_HOSTS:
        return explicit
    if _any_set(_CLAUDE_MARKERS):
        return "claude-code"
    if _any_set(_CODEX_MARKERS):
        return "codex"
    if explicit:
        return _EXPLICIT_HOSTS[explicit]
    if _any_set(_CURSOR_MARKERS):
        return "cursor"
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
            "message": f"Host {host!r} is unsupported for multi-ai-task: run it from {_SUPPORTED_HOSTS_TEXT}",
        }
    if entry["status"] != "supported":
        return {
            "ok": False,
            "host": host,
            "error_code": entry.get("error_code") or UNSUPPORTED_HOST_ERROR,
            "message": entry.get("message") or f"Host {host!r} is not supported for multi-ai-task: run it from {_SUPPORTED_HOSTS_TEXT}",
        }
    return {"ok": True, "host": host}


def _real(path: str | Path) -> Path:
    return Path(os.path.realpath(os.path.expanduser(str(path))))


def resolve_output_root(raw: str | Path) -> Path:
    """The one physical path of an output root: ``~`` expanded, symlinks and ``..`` resolved.

    Callers check this value and write below this same value, so a literal ``~`` that the shell
    did not expand (``--output-root=~/x``) cannot be checked as one place and written as another.
    """
    return _real(raw)


def _fold(path: Path) -> tuple[str, ...]:
    # Case-folded: a case-insensitive filesystem (macOS) reaches ~/.Claude through ~/.CLAUDE.
    return tuple(part.casefold() for part in path.parts)


def _inside(path: Path, root: Path) -> bool:
    inner, outer = _fold(path), _fold(root)
    return inner[: len(outer)] == outer


def _runtime_homes() -> list[Path]:
    home = Path(os.path.expanduser("~"))
    homes = [home / ".claude", home / ".codex"]
    if os.environ.get("CODEX_HOME"):
        homes.append(Path(os.environ["CODEX_HOME"]))
    return homes


def _state_dirs() -> list[Path]:
    dirs = [h / ".silver-bullet" for h in _runtime_homes()]
    if os.environ.get("SB_RUNTIME_STATE_DIR"):
        dirs.append(Path(os.environ["SB_RUNTIME_STATE_DIR"]))
    return dirs


def _active_delegation() -> tuple[list[Path], str, str]:
    """The ownership scope of the active agent delegation, as the delegation guard keeps it.

    Returns ``(scopes, host, task_id)``; nothing is active when the guard is switched
    off (SB_AGENT_DELEGATE_GUARD=0, SB_AGENT_DELEGATE_V2=0) or the state file is absent or unreadable.
    """
    if os.environ.get("SB_AGENT_DELEGATE_GUARD") == "0" or os.environ.get("SB_AGENT_DELEGATE_V2") == "0":
        return [], "", ""
    for state_dir in _state_dirs():
        state_file = state_dir / "agent-delegation-active.json"
        try:
            state = json.loads(state_file.read_text(encoding="utf-8"))
        except (OSError, ValueError, RecursionError):
            continue
        if not isinstance(state, dict) or state.get("active") is not True:
            continue
        raw = state.get("ownership_scope")
        scopes = [_real(item) for item in raw if isinstance(item, str) and item] if isinstance(raw, list) else []
        host, task = state.get("host"), state.get("task_id")
        return scopes, host if isinstance(host, str) else "", task if isinstance(task, str) else ""
    return [], "", ""


def output_root_refusal(output_root: Path) -> str | None:
    """Why a run may not write below ``output_root`` (None when it may).

    The hooks cannot see what this script writes, so the script keeps the hooks' boundaries itself: a run
    never writes into Silver Bullet's runtime state or plugin cache, a ``.git`` directory, the home
    directory (or a parent of it), or the ownership scope of an active agent delegation. That scope's own
    evidence directory (``.planning/agent-<host>/<task>/``) stays open, as it does for the delegation guard.
    """
    root = _real(output_root)
    home = _real("~")
    if _inside(home, root):
        return f"output root {root} is the home directory or one of its parents; use a project directory such as .planning/multi-ai/<run-id>/"
    if ".git" in _fold(root):
        return f"output root {root} is inside a .git directory"
    protected = [_real(d) for d in _state_dirs()]
    protected += [_real(h) for h in _runtime_homes()]
    if os.environ.get("SB_RUNTIME_PLUGIN_CACHE_ROOT"):
        protected.append(_real(os.environ["SB_RUNTIME_PLUGIN_CACHE_ROOT"]))
    for base in protected:
        if _inside(root, base):
            return f"output root {root} is inside Silver Bullet's runtime state or plugin cache ({base}); use a project directory such as .planning/multi-ai/<run-id>/"
    # Hidden directories directly under the home directory hold credentials and host configuration
    # (~/.ssh, ~/.aws, ~/.claude, ~/.codex ...): never an output root.
    if _inside(root, home) and len(root.parts) > len(home.parts) and root.parts[len(home.parts)].startswith("."):
        return f"output root {root} is inside a hidden directory of the home directory (credentials or host configuration); use a project directory such as .planning/multi-ai/<run-id>/"
    scopes, host, task = _active_delegation()
    for scope in scopes:
        if _inside(root, scope):
            marker = (".planning", f"agent-{host}", task)
            parts = root.parts[len(scope.parts):]
            if any(parts[i : i + 3] == marker for i in range(len(parts))):
                continue
            return (
                f"output root {root} is inside the ownership scope of the active agent delegation ({scope}); "
                f"use .planning/agent-{host or '<host>'}/{task or '<task>'}/ or a directory outside that scope"
            )
    return None


@dataclass
class PoolSelection:
    ocg_pool: str = "lite"
    cursor_pool: str = "default"
    include_only: list[str] = field(default_factory=list)
    exclude: list[str] = field(default_factory=list)
    cursor_subscription: str = "auto"


@dataclass
class BudgetPolicy:
    """Run caps. max_agents and concurrency are enforced at dispatch; the CLIs report no usage,
    so the USD and token caps are recorded in the manifest but cannot be metered in v1."""

    max_cost_micro_usd: int = field(default_factory=lambda: usd_to_micro_usd(DEFAULT_MAX_COST_USD))
    max_total_tokens: int = DEFAULT_MAX_TOTAL_TOKENS
    max_agents: int = DEFAULT_MAX_AGENTS
    concurrency: int = DEFAULT_CONCURRENCY


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


def append_ledger_entry(ledger: dict[str, Any], entry: dict[str, Any]) -> dict[str, Any]:
    """Append one dispatch event, bumping the generation and re-hashing the entry chain."""
    generation = int(ledger.get("generation", 0)) + 1
    full = {"entry_id": f"entry-{generation:06d}", "timestamp": utc_now_iso(), **entry}
    ledger["entries"].append(full)
    ledger["generation"] = generation
    ledger["head_hash"] = sha256_json(ledger["entries"])
    return full


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
            "max_agents": budget.max_agents,
            "concurrency": budget.concurrency,
            # The worker CLIs report no token or price data, so nothing is metered and no
            # actuals are claimed; only the agent cap and concurrency are enforced.
            "price_known": False,
            "usage_metered": False,
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
