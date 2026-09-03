#!/usr/bin/env python3
"""Validate solution-compare run artifacts."""
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

    req_path = out_dir / "solutions_requested.json"
    if not req_path.exists():
        errors.append("missing solutions_requested.json")
    else:
        data = json.loads(req_path.read_text(encoding="utf-8"))
        names = data.get("solutions") or data.get("names") or []
        if len(names) < 2:
            errors.append(f"need N>=2 named solutions, got {len(names)}")
        if len(names) > 12:
            warnings.append(f"soft warn: {len(names)} solutions exceeds practical limit of 12")

    if (out_dir / "shortlist" / "shortlist.json").exists():
        errors.append("shortlist.json must not exist in solution-compare mode")

    solutions_dir = out_dir / "solutions"
    if not solutions_dir.is_dir():
        errors.append("missing solutions/ directory")
    elif req_path.exists():
        req_data = json.loads(req_path.read_text(encoding="utf-8"))
        expected = len(req_data.get("solutions") or req_data.get("names") or [])
        scr_count = sum(1 for d in solutions_dir.iterdir() if (d / "scr.md").exists())
        if scr_count != expected:
            errors.append(f"expected {expected} SCR dirs, found {scr_count}")

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

    return {
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "warnings": warnings,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    args = parser.parse_args()
    result = validate(Path(args.dir))
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
