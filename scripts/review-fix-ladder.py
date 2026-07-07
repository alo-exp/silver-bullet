#!/usr/bin/env python3
"""Resolve host-aware model/reasoning rungs for silver:review-fix-ladder."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

REASONING_ORDER = ("low", "medium", "high", "xhigh")
CLAUDE_THINKING_ORDER = ("medium", "high", "xhigh")
CODEX_MINI_SLUG = "gpt-5.4-mini"

CURSOR_FIXED_RUNGS: list[tuple[str, str]] = [
    ("composer-2.5", "low"),
    ("composer-2.5", "medium"),
    ("composer-2.5", "high"),
    ("composer-2.5", "xhigh"),
    ("gpt-5.5", "low"),
    ("gpt-5.5", "medium"),
    ("gpt-5.5", "high"),
    ("gpt-5.5", "xhigh"),
]

# Composite slugs for Cursor Task `model` — reasoning effort is encoded in the slug,
# not a separate Task parameter. Keys are (ladder_model, reasoning_effort).
CURSOR_TASK_SLUG_MAP: dict[tuple[str, str], str] = {
    ("composer-2.5", "low"): "composer-2.5",
    ("composer-2.5", "medium"): "composer-2.5",
    ("composer-2.5", "high"): "composer-2.5",
    ("composer-2.5", "xhigh"): "composer-2.5",
    ("gpt-5.5", "low"): "gpt-5.5",
    # Host model-lock substitution: gpt-5.5-medium/high/xhigh are not selectable in Task.
    ("gpt-5.5", "medium"): "gpt-5.5-extra-high",
    ("gpt-5.5", "high"): "gpt-5.5-extra-high",
    ("gpt-5.5", "xhigh"): "gpt-5.5-extra-high",
}

# Native cursor-agent TUI slugs (CURSOR_AGENT_MODEL). Same-family effort levels
# (e.g. gpt-5.5-high) are available here but not in the Task model enum.
CURSOR_AGENT_MODEL_MAP: dict[tuple[str, str], str] = {
    ("composer-2.5", "low"): "composer-2.5",
    ("composer-2.5", "medium"): "composer-2.5",
    ("composer-2.5", "high"): "composer-2.5",
    ("composer-2.5", "xhigh"): "composer-2.5",
    ("gpt-5.5", "low"): "gpt-5.5",
    ("gpt-5.5", "medium"): "gpt-5.5-medium",
    ("gpt-5.5", "high"): "gpt-5.5-high",
    ("gpt-5.5", "xhigh"): "gpt-5.5-xhigh",
}

RFL_AGENT_CURSOR_PHASES = frozenset({"review", "verify_1", "verify_2"})

CLAUDE_FALLBACK_MODELS = (
    "claude-sonnet-4-6",
    "claude-opus-4-7",
    "claude-opus-4-8",
)

CODEX_FALLBACK_MODELS = ("gpt-5.4", "gpt-5.5")


def detect_host() -> str:
    runtime = os.environ.get("SILVER_BULLET_RUNTIME", "").strip().lower()
    if runtime in {"claude", "codex", "cursor"}:
        return runtime

    if any(
        os.environ.get(key)
        for key in (
            "CODEX_CI",
            "CODEX_THREAD_ID",
            "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
        )
    ):
        return "codex"

    if os.environ.get("CURSOR_PLUGIN_ROOT"):
        return "cursor"

    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if plugin_root:
        if "/.codex/" in plugin_root:
            return "codex"
        if "/.cursor/" in plugin_root:
            return "cursor"

    return "claude"


def reasoning_levels_for_model(model: dict[str, Any]) -> list[str]:
    levels = [
        entry.get("effort", "")
        for entry in model.get("supported_reasoning_levels", [])
        if isinstance(entry, dict) and entry.get("effort")
    ]
    ordered = [level for level in REASONING_ORDER if level in levels]
    return ordered or list(REASONING_ORDER)


def expand_model_rungs(models: list[str], reasoning_levels: list[str]) -> list[dict[str, str]]:
    rungs: list[dict[str, str]] = []
    for model in models:
        for reasoning in reasoning_levels:
            rungs.append({"model": model, "reasoning": reasoning})
    return rungs


def cursor_task_slug(model: str, reasoning: str) -> str:
    key = (model, reasoning)
    if key in CURSOR_TASK_SLUG_MAP:
        return CURSOR_TASK_SLUG_MAP[key]
    if reasoning in {"", "low"}:
        return model
    if reasoning == "xhigh":
        return f"{model}-extra-high"
    return f"{model}-{reasoning}"


def cursor_agent_model(model: str, reasoning: str) -> str:
    key = (model, reasoning)
    if key in CURSOR_AGENT_MODEL_MAP:
        return CURSOR_AGENT_MODEL_MAP[key]
    if reasoning in {"", "low"}:
        return model
    if reasoning == "xhigh":
        return f"{model}-xhigh"
    return f"{model}-{reasoning}"


def cursor_rung_delegation(model: str, reasoning: str) -> str:
    """Return task when Task slug matches native agent model; else agent-cursor."""
    if cursor_task_slug(model, reasoning) == cursor_agent_model(model, reasoning):
        return "task"
    return "agent-cursor"


def enrich_cursor_rung(rung: dict[str, str]) -> dict[str, str]:
    model = rung["model"]
    reasoning = rung["reasoning"]
    enriched = dict(rung)
    enriched["delegation"] = cursor_rung_delegation(model, reasoning)
    enriched["task_slug"] = cursor_task_slug(model, reasoning)
    enriched["agent_model"] = cursor_agent_model(model, reasoning)
    return enriched


def rfl_agent_cursor_artifact_dir(rung_index: int, phase: str) -> str:
    return f".planning/agent-cursor/rfl-rung-{rung_index}-{phase}"


def rfl_delegate_paths(rung_index: int, phase: str) -> dict[str, str]:
    base = rfl_agent_cursor_artifact_dir(rung_index, phase)
    return {
        "artifact_dir": base,
        "brief_path": f"{base}/brief.md",
        "log_path": f"{base}/cursor-run.log",
        "result_path": f"{base}/result.md",
    }


def rfl_delegate_command(
    *,
    rung_index: int,
    phase: str,
    agent_model: str,
    work_dir: str = ".",
    sb_root: str = ".",
) -> str:
    paths = rfl_delegate_paths(rung_index, phase)
    brief = paths["brief_path"]
    log = paths["log_path"]
    return (
        f"CURSOR_AGENT_MODEL={agent_model} "
        f"bash scripts/agent-cursor-delegate.sh "
        f"--work-dir {work_dir} "
        f"--brief-file {brief} "
        f"--log {log} "
        f"--sb-root {sb_root}"
    )


def codex_dynamic_rungs(cache_path: Path) -> list[dict[str, str]] | None:
    if not cache_path.is_file():
        return None

    try:
        payload = json.loads(cache_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    models = payload.get("models")
    if not isinstance(models, list) or not models:
        return None

    listed = [model for model in models if model.get("visibility") == "list"]
    if not listed:
        return None

    listed.sort(key=lambda model: int(model.get("priority", 0)), reverse=True)

    # Exclude Mini and skip the globally least-capable tier (Mini when present).
    usable = [model for model in listed if model.get("slug") != CODEX_MINI_SLUG]
    if not usable:
        return None

    rungs: list[dict[str, str]] = []
    for model in usable:
        slug = str(model.get("slug", "")).strip()
        if not slug:
            continue
        for reasoning in reasoning_levels_for_model(model):
            rungs.append({"model": slug, "reasoning": reasoning})

    return rungs or None


def codex_fallback_rungs() -> list[dict[str, str]]:
    return expand_model_rungs(list(CODEX_FALLBACK_MODELS), list(REASONING_ORDER))


def claude_fallback_rungs() -> list[dict[str, str]]:
    return expand_model_rungs(list(CLAUDE_FALLBACK_MODELS), list(CLAUDE_THINKING_ORDER))


def cursor_fixed_rungs() -> list[dict[str, str]]:
    return [{"model": model, "reasoning": reasoning} for model, reasoning in CURSOR_FIXED_RUNGS]


def resolve_ladder(host: str, codex_home: Path | None = None) -> dict[str, Any]:
    host = host.lower()
    if host == "cursor":
        return {
            "host": "cursor",
            "source": "fallback",
            "rungs": [enrich_cursor_rung(rung) for rung in cursor_fixed_rungs()],
        }

    if host == "codex":
        cache_path = (codex_home or Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))) / "models_cache.json"
        dynamic = codex_dynamic_rungs(cache_path)
        if dynamic:
            return {"host": "codex", "source": "dynamic", "rungs": dynamic}
        return {"host": "codex", "source": "fallback", "rungs": codex_fallback_rungs()}

    return {
        "host": "claude",
        "source": "fallback",
        "rungs": claude_fallback_rungs(),
    }


def resolve_rung_phase(
    payload: dict[str, Any],
    rung_index: int,
    phase: str,
    *,
    work_dir: str = ".",
    sb_root: str = ".",
) -> dict[str, Any]:
    rungs = payload.get("rungs", [])
    if rung_index < 1 or rung_index > len(rungs):
        raise ValueError(f"rung index {rung_index} out of range (1..{len(rungs)})")
    if phase not in RFL_AGENT_CURSOR_PHASES:
        raise ValueError(f"unsupported phase {phase!r} (expected review|verify_1|verify_2)")

    rung = rungs[rung_index - 1]
    model = rung["model"]
    reasoning = rung["reasoning"]
    delegation = rung.get("delegation") or cursor_rung_delegation(model, reasoning)
    task_slug = rung.get("task_slug") or cursor_task_slug(model, reasoning)
    agent_model = rung.get("agent_model") or cursor_agent_model(model, reasoning)

    result: dict[str, Any] = {
        "host": payload.get("host"),
        "rung": rung_index,
        "rung_total": len(rungs),
        "phase": phase,
        "model": model,
        "reasoning": reasoning,
        "delegation": delegation,
        "task_slug": task_slug,
        "agent_model": agent_model,
    }

    if delegation == "agent-cursor":
        paths = rfl_delegate_paths(rung_index, phase)
        result.update(paths)
        result["delegate_command"] = rfl_delegate_command(
            rung_index=rung_index,
            phase=phase,
            agent_model=agent_model,
            work_dir=work_dir,
            sb_root=sb_root,
        )
    else:
        result["task_model"] = task_slug

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve review-fix ladder rungs for the active host.")
    parser.add_argument("--host", choices=("cursor", "codex", "claude"), help="Override host detection")
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument(
        "--codex-home",
        type=Path,
        help="Override CODEX_HOME for models_cache.json discovery (tests)",
    )
    parser.add_argument("--rung", type=int, help="Rung index (1-based) for phase routing output")
    parser.add_argument(
        "--phase",
        choices=sorted(RFL_AGENT_CURSOR_PHASES),
        help="Rung phase for routing (review, verify_1, verify_2)",
    )
    parser.add_argument("--work-dir", default=".", help="Target work-dir for agent-cursor delegate command")
    parser.add_argument("--sb-root", default=".", help="SB repo root for agent-cursor delegate command")
    args = parser.parse_args()

    host = args.host or detect_host()
    payload = resolve_ladder(host, codex_home=args.codex_home)

    if args.rung is not None or args.phase is not None:
        if args.rung is None or args.phase is None:
            parser.error("--rung and --phase must be used together")
        try:
            phase_payload = resolve_rung_phase(
                payload,
                args.rung,
                args.phase,
                work_dir=args.work_dir,
                sb_root=args.sb_root,
            )
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        print(json.dumps(phase_payload, indent=2))
        return 0

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"host: {payload['host']}")
    print(f"source: {payload['source']}")
    print("rungs:")
    for index, rung in enumerate(payload["rungs"], start=1):
        model = rung["model"]
        reasoning = rung["reasoning"]
        if payload["host"] == "cursor":
            delegation = rung.get("delegation") or cursor_rung_delegation(model, reasoning)
            task_slug = rung.get("task_slug") or cursor_task_slug(model, reasoning)
            agent_model = rung.get("agent_model") or cursor_agent_model(model, reasoning)
            print(
                f"  {index}. {model} / {reasoning} "
                f"(delegation: {delegation}, task: {task_slug}, agent-cursor: {agent_model})"
            )
        else:
            print(f"  {index}. {model} / {reasoning}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
