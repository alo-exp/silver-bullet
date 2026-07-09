#!/usr/bin/env python3
"""Resolve host-aware model/reasoning rungs for silver:review-fix-ladder."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

REASONING_ORDER = ("low", "medium", "high", "xhigh")
CLAUDE_THINKING_ORDER = ("medium", "high", "xhigh")
CODEX_MINI_SLUG = "gpt-5.4-mini"

DEFAULT_CURSOR_MODELS = ("composer-2.5", "grok-4.5")
DEFAULT_CURSOR_EFFORTS = ("medium", "high", "xhigh")

GROK_EFFORT_SLUGS: dict[str, str] = {
    "medium": "grok-4.5-medium",
    "high": "grok-4.5-high",
    "xhigh": "grok-4.5-xhigh",
}

KNOWN_COMPOSITE_SLUGS: frozenset[str] = frozenset(
    {
        "composer-2.5",
        *GROK_EFFORT_SLUGS.values(),
        "gpt-5.5-medium",
        "gpt-5.5-high",
        "gpt-5.5-xhigh",
    }
)

CURSOR_SB_AGENTS_DEFAULTS: dict[str, Any] = {
    "enabled": True,
    "enabled_by_user": None,
    "selected_models": list(DEFAULT_CURSOR_MODELS),
    "effort_levels": list(DEFAULT_CURSOR_EFFORTS),
    "include_fast": False,
    "include_max": False,
    "agent_name_prefix": "sb",
    "catalog_source": "agent-models+docs",
    "catalog_fetched_at": None,
    "agents_install_status": "pending",
    "agents_install_scope": None,
    "enforcement_suspended": False,
}

RFL_REVIEW_VERIFY_PHASES = frozenset({"review", "verify_1", "verify_2"})

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


def sanitize_model_for_agent_name(model: str) -> str:
    return model.replace(".", "-")


def subagent_name_for(model: str, effort: str, prefix: str = "sb") -> str:
    return f"{prefix}-{sanitize_model_for_agent_name(model)}-{effort}"


def load_json_file(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def load_cursor_sb_agents_config(project_root: Path | None = None) -> dict[str, Any]:
    config = dict(CURSOR_SB_AGENTS_DEFAULTS)
    project_root = project_root or Path.cwd()

    project_cfg_path = project_root / ".silver-bullet.json"
    project_payload = load_json_file(project_cfg_path)
    if project_payload and isinstance(project_payload.get("cursor_sb_agents"), dict):
        config.update(project_payload["cursor_sb_agents"])
    elif not project_payload or "cursor_sb_agents" not in project_payload:
        global_path = Path.home() / ".config" / "silver-bullet" / "cursor-sb-agents.json"
        global_payload = load_json_file(global_path)
        if global_payload:
            config.update(global_payload)

    models = config.get("selected_models")
    if not isinstance(models, list) or not models:
        config["selected_models"] = list(DEFAULT_CURSOR_MODELS)
    efforts = config.get("effort_levels")
    if not isinstance(efforts, list) or not efforts:
        config["effort_levels"] = list(DEFAULT_CURSOR_EFFORTS)
    return config


def load_catalog_ids(project_root: Path | None = None) -> set[str]:
    ids: set[str] = set(KNOWN_COMPOSITE_SLUGS)
    project_root = project_root or Path.cwd()
    for path in (
        project_root / ".silver-bullet" / "cursor-models-catalog.json",
        Path.home() / ".config" / "silver-bullet" / "cursor-models-catalog.json",
    ):
        payload = load_json_file(path)
        if not payload:
            continue
        models = payload.get("models")
        if isinstance(models, list):
            for entry in models:
                if isinstance(entry, dict) and entry.get("id"):
                    ids.add(str(entry["id"]))
    return ids


def resolve_model_param(model: str, effort: str, catalog_ids: set[str] | None = None) -> str:
    catalog_ids = catalog_ids or set(KNOWN_COMPOSITE_SLUGS)
    if model == "composer-2.5" or model.startswith("composer-2.5"):
        return "composer-2.5"
    if model == "grok-4.5" or (model.startswith("grok-4.5") and "fast" not in model):
        return GROK_EFFORT_SLUGS.get(effort, f"grok-4.5-{effort}")
    composite = f"{model}-{effort}"
    if composite in catalog_ids:
        return composite
    bracket = f"{model}[effort={effort}]"
    if bracket in catalog_ids:
        return bracket
    return model


def enrich_cursor_sb_rung(
    model: str,
    reasoning: str,
    *,
    prefix: str = "sb",
    catalog_ids: set[str] | None = None,
) -> dict[str, Any]:
    model_param = resolve_model_param(model, reasoning, catalog_ids)
    return {
        "model": model,
        "reasoning": reasoning,
        "delegation": "custom-subagent",
        "subagent_name": subagent_name_for(model, reasoning, prefix),
        "model_param": model_param,
        "task_slug": None,
        "agent_model": None,
    }


def cursor_sb_agents_rungs(
    config: dict[str, Any],
    *,
    catalog_ids: set[str] | None = None,
) -> list[dict[str, Any]]:
    models = [str(m) for m in config.get("selected_models", DEFAULT_CURSOR_MODELS)]
    efforts = [str(e) for e in config.get("effort_levels", DEFAULT_CURSOR_EFFORTS)]
    prefix = str(config.get("agent_name_prefix", "sb") or "sb")
    rungs: list[dict[str, Any]] = []
    for model in models:
        for effort in efforts:
            rungs.append(enrich_cursor_sb_rung(model, effort, prefix=prefix, catalog_ids=catalog_ids))
    return rungs


def agent_search_dirs(project_root: Path) -> list[Path]:
    dirs: list[Path] = []
    global_dir = Path.home() / ".cursor" / "agents"
    if global_dir.is_dir():
        dirs.append(global_dir)
    project_dir = project_root / ".cursor" / "agents"
    if project_dir.is_dir():
        dirs.append(project_dir)
    return dirs


def agent_file_exists(name: str, project_root: Path) -> bool:
    for directory in agent_search_dirs(project_root):
        if (directory / f"{name}.md").is_file():
            return True
    return False


def probe_agents_via_script(project_root: Path, config: dict[str, Any]) -> dict[str, Any] | None:
    probe = project_root / "scripts" / "lib" / "cursor-sb-agents" / "probe-global-agents.sh"
    if not probe.is_file():
        return None
    env = os.environ.copy()
    env["SB_CURSOR_SB_AGENTS_CONFIG"] = json.dumps(config)
    try:
        proc = subprocess.run(
            ["bash", str(probe), "--json", "--skip-status"],
            cwd=project_root,
            env=env,
            capture_output=True,
            text=True,
            check=False, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode not in (0, 1):
        return None
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def check_agents(config: dict[str, Any], project_root: Path) -> dict[str, Any]:
    rungs = cursor_sb_agents_rungs(config, catalog_ids=load_catalog_ids(project_root))
    expected = [r["subagent_name"] for r in rungs]
    if os.environ.get("SB_CURSOR_SB_AGENTS_SKIP_PROBE")=="1":
        probe=None
    else:
        probe=probe_agents_via_script(project_root, config)
    if probe is not None:
        found = set(probe.get("found_names", []))
        missing = [name for name in expected if name not in found]
        return {
            "ok": len(missing) == 0 and bool(probe.get("ok", False)),
            "expected_count": len(expected),
            "expected_names": expected,
            "missing": missing,
            "source": "probe-global-agents.sh",
            "probe": probe,
        }
    missing = [name for name in expected if not agent_file_exists(name, project_root)]
    return {
        "ok": len(missing) == 0,
        "expected_count": len(expected),
        "expected_names": expected,
        "missing": missing,
        "source": "inline",
    }


def agents_enforcement_required(config: dict[str, Any]) -> bool:
    if config.get("enforcement_suspended"):
        return False
    if config.get("enabled_by_user") is False:
        return False
    if config.get("enabled") is False:
        return False
    return True


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


def resolve_cursor_ladder(project_root: Path | None = None) -> dict[str, Any]:
    project_root = project_root or Path.cwd()
    config = load_cursor_sb_agents_config(project_root)
    catalog_ids = load_catalog_ids(project_root)
    rungs = cursor_sb_agents_rungs(config, catalog_ids=catalog_ids)
    agents_status = check_agents(config, project_root)
    payload: dict[str, Any] = {
        "host": "cursor",
        "source": "cursor_sb_agents",
        "total_rungs": len(rungs),
        "rungs": rungs,
        "cursor_sb_agents": config,
        "agents": agents_status,
    }
    if agents_enforcement_required(config) and not agents_status["ok"]:
        payload["agents_missing"] = True
        payload["d21_hint"] = "bash scripts/install-cursor-sb-agents.sh --fix"
    return payload


def resolve_ladder(
    host: str,
    codex_home: Path | None = None,
    project_root: Path | None = None,
) -> dict[str, Any]:
    host = host.lower()
    if host == "cursor":
        return resolve_cursor_ladder(project_root)

    if host == "codex":
        cache_path = (codex_home or Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))) / "models_cache.json"
        dynamic = codex_dynamic_rungs(cache_path)
        if dynamic:
            return {"host": "codex", "source": "dynamic", "total_rungs": len(dynamic), "rungs": dynamic}
        fallback = codex_fallback_rungs()
        return {"host": "codex", "source": "fallback", "total_rungs": len(fallback), "rungs": fallback}

    fallback = claude_fallback_rungs()
    return {
        "host": "claude",
        "source": "fallback",
        "total_rungs": len(fallback),
        "rungs": fallback,
    }


def resolve_rung_phase(
    payload: dict[str, Any],
    rung_index: int,
    phase: str,
) -> dict[str, Any]:
    rungs = payload.get("rungs", [])
    if rung_index < 1 or rung_index > len(rungs):
        raise ValueError(f"rung index {rung_index} out of range (1..{len(rungs)})")
    if phase not in RFL_REVIEW_VERIFY_PHASES:
        raise ValueError(f"unsupported phase {phase!r} (expected review|verify_1|verify_2)")

    rung = rungs[rung_index - 1]
    return {
        "host": payload.get("host"),
        "rung": rung_index,
        "rung_total": len(rungs),
        "phase": phase,
        "model": rung["model"],
        "reasoning": rung["reasoning"],
        "delegation": rung.get("delegation", "custom-subagent"),
        "subagent_name": rung.get("subagent_name"),
        "model_param": rung.get("model_param"),
        "task_slug": None,
        "agent_model": None,
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
    parser.add_argument("--project-root", type=Path, help="Project root for cursor_sb_agents config and agent checks")
    parser.add_argument("--rung", type=int, help="Rung index (1-based) for phase routing output")
    parser.add_argument(
        "--phase",
        choices=sorted(RFL_REVIEW_VERIFY_PHASES),
        help="Rung phase for routing (review, verify_1, verify_2)",
    )
    parser.add_argument("--check-agents", action="store_true", help="Check expected sb-* custom subagents exist")
    args = parser.parse_args()

    host = args.host or detect_host()
    project_root = args.project_root or Path.cwd()
    payload = resolve_ladder(host, codex_home=args.codex_home, project_root=project_root)

    if args.check_agents:
        if host != "cursor":
            print(json.dumps({"ok": True, "skipped": True, "reason": "not cursor host"}, indent=2))
            return 0
        config = load_cursor_sb_agents_config(project_root)
        status = check_agents(config, project_root)
        print(json.dumps(status, indent=2))
        return 0 if status["ok"] else 1

    if args.rung is not None or args.phase is not None:
        if args.rung is None or args.phase is None:
            parser.error("--rung and --phase must be used together")
        try:
            phase_payload = resolve_rung_phase(payload, args.rung, args.phase)
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
    print(f"total_rungs: {payload.get('total_rungs', len(payload['rungs']))}")
    print("rungs:")
    for index, rung in enumerate(payload["rungs"], start=1):
        model = rung["model"]
        reasoning = rung["reasoning"]
        if payload["host"] == "cursor":
            print(
                f"  {index}. {model} / {reasoning} "
                f"(delegation: {rung.get('delegation')}, subagent: {rung.get('subagent_name')}, "
                f"model_param: {rung.get('model_param')})"
            )
        else:
            print(f"  {index}. {model} / {reasoning}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
