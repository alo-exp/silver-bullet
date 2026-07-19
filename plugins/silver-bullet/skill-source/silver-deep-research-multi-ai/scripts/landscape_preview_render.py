#!/usr/bin/env python3
"""Render MultAI-parity landscape SPA (self-contained, file:// safe)."""

from __future__ import annotations

import html
import json
import re
from pathlib import Path
from typing import Any

from skill_paths import ensure_multi_ai_scripts_on_path, ensure_scripts_on_path

from compression_markers import assert_no_compression_markers, sanitize_compression_markers

ensure_multi_ai_scripts_on_path()
ensure_scripts_on_path("silver-deep-research", marker="spa_embed.py")
from spa_embed import safe_json_payload  # noqa: E402

from skill_paths import resolve_multi_ai_scripts  # noqa: E402

ASSETS_DIR = resolve_multi_ai_scripts().parent / "assets"
TEMPLATE_PATH = ASSETS_DIR / "landscape-preview.template.html"

LANDSCAPE_MARKERS = [
    "data-sb-landscape-viewer",
    'id="sidebar"',
    'id="toc"',
    'id="exportBar"',
    "chart-frame",
    "landscape-matrix-panel",
    "_scrollToVendorCard",
    "compareResultsSection",
    "attachChartVendorNav",
    "setupQuadrantCompareOverlays",
    "quadrant-compare-btn",
    "cmp-score-row",
]

CHART_DEFAULTS: dict[str, Any] = {
    "anchors": {
        "mq": ["3A", "Positioning"],
        "gmq": ["3B", "Magic Quadrant"],
        "wave": ["3C", "Wave"],
        "vc": ["3D", "Value Curve"],
    },
    "titles": {},
    "mq_data": [],
    "mq_colors": {},
    "gmq_data": [],
    "gmq_colors": {
        "Leaders": "#1f3864",
        "Challengers": "#475569",
        "Visionaries": "#2f5597",
        "Niche Players": "#94a3b8",
    },
    "wave_data": [],
    "wave_colors": [
        "#1f3864",
        "#2f5597",
        "#3d6fa8",
        "#5b7fa6",
        "#64748b",
        "#475569",
        "#334155",
        "#94a3b8",
    ],
    "vc_kcfs": [],
    "vc_commercial": [],
    "vc_oss": [],
    "link_pairs": [],
}

MARKER_START = "// ─── Chart data ─────────────────────────────────────────────────────────────"
# End patch before mqQuadrantRegions — that helper must survive the bootstrap splice.
MARKER_END = "function mqQuadrantRegions"
HYPERLINKS_START = "// ─── Hyperlinks ──────────────────────────────────────────────────────────────"


def _load_json(path: Path) -> dict[str, Any] | list[Any] | None:
    if not path.is_file():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return data


def _find_landscape_markdown(root: Path) -> tuple[Path, str]:
    landscape_dir = root / "landscape"
    canonical = landscape_dir / "landscape-report.md"
    if canonical.is_file():
        text = canonical.read_text(encoding="utf-8")
        if text.strip():
            return canonical, text
    candidates: list[Path] = []
    if landscape_dir.is_dir():
        candidates.extend(
            sorted(
                (p for p in landscape_dir.glob("*.md") if p != canonical),
                key=lambda p: p.stat().st_size,
                reverse=True,
            )
        )
    candidates.extend(sorted(root.glob("*Market Landscape Report*.md")))
    candidates.extend(sorted(root.glob("*landscape*.md")))
    for path in candidates:
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            if text.strip():
                return path, text
    if canonical.is_file():
        return canonical, canonical.read_text(encoding="utf-8")
    return canonical, ""


def _chart_slugs_from_data(chart_data: dict[str, Any]) -> list[str]:
    slugs: list[str] = []
    seen: set[str] = set()

    def _collect(points: Any) -> None:
        if not isinstance(points, list):
            return
        for point in points:
            if not isinstance(point, dict):
                continue
            slug = str(point.get("slug") or "").strip()
            if slug and slug not in seen:
                seen.add(slug)
                slugs.append(slug)

    _collect(chart_data.get("mq_data"))
    for market_chart in (chart_data.get("markets") or {}).values():
        if isinstance(market_chart, dict):
            _collect(market_chart.get("mq_data"))
    return slugs


def _enrich_chart_data(
    chart_data: dict[str, Any],
    root: Path,
    comparison: dict[str, Any],
    *,
    need: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Merge full catalog URLs and vendor buckets without re-synthesizing markdown."""
    from category_pack import catalog_entries_from_pack, resolve_pack_from_need
    from materialize_solution_artifacts import _effective_known_solutions
    from synthesize_landscape import build_link_pairs, build_vendor_buckets  # noqa: E402

    merged = dict(chart_data)
    rankings = [r for r in (comparison.get("rankings") or []) if isinstance(r, dict)]
    pack = resolve_pack_from_need(need or {})
    known = _effective_known_solutions(need or {})

    commercial_catalog = None
    oss_catalog = None
    matrix_slugs: list[str] = _chart_slugs_from_data(chart_data)
    audit_path = root / "landscape" / "catalog_audit.json"
    if audit_path.is_file():
        audit_raw = _load_json(audit_path)
        if isinstance(audit_raw, dict):
            matrix_slugs = list(audit_raw.get("matrix_slugs") or matrix_slugs)
            for slug in audit_raw.get("adjacent") or []:
                if slug and slug not in matrix_slugs:
                    matrix_slugs.append(str(slug))
    if pack:
        if not matrix_slugs:
            matrix_slugs = [
                str(r.get("solution"))
                for r in rankings
                if isinstance(r, dict) and r.get("solution")
            ]
        commercial_catalog, oss_catalog = catalog_entries_from_pack(pack, matrix_slugs)

    link_pairs = build_link_pairs(
        rankings,
        root=root,
        commercial=commercial_catalog,
        oss=oss_catalog,
        known=known,
        pack=pack,
        chart_slugs=_chart_slugs_from_data(chart_data),
        matrix_slugs=matrix_slugs,
    )
    existing_pairs = merged.get("link_pairs") or []
    if isinstance(existing_pairs, list):
        seen_labels = {p[0] for p in link_pairs if isinstance(p, list) and len(p) >= 2}
        for pair in existing_pairs:
            if isinstance(pair, list) and len(pair) >= 2 and pair[0] not in seen_labels:
                link_pairs.append([pair[0], pair[1]])
                seen_labels.add(pair[0])
    if link_pairs:
        merged["link_pairs"] = link_pairs
        merged["vendor_urls"] = {label: url for label, url in link_pairs}
    markets = merged.get("markets")
    if isinstance(markets, dict) and pack:
        for mid, mchart in markets.items():
            if not isinstance(mchart, dict):
                continue
            market_slugs = _chart_slugs_from_data(mchart)
            commercial_m, oss_m = catalog_entries_from_pack(pack, market_slugs, market_id=str(mid))
            market_rankings = [
                r
                for r in rankings
                if isinstance(r, dict) and str(r.get("solution")) in set(market_slugs)
            ]
            market_pairs = build_link_pairs(
                market_rankings or None,
                root=root,
                commercial=commercial_m,
                oss=oss_m,
                known=known,
                pack=pack,
                chart_slugs=market_slugs,
                matrix_slugs=market_slugs,
            )
            if market_pairs:
                mchart = dict(mchart)
                mchart["link_pairs"] = market_pairs
                mchart["vendor_urls"] = {label: url for label, url in market_pairs}
                markets[mid] = mchart
        merged["markets"] = markets
    mq_data = merged.get("mq_data") or []
    gmq_data = merged.get("gmq_data") or mq_data
    if isinstance(mq_data, list) or isinstance(gmq_data, list):
        merged["vendor_buckets"] = build_vendor_buckets(
            mq_data if isinstance(mq_data, list) else [],
            gmq_data=gmq_data if isinstance(gmq_data, list) else None,
            commercial=commercial_catalog,
            oss=oss_catalog,
            known=known,
        )
    return merged


def _load_chart_data(
    root: Path,
    comparison: dict[str, Any] | None = None,
    *,
    need: dict[str, Any] | None = None,
) -> dict[str, Any]:
    for rel in (
        "landscape/chart-data.json",
        "chart-data.json",
        "consolidated/chart-data.json",
    ):
        raw = _load_json(root / rel)
        if isinstance(raw, dict):
            merged = dict(CHART_DEFAULTS)
            merged.update(raw)
            if comparison is not None:
                merged = _enrich_chart_data(merged, root, comparison, need=need)
            return merged
    return dict(CHART_DEFAULTS)


def _derive_vendors_from_comparison(
    comparison: dict[str, Any],
    *,
    need: dict[str, Any] | None = None,
) -> tuple[list[str], list[str]]:
    from category_pack import build_license_by_slug, resolve_pack_from_need
    from synthesize_landscape import vendor_license_bucket

    pack = resolve_pack_from_need(need)
    license_map = build_license_by_slug(pack) if pack else {}

    commercial: list[str] = []
    oss: list[str] = []
    seen: set[str] = set()
    for item in comparison.get("rankings") or []:
        if not isinstance(item, dict):
            continue
        slug = str(item.get("solution") or "").strip()
        if not slug or slug in seen:
            continue
        seen.add(slug)
        license_tag = str(item.get("license") or item.get("type") or "").lower()
        bucket = vendor_license_bucket(
            slug,
            fallback="oss" if ("oss" in license_tag or "open" in license_tag) else "commercial",
            license_map=license_map,
        )
        (oss if bucket == "oss" else commercial).append(slug)
    if not commercial and not oss:
        for name in _solution_columns(comparison):
            bucket = vendor_license_bucket(name, license_map=license_map)
            if bucket == "oss":
                oss.append(name)
            else:
                commercial.append(name)
    return commercial, oss


def _solution_columns(comparison: dict[str, Any]) -> list[str]:
    rankings = comparison.get("rankings") or []
    if isinstance(rankings, list) and rankings:
        labels = [str(r.get("solution")) for r in rankings if isinstance(r, dict) and r.get("solution")]
        if labels:
            return labels
    solutions: set[str] = set()
    for row in comparison.get("rows") or []:
        if isinstance(row, dict) and row.get("type") == "feature":
            sols = row.get("solutions")
            if isinstance(sols, dict):
                solutions.update(str(k) for k in sols)
    return sorted(solutions)


def _load_manifest(root: Path) -> dict[str, Any]:
    data = _load_json(root / "run_manifest.json")
    return data if isinstance(data, dict) else {}


def _load_need_profile(root: Path) -> dict[str, Any]:
    data = _load_json(root / "need_profile.json")
    return data if isinstance(data, dict) else {}


def _load_comparison(root: Path) -> dict[str, Any]:
    data = _load_json(root / "comparison" / "comparison.json")
    return data if isinstance(data, dict) else {}


def _load_consolidation(root: Path) -> dict[str, Any]:
    data = _load_json(root / "consolidated" / "consolidation.json")
    return data if isinstance(data, dict) else {}


def _load_envelopes(root: Path) -> list[dict[str, Any]]:
    data = _load_json(root / "contributions" / "all-envelopes.json")
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def _audit_link_slugs(root: Path) -> list[str]:
    """Matrix + adjacent slugs for homepage link_pairs (SPA + markdown linkify)."""
    audit_path = root / "landscape" / "catalog_audit.json"
    audit = _load_json(audit_path)
    if not isinstance(audit, dict):
        return []
    slugs: list[str] = list(audit.get("matrix_slugs") or [])
    for slug in audit.get("adjacent") or []:
        if slug and slug not in slugs:
            slugs.append(str(slug))
    return slugs


def collect_landscape_payload(root: Path, *, report_html: Path | None = None) -> dict[str, Any]:
    manifest = _load_manifest(root)
    need_profile = _load_need_profile(root)
    comparison = _load_comparison(root)
    consolidation = _load_consolidation(root)
    envelopes = _load_envelopes(root)
    md_path, markdown = _find_landscape_markdown(root)
    markdown = sanitize_compression_markers(markdown)
    assert_no_compression_markers(markdown, context="landscape markdown payload")
    chart_data = _load_chart_data(root, comparison, need=need_profile)
    commercial, oss = _derive_vendors_from_comparison(comparison, need=need_profile)
    report_path = report_html or (root / "landscape-report.html")
    ensure_scripts_on_path("silver-deep-research", marker="matrix_core.py")
    from matrix_core import comparison_matrix_xlsx_href  # noqa: E402

    xlsx_href = comparison_matrix_xlsx_href(root)

    title = (
        manifest.get("query")
        or need_profile.get("category")
        or md_path.stem.replace("-", " ")
        or "Market Landscape Report"
    )

    return {
        "title": title,
        "research_type": manifest.get("research_type", "solution-landscape"),
        "need_profile": need_profile or {"category": "landscape"},
        "comparison": comparison,
        "xlsx_href": xlsx_href,
        "research_slug": root.name,
        "landscape": {
            "markdown_path": str(md_path.relative_to(root)) if md_path.is_file() else "landscape/landscape-report.md",
            "commercial_vendors": commercial,
            "oss_vendors": oss,
        },
        "chart_data": chart_data,
        "markdown": markdown,
        "manifest": {
            "run_id": manifest.get("run_id"),
            "mode": manifest.get("mode"),
            "workflow_id": manifest.get("workflow_id"),
            "started_at": manifest.get("started_at"),
            "finished_at": manifest.get("finished_at"),
            "multi_ai": manifest.get("multi_ai") if isinstance(manifest.get("multi_ai"), dict) else {},
        },
        "consolidation": consolidation,
        "envelopes": envelopes,
        "generated_by": "silver-deep-research-multi-ai/landscape_preview_render.py",
    }


def _patch_chart_bootstrap(template: str) -> str:
    start = template.find(MARKER_START)
    end = template.find(MARKER_END)
    if start < 0 or end < 0 or end <= start:
        return template

    bootstrap = """
// ─── Chart data (embedded via SB report-data) ───────────────────────────────
let CHART_TITLES = {};
let MQ_DATA = [], MQ_COLORS = {}, GMQ_DATA = [], GMQ_COLORS = {}, WAVE_DATA = [],
    WAVE_COLORS = [],
    VC_KCFS = [], VC_COMMERCIAL = [], VC_OSS = [], LINK_PAIRS = [], VENDOR_URLS = {},
    VENDOR_BUCKETS = { commercial: [], oss: [], leaders: [], challengers: [] };
let MARKET_CHARTS = {};
let PRIMARY_CHART_DATA = {};

function hexAlpha(hex, alpha) {
  const h = String(hex || '#94a3b8').replace('#', '');
  if (h.length < 6) return `rgba(148,163,184,${alpha})`;
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

function vendorChartColor(label) {
  const palette = themedSeriesPalette();
  const wi = WAVE_DATA.findIndex(d => d.label === label);
  if (wi >= 0) return palette[wi % palette.length];
  const labels = [...new Set([...MQ_DATA, ...GMQ_DATA, ...WAVE_DATA].map(d => d.label).filter(Boolean))];
  const i = labels.indexOf(label);
  return palette[(i >= 0 ? i : 0) % palette.length];
}

function normalizeChartPalette() {
  const quads = sbQuadrantColors();
  Object.keys(quads).forEach(k => {
    MQ_COLORS[k] = quads[k];
    GMQ_COLORS[k] = quads[k];
  });
  const palette = themedSeriesPalette();
  VC_COMMERCIAL.forEach((s, i) => { s.color = palette[i % palette.length]; });
  VC_OSS.forEach((s, i) => {
    s.color = palette[(i + VC_COMMERCIAL.length) % palette.length];
  });
}

function applyChartData(cd) {
  if (!cd || typeof cd !== 'object') return;
  CHART_TITLES = cd.titles || {};
  MQ_DATA = cd.mq_data || [];
  MQ_COLORS = cd.mq_colors || {};
  GMQ_DATA = cd.gmq_data || cd.mq_data || [];
  GMQ_COLORS = cd.gmq_colors || cd.mq_colors || {};
  WAVE_DATA = cd.wave_data || [];
  WAVE_COLORS = cd.wave_colors || WAVE_COLORS;
  VC_KCFS = cd.vc_kcfs || [];
  VC_COMMERCIAL = cd.vc_commercial || [];
  VC_OSS = cd.vc_oss || [];
  LINK_PAIRS = cd.link_pairs || [];
  VENDOR_URLS = cd.vendor_urls || Object.fromEntries(LINK_PAIRS);
  VENDOR_BUCKETS = cd.vendor_buckets || VENDOR_BUCKETS;
  normalizeChartPalette();
}

function applyMarketChartFromHeading(heading) {
  let node = heading;
  while (node) {
    const t = (node.textContent || '').toLowerCase();
    for (const chart of Object.values(MARKET_CHARTS || {})) {
      const dn = String(chart.market_display_name || '').toLowerCase();
      if (dn && t.includes(dn)) {
        applyChartData(chart);
        return;
      }
      const role = String(chart.market_role || '');
      if (role && t.includes(role + ' market')) {
        applyChartData(chart);
        return;
      }
    }
    node = node.previousElementSibling;
  }
  if (PRIMARY_CHART_DATA && Object.keys(PRIMARY_CHART_DATA).length) {
    applyChartData(PRIMARY_CHART_DATA);
  }
}

function bootstrapFromEmbedded() {
  try {
    const raw = document.getElementById('report-data');
    if (!raw) throw new Error('missing #report-data payload');
    const data = JSON.parse(raw.textContent);
    window.__SB_REPORT__ = data;
    const cd = data.chart_data || {};
    MARKET_CHARTS = cd.markets || {};
    PRIMARY_CHART_DATA = cd;
    applyChartData(cd);
    if (data.title) document.title = data.title;
    const md = data.markdown || '';
    document.getElementById('content').innerHTML = marked.parse(md);
    buildTOC();
    document.getElementById('stats').textContent =
      md ? `${(md.length/1000).toFixed(1)}K chars · ${md.split('\\n').length} lines` : 'No markdown body';
    window.scrollTo(0, 0);
    setTimeout(() => {
      injectCharts();
      linkify();
      renderMatrixPanel();
      setTimeout(() => postRender(), 0);
    }, 0);
  } catch (e) {
    console.error('bootstrapFromEmbedded failed', e);
    const el = document.getElementById('content');
    if (el) el.innerHTML = `<pre style="color:red;padding:24px;">Report render failed: ${e}</pre>`;
  }
}

function renderMatrixPanel() {
  const host = document.getElementById('matrixPanelBody');
  if (!host || !window.__SB_REPORT__) return;
  const cmp = window.__SB_REPORT__.comparison || {};
  const rows = (cmp.rows || []).filter(r => r && r.type === 'feature');
  const rankings = (cmp.rankings || []).filter(r => r && r.solution);
  const solutions = rankings.map(r => r.solution);
  const scoreBySolution = Object.fromEntries(
    rankings.map(r => [r.solution, r.score != null ? r.score : (r.total_score != null ? r.total_score : '—')])
  );
  const cols = solutions.length ? solutions : [];
  if (!cols.length || !rows.length) {
    host.innerHTML = '<p class="muted">Comparison matrix not populated yet.</p>';
    return;
  }
  const slugifyLabel = (label) => String(label || '').toLowerCase()
    .replace(/\s*\([^)]*\)\s*/g, '')
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_]+/g, '-');
  const labelForSlug = (slug) => {
    for (const [name] of (LINK_PAIRS || [])) {
      if (slugifyLabel(name) === slug) return name;
    }
    for (const d of [...MQ_DATA, ...GMQ_DATA, ...WAVE_DATA, ...VC_COMMERCIAL, ...VC_OSS]) {
      if (d && (d.slug === slug || slugifyLabel(d.label) === slug)) return d.label;
    }
    return String(slug || '').replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  };
  const urlForLabel = (label) => {
    if (typeof VENDOR_URLS === 'object' && VENDOR_URLS[label]) return VENDOR_URLS[label];
    const hit = (LINK_PAIRS || []).find(([name]) => name === label);
    return hit ? hit[1] : '';
  };
  const headerHtml = (slug) => {
    const label = labelForSlug(slug);
    const url = urlForLabel(label);
    if (url) {
      return `<a class="vname-link" href="${url}" target="_blank" rel="noopener noreferrer">${label}</a>`;
    }
    return label;
  };
  let html = '<div class="table-wrap"><table class="matrix"><thead><tr><th>Feature</th><th>Priority</th>';
  cols.forEach(s => {
    const score = scoreBySolution[s] != null ? scoreBySolution[s] : '—';
    html += '<th>' + headerHtml(s) + '<div style="font-size:10px;font-weight:600;color:var(--sb-primary-mid);margin-top:2px;">Score ' + score + '</div></th>';
  });
  html += '</tr></thead><tbody>';
  html += '<tr class="cmp-score-row"><td><strong>Weighted score</strong></td><td>—</td>';
  cols.forEach(s => {
    const score = scoreBySolution[s] != null ? scoreBySolution[s] : '—';
    html += '<td style="font-weight:700;text-align:center;">' + score + '</td>';
  });
  html += '</tr>';
  rows.slice(0, 120).forEach(row => {
    html += '<tr><td>' + (row.name || '') + '</td><td>' + (row.priority || '—') + '</td>';
    cols.forEach(s => {
      const v = (row.solutions || {})[s] || '—';
      html += '<td class="' + (v ? 'tick' : '') + '">' + v + '</td>';
    });
    html += '</tr>';
  });
  html += '</tbody></table></div>';
  host.innerHTML = html;
}

"""
    return template[:start] + bootstrap + template[end:]


def _strip_hardcoded_link_pairs(template: str) -> str:
    """Remove template const LINK_PAIRS — bootstrap declares let LINK_PAIRS via applyChartData."""
    start = template.find(HYPERLINKS_START)
    if start < 0:
        return template
    fn = template.find("function linkify()", start)
    if fn < 0:
        return template
    return template[:start] + (
        "// ─── Hyperlinks (populated from embedded chart_data.link_pairs) ─────────\n"
    ) + template[fn:]


BOOTSTRAP_COMMENT = (
    "// Embedded bootstrap (landscape_preview_render.py) calls bootstrapFromEmbedded() instead of loadFile."
)

BOOTSTRAP_AUTOSTART = """
// Embedded bootstrap (landscape_preview_render.py)
(function scheduleLandscapeBootstrap() {
  function run() {
    if (typeof bootstrapFromEmbedded === 'function') bootstrapFromEmbedded();
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run, { once: true });
  } else {
    run();
  }
})();
"""


def _patch_load_call(template: str) -> str:
    template = re.sub(
        r"async function loadFile\(path\)\s*\{[\s\S]*?\n\}\n",
        "",
        template,
        count=1,
    )
    template = re.sub(
        r"loadFile\([^)]+\);\s*",
        "",
        template,
        count=1,
    )
    if BOOTSTRAP_COMMENT in template:
        template = template.replace(BOOTSTRAP_COMMENT, BOOTSTRAP_AUTOSTART.strip(), 1)
    elif "scheduleLandscapeBootstrap" not in template:
        # Fallback: append autostart before first DOMContentLoaded if marker was edited away.
        template = template.replace(
            "document.addEventListener('DOMContentLoaded', () => {",
            BOOTSTRAP_AUTOSTART + "\ndocument.addEventListener('DOMContentLoaded', () => {",
            1,
        )
    return template


def _inject_modern_theme(template: str) -> str:
    modern = """
  html, body, button, input, select, textarea { font-family: 'Roboto Condensed', 'Arial Narrow', Arial, sans-serif !important; }
  code, pre, kbd, samp { font-family: 'SF Mono', Consolas, 'Liberation Mono', monospace !important; }
  #content h1, #content h2 { color: var(--sb-primary); }
  #content h3, #content h4 { color: var(--sb-primary-mid); }
  #readProgressBar { background: var(--sb-primary-mid) !important; }
  .export-btn, #compareBtn, #matrixBtn {
    background: var(--sb-btn-bg) !important;
    color: var(--sb-btn-ink) !important;
    border: 1px solid var(--sb-border) !important;
    box-shadow: 0 2px 8px var(--sb-shadow) !important;
  }
  .export-btn:hover, #compareBtn:hover, #matrixBtn:hover {
    background: var(--sb-btn-hover) !important;
    color: var(--sb-btn-ink) !important;
    box-shadow: 0 4px 14px var(--sb-shadow-strong) !important;
  }
  .snav-btn.active { background: var(--sb-primary-mid) !important; border-color: var(--sb-primary-mid) !important; }
  #matrixDrawer { position: fixed; bottom: 88px; right: 24px; width: min(640px, 92vw); max-height: 55vh;
    overflow: auto; background: var(--sb-surface); border: 1px solid var(--sb-border-soft); border-radius: 12px; padding: 16px;
    box-shadow: 0 12px 32px var(--sb-shadow-strong); display: none; z-index: 1002; }
  #matrixDrawer.open { display: block; }
  #matrixDrawer table.matrix th, #matrixDrawer table.matrix td { border: 1px solid var(--sb-border-soft); padding: 6px 8px; font-size: 12px; }
  #matrixDrawer .tick { color: var(--sb-primary); font-weight: 500; text-align: center; }
  .muted { color: var(--sb-muted); font-size: 13px; }
"""
    return template.replace("</style>", modern + "\n</style>", 1)


def _inject_matrix_ui(template: str) -> str:
    matrix_btn = """
  <button id="matrixBtn" class="export-btn" type="button"><i data-lucide="table-2" class="btn-icon lucide-icon" aria-hidden="true"></i> Matrix</button>
"""
    if 'id="matrixBtn"' not in template:
        template = template.replace(
            '<button id="pdfExportBtn"',
            matrix_btn + '  <button id="pdfExportBtn"',
            1,
        )
    drawer = """
<div id="matrixDrawer" class="landscape-matrix-panel" role="dialog" aria-label="Solution comparison matrix">
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
    <strong style="font-size:14px;">Weighted comparison matrix</strong>
    <button id="matrixCloseBtn" type="button" class="icon-btn" aria-label="Close matrix"><i data-lucide="x" class="lucide-icon" aria-hidden="true"></i></button>
  </div>
  <div id="matrixPanelBody"><p class="muted">Loading…</p></div>
</div>
"""
    if 'id="matrixDrawer"' not in template:
        template = template.replace(
            '<div id="compareDrawer"',
            drawer + "\n" + '<div id="compareDrawer"',
            1,
        )
    hook = """
  const matrixBtn = document.getElementById('matrixBtn');
  if (matrixBtn) matrixBtn.addEventListener('click', () => {
    const slug = (window.__SB_REPORT__ && window.__SB_REPORT__.research_slug) || '';
    const fallback = slug ? ('comparison/' + slug + '-comparison-matrix.xlsx') : '';
    const href = (window.__SB_REPORT__ && window.__SB_REPORT__.xlsx_href) || fallback;
    const fname = href.split('/').pop() || 'comparison-matrix.xlsx';
    const a = document.createElement('a');
    a.href = href;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.download = fname;
    document.body.appendChild(a);
    a.click();
    a.remove();
  });
  const matrixClose = document.getElementById('matrixCloseBtn');
  if (matrixClose) matrixClose.addEventListener('click', () => {
    document.getElementById('matrixDrawer').classList.remove('open');
  });
"""
    if "matrixBtn" not in template.split("DOMContentLoaded")[1][:800]:
        template = template.replace(
            "document.getElementById('pdfExportBtn').addEventListener('click', exportToPDF);",
            "document.getElementById('pdfExportBtn').addEventListener('click', exportToPDF);\n" + hook,
            1,
        )
    return template


def _patch_pdf_export(template: str) -> str:
    """Replace print-window logic with blob-URL flow (file:// and IDE-browser safe)."""
    marker_start = "    // 9. Open print window"
    marker_end = "    // 10. Re-collapse\n    collapsedBodies.forEach"
    start = template.find(marker_start)
    end = template.find(marker_end)
    if start < 0 or end < 0 or end <= start:
        return template
    replacement = """    // 9. Open print window (blob URL — file:// and IDE-browser safe)
    const blob = new Blob([printHTML], { type: 'text/html;charset=utf-8' });
    const blobUrl = URL.createObjectURL(blob);
    let printWin = null;
    try {
      printWin = window.open(blobUrl, '_blank', 'noopener,noreferrer');
    } catch (e) {
      printWin = null;
    }
    const triggerPrint = (win) => {
      if (!win) return;
      const doPrint = () => { try { win.focus(); win.print(); } catch (e) {} };
      if (win.document && win.document.readyState === 'complete') {
        setTimeout(doPrint, 300);
      } else {
        win.onload = () => setTimeout(doPrint, 300);
        setTimeout(doPrint, 2500);
      }
    };
    if (printWin) {
      triggerPrint(printWin);
      setTimeout(() => URL.revokeObjectURL(blobUrl), 60000);
    } else {
      const iframe = document.createElement('iframe');
      iframe.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;';
      document.body.appendChild(iframe);
      iframe.src = blobUrl;
      iframe.onload = () => {
        try {
          iframe.contentWindow.focus();
          iframe.contentWindow.print();
        } catch (e) {
          window.print();
        }
        setTimeout(() => { URL.revokeObjectURL(blobUrl); iframe.remove(); }, 60000);
      };
    }

"""
    return template[:start] + replacement + template[end:]


def _inject_report_data(template: str, payload: dict[str, Any]) -> str:
    safe = safe_json_payload(payload)
    block = f'<script type="application/json" id="report-data">{safe}</script>\n'
    if "<head>" in template:
        template = template.replace("<head>", "<head>\n" + block, 1)
    template = template.replace('<html lang="en">', '<html lang="en" data-sb-landscape-viewer="multai-v1">', 1)
    return template


def render_landscape_preview(data: dict[str, Any]) -> str:
    if not TEMPLATE_PATH.is_file():
        raise FileNotFoundError(f"landscape template missing: {TEMPLATE_PATH}")
    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    template = _patch_chart_bootstrap(template)
    template = _strip_hardcoded_link_pairs(template)
    template = _patch_load_call(template)
    template = _inject_modern_theme(template)
    template = _inject_matrix_ui(template)
    template = _patch_pdf_export(template)
    template = _inject_report_data(template, data)
    template = template.replace("<title>Report Preview</title>", f"<title>{html.escape(str(data.get('title', 'Landscape Report')))}</title>", 1)
    return template


def render_landscape_preview_file(root: Path, out: Path | None = None) -> dict[str, Any]:
    out_path = out or root / "landscape-report.html"
    data = collect_landscape_payload(root, report_html=out_path)
    out_path.write_text(render_landscape_preview(data), encoding="utf-8")
    return {
        "status": "ok",
        "out": str(out_path),
        "profile": "landscape",
        "markers": LANDSCAPE_MARKERS,
        "viewer": "multai-parity-v1",
    }
