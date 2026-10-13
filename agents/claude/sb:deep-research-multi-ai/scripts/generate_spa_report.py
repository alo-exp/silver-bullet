#!/usr/bin/env python3
"""Generate DR-multi-AI SPA report HTML (--profile general|landscape).

Landscape HTML+PDF contracts live in landscape_preview_render.render_landscape_outputs().
This module keeps the general (tabbed) report and routes --profile landscape there.
"""

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


PROFILES: dict[str, dict[str, Any]] = {
    "general": {
        "default_out": "report.html",
        "collect": collect_general,
        "render": render_general,
        "validate_root": None,
    },
    "landscape": {
        "default_out": "landscape-report.html",
        "collect": None,
        "render": None,  # landscape_preview_render.render_landscape_outputs
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
        from landscape_preview_render import render_landscape_outputs

        return render_landscape_outputs(root, out=out_path)

    collect = spec["collect"]
    render = spec["render"]
    if collect is None or render is None:
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
