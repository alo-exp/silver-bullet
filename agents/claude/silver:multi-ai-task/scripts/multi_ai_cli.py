#!/usr/bin/env python3
"""CLI for /silver:multi-ai-task primitive."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from multi_ai_core import (  # noqa: E402
    PoolSelection,
    dry_run_report,
    host_gate,
)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Silver Bullet multi-ai-task v2 primitive")
    parser.add_argument("--output-root", help="Output root directory (required for live dispatch)")
    parser.add_argument("--ocg-pool", choices=["none", "lite", "regular"], default="lite")
    parser.add_argument("--cursor-pool", choices=["none", "default"], default="default")
    parser.add_argument("--include-only", action="append", default=[])
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--max-agents", type=int, default=11)
    parser.add_argument("--cursor-subscription", choices=["auto", "subscribed", "unsubscribed"], default="auto")
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

    payload = {
        "ok": False,
        "error_code": "MULTI_AI_LIVE_DISPATCH_NOT_READY",
        "message": "Live dispatch requires enabled backends; use --dry-run in Phase A scaffold",
    }
    print(json.dumps(payload, indent=2))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
