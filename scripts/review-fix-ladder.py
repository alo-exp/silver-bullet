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
    # Host model-lock substitution: gpt-5.5-medium/high are not selectable in Cursor.
    ("gpt-5.5", "medium"): "gpt-5.5-extra-high",
    ("gpt-5.5", "high"): "gpt-5.5-extra-high",
    ("gpt-5.5", "xhigh"): "gpt-5.5-extra-high",
}

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
            "rungs": cursor_fixed_rungs(),
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve review-fix ladder rungs for the active host.")
    parser.add_argument("--host", choices=("cursor", "codex", "claude"), help="Override host detection")
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument(
        "--codex-home",
        type=Path,
        help="Override CODEX_HOME for models_cache.json discovery (tests)",
    )
    args = parser.parse_args()

    host = args.host or detect_host()
    payload = resolve_ladder(host, codex_home=args.codex_home)

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"host: {payload['host']}")
    print(f"source: {payload['source']}")
    print("rungs:")
    for index, rung in enumerate(payload["rungs"], start=1):
        slug = cursor_task_slug(rung["model"], rung["reasoning"])
        if slug != rung["model"] or rung["reasoning"] != "low":
            print(f"  {index}. {rung['model']} / {rung['reasoning']} (cursor slug: {slug})")
        else:
            print(f"  {index}. {rung['model']} / {rung['reasoning']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
