#!/usr/bin/env python3
"""
Generate serverless single-file report.html with inline JSON payload.

No HTTP server required — works under file:// and Cursor Simple Browser.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Any

from spa_embed import safe_json_payload


def load_json(path: Path) -> dict[str, Any] | list[Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def collect_report_data(out_dir: Path) -> dict[str, Any]:
    manifest = load_json(out_dir / "run_manifest.json") or {}
    need = load_json(out_dir / "need_profile.json") or {}
    comparison = load_json(out_dir / "comparison" / "comparison.json") or {}
    shortlist = load_json(out_dir / "shortlist" / "shortlist.json")
    solutions_requested = load_json(out_dir / "solutions_requested.json")

    scrs: list[dict[str, Any]] = []
    sol_dir = out_dir / "solutions"
    if sol_dir.is_dir():
        for d in sorted(sol_dir.iterdir()):
            scr_path = d / "scr.md"
            if scr_path.exists():
                scrs.append({
                    "slug": d.name,
                    "title": d.name.replace("-", " ").title(),
                    "body": scr_path.read_text(encoding="utf-8")[:12000],
                })

    landscape_md = ""
    land_path = out_dir / "landscape" / "landscape-report.md"
    if land_path.exists():
        landscape_md = land_path.read_text(encoding="utf-8")[:20000]

    decision = ""
    dec_path = out_dir / "decision-record.md"
    if dec_path.exists():
        decision = dec_path.read_text(encoding="utf-8")[:8000]

    return {
        "title": manifest.get("question") or need.get("category") or "Solution Research",
        "research_type": manifest.get("research_type", "default"),
        "need_profile": need,
        "comparison": comparison,
        "shortlist": shortlist,
        "solutions_requested": solutions_requested,
        "landscape_excerpt": landscape_md,
        "scrs": scrs,
        "decision_excerpt": decision,
        "generated_by": "silver-deep-research/generate_report_spa.py",
    }


def render_html(data: dict[str, Any]) -> str:
    payload = safe_json_payload(data)
    title = html.escape(str(data.get("title", "Research Report")))
    return f"""<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
:root {{
  --bg: #f8f9fc; --surface: #fff; --border: #e2e8f0;
  --text: #0f172a; --muted: #64748b; --accent: #4f46e5;
}}
[data-theme="dark"] {{
  --bg: #0a0a0f; --surface: #12121a; --border: #1e293b;
  --text: #e2e8f0; --muted: #94a3b8;
}}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); line-height: 1.5; }}
header {{ padding: 1rem 1.5rem; border-bottom: 1px solid var(--border); background: var(--surface); }}
h1 {{ font-size: 1.25rem; }}
nav {{ display: flex; gap: 0.5rem; flex-wrap: wrap; padding: 0.75rem 1.5rem; border-bottom: 1px solid var(--border); background: var(--surface); }}
nav button {{ border: 1px solid var(--border); background: transparent; padding: 0.4rem 0.75rem; border-radius: 6px; cursor: pointer; color: var(--text); }}
nav button.active {{ background: var(--accent); color: #fff; border-color: var(--accent); }}
main {{ padding: 1.5rem; max-width: 1100px; margin: 0 auto; }}
.panel {{ display: none; }}
.panel.active {{ display: block; }}
table {{ width: 100%; border-collapse: collapse; font-size: 0.9rem; margin-top: 1rem; }}
th, td {{ border: 1px solid var(--border); padding: 0.4rem 0.6rem; text-align: left; }}
th {{ background: var(--surface); }}
pre {{ white-space: pre-wrap; background: var(--surface); padding: 1rem; border-radius: 8px; border: 1px solid var(--border); font-size: 0.85rem; max-height: 60vh; overflow: auto; }}
.filter-bar {{ margin: 0.75rem 0; display: flex; gap: 0.5rem; flex-wrap: wrap; align-items: center; }}
#themeToggle {{ margin-left: auto; }}
.tick {{ color: #059669; font-weight: bold; }}
</style>
</head>
<body>
<header>
  <h1 id="pageTitle">{title}</h1>
  <p style="color:var(--muted);font-size:0.85rem;margin-top:0.25rem">Serverless SPA — no local server required</p>
</header>
<nav id="tabNav" role="tablist">
  <button type="button" data-tab="overview" class="active">Overview</button>
  <button type="button" data-tab="landscape">Landscape</button>
  <button type="button" data-tab="scrs">SCRs</button>
  <button type="button" data-tab="matrix">Matrix</button>
  <button type="button" data-tab="recommendation">Recommendation</button>
  <button type="button" id="themeToggle">Theme</button>
</nav>
<main>
  <section id="panel-overview" class="panel active" data-tab-marker="overview"></section>
  <section id="panel-landscape" class="panel" data-tab-marker="landscape"></section>
  <section id="panel-scrs" class="panel" data-tab-marker="scrs"></section>
  <section id="panel-matrix" class="panel" data-tab-marker="matrix"></section>
  <section id="panel-recommendation" class="panel" data-tab-marker="recommendation"></section>
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

  document.getElementById('themeToggle').addEventListener('click', () => {{
    const html = document.documentElement;
    html.dataset.theme = html.dataset.theme === 'dark' ? 'light' : 'dark';
  }});

  const ov = document.getElementById('panel-overview');
  const np = data.need_profile || {{}};
  ov.innerHTML = '<h2>Need profile</h2><ul>'
    + '<li><strong>Category:</strong> ' + esc(np.category || '—') + '</li>'
    + '<li><strong>Audience:</strong> ' + esc(np.audience || '—') + '</li>'
    + '<li><strong>License:</strong> ' + esc(np.license_preference || '—') + '</li>'
    + '<li><strong>Must-haves:</strong> ' + esc((np.must_haves || []).join(', ') || '—') + '</li>'
    + '</ul><p style="margin-top:1rem;color:var(--muted)">Research type: ' + esc(data.research_type || 'default') + '</p>';

  const land = document.getElementById('panel-landscape');
  land.innerHTML = data.landscape_excerpt
    ? '<pre>' + esc(data.landscape_excerpt) + '</pre>'
    : '<p>No landscape section (compare-only run or survey pending).</p>';

  const scrPanel = document.getElementById('panel-scrs');
  if ((data.scrs || []).length) {{
    scrPanel.innerHTML = data.scrs.map(s =>
      '<details style="margin-bottom:0.75rem"><summary><strong>' + esc(s.title) + '</strong></summary><pre>' + esc(s.body) + '</pre></details>'
    ).join('');
  }} else {{
    scrPanel.innerHTML = '<p>No SCR artifacts yet.</p>';
  }}

  const matrix = document.getElementById('panel-matrix');
  const cmp = data.comparison || {{}};
  const rankings = cmp.rankings || [];
  const rows = (cmp.rows || []).filter(r => r.type === 'feature');
  const solutions = rankings.map(r => r.solution);
  let table = '';
  if (solutions.length) {{
    table += '<table id="matrixTable"><thead><tr><th>Feature</th><th>Priority</th>';
    solutions.forEach(s => {{ table += '<th data-sort>' + esc(s) + '</th>'; }});
    table += '</tr></thead><tbody>';
    rows.forEach(row => {{
      table += '<tr><td>' + esc(row.name) + '</td><td>' + esc(row.priority) + '</td>';
      solutions.forEach(s => {{
        const v = (row.solutions || {{}})[s] || '';
        table += '<td class="' + (v ? 'tick' : '') + '">' + esc(v) + '</td>';
      }});
      table += '</tr>';
    }});
    table += '</tbody></table>';
  }} else {{
    table += '<p>Matrix not built yet.</p>';
  }}
  matrix.innerHTML = table;

  const rec = document.getElementById('panel-recommendation');
  let recHtml = '';
  if (cmp.winner) {{
    recHtml += '<h2>Winner: ' + esc(cmp.winner) + '</h2>';
    if (cmp.runner_up) recHtml += '<p>Runner-up: ' + esc(cmp.runner_up) + '</p>';
    recHtml += '<ol>' + rankings.map(r => '<li>' + esc(r.solution) + ' — score ' + r.score + '</li>').join('') + '</ol>';
  }}
  if (data.decision_excerpt) recHtml += '<pre>' + esc(data.decision_excerpt) + '</pre>';
  rec.innerHTML = recHtml || '<p>Recommendation pending synthesis.</p>';
}})();
</script>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate serverless report.html SPA")
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--out", help="Output path (default: dir/report.html)")
    args = parser.parse_args()

    out_dir = Path(args.dir)
    out_path = Path(args.out) if args.out else out_dir / "report.html"
    data = collect_report_data(out_dir)
    out_path.write_text(render_html(data), encoding="utf-8")
    print(json.dumps({"status": "ok", "out": str(out_path)}))


if __name__ == "__main__":
    main()

