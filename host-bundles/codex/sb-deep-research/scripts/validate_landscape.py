#!/usr/bin/env python3
"""Validate solution-landscape run artifacts."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from deps_probe import openpyxl_importable
from matrix_core import comparison_matrix_xlsx_path, default_spa_report_path




def validate(out_dir: Path) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    shortlist_path = out_dir / "shortlist" / "shortlist.json"
    if not shortlist_path.exists():
        errors.append("missing shortlist/shortlist.json")
    else:
        data = json.loads(shortlist_path.read_text(encoding="utf-8"))
        solutions = data.get("solutions") or []
        if len(solutions) != 5:
            errors.append(f"shortlist must have exactly 5 solutions, got {len(solutions)}")

    land = out_dir / "landscape" / "landscape-report.md"
    if not land.exists():
        errors.append("missing landscape/landscape-report.md")

    solutions_dir = out_dir / "solutions"
    if not solutions_dir.is_dir():
        errors.append("missing solutions/ directory")
    else:
        scr_count = sum(1 for d in solutions_dir.iterdir() if (d / "scr.md").exists())
        if scr_count != 5:
            errors.append(f"expected 5 scr.md files, found {scr_count}")

    comp = out_dir / "comparison" / "comparison.json"
    if not comp.exists():
        errors.append("missing comparison/comparison.json")

    xlsx = comparison_matrix_xlsx_path(out_dir, report_html=default_spa_report_path(out_dir))
    # Accept fixtures produced before the directory-slug filename contract
    # was introduced; newly generated outputs still use the canonical path.
    if not xlsx.is_file():
        legacy_xlsx = out_dir / "comparison" / "comparison-matrix.xlsx"
        if legacy_xlsx.is_file():
            xlsx = legacy_xlsx
    if not xlsx.is_file():
        errors.append(f"missing {xlsx.relative_to(out_dir)}")
        if not openpyxl_importable():
            errors.append(
                "openpyxl not installed (pip install -r skills/silver-deep-research/requirements.txt)"
            )

    spa = out_dir / "report.html"
    if not spa.exists():
        errors.append("missing report.html")

    return {"status": "pass" if not errors else "fail", "errors": errors, "warnings": warnings}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    args = parser.parse_args()
    result = validate(Path(args.dir))
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
