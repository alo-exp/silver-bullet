#!/usr/bin/env python3
"""Encoder CLI of sb:review-fix-ladder: ladder resolution, run lifecycle, Policy C, hook entry.

Claude Code only: every rung is a Claude model run as a native read-only subagent (the Agent tool).
On Codex the ladder stops with a clear "not yet verified" message (documented defaults only).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

_LIB_DIR = Path(__file__).resolve().parent / "lib"
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))
import quota_window  # noqa: E402
import rfl_hook  # noqa: E402
import rfl_json  # noqa: E402
import rfl_launcher_policy as policy  # noqa: E402
import rfl_native as native  # noqa: E402
import rfl_policy_c  # noqa: E402

EXIT_REFUSED = 3
EXIT_TAMPER = 4
LIFECYCLE_PHASES = ("review", "verify_1", "verify_2")


def detect_host() -> str:
    runtime = os.environ.get("SILVER_BULLET_RUNTIME", "").strip().lower()
    if runtime in {"claude", "codex"}:
        return runtime
    if any(os.environ.get(k) for k in ("CODEX_CI", "CODEX_THREAD_ID", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE")):
        return "codex"
    if "/.codex/" in os.environ.get("CLAUDE_PLUGIN_ROOT", ""):
        return "codex"
    return "claude"


def resolve_ladder(host: str, project_root: Path | None = None, rungs_spec: str = "") -> dict[str, Any]:
    if host.lower() == "codex":
        return {"host": "codex", "enabled": False, "source": "disabled", "total_rungs": 0, "rungs": [],
                "message": native.CODEX_MESSAGE, "documented_defaults": native.CODEX_DEFAULTS}
    rungs = native.configured_rungs(project_root or Path.cwd(), rungs_spec)
    default = [native.parse_rung(t) for t in native.DEFAULT_RUNGS]
    custom = [(r["model"], r["effort"]) for r in rungs] != default
    return {"host": "claude", "enabled": True, "source": "config" if custom else "default", "total_rungs": len(rungs),
            "rungs": rungs, "spawn_tool": "Agent", "effort_applied": True}


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Review-fix ladder encoder (native Claude subagents).", allow_abbrev=False)
    p.add_argument("--json", action="store_true", help="Emit JSON only")
    p.add_argument("--host", choices=("codex", "claude"), help="Override host detection")
    p.add_argument("--project-root", type=Path, help="Project root (default: current directory)")
    p.add_argument("--run-dir", type=Path, help="RFL run directory (.planning/rfl-<id>/)")
    p.add_argument("--rung-dir", type=Path, help="Rung directory for Policy C / skip artifacts")
    p.add_argument("--rungs", default="", help="Rung override, e.g. 'rungs: +opus:xhigh -haiku:xhigh' or 'sonnet:high opus:high'")
    p.add_argument("--run-id", default="", help="Run id for --start (default: generated)")
    life = p.add_argument_group("run lifecycle (each command checks the order)")
    life.add_argument("--start", action="store_true", help="Create and go live with a run (needs --charter-file)")
    life.add_argument("--charter-file", type=Path, help="JSON: goal, scope, key_tasks, signals")
    life.add_argument("--approve", action="store_true", help="Record Policy E approval of the rung brief (after the user agreed)")
    life.add_argument("--resume", metavar="RUN_ID", help="Make a paused or legacy run live in this session")
    life.add_argument("--issue-ticket", choices=LIFECYCLE_PHASES, metavar="PHASE", help="review|verify_1|verify_2: print the exact spawn parameters")
    life.add_argument("--cancel-ticket", action="store_true", help="Count a ticket whose subagent never launched as a failed attempt")
    life.add_argument("--complete-triage", action="store_true", help="After --write-policy-c: move on from triage")
    life.add_argument("--record-apply", action="store_true", help="After applying ACCEPTed fixes: checks that in-scope files changed")
    life.add_argument("--run-signals", action="store_true", help="Run the charter's verification signals and record the result")
    life.add_argument("--advance", action="store_true", help="Leave the finished rung (Policy C, verify and signals are checked)")
    life.add_argument("--status", action="store_true", help="Print the run state")
    life.add_argument("--abort", metavar="RUN_ID", help="End a run; needs the user's own `RFL ABORT <run-id>` message")
    life.add_argument("--cleanup-legacy-timers", action="store_true", help="Remove leftover launchd agents of the old quota scheduler")
    life.add_argument("--dry-run", action="store_true", help="With --cleanup-legacy-timers: only list")
    life.add_argument("--hook", action="store_true", help="Hook entry point (payload on stdin); used by hooks/review-fix-ladder-guard.sh")
    pol = p.add_argument_group("Policy C and tables")
    pol.add_argument("--write-policy-c", action="store_true")
    pol.add_argument("--assert-policy-c", action="store_true")
    pol.add_argument("--assert-rfl-advance", action="store_true")
    pol.add_argument("--assert-consecutive-clean", action="store_true")
    pol.add_argument("--next-action", default="task", help="task|verify_1|verify_2|next_rung_review|mark_completed|stop")
    pol.add_argument("--current-phase", default=None)
    pol.add_argument("--issue-ledger", action="store_true")
    pol.add_argument("--write-review-brief", action="store_true", help="Policy G: the only legal review brief text")
    pol.add_argument("--issue-table", action="store_true")
    pol.add_argument("--triage-table", action="store_true")
    pol.add_argument("--resolved-table", action="store_true")
    pol.add_argument("--ladder-matrix", action="store_true")
    pol.add_argument("--launcher-steps", action="store_true")
    pol.add_argument("--launch-policy", action="store_true")
    pol.add_argument("--skip-artifact", action="store_true")
    pol.add_argument("--attempts", type=int, default=1)
    pol.add_argument("--outcome", choices=("success", "cannot_launch", "timeout"))
    pol.add_argument("--policy-phase", default="rung", choices=("rung", "post_ladder"))
    pol.add_argument("--rung-id", default=None)
    pol.add_argument("--next-rung", default=None)
    pol.add_argument("--table-json", default=None)
    pol.add_argument("--table-json-file", type=Path, default=None)
    q = p.add_argument_group("quota window classification (contract used by scripts/lib/agent-delegate-common.sh)")
    q.add_argument("--classify-quota-window", action="store_true")
    q.add_argument("--subscription-output", default="", help="Provider output to classify")
    q.add_argument("--subscription-output-file", type=Path)
    q.add_argument("--quota-host", default="")
    q.add_argument("--model", default="")
    q.add_argument("--quota-now", default="")
    return p


def _out(value: Any) -> int:
    print(json.dumps(value, indent=2))
    return 0


def _require(parser: argparse.ArgumentParser, args: argparse.Namespace, *names: str) -> None:
    for name in names:
        if getattr(args, name) is None:
            parser.error(f"--{name.replace('_', '-')} is required here")


def _json_arg(args: argparse.Namespace) -> Any:
    if args.table_json_file is not None:
        return json.loads(args.table_json_file.read_text(encoding="utf-8"))
    if args.table_json:
        return json.loads(args.table_json)
    raise ValueError("JSON payload required (--table-json or --table-json-file)")


def run_policy(parser: argparse.ArgumentParser, args: argparse.Namespace) -> int:
    if args.launcher_steps:
        return _out({"steps": policy.launcher_mandatory_steps()})
    if args.issue_ledger or args.write_review_brief:
        import rfl_issue_ledger as ledger

        rows = None
        if args.table_json or args.table_json_file:
            loaded = _json_arg(args)
            rows = loaded.get("rows") if isinstance(loaded, dict) else loaded
            if not isinstance(rows, list):
                print('ERROR: issue-ledger JSON must be an array or {"rows": [...]}', file=sys.stderr)
                return 2
        if rows is None and args.run_dir is None:
            print("ERROR: --issue-ledger/--write-review-brief requires --run-dir or --table-json", file=sys.stderr)
            return 2
        collected = ledger.collect_issue_ledger(run_dir=args.run_dir, rows=rows)
        print(ledger.render_review_brief(collected) if args.write_review_brief else ledger.render_issue_ledger(collected), end="")
        return 0
    if args.launch_policy:
        if not args.outcome:
            parser.error("--launch-policy requires --outcome")
        return _out(policy.next_launch_action(attempts=args.attempts, outcome=args.outcome, phase=args.policy_phase))
    if args.skip_artifact:
        if not args.outcome or args.rung_id is None:
            parser.error("--skip-artifact requires --rung-id and --outcome")
        payload = policy.skip_retry_artifact(rung=args.rung_id, event="", outcome=args.outcome, attempts=args.attempts,
                                             next_rung=args.next_rung, phase=args.policy_phase)
        if args.rung_dir is not None:
            args.rung_dir.mkdir(parents=True, exist_ok=True)
            (args.rung_dir / "SKIPPED.md").write_text(str(payload["skipped_md"]), encoding="utf-8")
            payload["skipped_md_path"] = str(args.rung_dir / "SKIPPED.md")
        return _out(payload)
    if args.write_policy_c:
        _require(parser, args, "rung_dir")
        body = _json_arg(args)
        if not isinstance(body, dict):
            print("ERROR: Policy C JSON must be an object", file=sys.stderr)
            return 2
        result = rfl_policy_c.write_policy_c(args.rung_dir, body, current_phase=args.current_phase)
        print(result["markdown"], end="")
        if not result["ok"]:
            print("ERROR: " + "; ".join(result["errors"]), file=sys.stderr)
            return 2
        return 0
    if args.assert_policy_c:
        _require(parser, args, "rung_dir")
        result = rfl_policy_c.assert_policy_c(args.rung_dir, current_phase=args.current_phase)
        print(json.dumps({"ok": result["ok"], "errors": result["errors"], "rung_dir": result["rung_dir"]}, indent=2))
        return 0 if result["ok"] else 2
    if args.assert_rfl_advance or args.assert_consecutive_clean:
        action = "next_rung_review" if args.assert_consecutive_clean and args.next_action == "task" else args.next_action
        result = rfl_policy_c.assert_rfl_advance(args.run_dir, rung_dir=args.rung_dir, project_root=args.project_root,
                                                 next_action=action, current_phase=args.current_phase)
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 2
    payload = _json_arg(args)
    if not isinstance(payload, list):
        print("ERROR: table JSON must be an array", file=sys.stderr)
        return 2
    renderer = (policy.render_issue_table if args.issue_table else policy.render_triage_table if args.triage_table
                else policy.render_resolved_table if args.resolved_table else policy.render_ladder_complete_matrix)
    print(renderer(payload), end="")
    return 0


def run_lifecycle(parser: argparse.ArgumentParser, args: argparse.Namespace, root: Path) -> int:
    if args.hook:
        return _out(rfl_hook.run_hook(sys.stdin.read(), root))
    if args.cleanup_legacy_timers:
        return _out({"ok": True, "found": native.cleanup_legacy_timers(dry_run=args.dry_run), "dry_run": args.dry_run})
    if args.start:
        return _out(native.start_run(root, args.charter_file, run_id=args.run_id, rungs_spec=args.rungs))
    if args.resume:
        return _out(native.resume_run(root, args.resume, args.charter_file))
    if args.abort:
        return _out(native.abort_run(root, args.abort))
    _require(parser, args, "run_dir")
    if args.approve:
        return _out(native.approve(root, args.run_dir))
    if args.issue_ticket:
        return _out(native.issue_ticket(root, args.run_dir, args.issue_ticket))
    if args.cancel_ticket:
        return _out(native.cancel_ticket(root, args.run_dir))
    if args.complete_triage:
        return _out(native.complete_triage(root, args.run_dir))
    if args.record_apply:
        return _out(native.record_apply(root, args.run_dir))
    if args.run_signals:
        result = native.run_signals(root, args.run_dir)
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 1
    if args.advance:
        return _out(native.advance(root, args.run_dir))
    return _out(native.status_report(root, args.run_dir))


LIFECYCLE_FLAGS = ("hook", "cleanup_legacy_timers", "start", "resume", "abort", "approve", "issue_ticket", "cancel_ticket",
                   "complete_triage", "record_apply", "run_signals", "advance", "status")
POLICY_FLAGS = ("launcher_steps", "issue_ledger", "write_review_brief", "launch_policy", "skip_artifact", "write_policy_c",
                "assert_policy_c", "assert_rfl_advance", "assert_consecutive_clean", "issue_table", "triage_table",
                "resolved_table", "ladder_matrix")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    root = (args.project_root or Path.cwd()).resolve()
    try:
        if args.classify_quota_window:
            blob = args.subscription_output
            if args.subscription_output_file is not None:
                blob = args.subscription_output_file.read_text(encoding="utf-8")
            return _out(quota_window.classify_quota_window(
                blob, host=args.quota_host, model=args.model, now=quota_window.parse_iso_datetime(args.quota_now)))
        if any(getattr(args, name) for name in LIFECYCLE_FLAGS):
            return run_lifecycle(parser, args, root)
        if any(getattr(args, name) for name in POLICY_FLAGS):
            return run_policy(parser, args)
        payload = resolve_ladder(args.host or detect_host(), root, args.rungs)
        if args.json or not payload["enabled"]:
            return _out(payload)
        print(f"host: {payload['host']}\nsource: {payload['source']}\ntotal_rungs: {payload['total_rungs']}\nrungs:")
        for rung in payload["rungs"]:
            print(f"  {rung['index']}. {rung['model']} / {rung['effort']}")
        return 0
    except native.Tamper as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_TAMPER
    except (native.RflError, rfl_json.BadJson, ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_REFUSED


if __name__ == "__main__":
    sys.exit(main())
