#!/usr/bin/env python3
"""Content-quality gate for solution-landscape packaging."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from category_pack import (
    build_known_solutions,
    get_hard_exclusion_slugs,
    get_must_research_slugs,
    get_sunset_registry,
    resolve_canonical_slug,
    resolve_pack_from_need,
)
from compression_markers import contains_compression_markers, find_compression_marker_snippets

_MUST_HAVE_ALIASES: dict[str, list[str]] = {
    "workflow composition": ["Workflow composition"],
    "multi-agent orchestration": ["Parent/child agent delegation", "Workflow composition"],
    "verification gates": ["Hook-enforced gates", "Automated review loops", "CI integration"],
    "cross-session state": ["Workflow composition"],
    "process layer above host runtime": ["Workflow composition", "IDE-native integration"],
}


def _load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else None


def _resolve_must_have_features(must_have: str) -> list[str]:
    key = must_have.lower().strip()
    if key in _MUST_HAVE_ALIASES:
        return _MUST_HAVE_ALIASES[key]
    title = " ".join(word.capitalize() for word in key.split())
    return [title]


def _critical_fill_rate(comparison: dict[str, Any]) -> tuple[float, int, int, float]:
    rows = comparison.get("rows") or []
    filled = 0
    total = 0
    active_row_rates: list[float] = []
    for row in rows:
        if not isinstance(row, dict) or row.get("type") != "feature":
            continue
        if row.get("priority") != "Critical":
            continue
        solutions = row.get("solutions") or {}
        row_filled = sum(1 for value in solutions.values() if value)
        row_total = len(solutions)
        total += row_total
        filled += row_filled
        if row_filled >= 2 and row_total:
            active_row_rates.append(row_filled / row_total)
    rate = (filled / total) if total else 0.0
    active_mean = (
        sum(active_row_rates) / len(active_row_rates) if active_row_rates else 0.0
    )
    return rate, filled, total, active_mean


def _winner_must_have_coverage(
    comparison: dict[str, Any],
    need: dict[str, Any],
) -> list[str]:
    gaps: list[str] = []
    winner = comparison.get("winner")
    if not winner:
        return ["no winner in comparison.json"]

    must_haves = need.get("must_haves") or []
    if not must_haves:
        return gaps

    feature_rows: dict[str, dict[str, Any]] = {}
    for row in comparison.get("rows") or []:
        if isinstance(row, dict) and row.get("type") == "feature" and row.get("name"):
            feature_rows[str(row["name"])] = row

    for must_have in must_haves:
        candidates = _resolve_must_have_features(str(must_have))
        covered = False
        for feature in candidates:
            row = feature_rows.get(feature)
            if not row:
                continue
            if (row.get("solutions") or {}).get(winner):
                covered = True
                break
        if not covered:
            gaps.append(f"winner {winner!r} lacks must-have {must_have!r}")
    return gaps


def _slug_display_map(comparison: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for item in comparison.get("rankings") or []:
        if isinstance(item, dict) and item.get("solution"):
            sol = str(item["solution"])
            mapping[sol] = sol
            mapping[re.sub(r"[^a-z0-9]+", "-", sol.lower()).strip("-")] = sol
    return mapping


def _collect_topn_slugs(comparison: dict[str, Any], chart: dict[str, Any] | None) -> set[str]:
    slugs: set[str] = set()
    for item in comparison.get("rankings") or []:
        if isinstance(item, dict) and item.get("solution"):
            slugs.add(str(item["solution"]))
    if chart:
        label_to_slug = {v: k for k, v in _slug_display_map(comparison).items()}
        for key in ("mq_data", "gmq_data", "wave_data"):
            for point in chart.get(key) or []:
                if isinstance(point, dict) and point.get("label"):
                    label = str(point["label"])
                    for slug, display in label_to_slug.items():
                        if display == label or slug == label:
                            slugs.add(slug)
    return slugs


def _check_catalog_audit_gates(
    research_dir: Path,
    need: dict[str, Any],
    comparison: dict[str, Any],
    chart: dict[str, Any] | None,
    md_text: str,
    errors: list[str],
    metrics: dict[str, Any],
) -> None:
    pack = resolve_pack_from_need(need)
    if not pack:
        return

    audit_path = research_dir / "landscape" / "catalog_audit.json"
    audit = _load_json(audit_path) if audit_path.is_file() else None
    if not audit:
        errors.append("landscape/catalog_audit.json missing (required when category_pack_id is set)")
        return

    metrics["catalog_audit"] = audit.get("counts", {})
    hard_exclusions = get_hard_exclusion_slugs(pack, need) if pack else set()
    sunset_slugs = {str(e["slug"]) for e in get_sunset_registry(pack)} if pack else set()
    forbidden = hard_exclusions | sunset_slugs
    topn = _collect_topn_slugs(comparison, chart)

    all_market_cores: set[str] = set()
    for ma in (audit.get("markets") or {}).values():
        if isinstance(ma, dict):
            all_market_cores.update(ma.get("core") or [])
    if not all_market_cores:
        all_market_cores.update(audit.get("matrix_slugs") or audit.get("core") or [])

    adjacent_set = set(audit.get("adjacent") or [])
    overlap = sorted(adjacent_set & all_market_cores)
    if overlap:
        errors.append(
            "adjacent list overlaps market cores (must be empty): " + ", ".join(overlap)
        )

    for slug in forbidden & topn:
        errors.append(f"forbidden slug {slug!r} in Top-N rankings or charts")

    dedupe_rules = pack.get("parent_child_dedupe") or []
    md_lower = md_text.lower()
    section5_match = re.search(r"^##\s+5\.\s+", md_text, re.M)
    adjacent_match = re.search(r"^##\s+\d+\.\s+Adjacent Markets", md_text, re.M)
    section5_start = section5_match.start() if section5_match else md_text.find("## 5.")
    section_adjacent = adjacent_match.start() if adjacent_match else md_text.find("## 7. Adjacent")
    core_block = md_text[section5_start:section_adjacent] if section_adjacent > 0 else md_text[section5_start:]
    core_h3_names = {
        m.group(1).strip().lower()
        for m in re.finditer(r"^###\s+(.+?)\s*$", core_block, re.M)
    }
    names = build_known_solutions(pack)

    def _normalize_h3_title(h3: str) -> str:
        return re.sub(r"\s*\([^)]*\)\s*$", "", h3).strip().lower()

    def _listed_in_core(slug: str) -> bool:
        display = names.get(slug, slug.replace("-", " ")).strip().lower()
        slug_norm = slug.replace("-", " ")
        for h3 in core_h3_names:
            title = _normalize_h3_title(h3)
            if title == display or title == slug_norm:
                return True
        return False

    for rule in dedupe_rules:
        parent = resolve_canonical_slug(str(rule.get("parent_slug", "")), pack)
        child = resolve_canonical_slug(str(rule.get("prefer_slug", "")), pack)
        if not parent or not child or parent == child:
            continue
        if _listed_in_core(parent) and _listed_in_core(child):
            errors.append(f"parent+child dual listing in core sections: {parent} + {child}")

    must_research = get_must_research_slugs(pack, need)
    gaps_file = research_dir / "coverage_gaps.json"
    gaps_ack = gaps_file.is_file()
    audit_gaps = audit.get("gaps") or []
    if audit_gaps and not gaps_ack:
        errors.append(
            f"must_research gaps {audit_gaps!r} without coverage_gaps.json acknowledgment"
        )

    if pack.get("category_id") == "agentic-sdlc-process-orchestrator":
        exclusion_markers = (
            "coding agent",
            "host runtime",
            "out of scope",
            "excluded from core",
        )
        if not any(m in md_lower for m in exclusion_markers):
            errors.append(
                "Market Definition lacks exclusion language for coding agents / host runtimes (APO pack)"
            )

    max_core = int(pack.get("max_core_count") or 25)
    primary_id = str(audit.get("primary_market_id") or pack.get("primary_market_id") or "apo")
    primary_core = (audit.get("markets") or {}).get(primary_id, {}).get("core") or audit.get("core") or []
    core_count = len(primary_core)
    if core_count > max_core:
        errors.append(f"primary market core count {core_count} exceeds pack max_core_count {max_core}")

    if "augment-code" in topn and "augment-cosmos" not in topn:
        errors.append("augment-code in Top-N without augment-cosmos rename per pack policy")

    if re.search(r"\baugment[- ]code\b", md_text, re.I) and not re.search(r"\baugment[- ]cosmos\b", md_text, re.I):
        if "augment-code" in (audit.get("core") or []):
            errors.append("augment-code present in core without Cosmos rename")


def validate_landscape_content(
    research_dir: Path,
    *,
    min_critical_fill_rate: float = 0.35,
) -> dict[str, Any]:
    research_dir = Path(research_dir)
    comparison = _load_json(research_dir / "comparison" / "comparison.json")
    need = _load_json(research_dir / "need_profile.json") or {}

    errors: list[str] = []
    metrics: dict[str, Any] = {}

    if not comparison:
        return {
            "status": "fail",
            "errors": ["comparison/comparison.json missing or invalid"],
            "metrics": metrics,
        }

    fill_rate, filled, total, active_mean = _critical_fill_rate(comparison)
    metrics["critical_fill_rate"] = round(fill_rate, 4)
    metrics["critical_active_row_mean_fill"] = round(active_mean, 4)
    metrics["critical_filled_cells"] = filled
    metrics["critical_total_cells"] = total
    if total == 0:
        errors.append("no Critical feature rows in comparison matrix")
    elif fill_rate < 0.10:
        errors.append(f"Critical matrix fill rate {fill_rate:.1%} indicates hollow report (<10%)")
    elif active_mean < min_critical_fill_rate and fill_rate < min_critical_fill_rate:
        errors.append(
            f"Critical matrix fill rate {fill_rate:.1%} and active-row mean {active_mean:.1%} "
            f"both below minimum {min_critical_fill_rate:.0%}"
        )

    must_have_gaps = _winner_must_have_coverage(comparison, need)
    metrics["must_have_gaps"] = must_have_gaps
    errors.extend(must_have_gaps)

    winner = comparison.get("winner")
    rankings = comparison.get("rankings") or []
    winner_score = None
    for item in rankings:
        if isinstance(item, dict) and item.get("solution") == winner:
            winner_score = item.get("score")
            break
    metrics["winner"] = winner
    metrics["winner_score"] = winner_score

    # Narrative consistency: silver-bullet should not be score 0 when matrix claims support
    sb = next((r for r in rankings if isinstance(r, dict) and r.get("solution") == "silver-bullet"), None)
    if sb and sb.get("score") == 0 and fill_rate > 0.1:
        errors.append("silver-bullet score is 0 despite non-trivial matrix fill (ranking inconsistency)")

    landscape_md = research_dir / "landscape" / "landscape-report.md"
    chart_data_path = research_dir / "landscape" / "chart-data.json"
    chart_raw: dict[str, Any] | None = None
    md_text = ""
    if landscape_md.is_file():
        md_text = landscape_md.read_text(encoding="utf-8")
        if contains_compression_markers(md_text):
            samples = find_compression_marker_snippets(md_text)
            errors.append(
                "landscape-report.md contains compression markers: "
                + "; ".join(samples or ["(marker detected)"])
            )
        for section in (
            "Market Definition & Scope",
            "Market Overview",
            "Competitive Positioning",
            "Key Industry Trends",
            "Top Commercial Solutions",
            "Top Open Source Solutions",
            "Buying Guidance",
            "Future Outlook",
            "Source Reliability Assessment",
        ):
            if section not in md_text:
                errors.append(f"landscape-report.md missing section: {section}")
        metrics["landscape_report_bytes"] = len(md_text.encode("utf-8"))
        if need.get("category_pack_id") and "Adjacent Markets" not in md_text:
            errors.append("landscape-report.md missing Adjacent Markets section (pack active)")
        if need.get("category_pack_id") and "Explicitly Excluded" not in md_text:
            errors.append("landscape-report.md missing Explicitly Excluded section (pack active)")
    else:
        errors.append("landscape/landscape-report.md missing")

    if chart_data_path.is_file():
        chart_raw = _load_json(chart_data_path) or {}
        mq = chart_raw.get("mq_data") or []
        gmq = chart_raw.get("gmq_data") or []
        wave = chart_raw.get("wave_data") or []
        metrics["chart_mq_points"] = len(mq)
        metrics["chart_gmq_points"] = len(gmq)
        metrics["chart_wave_points"] = len(wave)
        if not mq or not wave:
            errors.append("chart-data.json has empty mq_data or wave_data")
        if mq and gmq and json.dumps(mq, sort_keys=True) == json.dumps(gmq, sort_keys=True):
            errors.append("chart-data.json mq_data and gmq_data are identical (3A/3B must differ)")
        titles = chart_raw.get("titles") if isinstance(chart_raw.get("titles"), dict) else {}
        vc_title = str(titles.get("vc") or "")
        if vc_title and "radar" not in vc_title.lower() and "value curve" not in vc_title.lower():
            errors.append("chart-data.json titles.vc missing Value Curve / Radar labeling")
        gmq_leaders = {
            str(p.get("label"))
            for p in gmq
            if isinstance(p, dict) and p.get("q") == "Leaders" and p.get("label")
        }
        mq_leaders = {
            str(p.get("label"))
            for p in mq
            if isinstance(p, dict) and p.get("q") == "Leaders" and p.get("label")
        }
        vc_series = list(chart_raw.get("vc_commercial") or []) + list(chart_raw.get("vc_oss") or [])
        vc_labels = {
            str(s.get("label"))
            for s in vc_series
            if isinstance(s, dict) and s.get("label")
        }
        all_leaders = gmq_leaders | mq_leaders
        missing_vc = sorted(all_leaders - vc_labels)
        if missing_vc:
            errors.append(
                "chart-data.json Value Curve missing MQ leader series: "
                + ", ".join(missing_vc)
            )
        # Durable gate: vendor/homepage URLs must not be 404 / non-OK.
        vendor_urls = chart_raw.get("vendor_urls") if isinstance(chart_raw.get("vendor_urls"), dict) else {}
        if vendor_urls:
            from vendor_link_labels import filter_healthy_vendor_urls

            _kept, dropped = filter_healthy_vendor_urls(
                {str(k): str(v) for k, v in vendor_urls.items()}
            )
            metrics["vendor_url_health_dropped"] = dropped
            if dropped:
                sample = "; ".join(
                    f"{d.get('label')}→{d.get('url')} ({d.get('error') or d.get('status')})"
                    for d in dropped[:8]
                )
                errors.append(
                    f"chart-data.json vendor_urls include dead/non-OK links ({len(dropped)}): {sample}"
                )
    elif manifest := _load_json(research_dir / "run_manifest.json"):
        if manifest.get("research_type") in {"solution-landscape", "solution-compare"}:
            errors.append("landscape/chart-data.json missing")

    if landscape_md.is_file():
        # Overview quality — reject meta-research dumps that leak into solution cards.
        bad_overview = re.compile(
            r"\*\*Overview\*\*:\s*.*(?:"
            r"participates in the agentic|"
            r"Capability profile derived|"
            r"comparison matrix signals|"
            r"Triangulate consolidated|"
            r"Coverage is based on multi-AI|"
            r"Ideal for teams evaluating process layers"
            r")",
            re.I,
        )
        bad_hits = bad_overview.findall(md_text)
        metrics["bad_overview_hits"] = len(bad_hits)
        if bad_hits:
            errors.append(
                f"landscape-report.md has {len(bad_hits)} unusable Overview blurb(s) "
                "(meta-research / matrix dump language)"
            )
        if re.search(r"^Axes:\s*\*\*", md_text, re.M):
            errors.append("landscape-report.md still contains Axes caption under 3A")
        if "### 3A." not in md_text and not re.search(r"^####\s+3\.\d+\.1\s+", md_text, re.M):
            errors.append("landscape-report.md missing ### 3A. / ### 3B. chart headings")

    spa = research_dir / "landscape-report.html"
    if spa.is_file():
        html = spa.read_text(encoding="utf-8")
        metrics["landscape_spa_bytes"] = len(html.encode("utf-8"))
        for marker, label in (
            ("COMPARE_MAX = 10", "compare max 10"),
            ("type: 'radar'", "value-curve radar chart"),
            ("vc-compare-cb", "compare checkboxes"),
            ("border: none; outline: none; background: var(--sb-snav-chip-bg)", "snav chips without outline"),
            ("WAVE_ZONE_FILLS", "wave zone fills"),
            ("font-size: 1.875rem", "H1 rem hierarchy"),
            ("_scrollToVendorCard", "chart-to-card navigation"),
            ("compareResultsSection", "bottom compare section"),
        ):
            if marker not in html:
                errors.append(f"landscape-report.html missing durable SPA marker: {label}")
    elif manifest := _load_json(research_dir / "run_manifest.json"):
        if manifest.get("research_type") in {"solution-landscape", "solution-compare"}:
            # SPA may be generated after this gate in some call orders; only require when present
            # unless packaging already wrote chart-data (synthesis done).
            if chart_data_path.is_file():
                errors.append("landscape-report.html missing after landscape synthesis")

    if md_text:
        _check_catalog_audit_gates(
            research_dir, need, comparison, chart_raw, md_text, errors, metrics
        )

    return {
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "metrics": metrics,
    }


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Validate landscape report content quality")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument(
        "--min-critical-fill",
        type=float,
        default=0.35,
        help="Minimum Critical-row matrix fill rate (0-1)",
    )
    args = parser.parse_args()
    result = validate_landscape_content(
        Path(args.dir),
        min_critical_fill_rate=args.min_critical_fill,
    )
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())

