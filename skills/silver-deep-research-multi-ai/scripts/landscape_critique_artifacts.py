#!/usr/bin/env python3
"""Page-grounded critique artifacts embedded in landscape-report.md.

Executive summary, inclusion-ledger table, coverage matrix, and consensus
resolution table. Does not re-derive a research run_id.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Inclusion-ledger criteria and legend are category data (pack overlay vocabulary); without a
# pack there is no ledger.
INCLUSION_CRITERIA_ORDER: tuple[str, ...] = ()
INCLUSION_CRITERIA_ABBR: tuple[str, ...] = ()
LEDGER: dict[str, str] = {}

_STATUS_CELL = {"pass": "P", "fail": "F", "unknown": "U"}

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
    slugs: set[str] = set()
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
    if slug in _market_core(audit, market):
        return "included-core"
    if slug in _market_adjacent(audit, market):
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


def _market_blocks(
    pack: dict[str, Any] | None,
    audit: dict[str, Any] | None,
) -> list[tuple[str, str, str]]:
    """(market id, display name, role) for each market of the pack, else of the audit."""
    out: list[tuple[str, str, str]] = []
    for market in (pack or {}).get("markets") or []:
        if isinstance(market, dict) and market.get("id"):
            mid = str(market["id"])
            out.append((mid, str(market.get("display_name") or mid), str(market.get("role") or "")))
    if not out:
        out = [(str(mid), str(mid), "") for mid in ((audit or {}).get("markets") or {})]
    return out


def executive_summary_lines(
    *,
    chart: dict[str, Any] | None,
    pack: dict[str, Any] | None,
    known: dict[str, str],
    audit: dict[str, Any] | None,
) -> list[str]:
    from category_pack import pack_overlay

    overlay = pack_overlay(pack)
    markets = _market_blocks(pack, audit)
    lines = [
        "## Executive Summary",
        "",
        "One-page briefing for buyers. Charts and vendor cards follow; this page does not "
        "restate coordinate formulas.",
        "",
        "### Market overview",
        "",
    ]
    if overlay.get("market_overview"):
        lines.append(str(overlay["market_overview"]))
    elif markets:
        names = ", ".join(f"**{name}**" for _mid, name, _role in markets)
        lines.append(
            f"This report scores {len(markets)} market(s) separately: {names}. Shortlist by "
            "market rather than from a single blended ranking."
        )
    else:
        lines.append("No market definition was available for this run; see the sections below.")
    lines.extend(["", "### Key findings", ""])
    findings = [str(x) for x in overlay.get("key_findings") or []]
    for mid, name, _role in markets:
        core = sorted(_market_core(audit, mid))
        findings.append(
            f"{name}: {len(core)} core vendor(s) with evidence in this run"
            + (f" ({', '.join(known.get(s, s) for s in core[:8])})." if core else ".")
        )
    findings.append("This report does not call any vendor 'most complete'.")
    lines.extend(f"- {item}" for item in findings)
    lines.extend(["", "### Leader shortlist (per market)", ""])
    for mid, name, _role in markets:
        leaders = _leader_labels(chart, mid)
        lines.append(
            f"- **{name}:** {', '.join(leaders) if leaders else 'no vendor met the Leader criteria in this run'}"
        )
    lines.extend(
        [
            "",
            "Leader plots are MQ top-right in this run and follow from the evidenced features "
            "and the inclusion ledger, not from a 'most complete product' claim. They are not a "
            "mandate to buy one vendor across every profile.",
            "",
        ]
    )
    return lines


def _membership_sentence(
    pack: dict[str, Any] | None,
    audit: dict[str, Any] | None,
    known: dict[str, str],
) -> str:
    parts: list[str] = []
    for mid, name, _role in _market_blocks(pack, audit):
        core = sorted(_market_core(audit, mid))
        parts.append(
            f"{name} core ({len(core)}): " + (", ".join(known.get(s, s) for s in core) or "none")
        )
    return "; ".join(parts) + ". A vendor may be core in more than one market."


def inclusion_ledger_embed_lines(
    *,
    root: Path | None,
    audit: dict[str, Any] | None,
    pack: dict[str, Any] | None,
    known: dict[str, str],
) -> list[str]:
    if not INCLUSION_CRITERIA_ORDER:
        return []  # the inclusion ledger is a category-pack feature
    payload = load_inclusion_ledger(root)
    vendors = [v for v in (payload.get("vendors") or []) if isinstance(v, dict)]
    lines = [
        "### Vendor inclusion ledger",
        "",
        LEDGER.get("legend")
        or "Cells: **P** pass / **F** fail / **U** unknown. Full per-criterion notes: "
        "`landscape/inclusion-ledger.md`.",
        "",
        "**Membership must match charts.** "
        + _membership_sentence(pack, audit, known),
        "",
        "| Vendor | Market | "
        + " | ".join(INCLUSION_CRITERIA_ABBR)
        + " | Evidence cite | Final decision |",
        "|" + "---|" * (len(INCLUSION_CRITERIA_ABBR) + 4),
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
        line = _row(vendor, str(decision))
        if str(decision) == "hard-excluded":
            excluded_rows.append(line)
        elif str(decision).startswith("adjacent"):
            adjacent_rows.append(line)
        elif str(decision) == "included-core":
            core_rows.append(line)

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
    from category_pack import pack_overlay

    gap_notes = {
        str(k): str(v) for k, v in (pack_overlay(pack).get("vendor_gap_notes") or {}).items()
    }
    extra = [(slug, "hard-excluded", "hard-excluded") for slug in sorted(_hard_exclusion_slugs(pack))]
    for slug, mid, place in extra:
        if (slug, mid) not in seen:
            rows.append((slug, mid, place))
            seen.add((slug, mid))

    if not rows:
        return []
    lines = [
        "### Coverage completeness matrix",
        "",
        "Whether this run has **evidence files**, a **comparison-matrix score**, and a "
        "**market placement** — separate from ledger inclusion. Gaps are why a vendor "
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
        gaps: list[str] = []
        if slug in gap_notes:
            gaps.append(gap_notes[slug])
        if slug not in ranked and placement == "included-core":
            gaps.append("core without ranking row")
        if evidence.startswith("missing"):
            gaps.append("no solution artifacts")
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
    pack: dict[str, Any] | None = None,
) -> list[str]:
    """One row per disputed claim, attributed to the models that actually said it.

    Pack-authored analyst calls (overlay ``resolution_notes``, keyed by subject) supply the
    decision text; otherwise the dispute is reported as unresolved. The supporting and
    contradicting columns always come from this run's divergence data.
    """
    from category_pack import pack_overlay

    notes = {
        str(n["subject"]): n
        for n in pack_overlay(pack).get("resolution_notes") or []
        if isinstance(n, dict) and n.get("subject")
    }
    lines = [
        "### Consensus Resolution Table",
        "",
        "Disputed claims and how this report treats them. The model columns are taken from "
        "this run's divergence data; envelope quotes of disagreement belong in this table "
        "only — they are not seed lists, comparison columns, or Top Commercial membership.",
        "",
        "| Claim | Supporting models | Contradicting models | Final analyst decision | Evidence |",
        "|-------|-------------------|----------------------|------------------------|----------|",
    ]
    for item in notable or []:
        if not isinstance(item, dict) or not item.get("subject"):
            continue
        subject = str(item["subject"])
        supporting, contradicting = _sides_by_stance(item)
        note = notes.get(subject) or {}
        claim = str(note.get("claim") or item.get("claim") or item.get("topic") or subject)
        decision = str(
            note.get("decision")
            or "Unresolved: the models disagree and this tool does not adjudicate. "
            "Weigh the cited evidence before relying on either side."
        )
        evidence = str(note.get("evidence") or "See the divergence entry and its cited envelopes.")
        lines.append(f"| {claim} | {supporting} | {contradicting} | {decision} | {evidence} |")
    lines.append("")
    return lines


def patch_inclusion_ledger(
    root: Path,
    *,
    pack: dict[str, Any] | None,
    audit: dict[str, Any] | None,
    preserved: list[str] | None = None,
) -> dict[str, Any]:
    """Re-derive final decisions in inclusion-ledger.json from the pack; keep its run_id."""
    path = root / "landscape" / "inclusion-ledger.json"
    payload = load_inclusion_ledger(root)
    if not payload:
        payload = {"version": 1, "rule": "3-of-7", "vendors": []}
    payload["reviewer"] = "act-on-critique-artifacts"
    vendors = [v for v in (payload.get("vendors") or []) if isinstance(v, dict)]
    patched: list[dict[str, Any]] = []
    for vendor in vendors:
        slug = str(vendor.get("slug") or "")
        market = str(vendor.get("market") or "")
        homes = _home_core_markets(slug, audit)
        if slug in _hard_exclusion_slugs(pack):
            vendor = dict(vendor)
            vendor["final_decision"] = "hard-excluded"
            vendor["threshold_met"] = False
            vendor["placement"] = "hard-excluded"
        else:
            vendor = dict(vendor)
            if homes and market not in homes:
                vendor["market"] = homes[0]
                market = homes[0]
            vendor["final_decision"] = vendor_final_decision(
                slug, market, audit=audit, pack=pack
            )
        patched.append(vendor)
    payload["vendors"] = patched
    from generated_files import write_generated_text

    write_generated_text(root, path, json.dumps(payload, indent=2) + "\n", preserved=preserved)
    _write_inclusion_ledger_markdown(root, payload, pack=pack, audit=audit, preserved=preserved)
    return payload


def _write_inclusion_ledger_markdown(
    root: Path,
    payload: dict[str, Any],
    *,
    pack: dict[str, Any] | None,
    audit: dict[str, Any] | None,
    preserved: list[str] | None = None,
) -> None:
    lines = [
        "# Inclusion ledger (3-of-7)",
        "",
        f"Generated: {datetime.now(timezone.utc).date().isoformat()} · Reviewer: "
        f"`act-on-critique-artifacts` · Run: `{payload.get('run_id') or 'unknown'}` (not re-derived)",
        "",
        "Compact decision table (P/F/U). Pack hard-exclusions override proxy ticks that "
        "meet 3-of-7.",
        "",
        "| Vendor | Market | "
        + " | ".join(INCLUSION_CRITERIA_ABBR)
        + " | Evidence cite | Final decision |",
        "|" + "---|" * (len(INCLUSION_CRITERIA_ABBR) + 4),
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
    from generated_files import write_generated_text

    md_path = root / "landscape" / "inclusion-ledger.md"
    write_generated_text(root, md_path, "\n".join(lines).rstrip() + "\n", preserved=preserved)
