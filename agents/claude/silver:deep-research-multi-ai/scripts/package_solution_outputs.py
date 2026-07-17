#!/usr/bin/env python3
"""
Package solution-landscape / solution-compare outputs for DR-multi-AI.

Runs compare_solutions (JSON + MD + XLSX), then SPA HTML reports.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from skill_paths import ensure_dir_on_path, ensure_scripts_on_path


def package_solution_outputs(
    research_dir: Path,
    *,
    skip_compare: bool = False,
    skip_xlsx: bool = False,
    skip_spa: bool = False,
) -> dict:
    ensure_scripts_on_path("silver-deep-research", marker="compare_solutions.py")
    ensure_dir_on_path(Path(__file__).resolve().parent)
    results: dict = {"dir": str(research_dir)}

    manifest_path = research_dir / "run_manifest.json"
    if not skip_spa and not manifest_path.is_file():
        raise FileNotFoundError(
            "run_manifest.json required for SPA packaging; use --skip-spa or create manifest first"
        )

    if not skip_compare:
        from compare_solutions import compare_solutions

        results["compare"] = compare_solutions(research_dir, emit_xlsx=not skip_xlsx)
    elif not skip_xlsx:
        from generate_comparison_xlsx import generate_comparison_xlsx

        results["xlsx"] = generate_comparison_xlsx(research_dir)

    if not skip_spa:
        from generate_spa_report import generate_spa_report_file

        results["report_general"] = generate_spa_report_file(research_dir, "general")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        rtype = manifest.get("research_type")
        if rtype in {"solution-landscape", "solution-compare"}:
            results["report_landscape"] = generate_spa_report_file(research_dir, "landscape")

    xlsx_path = research_dir / "comparison" / "comparison-matrix.xlsx"
    if xlsx_path.is_file():
        results["comparison_matrix_xlsx"] = str(xlsx_path)

    results["status"] = "ok"
    return results


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Package solution research outputs (compare + XLSX + SPA)",
    )
    parser.add_argument("--dir", required=True, help="Research output directory")
    parser.add_argument("--skip-compare", action="store_true")
    parser.add_argument("--skip-xlsx", action="store_true")
    parser.add_argument("--skip-spa", action="store_true")
    args = parser.parse_args(argv)

    try:
        result = package_solution_outputs(
            Path(args.dir),
            skip_compare=args.skip_compare,
            skip_xlsx=args.skip_xlsx,
            skip_spa=args.skip_spa,
        )
    except Exception as exc:  # noqa: BLE001 — CLI boundary
        print(json.dumps({"status": "error", "reason": str(exc)}), file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
