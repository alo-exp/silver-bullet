#!/usr/bin/env python3
"""Generate DR-multi-AI SPA report HTML (--profile general|landscape)."""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path
from typing import Any, Callable

from skill_paths import ensure_scripts_on_path

ensure_scripts_on_path("silver-deep-research", marker="spa_embed.py")
from spa_embed import safe_json_payload  # noqa: E402

LANDSCAPE_MARKERS = [
    "data-landscape-marker",
    "panel-landscape-grid",
    "landscape-filter-bar",
    "landscape-chart-canvas",
]


def load_consolidation(root: Path) -> dict[str, Any]:
    path = root / "consolidated" / "consolidation.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def load_manifest(root: Path) -> dict[str, Any]:
    path = root / "run_manifest.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


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
    consolidation = load_consolidation(root)
    return {
        "title": manifest.get("query") or "Solution Landscape",
        "research_type": manifest.get("research_type", "solution-landscape"),
        "need_profile": {"category": "landscape"},
        "comparison": {"items": consolidation.get("consensus", [])},
        "landscape": {"solutions": consolidation.get("coverage", {})},
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
    return f"""<!DOCTYPE html>
<html lang="en" data-theme="light" data-landscape-marker="v1">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
body {{ font-family: system-ui, sans-serif; margin: 0; padding: 1rem; }}
#panel-landscape-grid {{ display: grid; gap: 1rem; }}
.landscape-filter-bar {{ display: flex; gap: 0.5rem; margin: 1rem 0; }}
#landscape-chart-canvas {{ min-height: 200px; border: 1px solid #ccc; padding: 1rem; }}
</style>
</head>
<body>
<header><h1>{title}</h1></header>
<div class="landscape-filter-bar" data-landscape-marker="filters">
  <label>Filter <input type="search" id="landscapeFilter" placeholder="Search solutions"></label>
</div>
<section id="panel-landscape-grid" data-tab-marker="overview"></section>
<div id="landscape-chart-canvas" data-landscape-marker="chart"></div>
<script type="application/json" id="report-data">{payload}</script>
<script>
(function() {{
  const data = JSON.parse(document.getElementById('report-data').textContent);
  function esc(s) {{ const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }}
  const grid = document.getElementById('panel-landscape-grid');
  const items = (data.comparison && data.comparison.items) || [];
  grid.innerHTML = items.length
    ? items.map(i => '<article><h3>' + esc(i.text || '') + '</h3><p>support ' + esc(String(i.support_count || 0)) + '</p></article>').join('')
    : '<p>No landscape items yet.</p>';
  document.getElementById('landscape-chart-canvas').textContent = 'Chart placeholder — ' + items.length + ' items';
}})();
</script>
</body>
</html>
"""


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
        "render": render_landscape,
        "validate_root": lambda root: _require_landscape_type(root),
        "markers": LANDSCAPE_MARKERS,
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
    collect = spec["collect"]
    render = spec["render"]
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

