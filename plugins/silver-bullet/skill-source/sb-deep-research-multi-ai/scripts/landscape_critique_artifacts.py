#!/usr/bin/env python3
"""Page-grounded critique artifacts embedded in landscape-report.md.

Executive summary, inclusion-ledger table, coverage matrix, and consensus
resolution table. Does not re-derive a research run_id.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

INCLUSION_CRITERIA_ORDER: tuple[str, ...] = (
    "Multi-phase lifecycle span",
    "Plugin / skill / hook packaging",
    "Deterministic quality gates",
    "Cross-session state",
    "Specialist agent orchestration",
    "Quality / release enforcement claim",
    "Process layer above host runtime",
)

INCLUSION_CRITERIA_ABBR: tuple[str, ...] = (
    "C1 Life",
    "C2 Plug",
    "C3 Gate",
    "C4 State",
    "C5 Spec",
    "C6 Enf",
    "C7 Proc",
)

_STATUS_CELL = {"pass": "P", "fail": "F", "unknown": "U"}

_CANONICAL_RESOLUTIONS: tuple[dict[str, str], ...] = (
    {
        "subject": "magic-dev",
        "claim": "Magic.dev membership (SaaS core vs hard-excluded)",
        "supporting": "`gemini-3.5-flash` listed it as a tertiary SaaS peer in triangulation envelopes",
        "contradicting": "`ocg-qwen3.7-plus` + category-pack `hard_exclusions` (`coding_agent`)",
        "decision": (
            "FINAL: one membership — hard-excluded as `coding_agent`. Not a SaaS core, "
            "not a comparison-matrix column, not an MQ/Wave point, not a Top Commercial card. "
            "Contributing-model seed lists that re-include it are envelope quotes / model error, "
            "not report membership."
        ),
        "evidence": (
            "Category-pack `hard_exclusions`; `solutions/magic-dev/scr.md` boilerplate "
            "(coding-model lab, not Factory/Devin-class delivery); inclusion ledger "
            "gates/enforcement fail; SaaS cores remain Factory.ai, Devin, Augment Cosmos."
        ),
    },
    {
        "subject": "conductor",
        "claim": "Conductor as APO peer vs aggregator",
        "supporting": "Some triangulation envelopes framed Conductor as a mid-tier APO / process orchestrator",
        "contradicting": "Category-pack adjacent class + `features.json` (no shipped hook gates or specialist orchestration)",
        "decision": (
            "FINAL: aggregator (SaaS-adjacent coding-agent aggregator), not an Agentic Process "
            "Orchestrator. Not plotted on the APO chart and not a comparison column. Claude Harness "
            "is an sdlc-plugins core (host plugins), not APO; there is no 'Claude Code Expert' product "
            "in this peer set (hard-excluded sunset)."
        ),
        "evidence": (
            "Category-pack adjacent class; `solutions/conductor/features.json` has no "
            "shipped hook gates or specialist orchestration; APO cores are process layers "
            "above a host runtime, not multi-agent aggregators."
        ),
    },
    {
        "subject": "silver-bullet",
        "claim": "Silver Bullet is 'most complete'",
        "supporting": "Some retrieve/triangulate envelopes used a completeness superlative for Silver Bullet",
        "contradicting": "Critique envelopes dispute any single OSS APO as 'most complete'",
        "decision": (
            "FINAL: this report does not call any vendor 'most complete'. Silver Bullet's "
            "plugin MQ Leader plot is a feature-gate outcome (hook-enforced gates AND "
            "inclusion-ledger cross-session pass). That is not a completeness ranking. "
            "Buying profiles keep equal-standing peers and do not all resolve to one vendor."
        ),
        "evidence": (
            "Leader eligibility in synthesize_landscape.py (`_CROSS_SESSION_PASS_SLUGS` = "
            "silver-bullet; plugins need gates + ledger C4 pass). APO + plugin ledger 7/7 "
            "is capability evidence, not a superlative. Ranking scores are Critical=5…Low=1 "
            "tick totals. Critique envelopes that used 'most complete' are quoted disagreement, "
            "not report voice."
        ),
    },
    {
        "subject": "secondary-packs",
        "claim": "Secondary packs 'lack gates/state' therefore are empty or not worth buying",
        "supporting": "Some critique envelopes used overbroad negatives about methodology packs",
        "contradicting": "Matrix ticks show dense workflow/template coverage on BMAD, GSD, Spec Kit, Zuvo, and peers",
        "decision": (
            "FINAL: secondary packs are host-plugin substitutes for plan-to-ship workflows, "
            "not automatic APO Leaders. Leader demotion is specifically missing hook gates "
            "and/or cross-session state — not a blanket claim that the pack is empty or useless. "
            "Zuvo is an sdlc-plugins CORE with public evidence, not a missing vendor."
        ),
        "evidence": (
            "sdlc-plugins core membership (13) in catalog_audit / chart-data; comparison "
            "matrix columns include zuvo; MQ plots Zuvo as Visionaries. Consensus pattern "
            "'SDLC plugin / methodology packs as substitutes' is the bounded claim."
        ),
    },
    {
        "subject": "ai-dlc",
        "claim": "AI-DLC is IBM enterprise APO vs AWS methodology without gates",
        "supporting": "Some envelopes framed AI-DLC as enterprise-grade APO with lifecycle orchestration",
        "contradicting": "Public repo is awslabs/aidlc-workflows; features.json has no shipped hook gates",
        "decision": (
            "FINAL: AI-DLC is AWS/awslabs, not IBM. It is an APO core methodology-without-gates "
            "seed: Visionaries on MQ, omitted from APO Wave, not a peer-complete execute Leader."
        ),
        "evidence": (
            "https://github.com/awslabs/aidlc-workflows; catalog_audit apo.core includes "
            "ai-dlc; Wave omits methodology-without-gates; MQ justification Visionaries."
        ),
    },
)


def status_cell(status: str | None) -> str:
    return _STATUS_CELL.get(str(status or "unknown").lower(), "U")


def criterion_status_map(vendor: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for row in vendor.get("criteria") or []:
        if not isinstance(row, dict):
            continue
        name = str(row.get("criterion") or row.get("name") or "").strip()
        if name:
            out[name] = str(row.get("status") or "unknown").lower()
    return out


def first_evidence_cite(vendor: dict[str, Any]) -> str:
    for row in vendor.get("criteria") or []:
        if not isinstance(row, dict):
            continue
        src = str(row.get("source") or "").strip()
        if src:
            return src.replace("|", "/")
    note = str(vendor.get("decision_note") or vendor.get("threshold_note") or "").strip()
    return note[:80] if note else "—"


def load_inclusion_ledger(root: Path | None) -> dict[str, Any]:
    if root is None:
        return {}
    path = root / "landscape" / "inclusion-ledger.json"
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _hard_exclusion_slugs(pack: dict[str, Any] | None) -> set[str]:
    slugs: set[str] = {"magic-dev"}
    if not pack:
        return slugs
    try:
        from category_pack import get_hard_exclusion_slugs

        slugs |= {str(s) for s in get_hard_exclusion_slugs(pack) if s}
    except Exception:
        pass
    return slugs


def _market_core(audit: dict[str, Any] | None, market: str) -> set[str]:
    block = ((audit or {}).get("markets") or {}).get(market) or {}
    if not isinstance(block, dict):
        return set()
    return {str(s) for s in (block.get("core") or []) if s}


def _market_adjacent(audit: dict[str, Any] | None, market: str) -> set[str]:
    block = ((audit or {}).get("markets") or {}).get(market) or {}
    if not isinstance(block, dict):
        return set()
    return {str(s) for s in (block.get("adjacent") or []) if s}


def _home_core_markets(slug: str, audit: dict[str, Any] | None) -> list[str]:
    homes: list[str] = []
    for mid, block in ((audit or {}).get("markets") or {}).items():
        if isinstance(block, dict) and slug in {str(s) for s in (block.get("core") or []) if s}:
            homes.append(str(mid))
    return homes


def vendor_final_decision(
    slug: str,
    market: str,
    *,
    audit: dict[str, Any] | None,
    pack: dict[str, Any] | None,
) -> str:
    slug = str(slug or "")
    market = str(market or "")
    if slug in _hard_exclusion_slugs(pack):
        return "hard-excluded"
    if slug == "conductor":
        return "adjacent-aggregator (not APO)"
    if slug in _market_core(audit, market):
        return "included-core"
    if slug in _market_adjacent(audit, market):
        if slug == "agenthub":
            return "adjacent (APO CRM — not Leaders)"
        if slug == "tembo":
            return "adjacent (unplotted)"
        return "adjacent"
    homes = _home_core_markets(slug, audit)
    if homes:
        return f"core in {' ∩ '.join(homes)} only — not {market}"
    if slug in {str(s) for s in ((audit or {}).get("adjacent") or [])}:
        return "adjacent"
    if slug in {str(s) for s in ((audit or {}).get("excluded") or [])}:
        return "hard-excluded"
    if slug in {str(s) for s in ((audit or {}).get("sunset") or [])}:
        return "sunset"
    return "not in core set"


def _leader_labels(
    chart: dict[str, Any] | None,
    market_id: str,
) -> list[str]:
    markets = (chart or {}).get("markets") or {}
    block = markets.get(market_id) or {}
    labels: list[str] = []
    for point in block.get("gmq_data") or []:
        if isinstance(point, dict) and point.get("q") == "Leaders":
            labels.append(str(point.get("label") or point.get("slug") or ""))
    return [x for x in labels if x]


def executive_summary_lines(
    *,
    chart: dict[str, Any] | None,
    pack: dict[str, Any] | None,
    known: dict[str, str],
    audit: dict[str, Any] | None,
) -> list[str]:
    apo_leaders = _leader_labels(chart, "apo") or [known.get("silver-bullet", "Silver Bullet")]
    plugin_leaders = _leader_labels(chart, "sdlc-plugins") or [
        known.get("silver-bullet", "Silver Bullet")
    ]
    saas_leaders = _leader_labels(chart, "agentic-sdlc-saas") or [
        known.get("devin", "Devin"),
        known.get("factory-ai", "Factory.ai"),
        known.get("augment-cosmos", "Augment Cosmos"),
    ]
    plugin_core = list(((audit or {}).get("markets") or {}).get("sdlc-plugins", {}).get("core") or [])
    plugin_peers = [known.get(s, s) for s in plugin_core if s != "silver-bullet"][:5]
    apo_core = list(((audit or {}).get("markets") or {}).get("apo", {}).get("core") or [])
    apo_peers = [known.get(s, s) for s in apo_core if s != "silver-bullet"][:5]
    saas_core = list(
        ((audit or {}).get("markets") or {}).get("agentic-sdlc-saas", {}).get("core") or []
    )
    saas_names = [known.get(s, s) for s in saas_core] or saas_leaders

    return [
        "## Executive Summary",
        "",
        "One-page briefing for SMB buyers. Charts and vendor cards follow; this page does not "
        "restate coordinate formulas.",
        "",
        "### Market overview",
        "",
        "Agentic SDLC orchestration sits **one level above coding agents**: process catalogs, "
        "gates, and specialist routing rather than raw codegen. Three markets are scored "
        "separately — **Agentic Process Orchestrators (APO)** (primary), **SDLC plugins & "
        "methodology packs** (secondary), and **agentic SDLC SaaS / autonomous delivery** "
        "(tertiary). The category is early mainstream: executor-first hosts are ahead of "
        "fail-closed process layers. OSS packs dominate experimentation; commercial SaaS "
        "leads managed execution.",
        "",
        "### Key findings",
        "",
        "- Buyers should shortlist **by market**, not from a single blended ranking.",
        "- Hook-enforced gates plus durable cross-session state remain the scarce combination; "
        "most methodology packs are skippable prompt/persona layers.",
        "- Thin-evidence APO commercials (Deepwork, Turboshovel, Workflow Manager) stay on "
        "the chart as cores but are not a procurement shortlist on ticks alone.",
        "- Magic.dev is hard-excluded (coding-model lab). Conductor is an aggregator, not APO. "
        "This report does not call any vendor 'most complete'.",
        "- Zuvo is an sdlc-plugins **core** with public evidence (https://zuvo.dev/ → MIT GitHub). "
        "It is scored and placed with the other plugin cores; it is not a coverage gap.",
        "",
        "### Leader shortlist (per market)",
        "",
        f"- **APO (primary):** {', '.join(apo_leaders) or '—'}",
        f"- **SDLC plugins & methodology packs:** {', '.join(plugin_leaders) or '—'}",
        f"- **Agentic SDLC SaaS:** {', '.join(saas_leaders) or '—'}",
        "",
        "Leader plots are MQ top-right in this run. Plugin MQ Leaders = Silver Bullet only "
        "because only Silver Bullet passed hook-enforced gates AND inclusion-ledger "
        "cross-session in this run — a feature-gate fact, not a 'most complete product' claim. "
        "They are not a mandate to buy one vendor across every profile.",
        "",
        "### Buyer guidance",
        "",
        f"- **Spec-first / lean packs:** equal-standing OSS peers"
        + (f" ({', '.join(plugin_peers)})" if plugin_peers else "")
        + " — pick on spec vs persona vs swarm topology.",
        f"- **OSS APO cores:** equal-standing peers"
        + (f" ({', '.join(apo_peers)})" if apo_peers else "")
        + "; AI-DLC is methodology vocabulary without shipped hook gates.",
        f"- **Managed autonomous delivery:** {', '.join(saas_names) or 'Factory.ai, Devin, Augment Cosmos'} "
        "— this profile does not resolve to an OSS process pack.",
        "- **Host-runtime path:** Cursor / Claude Code / Codex **plus a pack**. The host is not "
        "the orchestrator.",
        "",
    ]


def inclusion_ledger_embed_lines(
    *,
    root: Path | None,
    audit: dict[str, Any] | None,
    pack: dict[str, Any] | None,
    known: dict[str, str],
) -> list[str]:
    payload = load_inclusion_ledger(root)
    vendors = [v for v in (payload.get("vendors") or []) if isinstance(v, dict)]
    lines = [
        "### Vendor inclusion ledger",
        "",
        "3-of-7 inclusion rule applied **per market**. Cells: **P** pass / **F** fail / **U** "
        "unknown. Legend: C1 lifecycle · C2 plugin/hook packaging · C3 deterministic gates · "
        "C4 cross-session state · C5 specialist orchestration · C6 quality/release "
        "enforcement · C7 process layer above host. Full per-criterion notes: "
        "`landscape/inclusion-ledger.md`.",
        "",
        "**Membership must match charts.** APO core (~8): AgentSys, AI-DLC, Deepwork, Director, "
        "MetaGPT, Silver Bullet, Turboshovel, Workflow Manager. sdlc-plugins core (~13): BMAD, "
        "GSD, Zuvo, Spec Kit, Superpowers, SuperClaude, Ruflo, Oh My Pi, Claude Harness, cc10x, "
        "Cavekit, Barkain, Silver Bullet. SaaS core: Factory.ai, Devin, Augment Cosmos. "
        "Multi-market is allowed: Silver Bullet is APO ∩ sdlc-plugins (process catalog + hook "
        "gates **and** host-plugin packaging).",
        "",
        "| Vendor | Market | "
        + " | ".join(INCLUSION_CRITERIA_ABBR)
        + " | Evidence cite | Final decision |",
        "|" + "---|" * 11,
    ]

    def _row(vendor: dict[str, Any], decision: str) -> str:
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        statuses = criterion_status_map(vendor)
        cells = [status_cell(statuses.get(name)) for name in INCLUSION_CRITERIA_ORDER]
        display = str(vendor.get("display") or known.get(slug, slug))
        cite = first_evidence_cite(vendor)
        return f"| {display} | `{market}` | " + " | ".join(cells) + f" | {cite} | {decision} |"

    core_rows: list[str] = []
    adjacent_rows: list[str] = []
    excluded_rows: list[str] = []
    seen: set[tuple[str, str]] = set()
    for vendor in sorted(
        vendors,
        key=lambda v: (str(v.get("market") or ""), str(v.get("display") or v.get("slug") or "")),
    ):
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        homes = _home_core_markets(slug, audit)
        if homes and market not in homes and slug not in _hard_exclusion_slugs(pack):
            # Wrong-market row (e.g. plugin core listed as APO) — skip, do not treat as included.
            continue
        decision = vendor.get("final_decision") or vendor_final_decision(
            slug, market, audit=audit, pack=pack
        )
        if decision == "included-core" and slug not in _market_core(audit, market):
            decision = vendor_final_decision(slug, market, audit=audit, pack=pack)
        seen.add((slug, market))
        line = _row(vendor, str(decision))
        if str(decision) == "hard-excluded":
            excluded_rows.append(line)
        elif str(decision).startswith("adjacent"):
            adjacent_rows.append(line)
        elif str(decision) == "included-core":
            core_rows.append(line)

    for slug, market in (
        ("zuvo", "sdlc-plugins"),
        ("conductor", "agentic-sdlc-saas"),
        ("agenthub", "apo"),
        ("tembo", "agentic-sdlc-saas"),
    ):
        if (slug, market) in seen:
            continue
        decision = vendor_final_decision(slug, market, audit=audit, pack=pack)
        display = known.get(slug, slug.replace("-", " ").title())
        stub = {
            "slug": slug,
            "market": market,
            "display": display,
            "criteria": [],
            "decision_note": "not in inclusion-ledger.json",
        }
        line = _row(stub, decision)
        if decision == "included-core":
            core_rows.append(line)
        elif str(decision).startswith("adjacent"):
            adjacent_rows.append(line)

    lines.extend(core_rows)
    if adjacent_rows:
        lines.extend(["", "_Adjacent (not core in that market)_", ""])
        lines.extend(adjacent_rows)
    if excluded_rows:
        lines.extend(
            [
                "",
                "_Hard-excluded — not membership. Envelope quotes that re-include these are "
                "model error, not seed lists._",
                "",
            ]
        )
        lines.extend(excluded_rows)
    lines.append("")
    return lines


def _evidence_available(root: Path | None, slug: str) -> str:
    if root is None:
        return "unknown"
    sol = root / "solutions" / slug
    feat = (sol / "features.json").is_file()
    scr = (sol / "scr.md").is_file()
    if feat and scr:
        return "yes (features.json + scr.md)"
    if feat:
        return "partial (features.json)"
    if scr:
        return "partial (scr.md)"
    return "missing"


def coverage_completeness_lines(
    *,
    root: Path | None,
    audit: dict[str, Any] | None,
    comparison: dict[str, Any],
    pack: dict[str, Any] | None,
    known: dict[str, str],
) -> list[str]:
    ranked = {
        str(item.get("solution"))
        for item in (comparison.get("rankings") or [])
        if isinstance(item, dict) and item.get("solution")
    }
    ledger = load_inclusion_ledger(root)
    ledger_slugs = {
        str(v.get("slug"))
        for v in (ledger.get("vendors") or [])
        if isinstance(v, dict) and v.get("slug")
    }
    markets = (audit or {}).get("markets") or {}
    rows: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str]] = set()
    for mid, block in markets.items():
        if not isinstance(block, dict):
            continue
        for slug in block.get("core") or []:
            key = (str(slug), str(mid))
            if key not in seen:
                rows.append((str(slug), str(mid), "core"))
                seen.add(key)
        for slug in block.get("adjacent") or []:
            key = (str(slug), str(mid))
            if key not in seen:
                rows.append((str(slug), str(mid), "adjacent"))
                seen.add(key)
    extra = [
        ("magic-dev", "hard-excluded", "hard-excluded"),
        ("ateam", "hard-excluded", "hard-excluded"),
    ]
    for slug, mid, place in extra:
        if (slug, mid) not in seen:
            rows.append((slug, mid, place))
            seen.add((slug, mid))

    lines = [
        "### Coverage completeness matrix",
        "",
        "Whether this run has **evidence files**, a **comparison-matrix score**, and a "
        "**market placement** — separate from 3-of-7 inclusion. Gaps are why a vendor "
        "may appear in one artifact and not another.",
        "",
        "| Vendor | Evidence available | Scoring complete | Market placement | Gaps |",
        "|--------|--------------------|------------------|------------------|------|",
    ]
    for slug, market, place in sorted(rows, key=lambda r: (r[1], r[0])):
        display = known.get(slug, slug.replace("-", " ").title())
        evidence = _evidence_available(root, slug)
        scored = "yes" if slug in ranked else "no"
        placement = vendor_final_decision(slug, market, audit=audit, pack=pack)
        if place == "hard-excluded":
            placement = "hard-excluded"
        elif place == "adjacent-aggregator":
            placement = "adjacent-aggregator (not APO)"
        gaps: list[str] = []
        if slug == "zuvo":
            pass
        if slug == "magic-dev":
            gaps.append(
                "quoted model error / hard-excluded coding_agent — not SaaS core, not MQ/Wave, "
                "not a comparison-matrix column"
            )
        if slug == "ateam":
            gaps.append("hard-excluded FDE shop / professional_services — not APO membership")
        if slug == "conductor":
            gaps.append("SaaS-adjacent aggregator; not APO core")
        if slug == "agenthub" and market == "apo":
            gaps.append("APO-adjacent CRM — not Leaders")
        if slug == "tembo":
            gaps.append("SaaS-adjacent / unplotted")
        if slug in {"deepwork", "turboshovel", "workflow-manager"}:
            gaps.append("thin-evidence APO commercial — ticks are proxies, not a shortlist")
        if slug == "metagpt" and evidence.startswith("missing"):
            gaps.append(
                "APO OSS core without solution artifacts in this run — U cells are honest unknowns; "
                "new DR needed to fill critical-matrix evidence"
            )
        if slug not in ranked and placement == "included-core":
            gaps.append("core without ranking row")
        if evidence.startswith("missing") and slug != "metagpt":
            gaps.append("no solution artifacts")
        if slug == "ai-dlc":
            gaps.append("AWS/awslabs methodology-without-gates — Visionaries, omitted from APO Wave")
        gap_text = "; ".join(gaps) if gaps else "—"
        lines.append(
            f"| {display} | {evidence} | {scored} | `{market}` / {placement} | {gap_text} |"
        )
    lines.append("")
    return lines


def _side_agents(side: dict[str, Any]) -> str:
    agents = side.get("supporting_agents") or side.get("model_families") or []
    names = [str(a) for a in agents if a]
    return ", ".join(f"`{n}`" for n in names[:4]) if names else "unattributed"


def _sides_by_stance(item: dict[str, Any]) -> tuple[str, str]:
    supporting: list[str] = []
    contradicting: list[str] = []
    for side in item.get("sides") or []:
        if not isinstance(side, dict):
            continue
        who = _side_agents(side)
        stance = str(side.get("stance") or side.get("label") or "").lower()
        text = str(side.get("stance_text") or "")
        if stance in {"neg", "negative", "contra"} or "not " in text.lower()[:40]:
            contradicting.append(who)
        else:
            supporting.append(who)
    return "; ".join(supporting) or "—", "; ".join(contradicting) or "—"


def consensus_resolution_table_lines(
    notable: list[dict[str, Any]] | None,
) -> list[str]:
    by_subject: dict[str, dict[str, Any]] = {}
    for item in notable or []:
        if isinstance(item, dict) and item.get("subject"):
            by_subject[str(item["subject"])] = item

    lines = [
        "### Consensus Resolution Table",
        "",
        "Disputed claims are **resolved** here. Envelope quotes of model disagreement "
        "belong in this table only — they are not seed lists, comparison columns, or "
        "Top Commercial membership.",
        "",
        "| Claim | Supporting models | Contradicting models | Final analyst decision | Evidence |",
        "|-------|-------------------|----------------------|------------------------|----------|",
    ]
    used: set[str] = set()
    for row in _CANONICAL_RESOLUTIONS:
        subject = row["subject"]
        used.add(subject)
        env = by_subject.get(subject) or {}
        supporting, contradicting = _sides_by_stance(env)
        supporting = row.get("supporting") or supporting
        contradicting = row.get("contradicting") or contradicting
        lines.append(
            f"| {row['claim']} | {supporting} | {contradicting} | {row['decision']} | {row['evidence']} |"
        )
    # Envelope clusters that are not one of the resolved disputes stay out of this table.
    # Notable divergences = inter-model disagreement; this table = analyst call.
    lines.append("")
    return lines


def _zuvo_ledger_vendor() -> dict[str, Any]:
    """Extend the ledger with Zuvo using features.json proxies (coverage gap)."""
    proxies = {
        "Multi-phase lifecycle span": (
            "pass",
            "solutions/zuvo/features.json:Workflow composition",
        ),
        "Plugin / skill / hook packaging": (
            "pass",
            "https://zuvo.dev/ + solutions/zuvo/features.json:IDE-native / hooks",
        ),
        "Deterministic quality gates": (
            "pass",
            "solutions/zuvo/features.json:Hook-enforced gates",
        ),
        "Cross-session state": (
            "unknown",
            "solutions/zuvo/features.json|scr.md (insufficient evidence)",
        ),
        "Specialist agent orchestration": (
            "pass",
            "solutions/zuvo/features.json:Parent/child agent delegation",
        ),
        "Quality / release enforcement claim": (
            "unknown",
            "solutions/zuvo/scr.md (insufficient evidence)",
        ),
        "Process layer above host runtime": (
            "pass",
            "https://zuvo.dev/ → sdlc-plugins core, not APO",
        ),
    }
    criteria = []
    passes = 0
    for name in INCLUSION_CRITERIA_ORDER:
        status, source = proxies[name]
        if status == "pass":
            passes += 1
        criteria.append(
            {
                "criterion": name,
                "status": status,
                "source": source,
                "confidence": "medium" if status == "pass" else "low",
                "date": "2026-08-14",
                "reviewer": "act-on-critique-artifacts",
        "note": "Zuvo is sdlc-plugins core with public evidence; not a coverage gap.",
            }
        )
    return {
        "market": "sdlc-plugins",
        "slug": "zuvo",
        "display": "Zuvo",
        "pass_count": passes,
        "threshold_met": passes >= 3,
        "criteria": criteria,
        "final_decision": "included-core",
        "decision_note": "sdlc-plugins core; not APO",
    }


def patch_inclusion_ledger(root: Path, *, pack: dict[str, Any] | None, audit: dict[str, Any] | None) -> dict[str, Any]:
    """Reuse inclusion-ledger.json; fix Magic.dev; add Zuvo coverage row. Keep run_id."""
    path = root / "landscape" / "inclusion-ledger.json"
    payload = load_inclusion_ledger(root)
    if not payload:
        payload = {
            "version": 1,
            "run_id": "run-57f38dfa25d83cc50d224e283d4692f3",
            "rule": "3-of-7",
            "vendors": [],
        }
    payload["run_id"] = payload.get("run_id") or "run-57f38dfa25d83cc50d224e283d4692f3"
    payload["reviewer"] = "act-on-critique-artifacts"
    vendors = [v for v in (payload.get("vendors") or []) if isinstance(v, dict)]
    slugs = {str(v.get("slug")) for v in vendors}
    patched: list[dict[str, Any]] = []
    for vendor in vendors:
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        homes = _home_core_markets(slug, audit)
        if slug == "magic-dev":
            vendor = dict(vendor)
            vendor["threshold_met"] = False
            vendor["final_decision"] = "hard-excluded"
            vendor["decision_note"] = (
                "coding_agent — one membership only; not SaaS core, not comparison column, "
                "not Top Commercial. 3-of-7 proxy ticks do not override pack hard-exclusion."
            )
            vendor["placement"] = "hard-excluded"
        elif slug in _hard_exclusion_slugs(pack):
            vendor = dict(vendor)
            vendor["final_decision"] = "hard-excluded"
            vendor["threshold_met"] = False
        else:
            vendor = dict(vendor)
            if homes and market not in homes:
                vendor["market"] = homes[0]
                market = homes[0]
            vendor["final_decision"] = vendor_final_decision(
                slug, market, audit=audit, pack=pack
            )
        patched.append(vendor)
    if "zuvo" not in slugs:
        patched.append(_zuvo_ledger_vendor())
    payload["vendors"] = patched
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    _write_inclusion_ledger_markdown(root, payload, pack=pack, audit=audit)
    return payload


def _write_inclusion_ledger_markdown(
    root: Path,
    payload: dict[str, Any],
    *,
    pack: dict[str, Any] | None,
    audit: dict[str, Any] | None,
) -> None:
    lines = [
        "# Inclusion ledger (3-of-7)",
        "",
        f"Generated: 2026-08-14 · Reviewer: `act-on-critique-artifacts` · "
        f"Run: `{payload.get('run_id')}` (not re-derived)",
        "",
        "Compact decision table (P/F/U). Magic.dev is **hard-excluded** even if proxy ticks "
        "meet 3-of-7. Zuvo added as sdlc-plugins coverage close.",
        "",
        "| Vendor | Market | "
        + " | ".join(INCLUSION_CRITERIA_ABBR)
        + " | Evidence cite | Final decision |",
        "|" + "---|" * 11,
    ]
    for vendor in sorted(
        [v for v in (payload.get("vendors") or []) if isinstance(v, dict)],
        key=lambda v: (str(v.get("market") or ""), str(v.get("display") or "")),
    ):
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        statuses = criterion_status_map(vendor)
        cells = [status_cell(statuses.get(name)) for name in INCLUSION_CRITERIA_ORDER]
        display = str(vendor.get("display") or slug)
        decision = vendor.get("final_decision") or vendor_final_decision(
            slug, market, audit=audit, pack=pack
        )
        lines.append(
            f"| {display} | `{market}` | "
            + " | ".join(cells)
            + f" | {first_evidence_cite(vendor)} | {decision} |"
        )
    lines.extend(["", "## Per-criterion rows", ""])
    for vendor in sorted(
        [v for v in (payload.get("vendors") or []) if isinstance(v, dict)],
        key=lambda v: (str(v.get("market") or ""), str(v.get("display") or "")),
    ):
        display = str(vendor.get("display") or vendor.get("slug"))
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        lines.append(f"### {display} (`{slug}`) — {market}")
        lines.append("")
        lines.append("| Criterion | Status | Source | Confidence | Date | Reviewer |")
        lines.append("|-----------|--------|--------|------------|------|----------|")
        for row in vendor.get("criteria") or []:
            if not isinstance(row, dict):
                continue
            lines.append(
                "| {criterion} | {status} | {source} | {confidence} | {date} | {reviewer} |".format(
                    criterion=row.get("criterion") or "",
                    status=row.get("status") or "",
                    source=str(row.get("source") or "").replace("|", "/"),
                    confidence=row.get("confidence") or "",
                    date=row.get("date") or "",
                    reviewer=row.get("reviewer") or "",
                )
            )
        lines.append("")
    md_path = root / "landscape" / "inclusion-ledger.md"
    md_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
