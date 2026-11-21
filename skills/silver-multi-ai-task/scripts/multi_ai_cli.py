#!/usr/bin/env python3
"""CLI for /sb:multi-ai-task primitive."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from live_dispatch import backend_availability, run_multi_ai_live, stub_mode  # noqa: E402
from multi_ai_core import (  # noqa: E402
    DEFAULT_CONCURRENCY,
    DEFAULT_MAX_AGENTS,
    BudgetPolicy,
    PoolSelection,
    dry_run_report,
    host_gate,
    output_root_refusal,
    resolve_output_root,
)


def positive_int(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError(f"must be a positive integer, got {value}")
    return number


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Silver Bullet multi-ai-task v2 primitive")
    parser.add_argument("--output-root", help="Output root directory (required for live dispatch)")
    parser.add_argument("--task-prompt", default="", help="Task prompt for live workers")
    parser.add_argument(
        "--phase-id",
        choices=["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"],
        help="Optional DR prompt preset (default: neutral TASK instructions)",
    )
    parser.add_argument("--ocg-pool", choices=["none", "lite", "regular"], default="lite")
    parser.add_argument("--cursor-pool", choices=["none", "default"], default="default")
    parser.add_argument("--include-only", action="append", default=[])
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--max-agents", type=positive_int, default=DEFAULT_MAX_AGENTS)
    parser.add_argument("--concurrency", type=positive_int, default=DEFAULT_CONCURRENCY)
    parser.add_argument("--cursor-subscription", choices=["auto", "subscribed", "unsubscribed"], default="auto")
    parser.add_argument("--timeout-sec", type=positive_int, default=600)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.dry_run and not args.output_root:
        print(json.dumps({"ok": False, "error_code": "OUTPUT_ROOT_REQUIRED", "message": "--output-root required for live dispatch"}, indent=2))
        return 2

    # A dry run is a plan for a run, so it fails the same way a live run does on a host that cannot
    # run it (Cursor and unknown hosts); Claude Code and Codex are the supported hosts.
    gate = host_gate()
    if not gate["ok"]:
        payload = {"ok": False, "error_code": gate["error_code"], "message": gate["message"]}
        print(json.dumps(payload, indent=2))
        return 2

    # The hooks cannot see what this script writes, so it keeps their boundaries itself.
    # Resolved once: the check and every write use this same path (a literal "~" is expanded here).
    output_root = resolve_output_root(args.output_root) if args.output_root else None
    refusal = output_root_refusal(output_root) if output_root else None
    if refusal:
        print(json.dumps({"ok": False, "error_code": "OUTPUT_ROOT_NOT_ALLOWED", "message": refusal}, indent=2))
        return 2

    selection = PoolSelection(
        ocg_pool=args.ocg_pool,
        cursor_pool=args.cursor_pool,
        include_only=args.include_only,
        exclude=args.exclude,
        cursor_subscription=args.cursor_subscription,
    )
    if args.dry_run:
        report = dry_run_report(selection, max_agents=args.max_agents)
        if report.get("ok"):
            # Looks for each backend CLI the plan needs; nothing is started or written.
            report["backend_availability"] = backend_availability(report["resolved_pool"])
        print(json.dumps(report, indent=2))
        return 0 if report.get("ok") else 1

    if stub_mode():
        payload = {
            "ok": False,
            "error_code": "MULTI_AI_LIVE_DISPATCH_NOT_READY",
            "message": "Live dispatch disabled (SB_MULTI_AI_STUB=1); unset to enable",
        }
        print(json.dumps(payload, indent=2))
        return 2

    result = run_multi_ai_live(
        output_root=output_root,
        selection=selection,
        budget=BudgetPolicy(max_agents=args.max_agents, concurrency=args.concurrency),
        task_prompt=args.task_prompt,
        phase_id=args.phase_id,
        timeout_sec=args.timeout_sec,
    )
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
