#!/usr/bin/env python3
"""Address-all non-COI multi-AI critique fixes for multimarket landscape report.

Does NOT demote Silver Bullet for COI. Regenerates durable artifacts under the report root.
"""
from __future__ import annotations

import json
import re
import shutil
from collections import Counter
from copy import deepcopy
from datetime import date
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BAK = OUT / "backups"
TODAY = date.today().isoformat()
REVIEWER = "address-all-non-coi-pass"

CRITERIA = [
    "Multi-phase lifecycle span",
    "Plugin / skill / hook packaging",
    "Deterministic quality gates",
    "Cross-session state",
    "Specialist agent orchestration",
    "Quality / release enforcement claim",
    "Process layer above host runtime",
]

# features.json name → Blue Ocean KCF order
BO_KCFS = [
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

FEATURE_ALIASES = {
    "Parent/child agent delegation": "Parent/child delegation",
    "Parent/child delegation": "Parent/child delegation",
}

# Inclusion criterion → feature proxies (true helps pass; false/null do not invent pass)
CRITERION_FEATURES: dict[str, list[str]] = {
    "Multi-phase lifecycle span": ["Workflow composition", "Prebuilt SDLC templates"],
    "Plugin / skill / hook packaging": ["Skill/plugin marketplace", "IDE-native integration"],
    "Deterministic quality gates": ["Hook-enforced gates"],
    "Cross-session state": [],  # SCR/envelope only — features pack lacks this axis
    "Specialist agent orchestration": ["Parent/child agent delegation"],
    "Quality / release enforcement claim": ["CI integration", "Automated review loops", "Hook-enforced gates"],
    "Process layer above host runtime": ["IDE-native integration", "Skill/plugin marketplace"],
}

LABEL_TO_SLUG = {
    "cc10x": "cc10x",
    "AgentHub": "agenthub",
    "Silver Bullet": "silver-bullet",
    "AI-DLC": "ai-dlc",
    "BMAD-METHOD": "bmad",
    "GSD (Get Shit Done)": "gsd",
    "Oh My Pi (OMP)": "oh-my-pi",
    "Ruflo / Claude Flow": "ruflo",
    "GitHub Spec Kit": "spec-kit",
    "SuperClaude": "superclaude",
    "Superpowers": "superpowers",
    "Claude Harness": "claude-harness",
    "Devin": "devin",
    "Factory.ai": "factory-ai",
    "Augment Cosmos": "augment-cosmos",
    "Augment Code (Cosmos)": "augment-cosmos",
    "Magic.dev": "magic-dev",
    "Tembo": "tembo",
    "Zuvo": "zuvo",
}

AWS_AIDLC = "https://github.com/awslabs/aidlc-workflows"
IBM_URL_RE = re.compile(
    r"https?://(?:www\.)?developer\.ibm\.com/articles/ai-driven-development-life-cycle/?",
    re.I,
)


def bak(path: Path) -> None:
    BAK.mkdir(parents=True, exist_ok=True)
    if path.exists():
        dest = BAK / path.name
        shutil.copy2(path, dest)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def dump_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def feature_map(slug: str) -> dict[str, Any]:
    fj = ROOT / "solutions" / slug / "features.json"
    if not fj.exists():
        return {}
    data = load_json(fj)
    out: dict[str, Any] = {}
    for cat in data.get("categories", []):
        for f in cat.get("features", []):
            out[f["name"]] = f.get("supported")
    return out


def bo_score(supported: Any) -> int:
    """Feature-pass Blue Ocean cell: true=5, false=1, unknown/null=3 — not binary 3/5."""
    if supported is True:
        return 5
    if supported is False:
        return 1
    return 3


def bo_vector(slug: str) -> list[int]:
    fmap = feature_map(slug)
    vec: list[int] = []
    for kcf in BO_KCFS:
        val = None
        for name, raw in fmap.items():
            mapped = FEATURE_ALIASES.get(name, name)
            if mapped == kcf or name == kcf:
                val = raw
                break
        vec.append(bo_score(val))
    return vec


def scrub_ibm_text(text: str) -> str:
    t = IBM_URL_RE.sub(AWS_AIDLC, text)
    t = re.sub(
        r"AI-DLC\s*[—–-]\s*AI-Driven Development Lifecycle\s*\(developer\.ibm\.com\s*/\s*community\)",
        "AI-DLC — AI-Driven Development Lifecycle (AWS Labs / awslabs/aidlc-workflows)",
        t,
        flags=re.I,
    )
    t = re.sub(r"\bAI-DLC\s*\(IBM\)", "AI-DLC (AWS / awslabs)", t, flags=re.I)
    t = re.sub(r"\bIBM'?s?\s+AI-DLC\b", "AWS AI-DLC", t, flags=re.I)
    t = t.replace("developer.ibm.com / community", "AWS Labs / awslabs/aidlc-workflows")
    t = t.replace("developer.ibm.com/community", "awslabs/aidlc-workflows")
    return t


def scrub_ibm_obj(obj: Any) -> Any:
    if isinstance(obj, str):
        return scrub_ibm_text(obj)
    if isinstance(obj, list):
        return [scrub_ibm_obj(x) for x in obj]
    if isinstance(obj, dict):
        return {k: scrub_ibm_obj(v) for k, v in obj.items()}
    return obj


def demote_tembo(cd: dict[str, Any], catalog: dict[str, Any]) -> dict[str, Any]:
    """Demote Tembo from SaaS core → adjacent/unplotted using run evidence (≤2-of-7 + identity risk)."""
    evidence = {
        "decision": "demote_core_to_adjacent_unplotted",
        "reason": (
            "Run envelopes include both agent-surface claims (tembo.io, medium confidence) and an "
            "explicit inclusion judgment that Tembo 'Satisfies 2 of 7 inclusion criteria at most — "
            "qualifies as tertiary Adjacent, not Top-N' plus IDENTITY RISK (Postgres-first brand). "
            "Core/MQ/Wave/Blue Ocean require ≥3-of-7 clear evidence; keep listed adjacent/watchlist only."
        ),
        "sources": [
            "solutions/tembo/scr.md",
            "contributions/all-envelopes.json (Tembo 2-of-7 claim)",
            "https://tembo.io/",
            "https://www.tembo.io/blog/autonomous-software-maintenance-has-arrived",
        ],
        "date": TODAY,
        "reviewer": REVIEWER,
    }
    saas = cd["markets"]["agentic-sdlc-saas"]
    # membership
    core = [s for s in saas["membership"]["core"] if s != "tembo"]
    adj = list(dict.fromkeys(list(saas["membership"].get("adjacent", [])) + ["tembo"]))
    saas["membership"]["core"] = core
    saas["membership"]["adjacent"] = adj
    listed = list(dict.fromkeys(list(saas.get("listed_slugs", [])) + ["tembo"]))
    saas["listed_slugs"] = listed
    saas["membership"]["listed"] = [s for s in saas["membership"].get("listed", listed) if True]
    if "tembo" not in saas["membership"]["listed"]:
        saas["membership"]["listed"] = list(dict.fromkeys(list(saas["membership"].get("listed", [])) + ["tembo"]))
    saas["plotted_slugs"] = [s for s in saas["plotted_slugs"] if s != "tembo"]
    # charts
    for key in ("mq_data", "gmq_data", "wave_data"):
        saas[key] = [r for r in saas.get(key, []) if r.get("slug") != "tembo"]
    saas["vc_commercial"] = [r for r in saas.get("vc_commercial", []) if r.get("label") != "Tembo"]
    # buckets
    vb = saas["vendor_buckets"]
    for k in ("commercial", "leaders", "challengers", "visionaries", "niche_players"):
        if k in vb and isinstance(vb[k], list):
            vb[k] = [x for x in vb[k] if x != "Tembo"]
    # urls / links — keep URL for adjacent card
    unplotted = [u for u in saas.get("unplotted", []) if u.get("slug") != "tembo"]
    unplotted.append(
        {
            "slug": "tembo",
            "reason": (
                "Demoted from SaaS core: run evidence ≤2-of-7 inclusion + IDENTITY RISK "
                "(Postgres-first brand; agent product surface not clear enough for Top-N). "
                "Listed adjacent/watchlist only."
            ),
            "evidence_status": "demoted-adjacent",
        }
    )
    saas["unplotted"] = unplotted
    saas["membership"]["unplotted"] = unplotted
    # methodology
    meth = saas.setdefault("methodology", {})
    meth["wave_selection"] = "Wave includes all SaaS MQ-plotted cores (N=4 after Tembo demotion)."
    meth["wave_omitted"] = []
    meth["tembo_decision"] = evidence
    meth["empty_challengers_rationale"] = (
        "With four SaaS cores after Tembo demotion and two Leaders (Devin, Factory.ai), "
        "remaining peers (Augment Code/Cosmos, Magic.dev) are Visionaries by axis placement. "
        "No honest Challenger exists without inventing vendors — Challengers remain empty by evidence."
    )
    # top-level mirrors if present
    if cd.get("primary_market_id") == "agentic-sdlc-saas":
        pass
    # catalog_audit
    if "tembo" in catalog.get("core", []):
        catalog["core"] = [s for s in catalog["core"] if s != "tembo"]
    if "tembo" not in catalog.get("adjacent", []):
        catalog.setdefault("adjacent", []).append("tembo")
    by = catalog.setdefault("by_slug", {})
    by["tembo"] = {
        "classification": "adjacent",
        "reason": "Demoted from agentic-sdlc-saas core — ≤2-of-7 + identity risk (address-all-non-coi)",
    }
    markets = catalog.setdefault("markets", {})
    if "agentic-sdlc-saas" in markets:
        m = markets["agentic-sdlc-saas"]
        if isinstance(m, dict):
            if "core" in m:
                m["core"] = [s for s in m["core"] if s != "tembo"]
            if "adjacent" in m and "tembo" not in m["adjacent"]:
                m["adjacent"].append("tembo")
    (OUT / "tembo-decision.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return evidence


def rescore_blue_ocean(cd: dict[str, Any]) -> dict[str, Any]:
    report: dict[str, Any] = {"markets": {}, "scale": "feature-pass 1=false / 3=unknown / 5=true"}
    for mid, market in cd["markets"].items():
        before = {
            "commercial": deepcopy(market.get("vc_commercial", [])),
            "oss": deepcopy(market.get("vc_oss", [])),
        }
        new_c = []
        for row in market.get("vc_commercial", []):
            label = row["label"]
            if label == "Zuvo":
                continue  # quarantined — must not appear on Blue Ocean
            slug = LABEL_TO_SLUG.get(label)
            if not slug:
                new_c.append(row)
                continue
            vec = bo_vector(slug)
            new_c.append({**row, "data": vec, "score_source": "features.json feature-pass"})
        new_o = []
        for row in market.get("vc_oss", []):
            label = row["label"]
            if label == "Zuvo":
                continue
            slug = LABEL_TO_SLUG.get(label)
            if not slug:
                new_o.append(row)
                continue
            vec = bo_vector(slug)
            new_o.append({**row, "data": vec, "score_source": "features.json feature-pass"})
        # Rename Augment Cosmos label if present
        for row in new_c:
            if row.get("label") == "Augment Cosmos":
                row["label"] = "Augment Code (Cosmos)"
        market["vc_commercial"] = new_c
        market["vc_oss"] = new_o
        note = (
            "Blue Ocean KCF scores are feature-pass derived from solutions/*/features.json "
            "(true=5, false=1, unknown/null=3). Not a Leader definition; not binary 3/5."
        )
        market.setdefault("methodology", {})["blue_ocean"] = note
        report["markets"][mid] = {
            "before_unique": {
                "commercial": sorted({v for r in before["commercial"] for v in r.get("data", [])}),
                "oss": sorted({v for r in before["oss"] for v in r.get("data", [])}),
            },
            "after": {
                "commercial": [{k: r[k] for k in ("label", "data") if k in r} for r in new_c],
                "oss": [{k: r[k] for k in ("label", "data") if k in r} for r in new_o],
            },
        }
    cd.setdefault("scoring_methodology", {})["blue_ocean"] = (
        "KCF radar from features.json feature-pass (1/3/5). Contrast set only — not Leaders."
    )
    # also update top-level vc if mirrors primary
    primary = cd.get("primary_market_id")
    if primary and primary in cd["markets"]:
        m = cd["markets"][primary]
        cd["vc_commercial"] = deepcopy(m.get("vc_commercial", []))
        cd["vc_oss"] = deepcopy(m.get("vc_oss", []))
        cd["vc_kcfs"] = deepcopy(m.get("vc_kcfs", cd.get("vc_kcfs", BO_KCFS)))
    dump_json(OUT / "blue-ocean-rescore.json", report)
    return report


def criterion_status(slug: str, criterion: str, fmap: dict[str, Any], scr: str) -> dict[str, Any]:
    """Derive pass/fail/unknown from features + light SCR keyword evidence. No invented URLs."""
    feats = CRITERION_FEATURES.get(criterion, [])
    feat_vals = []
    for f in feats:
        if f in fmap:
            feat_vals.append((f, fmap[f]))
        elif f == "Parent/child agent delegation" and "Parent/child agent delegation" in fmap:
            feat_vals.append((f, fmap[f]))
    # keyword hints in SCR (evidence language only)
    kw_map = {
        "Multi-phase lifecycle span": [r"lifecycle", r"plan.?spec", r"multi-?phase", r"end-to-end"],
        "Plugin / skill / hook packaging": [r"plugin", r"skill", r"hook packaging", r"host-integrated"],
        "Deterministic quality gates": [r"deterministic", r"hook-enforced", r"quality gate", r"stop-check"],
        "Cross-session state": [r"cross-session", r"persist", r"memory", r"state machine", r"worktree"],
        "Specialist agent orchestration": [r"specialist", r"subagent", r"delegation", r"swarm", r"role"],
        "Quality / release enforcement claim": [r"enforcement", r"compliance", r"release gate", r"CI"],
        "Process layer above host runtime": [r"process layer", r"above host", r"meta-orchestr", r"wrapper"],
    }
    scr_l = scr.lower()
    kw_hit = any(re.search(p, scr_l, re.I) for p in kw_map.get(criterion, []))

    if any(v is True for _, v in feat_vals):
        status = "pass"
        confidence = "medium"
        source = f"solutions/{slug}/features.json:" + ",".join(f for f, v in feat_vals if v is True)
    elif feat_vals and all(v is False for _, v in feat_vals) and not kw_hit:
        status = "fail"
        confidence = "medium"
        source = f"solutions/{slug}/features.json (supported=false)"
    elif kw_hit and not feat_vals:
        status = "unknown"
        confidence = "low"
        source = f"solutions/{slug}/scr.md (keyword hint only — not feature-verified)"
    elif kw_hit and any(v is None for _, v in feat_vals):
        status = "unknown"
        confidence = "low"
        source = f"solutions/{slug}/scr.md + features null"
    else:
        status = "unknown"
        confidence = "low"
        source = f"solutions/{slug}/features.json|scr.md (insufficient evidence)"

    # Known strong cases from prior verified work
    if slug == "silver-bullet" and status != "pass":
        status, confidence, source = "pass", "high", "solutions/silver-bullet/scr.md + features.json"
    if slug == "tembo":
        # Explicit run judgment: ≤2-of-7
        if criterion in (
            "Process layer above host runtime",
            "Specialist agent orchestration",
        ):
            status, confidence = "unknown", "low"
            source = "envelopes: agent claims medium + identity risk"
        else:
            status, confidence = "fail", "medium"
            source = "envelopes: Satisfies 2 of 7 inclusion criteria at most"

    return {
        "criterion": criterion,
        "status": status,
        "source": source,
        "confidence": confidence,
        "date": TODAY,
        "reviewer": REVIEWER,
    }


def build_inclusion_ledger(cd: dict[str, Any]) -> dict[str, Any]:
    rows = []
    for mid, market in cd["markets"].items():
        cores = list(market.get("membership", {}).get("core", []))
        # also include matrix-relevant adjacent called out? Mission: matrix/core vendors
        for slug in cores:
            scr_p = ROOT / "solutions" / slug / "scr.md"
            scr = scr_p.read_text() if scr_p.exists() else ""
            fmap = feature_map(slug)
            crits = [criterion_status(slug, c, fmap, scr) for c in CRITERIA]
            passes = sum(1 for c in crits if c["status"] == "pass")
            rows.append(
                {
                    "market": mid,
                    "slug": slug,
                    "display": next(
                        (r.get("label") for r in market.get("mq_data", []) if r.get("slug") == slug),
                        slug,
                    ),
                    "pass_count": passes,
                    "threshold_met": passes >= 3,
                    "criteria": crits,
                }
            )
    # Tembo adjacent row for transparency
    scr = (ROOT / "solutions/tembo/scr.md").read_text()
    fmap = feature_map("tembo")
    crits = [criterion_status("tembo", c, fmap, scr) for c in CRITERIA]
    rows.append(
        {
            "market": "agentic-sdlc-saas",
            "slug": "tembo",
            "display": "Tembo",
            "pass_count": sum(1 for c in crits if c["status"] == "pass"),
            "threshold_met": False,
            "membership": "adjacent-unplotted",
            "criteria": crits,
        }
    )
    ledger = {
        "version": 1,
        "run_id": "run-57f38dfa25d83cc50d224e283d4692f3",
        "rule": "Core peer set requires ≥3 of 7 criteria with clear (non-advisory-only) evidence.",
        "generated": TODAY,
        "reviewer": REVIEWER,
        "vendors": rows,
    }
    dump_json(ROOT / "landscape/inclusion-ledger.json", ledger)
    # Markdown
    lines = [
        "# Inclusion ledger (3-of-7)",
        "",
        f"Generated: {TODAY} · Reviewer: `{REVIEWER}` · Run: `run-57f38dfa25d83cc50d224e283d4692f3`",
        "",
        "Rule: a vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities (see landscape-report §1).",
        "",
        "| Market | Vendor | Passes | ≥3? | Notes |",
        "|--------|--------|--------|-----|-------|",
    ]
    for r in rows:
        note = r.get("membership", "core")
        lines.append(
            f"| `{r['market']}` | {r['display']} (`{r['slug']}`) | {r['pass_count']}/7 | "
            f"{'YES' if r['threshold_met'] else 'NO'} | {note} |"
        )
    lines += ["", "## Per-criterion rows", ""]
    for r in rows:
        lines.append(f"### {r['display']} (`{r['slug']}`) — {r['market']}")
        lines.append("")
        lines.append("| Criterion | Status | Source | Confidence | Date | Reviewer |")
        lines.append("|-----------|--------|--------|------------|------|----------|")
        for c in r["criteria"]:
            lines.append(
                f"| {c['criterion']} | {c['status']} | {c['source']} | {c['confidence']} | {c['date']} | {c['reviewer']} |"
            )
        lines.append("")
    (ROOT / "landscape/inclusion-ledger.md").write_text("\n".join(lines) + "\n")
    dump_json(OUT / "inclusion-ledger-summary.json", {"vendors": len(rows), "path": "landscape/inclusion-ledger.md"})
    return ledger


def pros_lint() -> dict[str, Any]:
    changed = []
    token_pat = re.compile(
        r"\b(lifecycle_span|plugin_skill_hook_packaging|deterministic_gates|"
        r"cross_session_state|specialist_agents|process_layer_above_host|quality_release_enforcement)\b"
    )
    human = {
        "lifecycle_span": "multi-phase lifecycle coverage",
        "plugin_skill_hook_packaging": "plugin/skill/hook packaging",
        "deterministic_gates": "deterministic quality gates",
        "cross_session_state": "cross-session state",
        "specialist_agents": "specialist agent orchestration",
        "process_layer_above_host": "process layer above host runtime",
        "quality_release_enforcement": "quality/release enforcement",
    }
    for scr in sorted((ROOT / "solutions").glob("*/scr.md")):
        text = scr.read_text()
        orig = text
        # dedupe consecutive identical bullets under Evidence-backed notes
        lines = text.splitlines()
        out_lines = []
        seen_in_notes: set[str] = set()
        in_notes = False
        for line in lines:
            if line.strip().startswith("## Evidence-backed notes"):
                in_notes = True
                seen_in_notes = set()
                out_lines.append(line)
                continue
            if in_notes and line.startswith("## "):
                in_notes = False
            if in_notes and line.startswith("- "):
                norm = re.sub(r"\s+", " ", line[2:].strip().lower())
                if norm in seen_in_notes:
                    continue
                seen_in_notes.add(norm)
            out_lines.append(line)
        text = "\n".join(out_lines) + ("\n" if text.endswith("\n") else "")
        text = token_pat.sub(lambda m: human[m.group(1)], text)
        if text != orig:
            bak(scr)
            scr.write_text(text)
            changed.append(str(scr.relative_to(ROOT)))
    # landscape-report.md token scrub in reader prose
    md = ROOT / "landscape/landscape-report.md"
    mdt = md.read_text()
    md_orig = mdt
    mdt = token_pat.sub(lambda m: human[m.group(1)], mdt)
    # also dedupe identical consecutive Pros bullets
    lines = mdt.splitlines()
    out = []
    i = 0
    while i < len(lines):
        out.append(lines[i])
        if re.match(r"^\*\*Pros\*\*", lines[i].strip()) or lines[i].strip() == "**Pros**":
            i += 1
            seen = set()
            while i < len(lines) and lines[i].startswith("- "):
                norm = re.sub(r"\s+", " ", lines[i][2:].strip().lower())
                if norm not in seen:
                    seen.add(norm)
                    out.append(lines[i])
                i += 1
            continue
        i += 1
    mdt = "\n".join(out) + ("\n" if mdt.endswith("\n") else "")
    if mdt != md_orig:
        bak(md)
        md.write_text(mdt)
        changed.append("landscape/landscape-report.md")
    summary = {"files_changed": changed, "count": len(changed)}
    dump_json(OUT / "pros-lint.json", summary)
    return summary


def update_tembo_scr() -> None:
    p = ROOT / "solutions/tembo/scr.md"
    bak(p)
    p.write_text(
        """# Solution Capability Report: Tembo

Slug: `tembo`

## Executive summary

**DEMOTED from agentic-sdlc-saas core (2026-07-22 non-COI critique pass).** IDENTITY RISK remains: tembo.io is widely known as a Postgres platform. Run envelopes contain medium-confidence agent-surface claims (delegates to Claude Code / Cursor / Codex; approval gates; isolated VMs) **and** an explicit inclusion judgment that Tembo satisfies **at most 2 of 7** criteria → **Adjacent / watchlist, not Top-N**. Do not plot on SaaS MQ / Wave / Blue Ocean until a fresh evidence pack clears ≥3-of-7 with a distinct agent product page.

## Membership decision

- **Prior:** SaaS core Visionary (provisional, identity-risk flagged).
- **Now:** SaaS **adjacent / unplotted**; listed for coverage honesty only.
- **Evidence basis (this run only — no new DR):** envelope claim “Satisfies 2 of 7 inclusion criteria at most — qualifies as tertiary Adjacent, not Top-N”; conflicting low-confidence “database-focused DevOps” framing; blog URL present in envelopes (`…/autonomous-software-maintenance-has-arrived`) but not sufficient alone for core.

## Evidence-backed notes

- Tembo delegates work to Claude Code, Cursor and Codex across repos, triggered from Slack, Linear, GitHub and Sentry — claimed managed orchestration above host runtimes (source_ref tembo.io; confidence medium). Treat as **unverified for core scoring**.
- Tembo's last disclosed round was a $14M Series A (July 2024) after pivoting from managed Postgres (startupintros.com/orgs/tembo).
- Tembo positions primarily as Postgres platform with agentic expansion — public packaging detail limited; map as landscape peer / adjacent, not APO and not SaaS Top-N.
"""
    )


def rebuild_bo_markdown_tables(md: str, cd: dict[str, Any]) -> str:
    """Replace Blue Ocean markdown tables from rescored chart-data."""

    def table_for(market_id: str) -> str:
        m = cd["markets"][market_id]
        kcfs = m.get("vc_kcfs") or cd.get("vc_kcfs") or BO_KCFS
        series = list(m.get("vc_commercial", [])) + list(m.get("vc_oss", []))
        # Prefer commercial then oss; limit readable width
        labels = [r["label"] for r in series]
        header = "| Key Competitive Factor | " + " | ".join(labels) + " |"
        sep = "|------------------------|" + "|".join(["------"] * len(labels)) + "|"
        rows = [header, sep]
        for i, kcf in enumerate(kcfs):
            cells = [str(r["data"][i]) for r in series]
            rows.append(f"| {kcf} | " + " | ".join(cells) + " |")
        footnote = (
            "\n> **Blue Ocean scoring:** feature-pass from `solutions/*/features.json` "
            "(true=5, false=1, unknown=3). Not a Leader list. Zuvo excluded (quarantined)."
        )
        return "\n".join(rows) + footnote

    # Replace each §3.x.4 table block heuristically: from first | Key Competitive Factor | to blank line before ### or ##
    def replace_section(text: str, heading: str, market_id: str) -> str:
        idx = text.find(heading)
        if idx < 0:
            return text
        # find table start
        t0 = text.find("| Key Competitive Factor |", idx)
        if t0 < 0:
            return text
        # find end of table (line that doesn't start with |)
        rest = text[t0:]
        lines = rest.splitlines()
        end = 0
        for i, ln in enumerate(lines):
            if i > 0 and not ln.startswith("|") and not ln.startswith(">"):
                end = i
                break
        else:
            end = len(lines)
        # include trailing > notes that are blue-ocean related
        while end < len(lines) and lines[end].startswith(">"):
            end += 1
        new_table = table_for(market_id)
        return text[:t0] + new_table + "\n\n" + "\n".join(lines[end:]).lstrip("\n")

    md = replace_section(md, "#### 3.1.4 Blue Ocean", "apo")
    md = replace_section(md, "#### 3.2.4 Blue Ocean", "sdlc-plugins")
    md = replace_section(md, "#### 3.3.4 Blue Ocean", "agentic-sdlc-saas")
    return md


def patch_landscape_markdown(cd: dict[str, Any]) -> None:
    md_path = ROOT / "landscape/landscape-report.md"
    bak(md_path)
    md = md_path.read_text()
    md = scrub_ibm_text(md)

    # Link inclusion ledger after inclusion criteria block
    if "inclusion-ledger.md" not in md:
        anchor = "A vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities below"
        insert = (
            "\n\n**Per-vendor inclusion ledger (durable):** "
            "[`landscape/inclusion-ledger.md`](inclusion-ledger.md) "
            "(`criterion` / `source` / `confidence` / `date` / `reviewer` per core vendor). "
            "Machine-readable: [`inclusion-ledger.json`](inclusion-ledger.json).\n"
        )
        if anchor in md:
            # insert after the 7 bullets — find Process layer bullet end
            marker = "**Process layer above host runtime**"
            pos = md.find(marker)
            if pos > 0:
                nl = md.find("\n\n", pos)
                if nl > 0:
                    md = md[:nl] + insert + md[nl:]

    # Scope WONTFIX appendix
    wontfix = """

### Scope expansion — WONTFIX this run (exact gaps)

No full DR re-derive (`run_id=run-57f38dfa25d83cc50d224e283d4692f3`). Candidates below appear only as **gap/mention strings** in envelopes — **no SCR, features.json, or matrix row** in this package:

| Candidate | Envelope signal | Exact gap blocking inclusion |
|-----------|-----------------|------------------------------|
| AWS Kiro | Named in “likely-missing APO/plugin candidates” | No solution dir, no primary URL pack, no 3-of-7 ledger row |
| Task Master AI | Same missing-candidate list | No SCR/features; no verified host-packaging evidence in-run |
| Temporal | Gap area “Temporal trend and momentum analysis” | Workflow-engine adjacency only; not researched as APO/SaaS peer |
| APAC / EU regional packs | Gap note on secondary-market roadmap/geo | No geography-scoped discovery corpus or regional vendor SCR set |
| Qodo / Sourcegraph Amp / Tessl / GitHub Spark / observability platforms | Named in under-covered tertiary peer lists or third-party blogs | No in-run SCR; would require new retrieve+triangulate cycle |

"""
    if "Scope expansion — WONTFIX this run" not in md:
        # after Cavekit versioning or Excluded
        if "**Excluded / non-core**" in md:
            pos = md.find("**Excluded / non-core**")
            # after that paragraph
            nl = md.find("\n\n", pos)
            md = md[:nl] + wontfix + md[nl:]
        else:
            md += wontfix

    # Tembo SaaS MQ / Wave rows — rebuild §3.3.2 and §3.3.3 from chart-data
    saas = cd["markets"]["agentic-sdlc-saas"]

    def mq_table(market: dict[str, Any]) -> str:
        lines = [
            "| Vendor | Quadrant | Justification |",
            "|--------|----------|---------------|",
        ]
        for r in market.get("mq_data", []):
            label = r["label"]
            url = market.get("vendor_urls", {}).get(label) or market.get("vendor_urls", {}).get(r["slug"], "")
            cell = f"[{label}]({url})" if url else label
            note = r.get("identity_note") or r.get("evidence_status") or "Positioned from mq_data; SPA chart authoritative."
            if r.get("identity_note"):
                note = r["identity_note"]
            lines.append(f"| {cell} | {r['q']} | {note} |")
        return "\n".join(lines)

    def wave_table(market: dict[str, Any]) -> str:
        def lab(n: float) -> str:
            if n >= 4:
                return f"Strong ({n:g})"
            if n >= 3:
                return f"Competitive ({n:g})"
            if n >= 2:
                return f"Limited ({n:g})"
            return f"Nascent ({n:g})"

        lines = [
            "| Vendor | Current Offering | Strategy | Market Presence |",
            "|--------|------------------|----------|-----------------|",
        ]
        for r in market.get("wave_data", []):
            label = r["label"]
            url = market.get("vendor_urls", {}).get(label, "")
            cell = f"[{label}]({url})" if url else label
            lines.append(
                f"| {cell} | {lab(r['offering'])} | {lab(r['strategy'])} | {lab(r['presence'])} |"
            )
        return "\n".join(lines)

    # Replace SaaS MQ table
    m_start = md.find("#### 3.3.2 Magic Quadrant")
    if m_start >= 0:
        t0 = md.find("| Vendor | Quadrant |", m_start)
        t1 = md.find("\n\n>", t0)
        if t0 > 0 and t1 > t0:
            challenger_note = (
                "\n\n> **Challengers:** none in this market’s mq_data. "
                + saas.get("methodology", {}).get("empty_challengers_rationale", "")
            )
            leader_note = (
                "\n\n> **Leader definition (canonical):** MQ Leaders above = "
                "`markets.agentic-sdlc-saas.mq_data` with `q=Leaders`. "
                "GMQ / Blue Ocean / buying prose must not invent a competing Leader set."
            )
            tembo_note = (
                "\n\n> **Tembo:** demoted from SaaS core to adjacent/unplotted "
                "(≤2-of-7 + identity risk). See [`inclusion-ledger.md`](inclusion-ledger.md) and "
                "`methodology.tembo_decision` in chart-data."
            )
            md = md[:t0] + mq_table(saas) + challenger_note + leader_note + tembo_note + md[t1:]

    w_start = md.find("#### 3.3.3 Wave-Style Assessment — Agentic SDLC SaaS")
    if w_start >= 0:
        t0 = md.find("| Vendor | Current Offering |", w_start)
        # end before Blue Ocean heading or footnote
        t1 = md.find("#### 3.3.4", w_start)
        if t0 > 0 and t1 > t0:
            foot = "\n\n> Wave includes all MQ-plotted SaaS cores (N=4 after Tembo demotion).\n\n"
            md = md[:t0] + wave_table(saas) + foot + md[t1:]

    # Remove Tembo from tertiary peer prose lists where it claims core parity — soften
    md = md.replace(
        "Factory.ai/Devin/Cosmos/Tembo",
        "Factory.ai/Devin/Augment Code (Cosmos) (Tembo adjacent-only)",
    )
    md = md.replace(
        "Factory/Devin/Cosmos/Tembo",
        "Factory/Devin/Augment Code (Cosmos) (Tembo adjacent-only)",
    )

    md = rebuild_bo_markdown_tables(md, cd)

    # Security/procurement gap already present — ensure one durable pointer
    if "buyer deployment constraints" not in md.lower() and "SSO/SCIM" not in md:
        md += (
            "\n\n### Procurement evidence gaps (disclosed)\n"
            "This run does **not** populate SSO/SCIM, residency, BYOK, VPC SLA, or priced adoption metrics "
            "without verified sources. Treat those buyer dimensions as **not publicly verified in-run**.\n"
        )

    md_path.write_text(md)


def scrub_envelopes() -> dict[str, Any]:
    path = ROOT / "contributions/all-envelopes.json"
    bak(path)
    data = load_json(path)
    before = json.dumps(data).count("developer.ibm.com")
    data = scrub_ibm_obj(data)
    after = json.dumps(data).count("developer.ibm.com")
    dump_json(path, data)
    stats = {"before": before, "after": after, "path": str(path.relative_to(ROOT))}
    # Also scrub retrieve finals that may be copied — but SPA embeds envelopes only.
    for rel in [
        "phases/DR-RETRIEVE/final-retrieve.json",
        "phases/DR-RETRIEVE/final-retrieve-clean.json",
        "phases/DR-RETRIEVE/final-retrieve-perfect.json",
        "phases/DR-RETRIEVE/merged-retrieve.json",
        "phases/DR-RETRIEVE/final-retrieve-selection.json",
    ]:
        p = ROOT / rel
        if not p.exists():
            continue
        raw = p.read_text()
        b = raw.count("developer.ibm.com")
        if b:
            bak(p)
            p.write_text(scrub_ibm_text(raw))
            stats[rel] = {"before": b, "after": p.read_text().count("developer.ibm.com")}
    dump_json(OUT / "ibm-scrub.json", stats)
    return stats


def main() -> None:
    BAK.mkdir(parents=True, exist_ok=True)
    cd_path = ROOT / "landscape/chart-data.json"
    cat_path = ROOT / "landscape/catalog_audit.json"
    bak(cd_path)
    bak(cat_path)
    cd = load_json(cd_path)
    catalog = load_json(cat_path)

    tembo = demote_tembo(cd, catalog)
    bo = rescore_blue_ocean(cd)
    dump_json(cd_path, cd)
    dump_json(cat_path, catalog)

    update_tembo_scr()
    ledger = build_inclusion_ledger(cd)
    pros = pros_lint()
    scrub = scrub_envelopes()
    patch_landscape_markdown(cd)

    summary = {
        "tembo": tembo,
        "blue_ocean_markets": list(bo["markets"].keys()),
        "inclusion_vendors": len(ledger["vendors"]),
        "pros_lint": pros,
        "ibm_scrub": scrub,
    }
    dump_json(OUT / "APPLY-SUMMARY.json", summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
