#!/usr/bin/env python3
"""Deterministic MultAI-parity landscape synthesis from DR-multi-AI envelopes."""

from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path
from typing import Any

from compression_markers import assert_no_compression_markers, sanitize_compression_markers
from category_pack import (
    apply_parent_child_dedupe,
    build_known_solutions,
    build_license_by_slug,
    build_overview_seeds,
    catalog_entries_from_pack,
    format_inclusion_criteria_prose,
    get_markets,
    get_primary_market_id,
    market_slug_sets,
    resolve_pack_from_need,
)
from materialize_solution_artifacts import (
    KNOWN_SOLUTIONS,
    OVERVIEW_SEEDS,
    _effective_known_solutions,
    _effective_overview_seeds,
    _iter_claim_texts,
    discover_solutions,
    is_matrix_dump_claim,
    is_unusable_overview_claim,
)
from vendor_link_labels import (
    filter_vendor_link_pairs,
    is_generic_link_label,
    resolve_vendor_link_label,
)

SECTION_TITLES = [
    "Market Definition & Scope",
    "Market Overview",
    "Competitive Positioning — Analyst Frameworks",
    "Key Industry Trends",
    "Top Commercial Solutions for SMBs",
    "Top Open Source Solutions",
    "Adjacent Markets",
    "Explicitly Excluded",
    "Buying Guidance & Shortlist Profiles",
    "Future Outlook & Emerging Disruptors",
    "Source Reliability Assessment",
]

# Legacy catalogs retained for fallback when no category pack is active.
COMMERCIAL_CATALOG: list[dict[str, str]] = [
    {"slug": "factory-ai", "name": "Factory.ai", "url": "https://www.factory.ai/"},
    {"slug": "devin", "name": "Devin (Cognition)", "url": "https://devin.ai/"},
    {"slug": "github-copilot-workspace", "name": "GitHub Copilot Workspace", "url": "https://githubnext.com/projects/copilot-workspace"},
    {"slug": "cursor-agents", "name": "Cursor Background Agents", "url": "https://cursor.com/docs/background-agent"},
    {"slug": "sweep-ai", "name": "Sweep", "url": "https://sweep.dev/"},
    {"slug": "tembo", "name": "Tembo", "url": "https://tembo.io/"},
    {"slug": "replit-agent", "name": "Replit Agent", "url": "https://replit.com/"},
    {"slug": "windsurf", "name": "Windsurf (Codeium)", "url": "https://codeium.com/windsurf"},
    {"slug": "tabnine-enterprise", "name": "Tabnine Enterprise", "url": "https://www.tabnine.com/"},
    {"slug": "amazon-q-developer", "name": "Amazon Q Developer", "url": "https://aws.amazon.com/q/developer/"},
    {"slug": "sourcegraph-cody", "name": "Sourcegraph Cody", "url": "https://sourcegraph.com/cody"},
    {"slug": "augment-code", "name": "Augment Code", "url": "https://www.augmentcode.com/"},
    {"slug": "magic-dev", "name": "Magic.dev", "url": "https://magic.dev/"},
    {"slug": "poolside", "name": "Poolside", "url": "https://poolside.ai/"},
    {"slug": "coderabbit", "name": "CodeRabbit", "url": "https://coderabbit.ai/"},
    {"slug": "jetbrains-ai", "name": "JetBrains AI Assistant", "url": "https://www.jetbrains.com/ai/"},
    {"slug": "github-copilot-enterprise", "name": "GitHub Copilot Enterprise", "url": "https://github.com/features/copilot"},
    {"slug": "cognition-scout", "name": "Cognition Scout", "url": "https://cognition.ai/"},
    {"slug": "linear-agent", "name": "Linear Agent Integrations", "url": "https://linear.app/"},
]

# OSS / emerging — not commercial SMB catalog (Silver Bullet is open-source orchestration)
EMERGING_CATALOG: list[dict[str, str]] = [
    {"slug": "silver-bullet", "name": "Silver Bullet", "license": "Open Source", "url": "https://sb.alolabs.dev/"},
]

OSS_CATALOG: list[dict[str, str]] = [
    {"slug": "openhands", "name": "OpenHands", "license": "MIT", "url": "https://github.com/All-Hands-AI/OpenHands"},
    {"slug": "langgraph-platform", "name": "LangGraph Platform", "license": "Open Core", "url": "https://www.langchain.com/langgraph"},
    {"slug": "crewai", "name": "CrewAI", "license": "MIT", "url": "https://github.com/crewAIInc/crewAI"},
    {"slug": "metagpt", "name": "MetaGPT", "license": "MIT", "url": "https://github.com/FoundationAgents/MetaGPT"},
    {"slug": "spec-kit", "name": "GitHub spec-kit", "license": "MIT", "url": "https://github.com/github/spec-kit"},
    {"slug": "cline", "name": "Cline", "license": "Apache 2.0", "url": "https://github.com/cline/cline"},
    {"slug": "continue", "name": "Continue", "license": "Apache 2.0", "url": "https://github.com/continuedev/continue"},
    {"slug": "autogen", "name": "Microsoft AutoGen", "license": "MIT", "url": "https://github.com/microsoft/autogen"},
    {"slug": "gsd", "name": "GSD (Get Shit Done)", "license": "MIT", "url": "https://github.com/gsd-build/get-shit-done"},
    {"slug": "bmad-method", "name": "BMAD-METHOD", "license": "MIT", "url": "https://github.com/bmad-code-org/BMAD-METHOD"},
    {"slug": "aider", "name": "Aider", "license": "Apache 2.0", "url": "https://github.com/paul-gauthier/aider"},
    {"slug": "swe-agent", "name": "SWE-agent", "license": "MIT", "url": "https://github.com/SWE-agent/SWE-agent"},
    {"slug": "semantic-kernel", "name": "Semantic Kernel", "license": "MIT", "url": "https://github.com/microsoft/semantic-kernel"},
    {"slug": "gpt-engineer", "name": "GPT-Engineer", "license": "MIT", "url": "https://github.com/gpt-engineer-org/gpt-engineer"},
    {"slug": "praisonai", "name": "PraisonAI", "license": "MIT", "url": "https://github.com/MervinPraison/PraisonAI"},
    {"slug": "superagent", "name": "Superagent", "license": "MIT", "url": "https://github.com/homanp/superagent"},
    {"slug": "agentgpt", "name": "AgentGPT", "license": "GPL-3.0", "url": "https://github.com/reworkd/AgentGPT"},
    {"slug": "langchain", "name": "LangChain", "license": "MIT", "url": "https://github.com/langchain-ai/langchain"},
    {"slug": "open-interpreter", "name": "Open Interpreter", "license": "AGPL-3.0", "url": "https://github.com/OpenInterpreter/open-interpreter"},
    {"slug": "devika", "name": "Devika", "license": "MIT", "url": "https://github.com/stitionai/devika"},
]

def _resolve_catalogs(
    need: dict[str, Any],
    envelopes: list[dict[str, Any]],
    audit: dict[str, Any] | None = None,
) -> tuple[list[dict[str, str]], list[dict[str, str]], dict[str, Any]]:
    """Return (commercial_catalog, oss_catalog, audit) from pack classifier or legacy fallback."""
    pack = resolve_pack_from_need(need)
    if pack:
        if audit is None:
            from solution_classifier import classify_solutions

            audit = classify_solutions(envelopes, need, pack)
        matrix = list(audit.get("matrix_slugs") or audit.get("core") or [])
        matrix = apply_parent_child_dedupe(matrix, pack)
        commercial, oss = catalog_entries_from_pack(pack, matrix)
        return commercial, oss, audit
    return list(COMMERCIAL_CATALOG), list(OSS_CATALOG) + list(EMERGING_CATALOG), audit or {}


COMMERCIAL_SLUGS: frozenset[str] = frozenset(e["slug"] for e in COMMERCIAL_CATALOG)
OSS_SLUGS: frozenset[str] = frozenset(e["slug"] for e in OSS_CATALOG)
EMERGING_SLUGS: frozenset[str] = frozenset(e["slug"] for e in EMERGING_CATALOG)
NON_COMMERCIAL_SLUGS: frozenset[str] = OSS_SLUGS | EMERGING_SLUGS


def _known_for_need(need: dict[str, Any]) -> dict[str, str]:
    return _effective_known_solutions(need)


def _overview_for_need(need: dict[str, Any]) -> dict[str, str]:
    return _effective_overview_seeds(need)


def vendor_license_bucket(
    slug: str,
    *,
    fallback: str = "commercial",
    license_map: dict[str, str] | None = None,
) -> str:
    """Classify solution slug for landscape vendor panels (SB is permanently non-commercial)."""
    if license_map and license_map.get(slug) == "oss":
        return "oss"
    if slug in NON_COMMERCIAL_SLUGS:
        return "oss"
    if slug in COMMERCIAL_SLUGS:
        return "commercial"
    if license_map and license_map.get(slug) in {"commercial", "mixed", "unknown"}:
        return "commercial"
    return fallback


TREND_SEEDS: list[dict[str, str]] = [
    {
        "title": "Process-first orchestration above coding agents",
        "what": "Buyers increasingly separate the agent host (IDE, cloud sandbox) from the SDLC process layer that composes workflows, enforces gates, and records skills.",
        "smb": "SMBs without platform teams need opinionated process packs rather than bespoke agent graphs.",
        "vendor": "Silver Bullet, Factory.ai, and GitHub Copilot Workspace market explicit SDLC chains; Cursor and Devin remain executor-first.",
    },
    {
        "title": "Hook-enforced lifecycle gates",
        "what": "Host hooks that fail closed on skill recording, planning ownership, and delivery gates are emerging as trust rails for autonomous work.",
        "smb": "Reduces rework risk when junior teams delegate multi-step agent runs.",
        "vendor": "Silver Bullet and Cursor document hook layers; most git-native agents lack cross-host gate parity.",
    },
    {
        "title": "Machine-readable workflow catalogs",
        "what": "Atomic flow catalogs (workflows, steps, V-loops) enable composition, audit, and CI freshness checks beyond ad-hoc prompts.",
        "smb": "Lets lean teams adopt SDLC patterns without writing orchestration code.",
        "vendor": "Silver Bullet ships `apo-catalog.json`; spec-kit and GSD offer lighter-weight spec packs.",
    },
    {
        "title": "Git-native issue→PR agent loops",
        "what": "Issue trackers and repos become control planes for multi-step agent work with human review on PRs.",
        "smb": "Fits teams already on GitHub; lowers integration tax versus custom runtimes.",
        "vendor": "GitHub Copilot Workspace, Sweep, and Tembo target this pattern.",
    },
    {
        "title": "Autonomous software engineers (plan→ship)",
        "what": "Managed agents that plan, implement, test, and open PRs in customer repos are maturing for enterprise pilots.",
        "smb": "High capability but opaque process; pricing and governance remain enterprise-weighted.",
        "vendor": "Devin, Factory.ai Droids, and Magic.dev compete here.",
    },
    {
        "title": "BYO agent runtimes and graph orchestration",
        "what": "Frameworks expose durable graphs, interrupts, and delegation primitives for custom orchestration.",
        "smb": "Maximum flexibility at the cost of in-house agent ops expertise.",
        "vendor": "LangGraph Platform, CrewAI, MetaGPT, and AutoGen anchor this segment.",
    },
    {
        "title": "Spec-driven and context-engineering workflows",
        "what": "Lightweight methodology packs emphasize intent specs, critique loops, and context hygiene before code.",
        "smb": "Low-cost entry for teams not ready for full orchestration platforms.",
        "vendor": "GitHub spec-kit, GSD, and BMAD-METHOD are representative.",
    },
    {
        "title": "Multi-model pools and triangulated research",
        "what": "Landscape and buying decisions increasingly synthesise multiple model families with explicit divergence tracking.",
        "smb": "Improves confidence on niche categories where single-vendor marketing dominates.",
        "vendor": "Emerging in research tooling (MultAI pattern); not yet productised by incumbents.",
    },
]

KCF_NAMES = [
    "Workflow composition",
    "Atomic flow catalog",
    "Hook-enforced gates",
    "Parent/child delegation",
    "Managed hosting",
    "Prebuilt SDLC templates",
    "CI integration",
    "IDE-native integration",
    "Free tier / OSS core",
    "Predictable pricing",
]


# Matrix rows use "Parent/child agent delegation"; charts/KCF use the shorter label.
_CHART_SUPPORT_ALIASES: dict[str, str] = {
    "Parent/child agent delegation": "Parent/child delegation",
}
# Axis scoring credits equivalent features (e.g. zero-infra bootstrap → managed hosting).
_CHART_FEAT_EQUIV: dict[str, tuple[str, ...]] = {
    "Managed hosting": ("Zero-infra bootstrap",),
}


def _feat_supported(feats: dict[str, bool] | dict[str, bool | None], feature: str) -> bool:
    if feats.get(feature):
        return True
    for alt in _CHART_FEAT_EQUIV.get(feature, ()):
        if feats.get(alt):
            return True
    return False


def _normalize_chart_support(support: dict[str, dict[str, bool]]) -> dict[str, dict[str, bool]]:
    normalized: dict[str, dict[str, bool]] = {}
    for slug, feats in support.items():
        merged = dict(feats)
        for source, target in _CHART_SUPPORT_ALIASES.items():
            if merged.get(source) and not merged.get(target):
                merged[target] = True
        normalized[str(slug)] = merged
    return normalized


def _merge_features_json_support(
    support: dict[str, dict[str, bool]],
    root: Path | None,
) -> dict[str, dict[str, bool]]:
    if root is None:
        return support
    merged = {slug: dict(feats) for slug, feats in support.items()}
    solutions_dir = root / "solutions"
    if not solutions_dir.is_dir():
        return merged
    for features_path in solutions_dir.glob("*/features.json"):
        slug = features_path.parent.name
        try:
            payload = json.loads(features_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        bucket = merged.setdefault(slug, {})
        for category in payload.get("categories") or []:
            if not isinstance(category, dict):
                continue
            for feature in category.get("features") or []:
                if not isinstance(feature, dict):
                    continue
                name = str(feature.get("name") or "")
                if feature.get("supported") is True and name:
                    bucket[name] = True
    return _normalize_chart_support(merged)


def _build_chart_support(
    comparison: dict[str, Any],
    *,
    root: Path | None = None,
) -> dict[str, dict[str, bool]]:
    return _merge_features_json_support(_feature_support(comparison), root)


# Domain axis profiles — never inherit PE/DevOps framing for unrelated research_type runs.
_DOMAIN_AXIS_PROFILES: dict[str, dict[str, str]] = {
    "agentic sdlc": {
        "mq_anchor": "Process Orchestration",
        "mq_x": "← Low process orchestration         High process orchestration →",
        "mq_y": "← Low autonomous execution         High autonomous execution →",
        "mq_x_label": "Process orchestration depth",
        "mq_y_label": "Autonomous execution",
        "section_3a": "Process Orchestration × Autonomous Execution Matrix",
    },
    "sdlc orchestration": {
        "mq_anchor": "Process Orchestration",
        "mq_x": "← Low process orchestration         High process orchestration →",
        "mq_y": "← Low autonomous execution         High autonomous execution →",
        "mq_x_label": "Process orchestration depth",
        "mq_y_label": "Autonomous execution",
        "section_3a": "Process Orchestration × Autonomous Execution Matrix",
    },
    "coding agent": {
        "mq_anchor": "Process Orchestration",
        "mq_x": "← Low process orchestration         High process orchestration →",
        "mq_y": "← Low autonomous execution         High autonomous execution →",
        "mq_x_label": "Process orchestration depth",
        "mq_y_label": "Autonomous execution",
        "section_3a": "Process Orchestration × Autonomous Execution Matrix",
    },
}


def _derive_axis_profile(category: str, need: dict[str, Any], scope_text: str) -> dict[str, str]:
    """Resolve 2×2 axis labels from need_profile overrides, category, or scope — not PE template leftovers."""
    explicit = need.get("landscape_axes")
    if isinstance(explicit, dict) and explicit.get("mq_x") and explicit.get("mq_y"):
        return {
            "mq_anchor": str(explicit.get("mq_anchor") or "Positioning"),
            "mq_x": str(explicit["mq_x"]),
            "mq_y": str(explicit["mq_y"]),
            "mq_x_label": str(explicit.get("mq_x_label") or "X-axis capability"),
            "mq_y_label": str(explicit.get("mq_y_label") or "Y-axis capability"),
            "section_3a": str(explicit.get("section_3a") or f"{category} Positioning Matrix"),
        }

    haystack = f"{category} {scope_text}".lower()
    for key, profile in _DOMAIN_AXIS_PROFILES.items():
        if key in haystack:
            return dict(profile)

    # Generic fallback — analyst framework without domain-specific PE vocabulary
    short = category.split("—")[0].strip() or "Market"
    return {
        "mq_anchor": "Positioning",
        "mq_x": f"← Lower {short} capability         Higher {short} capability →",
        "mq_y": "← Lower execution strength         Higher execution strength →",
        "mq_x_label": f"{short} capability",
        "mq_y_label": "Execution strength",
        "section_3a": f"{category} Positioning Matrix",
    }


def _load_json(path: Path) -> Any:
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _load_envelopes(root: Path) -> list[dict[str, Any]]:
    data = _load_json(root / "contributions" / "all-envelopes.json")
    return [e for e in data if isinstance(e, dict)] if isinstance(data, list) else []


def _platform_list(envelopes: list[dict[str, Any]]) -> str:
    models = sorted({str(e.get("logical_model_id")) for e in envelopes if e.get("logical_model_id")})
    return ", ".join(models) if models else "multi-AI pool"


def _feature_support(comparison: dict[str, Any]) -> dict[str, dict[str, bool]]:
    support: dict[str, dict[str, bool]] = {}
    for row in comparison.get("rows") or []:
        if not isinstance(row, dict) or row.get("type") != "feature":
            continue
        feature = str(row.get("name") or "")
        for slug, mark in (row.get("solutions") or {}).items():
            support.setdefault(str(slug), {})[feature] = bool(mark and str(mark).strip())
    return support


def _score_solution(slug: str, comparison: dict[str, Any]) -> int:
    for item in comparison.get("rankings") or []:
        if isinstance(item, dict) and item.get("solution") == slug:
            return int(item.get("score") or 0)
    return 0


def _clean_text(text: str) -> str:
    return sanitize_compression_markers(text or "")


def _read_scr(root: Path, slug: str) -> str:
    path = root / "solutions" / slug / "scr.md"
    if not path.is_file():
        return ""
    return _clean_text(path.read_text(encoding="utf-8"))


def _scr_summary(scr: str, fallback: str, *, focus_name: str = "") -> str:
    scr = _clean_text(scr)
    fallback = _clean_text(fallback)
    if not scr:
        return fallback

    exec_match = re.search(r"## Executive summary\s*\n+(.*?)(?=\n## |\Z)", scr, re.S | re.I)
    if exec_match:
        exec_block = exec_match.group(1).strip()
        exec_paras = [
            ln.strip()
            for ln in exec_block.splitlines()
            if ln.strip() and not ln.startswith("-") and not ln.startswith("#")
        ]
        for para in exec_paras:
            if not is_unusable_overview_claim(para, focus_name=focus_name):
                return para[:420]

    lines = [ln.strip() for ln in scr.splitlines() if ln.strip() and not ln.startswith("#")]
    bullets = [ln.lstrip("- ").strip() for ln in lines if ln.startswith("-")]
    clean_bullets = [b for b in bullets if not is_unusable_overview_claim(b, focus_name=focus_name)]
    if clean_bullets:
        return clean_bullets[0][:420]

    clean_lines = [
        ln for ln in lines if not ln.startswith("-") and not is_unusable_overview_claim(ln, focus_name=focus_name)
    ]
    if clean_lines:
        return clean_lines[0][:420]
    return fallback


def _synthetic_overview(
    name: str,
    *,
    commercial: bool,
    positives: list[str],
    negatives: list[str],
) -> str:
    kind = "commercial" if commercial else "open-source"
    parts = [f"{name} is a {kind} option for agentic SDLC orchestration."]
    if positives:
        parts.append("Noted strengths include " + ", ".join(positives[:3]) + ".")
    if negatives:
        parts.append("Relative gaps include " + ", ".join(negatives[:2]) + ".")
    return " ".join(parts)


def _claims_for_slug(slug: str, claims: list[str], known: dict[str, str] | None = None) -> list[str]:
    effective = known or KNOWN_SOLUTIONS
    name = effective.get(slug, slug)
    hits = []
    for claim in claims:
        lower = claim.lower()
        if slug in lower or slug.replace("-", " ") in lower or name.lower() in lower:
            if is_unusable_overview_claim(claim, focus_name=name):
                continue
            hits.append(claim)
    return hits[:6]


def _build_solution_profile(
    entry: dict[str, str],
    *,
    commercial: bool,
    root: Path,
    claims: list[str],
    support: dict[str, dict[str, bool]],
    known: dict[str, str] | None = None,
    overview_seeds: dict[str, str] | None = None,
) -> dict[str, Any]:
    effective_known = known or KNOWN_SOLUTIONS
    effective_overview = overview_seeds or OVERVIEW_SEEDS
    slug = entry["slug"]
    name = entry["name"]
    scr = _read_scr(root, slug)
    slug_support = support.get(slug, {})
    positives = [f for f, ok in slug_support.items() if ok]
    negatives = [f for f, ok in slug_support.items() if ok is False and f in KCF_NAMES]
    claim_hits = _claims_for_slug(slug, claims, effective_known)
    seed = effective_overview.get(slug, "").strip()
    synthetic = _synthetic_overview(name, commercial=commercial, positives=positives, negatives=negatives)
    overview = seed or _scr_summary(scr, "", focus_name=name)
    if not overview or is_unusable_overview_claim(overview, focus_name=name):
        overview = claim_hits[0] if claim_hits else synthetic
    if is_unusable_overview_claim(overview, focus_name=name):
        overview = synthetic
    overview = re.sub(r"\s+", " ", overview).strip()[:420]
    pros = []
    for feat in positives[:5]:
        pros.append(f"**{feat}**: Supported in startup-weighted comparison matrix.")
    if commercial:
        pros.append("**Managed path**: Commercial offering with vendor-operated components.")
    else:
        pros.append("**Control & flexibility**: OSS/core deployable on your infrastructure.")
    while len(pros) < 4:
        pros.append("**Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.")
    cons = []
    if not slug_support.get("Managed hosting") and commercial:
        cons.append("**Hosting burden**: May require self-managed integration for some deployment paths.")
    if not slug_support.get("Hook-enforced gates"):
        cons.append("**Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.")
    if not slug_support.get("Atomic flow catalog"):
        cons.append("**No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.")
    if not slug_support.get("Workflow composition"):
        cons.append("**Limited composition**: Workflow composition not credited in comparison matrix.")
    if not cons:
        cons.append("**Operational depth**: Requires agent-ops maturity to realise full value.")
    cons.append("**Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.")
    license = entry.get("license", "Commercial")
    return {
        "name": name,
        "slug": slug,
        "license": license,
        "overview": overview,
        "pros": pros[:6],
        "cons": cons[:5],
        "best_for": f"SMB teams prioritising {positives[0].lower() if positives else 'agentic SDLC automation'} with {name}.",
        "avoid_if": f"You need capabilities {name} lacks in the matrix ({', '.join(negatives[:2]) or 'unverified gaps'}).",
        "url": entry.get("url", ""),
    }


def _quadrant(x: float, y: float) -> str:
    """Gartner MQ layout: Leaders TR, Challengers TL, Visionaries BR, Niche BL."""
    if x >= 5.5 and y >= 5.5:
        return "Leaders"
    if x < 5.5 and y >= 5.5:
        return "Challengers"
    if x >= 5.5:
        return "Visionaries"
    return "Niche Players"


def _wave_descriptor(score: int, maximum: int = 29) -> str:
    ratio = score / maximum if maximum else 0
    if ratio >= 0.65:
        return "Strong"
    if ratio >= 0.45:
        return "Good"
    if ratio >= 0.25:
        return "Moderate"
    return "Emerging"


def _catalog_entries(
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
) -> list[dict[str, str]]:
    if commercial is None and oss is None:
        return [*COMMERCIAL_CATALOG, *OSS_CATALOG, *EMERGING_CATALOG]
    entries: list[dict[str, str]] = []
    if commercial:
        entries.extend(commercial)
    if oss:
        entries.extend(oss)
    return entries


def _catalog_label(entry: dict[str, str], known: dict[str, str] | None = None) -> str:
    effective = known or KNOWN_SOLUTIONS
    return entry.get("name") or effective.get(entry["slug"], entry["slug"].replace("-", " ").title())


def _normalize_scope_markdown(text: str) -> str:
    """Demote a leading scope H1 so Section 1 keeps a single report title hierarchy."""
    lines = text.strip().splitlines()
    if lines and re.match(r"^#\s+", lines[0]):
        lines[0] = f"**{lines[0].lstrip('#').strip()}**"
    return "\n".join(lines)


def _slugify_label(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", label.strip().lower()).strip("-")


def _slug_for_label(
    label: str,
    *,
    known: dict[str, str],
    rankings: list[dict[str, Any]],
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
    support: dict[str, dict[str, bool]] | None = None,
) -> str | None:
    norm = label.strip()
    for slug, name in known.items():
        if name == norm:
            return slug
    for entry in _catalog_entries(commercial, oss):
        if _catalog_label(entry, known=known) == norm:
            return entry["slug"]
    for item in rankings:
        if not isinstance(item, dict):
            continue
        slug = str(item.get("solution") or "").strip()
        if not slug:
            continue
        if known.get(slug, slug.replace("-", " ").title()) == norm:
            return slug
    slugified = _slugify_label(norm)
    if support and slugified in support:
        return slugified
    for slug in support or {}:
        if known.get(slug, slug.replace("-", " ").title()) == norm:
            return slug
    return slugified or None


def _collect_mq_leader_series(
    gmq_data: list[dict[str, Any]],
    mq_data: list[dict[str, Any]],
) -> list[tuple[str, str]]:
    """Return deduped (slug, label) for every Magic Quadrant leader (3A + 3B)."""
    seen_labels: set[str] = set()
    leaders: list[tuple[str, str]] = []
    for point in [*gmq_data, *mq_data]:
        if point.get("q") != "Leaders":
            continue
        label = str(point.get("label") or "").strip()
        if not label or label in seen_labels:
            continue
        slug = str(point.get("slug") or "").strip()
        if slug:
            leaders.append((slug, label))
            seen_labels.add(label)
    return leaders


def _vc_series_entry(
    slug: str,
    label: str,
    feats: dict[str, bool],
    *,
    known: dict[str, str],
    oss: list[dict[str, str]] | None = None,
) -> dict[str, Any]:
    data = [5 if _feat_supported(feats, kcf) else (3 if slug in known else 2) for kcf in KCF_NAMES]
    oss_slugs = {e["slug"] for e in (oss or OSS_CATALOG)}
    color = "#22d3ee" if vendor_license_bucket(slug) == "oss" or slug in oss_slugs else "#4f46e5"
    return {"label": label, "data": data, "color": color}


def _legacy_slug_urls() -> dict[str, str]:
    """Slug → official URL from built-in commercial/OSS/emerging catalogs."""
    urls: dict[str, str] = {}
    for entry in _catalog_entries(None, None):
        url = entry.get("url")
        if url:
            urls[str(entry["slug"])] = str(url)
    return urls


def _resolve_slug_url(
    slug: str,
    slug_urls: dict[str, str],
    *,
    pack: dict[str, Any] | None = None,
) -> str | None:
    if slug in slug_urls:
        return slug_urls[slug]
    aliases = (pack or {}).get("product_aliases") if isinstance(pack, dict) else None
    if isinstance(aliases, dict):
        canonical = aliases.get(slug)
        if canonical and canonical in slug_urls:
            return slug_urls[canonical]
        for alias_slug, target in aliases.items():
            if target == slug and alias_slug in slug_urls:
                return slug_urls[alias_slug]
    return None


def _scr_homepage(scr_path: Path) -> str | None:
    if not scr_path.is_file():
        return None
    text = scr_path.read_text(encoding="utf-8", errors="replace")
    frontmatter = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if frontmatter:
        for line in frontmatter.group(1).splitlines():
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            if key.strip().lower() in {"homepage", "homepage_url", "official_url", "url"}:
                cleaned = value.strip().strip("'\"")
                if cleaned.startswith("http"):
                    return cleaned
    for match in re.finditer(r"https?://[^\s\])>\"']+", text):
        return match.group(0).rstrip(".,;)")
    return None


def build_link_pairs(
    rankings: list[dict[str, Any]] | None = None,
    *,
    root: Path | None = None,
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
    chart_slugs: list[str] | None = None,
    matrix_slugs: list[str] | None = None,
) -> list[list[str]]:
    """Build display-name → official URL pairs for catalog solutions (+ SCR hints)."""
    effective_known = known or KNOWN_SOLUTIONS
    catalog = _catalog_entries(commercial, oss)
    pairs: list[list[str]] = []
    seen_labels: set[str] = set()
    slug_urls: dict[str, str] = dict(_legacy_slug_urls())
    if pack:
        from category_pack import build_homepage_by_slug

        slug_urls.update(build_homepage_by_slug(pack))
    for entry in catalog:
        url = entry.get("url")
        if url:
            slug_urls[str(entry["slug"])] = str(url)

    def _append_link_pair(slug: str, raw_label: str, url: str) -> None:
        label = resolve_vendor_link_label(slug, raw_label)
        if not url or is_generic_link_label(label) or label in seen_labels:
            return
        pairs.append([label, url])
        seen_labels.add(label)
        short = label.split("(")[0].strip()
        if (
            short
            and short != label
            and not is_generic_link_label(short)
            and short not in seen_labels
        ):
            pairs.append([short, url])
            seen_labels.add(short)

    for entry in catalog:
        slug = str(entry["slug"])
        label = _catalog_label(entry, known=effective_known)
        url = _resolve_slug_url(slug, slug_urls, pack=pack)
        if url:
            _append_link_pair(slug, label, url)

    slug_sources: list[str] = []
    if matrix_slugs:
        slug_sources.extend(matrix_slugs)
    if chart_slugs:
        slug_sources.extend(chart_slugs)
    for item in rankings or []:
        if isinstance(item, dict) and item.get("solution"):
            slug_sources.append(str(item["solution"]))
    for slug in slug_sources:
        slug = str(slug).strip()
        if not slug:
            continue
        label = effective_known.get(slug, slug.replace("-", " ").title())
        url = _resolve_slug_url(slug, slug_urls, pack=pack)
        if url:
            _append_link_pair(slug, label, url)

    if root is not None:
        scr_slugs = {str(entry["slug"]) for entry in catalog}
        scr_slugs.update(str(slug) for slug in (chart_slugs or []))
        for slug in sorted(scr_slugs):
            scr = root / "solutions" / slug / "scr.md"
            if not scr.is_file():
                continue
            label = effective_known.get(slug, slug.replace("-", " ").title())
            url = _scr_homepage(scr)
            if url:
                _append_link_pair(slug, label, url)

    return filter_vendor_link_pairs(pairs)


def _linkify_markdown_vendors(
    markdown: str,
    link_pairs: list[list[str]],
) -> str:
    """Wrap vendor display names in markdown links for all prose occurrences."""
    if not link_pairs:
        return markdown
    segments = re.split(r"(\[[^\]]+\]\([^)]+\)|https?://\S+)", markdown)
    for label, url in filter_vendor_link_pairs(link_pairs):
        label = str(label).strip()
        url = str(url).strip()
        if not label or not url.startswith("http"):
            continue
        escaped = re.escape(label)
        pattern = re.compile(rf"\b({escaped})\b")
        for idx in range(0, len(segments), 2):
            segments[idx] = pattern.sub(rf"[\1]({url})", segments[idx])
    return "".join(segments)


def build_vendor_buckets(
    mq_data: list[dict[str, Any]],
    *,
    gmq_data: list[dict[str, Any]] | None = None,
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
    known: dict[str, str] | None = None,
) -> dict[str, list[str]]:
    commercial_labels = [
        _catalog_label(e, known=known) for e in (commercial or COMMERCIAL_CATALOG)
    ]
    oss_labels = [
        _catalog_label(e, known=known)
        for e in (oss or [*OSS_CATALOG, *EMERGING_CATALOG])
    ]
    leader_labels: list[str] = []
    seen: set[str] = set()
    for point in [*(gmq_data or []), *mq_data]:
        if point.get("q") != "Leaders":
            continue
        label = str(point.get("label") or "").strip()
        if label and label not in seen:
            leader_labels.append(label)
            seen.add(label)
    leaders = leader_labels
    challengers = [str(d.get("label")) for d in mq_data if d.get("q") == "Challengers" and d.get("label")]
    return {
        "commercial": commercial_labels,
        "oss": oss_labels,
        "leaders": leaders,
        "challengers": challengers,
    }


def build_chart_data(
    comparison: dict[str, Any],
    *,
    category: str,
    support: dict[str, dict[str, bool]],
    need: dict[str, Any] | None = None,
    scope_text: str = "",
    root: Path | None = None,
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
    known: dict[str, str] | None = None,
    market_slugs: set[str] | None = None,
    license_map: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> dict[str, Any]:
    effective_known = known or KNOWN_SOLUTIONS
    rankings = [r for r in (comparison.get("rankings") or []) if isinstance(r, dict)]
    if market_slugs:
        rankings = [r for r in rankings if str(r.get("solution")) in market_slugs]
        if not rankings:
            rankings = [{"solution": slug, "score": 0} for slug in sorted(market_slugs)[:12]]
    # Charts use ranked core solutions only (matrix columns), not legacy catalog slices.
    top = rankings[:12]
    mq_data = []
    gmq_data = []
    wave_data = []
    # 3A domain axes: process orchestration (x) × autonomous execution (y)
    mq_x_feats = ("Workflow composition", "Atomic flow catalog", "Hook-enforced gates")
    mq_y_feats = ("Parent/child delegation", "Managed hosting", "Prebuilt SDLC templates")
    # 3B Gartner axes: Completeness of Vision (x) × Ability to Execute (y)
    gmq_x_feats = ("Workflow composition", "Atomic flow catalog", "Prebuilt SDLC templates", "Free tier / OSS core")
    gmq_y_feats = ("Parent/child delegation", "Managed hosting", "CI integration", "Hook-enforced gates", "IDE-native integration")
    for item in top:
        slug = str(item.get("solution"))
        label = effective_known.get(slug, slug.replace("-", " ").title())
        score = int(item.get("score") or 0)
        feats = support.get(slug, {})
        mx = 3.0 + sum(1 for f in mq_x_feats if _feat_supported(feats, f)) * 2.2
        my = 3.0 + sum(1 for f in mq_y_feats if _feat_supported(feats, f)) * 2.0
        mx = min(9.5, mx + score / 15)
        my = min(9.5, my + score / 18)
        mq_data.append(
            {"slug": slug, "label": label, "x": round(mx, 1), "y": round(my, 1), "q": _quadrant(mx, my)}
        )

        gx = 2.5 + sum(1 for f in gmq_x_feats if _feat_supported(feats, f)) * 1.6
        gy = 2.5 + sum(1 for f in gmq_y_feats if _feat_supported(feats, f)) * 1.35
        gx = min(9.5, gx + score / 12)
        gy = min(9.5, gy + score / 14)
        gmq_data.append(
            {"slug": slug, "label": label, "x": round(gx, 1), "y": round(gy, 1), "q": _quadrant(gx, gy)}
        )

        offering = min(4.0, 1.5 + score / 10)
        strategy = min(4.0, 1.2 + sum(1 for f in ("Workflow composition", "Atomic flow catalog") if _feat_supported(feats, f)))
        presence = min(4, max(1, int(1 + score / 8)))
        wave_data.append({
            "slug": slug,
            "label": label,
            "offering": round(offering, 1),
            "strategy": round(strategy, 1),
            "presence": presence,
        })
    chart_slugs = [str(item.get("solution")) for item in top if item.get("solution")]
    if market_slugs:
        chart_slugs = sorted(set(chart_slugs) | set(market_slugs))
    link_pairs = build_link_pairs(
        rankings,
        root=root,
        commercial=commercial,
        oss=oss,
        known=effective_known,
        pack=pack,
        chart_slugs=chart_slugs,
        matrix_slugs=sorted(market_slugs) if market_slugs else None,
    )

    vc_commercial: list[dict[str, Any]] = []
    vc_oss: list[dict[str, Any]] = []
    existing_vc: set[str] = set()

    def _append_vc_series(slug: str, label: str) -> None:
        if not slug or not label or label in existing_vc:
            return
        feats = support.get(slug, {})
        series = _vc_series_entry(slug, label, feats, known=effective_known, oss=oss)
        existing_vc.add(label)
        if vendor_license_bucket(slug, license_map=license_map) == "oss":
            vc_oss.append(series)
        else:
            vc_commercial.append(series)

    # Value Curve / Leaders radar: every MQ leader (3A + 3B) with slug from chart points.
    leader_series = _collect_mq_leader_series(gmq_data, mq_data)
    leader_labels = [label for _, label in leader_series]
    for slug, label in leader_series:
        resolved = slug or _slug_for_label(
            label,
            known=effective_known,
            rankings=rankings,
            commercial=commercial,
            oss=oss,
            support=support,
        )
        if resolved:
            _append_vc_series(resolved, label)

    if not existing_vc:
        vc_core = (commercial or COMMERCIAL_CATALOG)[:5] + (oss or OSS_CATALOG)[:5]
        if not vc_core and top:
            vc_core = [
                {
                    "slug": str(item.get("solution")),
                    "name": effective_known.get(str(item.get("solution")), str(item.get("solution"))),
                }
                for item in top[:5]
            ]
        for entry in vc_core[:8]:
            slug = str(entry.get("slug") or "")
            label = entry.get("name") or effective_known.get(slug, slug.replace("-", " ").title())
            _append_vc_series(slug, label)
    else:
        for entry in _catalog_entries(commercial, oss):
            label = _catalog_label(entry, known=effective_known)
            if label not in leader_labels or label in existing_vc:
                continue
            _append_vc_series(entry["slug"], label)

    axes = _derive_axis_profile(category, need or {}, scope_text)

    return {
        "anchors": {
            "mq": ["3A", axes["mq_anchor"]],
            "gmq": ["3B", "Magic Quadrant"],
            "wave": ["3C", "Wave-Style"],
            "vc": ["3D", "Value Curve"],
        },
        "titles": {
            "mq": f"3A · {category} Positioning Matrix",
            "mq_x": axes["mq_x"],
            "mq_y": axes["mq_y"],
            "gmq": f"3B · Magic Quadrant — {category}",
            "gmq_x": "X-axis: Completeness of Vision",
            "gmq_y": "Y-axis: Ability to Execute",
            "wave": f"3C · Wave-Style Assessment — {category}",
            "vc": f"3D · Blue Ocean Value Curve (Leaders Radar) — {category}",
        },
        "mq_data": mq_data,
        "mq_colors": {
            "Leaders": "#1f3864",
            "Challengers": "#475569",
            "Visionaries": "#2f5597",
            "Niche Players": "#94a3b8",
        },
        "gmq_data": gmq_data,
        "gmq_colors": {
            "Leaders": "#1f3864",
            "Challengers": "#475569",
            "Visionaries": "#2f5597",
            "Niche Players": "#94a3b8",
        },
        "wave_data": wave_data[:8],
        "vc_kcfs": KCF_NAMES,
        "vc_commercial": vc_commercial,
        "vc_oss": vc_oss,
        "link_pairs": link_pairs,
        "vendor_buckets": build_vendor_buckets(
            mq_data,
            gmq_data=gmq_data,
            commercial=commercial,
            oss=oss,
            known=effective_known,
        ),
        "vendor_urls": {label: url for label, url in link_pairs},
    }


_MARKET_ROLE_LABELS = {
    "primary": "Primary",
    "secondary": "Secondary",
    "tertiary": "Tertiary",
}


def _market_solution_sections(
    pack: dict[str, Any],
    audit: dict[str, Any] | None,
    *,
    start_num: int = 5,
) -> tuple[list[dict[str, Any]], int]:
    """Plan per-market commercial/OSS sections with stable numbering."""
    sections: list[dict[str, Any]] = []
    num = start_num
    markets_audit = (audit or {}).get("markets") or {}
    for market in get_markets(pack):
        mid = str(market.get("id") or "")
        ma = markets_audit.get(mid) or {}
        market_core = list(ma.get("core") or [])
        commercial, oss = catalog_entries_from_pack(pack, market_core, market_id=mid)
        role = _MARKET_ROLE_LABELS.get(str(market.get("role") or ""), str(market.get("role") or ""))
        display = str(market.get("display_name") or mid)
        if commercial:
            sections.append(
                {
                    "num": num,
                    "kind": "commercial",
                    "market_id": mid,
                    "market_role": role,
                    "market_display": display,
                    "entries": commercial,
                }
            )
            num += 1
        if oss:
            sections.append(
                {
                    "num": num,
                    "kind": "oss",
                    "market_id": mid,
                    "market_role": role,
                    "market_display": display,
                    "entries": oss,
                }
            )
            num += 1
    return sections, num


def build_multi_market_chart_data(
    comparison: dict[str, Any],
    *,
    pack: dict[str, Any],
    support: dict[str, dict[str, bool]],
    need: dict[str, Any] | None = None,
    scope_text: str = "",
    root: Path | None = None,
    audit: dict[str, Any] | None = None,
    known: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Build per-market chart payloads; top-level mirrors primary market for backward compat."""
    license_map = build_license_by_slug(pack)
    slug_sets = market_slug_sets(pack)
    markets_out: dict[str, Any] = {}
    primary_id = get_primary_market_id(pack)

    for market in get_markets(pack):
        if not market.get("chart_eligible", True):
            continue
        mid = str(market["id"])
        role = _MARKET_ROLE_LABELS.get(str(market.get("role") or ""), str(market.get("role") or ""))
        display = str(market.get("display_name") or mid)
        market_category = f"{role} — {display}"
        market_core = set((audit or {}).get("markets", {}).get(mid, {}).get("core") or slug_sets.get(mid, set()))
        commercial, oss = catalog_entries_from_pack(pack, list(market_core), market_id=mid)
        chart = build_chart_data(
            comparison,
            category=market_category,
            support=support,
            need=need,
            scope_text=scope_text,
            root=root,
            commercial=commercial,
            oss=oss,
            known=known,
            market_slugs=market_core or slug_sets.get(mid),
            license_map=license_map,
            pack=pack,
        )
        chart["market_id"] = mid
        chart["market_role"] = market.get("role")
        chart["market_display_name"] = display
        markets_out[mid] = chart

    primary_chart = markets_out.get(primary_id) or next(iter(markets_out.values()), {})
    all_matrix_slugs: list[str] = []
    if audit:
        all_matrix_slugs = list(audit.get("matrix_slugs") or [])
        for slug in audit.get("adjacent") or []:
            if slug and slug not in all_matrix_slugs:
                all_matrix_slugs.append(str(slug))
    merged_link_pairs = build_link_pairs(
        [r for r in (comparison.get("rankings") or []) if isinstance(r, dict)],
        root=root,
        known=known,
        pack=pack,
        matrix_slugs=all_matrix_slugs or None,
    )
    if merged_link_pairs:
        primary_chart = dict(primary_chart)
        primary_chart["link_pairs"] = merged_link_pairs
        primary_chart["vendor_urls"] = {label: url for label, url in merged_link_pairs}
    return {
        "primary_market_id": primary_id,
        "markets": markets_out,
        **{k: v for k, v in primary_chart.items() if k not in {"market_id", "market_role", "market_display_name"}},
    }


def _render_solution_entry(profile: dict[str, Any], *, commercial: bool) -> list[str]:
    lines: list[str] = []
    if commercial:
        lines.append(f"### {profile['name']} (Commercial)")
    else:
        lines.append(f"### {profile['name']} (OSS — {profile.get('license', 'OSS')})")
    lines.append("")
    lines.append(f"* **Overview**: {profile['overview']}")
    lines.append("* **Major Pros**:")
    for pro in profile["pros"]:
        lines.append(f"  * {pro}")
    lines.append("* **Major Cons**:")
    for con in profile["cons"]:
        lines.append(f"  * {con}")
    lines.append(f"* **Best For**: {profile['best_for']}")
    lines.append(f"* **Avoid If**: {profile['avoid_if']}")
    lines.append("")
    return lines


def _humanize_pack_jargon(text: str, pack: dict[str, Any] | None) -> str:
    """Replace pack criterion / exclusion snake_case ids with analyst labels in prose."""
    out = _clean_text(text)
    if not out or not pack:
        return out
    labels: dict[str, str] = {}
    try:
        from category_pack import get_inclusion_criteria

        crit = get_inclusion_criteria(pack)
        for item in crit.get("criteria") or []:
            if isinstance(item, dict) and item.get("id"):
                labels[str(item["id"])] = str(item.get("label") or str(item["id"]).replace("_", " "))
    except ValueError:
        pass
    for entry in pack.get("exclusion_classes") or []:
        if isinstance(entry, dict) and entry.get("id"):
            labels[str(entry["id"])] = str(entry.get("label") or str(entry["id"]).replace("_", " "))
    for key in sorted(labels, key=len, reverse=True):
        out = re.sub(rf"\b{re.escape(key)}\b", labels[key], out)
    return out


def build_report_markdown(
    *,
    category: str,
    platform_list: str,
    scope_text: str,
    need: dict[str, Any],
    comparison: dict[str, Any],
    consolidation: dict[str, Any],
    envelopes: list[dict[str, Any]],
    claims: list[str],
    root: Path,
    report_date: str,
) -> str:
    scope_text = _normalize_scope_markdown(_clean_text(scope_text))
    claims = [_clean_text(claim) for claim in claims if _clean_text(claim)]
    consolidation = {
        **consolidation,
        "consensus": [
            {**item, "text": _clean_text(str(item.get("text") or ""))}
            for item in (consolidation.get("consensus") or [])
            if isinstance(item, dict) and _clean_text(str(item.get("text") or ""))
        ],
        "divergence": [
            {**item, "text": _clean_text(str(item.get("text") or ""))}
            for item in (consolidation.get("divergence") or [])
            if isinstance(item, dict) and _clean_text(str(item.get("text") or ""))
        ],
    }
    support = _build_chart_support(comparison, root=root)
    known = _known_for_need(need)
    overview_seeds = _overview_for_need(need)
    pack = resolve_pack_from_need(need)
    commercial_catalog, oss_catalog, audit = _resolve_catalogs(need, envelopes)
    if pack and audit:
        from solution_classifier import write_catalog_audit

        write_catalog_audit(root, audit)

    lines: list[str] = [
        f"# {category} Market Landscape Report",
        "",
        "*Analyst-grade landscape analysis for SMB decision-makers*",
        "",
        f"Knowledge basis: Synthesised from multiple AI platform responses ({platform_list})",
        report_date,
        "",
    ]

    # Section 1
    lines.extend(["## 1. Market Definition & Scope", ""])
    definition = (pack or {}).get("definition") or (
        f"{category} covers solutions operating one level above coding agents — "
        "orchestrating SDLC workflows, gates, and multi-agent delegation."
    )
    lines.append(scope_text.strip() or definition)
    jtbd = (pack or {}).get("jobs_to_be_done") or [
        "Compose repeatable SDLC workflows above IDE/cloud coding agents.",
        "Delegate parent/child agent work with review and verification gates.",
        "Record skills and enforce hook-based lifecycle chains.",
        "Shorten time-to-value with templates and managed paths.",
        "Integrate git, CI, and planning artifacts for agentic delivery.",
    ]
    lines.extend(["", "**Primary jobs-to-be-done**", ""])
    for i, job in enumerate(jtbd, 1):
        lines.append(f"{i}. {job}")
    if pack:
        lines.extend([
            "",
            "**Out of scope (excluded from core peer set)**",
            "",
            "- Generic **coding agents** and IDE copilots (Cursor Background Agents, Cline, Aider, Continue, OpenHands, SWE-agent)",
            "- **Host runtimes** that execute code without a process catalog (Devin, Copilot, Claude Code as hosts — listed under Adjacent only)",
            "- **Single-step** tools (PR review bots, PM integrations such as Linear)",
            "- **Generic agent frameworks** without SDLC process packaging (LangGraph, CrewAI as adjacent)",
            "- **Sunset** products (GitHub Copilot Workspace, AutoGen, AgentGPT, Devika)",
            "",
            "**Inclusion criteria**",
            "",
            format_inclusion_criteria_prose(pack),
            "",
        ])
    else:
        lines.extend([
            "",
            "**Inclusion criteria**: Meaningful SMB adoption signals, active maintenance, production-oriented orchestration (not raw LLM APIs or single-shot copilots).",
            "",
        ])

    # Section 2
    lines.extend(["## 2. Market Overview", ""])
    lines.append(
        "As of July 2026, the category is **early mainstream**: buyers separate agent hosts from process layers, but few vendors combine machine-readable catalogs with hook-enforced gates."
    )
    lines.append(
        "Verify latest data — market size estimates for agentic SDLC orchestration are not web-verified in this synthesis; growth is driven by multi-agent adoption and verification-gate demand."
    )
    lines.extend([
        "",
        "- **Maturity**: Early mainstream; executor-first agents are ahead of process catalogs.",
        "- **Commercial vs OSS**: OSS frameworks dominate experimentation; commercial players lead managed execution.",
        "- **SMB vs enterprise**: SMBs favour templates, predictable pricing, and managed hosting; enterprises prioritise audit, SSO, and residency.",
        "- **Deployment**: SaaS agents, IDE plugins, and self-hosted OSS graphs coexist; switching costs rise with hook and catalog lock-in.",
        "",
    ])

    # Section 3 — per-market analyst frameworks
    chart = (
        build_multi_market_chart_data(
            comparison,
            pack=pack,
            support=support,
            need=need,
            scope_text=scope_text,
            root=root,
            audit=audit,
            known=known,
        )
        if pack and get_markets(pack)
        else build_chart_data(
            comparison,
            category=category,
            support=support,
            need=need,
            scope_text=scope_text,
            root=root,
            commercial=commercial_catalog,
            oss=oss_catalog,
            known=known,
        )
    )
    lines.extend(["## 3. Competitive Positioning — Analyst Frameworks", ""])
    market_charts = (chart.get("markets") or {}) if isinstance(chart.get("markets"), dict) else {}
    if market_charts:
        # Preserve the original generic chart anchors for downstream report
        # consumers while exposing the richer per-market headings below.
        lines.extend([f"### 3A. {category} Positioning Matrix", "", f"### 3B. Magic Quadrant — {category}", ""])
        for m_idx, (mid, mchart) in enumerate(market_charts.items(), start=1):
            role = mchart.get("market_role", "")
            display = mchart.get("market_display_name", mid)
            role_label = _MARKET_ROLE_LABELS.get(str(role), str(role)).title()
            lines.append(f"### 3.{m_idx} {role_label} market: {display}")
            lines.append("")
            lines.append(f"#### 3.{m_idx}.1 {display} — Positioning Matrix")
            lines.append("")
            lines.append(f"#### 3.{m_idx}.2 Magic Quadrant — {display}")
            lines.append("")
            lines.append("| Vendor | Quadrant | Justification |")
            lines.append("|--------|----------|---------------|")
            for point in mchart.get("gmq_data") or []:
                lines.append(
                    f"| {point['label']} | {point['q']} | "
                    "Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |"
                )
            lines.extend([
                "",
                f"#### 3.{m_idx}.3 Wave-Style Assessment — {display}",
                "",
                "| Vendor | Current Offering | Strategy | Market Presence |",
                "|--------|------------------|----------|-----------------|",
            ])
            for item in (comparison.get("rankings") or [])[:8]:
                if not isinstance(item, dict):
                    continue
                slug = str(item.get("solution"))
                if slug not in {p.get("slug") for p in (mchart.get("mq_data") or []) if p.get("slug")}:
                    continue
                label = known.get(slug, slug)
                score = int(item.get("score") or 0)
                desc = _wave_descriptor(score)
                lines.append(f"| {label} | {desc} | {desc} | {desc} |")
            vc_labels = [s["label"] for s in (mchart.get("vc_commercial") or []) + (mchart.get("vc_oss") or [])[:5]]
            lines.extend([
                "",
                f"#### 3.{m_idx}.4 Blue Ocean Value Curve — {display}",
                "",
                "Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only.",
                "",
            ])
            if vc_labels:
                lines.append("| Key Competitive Factor | " + " | ".join(vc_labels) + " |")
                lines.append("|" + "---|" * (1 + len(vc_labels)))
                for idx, kcf in enumerate(KCF_NAMES):
                    row = [kcf]
                    for vc in (mchart.get("vc_commercial") or []) + (mchart.get("vc_oss") or [])[:5]:
                        row.append(str(vc["data"][idx]))
                    lines.append("| " + " | ".join(row) + " |")
            lines.append("")
    else:
        lines.append(f"### 3A. {category} Positioning Matrix")
        lines.append("")
        lines.append(f"### 3B. Magic Quadrant — {category}")
        lines.append("")
        lines.append("| Vendor | Quadrant | Justification |")
        lines.append("|--------|----------|---------------|")
        for point in chart["gmq_data"]:
            lines.append(
                f"| {point['label']} | {point['q']} | "
                "Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |"
            )
        lines.extend(["", "### 3C. Wave-Style Assessment", "", "| Vendor | Current Offering | Strategy | Market Presence |", "|--------|------------------|----------|-----------------|"])
        for item in (comparison.get("rankings") or [])[:8]:
            if not isinstance(item, dict):
                continue
            slug = str(item.get("solution"))
            label = known.get(slug, slug)
            score = int(item.get("score") or 0)
            desc = _wave_descriptor(score)
            lines.append(f"| {label} | {desc} | {desc} | {desc} |")
        vc_labels = [s["label"] for s in (chart["vc_commercial"] + chart["vc_oss"])[:5]]
        if not vc_labels:
            vc_labels = [e.get("name", e["slug"]) for e in (commercial_catalog + oss_catalog)[:5]]
        lines.extend([
            "",
            "### 3D. Blue Ocean Value Curve",
            "",
            "Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only.",
            "",
            "| Key Competitive Factor | " + " | ".join(vc_labels) + " |",
        ])
        lines.append("|" + "---|" * (1 + len(vc_labels)))
        for idx, kcf in enumerate(KCF_NAMES):
            row = [kcf]
            for vc in (chart["vc_commercial"] + chart["vc_oss"])[:5]:
                row.append(str(vc["data"][idx]))
            lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    # Section 4
    lines.extend(["## 4. Key Industry Trends", ""])
    for trend in TREND_SEEDS:
        lines.append(f"### {trend['title']}")
        lines.append(f"- **What**: {trend['what']}")
        lines.append(f"- **SMB impact**: {trend['smb']}")
        lines.append(f"- **Vendor response**: {trend['vendor']}")
        lines.append("")

    # Sections 5+ — per-market commercial/OSS when pack has markets[]
    market_sections: list[dict[str, Any]] = []
    next_section_num = 5
    if pack and get_markets(pack):
        market_sections, next_section_num = _market_solution_sections(pack, audit, start_num=5)
        for section in market_sections:
            kind_label = "Commercial" if section["kind"] == "commercial" else "Open Source"
            lines.extend([
                (
                    f"## {section['num']}. {section['market_display']} — "
                    f"Top {kind_label} Solutions ({len(section['entries'])} core)"
                ),
                "",
            ])
            for entry in section["entries"]:
                profile = _build_solution_profile(
                    entry,
                    commercial=section["kind"] == "commercial",
                    root=root,
                    claims=claims,
                    support=support,
                    known=known,
                    overview_seeds=overview_seeds,
                )
                lines.extend(
                    _render_solution_entry(profile, commercial=section["kind"] == "commercial")
                )
    else:
        lines.extend([f"## 5. Top Commercial Solutions for SMBs ({len(commercial_catalog)} core)", ""])
        for entry in commercial_catalog:
            profile = _build_solution_profile(
                entry, commercial=True, root=root, claims=claims, support=support,
                known=known, overview_seeds=overview_seeds,
            )
            lines.extend(_render_solution_entry(profile, commercial=True))

        lines.extend([f"## 6. Top Open Source Solutions ({len(oss_catalog)} core)", ""])
        for entry in oss_catalog:
            profile = _build_solution_profile(
                entry, commercial=False, root=root, claims=claims, support=support,
                known=known, overview_seeds=overview_seeds,
            )
            lines.extend(_render_solution_entry(profile, commercial=False))
        next_section_num = 7

    # Adjacent and Excluded (analyst honesty)
    if audit:
        section_adjacent = next_section_num
        section_excluded = next_section_num + 1
        lines.extend([f"## {section_adjacent}. Adjacent Markets (not core peers)", ""])
        lines.append(
            "Products below are relevant context but **not** scored on the Magic Quadrant, Wave, or comparison matrix."
        )
        lines.append("")
        for slug in audit.get("adjacent") or []:
            name = known.get(slug, slug.replace("-", " ").title())
            reason = (audit.get("by_slug") or {}).get(slug, {}).get("reason", "adjacent class")
            lines.append(f"- **{name}** (`{slug}`) — {reason}")
        lines.append("")

        lines.extend([f"## {section_excluded}. Explicitly Excluded", ""])
        matrix_set = set(audit.get("matrix_slugs") or audit.get("core") or [])
        for slug in (audit.get("excluded") or [])[:40]:
            if slug in matrix_set:
                continue
            name = known.get(slug, slug.replace("-", " ").title())
            reason = (audit.get("by_slug") or {}).get(slug, {}).get("reason", "excluded")
            lines.append(f"- **{name}** — {reason}")
        for slug in audit.get("sunset") or []:
            name = known.get(slug, slug.replace("-", " ").title())
            reason = (audit.get("by_slug") or {}).get(slug, {}).get("reason", "sunset")
            lines.append(f"- **{name}** — {reason}")
        if audit.get("gaps"):
            lines.extend(["", "**Coverage gaps (must-research seeds missing from envelopes)**", ""])
            for slug in audit["gaps"]:
                lines.append(f"- {known.get(slug, slug)} (`{slug}`)")
        lines.append("")
        section_buying = section_excluded + 1
        section_outlook = section_excluded + 2
        section_sources = section_excluded + 3
    else:
        section_buying = next_section_num
        section_outlook = next_section_num + 1
        section_sources = next_section_num + 2

    # Buying guidance
    lines.extend([f"## {section_buying}. Buying Guidance & Shortlist Profiles", ""])
    winner = comparison.get("winner") or "silver-bullet"
    core_names = [known.get(s, s) for s in (audit.get("core") or [])[:5]] if audit else []
    shortlist_hint = ", ".join(core_names) if core_names else known.get(winner, winner)
    lines.extend([
        f"- **Lean startup, process-first**: Prioritise workflow composition, atomic catalog, and hook gates — shortlist **{known.get(winner, winner)}** and peers: {shortlist_hint}.",
        "- **Open-source-first**: Prioritise Silver Bullet and OSS core orchestrators — budget for hook and catalog integration.",
        "- **Host-runtime path**: Use Adjacent host runtimes (Devin, Cursor) with a separate process layer — do not conflate with APO peers.",
        "",
    ])

    # Future outlook
    lines.extend([f"## {section_outlook}. Future Outlook & Emerging Disruptors", ""])
    for entry in EMERGING_CATALOG:
        profile = _build_solution_profile(
            entry, commercial=False, root=root, claims=claims, support=support,
            known=known, overview_seeds=overview_seeds,
        )
        lines.extend(_render_solution_entry(profile, commercial=False))
    outlook = [
        ("Router-first APO catalogs", "Process routers with Authorizer trust and nested V-loops may become default SB-style differentiators.", "Threatens executor-only agents."),
        ("Multi-model triangulation as a buying step", "Consensus/divergence synthesis becomes part of procurement for niche categories.", "Advantages transparency-first vendors."),
        ("Consolidation of git-native agents", "Issue→PR agents may merge with SDLC orchestration platforms.", "Threatens point tools without ecosystem depth."),
    ]
    for title, what, smb in outlook:
        lines.append(f"### {title}")
        lines.append(f"- {what} **SMB implication**: {smb}")
        lines.append("")

    # Source reliability
    lines.extend([f"## {section_sources}. Source Reliability Assessment", ""])
    lines.extend(["### Model response weights", ""])
    lines.append("| Source | Response Size | Weight Applied | Assessment |")
    lines.append("|--------|--------------|----------------|------------|")
    by_model: dict[str, list[dict[str, Any]]] = {}
    for env in envelopes:
        model = str(env.get("logical_model_id") or "unknown")
        by_model.setdefault(model, []).append(env)
    for model, envs in sorted(by_model.items()):
        size = sum(len(json.dumps(e.get("payload") or {})) for e in envs)
        weight = "**Good—Secondary**"
        if "gemini" in model.lower():
            weight = "**Heavy—Primary**"
        lines.append(
            f"| {model} | {size} chars | {weight} | Contributed DR phases with structured payloads; depth varies by phase. |"
        )
    lines.extend(["", "**Consensus patterns**: " + (
        "; ".join(_humanize_pack_jargon(str(c.get("text") or ""), pack) for c in consolidation.get("consensus", [])[:5])
        or "No cross-family consensus claims in triangulation — see divergence."
    )])
    lines.extend(["", "**Notable divergences**:"])
    for item in consolidation.get("divergence", [])[:8]:
        lines.append(f"- {_humanize_pack_jargon(str(item.get('text', '')), pack)}")
    lines.append("")
    matrix_slugs = list((audit or {}).get("matrix_slugs") or [])
    link_pairs = build_link_pairs(
        comparison.get("rankings"),
        root=root,
        commercial=commercial_catalog,
        oss=oss_catalog,
        known=known,
        pack=pack,
        matrix_slugs=matrix_slugs or None,
    )
    if audit:
        adjacent_slugs = [str(s) for s in (audit.get("adjacent") or []) if s]
        if adjacent_slugs:
            adjacent_pairs = build_link_pairs(
                None,
                root=root,
                known=known,
                pack=pack,
                matrix_slugs=adjacent_slugs,
            )
            seen = {p[0] for p in link_pairs}
            for pair in adjacent_pairs:
                if pair[0] not in seen:
                    link_pairs.append(pair)
                    seen.add(pair[0])
            link_pairs = sorted(link_pairs, key=lambda p: -len(p[0]))
    markdown = "\n".join(lines)
    markdown = _linkify_markdown_vendors(markdown, link_pairs)
    markdown = sanitize_compression_markers(markdown)
    assert_no_compression_markers(markdown, context="landscape-report.md synthesis")
    return markdown


def synthesize_landscape(
    research_dir: Path,
    *,
    force: bool = False,
) -> dict[str, Any]:
    research_dir = Path(research_dir)
    landscape_dir = research_dir / "landscape"
    landscape_dir.mkdir(parents=True, exist_ok=True)
    md_path = landscape_dir / "landscape-report.md"
    chart_path = landscape_dir / "chart-data.json"

    if md_path.is_file() and chart_path.is_file() and not force:
        existing = md_path.read_text(encoding="utf-8")
        if len(existing) > 8000 and chart_path.stat().st_size > 200:
            return {
                "status": "skipped",
                "reason": "existing landscape artifacts appear complete",
                "markdown_path": str(md_path),
                "chart_data_path": str(chart_path),
            }

    envelopes = _load_envelopes(research_dir)
    consolidation = _load_json(research_dir / "consolidated" / "consolidation.json") or {}
    comparison = _load_json(research_dir / "comparison" / "comparison.json") or {}
    need = _load_json(research_dir / "need_profile.json") or {}
    manifest = _load_json(research_dir / "run_manifest.json") or {}
    scope = (research_dir / "scope.md").read_text(encoding="utf-8") if (research_dir / "scope.md").is_file() else ""

    category = str(need.get("category") or manifest.get("query") or "Agentic SDLC Orchestration")
    if category.startswith("2026-"):
        category = "Agentic SDLC Orchestration"

    claims = _iter_claim_texts(envelopes)
    discover_solutions(envelopes)  # warm slug discovery side effects
    support = _build_chart_support(comparison, root=research_dir)
    known = _known_for_need(need)
    commercial_catalog, oss_catalog, _audit = _resolve_catalogs(need, envelopes)
    pack = resolve_pack_from_need(need)

    report_date = date.today().strftime("%B %d, %Y")
    markdown = build_report_markdown(
        category=category,
        platform_list=_platform_list(envelopes),
        scope_text=scope,
        need=need,
        comparison=comparison,
        consolidation=consolidation,
        envelopes=envelopes,
        claims=claims,
        root=research_dir,
        report_date=report_date,
    )
    chart_data = (
        build_multi_market_chart_data(
            comparison,
            pack=pack,
            support=support,
            need=need,
            scope_text=scope,
            root=research_dir,
            audit=_audit,
            known=known,
        )
        if pack
        else build_chart_data(
            comparison,
            category=category,
            support=support,
            need=need,
            scope_text=scope,
            root=research_dir,
            commercial=commercial_catalog,
            oss=oss_catalog,
            known=known,
        )
    )

    assert_no_compression_markers(markdown, context=str(md_path))
    md_path.write_text(markdown, encoding="utf-8")
    chart_path.write_text(json.dumps(chart_data, indent=2) + "\n", encoding="utf-8")

    return {
        "status": "ok",
        "markdown_path": str(md_path),
        "chart_data_path": str(chart_path),
        "markdown_bytes": md_path.stat().st_size,
        "chart_data_bytes": chart_path.stat().st_size,
        "sections": len(SECTION_TITLES),
        "mq_points": len(chart_data.get("mq_data") or []),
        "wave_points": len(chart_data.get("wave_data") or []),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Synthesize MultAI landscape report + chart-data.json")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--force", action="store_true", help="Overwrite existing artifacts")
    args = parser.parse_args()
    result = synthesize_landscape(Path(args.dir), force=args.force)
    print(json.dumps(result, indent=2))
    return 0 if result.get("status") in {"ok", "skipped"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
