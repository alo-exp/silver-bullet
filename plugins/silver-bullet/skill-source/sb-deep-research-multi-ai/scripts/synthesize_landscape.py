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
from landscape_critique_artifacts import (
    consensus_resolution_table_lines,
    coverage_completeness_lines,
    executive_summary_lines,
    inclusion_ledger_embed_lines,
    patch_inclusion_ledger,
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
    write_run_features_json,
)
from vendor_link_labels import (
    filter_healthy_link_pairs,
    filter_vendor_link_pairs,
    is_generic_link_label,
    linkify_bare_http_urls,
    normalize_vendor_link_label,
    resolve_vendor_link_label,
    rewrite_vendor_url,
    scrub_embedded_vendor_urls,
)

SECTION_TITLES = [
    "Executive Summary",
    "Problem",
    "Market",
    "Framework",
    "Findings",
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


def _comparison_rankings_markdown(comparison: dict[str, Any]) -> str:
    """Compact rankings dump for comparison-matrix.md after hard-exclusion filter."""
    rankings = [r for r in (comparison.get("rankings") or []) if isinstance(r, dict)]
    winner = comparison.get("winner") or (rankings[0].get("solution") if rankings else "")
    runner = comparison.get("runner_up") or (
        rankings[1].get("solution") if len(rankings) > 1 else ""
    )
    lines = [
        "# Comparison matrix (regenerated)",
        "",
        f"Winner: **{winner}** | Runner-up: **{runner}**",
        "",
        "> Prefer the interactive matrix in [`landscape-report.html`](../landscape-report.html). "
        "Cell empty/null = **unknown/unsupported in-envelope**, not proven absence.",
        "",
        "## Rankings",
        "",
    ]
    for i, row in enumerate(rankings, start=1):
        slug = row.get("solution") or ""
        score = row.get("score")
        lines.append(f"{i}. `{slug}` — {score}")
    lines.append("")
    return "\n".join(lines)


def filter_comparison_for_pack(
    comparison: dict[str, Any],
    pack: dict[str, Any] | None,
    need: dict[str, Any] | None = None,
    *,
    matrix_slugs: set[str] | None = None,
) -> dict[str, Any]:
    """Drop hard-excluded / sunset / aliased-duplicate slugs from rankings and matrix rows.

    When matrix_slugs is provided (catalog audit cores), further restrict columns to those
    cores so host-runtime adjacent products are not scored as MQ/matrix peers.
    """
    if not isinstance(comparison, dict) or not pack:
        return comparison
    from category_pack import (
        get_hard_exclusion_slugs,
        get_sunset_registry,
        resolve_canonical_slug,
    )

    forbidden = set(get_hard_exclusion_slugs(pack, need or {}))
    forbidden |= {str(e.get("slug")) for e in get_sunset_registry(pack) if e.get("slug")}
    # Always drop invented / aliased-duplicate columns even if research artifacts retain them.
    forbidden |= {"claude-code-expert", "sdlc-plugin", "sdlc"}
    allow = {str(s) for s in (matrix_slugs or set()) if s}

    def _keep(slug: str) -> bool:
        raw = str(slug or "").strip()
        if not raw or raw in forbidden:
            return False
        canonical = resolve_canonical_slug(raw, pack)
        if canonical in forbidden:
            return False
        # Drop alias columns when the canonical product is already present.
        if canonical != raw:
            return False
        if allow and canonical not in allow:
            return False
        return True

    out = dict(comparison)
    rankings = [
        r
        for r in (comparison.get("rankings") or [])
        if isinstance(r, dict) and _keep(str(r.get("solution") or ""))
    ]
    ranked: list[dict[str, Any]] = []
    for i, row in enumerate(rankings, start=1):
        item = dict(row)
        item["rank"] = i
        ranked.append(item)
    out["rankings"] = ranked
    rows_out: list[Any] = []
    for row in comparison.get("rows") or []:
        if not isinstance(row, dict):
            rows_out.append(row)
            continue
        row2 = dict(row)
        sols = row.get("solutions")
        if isinstance(sols, dict):
            row2["solutions"] = {k: v for k, v in sols.items() if _keep(str(k))}
        rows_out.append(row2)
    out["rows"] = rows_out
    winner = str(comparison.get("winner") or "")
    if winner and not _keep(winner):
        out["winner"] = rankings[0]["solution"] if rankings else None
    runner = str(comparison.get("runner_up") or "")
    if runner and not _keep(runner):
        out["runner_up"] = rankings[1]["solution"] if len(rankings) > 1 else None
    return out


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
        "vendor": "Devin and Factory.ai Droids compete here; Magic.dev is a coding-model lab, not a scored SaaS-core peer.",
    },
    {
        "title": "BYO agent runtimes and graph orchestration",
        "what": "Frameworks expose durable graphs, interrupts, and delegation primitives for custom orchestration.",
        "smb": "Maximum flexibility at the cost of in-house agent ops expertise.",
        "vendor": "LangGraph Platform, CrewAI, and AutoGen anchor this segment; MetaGPT is scored as APO OSS core, not a generic framework adjacent.",
    },
    {
        "title": "Spec-driven and context-engineering workflows",
        "what": "Lightweight methodology packs emphasize intent specs, critique loops, and context hygiene before code.",
        "smb": "Low-cost entry for teams not ready for full orchestration platforms.",
        "vendor": "GitHub spec-kit, GSD, and BMAD-METHOD are representative.",
    },
    {
        "title": "Multi-model pools and triangulated research",
        "what": "This research pass triangulates multiple model families with explicit divergence tracking. That is a report method — not a product feature vendors were scored on.",
        "smb": "Use triangulation to interrogate marketing claims; do not treat it as a matrix tick.",
        "vendor": "Not a scored MQ/Wave/matrix axis in this engine; see scoring methodology.",
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
# Do NOT equate local/plugin bootstrap with vendor-operated hosting.
# Zero-infra bootstrap ≠ Managed hosting (analyst-grade Ability-to-Execute).
_CHART_FEAT_EQUIV: dict[str, tuple[str, ...]] = {}

# Wave "Strength of Strategy" — weighted research signals (features.json + SCR text).
# A 2-feature staircase (Workflow composition + Atomic flow catalog) collapses almost
# every peer to the same x-value (typically 2.2); use a broader evidence set instead.
_WAVE_STRATEGY_FEATURE_WEIGHTS: tuple[tuple[str, float], ...] = (
    ("Atomic flow catalog", 0.55),
    ("Skill/plugin marketplace", 0.40),
    ("Prebuilt SDLC templates", 0.35),
    ("Free tier / OSS core", 0.30),
    ("Hook-enforced gates", 0.30),
    ("Automated review loops", 0.30),
    ("Parent/child delegation", 0.30),
    ("Managed hosting", 0.25),
    ("Visual/E2E verification", 0.25),
    ("IDE-native integration", 0.20),
    ("Zero-infra bootstrap", 0.20),
    ("CI integration", 0.20),
    ("Predictable pricing", 0.20),
    ("Per-seat transparency", 0.15),
    ("Self-serve signup", 0.15),
    ("Workflow composition", 0.15),
    ("Quick onboarding", 0.10),
)

_WAVE_STRATEGY_HOST_MARKERS: tuple[str, ...] = (
    "cursor",
    "codex",
    "claude code",
    "claude-code",
    "github copilot",
    "copilot sdk",
)


def _feat_supported(feats: dict[str, bool] | dict[str, bool | None], feature: str) -> bool:
    if feats.get(feature):
        return True
    for alt in _CHART_FEAT_EQUIV.get(feature, ()):
        if feats.get(alt):
            return True
    # Accept long-form matrix label when short chart label is requested.
    for source, target in _CHART_SUPPORT_ALIASES.items():
        if feature == target and feats.get(source):
            return True
        if feature == source and feats.get(target):
            return True
    return False


# Leaders require y >= 5.5. Cap below that when inclusion criteria are unmet.
_LEADER_Y_CAP = 5.4
# Methodology-without-gates must not plot as vision-peers of shipped orchestrators.
_METHODOLOGY_X_CAP = 6.5
_METHODOLOGY_Y_CAP = 5.2
_NON_LEADER_WAVE_PRESENCE_CAP = 2
_NON_LEADER_WAVE_OFFERING_CAP = 2.4
_NON_LEADER_WAVE_STRATEGY_CAP = 2.5
_CROSS_SESSION_PASS_SLUGS = {"silver-bullet"}


def _model_family_label(model_id: str) -> str:
    mid = str(model_id or "").lower()
    if "claude" in mid:
        return "claude"
    if "gemini" in mid:
        return "gemini"
    if "gpt" in mid or "luna" in mid:
        return "openai"
    if "qwen" in mid:
        return "qwen"
    if "deepseek" in mid:
        return "deepseek"
    if "kimi" in mid:
        return "kimi"
    if "mimo" in mid:
        return "mimo"
    if "minimax" in mid:
        return "minimax"
    return (mid.split("-")[0] if mid else "unknown")


def _load_inclusion_ledger_statuses(root: Path | None) -> dict[str, dict[str, str]]:
    """slug -> {normalized criterion -> status} from inclusion-ledger.json."""
    out: dict[str, dict[str, str]] = {}
    if root is None:
        return out
    path = root / "landscape" / "inclusion-ledger.json"
    if not path.is_file():
        return out
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return out
    for vendor in payload.get("vendors") or []:
        if not isinstance(vendor, dict) or not vendor.get("slug"):
            continue
        statuses: dict[str, str] = {}
        for row in vendor.get("criteria") or []:
            if not isinstance(row, dict):
                continue
            key = re.sub(
                r"[^a-z0-9]+",
                " ",
                str(row.get("criterion") or row.get("name") or "").lower(),
            ).strip()
            if not key:
                continue
            statuses[key] = str(row.get("status") or "unknown").lower()
        out[str(vendor["slug"])] = statuses
    return out


def _cross_session_status(slug: str, root: Path | None) -> str:
    """Return pass|fail|unknown from the inclusion ledger, else allowlist."""
    statuses = _load_inclusion_ledger_statuses(root).get(slug) or {}
    for key, status in statuses.items():
        if "cross session" in key or key.endswith("state"):
            if status in {"pass", "fail", "unknown"}:
                return status
    if slug in _CROSS_SESSION_PASS_SLUGS:
        return "pass"
    return "unknown"


def _has_hook_gates(feats: dict[str, bool] | dict[str, bool | None]) -> bool:
    return _feat_supported(feats, "Hook-enforced gates")


def _is_methodology_without_gates(feats: dict[str, bool] | dict[str, bool | None]) -> bool:
    """Conceptual/methodology seed: no shipped gates and no vendor-operated execute path."""
    return (
        not _has_hook_gates(feats)
        and not _feat_supported(feats, "Managed hosting")
        and not _feat_supported(feats, "Automated review loops")
    )


def _must_not_be_leader(
    market_id: str | None,
    slug: str,
    feats: dict[str, bool] | dict[str, bool | None],
    root: Path | None,
) -> bool:
    """Secondary packs and methodology-without-gates APO seeds cannot occupy Leaders."""
    mid = str(market_id or "")
    if mid == "sdlc-plugins":
        return not (
            _has_hook_gates(feats) and _cross_session_status(slug, root) == "pass"
        )
    if mid == "apo":
        return not _has_hook_gates(feats)
    return False


def _feat_tick(
    feats: dict[str, bool] | dict[str, bool | None],
    feature: str,
) -> bool | None:
    """True / False when matrix or features.json evidenced the factor; None if unknown."""
    if _feat_supported(feats, feature):
        return True
    keys = [feature]
    for source, target in _CHART_SUPPORT_ALIASES.items():
        if feature in {source, target}:
            keys.extend([source, target])
    for key in keys:
        if key in feats and feats[key] is False:
            return False
    return None


def select_vc_kcfs(
    leader_slugs: list[str],
    support: dict[str, dict[str, bool]],
) -> list[str]:
    """Blue Ocean factors that at least one Leader actually evidences (no all-false flatten)."""
    chosen: list[str] = []
    for kcf in KCF_NAMES:
        ticks = [_feat_tick(support.get(slug, {}), kcf) for slug in leader_slugs]
        if not any(tick is True for tick in ticks):
            continue
        chosen.append(kcf)
    return chosen


def _wave_band(value: float) -> str:
    if value >= 3.5:
        return "Strong"
    if value >= 2.5:
        return "Good"
    if value >= 1.5:
        return "Moderate"
    return "Emerging"


def _enforce_non_leader_y(
    points: list[dict[str, Any]],
    demoted: set[str],
) -> list[dict[str, Any]]:
    """Keep demoted slugs below the Leaders y-threshold after collision slotting."""
    if not points or not demoted:
        return points
    used = {float(p.get("y") or 0.0) for p in points}
    out: list[dict[str, Any]] = []
    for point in points:
        item = dict(point)
        slug = str(item.get("slug") or "")
        y = float(item.get("y") or 0.0)
        x = float(item.get("x") or 0.0)
        if slug in demoted and y >= 5.5:
            used.discard(y)
            chosen: float | None = None
            cand = _LEADER_Y_CAP
            while cand >= 1.0:
                slot = _round_coord(cand)
                if slot not in used:
                    chosen = slot
                    break
                cand = _round_coord(cand - 0.1)
            y = chosen if chosen is not None else _LEADER_Y_CAP
            used.add(y)
            item["y"] = y
        item["q"] = _quadrant(x, float(item.get("y") or 0.0))
        out.append(item)
    return out


def _enforce_axis_cap(
    points: list[dict[str, Any]],
    slugs: set[str],
    *,
    key: str,
    cap: float,
    lo: float = 1.0,
) -> list[dict[str, Any]]:
    """Keep named slugs at or below `cap` on x or y after collision slotting."""
    if not points or not slugs:
        return points
    used = {float(p.get(key) or 0.0) for p in points}
    out: list[dict[str, Any]] = []
    for point in points:
        item = dict(point)
        slug = str(item.get("slug") or "")
        value = float(item.get(key) or 0.0)
        if slug in slugs and value > cap + 1e-12:
            used.discard(value)
            chosen: float | None = None
            cand = cap
            while cand >= lo:
                slot = _round_coord(cand)
                if slot not in used:
                    chosen = slot
                    break
                cand = _round_coord(cand - 0.1)
            value = chosen if chosen is not None else cap
            used.add(value)
            item[key] = value
        x = float(item.get("x") or 0.0)
        y = float(item.get("y") or 0.0)
        item["q"] = _quadrant(x, y)
        out.append(item)
    return out


def _load_scr_text(root: Path | None, slug: str) -> str:
    if root is None or not slug:
        return ""
    path = root / "solutions" / slug / "scr.md"
    if not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def _scr_strategy_bonus(scr_text: str) -> float:
    """Small Strategy bonuses from SCR-documented signals only (no invented capabilities)."""
    if not scr_text:
        return 0.0
    text = scr_text.lower()
    bonus = 0.0
    host_hits = sum(1 for marker in _WAVE_STRATEGY_HOST_MARKERS if marker in text)
    # "claude" alone counts as one host IDE mention when multi-word forms absent.
    if host_hits == 0 and re.search(r"\bclaude\b", text):
        host_hits = 1
    if host_hits >= 2:
        bonus += 0.25  # multi-host / multi-runtime strategy
    elif host_hits == 1:
        bonus += 0.10
    if any(
        token in text
        for token in ("open-source", "open source", "mit-licensed", "mit licensed")
    ):
        bonus += 0.20  # open strategy
    if "marketplace" in text or "ecosystem" in text:
        bonus += 0.15
    if "roadmap" in text:
        bonus += 0.10
    return min(0.55, bonus)


def _wave_strategy_score(
    feats: dict[str, bool] | dict[str, bool | None],
    *,
    scr_text: str = "",
) -> float:
    """Strength of Strategy (1–4) from differentiated evidence — not a peer-clone constant."""
    raw = 1.0
    for feature, weight in _WAVE_STRATEGY_FEATURE_WEIGHTS:
        if _feat_supported(feats, feature):
            raw += weight
    raw += _scr_strategy_bonus(scr_text)
    return round(min(4.0, max(1.0, raw)), 1)


def avoid_wave_coord_collisions(
    points: list[dict[str, Any]],
    *,
    step: float = 0.1,
) -> list[dict[str, Any]]:
    """Ensure Wave strategy (x) and offering (y) are each unique within a chart.

    Preserves input order (ranking order) so callers can safely slice top-N
    afterward without alphabetical membership churn. Deterministic collision
    slotting only — does not invent scores.
    """
    mapped: list[dict[str, Any]] = []
    for point in points:
        item = dict(point)
        item["x"] = float(item.get("strategy") or 0.0)
        item["y"] = float(item.get("offering") or 0.0)
        mapped.append(item)
    fixed = avoid_chart_coord_collisions(
        mapped,
        step=step,
        x_lo=1.0,
        x_hi=4.0,
        y_lo=1.0,
        y_hi=4.0,
        update_quadrant=False,
    )
    out: list[dict[str, Any]] = []
    for item in fixed:
        row = {k: v for k, v in item.items() if k not in {"x", "y", "q"}}
        row["strategy"] = round(max(1.0, min(4.0, float(item["x"]))), 1)
        row["offering"] = round(max(1.0, min(4.0, float(item["y"]))), 1)
        out.append(row)
    return out


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
                if not name:
                    continue
                # Explicit false clears matrix/chart inflation; true credits support.
                if feature.get("supported") is True:
                    bucket[name] = True
                elif feature.get("supported") is False:
                    bucket[name] = False
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


def apply_preserving_notable_divergences(markdown: str, fn: Any) -> str:
    """Run fn on report body except resolution-table / notable-divergences quotes."""
    text = markdown or ""
    start = re.search(
        r"\n### Consensus Resolution Table|\n\*\*Notable divergences\*\*",
        text,
    )
    if not start:
        return fn(text)
    # Protect through the next H2, or EOF for the legacy divergences block.
    rest = text[start.start() + 1 :]
    nxt = re.search(r"\n## ", rest)
    end = start.start() + 1 + (nxt.start() if nxt else len(rest))
    return fn(text[: start.start()]) + text[start.start() : end] + fn(text[end:])


def _clean_text(text: str) -> str:
    return sanitize_compression_markers(text or "")


def _normalize_divergence_text(text: str) -> str:
    """Normalize divergence prose for near-duplicate detection."""
    cleaned = _clean_text(text or "")
    cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", cleaned)
    cleaned = cleaned.lower()
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


def _divergence_token_jaccard(a: str, b: str) -> float:
    ta = {t for t in a.split() if t}
    tb = {t for t in b.split() if t}
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    union = len(ta | tb)
    return inter / union if union else 0.0


_DIVERGENCE_SUBJECTS: tuple[tuple[str, str], ...] = (
    ("adjacent only band", "adjacent-only"),
    ("adjacent-only band", "adjacent-only"),
    ("generic agent frameworks", "adjacent-only"),
    ("cognition scout", "cognition-scout"),
    ("magic.dev", "magic-dev"),
    ("magic dev", "magic-dev"),
    ("github spec kit", "spec-kit"),
    ("host runtime", "host-runtimes"),
    ("augment cosmos", "augment-cosmos"),
    ("augment code", "augment-cosmos"),
    ("cross session", "cross-session"),
    ("secondary market", "secondary-market"),
    ("sdlc plugin", "secondary-market"),
    ("tertiary market", "tertiary-market"),
    ("tertiary agentic", "tertiary-market"),
    ("sunset list", "sunset-list"),
    ("primary apo market", "apo-maturity"),
    ("ai dlc", "ai-dlc"),
    ("aidlc", "ai-dlc"),
    ("silver bullet", "silver-bullet"),
    ("factory.ai", "factory-ai"),
    ("factory ai", "factory-ai"),
    ("bmad method", "bmad"),
    ("cc10x", "cc10x"),
    ("conductor", "conductor"),
    ("factory", "factory-ai"),
    ("devin", "devin"),
    ("metagpt", "metagpt"),
    ("bmad", "bmad"),
    ("zuvo", "zuvo"),
)

_DIVERGENCE_SUBJECT_LABELS = {
    "ai-dlc": "AI-DLC",
    "silver-bullet": "Silver Bullet completeness",
    "conductor": "Conductor positioning",
    "magic-dev": "Magic.dev / Cognition Scout inclusion",
    "cognition-scout": "Magic.dev / Cognition Scout inclusion",
    "host-runtimes": "Host runtimes vs APO",
    "secondary-market": "Secondary SDLC-plugin threat",
    "cross-session": "Secondary-pack gates and state",
    "apo-maturity": "Primary APO market maturity",
    "factory-ai": "Factory.ai role",
    "cc10x": "cc10x plugin vs APO",
    "zuvo": "Zuvo classification",
    "adjacent-only": "Adjacent-only frameworks",
    "tertiary-market": "Tertiary SaaS inclusion",
    "augment-cosmos": "Augment Cosmos naming",
    "spec-kit": "GitHub Spec Kit",
    "sunset-list": "Sunset-list handling",
    "bmad": "BMAD / secondary packs",
    "devin": "Devin vs tertiary SaaS",
}

_STANCE_NEG = (
    "weakest",
    "excluded",
    "hard excluded",
    "hard-excluded",
    "must not",
    "must never",
    "never plotted",
    "not a shipped",
    "methodology framework",
    "methodology/framework",
    "complementary rather",
    "not directly substitutable",
    "self-referential",
    "unsupported superlative",
    "overbroad",
    "home-field",
    "home-team",
    "self-serving",
    "thin wrappers",
    "conceptual lifecycle",
    "conceptual framework",
)
_STANCE_POS = (
    "enterprise-grade",
    "leading verifiable",
    "in-scope",
    "analyst-grade",
    "formidable",
    "most complete",
    "most comprehensive",
    "closest tertiary",
    "represent the tertiary",
    "round out the tertiary",
    "process layer",
    "process-layer",
)


def _divergence_subject_key(norm: str, claim_key: str = "") -> str:
    """Topic key for clustering. Prefers the earliest head-of-claim subject."""
    blob = f"{claim_key} {norm}".strip()
    tokens = [t for t in blob.split() if t]
    head = " ".join(tokens[:16])
    priority_pos = 10**9
    priority_key = ""
    for needle, key in _DIVERGENCE_SUBJECTS:
        if key not in {"magic-dev", "cognition-scout"}:
            continue
        pos = blob.find(needle)
        if pos >= 0 and pos < priority_pos:
            priority_pos = pos
            priority_key = key
    if priority_key:
        return priority_key
    best_key = ""
    best_pos = 10**9
    best_len = 0
    for needle, key in _DIVERGENCE_SUBJECTS:
        pos = blob.find(needle)
        if pos < 0:
            continue
        in_head = needle in head
        if not in_head and pos > 48:
            continue
        if pos < best_pos or (pos == best_pos and len(needle) > best_len):
            best_pos = pos
            best_len = len(needle)
            best_key = key
    if best_key:
        return best_key
    return " ".join(tokens[:4]) if tokens else blob[:48]


def _item_stance(side: dict[str, Any]) -> str:
    raw = str(side.get("stance_text") or side.get("text") or "")
    return _divergence_stance(_normalize_divergence_text(raw))


def _divergence_stance(norm: str) -> str:
    blob = _normalize_divergence_text(norm or "")
    neg = any(_normalize_divergence_text(tok) in blob for tok in _STANCE_NEG)
    pos = any(_normalize_divergence_text(tok) in blob for tok in _STANCE_POS)
    if neg and not pos:
        return "neg"
    if pos and not neg:
        return "pos"
    return "mix"


def _clip_divergence_claim(text: str, limit: int = 220) -> str:
    cleaned = re.sub(r"\s+", " ", _clean_text(text or "")).strip()
    if len(cleaned) <= limit:
        return cleaned.rstrip(".")
    clipped = cleaned[: limit - 1]
    if " " in clipped:
        clipped = clipped.rsplit(" ", 1)[0]
    return clipped.rstrip(".,;:") + "…"


def _agent_list(item: dict[str, Any]) -> list[str]:
    raw = item.get("supporting_agents") or item.get("agents") or []
    if isinstance(raw, str):
        raw = [raw]
    out = [str(a).strip() for a in raw if str(a).strip()]
    return out


def _family_list(item: dict[str, Any]) -> list[str]:
    raw = item.get("model_families") or item.get("families") or []
    if isinstance(raw, str):
        raw = [raw]
    out = [str(a).strip() for a in raw if str(a).strip()]
    return out


def _normalize_divergence_item(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        text = _clean_text(str(raw or "")).strip()
        if not text:
            return None
        return {
            "text": text,
            "claim_key": "",
            "supporting_agents": [],
            "model_families": [],
            "wave": "DR-TRIANGULATE",
            "support_count": 1,
        }
    text = _clean_text(str(raw.get("text") or "")).strip()
    if not text:
        return None
    item = dict(raw)
    item["text"] = text
    item["claim_key"] = str(item.get("claim_key") or "")
    item["supporting_agents"] = _agent_list(item)
    item["model_families"] = _family_list(item)
    item["wave"] = str(item.get("wave") or "DR-TRIANGULATE")
    item["support_count"] = int(item.get("support_count") or len(item["supporting_agents"]) or 1)
    return item


def _critique_divergence_items(envelopes: list[Any] | None) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for env in envelopes or []:
        if not isinstance(env, dict) or env.get("phase_id") != "DR-CRITIQUE":
            continue
        payload = env.get("payload") if isinstance(env.get("payload"), dict) else {}
        for crit in payload.get("critiques") or []:
            if not isinstance(crit, dict):
                continue
            sev = str(crit.get("severity") or "").lower()
            if sev not in {"high", "critical"}:
                continue
            target = _clean_text(str(crit.get("target") or "")).strip()
            finding = _clean_text(str(crit.get("finding") or "")).strip()
            text = f"{target}: {finding}".strip(": ").strip()
            if not text:
                continue
            items.append(
                {
                    "text": text,
                    "claim_key": target,
                    "supporting_agents": [str(env.get("logical_model_id") or "").strip()]
                    if env.get("logical_model_id")
                    else [],
                    "model_families": [str(env.get("model_family_id") or "").strip()]
                    if env.get("model_family_id")
                    else [],
                    "wave": "DR-CRITIQUE",
                    "support_count": 1,
                    "label": "divergent",
                    "stance_text": finding,
                }
            )
    return items


def _is_divergence_restatement(a_norm: str, b_norm: str, similarity: float) -> bool:
    jac = _divergence_token_jaccard(a_norm, b_norm)
    if jac >= similarity:
        return True
    if a_norm[:60] and a_norm[:60] == b_norm[:60]:
        return True
    return False


def _merge_restatement_sides(
    cluster: list[dict[str, Any]],
    *,
    similarity: float,
) -> list[dict[str, Any]]:
    sides: list[dict[str, Any]] = []
    norms: list[str] = []
    for item in cluster:
        norm = _normalize_divergence_text(str(item.get("text") or ""))
        idx = next((i for i, prev in enumerate(norms) if _is_divergence_restatement(norm, prev, similarity)), -1)
        if idx < 0:
            side = dict(item)
            side["supporting_agents"] = list(_agent_list(item))
            side["model_families"] = list(_family_list(item))
            sides.append(side)
            norms.append(norm)
            continue
        prev = sides[idx]
        agents = set(_agent_list(prev)) | set(_agent_list(item))
        families = set(_family_list(prev)) | set(_family_list(item))
        prev_text = str(prev.get("text") or "")
        cur_text = str(item.get("text") or "")
        if len(cur_text) > len(prev_text) + 12:
            prev["text"] = cur_text
            norms[idx] = norm
        prev["supporting_agents"] = sorted(agents)
        prev["model_families"] = sorted(families)
        prev["support_count"] = int(prev.get("support_count") or 0) + int(item.get("support_count") or 0)
        if str(item.get("wave") or "") == "DR-CRITIQUE":
            prev["wave"] = "DR-CRITIQUE"
            if item.get("stance_text"):
                prev["stance_text"] = item.get("stance_text")
        elif str(prev.get("wave") or "") != "DR-CRITIQUE" and str(item.get("wave") or ""):
            prev["wave"] = str(item.get("wave"))
    return sides


def _format_inter_model_divergence(subject: str, sides: list[dict[str, Any]]) -> str:
    label = _DIVERGENCE_SUBJECT_LABELS.get(subject) or subject.replace("-", " ").title()
    parts: list[str] = []
    for side in sides[:4]:
        agents = _agent_list(side)
        families = _family_list(side)
        wave = str(side.get("wave") or "DR-TRIANGULATE")
        who = ", ".join(f"`{a}`" for a in agents[:3]) if agents else "unattributed claim"
        meta: list[str] = []
        if families:
            meta.append("/".join(families[:3]))
        if wave == "DR-CRITIQUE":
            meta.append("DR-CRITIQUE")
        prefix = who + (f" ({', '.join(meta)})" if meta else "")
        parts.append(f"{prefix} — {_clip_divergence_claim(str(side.get('text') or ''))}")
    return f"**{label}:** " + "; ".join(parts)


def _union_divergence_sides(group: list[dict[str, Any]]) -> dict[str, Any]:
    """Collapse same-stance paraphrases into one side, keeping the longest claim."""
    best = dict(group[0])
    agents: set[str] = set()
    families: set[str] = set()
    support = 0
    waves: set[str] = set()
    for item in group:
        agents.update(_agent_list(item))
        families.update(_family_list(item))
        support += int(item.get("support_count") or 1)
        waves.add(str(item.get("wave") or "DR-TRIANGULATE"))
        text = str(item.get("text") or "")
        if len(text) > len(str(best.get("text") or "")):
            best = dict(item)
    best["supporting_agents"] = sorted(agents)
    best["model_families"] = sorted(families)
    best["support_count"] = support
    if "DR-CRITIQUE" in waves:
        best["wave"] = "DR-CRITIQUE"
        stance_texts = [str(item.get("stance_text") or "") for item in group if item.get("stance_text")]
        if stance_texts:
            best["stance_text"] = max(stance_texts, key=len)
    return best


def _collapse_same_stance_sides(
    sides: list[dict[str, Any]],
    *,
    similarity: float,
) -> list[dict[str, Any]]:
    buckets: dict[str, list[dict[str, Any]]] = {"pos": [], "neg": [], "mix": []}
    for side in sides:
        stance = _item_stance(side)
        buckets.setdefault(stance, []).append(side)
    out: list[dict[str, Any]] = []
    if buckets["pos"]:
        out.append(_union_divergence_sides(buckets["pos"]))
    out.extend(_merge_restatement_sides(buckets["neg"], similarity=min(similarity, 0.40)))
    out.extend(_merge_restatement_sides(buckets["mix"], similarity=min(similarity, 0.38)))
    return out


def _sides_disagree(sides: list[dict[str, Any]], *, similarity: float) -> bool:
    if len(sides) < 2:
        return False
    families: set[str] = set()
    agents: set[str] = set()
    waves: set[str] = set()
    stances: set[str] = set()
    crit_neg = False
    tri_pos = False
    tri_mix = False
    for side in sides:
        families.update(_family_list(side))
        agents.update(_agent_list(side))
        wave = str(side.get("wave") or "DR-TRIANGULATE")
        waves.add(wave)
        stance = _item_stance(side)
        stances.add(stance)
        if wave == "DR-CRITIQUE" and stance == "neg":
            crit_neg = True
        elif wave != "DR-CRITIQUE" and stance == "pos":
            tri_pos = True
        elif wave != "DR-CRITIQUE" and stance == "mix":
            tri_mix = True
    distinct_sources = len(families) >= 2 or len(agents) >= 2 or len(waves) >= 2
    if not distinct_sources:
        return False
    if "neg" in stances and "pos" in stances:
        return True
    # Critique wave vs triangulation only when the critique actually contradicts.
    if crit_neg and (tri_pos or tri_mix):
        return True
    return False


def select_notable_divergences(
    items: list[Any] | None,
    *,
    limit: int = 8,
    similarity: float = 0.55,
    envelopes: list[Any] | None = None,
) -> list[dict[str, Any]]:
    """Select inter-model research disagreements (not chart-axis mismatches).

    Clusters triangulation/critique claims by subject, merges near-duplicate
    restatements (keeps one AI-DLC copy per *side*), and emits a bullet only
    when contributing models / waves / SCRs actually disagree.
    """
    pool: list[dict[str, Any]] = []
    for raw in list(items or []) + _critique_divergence_items(envelopes):
        item = _normalize_divergence_item(raw)
        if item:
            pool.append(item)

    clusters: dict[str, list[dict[str, Any]]] = {}
    for item in pool:
        norm = _normalize_divergence_text(str(item.get("text") or ""))
        subject = _divergence_subject_key(norm, _normalize_divergence_text(str(item.get("claim_key") or "")))
        clusters.setdefault(subject, []).append(item)

    scored: list[tuple[int, dict[str, Any]]] = []
    for subject, cluster in clusters.items():
        sides = _merge_restatement_sides(cluster, similarity=similarity)
        sides = _collapse_same_stance_sides(sides, similarity=similarity)
        if not _sides_disagree(sides, similarity=similarity):
            continue
        families: set[str] = set()
        waves: set[str] = set()
        stances: set[str] = set()
        for side in sides:
            families.update(_family_list(side))
            waves.add(str(side.get("wave") or "DR-TRIANGULATE"))
            stances.add(_item_stance(side))
        rank = (
            len(families) * 10
            + (25 if "DR-CRITIQUE" in waves else 0)
            + (12 if "neg" in stances and "pos" in stances else 0)
            + len(sides)
        )
        text = _format_inter_model_divergence(subject, sides)
        scored.append(
            (
                rank,
                {
                    "text": text,
                    "claim_key": subject,
                    "subject": subject,
                    "sides": sides,
                    "support_count": sum(int(s.get("support_count") or 1) for s in sides),
                    "model_families": sorted(families),
                    "label": "divergent",
                },
            )
        )
    scored.sort(key=lambda pair: (-pair[0], str(pair[1].get("subject") or "")))
    return [item for _, item in scored[:limit]]


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
    kcfs: list[str] | None = None,
) -> dict[str, Any]:
    factors = kcfs if kcfs is not None else list(KCF_NAMES)
    data = []
    for kcf in factors:
        tick = _feat_tick(feats, kcf)
        # Evidenced true = 5; evidenced false or unknown-on-a-selected-factor = 1.
        # Do not invent mid-scores (3/2) for unverified cells.
        data.append(5 if tick is True else 1)
    oss_slugs = {e["slug"] for e in (OSS_CATALOG if oss is None else oss)}
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

    filtered = filter_vendor_link_pairs(pairs)
    # Drop 404 / non-OK vendor URLs so synthesize never emits dead homepage links.
    healthy, dropped = filter_healthy_link_pairs(filtered)
    if dropped:
        import sys

        for item in dropped:
            print(
                f"[vendor-url-health] dropping {item.get('label')!r} → "
                f"{item.get('url')} ({item.get('error') or item.get('status')})",
                file=sys.stderr,
            )
    return healthy


def _linkify_markdown_vendors(
    markdown: str,
    link_pairs: list[list[str]],
    *,
    protected_labels: set[str] | None = None,
) -> str:
    """Wrap vendor display names in markdown links for all prose occurrences."""
    if not link_pairs:
        return linkify_bare_http_urls(markdown)
    protected = {
        normalize_vendor_link_label(x)
        for x in (protected_labels or set())
        if normalize_vendor_link_label(x)
    }
    # Placeholder-protect longer unlinked labels so shorter linked names
    # (e.g. "Claude Code") cannot rewrite inside "Claude Code Expert".
    placeholders: list[tuple[str, str]] = []
    text = markdown
    for i, label in enumerate(sorted(protected, key=len, reverse=True)):
        if label not in text:
            continue
        token = f"\uE000PROT{i}\uE001"
        text = text.replace(label, token)
        placeholders.append((token, label))

    segments = re.split(r"(\[[^\]]+\]\([^)]+\)|https?://\S+)", text)
    for label, url in sorted(
        filter_vendor_link_pairs(link_pairs),
        key=lambda p: -len(str(p[0])),
    ):
        label = str(label).strip()
        url = str(url).strip()
        if not label or not url.startswith("http"):
            continue
        escaped = re.escape(label)
        pattern = re.compile(rf"\b({escaped})\b")
        for idx in range(0, len(segments), 2):
            segments[idx] = pattern.sub(rf"[\1]({url})", segments[idx])
    out = "".join(segments)
    for token, label in placeholders:
        out = out.replace(token, label)
    return linkify_bare_http_urls(out)


def build_vendor_buckets(
    mq_data: list[dict[str, Any]],
    *,
    gmq_data: list[dict[str, Any]] | None = None,
    commercial: list[dict[str, str]] | None = None,
    oss: list[dict[str, str]] | None = None,
    known: dict[str, str] | None = None,
) -> dict[str, list[str]]:
    # None → legacy global catalogs. Empty list must stay empty (all-OSS or
    # all-commercial markets) — `or` would wrongly inject cross-market vendors.
    commercial_src = COMMERCIAL_CATALOG if commercial is None else commercial
    oss_src = [*OSS_CATALOG, *EMERGING_CATALOG] if oss is None else oss
    commercial_labels = [_catalog_label(e, known=known) for e in commercial_src]
    oss_labels = [_catalog_label(e, known=known) for e in oss_src]
    # Positioning Matrix (MQ) is authoritative for Leaders/Challengers filters.
    # GMQ may disagree (e.g. MQ Visionaries / GMQ Leaders) — do not let GMQ pollute MQ.
    quad_by_label: dict[str, str] = {}
    for point in gmq_data or []:
        label = str(point.get("label") or "").strip()
        quad = str(point.get("q") or "").strip()
        if label and quad:
            quad_by_label[label] = quad
    for point in mq_data:
        label = str(point.get("label") or "").strip()
        quad = str(point.get("q") or "").strip()
        if label and quad:
            quad_by_label[label] = quad  # MQ overwrites GMQ
    leaders = [label for label, quad in quad_by_label.items() if quad == "Leaders"]
    challengers = [label for label, quad in quad_by_label.items() if quad == "Challengers"]
    return {
        "commercial": commercial_labels,
        "oss": oss_labels,
        "leaders": leaders,
        "challengers": challengers,
    }


# Per-market chart axis profiles — markets must not reuse identical score geometry.
_MARKET_CHART_PROFILES: dict[str, dict[str, Any]] = {
    "apo": {
        "mq_x_feats": ("Workflow composition", "Atomic flow catalog", "Hook-enforced gates"),
        "mq_y_feats": ("Parent/child delegation", "Managed hosting", "Prebuilt SDLC templates"),
        "gmq_x_feats": (
            "Workflow composition",
            "Atomic flow catalog",
            "Prebuilt SDLC templates",
            "Free tier / OSS core",
        ),
        "gmq_y_feats": (
            "Parent/child delegation",
            "Managed hosting",
            "CI integration",
            "Hook-enforced gates",
            "IDE-native integration",
        ),
        "mq_base": (3.0, 3.0),
        "mq_feat_w": (2.2, 2.0),
        "mq_score_div": (15.0, 18.0),
        "gmq_base": (2.5, 2.5),
        "gmq_feat_w": (1.6, 1.35),
        "gmq_score_div": (12.0, 14.0),
    },
    "sdlc-plugins": {
        # Y must differentiate OSS packs — do NOT use universal OSS/IDE/hooks axes
        # (those clamp every plugin to Leaders y=9.5). Prefer rare capabilities.
        "mq_x_feats": ("Workflow composition", "Prebuilt SDLC templates", "Hook-enforced gates"),
        "mq_y_feats": ("Atomic flow catalog", "Parent/child delegation", "Managed hosting"),
        "gmq_x_feats": (
            "Prebuilt SDLC templates",
            "Atomic flow catalog",
            "Free tier / OSS core",
            "Skill/plugin marketplace",
        ),
        "gmq_y_feats": (
            "Parent/child delegation",
            "Atomic flow catalog",
            "Managed hosting",
            "Quick onboarding",
        ),
        "mq_base": (3.4, 2.4),
        "mq_feat_w": (1.55, 1.9),
        "mq_score_div": (14.0, 12.0),
        "gmq_base": (2.8, 2.3),
        "gmq_feat_w": (1.45, 1.5),
        "gmq_score_div": (13.0, 15.0),
    },
    "agentic-sdlc-saas": {
        "mq_x_feats": ("Workflow composition", "Managed hosting", "Parent/child delegation"),
        "mq_y_feats": ("Hook-enforced gates", "CI integration", "IDE-native integration"),
        "gmq_x_feats": (
            "Managed hosting",
            "Workflow composition",
            "Parent/child delegation",
            "Prebuilt SDLC templates",
        ),
        "gmq_y_feats": (
            "CI integration",
            "Hook-enforced gates",
            "IDE-native integration",
            "Automated review loops",
            "Zero-infra bootstrap",
        ),
        "mq_base": (3.3, 2.8),
        "mq_feat_w": (2.05, 2.15),
        "mq_score_div": (14.0, 16.5),
        "gmq_base": (2.2, 2.9),
        "gmq_feat_w": (1.7, 1.25),
        "gmq_score_div": (11.5, 13.5),
    },
}


def _market_chart_profile(market_id: str | None) -> dict[str, Any]:
    mid = str(market_id or "apo")
    if mid in _MARKET_CHART_PROFILES:
        return dict(_MARKET_CHART_PROFILES[mid])
    return dict(_MARKET_CHART_PROFILES["apo"])


def _clamp_chart_xy(x: float, y: float) -> tuple[float, float]:
    return max(1.0, min(9.5, x)), max(1.0, min(9.5, y))


def _round_coord(value: float, precision: int = 1) -> float:
    return round(float(value), precision)


def _uniquify_axis(
    values: list[float],
    *,
    lo: float,
    hi: float,
    step: float = 0.1,
    precision: int = 1,
    tiebreak: list[float] | None = None,
) -> list[float]:
    """Make axis values unique at `precision` decimals while preserving rank.

    Higher true scores claim slots first. Collisions take the nearest free slot
    toward the interior of [lo, hi] — deterministic collision avoidance around
    true scores, not random offset and not a global rescale. Idempotent when
    values are already unique.
    """
    n = len(values)
    if n == 0:
        return []
    if n == 1:
        return [max(lo, min(hi, _round_coord(values[0], precision)))]

    used: set[float] = set()
    out = [0.0] * n
    secondary = tiebreak if tiebreak is not None and len(tiebreak) == n else [0.0] * n
    # High scores first so a 9.5 cluster occupies 9.5, 9.4, … without dragging
    # an already-unique mid-scale point down. Equal scores yield to the other axis.
    order = sorted(
        range(n),
        key=lambda i: (-_round_coord(values[i], precision), -float(secondary[i]), i),
    )
    mid = (lo + hi) / 2.0
    for i in order:
        target = max(lo, min(hi, _round_coord(values[i], precision)))
        chosen: float | None = None
        if target not in used:
            chosen = target
        else:
            prefer_down = target >= mid
            k = 1
            while k < 400 and chosen is None:
                minus = _round_coord(target - k * step, precision)
                plus = _round_coord(target + k * step, precision)
                seq = (minus, plus) if prefer_down else (plus, minus)
                for cand in seq:
                    if lo - 1e-12 <= cand <= hi + 1e-12 and cand not in used:
                        chosen = cand
                        break
                k += 1
        if chosen is None:
            scan = lo
            while scan <= hi + 1e-12:
                rv = _round_coord(scan, precision)
                if rv not in used:
                    chosen = rv
                    break
                scan = _round_coord(scan + step, precision)
        if chosen is None:
            chosen = target
        used.add(chosen)
        out[i] = chosen
    return out


def avoid_chart_coord_collisions(
    points: list[dict[str, Any]],
    *,
    step: float = 0.1,
    x_lo: float = 1.0,
    x_hi: float = 9.5,
    y_lo: float = 1.0,
    y_hi: float = 9.5,
    x_key: str = "x",
    y_key: str = "y",
    update_quadrant: bool = True,
) -> list[dict[str, Any]]:
    """Ensure no two points share the same x *or* the same y on a chart.

    Analyst reports almost never align two solutions on a shared vertical or
    horizontal. Rank order of the true scores is preserved; only the smallest
    step-sized slot shift is applied (collision avoidance, not random jitter).
    Idempotent when axes are already unique.
    """
    if not points:
        return []
    items = [dict(point) for point in points]
    xs = [float(item.get(x_key) or 0.0) for item in items]
    ys = [float(item.get(y_key) or 0.0) for item in items]
    new_x = _uniquify_axis(xs, lo=x_lo, hi=x_hi, step=step, tiebreak=ys)
    new_y = _uniquify_axis(ys, lo=y_lo, hi=y_hi, step=step, tiebreak=xs)
    out: list[dict[str, Any]] = []
    for item, x, y in zip(items, new_x, new_y):
        orig_q = item.get("q")
        item[x_key] = x
        item[y_key] = y
        if x_key == "x":
            item["x"] = x
        if y_key == "y":
            item["y"] = y
        if update_quadrant and x_key == "x" and y_key == "y":
            item["q"] = _quadrant(x, y)
        elif orig_q:
            item["q"] = orig_q
        out.append(item)
    return out


def chart_listed_membership(
    *,
    core: list[str] | set[str],
    adjacent: list[str] | set[str] | None = None,
    reason_by_slug: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Canonical membership sets for chart↔list consistency invariants."""
    core_set = {str(s) for s in core if s}
    adj_set = {str(s) for s in (adjacent or []) if s} - core_set
    listed = sorted(core_set | adj_set)
    reasons = reason_by_slug or {}
    return {
        "core": sorted(core_set),
        "adjacent": sorted(adj_set),
        "listed": listed,
        "unplotted": [
            {
                "slug": slug,
                "reason": reasons.get(
                    slug,
                    "adjacent competitor — listed for the market, not MQ/Wave core",
                ),
            }
            for slug in sorted(adj_set)
        ],
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
    market_id: str | None = None,
    adjacent_slugs: set[str] | list[str] | None = None,
) -> dict[str, Any]:
    effective_known = known or KNOWN_SOLUTIONS
    rankings = [r for r in (comparison.get("rankings") or []) if isinstance(r, dict)]
    forbidden: set[str] = set()
    if pack:
        try:
            from category_pack import get_hard_exclusion_slugs

            forbidden = {str(s) for s in get_hard_exclusion_slugs(pack, need or {}) if s}
        except Exception:
            forbidden = set()
    if forbidden:
        rankings = [r for r in rankings if str(r.get("solution") or "") not in forbidden]
        if market_slugs:
            market_slugs = {str(s) for s in market_slugs if str(s) not in forbidden}
    if market_slugs:
        rankings = [r for r in rankings if str(r.get("solution")) in market_slugs]
        present = {str(r.get("solution")) for r in rankings if r.get("solution")}
        # Every market core must plot — OSS cores (e.g. MetaGPT) must not vanish from MQ
        # solely because they are missing from comparison rankings or fall past a top-12 cut.
        for slug in sorted(market_slugs):
            if slug not in present:
                rankings.append({"solution": slug, "score": 0})
                present.add(slug)
        if not rankings:
            rankings = [{"solution": slug, "score": 0} for slug in sorted(market_slugs)]
    # Charts use ranked core solutions; include all market cores (cap by pack max).
    chart_cap = 12
    if market_slugs:
        chart_cap = max(12, len(market_slugs))
        if pack:
            try:
                from category_pack import get_markets

                for market in get_markets(pack):
                    mid_seeds = {
                        str(s.get("slug"))
                        for s in (market.get("seeds") or [])
                        if isinstance(s, dict) and s.get("slug")
                    }
                    if market_slugs & mid_seeds:
                        chart_cap = max(
                            chart_cap,
                            int(market.get("max_core_count") or chart_cap),
                            len(market_slugs),
                        )
                        break
            except Exception:
                chart_cap = max(chart_cap, len(market_slugs))
    top = rankings[:chart_cap]
    mq_data = []
    gmq_data = []
    wave_data = []
    profile = _market_chart_profile(market_id)
    mq_x_feats = tuple(profile["mq_x_feats"])
    mq_y_feats = tuple(profile["mq_y_feats"])
    gmq_x_feats = tuple(profile["gmq_x_feats"])
    gmq_y_feats = tuple(profile["gmq_y_feats"])
    mq_base_x, mq_base_y = profile["mq_base"]
    mq_feat_wx, mq_feat_wy = profile["mq_feat_w"]
    mq_score_dx, mq_score_dy = profile["mq_score_div"]
    gmq_base_x, gmq_base_y = profile["gmq_base"]
    gmq_feat_wx, gmq_feat_wy = profile["gmq_feat_w"]
    gmq_score_dx, gmq_score_dy = profile["gmq_score_div"]
    for item in top:
        slug = str(item.get("solution"))
        label = effective_known.get(slug, slug.replace("-", " ").title())
        score = int(item.get("score") or 0)
        feats = support.get(slug, {})
        mx = mq_base_x + sum(1 for f in mq_x_feats if _feat_supported(feats, f)) * mq_feat_wx
        my = mq_base_y + sum(1 for f in mq_y_feats if _feat_supported(feats, f)) * mq_feat_wy
        mx = mx + score / mq_score_dx
        my = my + score / mq_score_dy
        if _must_not_be_leader(market_id, slug, feats, root):
            my = min(my, _LEADER_Y_CAP)
        if _is_methodology_without_gates(feats):
            mx = min(mx, _METHODOLOGY_X_CAP)
            my = min(my, _METHODOLOGY_Y_CAP)
        mx, my = _clamp_chart_xy(mx, my)
        mq_data.append(
            {"slug": slug, "label": label, "x": round(mx, 1), "y": round(my, 1), "q": _quadrant(mx, my)}
        )

        gx = gmq_base_x + sum(1 for f in gmq_x_feats if _feat_supported(feats, f)) * gmq_feat_wx
        gy = gmq_base_y + sum(1 for f in gmq_y_feats if _feat_supported(feats, f)) * gmq_feat_wy
        gx = gx + score / gmq_score_dx
        gy = gy + score / gmq_score_dy
        if _must_not_be_leader(market_id, slug, feats, root):
            gy = min(gy, _LEADER_Y_CAP)
        if _is_methodology_without_gates(feats):
            gx = min(gx, _METHODOLOGY_X_CAP)
            gy = min(gy, _METHODOLOGY_Y_CAP)
        gx, gy = _clamp_chart_xy(gx, gy)
        gmq_data.append(
            {"slug": slug, "label": label, "x": round(gx, 1), "y": round(gy, 1), "q": _quadrant(gx, gy)}
        )

        offering = min(4.0, 1.5 + score / 10)
        strategy = _wave_strategy_score(
            feats,
            scr_text=_load_scr_text(root, slug),
        )
        presence = min(4, max(1, int(1 + score / 8)))
        # OSS/local install without vendor-operated hosting is not full Wave "presence".
        if not _feat_supported(feats, "Managed hosting"):
            presence = min(presence, 3)
        # Conceptual methodology without shipped gates is not a Wave peer of shipped orchestrators.
        if _is_methodology_without_gates(feats):
            continue
        if _must_not_be_leader(market_id, slug, feats, root):
            presence = min(presence, _NON_LEADER_WAVE_PRESENCE_CAP)
            offering = min(offering, _NON_LEADER_WAVE_OFFERING_CAP)
            strategy = min(strategy, _NON_LEADER_WAVE_STRATEGY_CAP)
        wave_data.append(
            {
                "slug": slug,
                "label": label,
                "offering": round(offering, 1),
                "strategy": round(strategy, 1),
                "presence": presence,
            }
        )
    mq_data = avoid_chart_coord_collisions(mq_data)
    gmq_data = avoid_chart_coord_collisions(gmq_data)
    demoted = {
        str(item.get("solution") or "")
        for item in top
        if _must_not_be_leader(
            market_id,
            str(item.get("solution") or ""),
            support.get(str(item.get("solution") or ""), {}),
            root,
        )
    }
    if demoted:
        mq_data = _enforce_non_leader_y(mq_data, demoted)
        gmq_data = _enforce_non_leader_y(gmq_data, demoted)
        mq_data = avoid_chart_coord_collisions(mq_data)
        gmq_data = avoid_chart_coord_collisions(gmq_data)
        mq_data = _enforce_non_leader_y(mq_data, demoted)
        gmq_data = _enforce_non_leader_y(gmq_data, demoted)
    methodology = {
        str(item.get("solution") or "")
        for item in top
        if _is_methodology_without_gates(support.get(str(item.get("solution") or ""), {}))
    }
    if methodology:
        mq_data = _enforce_axis_cap(mq_data, methodology, key="x", cap=_METHODOLOGY_X_CAP)
        mq_data = _enforce_axis_cap(mq_data, methodology, key="y", cap=_METHODOLOGY_Y_CAP)
        gmq_data = _enforce_axis_cap(gmq_data, methodology, key="x", cap=_METHODOLOGY_X_CAP)
        gmq_data = _enforce_axis_cap(gmq_data, methodology, key="y", cap=_METHODOLOGY_Y_CAP)
        mq_data = avoid_chart_coord_collisions(mq_data)
        gmq_data = avoid_chart_coord_collisions(gmq_data)
        mq_data = _enforce_axis_cap(mq_data, methodology, key="x", cap=_METHODOLOGY_X_CAP)
        mq_data = _enforce_axis_cap(mq_data, methodology, key="y", cap=_METHODOLOGY_Y_CAP)
        gmq_data = _enforce_axis_cap(gmq_data, methodology, key="x", cap=_METHODOLOGY_X_CAP)
        gmq_data = _enforce_axis_cap(gmq_data, methodology, key="y", cap=_METHODOLOGY_Y_CAP)
        if demoted:
            mq_data = _enforce_non_leader_y(mq_data, demoted)
            gmq_data = _enforce_non_leader_y(gmq_data, demoted)
    for _label, _pts in (("mq_data", mq_data), ("gmq_data", gmq_data)):
        xs = [float(p["x"]) for p in _pts]
        ys = [float(p["y"]) for p in _pts]
        if len(xs) != len(set(xs)) or len(ys) != len(set(ys)):
            raise ValueError(
                f"shared axis line remains in {market_id or category}:{_label}: "
                f"x={xs} y={ys}"
            )
    chart_slugs = [str(item.get("solution")) for item in top if item.get("solution")]
    if market_slugs:
        chart_slugs = sorted(set(chart_slugs) | set(market_slugs))
    reason_by_slug: dict[str, str] = {}
    if pack and market_id:
        for market in (pack.get("markets") or []):
            if str(market.get("id") or "") != str(market_id):
                continue
            for seed in (market.get("adjacent_seeds") or []):
                slug = str(seed.get("slug") or "")
                if not slug:
                    continue
                if seed.get("quarantine"):
                    reason_by_slug[slug] = (
                        "quarantined — identity/OSS/license unverified; watchlist only (not MQ/Wave/Leader)"
                    )
                elif "demot" in str(seed.get("notes") or "").lower():
                    reason_by_slug[slug] = str(seed.get("notes") or "demoted adjacent — not core plotted")
    membership = chart_listed_membership(
        core=market_slugs or chart_slugs,
        adjacent=adjacent_slugs,
        reason_by_slug=reason_by_slug,
    )
    plotted = {str(p.get("slug")) for p in mq_data if p.get("slug")}
    # Invariant: every plotted core must be in listed membership.
    stray = sorted(plotted - set(membership["listed"]))
    if stray and market_slugs:
        membership["listed"] = sorted(set(membership["listed"]) | plotted)
        membership["core"] = sorted(set(membership["core"]) | plotted)
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
        series = _vc_series_entry(
            slug, label, feats, known=effective_known, oss=oss, kcfs=vc_kcfs
        )
        existing_vc.add(label)
        if vendor_license_bucket(slug, license_map=license_map) == "oss":
            vc_oss.append(series)
        else:
            vc_commercial.append(series)

    # Value Curve / Leaders radar: every MQ leader (3A + 3B) with slug from chart points.
    leader_series = _collect_mq_leader_series(gmq_data, mq_data)
    leader_labels = [label for _, label in leader_series]
    vc_kcfs = select_vc_kcfs([slug for slug, _ in leader_series if slug], support)
    if not vc_kcfs:
        vc_kcfs = [k for k in KCF_NAMES if k != "Managed hosting"][:6]
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
        commercial_src = COMMERCIAL_CATALOG if commercial is None else commercial
        oss_src = OSS_CATALOG if oss is None else oss
        vc_core = list(commercial_src)[:5] + list(oss_src)[:5]
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
    chart_notes: list[str] = []
    mid = str(market_id or "")
    if mid == "apo":
        chart_notes.append(
            "Methodology/framework seeds without shipped hook gates (for example AI-DLC) are omitted "
            "from Wave and are not peer-complete on MQ: Completeness of Vision is capped so they do "
            "not plot as shipped-orchestrator peers; Ability to Execute is capped below Leaders."
        )
    if mid == "sdlc-plugins":
        chart_notes.append(
            "Leaders require hook-enforced gates plus inclusion-ledger cross-session pass. "
            "Methodology packs that fail those under-served criteria are Visionaries or lower "
            "even when workflow ticks are dense. Wave presence, offering, and strategy are capped "
            "for packs that fail Leader eligibility."
        )
    if mid == "agentic-sdlc-saas":
        chart_notes.append(
            "SaaS-core MQ/Wave plots shipped autonomous-delivery products with managed hosting. "
            "Coding-model labs without orchestration evidence are hard-excluded, not tertiary core."
        )
    if demoted:
        chart_notes.append(
            "Demoted from Leaders for missing gates and/or cross-session state: "
            + ", ".join(sorted(s for s in demoted if s))
            + "."
        )

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
        "wave_data": avoid_wave_coord_collisions(wave_data[:8]),
        "vc_kcfs": vc_kcfs,
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
        "market_id": market_id,
        "membership": membership,
        "plotted_slugs": sorted(plotted),
        "listed_slugs": membership["listed"],
        "unplotted": membership["unplotted"],
        "chart_notes": chart_notes,
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
        ma = (audit or {}).get("markets", {}).get(mid, {}) or {}
        market_core = set(ma.get("core") or slug_sets.get(mid, set()))
        market_adj = set(ma.get("adjacent") or [])
        try:
            from category_pack import get_hard_exclusion_slugs

            forbidden = {str(s) for s in get_hard_exclusion_slugs(pack, need or {}) if s}
        except Exception:
            forbidden = set()
        if forbidden:
            market_core -= forbidden
            market_adj -= forbidden
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
            market_id=mid,
            adjacent_slugs=market_adj,
        )
        chart["market_id"] = mid
        chart["market_role"] = market.get("role")
        chart["market_display_name"] = display
        # Chart↔list: every plotted slug label must appear in commercial∪oss buckets.
        buckets = chart.get("vendor_buckets") or {}
        bucket_labels = set(buckets.get("commercial") or []) | set(buckets.get("oss") or [])
        for point in chart.get("mq_data") or []:
            label = str(point.get("label") or "").strip()
            slug = str(point.get("slug") or "")
            if label and label not in bucket_labels:
                if vendor_license_bucket(slug, license_map=license_map) == "oss":
                    buckets.setdefault("oss", []).append(label)
                else:
                    buckets.setdefault("commercial", []).append(label)
                bucket_labels.add(label)
        chart["vendor_buckets"] = buckets
        # Per-market plotted_slugs must equal MQ slugs (membership.core after stray
        # merge). Adjacent/excluded vendors must not remain in plotted_slugs.
        mq_slugs = sorted(
            {str(p.get("slug")) for p in (chart.get("mq_data") or []) if p.get("slug")}
        )
        membership = dict(chart.get("membership") or {})
        membership["core"] = sorted(set(membership.get("core") or []) | set(mq_slugs))
        chart["membership"] = membership
        chart["plotted_slugs"] = mq_slugs
        chart["listed_slugs"] = membership.get("listed") or []
        chart["unplotted"] = membership.get("unplotted") or []
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
    return scrub_membership_framing(out, pack)


def _non_apo_display_labels(pack: dict[str, Any]) -> set[str]:
    """Display names that must not be framed as APO core (adjacent / other-market only)."""
    apo_slugs: set[str] = set()
    for market in get_markets(pack):
        if str(market.get("id") or "") == "apo":
            apo_slugs = {
                str(s.get("slug"))
                for s in (market.get("seeds") or [])
                if isinstance(s, dict) and s.get("slug")
            }
            break
    labels: set[str] = set()
    for market in get_markets(pack):
        mid = str(market.get("id") or "")
        for bucket in ("adjacent_seeds", "seeds"):
            if bucket == "seeds" and mid == "apo":
                continue
            for seed in market.get(bucket) or []:
                if not isinstance(seed, dict) or not seed.get("slug"):
                    continue
                slug = str(seed["slug"])
                if slug in apo_slugs:
                    continue
                if bucket == "seeds" and mid == "apo":
                    continue
                # Adjacent anywhere, or core seeds of non-APO markets, are not APO peers.
                if bucket == "adjacent_seeds" or mid != "apo":
                    name = str(seed.get("name") or slug).strip()
                    if name:
                        labels.add(name)
    return labels


def scrub_membership_framing(text: str, pack: dict[str, Any] | None) -> str:
    """Rewrite prose that mis-labels non-APO members (e.g. Conductor, Claude Harness) as APO peers.

    Operates line-by-line so full markdown documents are not collapsed to a single rewrite.
    """
    if not text or not pack:
        return text
    non_apo = _non_apo_display_labels(pack)
    if not non_apo:
        return text
    # Prefer longer names first so "Claude Harness" wins over "Claude".
    non_apo_sorted = sorted(non_apo, key=len, reverse=True)

    def _scrub_unit(unit: str) -> str:
        if not unit.strip():
            return unit
        matched = [n for n in non_apo_sorted if re.search(rf"\b{re.escape(n)}\b", unit, flags=re.I)]
        if not matched:
            return unit
        if not re.search(r"\bAPOs?\b|Agentic Process Orchestrator|primary-market APO", unit, flags=re.I):
            return unit

        out = unit

        def _rewrite_apo_candidate(buf: str, name: str, mid: str) -> str:
            """Rewrite bare or markdown-linked '<Name> is a primary-market APO candidate — '."""
            esc = re.escape(name)

            def _repl(m: re.Match[str]) -> str:
                url = m.group(1)
                if url:
                    return f"[{name}]({url}) {mid}"
                return f"{name} {mid}"

            # [Name](url) or bare Name, then APO-candidate clause.
            return re.sub(
                rf"(?:\[{esc}\]\(([^)]+)\)|\b{esc}\b)\s+is a primary-market APO candidate\s*[—\-–]\s*",
                _repl,
                buf,
                flags=re.I,
            )

        # Generic: non-APO products must not be called primary-market APO candidates.
        # Must match markdown-linked names: [Claude Harness](url) is a primary-market APO candidate
        for name in matched:
            if name.lower() == "claude harness":
                out = _rewrite_apo_candidate(
                    out,
                    name,
                    "is an SDLC-plugins methodology pack (not an APO peer) — ",
                )
                # Fallback for non-dash APO co-mentions still mislabeled as APO peers.
                if re.search(r"primary-market APO candidate", out, flags=re.I):
                    out = re.sub(
                        rf"(?:\[{re.escape(name)}\]\([^)]+\)|\b{re.escape(name)}\b)(?=[^.]*\bAPOs?\b)",
                        f"{name} (sdlc-plugins, not APO)",
                        out,
                        count=1,
                        flags=re.I,
                    )
            elif name.lower() == "magic.dev":
                out = _rewrite_apo_candidate(
                    out,
                    name,
                    "is a hard-excluded coding-model lab (not a SaaS core, not an APO peer) — ",
                )
            elif name.lower() in {
                "cursor",
                "claude code",
                "codex",
                "github copilot",
                "cognition scout",
            }:
                out = _rewrite_apo_candidate(
                    out,
                    name,
                    "is a host-runtime / SaaS-adjacent surface (not an APO peer) — ",
                )
            else:
                out = _rewrite_apo_candidate(
                    out,
                    name,
                    "is not an APO peer — ",
                )

        if re.search(r"cc10x occupies a mid-tier APO", out, flags=re.I):
            out = re.sub(
                r"cc10x occupies a mid-tier APO band[^.]*\.",
                "cc10x is an SDLC-plugins Claude Code plugin (not an APO peer).",
                out,
                flags=re.I,
            )

        if not re.search(r"\bConductor\b", out, flags=re.I):
            return out

        if re.search(r"mid-tier APO cluster|mid-tier APO band", out, flags=re.I):
            prefix = ""
            stripped = out.lstrip()
            if stripped.startswith("- "):
                prefix = "- "
            elif stripped.startswith("* "):
                prefix = "* "
            return (
                f"{prefix}cc10x is an SDLC-plugins Claude Code plugin (not an APO peer); "
                "Conductor is a SaaS-adjacent coding-agent aggregator (parallel Claude Code/Codex "
                "worktrees), not an APO peer; Director is an APO seed with unverified identity "
                "and no shipped hook gates — not a plugin and not an aggregator."
            )
        if re.search(r"most credible non-SB APO|non-SB APO entrants", out, flags=re.I):
            return (
                "AI-DLC is the most credible non-SB APO entrant in the primary market on "
                "methodology pedigree; Conductor is SaaS-adjacent (coding-agent aggregator), not APO."
            )
        if re.search(r"Conductor occupies a distinct sub-position", out, flags=re.I):
            return (
                "Conductor occupies a SaaS-adjacent niche — parallel-worker orchestration and "
                "workspace isolation for coding agents — and is not an APO peer to gate-enforcement "
                "orchestrators like Silver Bullet."
            )
        if re.search(
            r"leading verifiable solutions|thinly populated.*Conductor|Conductor.*leading",
            out,
            flags=re.I,
        ):
            out = re.sub(
                r"\bConductor(?:\.build)?\b",
                "REMOVED_NON_APO",
                out,
                flags=re.I,
            )
        # Strip Conductor (plain + markdown-linked) from APO enumerations / seed lists.
        out = re.sub(r"\[Conductor(?:\.build)?\]\([^)]+\)", "Conductor", out, flags=re.I)
        out = re.sub(r",\s*Conductor(?:\.build)?(?=\s*[,)])", "", out, flags=re.I)
        out = re.sub(r"\bConductor(?:\.build)?,\s*", "", out, flags=re.I)
        out = re.sub(r"\band\s+Conductor(?:\.build)?\b", "", out, flags=re.I)
        out = re.sub(r"\bConductor(?:\.build)?\s+and\s+", "", out, flags=re.I)
        out = out.replace("REMOVED_NON_APO", "")
        # Clarify remaining Conductor+APO co-mentions.
        if re.search(r"\bConductor\b", out, flags=re.I) and re.search(
            r"\bAPOs?\b", out, flags=re.I
        ):
            if not re.search(r"not an? APO|not APO|SaaS-adjacent", out, flags=re.I):
                out = re.sub(
                    r"\bConductor\b",
                    "Conductor (SaaS-adjacent coding-agent aggregator, not APO)",
                    out,
                    count=1,
                    flags=re.I,
                )
        out = re.sub(r"\s{2,}", " ", out)
        out = re.sub(r",\s*,", ",", out)
        out = re.sub(r",\s+and\s+and\b", ", and", out)
        out = re.sub(r"\(\s*,", "(", out)
        out = re.sub(r",\s*\)", ")", out)
        out = re.sub(r",\s+and\s+\.", ".", out)
        out = re.sub(r"\s+\.", ".", out)
        return out.strip(" ,")

    # Preserve document structure: scrub each line independently.
    return "\n".join(_scrub_unit(line) for line in text.splitlines())


def _envelope_claim_records(envelopes: list[dict[str, Any]]) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    for env in envelopes or []:
        if not isinstance(env, dict):
            continue
        model = str(env.get("logical_model_id") or "unknown")
        family = _model_family_label(model)
        phase = str(env.get("phase_id") or "")
        payload = env.get("payload") or {}
        texts: list[str] = []
        cands = payload.get("claim_candidates") if isinstance(payload, dict) else None
        if isinstance(cands, list):
            for item in cands:
                if isinstance(item, dict) and item.get("text"):
                    texts.append(str(item["text"]))
        if isinstance(payload, dict):
            for ev in payload.get("evidence") or []:
                if isinstance(ev, dict):
                    blob = ev.get("claim") or ev.get("text")
                    if blob:
                        texts.append(str(blob))
                elif isinstance(ev, str) and ev.strip():
                    texts.append(ev)
        for text in texts:
            cleaned = _clean_text(text).strip()
            if cleaned:
                records.append(
                    {"model": model, "family": family, "phase": phase, "text": cleaned}
                )
    return records


_CONSENSUS_THEMES: tuple[tuple[str, tuple[str, ...], str, str], ...] = (
    (
        "process-first",
        (
            "process layer",
            "above a host",
            "above the host",
            "host coding-agent",
            "compliance/enforcement layer",
        ),
        "Process layer above host runtimes",
        "Contributing models treat Agentic Process Orchestrators as a process or "
        "enforcement layer above a host coding-agent runtime, not as a synonym for "
        "autonomous code generation.",
    ),
    (
        "hook-gates",
        (
            "hook",
            "deterministic gate",
            "machine-checkable",
            "quality gate",
            "pretooluse",
        ),
        "Hook-enforced and deterministic gates",
        "Models agree that machine-checkable gates (host hooks, blocking quality rails) "
        "are the main differentiator versus prompt- or persona-level methodology packs, "
        "which an agent can skip.",
    ),
    (
        "methodology-packs",
        (
            "methodology pack",
            "sdlc plugin",
            "secondary-market",
            "secondary market",
        ),
        "SDLC plugin / methodology packs as substitutes",
        "Models agree the secondary market (BMAD, GSD, Superpowers, Spec Kit, Ruflo, "
        "Oh My Pi, and peers) covers plan-to-ship workflows as host plugins. That is a "
        "substitute class, not automatic Leader standing on the primary APO chart.",
    ),
    (
        "cross-session",
        (
            "cross-session",
            "persistent memory",
            "state machine",
        ),
        "Cross-session state is under-served",
        "Models agree durable cross-session state is the weakest inclusion criterion "
        "for most methodology packs; markdown re-read per session is not an enforced "
        "state machine.",
    ),
    (
        "tertiary-saas",
        (
            "tertiary",
            "autonomous delivery",
            "factory.ai",
            "devin",
        ),
        "Tertiary SaaS as buying substitutes",
        "Models agree Factory.ai, Devin, and Augment Cosmos are analyst-grade substitutes "
        "for process-orchestration buying even when they do not self-label as APO. "
        "They are scored in the SaaS market, not as APO peers.",
    ),
)


def build_consensus_patterns(
    envelopes: list[dict[str, Any]],
    *,
    min_families: int = 3,
) -> list[dict[str, Any]]:
    """Synthesize what contributing models actually agreed on (not trend stubs)."""
    records = [
        rec
        for rec in _envelope_claim_records(envelopes)
        if rec.get("phase") in {"DR-TRIANGULATE", "DR-CRITIQUE", "DR-RETRIEVE"}
    ]
    patterns: list[dict[str, Any]] = []
    for theme_id, needles, title, synthesis in _CONSENSUS_THEMES:
        families: set[str] = set()
        models: set[str] = set()
        for rec in records:
            blob = rec["text"].lower()
            if any(needle in blob for needle in needles):
                families.add(rec["family"])
                models.add(rec["model"])
        if len(families) < min_families:
            continue
        patterns.append(
            {
                "id": theme_id,
                "title": title,
                "text": synthesis,
                "families": sorted(families),
                "models": sorted(models),
            }
        )
    return patterns


def _scoring_methodology_lines(
    comparison: dict[str, Any],
    pack: dict[str, Any] | None,
) -> list[str]:
    """Buyer-readable scoring rubric — ticks × weights, no jitter, no hidden model."""
    lines = [
        "### Scoring methodology",
        "",
        "Charts answer **which evidenced capabilities a vendor has**, not a 100-point brand "
        "score and not a 'most complete product' ranking. Every plotted number is "
        "reproducible from the comparison matrix in this report (`comparison/comparison.json`). "
        "`solutions/<slug>/features.json` is the machine copy of those same ticks — not a "
        "hidden feature set.",
        "",
        "**1. Comparison-matrix ranking (buyer: weighted capability depth).** "
        "Each matrix row has a priority. A ✔ adds that row's points; an empty cell adds 0. "
        "This is the MultAI comparator, **not** a TopGun 55/20/15/10 blend:",
        "",
        "- Critical = **5** · Very High = **4** · High = **3** · Medium = **2** · Low = **1**",
        "- Ranking score = sum of (priority points × 1 if ticked). Stored as "
        "`comparison.rankings[].score`.",
        "",
        "**2. Chart coordinates (buyer: process depth vs execute depth).** "
        "Each axis uses a short feature list (the buyer-priority capabilities for that "
        "market), not the full matrix. For each axis:",
        "",
        "1. **Floor** — where a vendor with zero axis ticks still sits so they remain visible.",
        "2. **Tick points** — each evidenced axis feature adds a fixed number of chart points "
        "(points-per-tick). That is the weight: how much one capability moves the plot.",
        "3. **Ranking remainder** — `ranking_score ÷ spread`. Spread is **how many ranking "
        "points equal 1.0 chart unit**, so two vendors with the same axis ticks still "
        "separate slightly by overall matrix depth. Example: spread 15 means a 15-point "
        "ranking gap moves that axis by 1.0.",
        "4. **Caps** — Leader eligibility and methodology-without-gates (below) can lower "
        "an axis; they never invent ticks.",
        "5. **Collision slotting** — if two vendors would share an X or a Y at one decimal "
        "place, a deterministic 0.1-step walk takes the nearest free slot inside the chart "
        "bounds. Rank order of the true scores is preserved. This is collision avoidance, "
        "**not a score and not random jitter**. The engine does not apply jitter amplitudes.",
        "",
        "Positioning Matrix (3A) X = process / offering depth; Y = execute / operations. "
        "Magic Quadrant (3B) X = Completeness of Vision; Y = Ability to Execute. "
        "Quadrants split at **5.5 / 5.5** (Leaders top-right).",
        "",
        "**3. Wave (3C).** Current Offering = floor 1.5 + ranking_score/10, cap 4 "
        "(matrix depth as current product). Strength of Strategy starts at 1.0, adds the "
        "weighted feature ticks below, then small SCR-text bonuses (multi-host 0.10/0.25, "
        "OSS license 0.20, marketplace/ecosystem 0.15, roadmap 0.10, bonus cap +0.55), "
        "then cap 4 — **not** `1.2 + count(Workflow, Atomic)`. Market Presence = "
        "`int(1 + ranking_score/8)`, cap 4, then cap 3 without Managed hosting. "
        "Packs that fail Leader eligibility are capped to presence ≤ 2 / offering ≤ 2.4 / "
        "strategy ≤ 2.5. Methodology-without-gates seeds are **omitted from Wave**.",
        "",
        "**Strategy feature weights (points added when the matrix ticks that feature):** "
        + "; ".join(f"{name} +{wt:.2f}" for name, wt in _WAVE_STRATEGY_FEATURE_WEIGHTS)
        + ".",
        "",
        "**4. Blue Ocean (3D).** Leaders only. A factor is plotted only when at least one "
        "Leader has matrix evidence. True = 5, otherwise 1. Unmanaged OSS hosting is not "
        "plotted as a flat factor when no Leader has hosting. Zero-infra bootstrap is **not** "
        "treated as Managed hosting.",
        "",
        "**Leader eligibility.** SDLC plugins need hook-enforced gates **and** "
        "inclusion-ledger cross-session pass. APO seeds without shipped hook gates cannot "
        "occupy Leaders. Plugin MQ Leaders = Silver Bullet only in this run is that "
        "feature-gate fact — not a 'most complete product' claim.",
        "",
        "**Hard-exclusion membership.** A slug on the pack hard-exclusion list (Magic.dev as "
        "`coding_agent`; A.Team as professional services) has **one** membership — excluded. "
        "It is not a core, not an MQ/Wave point, and not a comparison-matrix column. "
        "Contributing-model seed lists that re-include it are envelope quotes, not membership.",
        "",
        "**Not scored.** Multi-model triangulation, brand reputation, and COI. "
        "Triangulation is a research method for this document; vendors were not graded on it. "
        "This report does not call any vendor 'most complete'.",
        "",
    ]
    by_priority: dict[str, list[str]] = {}
    for row in comparison.get("rows") or []:
        if not isinstance(row, dict) or row.get("type") != "feature":
            continue
        name = str(row.get("name") or "").strip()
        if not name:
            continue
        pri = str(row.get("priority") or "Unspecified")
        by_priority.setdefault(pri, []).append(name)
    if by_priority:
        lines.append(
            "Matrix rows in this run (the ranking uses these priorities; chart axes use the "
            "short feature lists in the rubric table, not every row as an axis tick):"
        )
        lines.append("")
        for pri in ("Critical", "Very High", "High", "Medium", "Low", "Unspecified"):
            names = by_priority.get(pri) or []
            if names:
                wt = {"Critical": 5, "Very High": 4, "High": 3, "Medium": 2, "Low": 1}.get(pri, 1)
                lines.append(f"- **{pri} ({wt} pts per ✔)**: {', '.join(names)}")
        lines.append("")
    if pack:
        from category_pack import get_markets

        lines.extend(
            [
                "| Market | Chart | Axis | Buyer meaning | Axis features (1 tick each) | Floor | Points per tick | Ranking spread (pts → 1.0 chart) |",
                "|---|---|---|---|---|---|---|---|",
            ]
        )
        for market in get_markets(pack):
            mid = str(market.get("id") or "")
            profile = _market_chart_profile(mid)
            display = str(market.get("display_name") or mid)
            bx, by = profile["mq_base"]
            wx, wy = profile["mq_feat_w"]
            dx, dy = profile["mq_score_div"]
            gbx, gby = profile["gmq_base"]
            gwx, gwy = profile["gmq_feat_w"]
            gdx, gdy = profile["gmq_score_div"]
            rows = (
                (
                    "3A Positioning",
                    "X",
                    "Process / offering depth",
                    profile["mq_x_feats"],
                    bx,
                    wx,
                    dx,
                ),
                (
                    "3A Positioning",
                    "Y",
                    "Execute / operations depth",
                    profile["mq_y_feats"],
                    by,
                    wy,
                    dy,
                ),
                (
                    "3B Magic Quadrant",
                    "X",
                    "Completeness of Vision",
                    profile["gmq_x_feats"],
                    gbx,
                    gwx,
                    gdx,
                ),
                (
                    "3B Magic Quadrant",
                    "Y",
                    "Ability to Execute",
                    profile["gmq_y_feats"],
                    gby,
                    gwy,
                    gdy,
                ),
            )
            for chart, axis, meaning, feats, floor, ppt, spread in rows:
                lines.append(
                    f"| {display} | {chart} | {axis} | {meaning} | "
                    f"{', '.join(feats)} | {floor} | {ppt} | {spread} |"
                )
        lines.append("")
        lines.append(
            "Worked identity: `axis = floor + (count of those axis ticks × points-per-tick) + "
            "(ranking_score ÷ spread)`, then clamp to [1.0, 9.5], then collision-slot unique "
            "X and unique Y at 0.1. No jitter term."
        )
        lines.append("")
    return lines


def _buying_guidance_lines(
    *,
    known: dict[str, str],
    audit: dict[str, Any] | None,
    support: dict[str, dict[str, bool]],
) -> list[str]:
    """Peer shortlists with equal standing — do not converge every profile on one vendor."""
    plugin_core = []
    apo_core = []
    saas_core = []
    if audit:
        markets = audit.get("markets") or {}
        plugin_core = list((markets.get("sdlc-plugins") or {}).get("core") or [])
        apo_core = list((markets.get("apo") or {}).get("core") or [])
        saas_core = list((markets.get("agentic-sdlc-saas") or {}).get("core") or [])

    def _names(slugs: list[str], limit: int = 6) -> str:
        labels = [known.get(s, s.replace("-", " ").title()) for s in slugs[:limit]]
        return ", ".join(labels) if labels else "the scored cores in that market"

    plugin_peers = [s for s in plugin_core if s != "silver-bullet"]
    if "zuvo" in plugin_core and "zuvo" not in plugin_peers[:12]:
        plugin_peers = ["zuvo"] + [s for s in plugin_peers if s != "zuvo"]
    apo_peers = [s for s in apo_core if s != "silver-bullet"]
    return [
        f"- **Lean startup / spec-first packs**: Shortlist OSS methodology packs on equal standing — "
        f"{_names(plugin_peers or ['gsd', 'bmad', 'superpowers', 'spec-kit', 'ruflo', 'zuvo'], limit=12)}. "
        "Include Zuvo as an sdlc-plugins **core** (public site → MIT GitHub). "
        "Pick on spec-driven vs persona vs swarm topology. Do not treat a single orchestrator as the default.",
        f"- **Process-first / fail-closed delivery**: Plugin MQ Leaders = "
        f"{known.get('silver-bullet', 'Silver Bullet')} **only** in this run because only that "
        "slug passed **both** hook-enforced gates and inclusion-ledger cross-session. That is a "
        "**feature-gate fact**, not a claim that the product is 'most complete'. This report "
        "does not call any vendor 'most complete'. Other APO cores remain peers below.",
        f"- **Open-source APO cores**: {_names(apo_peers or ['ai-dlc', 'agentsys', 'metagpt', 'director'], limit=8)} "
        "stand as peers. AI-DLC is AWS/awslabs methodology vocabulary without shipped hook gates "
        "in features.json — Visionaries on MQ, omitted from APO Wave; not IBM. Director is an APO "
        "seed with unverified identity and no shipped hook gates — not a plugin and not an aggregator.",
        f"- **Host-runtime path**: Use Cursor, Claude Code, or Codex with a separate pack "
        f"({_names((plugin_peers or ['gsd', 'bmad', 'spec-kit', 'zuvo'])[:5])}). "
        "The host is not the orchestrator; Factory/Devin are SaaS cores, not host-runtime add-ons.",
        f"- **Managed autonomous delivery**: Shortlist {_names(saas_core or ['factory-ai', 'devin', 'augment-cosmos'])}. "
        "This profile does not resolve to an OSS process pack. Magic.dev is hard-excluded "
        "(coding-model lab), not a SaaS-core substitute.",
        "- **Triangulation**: Use contributing-model consensus and the Consensus Resolution Table "
        "as a **reading aid**. Notable divergences are inter-model disagreements; the resolution "
        "table is the analyst call this report follows. Triangulation is not a scored axis.",
        "",
    ]


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
    # Scrub non-APO vendors (e.g. Conductor) mis-framed as APO in claim/consensus prose.
    claims = [scrub_membership_framing(c, pack) for c in claims]
    consolidation = {
        **consolidation,
        "consensus": [
            {**item, "text": scrub_membership_framing(str(item.get("text") or ""), pack)}
            for item in (consolidation.get("consensus") or [])
            if isinstance(item, dict)
        ],
        "divergence": select_notable_divergences(
            [
                {**item, "text": scrub_membership_framing(str(item.get("text") or ""), pack)}
                for item in (consolidation.get("divergence") or [])
                if isinstance(item, dict)
            ],
            envelopes=envelopes,
            limit=8,
        ),
    }
    commercial_catalog, oss_catalog, audit = _resolve_catalogs(need, envelopes)
    if pack and audit:
        from solution_classifier import write_catalog_audit

        write_catalog_audit(root, audit)
        patch_inclusion_ledger(root, pack=pack, audit=audit)

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

    lines: list[str] = [
        f"# {category} Market Landscape Report",
        "",
        "*Analyst-grade landscape analysis for SMB decision-makers*",
        "",
        f"Knowledge basis: Synthesised from multiple AI platform responses ({platform_list})",
        report_date,
        "",
    ]
    lines.extend(
        executive_summary_lines(chart=chart, pack=pack, known=known, audit=audit)
    )

    definition = (pack or {}).get("definition") or (
        f"{category} covers solutions operating one level above coding agents — "
        "orchestrating SDLC workflows, gates, and multi-agent delegation."
    )
    jtbd = (pack or {}).get("jobs_to_be_done") or [
        "Compose repeatable SDLC workflows above IDE/cloud coding agents.",
        "Delegate parent/child agent work with review and verification gates.",
        "Record skills and enforce hook-based lifecycle chains.",
        "Shorten time-to-value with templates and managed paths.",
        "Integrate git, CI, and planning artifacts for agentic delivery.",
    ]

    lines.extend(["## 1. Problem", ""])
    lines.append(
        "Coding agents execute work; they do not by themselves **enforce** an SDLC. "
        "Buyers need a process layer so planning, verification, review, and release cannot "
        "be skipped when agents run in parallel or across sessions."
    )
    lines.extend(["", "**Primary jobs-to-be-done**", ""])
    for i, job in enumerate(jtbd, 1):
        lines.append(f"{i}. {job}")
    lines.append("")

    lines.extend(["## 2. Market", ""])
    lines.extend(["### Market Definition & Scope", ""])
    lines.append(scope_text.strip() or definition)
    if pack:
        lines.extend([
            "",
            "**Out of scope (excluded from core peer set)**",
            "",
            "- Generic **coding agents** and IDE copilots (Cursor Background Agents, Cline, Aider, Continue, OpenHands, SWE-agent)",
            "- **Host runtimes** that execute code without a process catalog (Cursor, Copilot, Claude Code, Codex as hosts — listed under Adjacent). Devin is agentic-sdlc-saas core, not a host-runtime adjacent.",
            "- **Single-step** tools (PR review bots, PM integrations such as Linear)",
            "- **Generic agent frameworks** without SDLC process packaging (LangGraph, CrewAI as adjacent)",
            "- **Sunset** products (GitHub Copilot Workspace, AutoGen, AgentGPT, Devika)",
            "",
        ])
    lines.extend(["### Market Overview", ""])
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
        "### Key Industry Trends",
        "",
    ])
    for trend in TREND_SEEDS:
        lines.append(f"#### {trend['title']}")
        lines.append(f"- **What**: {trend['what']}")
        lines.append(f"- **SMB impact**: {trend['smb']}")
        lines.append(f"- **Vendor response**: {trend['vendor']}")
        lines.append("")

    lines.extend(["## 3. Framework", ""])
    lines.extend(["### Inclusion criteria", ""])
    if pack:
        lines.append(format_inclusion_criteria_prose(pack))
        lines.append("")
    else:
        lines.append(
            "Meaningful SMB adoption signals, active maintenance, production-oriented "
            "orchestration (not raw LLM APIs or single-shot copilots)."
        )
        lines.append("")
    lines.extend(_scoring_methodology_lines(comparison, pack))
    lines.extend(
        inclusion_ledger_embed_lines(root=root, audit=audit, pack=pack, known=known)
    )
    lines.extend(
        coverage_completeness_lines(
            root=root, audit=audit, comparison=comparison, pack=pack, known=known
        )
    )

    # Section 4 — findings: charts then vendors
    lines.extend(["## 4. Findings", ""])
    lines.extend(["### Competitive Positioning — Analyst Frameworks", ""])
    market_charts = (chart.get("markets") or {}) if isinstance(chart.get("markets"), dict) else {}
    if market_charts:
        for m_idx, (mid, mchart) in enumerate(market_charts.items(), start=1):
            role = mchart.get("market_role", "")
            display = mchart.get("market_display_name", mid)
            role_label = _MARKET_ROLE_LABELS.get(str(role), str(role)).title()
            lines.append(f"### 4.{m_idx} {role_label} market: {display}")
            lines.append("")
            for note in mchart.get("chart_notes") or []:
                lines.append(f"- {note}")
            if mchart.get("chart_notes"):
                lines.append("")
            lines.append(f"#### 4.{m_idx}.1 {display} — Positioning Matrix")
            lines.append("")
            lines.append(f"#### 4.{m_idx}.2 Magic Quadrant — {display}")
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
                f"#### 4.{m_idx}.3 Wave-Style Assessment — {display}",
                "",
                "| Vendor | Current Offering | Strategy | Market Presence |",
                "|--------|------------------|----------|-----------------|",
            ])
            for point in mchart.get("wave_data") or []:
                label = str(point.get("label") or "")
                offering = _wave_band(float(point.get("offering") or 0))
                strategy = _wave_band(float(point.get("strategy") or 0))
                presence_n = int(point.get("presence") or 1)
                presence = {4: "Strong", 3: "Good", 2: "Moderate", 1: "Emerging"}.get(
                    presence_n, "Emerging"
                )
                lines.append(f"| {label} | {offering} | {strategy} | {presence} |")
            vc_series = (mchart.get("vc_commercial") or []) + (mchart.get("vc_oss") or [])
            vc_labels = [s["label"] for s in vc_series]
            vc_kcfs = list(mchart.get("vc_kcfs") or KCF_NAMES)
            lines.extend([
                "",
                f"#### 4.{m_idx}.4 Blue Ocean Value Curve — {display}",
                "",
                "Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only. "
                "Factors appear only when at least one Leader has matrix/features.json evidence.",
                "",
            ])
            if vc_labels and vc_kcfs:
                lines.append("| Key Competitive Factor | " + " | ".join(vc_labels) + " |")
                lines.append("|" + "---|" * (1 + len(vc_labels)))
                for idx, kcf in enumerate(vc_kcfs):
                    row = [kcf]
                    for vc in vc_series:
                        data = vc.get("data") or []
                        row.append(str(data[idx]) if idx < len(data) else "1")
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
                data = vc.get("data") or []
                row.append(str(data[idx]) if idx < len(data) else "1")
            lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    # Vendor cards stay inside Findings (not new H2 chapters)
    market_sections: list[dict[str, Any]] = []
    if pack and get_markets(pack):
        market_sections, _next_unused = _market_solution_sections(pack, audit, start_num=5)
        for section in market_sections:
            kind_label = "Commercial" if section["kind"] == "commercial" else "Open Source"
            lines.extend([
                (
                    f"### {section['market_display']} — "
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
        lines.extend([f"### Top Commercial Solutions for SMBs ({len(commercial_catalog)} core)", ""])
        for entry in commercial_catalog:
            profile = _build_solution_profile(
                entry, commercial=True, root=root, claims=claims, support=support,
                known=known, overview_seeds=overview_seeds,
            )
            lines.extend(_render_solution_entry(profile, commercial=True))

        lines.extend([f"### Top Open Source Solutions ({len(oss_catalog)} core)", ""])
        for entry in oss_catalog:
            profile = _build_solution_profile(
                entry, commercial=False, root=root, claims=claims, support=support,
                known=known, overview_seeds=overview_seeds,
            )
            lines.extend(_render_solution_entry(profile, commercial=False))

    # Adjacent and Excluded stay in Findings
    if audit:
        lines.extend(["### Adjacent Markets (not core peers)", ""])
        lines.append(
            "Products below are relevant context but **not** scored as core peers on the market "
            "where they are adjacent. A vendor may be **core in one market and adjacent in another** "
            "(multi-market is allowed). Silver Bullet is core in APO ∩ sdlc-plugins — process "
            "catalog + hook gates (APO) and host-plugin packaging (plugins). Devin is "
            "agentic-sdlc-saas core, not a host-runtime adjacent. AgentHub is APO-adjacent CRM, "
            "not an APO Leader. Conductor is a SaaS-adjacent aggregator, not APO. Tembo is "
            "SaaS-adjacent and unplotted."
        )
        lines.append("")
        for slug in audit.get("adjacent") or []:
            name = known.get(slug, slug.replace("-", " ").title())
            reason = (audit.get("by_slug") or {}).get(slug, {}).get("reason", "adjacent class")
            lines.append(f"- **{name}** (`{slug}`) — {reason}")
        lines.append("")

        lines.extend(["### Explicitly Excluded", ""])
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
            core_slugs: set[str] = set()
            for block in (audit.get("markets") or {}).values():
                if isinstance(block, dict):
                    core_slugs.update(str(s) for s in (block.get("core") or []) if s)
            by_slug = audit.get("by_slug") or {}
            real_gaps: list[str] = []
            for slug in audit["gaps"]:
                meta = by_slug.get(str(slug)) if isinstance(by_slug, dict) else {}
                if not isinstance(meta, dict):
                    meta = {}
                canonical = str(meta.get("canonical_slug") or slug)
                if canonical in core_slugs or str(meta.get("classification") or "") == "core":
                    continue
                if canonical == "zuvo" or str(slug) in {"zuvo", "sdlc-plugin"}:
                    continue
                real_gaps.append(str(slug))
            if real_gaps:
                lines.extend(
                    [
                        "",
                        "**Coverage gaps (must-research seeds missing from envelopes)**",
                        "",
                    ]
                )
                for slug in real_gaps:
                    lines.append(f"- {known.get(slug, slug)} (`{slug}`)")
        lines.append("")

    # Consensus + resolution stay in Findings (envelope quotes only here)
    lines.extend(["### Consensus Patterns", ""])
    patterns = build_consensus_patterns(envelopes)
    if patterns:
        lines.append(
            "What contributing models **agreed on** across retrieve / triangulate / critique "
            "envelopes (at least three model families). This is not a dump of industry trends "
            "and not a buying recommendation."
        )
        lines.append("")
        for pat in patterns:
            fam = ", ".join(pat["families"])
            lines.append(f"#### {pat['title']}")
            lines.append(f"- **Agreement** ({len(pat['families'])} families: {fam}): {pat['text']}")
            lines.append("")
        lines.append(
            "Catalogs and git-native issue-to-PR loops appear in this report's trend list; "
            "they did **not** reach cross-family agreement in contributing-model claims, "
            "so they are not listed as consensus."
        )
        lines.append("")
    else:
        lines.append(
            "No cross-family consensus claims were extracted from contributing-model envelopes."
        )
        lines.append("")

    notable = consolidation.get("divergence") or []
    lines.extend(consensus_resolution_table_lines(notable if isinstance(notable, list) else []))

    # Buying guidance
    lines.extend(["## 5. Buying Guidance & Shortlist Profiles", ""])
    lines.extend(
        _buying_guidance_lines(known=known, audit=audit, support=support)
    )

    # Future outlook
    lines.extend(["## 6. Future Outlook & Emerging Disruptors", ""])
    outlook = [
        (
            "Router-first catalogs and hook gates",
            "Process routers with nested verify loops remain a differentiator for teams that need fail-closed delivery, not just prompt packs.",
            "Threatens executor-only agents.",
        ),
        (
            "Multi-model triangulation as a research method",
            "This report triangulates contributing models. Vendors were **not** scored on multi-model pools — triangulation is not a matrix row or MQ/Wave axis.",
            "Use it to read claims; do not treat it as a product feature tick.",
        ),
        (
            "Consolidation of git-native agents",
            "Issue-to-PR agents may merge with SDLC orchestration platforms.",
            "Threatens point tools without ecosystem depth.",
        ),
        (
            "Completeness claims are closed for this report",
            "The analyst decision is that this report does not call any vendor 'most complete'. Ranking scores are feature-tick totals. Plugin MQ Leaders = Silver Bullet only is a hooks + cross-session feature-gate, not a completeness ranking.",
            "Treat Leader plots as feature-gate outcomes; keep equal-standing shortlists by buying profile.",
        ),
    ]
    for title, what, smb in outlook:
        lines.append(f"### {title}")
        lines.append(f"- {what} **SMB implication**: {smb}")
        lines.append("")

    # Source reliability
    lines.extend(["## 7. Source Reliability Assessment", ""])
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
    protected: set[str] = set()
    if audit:
        for slug in list(audit.get("excluded") or []) + list(audit.get("sunset") or []):
            protected.add(known.get(str(slug), str(slug).replace("-", " ").title()))
        protected.add("Claude Code Expert")  # invented seed — never linkify substring
    markdown = _linkify_markdown_vendors(markdown, link_pairs, protected_labels=protected)
    # Final membership pass after linkify so SCR-sourced overviews and linked
    # Conductor mentions cannot keep APO mid-tier / leading framing — but keep
    # the Notable divergences block intact (inter-model quotes).
    markdown = apply_preserving_notable_divergences(
        markdown, lambda body: scrub_membership_framing(body, pack)
    )
    markdown = sanitize_compression_markers(markdown)
    assert_no_compression_markers(markdown, context="landscape-report.md synthesis")
    return markdown


def synthesize_landscape(
    research_dir: Path,
    *,
    force: bool = False,
    skip_charts: bool = False,
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
    known = _known_for_need(need)
    commercial_catalog, oss_catalog, _audit = _resolve_catalogs(need, envelopes)
    pack = resolve_pack_from_need(need)
    comparison = filter_comparison_for_pack(
        comparison,
        pack,
        need,
        matrix_slugs=set((_audit or {}).get("matrix_slugs") or []) or None,
    )
    comparison_path = research_dir / "comparison" / "comparison.json"
    if comparison_path.parent.is_dir():
        comparison_path.write_text(json.dumps(comparison, indent=2) + "\n", encoding="utf-8")
        matrix_md_path = comparison_path.parent / "comparison-matrix.md"
        matrix_md_path.write_text(_comparison_rankings_markdown(comparison), encoding="utf-8")
    support = _build_chart_support(comparison, root=research_dir)
    write_run_features_json(
        research_dir,
        comparison=comparison,
        support=support,
        known=known,
    )

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
    assert_no_compression_markers(markdown, context=str(md_path))
    md_path.write_text(markdown, encoding="utf-8")
    if skip_charts:
        return {
            "status": "ok",
            "markdown_path": str(md_path),
            "chart_data_path": str(chart_path),
            "markdown_bytes": md_path.stat().st_size,
            "chart_data_bytes": chart_path.stat().st_size if chart_path.is_file() else 0,
            "sections": len(SECTION_TITLES),
            "charts": "skipped",
        }

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
    parser.add_argument(
        "--skip-charts",
        action="store_true",
        help="Rewrite landscape-report.md only; leave chart-data.json untouched",
    )
    args = parser.parse_args()
    result = synthesize_landscape(Path(args.dir), force=args.force, skip_charts=args.skip_charts)
    print(json.dumps(result, indent=2))
    return 0 if result.get("status") in {"ok", "skipped"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
