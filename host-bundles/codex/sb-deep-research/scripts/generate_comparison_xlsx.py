#!/usr/bin/env python3
"""
Emit comparison/{dir-slug}-comparison-matrix.xlsx from comparison.json + need_profile.json.

Uses MultAI-ported matrix_builder (create) and matrix_ops (reorder by score).
Weighted score row uses Excel COUNTIFS formulas aligned with matrix_core.WEIGHTS.
Naming: `{research-dir-basename}-comparison-matrix.xlsx` under comparison/ (e.g.
2026-07-19-agentic-sdlc-orchestration-landscape-fullpool/ →
comparison/2026-07-19-agentic-sdlc-orchestration-landscape-fullpool-comparison-matrix.xlsx).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from matrix_builder import build_matrix
from matrix_core import TICK, comparison_matrix_xlsx_path
from matrix_ops import reorder_columns_by_score


def _solution_order(comparison: dict[str, Any]) -> list[str]:
    rankings = comparison.get("rankings") or []
    if rankings:
        return [str(r["solution"]) for r in rankings if r.get("solution")]
    for row in comparison.get("rows") or []:
        if row.get("type") == "feature" and row.get("solutions"):
            return list(row["solutions"].keys())
    return []


def comparison_to_builder_config(
    comparison: dict[str, Any],
    need: dict[str, Any],
) -> dict[str, Any]:
    """Map DR comparison.json rows to matrix_builder config."""
    solutions = _solution_order(comparison)
    categories: list[dict[str, Any]] = []
    current_name: str | None = None
    current_features: list[dict[str, str]] = []

    for row in comparison.get("rows") or []:
        row_type = row.get("type")
        if row_type == "category":
            if current_name and current_features:
                categories.append({"name": current_name, "features": current_features})
            current_name = str(row.get("name") or "General")
            current_features = []
            continue
        if row_type != "feature":
            continue
        fname = str(row.get("name") or "").strip()
        if not fname:
            continue
        current_features.append(
            {"name": fname, "priority": str(row.get("priority") or "Medium")}
        )

    if current_name and current_features:
        categories.append({"name": current_name, "features": current_features})

    platforms: list[dict[str, Any]] = []
    for sol in solutions:
        ticked: list[str] = []
        for row in comparison.get("rows") or []:
            if row.get("type") != "feature":
                continue
            if row.get("solutions", {}).get(sol) == TICK:
                ticked.append(str(row["name"]))
        platforms.append({"name": sol, "features": ticked})

    category = str(need.get("category") or "Solution")
    persona_id = need.get("persona_id")
    title = f"{category} — Capability Comparison Matrix"
    if persona_id:
        title = f"{category} ({persona_id}) — Capability Comparison Matrix"

    return {
        "title": title,
        "categories": categories,
        "platforms": platforms,
    }


def generate_comparison_xlsx(
    research_dir: Path,
    *,
    comparison_path: Path | None = None,
    need_profile_path: Path | None = None,
    out_path: Path | None = None,
    report_html: Path | None = None,
    reorder: bool = True,
) -> dict[str, Any]:
    comp_path = comparison_path or (research_dir / "comparison" / "comparison.json")
    need_path = need_profile_path or (research_dir / "need_profile.json")
    xlsx_path = out_path or comparison_matrix_xlsx_path(
        research_dir, report_html=report_html
    )

    comparison = json.loads(comp_path.read_text(encoding="utf-8"))
    need: dict[str, Any] = {}
    if need_path.is_file():
        need = json.loads(need_path.read_text(encoding="utf-8"))

    config = comparison_to_builder_config(comparison, need)
    if not config["platforms"]:
        raise ValueError("comparison.json has no solution columns for XLSX export")
    if not config["categories"]:
        raise ValueError("comparison.json has no feature rows for XLSX export")

    xlsx_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = xlsx_path.with_suffix(".tmp.xlsx")
    try:
        build_result = build_matrix(config, str(tmp_path))
        reorder_result: dict[str, Any] = {}
        if reorder and len(config["platforms"]) > 1:
            reorder_result = reorder_columns_by_score(str(tmp_path), str(xlsx_path))
        else:
            tmp_path.replace(xlsx_path)
    finally:
        tmp_path.unlink(missing_ok=True)

    return {
        "status": "ok",
        "output": str(xlsx_path),
        "platforms": build_result.get("platform_names", []),
        "features": build_result.get("features", 0),
        "reorder": reorder_result,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate weighted comparison-matrix.xlsx from comparison.json",
    )
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument(
        "--comparison",
        help="comparison.json path (default: <dir>/comparison/comparison.json)",
    )
    parser.add_argument(
        "--need-profile",
        help="need_profile.json path (default: <dir>/need_profile.json)",
    )
    parser.add_argument(
        "--out",
        help="Output .xlsx path (default: comparison/{dir-slug}-comparison-matrix.xlsx)",
    )
    parser.add_argument(
        "--report-html",
        help="Deprecated; XLSX naming uses research directory slug only",
    )
    parser.add_argument(
        "--no-reorder",
        action="store_true",
        help="Skip reorder-columns-by-score after build",
    )
    args = parser.parse_args(argv)

    research_dir = Path(args.dir)
    try:
        result = generate_comparison_xlsx(
            research_dir,
            comparison_path=Path(args.comparison) if args.comparison else None,
            need_profile_path=Path(args.need_profile) if args.need_profile else None,
            out_path=Path(args.out) if args.out else None,
            report_html=Path(args.report_html) if args.report_html else None,
            reorder=not args.no_reorder,
        )
    except Exception as exc:  # noqa: BLE001 — CLI boundary
        print(json.dumps({"status": "error", "reason": str(exc)}), file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

