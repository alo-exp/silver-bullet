#!/usr/bin/env python3
"""CLI for /silver:multi-ai-task primitive."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from live_dispatch import run_multi_ai_live, stub_mode  # noqa: E402
from multi_ai_core import PoolSelection, dry_run_report, host_gate  # noqa: E402


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Silver Bullet multi-ai-task v2 primitive")
    parser.add_argument("--output-root", help="Output root directory (required for live dispatch)")
    parser.add_argument("--task-prompt", default="", help="Task prompt for live workers")
    parser.add_argument("--phase-id", choices=["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"], help="Optional DR phase scope")
    parser.add_argument("--ocg-pool", choices=["none", "lite", "regular"], default="lite")
    parser.add_argument("--cursor-pool", choices=["none", "default"], default="default")
    parser.add_argument("--include-only", action="append", default=[])
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--max-agents", type=int, default=11)
    parser.add_argument("--cursor-subscription", choices=["auto", "subscribed", "unsubscribed"], default="auto")
    parser.add_argument("--timeout-sec", type=int, default=600)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.dry_run and not args.output_root:
        print(json.dumps({"ok": False, "error_code": "OUTPUT_ROOT_REQUIRED", "message": "--output-root required for live dispatch"}), indent=2)
        return 2

    if not args.dry_run:
        gate = host_gate()
        if not gate["ok"]:
            payload = {"ok": False, "error_code": gate["error_code"], "message": gate["message"]}
            print(json.dumps(payload, indent=2))
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
        output_root=Path(args.output_root),
        selection=selection,
        task_prompt=args.task_prompt,
        phase_id=args.phase_id,
        timeout_sec=args.timeout_sec,
    )
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
