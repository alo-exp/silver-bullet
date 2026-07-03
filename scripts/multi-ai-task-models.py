#!/usr/bin/env python3
"""Resolve host-aware medium-reasoning models for silver:multi-ai.

Uses the same model inventory as silver:review-fix-ladder (review-fix-ladder.py)
but pins reasoning effort to medium only. When OpenCode Go (OCG) is available,
includes OCG models from ~/.config/opencode/opencode.json(c) agent entries.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
_LADDER_PATH = _SCRIPT_DIR / "review-fix-ladder.py"
_spec = importlib.util.spec_from_file_location("review_fix_ladder", _LADDER_PATH)
if _spec is None or _spec.loader is None:
    raise RuntimeError(f"unable to load {_LADDER_PATH}")
_ladder = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ladder)

cursor_task_slug = _ladder.cursor_task_slug
detect_host = _ladder.detect_host
resolve_ladder = _ladder.resolve_ladder

MEDIUM = "medium"
OCG_PREFIX = "opencode-go/"

# OCG-Lite: budget-friendly model replacements.
# Keys are the full OCG model refs from the standard set;
# values are their lite replacements. Models mapped to None are excluded.
OCG_LITE_MODEL_MAP: dict[str, str | None] = {
    "opencode-go/minimax-m3": "opencode-go/minimax-m3",
    "opencode-go/qwen3.7-max": "opencode-go/qwen3.7-plus",
    "opencode-go/deepseek-v4-pro": "opencode-go/deepseek-v4-flash",
    "opencode-go/glm-5.2": None,
    "opencode-go/kimi-k2.6": "opencode-go/kimi-k2.7-code",
    "opencode-go/mimo-v2.5-pro": "opencode-go/mimo-v2.5",
}


def _load_opencode_config() -> dict[str, Any] | None:
    config_dir = Path(os.environ.get("OPENCODE_CONFIG_DIR", Path.home() / ".config" / "opencode"))
    for name in ("opencode.jsonc", "opencode.json"):
        path = config_dir / name
        if not path.is_file():
            continue
        raw = path.read_text(encoding="utf-8")
        # Strip // and /* */ comments for jsonc.
        raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.DOTALL)
        raw = re.sub(r"//[^\n]*", "", raw)
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    return None


def ocg_models_from_config(config: dict[str, Any]) -> list[dict[str, str]]:
    agents = config.get("agent")
    if not isinstance(agents, dict):
        return []

    models: list[dict[str, str]] = []
    seen: set[str] = set()
    for agent_name, agent_cfg in agents.items():
        if not isinstance(agent_cfg, dict):
            continue
        model_ref = agent_cfg.get("model")
        if not isinstance(model_ref, str) or not model_ref.strip():
            continue
        model_ref = model_ref.strip()
        if not model_ref.startswith(OCG_PREFIX):
            continue
        if model_ref in seen:
            continue
        seen.add(model_ref)
        models.append(
            {
                "model": model_ref,
                "reasoning": MEDIUM,
                "source": "ocg-config",
                "agent": str(agent_name),
            }
        )
    return models


def medium_rungs_from_ladder(host: str, codex_home: Path | None = None) -> list[dict[str, str]]:
    ladder = resolve_ladder(host, codex_home=codex_home)
    rungs: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for rung in ladder.get("rungs", []):
        if rung.get("reasoning") != MEDIUM:
            continue
        model = str(rung.get("model", "")).strip()
        if not model:
            continue
        key = (model, MEDIUM)
        if key in seen:
            continue
        seen.add(key)
        rungs.append({"model": model, "reasoning": MEDIUM, "source": ladder.get("source", "ladder")})
    return rungs


def apply_lite_mapping(models: list[dict[str, str]]) -> list[dict[str, str]]:
    mapped: list[dict[str, str]] = []
    for entry in models:
        model = entry["model"]
        if model in OCG_LITE_MODEL_MAP:
            replacement = OCG_LITE_MODEL_MAP[model]
            if replacement is None:
                continue
            mapped.append({**entry, "model": replacement, "source": "ocg-lite"})
        else:
            mapped.append(entry)
    return mapped


def resolve_multi_ai_models(host: str, codex_home: Path | None = None, *, lite: bool = False) -> dict[str, Any]:
    host = host.lower()
    ladder_models = medium_rungs_from_ladder(host, codex_home=codex_home)
    ocg_models: list[dict[str, str]] = []
    config = _load_opencode_config()
    if config:
        ocg_models = ocg_models_from_config(config)

    # OCG plan: when Kay/OpenCode agents exist, prefer them for parallel dispatch.
    if ocg_models:
        primary = ocg_models
        secondary = [m for m in ladder_models if m["model"] not in {o["model"] for o in ocg_models}]
        models = primary + secondary
        plan = "ocg-primary"
    else:
        models = ladder_models
        plan = "ladder-medium-only"

    if lite:
        models = apply_lite_mapping(models)
        plan = "ocg-lite"

    return {
        "host": host,
        "plan": plan,
        "reasoning": MEDIUM,
        "models": models,
        "ocg_prerequisite": (
            "When using OpenCode Go (Mechanism 1), define one subagent per model in "
            "~/.config/opencode/opencode.json(c) under agent.<name>.model (e.g. "
            "opencode-go/minimax-m3) and allow it in permission.task. "
            "See skills/silver-multi-ai/rules/dispatch-mechanics.md."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Resolve silver:multi-ai models (medium reasoning, ladder-aligned)."
    )
    parser.add_argument("--host", choices=("cursor", "codex", "claude"), help="Override host detection")
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument("--codex-home", type=Path, help="Override CODEX_HOME (tests)")
    parser.add_argument("--lite", action="store_true", help="OCG-Lite: budget-friendly model replacements")
    args = parser.parse_args()

    host = args.host or detect_host()
    payload = resolve_multi_ai_models(host, codex_home=args.codex_home, lite=args.lite)

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"host: {payload['host']}")
    print(f"plan: {payload['plan']}")
    print(f"reasoning: {payload['reasoning']}")
    print("models:")
    for index, entry in enumerate(payload["models"], start=1):
        model = entry["model"]
        slug = cursor_task_slug(model, MEDIUM) if payload["host"] == "cursor" else model
        extra = f" (cursor slug: {slug})" if slug != model else ""
        print(f"  {index}. {model} / {MEDIUM} [{entry.get('source', '?')}]{extra}")
    print(f"ocg_prerequisite: {payload['ocg_prerequisite']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
