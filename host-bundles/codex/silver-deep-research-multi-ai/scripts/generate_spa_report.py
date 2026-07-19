#!/usr/bin/env python3
"""Generate DR-multi-AI SPA report HTML (--profile general|landscape)."""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path
from typing import Any

from skill_paths import ensure_multi_ai_scripts_on_path, ensure_scripts_on_path

ensure_multi_ai_scripts_on_path()
ensure_scripts_on_path("silver-deep-research", marker="spa_embed.py")
from spa_embed import safe_json_payload  # noqa: E402

LANDSCAPE_MARKERS = [
    "data-landscape-marker",
    "panel-landscape-grid",
    "landscape-filter-bar",
    "landscape-chart-canvas",
]

LANDSCAPE_EXCERPT_MAX = 20000


def _load_json(path: Path) -> dict[str, Any] | list[Any] | None:
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def load_consolidation(root: Path) -> dict[str, Any]:
    data = _load_json(root / "consolidated" / "consolidation.json")
    return data if isinstance(data, dict) else {}


def load_manifest(root: Path) -> dict[str, Any]:
    data = _load_json(root / "run_manifest.json")
    return data if isinstance(data, dict) else {}


def load_need_profile(root: Path) -> dict[str, Any]:
    data = _load_json(root / "need_profile.json")
    return data if isinstance(data, dict) else {}


def load_comparison(root: Path) -> dict[str, Any]:
    data = _load_json(root / "comparison" / "comparison.json")
    return data if isinstance(data, dict) else {}


def load_envelopes(root: Path) -> list[dict[str, Any]]:
    data = _load_json(root / "contributions" / "all-envelopes.json")
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def load_landscape_excerpt(root: Path) -> str:
    path = root / "landscape" / "landscape-report.md"
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")[:LANDSCAPE_EXCERPT_MAX]


def _solution_labels(comparison: dict[str, Any]) -> list[str]:
    rankings = comparison.get("rankings") or []
    if isinstance(rankings, list) and rankings:
        labels: list[str] = []
        for item in rankings:
            if isinstance(item, dict) and item.get("solution"):
                labels.append(str(item["solution"]))
        if labels:
            return labels
    rows = comparison.get("rows") or []
    solutions: set[str] = set()
    if isinstance(rows, list):
        for row in rows:
            if isinstance(row, dict):
                sols = row.get("solutions")
                if isinstance(sols, dict):
                    solutions.update(str(k) for k in sols)
    return sorted(solutions)


def collect_general(root: Path) -> dict[str, Any]:
    manifest = load_manifest(root)
    consolidation = load_consolidation(root)
    return {
        "title": manifest.get("query") or "Multi-AI Deep Research",
        "research_type": manifest.get("research_type", "default"),
        "need_profile": {"category": manifest.get("research_type", "default")},
        "comparison": {"consensus_count": len(consolidation.get("consensus", []))},
        "consolidation": consolidation,
        "generated_by": "silver-deep-research-multi-ai/generate_spa_report.py:general",
    }


def collect_landscape(root: Path) -> dict[str, Any]:
    manifest = load_manifest(root)
    need_profile = load_need_profile(root)
    comparison = load_comparison(root)
    consolidation = load_consolidation(root)
    landscape_excerpt = load_landscape_excerpt(root)
    envelopes = load_envelopes(root)
    multi_ai = manifest.get("multi_ai") if isinstance(manifest.get("multi_ai"), dict) else {}

    title = manifest.get("query") or need_profile.get("category") or "Solution Landscape"

    return {
        "title": title,
        "research_type": manifest.get("research_type", "solution-landscape"),
        "need_profile": need_profile or {"category": "landscape"},
        "comparison": comparison,
        "landscape": {
            "excerpt": landscape_excerpt,
            "solutions": _solution_labels(comparison),
            "winner": comparison.get("winner"),
            "runner_up": comparison.get("runner_up"),
            "caveats": comparison.get("caveats") or [],
        },
        "manifest": {
            "run_id": manifest.get("run_id"),
            "mode": manifest.get("mode"),
            "workflow_id": manifest.get("workflow_id"),
            "started_at": manifest.get("started_at"),
            "finished_at": manifest.get("finished_at"),
            "multi_ai": multi_ai,
        },
        "consolidation": consolidation,
        "envelopes": envelopes,
        "generated_by": "silver-deep-research-multi-ai/generate_spa_report.py:landscape",
    }


def render_general(data: dict[str, Any]) -> str:
    payload = safe_json_payload(data)
    title = html.escape(str(data.get("title", "Research Report")))
    return f"""<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
body {{ font-family: system-ui, sans-serif; margin: 0; padding: 1.5rem; line-height: 1.5; }}
nav button {{ margin-right: 0.5rem; }}
.panel {{ display: none; }} .panel.active {{ display: block; }}
table {{ border-collapse: collapse; width: 100%; }} th, td {{ border: 1px solid #ccc; padding: 0.4rem; }}
</style>
</head>
<body>
<header><h1>{title}</h1></header>
<nav id="tabNav" role="tablist">
  <button type="button" data-tab="overview" class="active">Overview</button>
  <button type="button" data-tab="matrix">Matrix</button>
</nav>
<main>
  <section id="panel-overview" class="panel active" data-tab-marker="overview"></section>
  <section id="panel-matrix" class="panel" data-tab-marker="matrix"></section>
</main>
<script type="application/json" id="report-data">{payload}</script>
<script>
(function() {{
  const data = JSON.parse(document.getElementById('report-data').textContent);
  const panels = document.querySelectorAll('.panel');
  const buttons = document.querySelectorAll('#tabNav button[data-tab]');
  function esc(s) {{ const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }}
  function showTab(name) {{
    panels.forEach(p => p.classList.toggle('active', p.dataset.tabMarker === name));
    buttons.forEach(b => b.classList.toggle('active', b.dataset.tab === name));
  }}
  buttons.forEach(b => b.addEventListener('click', () => showTab(b.dataset.tab)));
  document.getElementById('panel-overview').innerHTML = '<p>Research type: ' + esc(data.research_type || 'default') + '</p>';
  let table = '';
  const rows = (data.consolidation && data.consolidation.consensus) || [];
  if (rows.length) {{
    table += '<table id="matrixTable"><thead><tr><th>Claim</th><th>Support</th></tr></thead><tbody>';
    rows.forEach(r => {{ table += '<tr><td>' + esc(r.text || '') + '</td><td>' + esc(String(r.support_count || 0)) + '</td></tr>'; }});
    table += '</tbody></table>';
  }} else {{
    table = '<p>No consensus rows yet.</p>';
  }}
  document.getElementById('panel-matrix').innerHTML = table;
}})();
</script>
</body>
</html>
"""


def render_landscape(data: dict[str, Any]) -> str:
    payload = safe_json_payload(data)
    title = html.escape(str(data.get("title", "Landscape Report")))
    head = f"""<!DOCTYPE html>
<html lang="en" data-theme="light" data-landscape-marker="v1">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
:root {{
  --bg-page: #f6f4f0;
  --bg-card: #ffffff;
  --bg-elevated: #f0ece6;
  --text-primary: #050f08;
  --text-secondary: #0d3a1a;
  --text-dim: #285c38;
  --border: #8cc4a4;
  --border-soft: rgba(140, 196, 164, 0.45);
  --accent: #00c834;
  --accent-soft: rgba(0, 200, 52, 0.14);
  --accent2: #006fa8;
  --amber: #a86000;
  --red: #aa1830;
  --radius: 12px;
  --radius-sm: 8px;
  --shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
  --font-sans: 'Inter', system-ui, -apple-system, sans-serif;
}}
[data-theme="dark"] {{
  --bg-page: #0a0f0c;
  --bg-card: #121a15;
  --bg-elevated: #1a241d;
  --text-primary: #e8f5ec;
  --text-secondary: #b8d4c4;
  --text-dim: #7aa892;
  --border: #2a4a38;
  --border-soft: rgba(42, 74, 56, 0.65);
  --accent: #3dff7a;
  --accent-soft: rgba(61, 255, 122, 0.16);
  --accent2: #4db8ff;
  --amber: #f0b35a;
  --red: #ff6b7a;
  --shadow: 0 12px 36px rgba(0, 0, 0, 0.45);
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; font-family: var(--font-sans); background: var(--bg-page); color: var(--text-primary); line-height: 1.55; }}
a {{ color: var(--accent2); }}
.shell {{ max-width: 1180px; margin: 0 auto; padding: 1rem 1rem 2.5rem; }}
.hero {{ background: var(--bg-card); border: 1px solid var(--border-soft); border-radius: var(--radius); padding: 1.25rem 1.35rem; box-shadow: var(--shadow); }}
.hero-top {{ display: flex; gap: 1rem; align-items: flex-start; justify-content: space-between; flex-wrap: wrap; }}
.hero h1 {{ margin: 0; font-size: clamp(1.2rem, 3.5vw, 1.75rem); letter-spacing: -0.02em; }}
.hero .subtitle {{ color: var(--text-dim); font-size: 0.92rem; margin-top: 0.35rem; }}
.toolbar {{ display: flex; gap: 0.5rem; flex-wrap: wrap; align-items: center; }}
.btn {{ border: 1px solid var(--border); background: var(--bg-elevated); color: var(--text-primary); border-radius: 999px; padding: 0.45rem 0.85rem; font: inherit; cursor: pointer; }}
.btn.active {{ background: var(--accent); color: #041208; border-color: var(--accent); font-weight: 600; }}
.btn-ghost {{ background: transparent; }}
.rank-strip {{ display: flex; gap: 0.6rem; flex-wrap: wrap; margin-top: 1rem; }}
.rank-badge {{ display: inline-flex; align-items: center; gap: 0.45rem; padding: 0.35rem 0.7rem; border-radius: 999px; border: 1px solid var(--border-soft); background: var(--bg-elevated); font-size: 0.85rem; }}
.rank-badge .num {{ display: inline-flex; width: 1.35rem; height: 1.35rem; align-items: center; justify-content: center; border-radius: 50%; background: var(--accent-soft); color: var(--text-primary); font-weight: 700; font-size: 0.75rem; }}
.rank-badge.winner {{ border-color: var(--accent); box-shadow: 0 0 0 1px var(--accent-soft); }}
.tabs {{ display: flex; gap: 0.45rem; flex-wrap: wrap; margin: 1rem 0 0.75rem; }}
.panel {{ display: none; }}
.panel.active {{ display: block; }}
.card {{ background: var(--bg-card); border: 1px solid var(--border-soft); border-radius: var(--radius); padding: 1rem 1.1rem; margin-bottom: 0.85rem; }}
.card h2, .card h3 {{ margin: 0 0 0.6rem; font-size: 1.05rem; }}
.meta-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.65rem; }}
.meta-item {{ background: var(--bg-elevated); border-radius: var(--radius-sm); padding: 0.65rem 0.75rem; }}
.meta-item .label {{ color: var(--text-dim); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }}
.meta-item .value {{ font-weight: 600; margin-top: 0.2rem; word-break: break-word; }}
.landscape-filter-bar {{ display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin: 0.75rem 0 0.85rem; }}
.landscape-filter-bar input, .landscape-filter-bar select {{ border: 1px solid var(--border); background: var(--bg-card); color: var(--text-primary); border-radius: var(--radius-sm); padding: 0.45rem 0.6rem; font: inherit; min-width: 0; }}
.landscape-filter-bar input[type="search"] {{ flex: 1 1 220px; }}
.table-wrap {{ overflow-x: auto; border: 1px solid var(--border-soft); border-radius: var(--radius-sm); }}
table.matrix {{ width: 100%; border-collapse: collapse; font-size: 0.86rem; }}
table.matrix th, table.matrix td {{ border-bottom: 1px solid var(--border-soft); padding: 0.45rem 0.55rem; text-align: left; vertical-align: top; }}
table.matrix th {{ background: var(--bg-elevated); position: sticky; top: 0; z-index: 1; white-space: nowrap; }}
table.matrix th.sortable {{ cursor: pointer; user-select: none; }}
table.matrix th.sortable:hover {{ color: var(--accent2); }}
table.matrix td.tick {{ color: var(--accent); font-weight: 700; text-align: center; }}
#panel-landscape-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 0.75rem; }}
.solution-card {{ border: 1px solid var(--border-soft); border-radius: var(--radius-sm); padding: 0.75rem; background: var(--bg-elevated); }}
.solution-card h4 {{ margin: 0 0 0.35rem; }}
#landscape-chart-canvas {{ margin-top: 0.5rem; display: grid; gap: 0.55rem; }}
.chart-row {{ display: grid; grid-template-columns: minmax(110px, 28%) 1fr minmax(42px, 48px); gap: 0.55rem; align-items: center; }}
.chart-label {{ font-size: 0.82rem; color: var(--text-secondary); word-break: break-word; }}
.chart-track {{ height: 0.85rem; border-radius: 999px; background: var(--bg-elevated); border: 1px solid var(--border-soft); overflow: hidden; }}
.chart-bar {{ height: 100%; background: linear-gradient(90deg, var(--accent2), var(--accent)); border-radius: 999px; }}
.chart-bar.winner {{ background: linear-gradient(90deg, var(--accent), #7dff9f); }}
.chart-score {{ font-weight: 700; font-size: 0.82rem; text-align: right; }}
.timeline {{ list-style: none; padding: 0; margin: 0; }}
.timeline li {{ display: grid; grid-template-columns: 120px 1fr; gap: 0.75rem; padding: 0.55rem 0; border-bottom: 1px dashed var(--border-soft); }}
.timeline .phase-id {{ font-weight: 700; color: var(--accent2); }}
.pool-list {{ display: flex; flex-wrap: wrap; gap: 0.45rem; }}
.pool-chip {{ border: 1px solid var(--border-soft); border-radius: 999px; padding: 0.25rem 0.6rem; font-size: 0.8rem; background: var(--bg-elevated); }}
pre.excerpt {{ white-space: pre-wrap; background: var(--bg-elevated); border-radius: var(--radius-sm); padding: 0.75rem; border: 1px solid var(--border-soft); font-size: 0.84rem; max-height: 360px; overflow: auto; }}
.evidence-list {{ display: grid; gap: 0.55rem; }}
.evidence-item {{ border-left: 3px solid var(--accent2); padding: 0.45rem 0.65rem; background: var(--bg-elevated); border-radius: 0 var(--radius-sm) var(--radius-sm) 0; }}
.muted {{ color: var(--text-dim); font-size: 0.88rem; }}
@media (max-width: 375px) {{
  .shell {{ padding: 0.65rem 0.65rem 1.5rem; }}
  .hero {{ padding: 0.9rem; }}
  .tabs {{ gap: 0.35rem; }}
  .btn {{ padding: 0.4rem 0.65rem; font-size: 0.85rem; }}
  .chart-row {{ grid-template-columns: 1fr; }}
  .timeline li {{ grid-template-columns: 1fr; }}
  table.matrix {{ font-size: 0.78rem; }}
}}
</style>
</head>
<body>
<div class="shell">
  <header class="hero">
    <div class="hero-top">
      <div>
        <h1 id="pageTitle">{title}</h1>
        <p class="subtitle">Multi-AI solution landscape — serverless SPA (file:// safe)</p>
      </div>
      <div class="toolbar">
        <button type="button" class="btn btn-ghost" id="themeToggle" aria-label="Toggle theme">Theme</button>
      </div>
    </div>
    <div class="rank-strip" id="rankStrip" aria-label="Platform rankings"></div>
  </header>
  <nav class="tabs" id="tabNav" role="tablist" aria-label="Landscape sections">
    <button type="button" class="btn active" data-tab="overview">Overview</button>
    <button type="button" class="btn" data-tab="matrix">Matrix</button>
    <button type="button" class="btn" data-tab="solutions">Solutions</button>
    <button type="button" class="btn" data-tab="evidence">Evidence</button>
    <button type="button" class="btn" data-tab="methodology">Methodology</button>
  </nav>
  <main>
    <section id="panel-overview" class="panel active" data-tab-marker="overview">
      <div class="card"><h2>Need profile</h2><div class="meta-grid" id="needProfileGrid"></div></div>
      <div class="card"><h2>Landscape excerpt</h2><div id="landscapeExcerpt" class="muted">Loading…</div></div>
      <section id="panel-landscape-grid" data-landscape-marker="grid" aria-label="Solution highlights"></section>
      <div class="card"><h2>Weighted scores</h2><div id="landscape-chart-canvas" data-landscape-marker="chart" aria-label="Score chart"></div></div>
    </section>
    <section id="panel-matrix" class="panel" data-tab-marker="matrix">
      <div class="card">
        <h2>Comparison matrix</h2>
        <div class="landscape-filter-bar" data-landscape-marker="filters">
          <input type="search" id="matrixSearch" placeholder="Search features…" aria-label="Search matrix">
          <select id="matrixCategory" aria-label="Filter by category"><option value="">All categories</option></select>
          <button type="button" class="btn btn-ghost" id="matrixReset">Reset</button>
        </div>
        <div class="table-wrap" id="matrixMount"></div>
      </div>
    </section>
    <section id="panel-solutions" class="panel" data-tab-marker="solutions">
      <div class="card"><h2>Ranked platforms</h2><div id="solutionsMount"></div></div>
    </section>
    <section id="panel-evidence" class="panel" data-tab-marker="evidence">
      <div class="card"><h2>Consolidated evidence</h2><div id="evidenceMount"></div></div>
    </section>
    <section id="panel-methodology" class="panel" data-tab-marker="methodology">
      <div class="card"><h2>Multi-AI provenance</h2><div id="provenanceMount"></div></div>
      <div class="card"><h2>Pool attribution</h2><div id="poolMount"></div></div>
      <div class="card"><h2>DR phase timeline</h2><ol class="timeline" id="phaseTimeline"></ol></div>
    </section>
  </main>
</div>
<script type="application/json" id="report-data">{payload}</script>
"""
    tail = """
<script>
(function() {
  const data = JSON.parse(document.getElementById('report-data').textContent);
  const panels = document.querySelectorAll('.panel');
  const tabButtons = document.querySelectorAll('#tabNav button[data-tab]');
  const cmp = data.comparison || {};
  const landscape = data.landscape || {};
  const manifest = data.manifest || {};
  const multiAi = manifest.multi_ai || {};
  const rankings = Array.isArray(cmp.rankings) ? cmp.rankings.slice() : [];
  const rows = Array.isArray(cmp.rows) ? cmp.rows.slice() : [];
  const categories = Array.isArray(cmp.categories) ? cmp.categories.slice() : [];
  let sortKey = 'feature';
  let sortDir = 1;

  function esc(s) {
    const d = document.createElement('div');
    d.textContent = s == null ? '' : String(s);
    return d.innerHTML;
  }

  function showTab(name) {
    panels.forEach(p => p.classList.toggle('active', p.dataset.tabMarker === name));
    tabButtons.forEach(b => b.classList.toggle('active', b.dataset.tab === name));
  }
  tabButtons.forEach(b => b.addEventListener('click', () => showTab(b.dataset.tab)));

  document.getElementById('themeToggle').addEventListener('click', () => {
    const root = document.documentElement;
    root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
  });

  function renderRankStrip() {
    const host = document.getElementById('rankStrip');
    if (!rankings.length) {
      host.innerHTML = '<span class="muted">Rankings pending comparison synthesis.</span>';
      return;
    }
    host.innerHTML = rankings.map(r => {
      const winner = cmp.winner && r.solution === cmp.winner;
      return '<span class="rank-badge' + (winner ? ' winner' : '') + '"><span class="num">#' + esc(r.rank) + '</span><span>' + esc(r.solution) + '</span><span class="muted">' + esc(r.score) + '</span></span>';
    }).join('');
  }

  function renderNeedProfile() {
    const np = data.need_profile || {};
    const fields = [
      ['Category', np.category],
      ['Persona', np.persona_id],
      ['Audience', np.audience],
      ['License', np.license_preference || cmp.license_preference],
      ['Must-haves', (np.must_haves || []).join(', ')],
      ['Constraints', (np.constraints || []).join(', ')],
    ];
    document.getElementById('needProfileGrid').innerHTML = fields.map(([label, value]) =>
      '<div class="meta-item"><div class="label">' + esc(label) + '</div><div class="value">' + esc(value || '—') + '</div></div>'
    ).join('');
  }

  function renderLandscapeExcerpt() {
    const excerpt = landscape.excerpt || '';
    document.getElementById('landscapeExcerpt').innerHTML = excerpt
      ? '<pre class="excerpt">' + esc(excerpt) + '</pre>'
      : '<p class="muted">No landscape narrative yet.</p>';
  }

  function renderGrid() {
    const grid = document.getElementById('panel-landscape-grid');
    if (!rankings.length) {
      grid.innerHTML = '<div class="solution-card"><p class="muted">No ranked solutions yet.</p></div>';
      return;
    }
    grid.innerHTML = rankings.slice(0, 6).map(r => {
      const winner = cmp.winner && r.solution === cmp.winner;
      return '<article class="solution-card"><h4>' + esc(r.solution) + (winner ? ' ★' : '') + '</h4><p class="muted">Rank #' + esc(r.rank) + ' · score ' + esc(r.score) + '</p></article>';
    }).join('');
  }

  function renderChart() {
    const canvas = document.getElementById('landscape-chart-canvas');
    if (!rankings.length) {
      canvas.innerHTML = '<p class="muted">Score chart available after comparison rankings are emitted.</p>';
      return;
    }
    const maxScore = Math.max.apply(null, rankings.map(r => Number(r.score) || 0).concat([1]));
    canvas.innerHTML = rankings.map(r => {
      const pct = Math.round(((Number(r.score) || 0) / maxScore) * 100);
      const winner = cmp.winner && r.solution === cmp.winner;
      return '<div class="chart-row"><div class="chart-label">#' + esc(r.rank) + ' ' + esc(r.solution) + '</div><div class="chart-track"><div class="chart-bar' + (winner ? ' winner' : '') + '" style="width:' + pct + '%"></div></div><div class="chart-score">' + esc(r.score) + '</div></div>';
    }).join('');
  }

  function currentCategoryFilter() { return document.getElementById('matrixCategory').value; }
  function currentSearch() { return (document.getElementById('matrixSearch').value || '').trim().toLowerCase(); }

  function filteredRows() {
    const cat = currentCategoryFilter();
    const q = currentSearch();
    let activeCat = '';
    const out = [];
    rows.forEach(row => {
      if (row.type === 'category') {
        activeCat = row.name || '';
        if (!cat || cat === activeCat) out.push(row);
        return;
      }
      if (row.type !== 'feature') return;
      const inCat = !cat || activeCat === cat || (row.category && row.category === cat);
      const hay = ((row.name || '') + ' ' + (row.priority || '')).toLowerCase();
      if (inCat && (!q || hay.includes(q))) out.push(Object.assign({}, row, { _cat: activeCat }));
    });
    return out;
  }

  function solutionColumns() {
    if (rankings.length) return rankings.map(r => r.solution);
    const set = new Set();
    rows.forEach(row => { if (row.solutions) Object.keys(row.solutions).forEach(k => set.add(k)); });
    return Array.from(set).sort();
  }

  function bindSortHandlers() {
    document.querySelectorAll('#matrixMount th.sortable').forEach(th => {
      th.addEventListener('click', () => {
        const key = th.dataset.sort;
        if (sortKey === key) sortDir *= -1; else { sortKey = key; sortDir = 1; }
        renderMatrix(true);
      });
    });
  }

  function renderMatrix(skipSort) {
    const mount = document.getElementById('matrixMount');
    const solutions = solutionColumns();
    let visible = filteredRows().filter(r => r.type === 'feature');
    if (!skipSort) { sortKey = 'feature'; sortDir = 1; }
    visible.sort((a, b) => {
      let av; let bv;
      if (sortKey === 'feature') { av = a.name || ''; bv = b.name || ''; }
      else if (sortKey === 'priority') { av = a.priority || ''; bv = b.priority || ''; }
      else { av = ((a.solutions || {})[sortKey] || ''); bv = ((b.solutions || {})[sortKey] || ''); }
      if (av < bv) return -1 * sortDir;
      if (av > bv) return 1 * sortDir;
      return 0;
    });
    let table = '';
    if (!solutions.length) {
      mount.innerHTML = '<p class="muted">Matrix not built yet.</p>';
      return;
    }
    table += '<table class="matrix" id="matrixTable"><thead><tr>';
    table += '<th class="sortable" data-sort="feature">Feature</th><th class="sortable" data-sort="priority">Priority</th>';
    solutions.forEach(s => { table += '<th class="sortable" data-sort="' + esc(s) + '">' + esc(s) + '</th>'; });
    table += '</tr></thead><tbody>';
    if (!visible.length) {
      table += '<tr><td colspan="' + (2 + solutions.length) + '">No rows match the current filter.</td></tr>';
    } else {
      visible.forEach(row => {
        table += '<tr><td>' + esc(row.name) + '</td><td>' + esc(row.priority || '—') + '</td>';
        solutions.forEach(s => {
          const v = (row.solutions || {})[s] || '';
          table += '<td class="' + (v ? 'tick' : '') + '">' + esc(v || '—') + '</td>';
        });
        table += '</tr>';
      });
    }
    table += '</tbody></table>';
    mount.innerHTML = table;
    bindSortHandlers();
  }

  function populateCategoryFilter() {
    const select = document.getElementById('matrixCategory');
    const existing = new Set(categories);
    rows.forEach(r => { if (r.type === 'category' && r.name) existing.add(r.name); });
    Array.from(existing).sort().forEach(name => {
      const opt = document.createElement('option');
      opt.value = name;
      opt.textContent = name;
      select.appendChild(opt);
    });
  }

  function renderSolutions() {
    const host = document.getElementById('solutionsMount');
    if (!rankings.length) {
      host.innerHTML = '<p class="muted">No solution rankings yet.</p>';
      return;
    }
    host.innerHTML = rankings.map(r => {
      const winner = cmp.winner && r.solution === cmp.winner;
      const runner = cmp.runner_up && r.solution === cmp.runner_up;
      let tags = '';
      if (winner) tags += '<span class="pool-chip">Winner</span>';
      if (runner) tags += '<span class="pool-chip">Runner-up</span>';
      return '<div class="solution-card" style="margin-bottom:0.55rem"><h4>#' + esc(r.rank) + ' ' + esc(r.solution) + '</h4><p>Weighted score: <strong>' + esc(r.score) + '</strong></p><div class="pool-list">' + tags + '</div></div>';
    }).join('');
    const caveats = cmp.caveats || landscape.caveats || [];
    if (caveats.length) {
      host.innerHTML += '<div class="card" style="margin-top:0.75rem"><h3>Caveats</h3><ul>' + caveats.map(c => '<li>' + esc(c) + '</li>').join('') + '</ul></div>';
    }
  }

  function renderEvidence() {
    const host = document.getElementById('evidenceMount');
    const consensus = (data.consolidation && data.consolidation.consensus) || [];
    const envelopes = Array.isArray(data.envelopes) ? data.envelopes : [];
    let html = '';
    if (consensus.length) {
      html += '<div class="evidence-list">' + consensus.slice(0, 40).map(item =>
        '<div class="evidence-item"><strong>' + esc(item.text || item.claim || 'Claim') + '</strong><div class="muted">support ' + esc(item.support_count || item.support || 0) + '</div></div>'
      ).join('') + '</div>';
    }

    const evidenceItems = [];
    envelopes.forEach(env => {
      const payload = env.payload || {};
      const phase = env.phase_id || 'DR';
      const model = env.logical_model_id || env.model_family_id || 'model';
      (payload.evidence || []).forEach(item => {
        if (!item || typeof item !== 'object') return;
        const claim = item.claim || item.text || '';
        if (!claim) return;
        evidenceItems.push({
          claim: claim,
          source_ref: item.source_ref || '',
          confidence: item.confidence,
          phase: phase,
          model: model,
        });
      });
      (payload.claim_candidates || []).forEach(item => {
        if (!item || typeof item !== 'object') return;
        const claim = item.text || item.claim || '';
        if (!claim) return;
        evidenceItems.push({
          claim: claim,
          source_ref: item.source_ref || item.source || '',
          confidence: item.confidence,
          phase: phase,
          model: model,
        });
      });
      (payload.sources || []).forEach(item => {
        if (typeof item === 'string' && item.trim()) {
          evidenceItems.push({ claim: item.trim(), source_ref: '', confidence: null, phase: phase, model: model });
          return;
        }
        if (!item || typeof item !== 'object') return;
        const label = item.title || item.url || item.name || '';
        if (!label) return;
        evidenceItems.push({
          claim: label,
          source_ref: item.url || item.ref || '',
          confidence: item.confidence,
          phase: phase,
          model: model,
        });
      });
    });

    if (evidenceItems.length) {
      html += '<h3 style="margin-top:1rem">Research evidence</h3><div class="evidence-list">' + evidenceItems.slice(0, 60).map(item => {
        let meta = esc(item.phase) + ' · ' + esc(item.model);
        if (item.confidence != null) meta += ' · conf ' + esc(item.confidence);
        if (item.source_ref) meta += ' · ' + esc(item.source_ref);
        return '<div class="evidence-item"><strong>' + esc(item.claim) + '</strong><div class="muted">' + meta + '</div></div>';
      }).join('') + '</div>';
    } else if (envelopes.length) {
      html += '<h3 style="margin-top:1rem">Phase contributions</h3><div class="evidence-list">' + envelopes.slice(0, 30).map(env =>
        '<div class="evidence-item"><strong>' + esc(env.phase_id || 'DR') + '</strong> · ' + esc(env.logical_model_id || env.model_family_id || 'model') + '<div class="muted">Envelope received (no structured evidence payload).</div></div>'
      ).join('') + '</div>';
    }
    host.innerHTML = html || '<p class="muted">No consolidated evidence yet.</p>';
  }

  function renderMethodology() {
    document.getElementById('provenanceMount').innerHTML = '<div class="meta-grid">'
      + '<div class="meta-item"><div class="label">Run ID</div><div class="value">' + esc(manifest.run_id || '—') + '</div></div>'
      + '<div class="meta-item"><div class="label">Workflow</div><div class="value">' + esc(manifest.workflow_id || 'WF-SILVER-DEEP-RESEARCH-MULTI-AI') + '</div></div>'
      + '<div class="meta-item"><div class="label">Mode</div><div class="value">' + esc(manifest.mode || '—') + '</div></div>'
      + '<div class="meta-item"><div class="label">Window</div><div class="value">' + esc(manifest.started_at || '—') + ' → ' + esc(manifest.finished_at || '—') + '</div></div>'
      + '</div>';

    const poolCfg = multiAi.pool_config || {};
    const resolved = Array.isArray(poolCfg.resolved_pool) ? poolCfg.resolved_pool : [];
    let poolHtml = '<div class="meta-grid">'
      + '<div class="meta-item"><div class="label">OCG pool</div><div class="value">' + esc(poolCfg.ocg_pool || '—') + '</div></div>'
      + '<div class="meta-item"><div class="label">Cursor pool</div><div class="value">' + esc(poolCfg.cursor_pool || '—') + '</div></div>'
      + '<div class="meta-item"><div class="label">Dispatch</div><div class="value">' + esc(poolCfg.dispatch_mode || '—') + '</div></div>'
      + '</div>';
    if (resolved.length) {
      poolHtml += '<div class="pool-list" style="margin-top:0.75rem">' + resolved.map(m =>
        '<span class="pool-chip">' + esc(m.logical_model_id || m.model || 'model') + ' · ' + esc(m.backend || 'backend') + '</span>'
      ).join('') + '</div>';
    }
    document.getElementById('poolMount').innerHTML = poolHtml;

    const phases = Array.isArray(multiAi.phases) ? multiAi.phases : [];
    document.getElementById('phaseTimeline').innerHTML = phases.length
      ? phases.map(p => '<li><div class="phase-id">' + esc(p.phase_id || 'DR') + '</div><div>' + esc(p.work_item_id || '') + (p.parallel ? ' · parallel' : '') + '</div></li>').join('')
      : '<li><div class="phase-id">DR</div><div class="muted">Phase timeline not recorded in manifest.</div></li>';
  }

  populateCategoryFilter();
  document.getElementById('matrixSearch').addEventListener('input', () => renderMatrix(false));
  document.getElementById('matrixCategory').addEventListener('change', () => renderMatrix(false));
  document.getElementById('matrixReset').addEventListener('click', () => {
    document.getElementById('matrixSearch').value = '';
    document.getElementById('matrixCategory').value = '';
    renderMatrix(false);
  });

  renderRankStrip();
  renderNeedProfile();
  renderLandscapeExcerpt();
  renderGrid();
  renderChart();
  renderMatrix(false);
  renderSolutions();
  renderEvidence();
  renderMethodology();
})();
</script>
</body>
</html>
"""
    return head + tail


PROFILES: dict[str, dict[str, Any]] = {
    "general": {
        "default_out": "report.html",
        "collect": collect_general,
        "render": render_general,
        "validate_root": None,
    },
    "landscape": {
        "default_out": "landscape-report.html",
        "collect": collect_landscape,
        "render": None,  # landscape_preview_render.render_landscape_preview
        "validate_root": lambda root: _require_landscape_type(root),
        "markers": None,  # set by landscape_preview_render
    },
}


def _require_landscape_type(root: Path) -> None:
    rtype = load_manifest(root).get("research_type")
    if rtype not in {"solution-landscape", "solution-compare"}:
        raise ValueError(f"landscape report only for solution types, got {rtype!r}")


def generate_spa_report_file(
    root: Path,
    profile: str,
    out: Path | None = None,
) -> dict[str, Any]:
    """Generate SPA HTML for profile; return result dict (library entrypoint)."""
    if profile not in PROFILES:
        raise ValueError(f"unknown profile: {profile!r}")
    spec = PROFILES[profile]
    validator = spec.get("validate_root")
    if callable(validator):
        validator(root)
    out_path = out if out else root / spec["default_out"]

    if profile == "landscape":
        from landscape_preview_render import render_landscape_preview_file

        return render_landscape_preview_file(root, out=out_path)

    collect = spec["collect"]
    render = spec["render"]
    if render is None:
        raise ValueError(f"profile {profile!r} has no render function")
    data = collect(root)
    out_path.write_text(render(data), encoding="utf-8")
    result: dict[str, Any] = {"status": "ok", "out": str(out_path), "profile": profile}
    markers = spec.get("markers")
    if markers:
        result["markers"] = markers
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate DR-multi-AI SPA report HTML")
    parser.add_argument("--dir", required=True, help="Research root")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="general")
    parser.add_argument("--out", help="Output path (default depends on profile)")
    args = parser.parse_args(argv)
    root = Path(args.dir)
    out = Path(args.out) if args.out else None
    try:
        result = generate_spa_report_file(root, args.profile, out=out)
    except ValueError as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

