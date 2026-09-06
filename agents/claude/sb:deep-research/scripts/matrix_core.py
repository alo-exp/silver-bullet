"""Shared matrix scoring constants for compare_solutions and XLSX tools."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

WEIGHTS: dict[str, int] = {
    "Critical": 5,
    "Very High": 4,
    "High": 3,
    "Medium": 2,
    "Low": 1,
}

TICK = "\u2714"
# Excel COUNTIF/COUNTIFS criterion — must match ticks only, not em-dash placeholders.
TICK_CRITERION = TICK


def research_dir_slug(research_dir: Path) -> str:
    """Return the DR research directory basename (slug)."""
    return (research_dir.name or "research").strip() or "research"


def comparison_matrix_xlsx_filename(dir_slug: str) -> str:
    """Return `{dir_slug}-comparison-matrix.xlsx` for a research directory slug."""
    slug = (dir_slug or "research").strip() or "research"
    return f"{slug}-comparison-matrix.xlsx"


def default_spa_report_path(research_dir: Path) -> Path:
    """Pick the SPA HTML report path for landscape vs general profiles."""
    manifest_path = research_dir / "run_manifest.json"
    rtype: str | None = None
    if manifest_path.is_file():
        try:
            rtype = json.loads(manifest_path.read_text(encoding="utf-8")).get("research_type")
        except (json.JSONDecodeError, OSError):
            rtype = None
    landscape = research_dir / "landscape-report.html"
    if rtype in ("solution-landscape", "solution-compare"):
        return landscape
    if landscape.is_file():
        return landscape
    return research_dir / "report.html"


def comparison_matrix_xlsx_path(
    research_dir: Path,
    *,
    report_html: Path | None = None,
) -> Path:
    """Resolved path: comparison/{dir-slug}-comparison-matrix.xlsx."""
    _ = report_html  # retained for call-site compatibility; naming uses dir slug only
    name = comparison_matrix_xlsx_filename(research_dir_slug(research_dir))
    return research_dir / "comparison" / name


def comparison_matrix_xlsx_href(
    research_dir: Path,
    *,
    report_html: Path | None = None,
) -> str | None:
    """Relative href from research root when the matrix XLSX exists."""
    path = comparison_matrix_xlsx_path(research_dir, report_html=report_html)
    if not path.is_file():
        return None
    try:
        return str(path.relative_to(research_dir))
    except ValueError:
        return str(path)


def priority_weight(priority: str) -> int:
    return WEIGHTS.get(priority, 1)


def score_solutions_from_rows(
    rows: list[dict[str, Any]],
    solutions: list[str],
) -> dict[str, int]:
    """Sum weighted ticks per solution from comparison row dicts."""
    scores = {s: 0 for s in solutions}
    for row in rows:
        if row.get("type") != "feature":
            continue
        wt = priority_weight(str(row.get("priority", "Medium")))
        sol_cells = row.get("solutions") or {}
        for sol in solutions:
            if sol_cells.get(sol) == TICK:
                scores[sol] += wt
    return scores

