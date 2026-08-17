#!/usr/bin/env python3
"""Shared library for Cursor SB custom subagents installer."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

MANAGED_MARKER = "<!-- sb-managed: cursor-sb-agents -->"
DOCS_URL = "https://cursor.com/docs/models-and-pricing.md"
DEFAULT_EFFORT_LEVELS = ["medium", "high", "xhigh"]
DEFAULT_SELECTED_MODELS = ["composer-2.5", "grok-4.5"]
# Cursor Agent CLI lists cursor-grok-4.5-{low,medium,high} (+ fast). Legacy
# grok-4.5-{medium,high,xhigh} still resolve for some efforts; grok-4.5-low does
# NOT. Prefer cursor- prefixed slugs for low/medium/high. xhigh has no
# cursor-grok-4.5-xhigh entry — keep grok-4.5-xhigh.
GROK_EFFORT_MAP = {
    "low": "cursor-grok-4.5-low",
    "medium": "cursor-grok-4.5-medium",
    "high": "cursor-grok-4.5-high",
    "xhigh": "grok-4.5-xhigh",
}
GROK_FAST_EFFORT_MAP = {
    "low": "cursor-grok-4.5-low-fast",
    "medium": "cursor-grok-4.5-medium-fast",
    "high": "cursor-grok-4.5-high-fast",
    "xhigh": "grok-4.5-fast-xhigh",
}
# Cursor Agent CLI lists cursor-grok-4.6-{low,medium,high,xhigh} (+ fast).
# Extra High is cursor-grok-4.6-xhigh (there is no unprefixed grok-4.6-xhigh).
GROK_46_EFFORT_MAP = {
    "low": "cursor-grok-4.6-low",
    "medium": "cursor-grok-4.6-medium",
    "high": "cursor-grok-4.6-high",
    "xhigh": "cursor-grok-4.6-xhigh",
}
GROK_46_FAST_EFFORT_MAP = {
    "low": "cursor-grok-4.6-low-fast",
    "medium": "cursor-grok-4.6-medium-fast",
    "high": "cursor-grok-4.6-high-fast",
    "xhigh": "cursor-grok-4.6-xhigh-fast",
}
# Families whose Cursor slugs are not `{base}-{effort}`. Config `rfl_effort_maps`
# overrides these. Never include Fast slugs here.
BUILTIN_EFFORT_MAPS = {
    "opus-5": {
        "medium": "claude-opus-5-thinking-medium",
        "high": "claude-opus-5-thinking-high",
        "xhigh": "claude-opus-5-thinking-xhigh",
        "max": "claude-opus-5-thinking-max",
    },
    "glm-5.2": {
        "high": "glm-5.2-high",
        "xhigh": "glm-5.2-max",
        "max": "glm-5.2-max",
    },
    "kimi-k3": {
        "high": "kimi-k3-high",
        "xhigh": "kimi-k3-max",
        "max": "kimi-k3-max",
    },
}

FAST_RE = re.compile(r"(?:^|-)fast(?:-|$)", re.I)
MAX_ID_RE = re.compile(r"(?:^|-)max(?:-|$)|\[context=", re.I)
LOW_SUFFIX_RE = re.compile(r"-low(?:-|$)", re.I)


def default_config() -> dict[str, Any]:
    return {
        "enabled": True,
        "enabled_by_user": None,
        "selected_models": list(DEFAULT_SELECTED_MODELS),
        "effort_levels": list(DEFAULT_EFFORT_LEVELS),
        "include_fast": False,
        "include_max": False,
        "agent_name_prefix": "sb",
        "catalog_source": "agent-models+docs",
        "catalog_fetched_at": None,
        "agents_install_status": "pending",
        "agents_install_scope": None,
        "enforcement_suspended": False,
    }


def sanitize_model(model: str) -> str:
    return model.replace(".", "-").replace("_", "-")


def agent_name(base_model: str, effort: str, prefix: str = "sb") -> str:
    return f"{prefix}-{sanitize_model(base_model)}-{effort}"


def is_fast_id(model_id: str) -> bool:
    return bool(FAST_RE.search(model_id))


def is_max_id(model_id: str, notes: str = "") -> bool:
    if MAX_ID_RE.search(model_id):
        return True
    if notes and "requires max mode" in notes.lower():
        return True
    return False


def is_low_effort_slug(model_id: str) -> bool:
    return bool(LOW_SUFFIX_RE.search(model_id))


def fetch_docs_markdown() -> str:
    req = urllib.request.Request(
        DOCS_URL,
        headers={"User-Agent": "silver-bullet/cursor-sb-agents/1.0"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8", errors="replace")


def parse_pricing_table(markdown: str) -> dict[str, dict[str, Any]]:
    """Parse docs model pricing rows into base-model entries."""
    pricing: dict[str, dict[str, Any]] = {}
    in_table = False
    for line in markdown.splitlines():
        if line.strip().startswith("| Model"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.strip().startswith("|"):
            if pricing:
                break
            continue
        if re.match(r"^\|\s*-+", line):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) < 6:
            continue
        raw_name, provider, inp, cache_write, cache_read, out = cols[:6]
        notes = cols[6] if len(cols) > 6 else ""
        link_match = re.search(r"\[([^\]]+)\]", raw_name)
        display_name = link_match.group(1) if link_match else raw_name.strip()
        base_id = slugify_display_name(display_name)
        if not base_id or base_id == "auto":
            continue
        pricing[base_id] = {
            "id": base_id,
            "display_name": display_name,
            "provider": provider,
            "pool": pool_for_provider(provider),
            "pricing": {
                "input": parse_price(inp),
                "cache_write": parse_price(cache_write),
                "cache_read": parse_price(cache_read),
                "output": parse_price(out),
                "unit": "per_1M",
            },
            "notes": notes,
        }
    return pricing


def slugify_display_name(name: str) -> str:
    n = name.strip().lower()
    n = n.replace("cursor ", "")
    replacements = {
        "composer 2.5": "composer-2.5",
        "composer 1": "composer-1",
        "grok 4.5": "grok-4.5",
        "gpt-5.5": "gpt-5.5",
        "gpt-5.2": "gpt-5.2",
        "gpt-5.3-codex": "gpt-5.3-codex",
    }
    if n in replacements:
        return replacements[n]
    slug = re.sub(r"[^a-z0-9]+", "-", n).strip("-")
    return slug


def parse_price(value: str) -> float | None:
    value = value.strip()
    if not value or value == "-":
        return None
    m = re.search(r"\$?([\d.]+)", value)
    return float(m.group(1)) if m else None


def pool_for_provider(provider: str) -> str:
    if provider.strip().lower() == "cursor":
        return "first-party"
    return "api"


def run_agent_models() -> tuple[list[dict[str, str]], str]:
    for cmd in (["agent", "models"], ["cursor-agent", "models"]):
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
                timeout=120,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
        if proc.returncode != 0:
            continue
        entries = parse_agent_models_output(proc.stdout)
        if entries:
            return entries, cmd[0]
    return [], ""


def parse_agent_models_output(text: str) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.lower().startswith("available models"):
            continue
        if " - " not in line:
            continue
        model_id, display = line.split(" - ", 1)
        model_id = model_id.strip()
        if model_id == "auto":
            continue
        entries.append({"id": model_id, "display_name": display.strip()})
    return entries


def base_model_from_slug(model_id: str) -> str:
    if model_id.startswith("composer-"):
        if is_fast_id(model_id):
            return model_id.split("-fast", 1)[0]
        return model_id
    # Normalize both cursor-grok-4.5-* and legacy grok-4.5-* to base grok-4.5
    if model_id.startswith("cursor-grok-4.5") or model_id.startswith("grok-4.5"):
        return "grok-4.5"
    if model_id.startswith("cursor-grok-4.6") or model_id.startswith("grok-4.6"):
        return "grok-4.6"
    for effort in (
        "thinking-max",
        "thinking-xhigh",
        "thinking-high",
        "thinking-medium",
        "thinking-low",
        "xhigh",
        "extra-high",
        "high",
        "medium",
        "low",
        "none",
        "max",
    ):
        suffix = f"-{effort}"
        if model_id.endswith(suffix):
            return model_id[: -len(suffix)]
        fast_suffix = f"-fast{suffix}"
        if model_id.endswith(fast_suffix):
            return model_id[: -len(fast_suffix)]
    if "[" in model_id:
        return model_id.split("[", 1)[0]
    return model_id


def effort_from_slug(model_id: str, base: str) -> str | None:
    if base == "composer-2.5" or base.startswith("composer-"):
        return None
    if base == "grok-4.5":
        for effort, slug in GROK_EFFORT_MAP.items():
            if model_id == slug:
                return effort
        for effort, slug in GROK_FAST_EFFORT_MAP.items():
            if model_id == slug:
                return effort
        # Legacy aliases still seen in older agent defs / probes
        legacy = {
            "grok-4.5-medium": "medium",
            "grok-4.5-high": "high",
            "grok-4.5-xhigh": "xhigh",
            "grok-4.5-fast-medium": "medium",
            "grok-4.5-fast-high": "high",
            "grok-4.5-fast-xhigh": "xhigh",
        }
        if model_id in legacy:
            return legacy[model_id]
        return None
    if base == "grok-4.6":
        for effort, slug in GROK_46_EFFORT_MAP.items():
            if model_id == slug:
                return effort
        for effort, slug in GROK_46_FAST_EFFORT_MAP.items():
            if model_id == slug:
                return effort
        return None
    remainder = model_id[len(base) :].lstrip("-")
    if remainder.startswith("fast-"):
        remainder = remainder[5:]
    mapping = {
        "xhigh": "xhigh",
        "extra-high": "xhigh",
        "high": "high",
        "medium": "medium",
        "low": "low",
        "none": "medium",
        "max": "max",
        "thinking-max": "max",
        "thinking-xhigh": "xhigh",
        "thinking-high": "high",
        "thinking-medium": "medium",
        "thinking-low": "low",
    }
    return mapping.get(remainder)


def build_catalog(
    docs_pricing: dict[str, dict[str, Any]],
    agent_entries: list[dict[str, str]],
) -> dict[str, Any]:
    agent_by_id = {e["id"]: e for e in agent_entries}
    bases: dict[str, dict[str, Any]] = {}

    for entry in agent_entries:
        model_id = entry["id"]
        base = base_model_from_slug(model_id)
        if base not in bases:
            doc = docs_pricing.get(base, {})
            bases[base] = {
                "id": base,
                "display_name": doc.get("display_name", base),
                "provider": doc.get("provider", "Unknown"),
                "pool": doc.get("pool", "api"),
                "pricing": doc.get(
                    "pricing",
                    {
                        "input": None,
                        "cache_write": None,
                        "cache_read": None,
                        "output": None,
                        "unit": "per_1M",
                    },
                ),
                "effort_values": [],
                "agent_ids": [],
                "fast_available": False,
                "max_detected": False,
                "notes": doc.get("notes", ""),
            }
        bases[base]["agent_ids"].append(model_id)
        if is_fast_id(model_id):
            bases[base]["fast_available"] = True
        notes = docs_pricing.get(base, {}).get("notes", "")
        if is_max_id(model_id, notes):
            bases[base]["max_detected"] = True
        effort = effort_from_slug(model_id, base)
        if effort and effort not in bases[base]["effort_values"]:
            bases[base]["effort_values"].append(effort)

    for base, doc in docs_pricing.items():
        if base not in bases:
            bases[base] = {
                "id": base,
                "display_name": doc["display_name"],
                "provider": doc["provider"],
                "pool": doc["pool"],
                "pricing": doc["pricing"],
                "effort_values": [],
                "agent_ids": [],
                "fast_available": False,
                "max_detected": is_max_id(base, doc.get("notes", "")),
                "notes": doc.get("notes", ""),
            }

    for base in bases:
        if base.startswith("composer-"):
            bases[base]["effort_values"] = list(DEFAULT_EFFORT_LEVELS)
        elif base in ("grok-4.5", "grok-4.6"):
            bases[base]["effort_values"] = list(DEFAULT_EFFORT_LEVELS)
        else:
            ev = [e for e in bases[base]["effort_values"] if e != "low"]
            bases[base]["effort_values"] = sorted(
                ev,
                key=lambda x: DEFAULT_EFFORT_LEVELS.index(x)
                if x in DEFAULT_EFFORT_LEVELS
                else 99,
            )

    return {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "source": "agent-models+docs" if agent_entries else "docs-only",
        "agent_cli": "agent" if agent_entries else None,
        "models": sorted(bases.values(), key=lambda m: m["id"]),
    }


def filter_selectable_models(
    catalog: dict[str, Any],
    include_fast: bool = False,
    include_max: bool = False,
) -> list[dict[str, Any]]:
    selectable: list[dict[str, Any]] = []
    for model in catalog.get("models", []):
        base_id = model["id"]
        if base_id == "auto":
            continue
        if model.get("max_detected") and not include_max:
            continue
        if is_max_id(base_id, model.get("notes", "")) and not include_max:
            continue
        if model.get("fast_available") and is_fast_id(base_id) and not include_fast:
            continue
        if not model.get("agent_ids") and catalog.get("source") != "docs-only":
            continue
        selectable.append(model)
    return selectable


def resolve_model_param(
    base_model: str,
    effort: str,
    catalog: dict[str, Any] | None = None,
    include_fast: bool = False,
    config: dict[str, Any] | None = None,
) -> str:
    maps: dict[str, dict[str, str]] = dict(BUILTIN_EFFORT_MAPS)
    if config:
        maps.update(config.get("rfl_effort_maps") or {})
    if base_model in maps and effort in maps[base_model]:
        return maps[base_model][effort]

    if base_model.startswith("composer-"):
        if include_fast and base_model.endswith("-fast"):
            return base_model
        return "composer-2.5" if base_model.startswith("composer-2") else base_model

    if base_model == "grok-4.5":
        if include_fast:
            return GROK_FAST_EFFORT_MAP.get(effort, f"grok-4.5-fast-{effort}")
        return GROK_EFFORT_MAP.get(effort, f"grok-4.5-{effort}")

    if base_model == "grok-4.6":
        if include_fast:
            return GROK_46_FAST_EFFORT_MAP.get(effort, f"cursor-grok-4.6-{effort}-fast")
        return GROK_46_EFFORT_MAP.get(effort, f"cursor-grok-4.6-{effort}")

    composite = f"{base_model}-{effort}"
    if include_fast:
        fast_composite = f"{base_model}-fast-{effort}"
        if catalog and id_in_catalog(fast_composite, catalog):
            return fast_composite

    if catalog and id_in_catalog(composite, catalog):
        return composite

    bracket = f"{base_model}[effort={effort}]"
    if catalog and id_in_catalog(bracket, catalog):
        return bracket

    if catalog:
        for entry in catalog.get("models", []):
            if entry["id"] == base_model and entry.get("agent_ids"):
                return entry["agent_ids"][0]
    return base_model


def id_in_catalog(model_id: str, catalog: dict[str, Any]) -> bool:
    for entry in catalog.get("models", []):
        if model_id in entry.get("agent_ids", []):
            return True
        if entry["id"] == model_id:
            return True
    return False


def efforts_for_model(config: dict[str, Any], model: str) -> list[str]:
    maps = config.get("rfl_effort_maps") or {}
    if model in maps and maps[model]:
        return list(maps[model].keys())
    levels = list(config.get("effort_levels", DEFAULT_EFFORT_LEVELS))
    builtin = BUILTIN_EFFORT_MAPS.get(model, {})
    if config.get("include_max") and "max" in builtin and "max" not in levels:
        levels = [*levels, "max"]
    return levels


def expected_agent_names(config: dict[str, Any]) -> list[str]:
    prefix = config.get("agent_name_prefix", "sb")
    names: list[str] = []
    for model in config.get("selected_models", []):
        for effort in efforts_for_model(config, model):
            names.append(agent_name(model, effort, prefix))
    return names


def expected_model_params(config: dict[str, Any], catalog: dict[str, Any]) -> dict[str, str]:
    params: dict[str, str] = {}
    include_fast = bool(config.get("include_fast"))
    for model in config.get("selected_models", []):
        for effort in efforts_for_model(config, model):
            name = agent_name(model, effort, config.get("agent_name_prefix", "sb"))
            params[name] = resolve_model_param(
                model, effort, catalog, include_fast, config
            )
    return params


def format_pricing_label(model: dict[str, Any]) -> str:
    p = model.get("pricing", {})
    inp = p.get("input")
    cache = p.get("cache_read")
    out = p.get("output")
    parts: list[str] = []
    if inp is not None:
        parts.append(f"${inp:.2f} in")
    if cache is not None:
        parts.append(f"${cache:.2f} cache")
    if out is not None:
        parts.append(f"${out:.2f} out")
    suffix = f" ({model.get('pool', 'api')})" if parts else ""
    return " / ".join(parts) + suffix + " (per 1M)" if parts else model.get("pool", "")


def render_agent_markdown(
    agent_name_value: str,
    base_model: str,
    effort: str,
    model_param: str,
    template: str,
) -> str:
    label = "opus-5 thinking" if base_model == "opus-5" else base_model
    mapped = ""
    if effort == "xhigh" and model_param.endswith("-max"):
        mapped = " (mapped to max)"
    description = (
        f"SB reusable ladder agent — {label} effort={effort}{mapped}"
        + (f" (Cursor slug {model_param})." if model_param != base_model else ".")
    )
    if base_model == "opus-5" or mapped:
        body = (
            f"You are a Silver Bullet reusable review/verify agent at {label} effort={effort}{mapped}.\n"
            "Follow the brief: review-only or verify-only as instructed. Do not triage or fix unless the brief says incorporate/fix."
        )
    else:
        body = (
            f"You are a Silver Bullet reusable review/verify agent at {label} / {effort}.\n"
            "Follow the brief: review-only or verify-only as instructed. Do not triage or fix."
        )
    content = template.replace("{{AGENT_NAME}}", agent_name_value)
    content = content.replace("{{DESCRIPTION}}", description)
    content = content.replace("{{MODEL_PARAM}}", model_param)
    content = content.replace("{{BODY}}", body)
    if MANAGED_MARKER not in content:
        content = content.rstrip() + "\n" + MANAGED_MARKER + "\n"
    return content


def load_json(path: Path | str) -> dict[str, Any]:
    p = Path(path) if not isinstance(path, Path) else path
    if not p.is_file():
        return {}
    with p.open(encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path | str, data: dict[str, Any]) -> None:
    p = Path(path) if not isinstance(path, Path) else path
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def fetch_and_cache_catalog(
    global_cache: Path,
    project_cache: Path | None = None,
) -> dict[str, Any]:
    try:
        markdown = fetch_docs_markdown()
        docs_pricing = parse_pricing_table(markdown)
    except (urllib.error.URLError, TimeoutError) as exc:
        print(f"WARN: docs fetch failed: {exc}", file=sys.stderr)
        docs_pricing = {}

    agent_entries, cli = run_agent_models()
    catalog = build_catalog(docs_pricing, agent_entries)
    catalog["agent_cli"] = cli or catalog.get("agent_cli")

    write_json(global_cache, catalog)
    if project_cache:
        write_json(project_cache, catalog)
    return catalog


def frontmatter_name(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    block = text[3:end]
    for line in block.splitlines():
        if line.startswith("name:"):
            return line.split(":", 1)[1].strip()
    return None


def has_managed_marker(path: Path) -> bool:
    try:
        return MANAGED_MARKER in path.read_text(encoding="utf-8")
    except OSError:
        return False


