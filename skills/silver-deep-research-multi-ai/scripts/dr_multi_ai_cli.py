#!/usr/bin/env python3
"""CLI for /sb:deep-research-multi-ai composer."""

from __future__ import annotations

import argparse
import json
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path


DRM_SCRIPTS = Path(__file__).resolve().parent
REPO_ROOT = DRM_SCRIPTS.parents[2]
_BOOTSTRAPPED = False


def _bootstrap() -> None:
    global _BOOTSTRAPPED
    if _BOOTSTRAPPED:
        return
    from skill_paths import ensure_dir_on_path, ensure_scripts_on_path

    ensure_scripts_on_path("silver-multi-ai-task", marker="multi_ai_core.py")
    ensure_dir_on_path(DRM_SCRIPTS)
    _BOOTSTRAPPED = True

SOLUTION_RESEARCH_TYPES = frozenset({"solution-landscape", "solution-compare"})


def needs_solution_packaging(research_type: str) -> bool:
    return research_type in SOLUTION_RESEARCH_TYPES


def load_parallel_phases(research_type: str, mode: str) -> list[str]:
    cfg = json.loads((DRM_SCRIPTS.parent / "reference" / "parallel-phases-v1.json").read_text(encoding="utf-8"))
    table = cfg["by_research_type"].get(research_type, cfg["by_research_type"]["default"])
    phases = table.get(mode, [])
    return list(phases)


def default_output_root(query: str) -> Path:
    slug = query.strip().replace(" ", "-").lower()[:80]
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return REPO_ROOT / "research" / f"{date}-{slug}"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Silver Bullet deep-research-multi-ai composer")
    parser.add_argument("query", nargs="?", default="", help="Research question")
    parser.add_argument("--mode", choices=["quick", "standard", "deep", "ultradeep"], default="deep")
    parser.add_argument(
        "--research-type",
        choices=["default", "solution-landscape", "solution-compare"],
        default="default",
    )
    parser.add_argument("--output-root", help="Research output root (research/<date>-<slug>/)")
    parser.add_argument("--ocg-pool", choices=["none", "lite", "regular"], default="lite")
    parser.add_argument("--cursor-pool", choices=["none", "default"], default="default")
    parser.add_argument("--include-only", action="append", default=[], help="Restrict pool to listed agents only (do NOT use for full landscape runs)")
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-phases", type=int, help="Limit live phases (partial run)")
    parser.add_argument("--timeout-sec", type=int, default=600)
    parser.add_argument("--force", action="store_true", help="Clear output-root before live run")
    parser.add_argument(
        "--package-only",
        action="store_true",
        help="Run solution packaging (compare + XLSX + SPA) on --output-root",
    )
    parser.add_argument("--skip-compare", action="store_true")
    parser.add_argument("--skip-xlsx", action="store_true")
    parser.add_argument("--skip-spa", action="store_true")
    parser.add_argument("--cursor-subscription", choices=["auto", "subscribed", "unsubscribed"], default="auto")
    return parser.parse_args(argv)


def _package_solution_outputs(args: argparse.Namespace) -> int:
    if not needs_solution_packaging(args.research_type):
        print(json.dumps({"ok": False, "error_code": "SOLUTION_PACKAGING_TYPE_MISMATCH", "message": "--package-only requires solution-landscape or solution-compare"}, indent=2))
        return 2
    if not args.output_root:
        print(json.dumps({"ok": False, "error_code": "OUTPUT_ROOT_REQUIRED", "message": "--package-only requires --output-root"}, indent=2))
        return 2

    try:
        _bootstrap()
        from package_solution_outputs import package_solution_outputs  # noqa: E402

        result = package_solution_outputs(Path(args.output_root), skip_compare=args.skip_compare, skip_xlsx=args.skip_xlsx, skip_spa=args.skip_spa)
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"ok": False, "error_code": "SOLUTION_PACKAGING_FAILED", "message": str(exc)}, indent=2))
        return 1

    print(json.dumps({"ok": True, **result}, indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.package_only:
        return _package_solution_outputs(args)

    if not args.query:
        print(json.dumps({"ok": False, "error_code": "QUERY_REQUIRED", "message": "research query positional required"}, indent=2))
        return 2

    if args.include_only and args.research_type in SOLUTION_RESEARCH_TYPES and not args.max_phases:
        import warnings

        warnings.warn(
            "--include-only replaces the full pool; omit it for full solution-landscape runs "
            f"(got {len(args.include_only)} agent(s) instead of lite+default ~11)",
            stacklevel=1,
        )

    parallel = load_parallel_phases(args.research_type, args.mode)
    _bootstrap()
    from multi_ai_core import PoolSelection, dry_run_report, host_gate  # noqa: E402

    selection = PoolSelection(
        ocg_pool=args.ocg_pool,
        cursor_pool=args.cursor_pool,
        include_only=args.include_only,
        exclude=args.exclude,
        cursor_subscription=args.cursor_subscription,
    )

    if args.dry_run:
        report = dry_run_report(selection)
        report["parallel_phases"] = parallel
        if not parallel and args.mode not in {"quick"}:
            report["ok"] = False
            report["error_code"] = "EMPTY_PARALLEL_PHASES"
            report["message"] = f"no parallel phases for research_type={args.research_type!r} mode={args.mode!r}"
        report["research_type"] = args.research_type
        report["mode"] = args.mode
        if needs_solution_packaging(args.research_type):
            report["solution_packaging"] = {
                "script": "package_solution_outputs.py",
                "invoke": "--package-only --output-root <dir>",
                "artifacts": ["comparison/comparison-matrix.xlsx", "report.html", "landscape-report.html"],
            }
        print(json.dumps(report, indent=2))
        return 0 if report.get("ok") else 1

    gate = host_gate()
    if not gate["ok"]:
        print(json.dumps({"ok": False, "error_code": gate["error_code"], "message": gate.get("message", "")}, indent=2))
        return 2

    output_root = Path(args.output_root) if args.output_root else default_output_root(args.query)
    if args.force and output_root.exists():
        shutil.rmtree(output_root)
    os.environ.setdefault("SB_HOST", "cursor")

    from dr_live_runner import run_dr_live  # noqa: E402

    try:
        live_result = run_dr_live(
            query=args.query,
            output_root=output_root,
            selection=selection,
            parallel_phases=parallel,
            mode=args.mode,
            research_type=args.research_type,
            max_phases=args.max_phases,
            timeout_sec=args.timeout_sec,
        )
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"ok": False, "error_code": "DR_LIVE_RUN_FAILED", "message": str(exc)}, indent=2))
        return 1

    if needs_solution_packaging(args.research_type) and live_result.get("ok"):
        from package_solution_outputs import package_solution_outputs  # noqa: E402

        try:
            pkg = package_solution_outputs(output_root)
            live_result["packaging"] = pkg
        except Exception as exc:  # noqa: BLE001
            live_result["packaging_error"] = str(exc)

    print(json.dumps(live_result, indent=2))
    return 0 if live_result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

