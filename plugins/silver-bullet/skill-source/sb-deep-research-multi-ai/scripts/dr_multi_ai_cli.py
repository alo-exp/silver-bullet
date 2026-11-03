#!/usr/bin/env python3
"""CLI for /sb:deep-research-multi-ai composer."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path


DRM_SCRIPTS = Path(__file__).resolve().parent
WORKFLOW_ID = "WF-SILVER-DEEP-RESEARCH-MULTI-AI"
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
    """research/<date>-<slug> under the caller's working directory (their project), never
    inside the installed skill. The slug is one [a-z0-9-] path segment: '/' and '..' in the
    query cannot nest or escape."""
    slug = re.sub(r"[^a-z0-9]+", "-", query.lower()).strip("-")[:80].strip("-") or "research"
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return Path.cwd() / "research" / f"{date}-{slug}"


def _positive_int(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def _is_previous_run(path: Path) -> bool:
    try:
        manifest = json.loads((path / "run_manifest.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return isinstance(manifest, dict) and manifest.get("workflow_id") == WORKFLOW_ID


def force_refusal(output_root: Path) -> str | None:
    """Why --force must not touch `output_root`, or None when it is a previous run of this tool."""
    target = output_root.resolve()
    cwd = Path.cwd().resolve()
    if target == Path(target.anchor) or target == Path.home().resolve():
        return f"{output_root} is the filesystem root or the home directory"
    if target == cwd or target in cwd.parents:
        return f"{output_root} is the working directory or one of its parents"
    if not target.is_dir() or not _is_previous_run(target):
        return f"{output_root} is not a previous {WORKFLOW_ID} run (no matching run_manifest.json)"
    return None


def _generated_for_old_query(path: Path, query: str) -> bool:
    """True for a need profile / scope that dr_live_runner generated for a DIFFERENT query.

    Those name the old topic and would brief the new run on it. The ones generated for the same
    query are carried: a regenerated file would be identical, and one the user edited since (must-haves,
    a category pack) must not be lost.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return False
    topic = query.strip()
    if path.name == "scope.md":
        return text.startswith("# Research scope\n\nResearch topic: ") and not text.startswith(
            f"# Research scope\n\nResearch topic: {topic}\n"
        )
    try:
        profile = json.loads(text)
        return bool(profile.get("auto_assumed")) and profile.get("category") != (topic or "research")
    except (ValueError, AttributeError):
        return False


def carry_over_user_inputs(previous: Path, output_root: Path, query: str = "") -> list[str]:
    """Copy the user's need_profile.json and scope.md from the moved-aside run into the new one.

    A fresh run must keep the user's category pack and must-haves instead of silently
    falling back to an automatic profile. Returns the names copied.
    """
    copied: list[str] = []
    for name in ("need_profile.json", "scope.md"):
        source = previous / name
        if source.is_file() and not source.is_symlink():
            if _generated_for_old_query(source, query):
                continue  # auto-written for the previous query: it would brief the new run on the old topic
            output_root.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, output_root / name)
            copied.append(name)
    return copied


def move_previous_run_aside(output_root: Path) -> Path:
    """Rename a previous run to <name>.replaced-<UTC time>; nothing is deleted."""
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    target = output_root.with_name(f"{output_root.name}.replaced-{stamp}")
    counter = 1
    while target.exists():
        counter += 1
        target = output_root.with_name(f"{output_root.name}.replaced-{stamp}-{counter}")
    output_root.rename(target)
    return target


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
    parser.add_argument("--max-phases", type=_positive_int, help="Limit live phases (partial run, at least 1)")
    parser.add_argument("--timeout-sec", type=int, default=600)
    parser.add_argument(
        "--force",
        action="store_true",
        help="Move a previous run at --output-root aside (renamed, never deleted) before the live run",
    )
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
    moved_aside: Path | None = None
    if output_root.exists() and (args.force or _is_previous_run(output_root)):
        refusal = force_refusal(output_root) if args.force else (
            f"{output_root} already holds a run; pass --force to move it aside"
        )
        if refusal:
            print(json.dumps({"ok": False, "error_code": "FORCE_REFUSED" if args.force else "OUTPUT_ROOT_HAS_RUN",
                              "message": refusal}, indent=2))
            return 2
        moved_aside = move_previous_run_aside(output_root)
        carry_over_user_inputs(moved_aside, output_root, args.query)
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

    if moved_aside is not None:
        live_result["moved_aside"] = str(moved_aside)
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

