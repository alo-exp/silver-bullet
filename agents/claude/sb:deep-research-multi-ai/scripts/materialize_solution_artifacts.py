#!/usr/bin/env python3
"""Materialize SCR + features.json from live DR-multi-AI contribution envelopes."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from category_pack import (
    build_known_solutions,
    build_overview_seeds,
    normalize_slug,
    resolve_pack_from_need,
)

FEATURE_TEMPLATE: list[dict[str, Any]] = [
    {
        "name": "Process orchestration",
        "features": [
            "Workflow composition",
            "Atomic flow catalog",
            "Parent/child agent delegation",
            "Hook-enforced gates",
        ],
    },
    {
        "name": "Developer Experience",
        "features": [
            "Self-serve signup",
            "Quick onboarding",
            "IDE-native integration",
            "Skill/plugin marketplace",
        ],
    },
    {
        "name": "Pricing and licensing",
        "features": [
            "Predictable pricing",
            "Free tier / OSS core",
            "Per-seat transparency",
        ],
    },
    {
        "name": "Time to value",
        "features": [
            "Managed hosting",
            "Prebuilt SDLC templates",
            "Zero-infra bootstrap",
        ],
    },
    {
        "name": "Verification and quality",
        "features": [
            "Automated review loops",
            "CI integration",
            "Visual/E2E verification",
        ],
    },
    {
        "name": "Security and compliance",
        "features": [
            "SSO",
            "RBAC",
            "Audit log",
        ],
    },
]

KNOWN_SOLUTIONS: dict[str, str] = {
    "silver-bullet": "Silver Bullet",
    "ai-dlc": "AI-DLC",
    "agentsys": "AgentSys",
    "zuvo": "Zuvo",
    "sdlc-plugin": "SDLC Plugin",
    "deepwork": "Deepwork",
    "workflow-manager": "Workflow Manager",
    "turboshovel": "Turboshovel",
    "cavekit": "Cavekit v3.1",
    "factory-ai": "Factory.ai",
    "devin": "Devin (Cognition)",
    "github-copilot-workspace": "GitHub Copilot Workspace",
    "cursor-agents": "Cursor Background Agents",
    "openhands": "OpenHands",
    "langgraph-platform": "LangGraph Platform",
    "sweep-ai": "Sweep",
    "crewai": "CrewAI",
    "tembo": "Tembo",
    "cline": "Cline",
    "spec-kit": "GitHub spec-kit",
    "bmad-method": "BMAD-METHOD",
    "aider": "Aider",
    "continue": "Continue",
    "autogen": "Microsoft AutoGen",
    "linear": "Linear",
    "linear-agent": "Linear Agent Integrations",
}

def _effective_known_solutions(need: dict[str, Any] | None = None) -> dict[str, str]:
    """Merge base KNOWN_SOLUTIONS with pack product_names when a pack is active."""
    pack = resolve_pack_from_need(need)
    if pack:
        merged = dict(KNOWN_SOLUTIONS)
        merged.update(build_known_solutions(pack))
        return merged
    return dict(KNOWN_SOLUTIONS)


def _effective_overview_seeds(need: dict[str, Any] | None = None) -> dict[str, str]:
    pack = resolve_pack_from_need(need)
    seeds = dict(OVERVIEW_SEEDS)
    if pack:
        seeds.update(build_overview_seeds(pack))
    return seeds


# Curated product blurbs for solution-card Overviews (not research-meta notes).
OVERVIEW_SEEDS: dict[str, str] = {
    "silver-bullet": "Silver Bullet is an open-source Agentic Process Orchestrator — a process layer inside Cursor, Codex, and Claude Code that composes workflows, enforces hook gates, and records skills.",
    "factory-ai": "Factory.ai provides managed Droids with workflow composition, parent/child delegation, review loops, and cloud hosting for agentic software delivery.",
    "devin": "Devin is Cognition's autonomous software engineer that plans, implements, tests, and ships code via pull requests in customer repositories.",
    "github-copilot-workspace": "GitHub Copilot Workspace is a Copilot-native environment for issue→spec→plan→implement→PR workflows on GitHub.",
    "cursor-agents": "Cursor Background Agents run long-lived coding agents in the cloud against your repos, with IDE-native handoff into Cursor.",
    "sweep-ai": "Sweep automates GitHub issue→PR coding workflows as an AI assistant on the git control plane.",
    "tembo": "Tembo runs cloud agents across repos, tickets, and tools with reviewable sessions and automations for startup engineering teams.",
    "replit-agent": "Replit Agent targets rapid idea-to-deploy prototyping with parallel agents and one-click hosting inside Replit.",
    "windsurf": "Windsurf (Codeium) is a multi-agent IDE that coordinates local and cloud coding agents from a single editor surface.",
    "tabnine-enterprise": "Tabnine Enterprise delivers privacy-focused AI coding assistance with enterprise controls for regulated engineering orgs.",
    "amazon-q-developer": "Amazon Q Developer is AWS's agentic coding assistant embedded in the AWS toolchain for build, ops, and migration tasks.",
    "sourcegraph-cody": "Sourcegraph Cody is a code-aware AI assistant grounded in large-codebase context search and chat inside the editor.",
    "augment-code": "Augment Code positions as agentic development at org scale with workflow packs for review, tests, incidents, and ticket-to-PR.",
    "magic-dev": "Magic.dev builds long-context coding models and agents aimed at large-repo autonomous engineering tasks.",
    "poolside": "Poolside sells open-weight agentic coding foundation models for on-prem and private deployments rather than a full process layer.",
    "coderabbit": "CodeRabbit is an AI code-review product focused on PR commentary and review automation rather than full SDLC orchestration.",
    "jetbrains-ai": "JetBrains AI Assistant brings AI coding and refactor help into IntelliJ-based IDEs with JetBrains ecosystem integration.",
    "github-copilot-enterprise": "GitHub Copilot Enterprise extends Copilot with org knowledge, preferential models, and enterprise admin controls on GitHub.",
    "cognition-scout": "Cognition Scout is Cognition's agent surface adjacent to Devin for scoped autonomous engineering tasks.",
    "linear-agent": "Linear Agent Integrations connect issue tracking in Linear to coding agents for ticket-driven implementation loops.",
    "openhands": "OpenHands is an OSS autonomous coding agent (CodeAct/sandbox) for BYO runtime execution with end-of-run verification.",
    "langgraph-platform": "LangGraph Platform hosts durable agent graphs with Cloud, Hybrid, and self-hosted control planes for custom orchestration.",
    "crewai": "CrewAI combines role-based agent Crews with event-driven Flows for production multi-agent workflows.",
    "metagpt": "MetaGPT maps a software-company SOP into role agents (PM/architect/engineer) that produce structured SDLC artifacts from a one-line brief.",
    "spec-kit": "GitHub spec-kit makes specifications executable via constitution.md principles and spec-driven development workflows.",
    "cline": "Cline is an open-source IDE agent that plans and edits in the editor with tool use and human-in-the-loop approval.",
    "continue": "Continue is an open-source AI coding extension for IDE chat, edit, and autocomplete workflows (acquired by Cursor in 2026).",
    "autogen": "Microsoft AutoGen is a multi-agent conversation framework for building custom agent graphs and tool-using collaborators.",
    "gsd": "GSD (Get Shit Done) is a Claude Code meta-prompting / spec-driven system for structured agent delivery loops.",
    "bmad-method": "BMAD-METHOD is an open methodology pack for agentic product and engineering workflows with role prompts and artifacts.",
    "aider": "Aider is a git-native CLI coding agent that edits repos in tight commit loops with strong OSS community adoption.",
    "swe-agent": "SWE-agent is an open research agent that solves GitHub issues end-to-end inside a controlled execution environment.",
    "semantic-kernel": "Semantic Kernel is Microsoft's SDK for orchestrating AI plugins, plans, and agents inside .NET/Python apps.",
    "gpt-engineer": "GPT-Engineer generates and iterates codebases from natural-language specs as a lightweight OSS coding agent.",
    "praisonai": "PraisonAI is a low-code multi-agent framework for composing crews of specialized AI workers.",
    "superagent": "Superagent is an open platform for building, hosting, and monitoring AI agents with tool integrations.",
    "agentgpt": "AgentGPT is a browser-based autonomous agent UI for goal-driven task decomposition and execution.",
    "langchain": "LangChain is a widely used framework for LLM apps and agents, with LangGraph for durable workflow orchestration.",
    "open-interpreter": "Open Interpreter lets language models run code locally for general computer-use style agent tasks.",
    "devika": "Devika is an open-source agentic software engineer that plans and implements coding tasks in a local stack.",
}

SLUG_ALIASES: dict[str, str] = {
    "sb": "silver-bullet",
    "silver bullet": "silver-bullet",
    "factory.ai": "factory-ai",
    "factory ai": "factory-ai",
    "factory": "factory-ai",
    "github copilot workspace": "github-copilot-workspace",
    "github copilot": "github-copilot-workspace",
    "copilot workspace": "github-copilot-workspace",
    "copilot": "github-copilot-workspace",
    "cursor cloud": "cursor-agents",
    "cursor background agents": "cursor-agents",
    "cursor agents": "cursor-agents",
    "cursor": "cursor-agents",
    "devin (cognition)": "devin",
    "cognition": "devin",
    "langgraph": "langgraph-platform",
    "langgraph platform": "langgraph-platform",
    "open hands": "openhands",
    "all-hands": "openhands",
    "sweep": "sweep-ai",
    "sweep.dev": "sweep-ai",
    "spec kit": "spec-kit",
    "github spec-kit": "spec-kit",
}

_MATRIX_DUMP_RE = re.compile(
    r"(?:"
    r"startup-weighted\s+matrix|"
    r"prior\s+startup-weighted\s+run\s+scored|"
    r"prior\s+startup-weighted\s+live\s+matrix\s+rankings|"
    r"matrix\s+rankings\s*:|"
    r"internal\s+comparative\s+evidence|"
    r"prior\s+dry[- ]run|"
    r"persona_id\s*=\s*startup|"
    r"\bmatrix\s*[—–-]\s*|"
    r"startup\s+shortlist\s+scores|"
    r"live\s+fullpool\s+solution\s+set|"
    r"fullpool\s+solution\s+set|"
    r"re-score\s*\(\s*minimum\s*\)|"
    r"market\s+segments?\s*(?:\(\s*startup-weighted\s*\))?|"
    r"market\s+subsegments?\s+useful\s+for\s+matrix|"
    r"on\s+critical\s+['\"]workflow\s+composition['\"]|"
    r"prior\s+live\s+shortlist|"
    r"(?:\b[a-z][\w-]*\s+\d{1,3}\s*;\s*){2,}[a-z][\w-]*\s+\d{1,3}|"
    r"(?:\b[a-z][\w-]*\s+\d{1,3}\s*,\s*){2,}[a-z][\w-]*\s+\d{1,3}"
    r")",
    re.IGNORECASE,
)

_META_OVERVIEW_RE = re.compile(
    r"(?:"
    r"participates in the (?:agentic|category)|"
    r"capability profile derived|"
    r"coverage is based on multi[- ]ai|"
    r"comparison matrix signals|"
    r"\btriangulat(?:e|ion|ed)\b|"
    r"consolidated narrative|"
    r"zero triangulate|"
    r"landscape omits|"
    r"missing coverage of|"
    r"absent from consolidated|"
    r"should anchor any comparison|"
    r"ideal for teams evaluating process layers|"
    r"live multi-ai dr envelopes|"
    r"multi-ai envelope synthesis|"
    r"retrieve sources still include|"
    r"risks scoring a legacy brand|"
    r"treat gsd as legacy|"
    r"no analysis of open-source alternatives|"
    r"top credible threats to sb|"
    r"the market has consolidated around|"
    r"true pr-only review tools"
    r")",
    re.IGNORECASE,
)


def is_matrix_dump_claim(text: str) -> bool:
    """Return True when claim text is a cross-vendor matrix/score dump, not solution prose."""
    t = (text or "").strip()
    if not t:
        return True
    if _MATRIX_DUMP_RE.search(t):
        return True
    lower = t.lower()
    if "maps to must_have" in lower or "maps to must-have" in lower:
        return True
    if re.search(r"✔\s+for\s+", t) and "," in t:
        return True
    if re.search(r"\bscored\b", lower) and re.search(r"\b\d{2,}\b", t) and t.count(",") >= 2:
        return True
    return False


def is_unusable_overview_claim(text: str, *, focus_name: str = "") -> bool:
    """Reject meta-research / multi-vendor dumps unsuitable as a solution Overview blurb."""
    t = (text or "").strip()
    if not t or is_matrix_dump_claim(t):
        return True
    if _META_OVERVIEW_RE.search(t):
        return True
    if len(t) > 420:
        return True
    focus = (focus_name or "").lower()
    lower = t.lower()
    # Card identity leaks: another product's install path or report methodology prose.
    if focus and "director" in focus and "superpowers" in lower:
        return True
    if focus and "cc10x" in focus and (
        "startup-weighted comparison" in lower
        or "silver bullet" in lower and "anchor" in lower
        or "methodology" in lower and "score" in lower
    ):
        return True
    # Claims that list many other products are landscape notes, not overviews.
    others = 0
    for display in KNOWN_SOLUTIONS.values():
        name = display.lower()
        if not name or (focus and (name == focus or name in focus or focus in name)):
            continue
        if name in lower:
            others += 1
            if others >= 3:
                return True
    return False


def _slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def _normalize_slug(token: str, known: dict[str, str] | None = None, pack: dict[str, Any] | None = None) -> str | None:
    token = token.strip().lower().strip("`\"'")
    if not token:
        return None
    effective = known or KNOWN_SOLUTIONS
    if token in effective:
        return token
    if token in SLUG_ALIASES:
        return SLUG_ALIASES[token]
    compact = re.sub(r"[^a-z0-9]+", " ", token).strip()
    if compact in SLUG_ALIASES:
        return SLUG_ALIASES[compact]
    if pack:
        resolved = normalize_slug(token, pack)
        if resolved:
            return resolved
    slug = _slugify(token)
    return slug if slug in effective else None


def _extract_slugs_from_text(
    text: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> list[str]:
    effective = known or KNOWN_SOLUTIONS
    found: list[str] = []
    lower = text.lower()
    for slug, display in effective.items():
        if slug.replace("-", " ") in lower or slug in lower or display.lower() in lower:
            found.append(slug)
    for alias, slug in SLUG_ALIASES.items():
        if alias in lower and slug not in found:
            found.append(slug)
    if pack:
        from category_pack import build_alias_map

        aliases = build_alias_map(pack)
        for alias, canonical in aliases.items():
            if len(alias) >= 2 and alias in lower and canonical not in found:
                found.append(canonical)
    return found


def discover_solutions(
    envelopes: list[dict[str, Any]],
    *,
    min_solutions: int = 2,
    need: dict[str, Any] | None = None,
) -> list[str]:
    pack = resolve_pack_from_need(need)
    if pack:
        from solution_classifier import classify_solutions

        audit = classify_solutions(envelopes, need, pack)
        matrix_slugs = list(audit.get("matrix_slugs") or audit.get("core") or [])
        if len(matrix_slugs) >= min_solutions:
            return matrix_slugs
        return matrix_slugs or list(pack.get("core_seeds") or [])[: max(min_solutions, 5)]

    known = _effective_known_solutions(need)
    scores: dict[str, int] = {}
    for text in _iter_claim_texts(envelopes):
        for slug in _extract_slugs_from_text(text, known, pack):
            scores[slug] = scores.get(slug, 0) + 1
    ranked = sorted(scores, key=lambda s: (-scores[s], s))
    if len(ranked) >= min_solutions:
        return ranked
    return sorted(known)[: max(min_solutions, 5)]


def _iter_claim_texts(envelopes: list[dict[str, Any]]) -> list[str]:
    texts: list[str] = []
    for env in envelopes:
        payload = env.get("payload") or {}
        for item in payload.get("evidence") or []:
            if isinstance(item, dict):
                claim = item.get("claim") or item.get("text") or ""
                if claim:
                    texts.append(str(claim))
        for item in payload.get("claim_candidates") or []:
            if isinstance(item, dict):
                text = item.get("text") or item.get("claim") or ""
                if text:
                    texts.append(str(text))
        for item in payload.get("critiques") or []:
            if isinstance(item, dict):
                finding = item.get("finding") or item.get("target") or ""
                if finding:
                    texts.append(str(finding))
        for item in payload.get("gaps") or []:
            if isinstance(item, dict):
                desc = item.get("description") or item.get("area") or ""
                if desc:
                    texts.append(str(desc))
    return texts

_MATRIX_ENTRY_RE = re.compile(
    r"Matrix entry\s*[—–\-]\s*(?P<feature>[^:]+?)(?:\s*\([^)]*\))?\s*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_MATRIX_ROW_RE = re.compile(
    r"(?:matrix|row|critical|very high)[^'\"]*['\"](?P<feature>[^'\"]+)['\"]"
    r"[^:]*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_MATRIX_DASH_RE = re.compile(
    r"Matrix\s*[—–\-]\s*(?P<feature>[^:]+?)(?:\s*\([^)]*\))?\s*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_CHECKMARK_FOR_RE = re.compile(
    r"(?P<feature>[^✔✓\n]{4,}?)\s*[✔✓]\s+for\s+(?P<body>.+)",
    re.IGNORECASE,
)
_SLUG_NEGATION_RE = re.compile(
    r"(?P<slug>[a-z][a-z0-9-]*)\s+(?:do(?:es)?\s+not|doesn't|fails?|lacks?)\b",
    re.IGNORECASE,
)
_CORE_SET_CLAIM_RE = re.compile(
    r"(?:"
    r"Confirmed in-scope core set|"
    r"Startup-weighted core|"
    r"startup-weighted(?:\s+\w+){0,4}\s+for matrix|"
    r"primary APO matrix should prioritize|"
    r"in-scope commercial \+ OSS solution count"
    r")",
    re.IGNORECASE,
)
_MATRIX_LEADERS_RE = re.compile(
    r"(?:matrix leaders are|APO matrix leaders|Commercial-weighted peer)",
    re.IGNORECASE,
)
_CRITERION_KEYWORD_TO_ID: dict[str, str] = {
    "lifecycle span": "lifecycle_span",
    "plugin/skill/hook packaging": "plugin_skill_hook_packaging",
    "deterministic gates": "deterministic_gates",
    "cross-session state": "cross_session_state",
    "cross session state": "cross_session_state",
    "specialist agents": "specialist_agents",
    "quality/release enforcement": "quality_release_enforcement",
    "quality release enforcement": "quality_release_enforcement",
    "process layer above": "process_layer_above_host",
}
_HEAD_SLUG_ALIASES: dict[str, str] = {
    "director mode lite": "director",
    "director mode": "director",
    "ai sdlc harness": "claude-harness",
    "claude harness": "claude-harness",
    "a(i)-team": "ateam",
    "a-team": "ateam",
    "ai-team": "ateam",
    "cavekit v3.1": "cavekit-v31",
    "cavekit": "cavekit-v31",
    "barkain workflow orchestrator": "barkain-workflow-orchestrator",
    "barkain": "barkain-workflow-orchestrator",
    "github spec kit": "spec-kit",
    "spec kit": "spec-kit",
    "bmad-method": "bmad",
    "bmad": "bmad",
    "gsd": "gsd",
    "superpowers": "superpowers",
    "zuvo": "zuvo",
    "factory.ai": "factory-ai",
    "factory ai": "factory-ai",
    "augment cosmos": "augment-cosmos",
    "silver bullet": "silver-bullet",
}

_FEATURE_ALIASES: dict[str, str] = {
    "multi-agent orchestration": "Parent/child agent delegation",
    "verification gates": "Hook-enforced gates",
    "verification/hook gates": "Hook-enforced gates",
    "hook-enforced sdlc gates": "Hook-enforced gates",
    "ide hook enforcement": "Hook-enforced gates",
    "hook-enforced process": "Hook-enforced gates",
    "headless ci execution": "CI integration",
    "partial composition": "Workflow composition",
    "multi-agent workflows": "Workflow composition",
    "workflow composition": "Workflow composition",
    "delegation": "Parent/child agent delegation",
    "parent/child delegation": "Parent/child agent delegation",
    "atomic-flow catalog": "Atomic flow catalog",
    "atomic flow catalog": "Atomic flow catalog",
    "atomic flows": "Atomic flow catalog",
    "workflow catalog": "Atomic flow catalog",
    "hook-enforced gates": "Hook-enforced gates",
    "hook gates": "Hook-enforced gates",
    "hook enforcement": "Hook-enforced gates",
    "automated review loops": "Automated review loops",
    "managed hosting": "Managed hosting",
    "ci integration": "CI integration",
    "ci/cd": "CI integration",
    "plugin marketplace": "Skill/plugin marketplace",
    "skill marketplace": "Skill/plugin marketplace",
    "ide-native": "IDE-native integration",
    "ide-native integration": "IDE-native integration",
    "open-source": "Free tier / OSS core",
    "oss core": "Free tier / OSS core",
    "sdlc templates": "Prebuilt SDLC templates",
    "prebuilt sdlc": "Prebuilt SDLC templates",
    "zero-infra": "Zero-infra bootstrap",
    "predictable pricing": "Predictable pricing",
    "audit logs": "Audit log",
    "visual/e2e": "Visual/E2E verification",
    "e2e verification": "Visual/E2E verification",
    "composing workflows": "Workflow composition",
    "composes workflows": "Workflow composition",
    "workflow state": "Workflow composition",
    "enforcing gates": "Hook-enforced gates",
    "cross-session state": "Workflow composition",
    "cross session state": "Workflow composition",
    "process layer above host": "Workflow composition",
    "process layer": "Workflow composition",
}

_INCLUSION_CRITERION_FEATURES: dict[str, list[str]] = {
    "lifecycle_span": ["Workflow composition", "Atomic flow catalog"],
    "plugin_skill_hook_packaging": ["Skill/plugin marketplace", "IDE-native integration"],
    "deterministic_gates": ["Hook-enforced gates"],
    "cross_session_state": ["Workflow composition"],
    "specialist_agents": ["Parent/child agent delegation"],
    "quality_release_enforcement": ["Automated review loops", "Hook-enforced gates"],
    "process_layer_above_host": ["Workflow composition", "IDE-native integration"],
}

_INCLUSION_CRITERIA_SIGNAL_RE = re.compile(
    r"inclusion criteria|inclusion criterion|lifecycle_span|deterministic gate|cross[- ]session|"
    r"plugin/skill|process layer|specialist agent|quality/release|passing all 7|satisfies all 7|"
    r"≥\s*3 inclusion|evidence host-integrated|orchestrat|workflow orchestrat|methodology pack",
    re.IGNORECASE,
)
_ALL_SEVEN_INCLUSION_RE = re.compile(
    r"(?:passing|satisf(?:y|ies)|covering|meets?)\s+all\s+7\s+inclusion",
    re.IGNORECASE,
)
_PAREN_CRITERION_SLUGS_RE = re.compile(
    r"(?P<phrase>deterministic gate|lifecycle span|cross[- ]host|plugin[- ]ecosystem|"
    r"gate determinism|workflow orchestrat|process[- ]layer)[^.;]{0,80}\((?P<list>[^)]+)\)",
    re.IGNORECASE,
)

_PROSE_POSITIVE_SIGNALS: list[tuple[re.Pattern[str], list[str]]] = [
    (re.compile(r"workflow|compos|router|lifecycle|orchestrat|repeatable workflow", re.I), ["Workflow composition"]),
    (re.compile(r"atomic flow|flow catalog|pre-composed|catalog of|workflow catalog", re.I), ["Atomic flow catalog"]),
    (re.compile(r"sequential or parallel|parallel execution|task decomposition", re.I), ["Workflow composition", "Parent/child agent delegation"]),
    (
        re.compile(
            r"hook|gate|blocking|fail.?closed|deterministic|quality gate|return block|enforcement|stop-hook",
            re.I,
        ),
        ["Hook-enforced gates"],
    ),
    (re.compile(r"open.?source|\boss\b", re.I), ["Free tier / OSS core"]),
    (re.compile(r"ci/?cd|ci integration|lint/test/build", re.I), ["CI integration"]),
    (re.compile(r"plugin|marketplace|skill pack", re.I), ["Skill/plugin marketplace"]),
    (
        re.compile(
            r"low startup burden|quick (?:setup|onboard)|two (?:marketplace )?commands|"
            r"marketplace installation|automatic setup|installs as a",
            re.I,
        ),
        ["Quick onboarding", "Zero-infra bootstrap"],
    ),
    (re.compile(r"verification|review loop|tdd", re.I), ["Automated review loops"]),
    (re.compile(r"process layer|above host|ide-native|claude code|codex|cursor", re.I), ["IDE-native integration"]),
    (re.compile(r"persist(?:s|ent)?\s+(?:evidence|state|progress)|cross[- ]session|state under", re.I), ["Workflow composition"]),
    (re.compile(r"specialist delegation|role[- ]based|multi[- ]agent", re.I), ["Parent/child agent delegation"]),
    (re.compile(r"schema validation|integrity[- ]gate|governance depth", re.I), ["Hook-enforced gates", "Automated review loops"]),
    (re.compile(r"host[- ]integrated|process orchestrator|sdlc plugin", re.I), ["Workflow composition", "IDE-native integration"]),
    (
        re.compile(
            r"(?:low|medium)[- ]startup burden|startup[- ]weighted|rapid (?:setup|onboard)|time[- ]to[- ]value",
            re.I,
        ),
        ["Quick onboarding", "Zero-infra bootstrap"],
    ),
    (re.compile(r"prebuilt|sdlc templates|template pack|methodology pack", re.I), ["Prebuilt SDLC templates"]),
    (re.compile(r"managed hosting|cloud agent|hosted runtime|autonomous delivery engine", re.I), ["Managed hosting"]),
]


def _all_template_features() -> list[str]:
    features: list[str] = []
    for category in FEATURE_TEMPLATE:
        features.extend(category["features"])
    return features


def _resolve_features(feature_text: str) -> list[str]:
    text = feature_text.strip()
    lower = text.lower()
    matched: list[str] = []
    for feature in _all_template_features():
        if feature.lower() in lower and feature not in matched:
            matched.append(feature)
    for alias, feature in _FEATURE_ALIASES.items():
        if alias in lower and feature not in matched:
            matched.append(feature)
    if matched:
        return matched
    for feature in _all_template_features():
        if feature.lower() == lower:
            return [feature]
    return [text]


def _matrix_entry_head_is_solution(
    head: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    """True when 'Matrix entry — {head}:' names a product, not a matrix feature row."""
    effective = known or KNOWN_SOLUTIONS
    head_clean = re.sub(r"\([^)]*\)", "", head).strip()
    if not head_clean:
        return False
    if re.search(r"[✔✓✖✗]", head_clean):
        return False
    lower = head_clean.lower()
    for feature in _all_template_features():
        if lower == feature.lower() or lower.startswith(feature.lower() + " "):
            return False
    for alias in _FEATURE_ALIASES:
        if lower == alias or lower.startswith(alias + " "):
            return False
    if _normalize_slug(head_clean, effective, pack):
        return True
    if _extract_slugs_from_text(head_clean, effective, pack):
        return True
    if _slugify(head_clean) and not re.search(r"\s", head_clean):
        return True
    return False


def _canonical_known_slug(
    slug: str,
    known: dict[str, str] | None = None,
) -> str:
    effective = known or KNOWN_SOLUTIONS
    if slug in effective:
        return slug
    for candidate in sorted(effective, key=len, reverse=True):
        if slug.startswith(f"{candidate}-") or candidate.startswith(f"{slug}-"):
            return candidate
    return slug


def _resolve_solution_slug(
    head: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> str | None:
    effective = known or KNOWN_SOLUTIONS
    head_clean = re.sub(r"\([^)]*\)", "", head).strip()
    head_key = head_clean.lower().strip()
    if head_key in _HEAD_SLUG_ALIASES:
        return _canonical_known_slug(_HEAD_SLUG_ALIASES[head_key], effective)
    for alias, slug in sorted(_HEAD_SLUG_ALIASES.items(), key=lambda item: len(item[0]), reverse=True):
        if head_key == alias or head_key.startswith(f"{alias} "):
            return _canonical_known_slug(slug, effective)
    lower = head_clean.lower()
    for slug, display in sorted(effective.items(), key=lambda item: len(item[1]), reverse=True):
        disp = display.lower()
        if lower == disp or lower.startswith(f"{disp} ") or disp.startswith(lower):
            return _canonical_known_slug(slug, effective)
    slug = _normalize_slug(head_clean, effective, pack)
    if slug:
        return _canonical_known_slug(slug, effective)
    slugs = _extract_slugs_from_text(head_clean, effective, pack)
    if slugs:
        return _canonical_known_slug(slugs[0], effective)
    compact = _slugify(head_clean)
    if compact and not re.search(r"\s", head_clean):
        return _canonical_known_slug(compact, effective)
    return None


def _infer_features_from_solution_prose(
    support: dict[str, dict[str, bool | None]],
    slug: str,
    body: str,
) -> None:
    if re.search(r"lifecycle_span\s*=", body, re.IGNORECASE):
        for criterion, features in _INCLUSION_CRITERION_FEATURES.items():
            match = re.search(
                rf"{criterion}\s*=\s*(?P<val>yes|no|partial|true|false)",
                body,
                re.IGNORECASE,
            )
            if not match:
                continue
            val = match.group("val").lower()
            positive = val in {"yes", "true"}
            partial = val == "partial"
            for feature in features:
                if positive:
                    _assign_support(support, slug, feature, True)
                elif not partial:
                    _assign_support(support, slug, feature, False)
        return

    for pattern, features in _PROSE_POSITIVE_SIGNALS:
        if pattern.search(body):
            for feature in features:
                _assign_support(support, slug, feature, True)

    for feature in _features_in_text(body):
        _assign_support(support, slug, feature, True)


def _parse_solution_led_matrix_entry(
    support: dict[str, dict[str, bool | None]],
    head: str,
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _matrix_entry_head_is_solution(head, known, pack):
        return False
    slug = _resolve_solution_slug(head, known, pack)
    if not slug:
        return False
    _infer_features_from_solution_prose(support, slug, body)
    return True


def _assign_support(
    support: dict[str, dict[str, bool | None]],
    slug: str,
    feature: str,
    value: bool,
) -> None:
    current = support.setdefault(slug, {}).get(feature)
    if value:
        support[slug][feature] = True
    elif current is not True:
        support[slug][feature] = False


def _extract_slugs_from_list(
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> list[str]:
    effective = known or KNOWN_SOLUTIONS
    found: list[str] = []
    cleaned = re.sub(r"\([^)]*\)", " ", text)
    cleaned = re.sub(
        r"\b(?:only|among|evaluated|set|peers|weaker|etc\.?|commercial peers)\b.*$",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    for token in re.split(r"[,;/]", cleaned):
        token = re.sub(
            r"\b(pass|fail|scores?|✔|✓|✖|✗|true|yes|no|not|and|partially)\b",
            "",
            token,
            flags=re.IGNORECASE,
        ).strip()
        if not token:
            continue
        token_key = token.lower()
        if token_key in _HEAD_SLUG_ALIASES:
            slug = _HEAD_SLUG_ALIASES[token_key]
        else:
            slug = _normalize_slug(token, effective, pack)
        if slug and slug not in found:
            found.append(_canonical_known_slug(slug, effective))
    for slug in _extract_slugs_from_text(cleaned, effective, pack):
        canonical = _canonical_known_slug(slug, effective)
        if canonical not in found:
            found.append(canonical)
    return found


def _parse_checkmark_body(
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> tuple[list[str], list[str]]:
    positive: list[str] = []
    negative: list[str] = []
    for section in re.split(r"\s*;\s*", body.strip()):
        section = section.strip()
        if not section:
            continue
        neg_match = re.match(r"[✖✗]\s*(.+)", section)
        if neg_match:
            negative.extend(_extract_slugs_from_list(neg_match.group(1), known=known, pack=pack))
            continue
        pos_match = re.match(r"[✔✓]\s*(.+)", section)
        if pos_match:
            pos_body = pos_match.group(1)
            only_match = re.search(r"^(.+?)\s+only\b", pos_body, re.IGNORECASE)
            chunk = only_match.group(1) if only_match else pos_body
            positive.extend(_extract_slugs_from_list(chunk, known=known, pack=pack))
            continue
        if re.search(r"[✖✗]", section):
            negative.extend(_extract_slugs_from_list(section, known=known, pack=pack))
        elif re.search(r"[✔✓]", section):
            positive.extend(_extract_slugs_from_list(section, known=known, pack=pack))
    return positive, negative


def _split_solution_lists(
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> tuple[list[str], list[str]]:
    effective = known or KNOWN_SOLUTIONS
    positive: list[str] = []
    negative: list[str] = []
    if re.search(r"[✔✓✖✗]", body):
        return _parse_checkmark_body(body, known=effective, pack=pack)

    parts = re.split(
        r"\b(?:but|while|whereas|;\s*(?=[a-z][a-z0-9-]*\s+do(?:es)?\s+not))\b",
        body,
        flags=re.IGNORECASE,
    )
    pos_text = parts[0]
    neg_text = parts[1] if len(parts) > 1 else ""

    for token in re.split(r"[,;]", pos_text):
        token = re.sub(r"\b(pass|fail|scores?|✔|✓|true|yes)\b", "", token, flags=re.IGNORECASE)
        slug = _normalize_slug(token, effective, pack)
        if slug:
            positive.append(_canonical_known_slug(slug, effective))

    for match in _SLUG_NEGATION_RE.finditer(neg_text or body):
        slug = _normalize_slug(match.group("slug"), effective, pack)
        if slug:
            negative.append(_canonical_known_slug(slug, effective))
    for token in re.split(r"[,;]", neg_text):
        if not re.search(r"\bdo(?:es)?\s+not\b", token, re.IGNORECASE):
            continue
        slug = _normalize_slug(
            re.sub(r"\bdo(?:es)?\s+not\b.*", "", token, flags=re.IGNORECASE),
            effective,
            pack,
        )
        if slug:
            negative.append(_canonical_known_slug(slug, effective))
    return positive, negative


def _apply_matrix_row(
    support: dict[str, dict[str, bool | None]],
    feature_text: str,
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    features = _resolve_features(feature_text)
    positive, negative = _split_solution_lists(body, known=known, pack=pack)
    for feature in features:
        for slug in positive:
            _assign_support(support, slug, feature, True)
        for slug in negative:
            _assign_support(support, slug, feature, False)


def _features_in_text(text: str) -> list[str]:
    lower = text.lower()
    matched: list[str] = []
    for feature in _all_template_features():
        if feature.lower() in lower and feature not in matched:
            matched.append(feature)
    for alias, feature in _FEATURE_ALIASES.items():
        if alias in lower and feature not in matched:
            matched.append(feature)
    return matched


def _primary_slug_in_text(text: str) -> str | None:
    lower = text.lower()
    if re.search(r"\bsb\b", lower[:80]):
        return "silver-bullet"
    slugs = _extract_slugs_from_text(text)
    return slugs[0] if slugs else None


def _parse_comparative_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    lower = text.lower()
    for slug in _extract_slugs_from_text(text):
        slug_pat = re.escape(slug.replace("-", "[ -]"))
        for match in re.finditer(rf"\b{slug_pat}\b\s+lacks?\s+([^.;]+)", lower):
            for feature in _features_in_text(match.group(1)):
                _assign_support(support, slug, feature, False)

    offer_match = re.search(
        r"\bwhile\s+(.+?)\s+offer(?:s)?\s+(.+?)(?:\.|;|$)",
        text,
        re.IGNORECASE,
    )
    if offer_match:
        for slug in _extract_slugs_from_text(offer_match.group(1)):
            for feature in _features_in_text(offer_match.group(2)):
                _assign_support(support, slug, feature, True)


def _parse_prose_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    slug = _primary_slug_in_text(text)
    if not slug:
        return

    check_match = re.search(
        r"[✔✓].*?(?:rows?|features?):\s*(.+?)(?:\.|$)",
        text,
        re.IGNORECASE,
    )
    if check_match:
        for feature in _features_in_text(check_match.group(1)):
            _assign_support(support, slug, feature, True)

    parts = re.split(
        r"\b(?:,\s*)?but\s+(?:lacks?|no|does not|without|not|scores? poorly|trail)\b",
        text,
        maxsplit=1,
        flags=re.IGNORECASE,
    )
    pos = parts[0]
    neg = parts[1] if len(parts) > 1 else ""

    if re.search(
        r"\b(offers?|provides?|supports?|includes?|covers?)\b",
        pos,
        re.IGNORECASE,
    ):
        for feature in _features_in_text(pos):
            _assign_support(support, slug, feature, True)

    for feature in _features_in_text(neg):
        _assign_support(support, slug, feature, False)

    if neg and re.search(r"(?:\blacks?\b|blanks? on|trail on|✗|✖)", neg, re.IGNORECASE):
        for feature in _features_in_text(neg):
            _assign_support(support, slug, feature, False)


def _parse_checkmark_for_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    match = _CHECKMARK_FOR_RE.search(text)
    if not match:
        return False
    _apply_matrix_row(
        support,
        match.group("feature"),
        match.group("body"),
        known=known,
        pack=pack,
    )
    return True


def _parse_matrix_dash_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    match = _MATRIX_DASH_RE.search(text)
    if not match:
        return False
    _apply_matrix_row(
        support,
        match.group("feature"),
        match.group("body"),
        known=known,
        pack=pack,
    )
    return True


def _parse_must_have_satisfaction(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"satisfying all three matrix must-haves", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if not slug:
        return
    for feature in (
        "Workflow composition",
        "Parent/child agent delegation",
        "Hook-enforced gates",
    ):
        _assign_support(support, slug, feature, True)
    if re.search(r"\bci\b|ci execution|ci integration", text, re.IGNORECASE):
        _assign_support(support, slug, "CI integration", True)


def _parse_has_checkmark_features(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    for match in re.finditer(
        r"has\s+[✔✓]\s*([^.;]+)|[✔✓]\s*((?:Atomic|Workflow|Hook)[^.;]{0,60})",
        text,
        re.IGNORECASE,
    ):
        fragment = match.group(1) or match.group(2) or ""
        slug = _primary_slug_in_text(text[: match.start() + 40])
        if not slug:
            slug = _primary_slug_in_text(text)
        if not slug:
            continue
        for feature in _features_in_text(fragment):
            _assign_support(support, slug, feature, True)

    for match in re.finditer(
        r"([a-z][a-z0-9-]*)\s+also\s+[✔✓]\s*(?:\(([^)]+)\))?",
        text,
        re.IGNORECASE,
    ):
        slug = _normalize_slug(match.group(1))
        if not slug:
            continue
        hint = match.group(2) or text[match.end() : match.end() + 80]
        for feature in _features_in_text(hint):
            _assign_support(support, slug, feature, True)


def _parse_solution_lead_negative(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    lower = text.lower()
    for slug, display in KNOWN_SOLUTIONS.items():
        patterns = (
            rf"^{re.escape(display.lower())}\b",
            rf"^{re.escape(slug.replace('-', ' '))}\b",
            rf"^{re.escape(slug)}\b",
        )
        if not any(re.search(pat, lower) for pat in patterns):
            continue
        if re.search(
            r"\bno\s+(?:workflow\s+)?catalog\b|\bwithout\b.{0,40}\bcatalog\b",
            lower,
        ):
            _assign_support(support, slug, "Atomic flow catalog", False)
            _assign_support(support, slug, "Workflow composition", False)
        if re.search(r"hook[- ]enforced|hook enforcement|ide hook", lower):
            if re.search(r"\bno\b|\blacks?\b|\bwithout\b", lower):
                _assign_support(support, slug, "Hook-enforced gates", False)
        if re.search(r"\bpartial composition\b", lower):
            _assign_support(support, slug, "Workflow composition", True)
        if re.search(r"\bno catalog or\b", lower):
            _assign_support(support, slug, "Atomic flow catalog", False)
        if re.search(r"\bopen[- ]source\b|\boss\b", lower):
            _assign_support(support, slug, "Free tier / OSS core", True)
        if re.search(r"\bverification[- ]gate\b|\bverification gate\b", lower):
            if re.search(r"\bno\b|\blacks?\b|\blimited\b|\bwithout\b", lower):
                _assign_support(support, slug, "Hook-enforced gates", False)
        if re.search(r"\blimited multi-agent\b", lower):
            _assign_support(support, slug, "Parent/child agent delegation", False)
        if re.search(r"\bci/?cd\b|\bci integration\b", lower):
            _assign_support(support, slug, "CI integration", True)
        if re.search(r"multi-agent workflows?\b", lower) and not re.search(
            r"\bno\b.{0,20}multi-agent",
            lower,
        ):
            _assign_support(support, slug, "Parent/child agent delegation", True)
        break


def _parse_managed_hosting_offer(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"offer managed hosting", text, re.IGNORECASE):
        return
    exclude: set[str] = set()
    if re.search(r"\bSB\b|silver[- ]bullet", text, re.IGNORECASE) and re.search(
        r"\bwhile\b",
        text,
        re.IGNORECASE,
    ):
        exclude.add("silver-bullet")
    for slug in _extract_slugs_from_text(text):
        if slug in exclude:
            continue
        _assign_support(support, slug, "Managed hosting", True)
        if re.search(r"managed hosting paths?", text, re.IGNORECASE):
            _assign_support(support, slug, "Zero-infra bootstrap", True)


def _parse_startup_must_have_badge(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"all three startup must_haves", text, re.IGNORECASE):
        return
    if not re.search(r"\bSB\b|silver[- ]bullet", text, re.IGNORECASE):
        return
    for feature in (
        "Workflow composition",
        "Parent/child agent delegation",
        "Hook-enforced gates",
    ):
        _assign_support(support, "silver-bullet", feature, True)


def _parse_template_ttv(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"time-to-value through templates|managed triggers", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if slug:
        _assign_support(support, slug, "Prebuilt SDLC templates", True)


def _parse_autonomous_ship_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"plans?, writes?, tests?, and ships", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if not slug:
        return
    _assign_support(support, slug, "Managed hosting", True)
    _assign_support(support, slug, "CI integration", True)
    _assign_support(support, slug, "Zero-infra bootstrap", True)


def _parse_strong_composition_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"strong git-native composition|strong BYO composition", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if slug:
        _assign_support(support, slug, "Workflow composition", True)


def _parse_openhands_templates(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"automation templates", text, re.IGNORECASE):
        return
    if "openhands" in text.lower():
        _assign_support(support, "openhands", "Prebuilt SDLC templates", True)


def _parse_inclusion_criteria_scoped_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    if not _INCLUSION_CRITERIA_SIGNAL_RE.search(text):
        return
    effective = known or KNOWN_SOLUTIONS
    if _ALL_SEVEN_INCLUSION_RE.search(text):
        for slug in _extract_slugs_from_text(text, effective, pack):
            for feature in _default_inclusion_features():
                _assign_support(support, slug, feature, True)
        return
    for match in _PAREN_CRITERION_SLUGS_RE.finditer(text):
        slugs = _extract_slugs_from_list(match.group("list"), known=effective, pack=pack)
        if not slugs:
            continue
        features = _features_for_inclusion_mentions(match.group("phrase")) or _features_in_text(
            match.group("phrase")
        )
        for slug in slugs:
            for feature in features:
                _assign_support(support, slug, feature, True)
    for slug in _extract_slugs_from_text(text, effective, pack):
        _infer_features_from_solution_prose(support, slug, text)


def _apply_slug_scoped_prose(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    _parse_comparative_claims(support, text)
    _parse_prose_claim(support, text)
    _parse_must_have_satisfaction(support, text)
    _parse_has_checkmark_features(support, text)
    _parse_solution_lead_negative(support, text)
    _parse_managed_hosting_offer(support, text)
    _parse_startup_must_have_badge(support, text)
    _parse_template_ttv(support, text)
    _parse_autonomous_ship_claim(support, text)
    _parse_strong_composition_claim(support, text)
    _parse_openhands_templates(support, text)
    _parse_inclusion_criteria_scoped_claim(support, text, known=known, pack=pack)
    lower = text.lower()
    for slug in _extract_slugs_from_text(text):
        slug_pat = re.escape(slug.replace("-", "[ -]"))
        slug_region = re.search(rf"\b{slug_pat}\b", lower)
        if not slug_region:
            continue
        start = slug_region.end()
        end = min(len(lower), slug_region.end() + 160)
        window = lower[start:end]
        slug_pat_text = slug.replace("-", " ")
        for feature in _features_in_text(window):
            lack = re.search(
                rf"(?P<subj>[^.;:,]+?)\s+(?:lacks?|without|fails?)\s+[^.;]*{re.escape(feature.lower())}",
                window,
            )
            if lack:
                subj = lack.group("subj").strip()
                if slug in subj or slug_pat_text in subj:
                    _assign_support(support, slug, feature, False)
                continue
            if re.search(
                r"(?:\bsupports?\b|\bprovides?\b|\boffers?\b|\bpass\b|✔|✓|\byes\b|\bstrong\b|\bincludes?\b|\bcovers?\b|\bsatisfying\b|\bcompos)",
                window,
            ):
                _assign_support(support, slug, feature, True)


def _features_for_inclusion_mentions(text: str) -> list[str]:
    lower = text.lower()
    features: list[str] = []
    for keyword, criterion_id in _CRITERION_KEYWORD_TO_ID.items():
        if keyword not in lower:
            continue
        for feature in _INCLUSION_CRITERION_FEATURES[criterion_id]:
            if feature not in features:
                features.append(feature)
    return features


def _default_inclusion_features() -> list[str]:
    features: list[str] = []
    for criterion_features in _INCLUSION_CRITERION_FEATURES.values():
        for feature in criterion_features:
            if feature not in features:
                features.append(feature)
    return features


def _extract_bulk_solution_list(text: str) -> str | None:
    list_part: str | None = None
    for pattern in (
        r"for matrix:\s*(.+)$",
        r"should prioritize\s+(.+)$",
        r"core set[^:]*:\s*(.+)$",
        r"matrix leaders are\s+(.+)$",
        r"Commercial-weighted peer:\s*(.+)$",
    ):
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            list_part = match.group(1)
            break
    if list_part is None and re.search(r"\bare\b", text, re.IGNORECASE):
        list_part = re.split(r"\bare\b", text, maxsplit=1, flags=re.IGNORECASE)[1]
    if not list_part:
        return None
    list_part = re.split(
        r"\s*(?:—|–|-)\s*(?:comfortably|once|then|filter|Commercial|Generic|with host|excluded)",
        list_part,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    list_part = re.split(
        r"\s*;\s*(?:Generic|Commercial|then\b)",
        list_part,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    return list_part.strip(" .")


def _parse_core_set_bulk_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _CORE_SET_CLAIM_RE.search(text):
        return False
    list_part = _extract_bulk_solution_list(text)
    if not list_part:
        return False
    slugs = _extract_slugs_from_list(list_part, known=known, pack=pack)
    if not slugs:
        return False
    features = _features_for_inclusion_mentions(text)
    if not features:
        features = _default_inclusion_features()
    if re.search(r"startup[- ]weighted", text, re.IGNORECASE):
        for feature in ("Quick onboarding", "Zero-infra bootstrap"):
            if feature not in features:
                features.append(feature)
    for slug in slugs:
        for feature in features:
            _assign_support(support, slug, feature, True)
    return True


def _parse_matrix_leaders_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _MATRIX_LEADERS_RE.search(text):
        return False
    list_part = _extract_bulk_solution_list(text)
    if not list_part:
        return False
    slugs = _extract_slugs_from_list(list_part, known=known, pack=pack)
    if not slugs:
        return False
    features = _features_for_inclusion_mentions(text) or [
        "Workflow composition",
        "IDE-native integration",
        "Parent/child agent delegation",
    ]
    for slug in slugs:
        for feature in features:
            _assign_support(support, slug, feature, True)
        _infer_features_from_solution_prose(support, slug, text)
    return True


def _parse_host_runtime_substrate_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not re.search(r"host runtime|substrate row|exclusion class host_runtime", text, re.IGNORECASE):
        return False
    effective = known or KNOWN_SOLUTIONS
    host_slugs = {
        slug
        for slug in _extract_slugs_from_text(text, effective, pack)
        if slug in {"cursor", "claude-code", "codex", "github-copilot"}
    }
    if not host_slugs:
        return False
    for slug in host_slugs:
        _assign_support(support, slug, "IDE-native integration", True)
    return True


def parse_feature_support(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> dict[str, dict[str, bool | None]]:
    effective = known or KNOWN_SOLUTIONS
    support: dict[str, dict[str, bool | None]] = {}
    for text in _iter_claim_texts(envelopes):
        if _parse_core_set_bulk_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_matrix_leaders_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_host_runtime_substrate_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_matrix_dash_claims(support, text, known=effective, pack=pack):
            continue
        if _parse_checkmark_for_claims(support, text, known=effective, pack=pack):
            continue

        entry_match = _MATRIX_ENTRY_RE.search(text)
        if entry_match:
            head = entry_match.group("feature").strip()
            body = entry_match.group("body").strip()
            if _parse_solution_led_matrix_entry(support, head, body, known=effective, pack=pack):
                continue
            _apply_matrix_row(support, head, body, known=effective, pack=pack)
            continue

        match = _MATRIX_ROW_RE.search(text)
        if match:
            _apply_matrix_row(
                support,
                match.group("feature"),
                match.group("body"),
                known=effective,
                pack=pack,
            )
            continue

        if "matrix entry" in text.lower():
            continue
        _apply_slug_scoped_prose(support, text, known=effective, pack=pack)
    return support


def _group_features_into_categories(feature_names: list[str]) -> list[dict[str, Any]]:
    template_index: dict[str, str] = {}
    for cat in FEATURE_TEMPLATE:
        for feat in cat["features"]:
            template_index[str(feat)] = str(cat["name"])
    grouped: dict[str, list[str]] = {}
    order: list[str] = []
    for name in feature_names:
        cat = template_index.get(name) or "Run-synthesized"
        if cat not in grouped:
            grouped[cat] = []
            order.append(cat)
        if name not in grouped[cat]:
            grouped[cat].append(name)
    return [{"name": cat, "features": grouped[cat]} for cat in order]


def synthesize_feature_rubric(
    *,
    comparison: dict[str, Any] | None = None,
    support: dict[str, dict[str, bool | None]] | None = None,
) -> dict[str, Any]:
    """Build the run-level rubric from comparison rows or discovered support.

    Do not stamp the canned FEATURE_TEMPLATE when the run already produced a rubric.
    """
    grouped: dict[str, list[str]] = {}
    cat_order: list[str] = []
    current_cat = "Capabilities"
    if comparison:
        for row in comparison.get("rows") or []:
            if not isinstance(row, dict):
                continue
            if row.get("type") == "category":
                current_cat = str(row.get("name") or "Capabilities")
                continue
            if row.get("type") != "feature":
                continue
            name = str(row.get("name") or "").strip()
            if not name:
                continue
            if current_cat not in grouped:
                grouped[current_cat] = []
                cat_order.append(current_cat)
            if name not in grouped[current_cat]:
                grouped[current_cat].append(name)
        if cat_order:
            return {
                "source": "comparison.json",
                "categories": [{"name": cat, "features": grouped[cat]} for cat in cat_order],
            }

    names: list[str] = []
    seen: set[str] = set()
    for feats in (support or {}).values():
        if not isinstance(feats, dict):
            continue
        for name in feats:
            label = str(name).strip()
            if label and label not in seen:
                seen.add(label)
                names.append(label)
    if names:
        return {"source": "live-envelopes", "categories": _group_features_into_categories(names)}

    return {
        "source": "fallback-template",
        "categories": [
            {"name": str(cat["name"]), "features": list(cat["features"])}
            for cat in FEATURE_TEMPLATE
        ],
    }


def build_features_json(
    slug: str,
    support: dict[str, dict[str, bool | None]],
    *,
    known: dict[str, str] | None = None,
    comparison: dict[str, Any] | None = None,
    rubric: dict[str, Any] | None = None,
) -> dict[str, Any]:
    effective = known or KNOWN_SOLUTIONS
    per_solution = support.get(slug, {})
    spec = rubric or synthesize_feature_rubric(comparison=comparison, support=support)
    categories: list[dict[str, Any]] = []
    for category in spec.get("categories") or []:
        features: list[dict[str, Any]] = []
        for feature in category.get("features") or []:
            name = feature if isinstance(feature, str) else str(feature.get("name") or "")
            if not name:
                continue
            features.append({"name": name, "supported": per_solution.get(name)})
        if features:
            categories.append(
                {"name": str(category.get("name") or "Capabilities"), "features": features}
            )
    return {
        "solution_name": slug,
        "display_name": effective.get(slug, slug),
        "categories": categories,
        "source": spec.get("source") or "live-envelopes",
        "rubric_source": spec.get("source") or "live-envelopes",
    }


def write_run_features_json(
    research_dir: Path,
    *,
    comparison: dict[str, Any] | None = None,
    support: dict[str, dict[str, bool | None]] | None = None,
    known: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Write landscape/features-rubric.json and per-solution features.json from the run rubric."""
    research_dir = Path(research_dir)
    comparison = comparison if isinstance(comparison, dict) else {}
    if not comparison:
        cmp_path = research_dir / "comparison" / "comparison.json"
        if cmp_path.is_file():
            try:
                loaded = json.loads(cmp_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                loaded = {}
            if isinstance(loaded, dict):
                comparison = loaded
    rubric = synthesize_feature_rubric(comparison=comparison, support=support)
    landscape_dir = research_dir / "landscape"
    landscape_dir.mkdir(parents=True, exist_ok=True)
    (landscape_dir / "features-rubric.json").write_text(
        json.dumps(rubric, indent=2) + "\n",
        encoding="utf-8",
    )
    effective = known or KNOWN_SOLUTIONS
    slugs: list[str] = []
    for item in comparison.get("rankings") or []:
        if isinstance(item, dict) and item.get("solution"):
            slugs.append(str(item["solution"]))
    solutions_root = research_dir / "solutions"
    if solutions_root.is_dir():
        for sol_dir in sorted(solutions_root.iterdir()):
            if sol_dir.is_dir() and sol_dir.name not in slugs:
                slugs.append(sol_dir.name)
    written: list[str] = []
    for slug in slugs:
        sol_dir = solutions_root / slug
        sol_dir.mkdir(parents=True, exist_ok=True)
        payload = build_features_json(slug, support or {}, known=effective, rubric=rubric)
        path = sol_dir / "features.json"
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        written.append(str(path.relative_to(research_dir)))
    return {
        "status": "ok",
        "rubric_source": rubric.get("source"),
        "features_written": written,
        "rubric_path": "landscape/features-rubric.json",
    }


def _scr_claims_for_slug(slug: str, envelopes: list[dict[str, Any]]) -> list[str]:
    display = KNOWN_SOLUTIONS.get(slug, slug)
    slug_pat = slug.replace("-", " ")
    claims: list[str] = []
    for text in _iter_claim_texts(envelopes):
        lower = text.lower()
        if slug not in lower and slug_pat not in lower and display.lower() not in lower:
            continue
        if is_unusable_overview_claim(text, focus_name=display):
            continue
        claims.append(text)
        if len(claims) >= 12:
            break
    return claims


def build_scr_md(slug: str, envelopes: list[dict[str, Any]]) -> str:
    display = KNOWN_SOLUTIONS.get(slug, slug)
    clean_claims = _scr_claims_for_slug(slug, envelopes)
    seed = OVERVIEW_SEEDS.get(slug, "").strip()
    exec_summary = seed or (
        clean_claims[0]
        if clean_claims
        else f"{display} is a solution in the agentic SDLC orchestration landscape."
    )
    lines = [
        f"# Solution Capability Report: {display}",
        "",
        f"Slug: `{slug}`",
        "",
        "## Executive summary",
        "",
        exec_summary,
        "",
        "## Evidence-backed notes",
        "",
    ]
    if clean_claims:
        for text in clean_claims:
            lines.append(f"- {text}")
    elif seed:
        lines.append(f"- {seed}")
    else:
        lines.append("_No direct prose evidence lines matched this solution slug in live envelopes._")
    lines.append("")
    return "\n".join(lines)


def materialize_solution_artifacts(
    research_dir: Path,
    *,
    envelopes: list[dict[str, Any]] | None = None,
    shortlist_count: int = 5,
) -> dict[str, Any]:
    research_dir = Path(research_dir)
    need_path = research_dir / "need_profile.json"
    need: dict[str, Any] = {}
    if need_path.is_file():
        need = json.loads(need_path.read_text(encoding="utf-8"))

    if envelopes is None:
        env_path = research_dir / "contributions" / "all-envelopes.json"
        if not env_path.is_file():
            raise FileNotFoundError(f"missing envelopes: {env_path}")
        raw = json.loads(env_path.read_text(encoding="utf-8"))
        if not isinstance(raw, list):
            raise ValueError("all-envelopes.json must be a JSON array")
        envelopes = [item for item in raw if isinstance(item, dict)]

    if not envelopes:
        raise ValueError("no contribution envelopes to materialize from")

    known = _effective_known_solutions(need)
    pack = resolve_pack_from_need(need)
    audit: dict[str, Any] | None = None
    if pack:
        from solution_classifier import classify_solutions, write_catalog_audit

        audit = classify_solutions(envelopes, need, pack)
        write_catalog_audit(research_dir, audit)

    slugs = discover_solutions(envelopes, need=need)
    support = parse_feature_support(envelopes, known=known, pack=pack)
    rubric = synthesize_feature_rubric(support=support)
    shortlist = slugs[:shortlist_count]

    solutions_root = research_dir / "solutions"
    solutions_root.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    slug_set = set(slugs)
    for slug in slugs:
        sol_dir = solutions_root / slug
        sol_dir.mkdir(parents=True, exist_ok=True)
        features_path = sol_dir / "features.json"
        features_path.write_text(
            json.dumps(build_features_json(slug, support, known=known, rubric=rubric), indent=2) + "\n",
            encoding="utf-8",
        )
        (sol_dir / "scr.md").write_text(build_scr_md(slug, envelopes), encoding="utf-8")
        written.append(str(features_path.relative_to(research_dir)))

    if pack and solutions_root.is_dir():
        import shutil

        for sol_dir in solutions_root.iterdir():
            if sol_dir.is_dir() and sol_dir.name not in slug_set:
                shutil.rmtree(sol_dir)

    shortlist_dir = research_dir / "shortlist"
    shortlist_dir.mkdir(parents=True, exist_ok=True)
    shortlist_payload = {
        "count": len(shortlist),
        "solutions": [
            {
                "rank": i,
                "name": known.get(slug, slug),
                "slug": slug,
                "source": "live-envelopes",
            }
            for i, slug in enumerate(shortlist, start=1)
        ],
    }
    (shortlist_dir / "shortlist.json").write_text(
        json.dumps(shortlist_payload, indent=2) + "\n",
        encoding="utf-8",
    )

    solutions_index = {
        "count": len(slugs),
        "source": "live-envelopes",
        "solutions": [
            {
                "slug": slug,
                "name": known.get(slug, slug),
                "features_path": f"solutions/{slug}/features.json",
                "scr_path": f"solutions/{slug}/scr.md",
            }
            for slug in slugs
        ],
    }
    (research_dir / "solutions.json").write_text(
        json.dumps(solutions_index, indent=2) + "\n",
        encoding="utf-8",
    )
    landscape_dir = research_dir / "landscape"
    landscape_dir.mkdir(parents=True, exist_ok=True)
    (landscape_dir / "features-rubric.json").write_text(
        json.dumps(rubric, indent=2) + "\n",
        encoding="utf-8",
    )

    result: dict[str, Any] = {
        "status": "ok",
        "solutions_count": len(slugs),
        "shortlist_count": len(shortlist),
        "features_written": written,
        "solutions_index": "solutions.json",
        "shortlist": "shortlist/shortlist.json",
    }
    if audit:
        result["catalog_audit"] = "landscape/catalog_audit.json"
        result["core_count"] = len(audit.get("core") or [])
    return result


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Materialize SCR/features from live DR envelopes")
    parser.add_argument("--dir", required=True, help="Research output directory")
    args = parser.parse_args()
    try:
        result = materialize_solution_artifacts(Path(args.dir))
    except (FileNotFoundError, ValueError) as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}))
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
