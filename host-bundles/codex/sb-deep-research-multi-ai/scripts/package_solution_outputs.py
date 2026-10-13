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

from skill_paths import ensure_dir_on_path, ensure_multi_ai_scripts_on_path, ensure_scripts_on_path

from compression_markers import assert_file_free_of_compression_markers


def package_solution_outputs(
    research_dir: Path,
    *,
    skip_compare: bool = False,
    skip_xlsx: bool = False,
    skip_spa: bool = False,
) -> dict:
    ensure_scripts_on_path("silver-deep-research", marker="compare_solutions.py")
    # Prefer skills/silver-deep-research-multi-ai/scripts so agent/plugin mirrors
    # always pick up landscape synthesis, materialize, template, and SPA render.
    ensure_multi_ai_scripts_on_path()
    ensure_dir_on_path(Path(__file__).resolve().parent)
    results: dict = {"dir": str(research_dir)}

    manifest_path = research_dir / "run_manifest.json"
    manifest: dict | None = None
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not skip_spa and manifest is None:
        raise FileNotFoundError(
            "run_manifest.json required for SPA packaging; use --skip-spa or create manifest first"
        )

    research_type = (manifest or {}).get("research_type")
    is_landscape = research_type in {"solution-landscape", "solution-compare"}

    if is_landscape:
        from materialize_solution_artifacts import materialize_solution_artifacts

        results["materialize"] = materialize_solution_artifacts(research_dir)

    if not skip_compare:
        from compare_solutions import compare_solutions

        results["compare"] = compare_solutions(research_dir, emit_xlsx=not skip_xlsx)
    elif not skip_xlsx:
        from generate_comparison_xlsx import generate_comparison_xlsx

        results["xlsx"] = generate_comparison_xlsx(research_dir)

    if not skip_spa:
        from generate_spa_report import generate_spa_report_file

        results["report_general"] = generate_spa_report_file(research_dir, "general")
        if is_landscape:
            from synthesize_landscape import synthesize_landscape

            results["landscape_synthesis"] = synthesize_landscape(research_dir, force=True)
            from landscape_preview_render import render_landscape_outputs

            results["report_landscape"] = render_landscape_outputs(research_dir)
            from validate_landscape_content import validate_landscape_content

            content_gate = validate_landscape_content(research_dir)
            results["landscape_content_gate"] = content_gate
            if content_gate.get("status") != "pass":
                raise ValueError(
                    "landscape content quality gate failed: "
                    + "; ".join(content_gate.get("errors") or [])
                )
            assert_file_free_of_compression_markers(
                research_dir / "landscape" / "landscape-report.md",
                label="landscape/landscape-report.md",
            )
            assert_file_free_of_compression_markers(
                research_dir / "landscape-report.html",
                label="landscape-report.html",
            )

    xlsx_path = None
    ensure_scripts_on_path("silver-deep-research", marker="matrix_core.py")
    from matrix_core import comparison_matrix_xlsx_path  # noqa: E402

    candidate = comparison_matrix_xlsx_path(research_dir)
    if candidate.is_file():
        xlsx_path = candidate
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

