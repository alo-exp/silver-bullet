#!/usr/bin/env python3
"""RFL launcher policy: launch retry/skip, issue tables, default /sb:agent-* routing."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

RFL_SEVERITIES = ("HIGH", "MED", "LOW", "NIT")
LAUNCH_FAIL_OUTCOMES = frozenset({"cannot_launch", "timeout"})
DEFAULT_AVAILABLE_HOSTS = ("pi", "opencode", "cursor", "codex", "claude", "gemini-cli")
GROK_SUBSTITUTE_MODEL = "cursor-grok-4.6-high"
GROK_SUBSTITUTE_HOSTS = frozenset({"opencode", "pi"})
LAUNCHER_MANDATORY_STEPS = (
    "policy_c_artifact",
    "issue_table",
    "launcher_triage",
    "triage_table",
    "launcher_fix",
    "resolved_table",
    "issue_ledger_brief",
    "ladder_complete_matrix",
)

AGENT_HOST_CATALOG: dict[str, dict[str, str]] = {
    "cursor": {
        "host": "cursor",
        "skill": "silver-agent-cursor",
        "route": "/sb:agent-cursor",
        "invoke": "scripts/agent-cursor-delegate.sh",
    },
    "codex": {
        "host": "codex",
        "skill": "silver-agent-codex",
        "route": "/sb:agent-codex",
        "invoke": "scripts/agent-codex/invoke.sh",
    },
    "claude": {
        "host": "claude",
        "skill": "silver-agent-claude",
        "route": "/sb:agent-claude",
        "invoke": "scripts/agent-claude/invoke.sh",
    },
    "pi": {
        "host": "pi",
        "skill": "silver-agent-pi",
        "route": "/sb:agent-pi",
        "invoke": "scripts/agent-pi-delegate.sh",
    },
    "opencode": {
        "host": "opencode",
        "skill": "silver-agent-opencode",
        "route": "/sb:agent-opencode",
        "invoke": "scripts/agent-opencode-delegate.sh",
    },
    "gemini-cli": {
        "host": "gemini-cli",
        "skill": "gemini-cli",
        "route": "gemini",
        "invoke": "gemini",
    },
}

USER_AGENT_ALIASES: dict[str, str] = {
    "cursor": "cursor",
    "agent-cursor": "cursor",
    "silver-agent-cursor": "cursor",
    "/sb:agent-cursor": "cursor",
    "codex": "codex",
    "agent-codex": "codex",
    "silver-agent-codex": "codex",
    "/sb:agent-codex": "codex",
    "claude": "claude",
    "agent-claude": "claude",
    "silver-agent-claude": "claude",
    "/sb:agent-claude": "claude",
    "pi": "pi",
    "agent-pi": "pi",
    "silver-agent-pi": "pi",
    "/sb:agent-pi": "pi",
    "opencode": "opencode",
    "agent-opencode": "opencode",
    "silver-agent-opencode": "opencode",
    "/sb:agent-opencode": "opencode",
    "gemini": "gemini-cli",
    "gemini-cli": "gemini-cli",
}

SEVERITY_ALIASES: dict[str, str] = {
    "HIGH": "HIGH",
    "HIGHS": "HIGH",
    "BLOCKER": "HIGH",
    "BLOCKERS": "HIGH",
    "MED": "MED",
    "MEDIUM": "MED",
    "MEDIUMS": "MED",
    "LOW": "LOW",
    "LOWS": "LOW",
    "NIT": "NIT",
    "NITS": "NIT",
    "NITPICK": "NIT",
    "NITPICKS": "NIT",
}


def model_family(model: str) -> str:
    slug = (model or "").strip().lower()
    if not slug:
        return "other"
    if slug.startswith(("gpt-", "chatgpt-", "sb-gpt-")):
        return "gpt"
    if slug.startswith(("opus-", "claude-", "sb-opus-", "sb-claude-")):
        return "claude"
    if "gemini" in slug:
        return "gemini"
    if "grok" in slug:
        return "grok"
    if slug.startswith("composer-") or "composer" in slug:
        return "composer"
    return "other"


def normalize_user_agent(user_agent: str | None) -> str | None:
    if user_agent is None:
        return None
    raw = user_agent.strip().lower()
    if not raw:
        return None
    return USER_AGENT_ALIASES.get(raw, raw)


def _host_payload(host: str, *, source: str, model: str, family: str) -> dict[str, Any]:
    catalog = AGENT_HOST_CATALOG.get(
        host,
        {
            "host": host,
            "skill": host,
            "route": host,
            "invoke": "",
        },
    )
    return {
        "model": model,
        "family": family,
        "host": catalog["host"],
        "skill": catalog.get("skill"),
        "route": catalog.get("route"),
        "invoke": catalog.get("invoke"),
        "source": source,
        "preserves_host_mode": True,
        "user_override": source == "user_override",
    }


def default_agent_host_route(
    model: str,
    *,
    user_agent: str | None = None,
    available_hosts: Iterable[str] | None = None,
) -> dict[str, Any]:
    """Map a model family onto a /sb:agent-* host.

    User override always wins. GPT/Claude stay on Codex/Claude unless the user
    named a different agent. Do not smash host ``--mode`` permission flags.
    """
    available = tuple(available_hosts) if available_hosts is not None else DEFAULT_AVAILABLE_HOSTS
    family = model_family(model)
    override = normalize_user_agent(user_agent)
    if override:
        return _host_payload(override, source="user_override", model=model, family=family)
    if family in {"grok", "composer"}:
        return _host_payload("cursor", source="default", model=model, family=family)
    if family == "gpt":
        return _host_payload("codex", source="default", model=model, family=family)
    if family == "claude":
        return _host_payload("claude", source="default", model=model, family=family)
    if family == "gemini":
        for host in ("gemini-cli", "pi", "opencode", "cursor"):
            if host in available:
                return _host_payload(host, source="gemini_cascade", model=model, family=family)
        return _host_payload("cursor", source="gemini_cascade", model=model, family=family)
    for host in ("pi", "opencode"):
        if host in available:
            return _host_payload(host, source="other_default", model=model, family=family)
    if available:
        return _host_payload(str(available[0]), source="other_fallback", model=model, family=family)
    return _host_payload("opencode", source="other_fallback", model=model, family=family)


def next_launch_action(
    *,
    attempts: int,
    outcome: str,
    phase: str = "rung",
    host: str | None = None,
) -> dict[str, Any]:
    """Launch/timeout retry: retry once immediately, then skip; OpenCode/Pi substitute Grok 4.6 High."""
    outcome_n = (outcome or "").strip().lower()
    phase_n = (phase or "rung").strip().lower()
    failed_host = normalize_user_agent(host)
    if attempts < 1:
        raise ValueError("attempts must be >= 1")
    if phase_n not in {"rung", "post_ladder"}:
        raise ValueError(f"unsupported phase {phase!r}")
    if outcome_n == "success":
        return {
            "action": "recovered" if phase_n == "post_ladder" else "continue",
            "outcome": outcome_n,
            "phase": phase_n,
            "attempts": attempts,
            "skipped": False,
            "retry": False,
            "retry_kind": None,
            "post_ladder_retry_pending": False,
            "post_ladder_retry_done": phase_n == "post_ladder",
        }
    if outcome_n not in LAUNCH_FAIL_OUTCOMES:
        raise ValueError(f"unsupported outcome {outcome!r}")
    if phase_n == "rung":
        if attempts <= 1:
            return {
                "action": "retry_immediate",
                "outcome": outcome_n,
                "phase": phase_n,
                "attempts": attempts,
                "skipped": False,
                "retry": True,
                "retry_kind": "immediate",
                "post_ladder_retry_pending": False,
                "post_ladder_retry_done": False,
            }
        if failed_host in GROK_SUBSTITUTE_HOSTS:
            cursor = AGENT_HOST_CATALOG["cursor"]
            return {
                "action": "substitute_grok",
                "outcome": outcome_n,
                "phase": phase_n,
                "attempts": attempts,
                "skipped": False,
                "retry": False,
                "retry_kind": None,
                "post_ladder_retry_pending": False,
                "post_ladder_retry_done": False,
                "failed_host": failed_host,
                "substitute_host": "cursor",
                "substitute_model": GROK_SUBSTITUTE_MODEL,
                "substitute_route": cursor["route"],
                "substitute_skill": cursor["skill"],
            }
        return {
            "action": "skip",
            "outcome": outcome_n,
            "phase": phase_n,
            "attempts": attempts,
            "skipped": True,
            "retry": False,
            "retry_kind": None,
            "post_ladder_retry_pending": True,
            "post_ladder_retry_done": False,
        }
    return {
        "action": "remain_skipped",
        "outcome": outcome_n,
        "phase": phase_n,
        "attempts": attempts,
        "skipped": True,
        "retry": False,
        "retry_kind": None,
        "post_ladder_retry_pending": False,
        "post_ladder_retry_done": True,
    }


def skip_retry_artifact(
    *,
    rung: str | int,
    event: str,
    outcome: str,
    attempts: int,
    next_rung: str | int | None = None,
    phase: str = "rung",
    host: str | None = None,
) -> dict[str, Any]:
    """JSON + SKIPPED.md body for `.planning/rfl-*/rung-*/` so the launcher can present skip/retry."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    policy = next_launch_action(attempts=attempts, outcome=outcome, phase=phase, host=host)
    payload: dict[str, Any] = {
        "rung": rung,
        "next_rung": next_rung,
        "event": event or policy["action"],
        "outcome": outcome,
        "attempts": attempts,
        "phase": phase,
        "timestamp": now,
        **policy,
        "skipped_md": (
            (
                f"# SUBSTITUTE GROK — rung {rung}\n\n"
                f"- reason: `{outcome}`\n"
                f"- event: `{policy['action']}`\n"
                f"- attempts: {attempts}\n"
                f"- phase: `{phase}`\n"
                f"- timestamp: {now}\n"
                f"- substitute_model: `{policy.get('substitute_model')}`\n"
                f"- next_rung: {next_rung if next_rung is not None else 'n/a'}\n"
            )
            if policy.get("action") == "substitute_grok"
            else (
                f"# SKIPPED — rung {rung}\n\n"
                f"- reason: `{outcome}`\n"
                f"- event: `{policy['action']}`\n"
                f"- attempts: {attempts}\n"
                f"- phase: `{phase}`\n"
                f"- timestamp: {now}\n"
                f"- next_rung: {next_rung if next_rung is not None else 'n/a'}\n"
                f"- post_ladder_retry_pending: {policy['post_ladder_retry_pending']}\n"
            )
        ),
    }
    return payload


def normalize_severity(raw: str) -> str:
    key = (raw or "").strip().upper()
    return SEVERITY_ALIASES.get(key, key if key in RFL_SEVERITIES else "LOW")


def _md_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def render_issue_table(issues: list[dict[str, Any]]) -> str:
    grouped: dict[str, list[dict[str, Any]]] = {sev: [] for sev in RFL_SEVERITIES}
    for issue in issues:
        sev = normalize_severity(str(issue.get("severity", "LOW")))
        grouped.setdefault(sev, []).append(issue)
    parts = ["## Reported issues (by severity)", ""]
    for sev in RFL_SEVERITIES:
        rows = grouped.get(sev, [])
        parts.append(f"### {sev}")
        parts.append("")
        parts.append("| ID | Title |")
        parts.append("|----|-------|")
        if not rows:
            parts.append("| — | **none** |")
        else:
            for issue in rows:
                parts.append(
                    f"| {_md_cell(issue.get('id', ''))} | {_md_cell(issue.get('title', ''))} |"
                )
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def render_triage_table(rows: list[dict[str, Any]]) -> str:
    parts = [
        "## Triage (launcher, not rung model)",
        "",
        "| ID | Severity | Decision | Reason |",
        "|----|----------|----------|--------|",
    ]
    if not rows:
        parts.append("| — | — | — | **none** |")
    else:
        for row in rows:
            decision = str(row.get("decision", "")).strip().upper()
            parts.append(
                "| "
                f"{_md_cell(row.get('id', ''))} | "
                f"{_md_cell(normalize_severity(str(row.get('severity', ''))))} | "
                f"{_md_cell(decision)} | "
                f"{_md_cell(row.get('reason', ''))} |"
            )
    parts.append("")
    return "\n".join(parts)


def render_resolved_table(rows: list[dict[str, Any]]) -> str:
    parts = [
        "## Resolved (after launcher ACCEPT fixes)",
        "",
        "| ID | Severity | Title | Decision | Resolved |",
        "|----|----------|-------|----------|----------|",
    ]
    if not rows:
        parts.append("| — | — | — | — | **none** |")
    else:
        for row in rows:
            resolved = row.get("resolved", "")
            if isinstance(resolved, bool):
                resolved = "yes" if resolved else "no"
            parts.append(
                "| "
                f"{_md_cell(row.get('id', ''))} | "
                f"{_md_cell(normalize_severity(str(row.get('severity', ''))))} | "
                f"{_md_cell(row.get('title', ''))} | "
                f"{_md_cell(str(row.get('decision', '')).upper())} | "
                f"{_md_cell(resolved)} |"
            )
    parts.append("")
    return "\n".join(parts)


def render_ladder_complete_matrix(rungs: list[dict[str, Any]]) -> str:
    parts = [
        "## Ladder-complete matrix",
        "",
        "| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |",
        "|------|----------|------|-----|-----|-----|----------|----------|",
    ]
    footnotes: list[str] = []
    tot_high = tot_med = tot_low = tot_nit = tot_reported = tot_accepted = 0
    for row in rungs:
        high = int(row.get("high", 0) or 0)
        med = int(row.get("med", 0) or 0)
        low = int(row.get("low", 0) or 0)
        nit = int(row.get("nit", 0) or 0)
        reported = int(row.get("reported", high + med + low + nit) or 0)
        accepted = int(row.get("accepted", 0) or 0)
        parts.append(
            "| "
            f"{_md_cell(row.get('rung', ''))} | "
            f"{_md_cell(row.get('reviewer', ''))} | "
            f"{high} | {med} | {low} | {nit} | {reported} | {accepted} |"
        )
        tot_high += high
        tot_med += med
        tot_low += low
        tot_nit += nit
        tot_reported += reported
        tot_accepted += accepted
        notes = []
        if row.get("clean"):
            notes.append("CLEAN")
        if row.get("id_collision"):
            notes.append("ID collision")
        if row.get("skipped_then_retried"):
            notes.append("skipped-then-retried")
        if notes:
            footnotes.append(f"- Rung {_md_cell(row.get('rung', ''))}: {'; '.join(notes)}")
    parts.append(
        f"| TOTAL | — | {tot_high} | {tot_med} | {tot_low} | {tot_nit} | "
        f"{tot_reported} | {tot_accepted} |"
    )
    parts.append("")
    parts.append(
        "Severity columns are reported counts. **Accepted** is after launcher triage "
        "(rejects excluded)."
    )
    parts.append("")
    if footnotes:
        parts.append("Footnotes:")
        parts.extend(footnotes)
        parts.append("")
    else:
        parts.append("Footnotes: none.")
        parts.append("")
    return "\n".join(parts)


def launcher_mandatory_steps() -> list[str]:
    return list(LAUNCHER_MANDATORY_STEPS)


def attach_default_host_route(payload: dict[str, Any], model: str) -> dict[str, Any]:
    route = default_agent_host_route(model)
    payload["default_agent_host"] = route["host"]
    payload["default_agent_skill"] = route["skill"]
    payload["default_agent_route"] = route["route"]
    payload["preserves_host_mode"] = True
    return payload


def _parse_available_hosts(raw: str | None) -> tuple[str, ...] | None:
    if raw is None or raw.strip() == "":
        return None
    return tuple(part.strip() for part in raw.split(",") if part.strip())


def _load_json_arg(raw: str | None, path: Path | None) -> Any:
    if path is not None:
        return json.loads(path.read_text(encoding="utf-8"))
    if raw:
        return json.loads(raw)
    raise ValueError("JSON payload required (--table-json or --table-json-file)")


def add_policy_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--default-host-route",
        action="store_true",
        help="Emit default /sb:agent-* host for a model family (user --user-agent wins)",
    )
    parser.add_argument(
        "--user-agent",
        default=None,
        help="User-named agent/host override (cursor, codex, claude, pi, opencode, gemini-cli, or any named agent)",
    )
    parser.add_argument(
        "--available-hosts",
        default=None,
        help="Comma-separated hosts present in the user env (default: pi,opencode,cursor,codex,claude,gemini-cli)",
    )
    parser.add_argument(
        "--launch-policy",
        action="store_true",
        help="Emit next action for a launch/timeout attempt (retry once, then skip or OpenCode/Pi Grok substitute)",
    )
    parser.add_argument(
        "--host",
        default=None,
        help="Failed host for --launch-policy (opencode/pi substitute Grok 4.6 High after retry)",
    )
    parser.add_argument("--attempts", type=int, default=1, help="Finished launch attempts including the current outcome")
    parser.add_argument(
        "--outcome",
        choices=("success", "cannot_launch", "timeout"),
        help="Launch attempt outcome for --launch-policy / --skip-artifact",
    )
    parser.add_argument(
        "--policy-phase",
        dest="policy_phase",
        default="rung",
        choices=("rung", "post_ladder"),
        help="rung = in-ladder attempt; post_ladder = retry skipped rungs after the ladder",
    )
    parser.add_argument("--skip-artifact", action="store_true", help="Emit SKIPPED.md JSON for a rung skip/retry")
    parser.add_argument("--rung-id", default=None, help="Rung id for --skip-artifact")
    parser.add_argument("--next-rung", default=None, help="Next rung id recorded on skip")
    parser.add_argument("--issue-table", action="store_true", help="Render HIGH/MED/LOW/NIT issue table from JSON")
    parser.add_argument("--triage-table", action="store_true", help="Render accepted vs rejected triage table from JSON")
    parser.add_argument("--resolved-table", action="store_true", help="Render issue table with Resolved column from JSON")
    parser.add_argument("--ladder-matrix", action="store_true", help="Render ladder-complete summary matrix from JSON")
    parser.add_argument(
        "--issue-ledger",
        action="store_true",
        help="Emit canonical issue-ledger markdown from --run-dir ISSUE-LEDGER.md / POLICY-C*.json (or --table-json)",
    )
    parser.add_argument(
        "--write-review-brief",
        action="store_true",
        help="Emit the only legal Policy G pack-ledger review brief from --run-dir or --table-json (hand-written one-ID briefs are non-compliant)",
    )
    parser.add_argument("--launcher-steps", action="store_true", help="Emit mandatory launcher steps JSON")
    parser.add_argument(
        "--write-policy-c",
        action="store_true",
        help="Write POLICY-C.json + POLICY-C.md under --rung-dir and print markdown",
    )
    parser.add_argument(
        "--assert-policy-c",
        action="store_true",
        help="Exit non-zero if --rung-dir Policy C artifact is missing or schema-invalid",
    )
    parser.add_argument(
        "--assert-rfl-advance",
        action="store_true",
        help="Exit non-zero if consecutive_clean_reviews < 2 or canonical verify filenames are missing before next_rung_review (verify-2.md required on CLEAN; skipped on already-triaged NOT CLEAN)",
    )
    parser.add_argument(
        "--assert-consecutive-clean",
        action="store_true",
        help="Exit non-zero if LADDER-STATUS.json consecutive_clean_reviews < 2 when starting the next rung/model",
    )
    parser.add_argument(
        "--record-rung-review-outcome",
        default=None,
        metavar="OUTCOME",
        help="Record clean (increment streak) or accept-apply (reset streak) on --run-dir/LADDER-STATUS.json",
    )
    parser.add_argument("--rung-dir", type=Path, default=None, help="Rung directory for Policy C / skip artifacts")
    parser.add_argument("--run-dir", type=Path, default=None, help="RFL run directory (.planning/rfl-<id>/)")
    parser.add_argument("--project-root", type=Path, default=None, help="Project root for discovering active RFL runs")
    parser.add_argument(
        "--next-action",
        default="task",
        help="task|verify_1|verify_2|next_rung_review|mark_completed|stop",
    )
    parser.add_argument("--current-phase", default=None, help="Documented rung phase (e.g. rung_1_fix_parallel)")
    parser.add_argument("--prompt", default="", help="Task/skill prompt used to infer --next-action")
    parser.add_argument("--table-json", default=None, help="Inline JSON array/object for table/matrix/Policy C commands")
    parser.add_argument("--table-json-file", type=Path, default=None, help="JSON file for table/matrix/Policy C commands")


def dispatch_policy_cli(args: argparse.Namespace) -> int | None:
    """Handle policy flags. Return an exit code, or None if the caller should continue."""
    policy_requested = any(
        (
            args.default_host_route,
            args.launch_policy,
            args.skip_artifact,
            args.issue_table,
            args.triage_table,
            args.resolved_table,
            args.ladder_matrix,
            getattr(args, "issue_ledger", False),
            getattr(args, "write_review_brief", False),
            args.launcher_steps,
            getattr(args, "write_policy_c", False),
            getattr(args, "assert_policy_c", False),
            getattr(args, "assert_rfl_advance", False),
            getattr(args, "assert_consecutive_clean", False),
            getattr(args, "record_rung_review_outcome", None),
        )
    )
    if not policy_requested:
        return None

    if args.launcher_steps:
        print(json.dumps({"steps": launcher_mandatory_steps()}, indent=2))
        return 0

    if getattr(args, "issue_ledger", False) or getattr(args, "write_review_brief", False):
        from rfl_issue_ledger import collect_issue_ledger, render_issue_ledger, render_review_brief

        inline_rows = None
        if args.table_json or args.table_json_file:
            try:
                loaded = _load_json_arg(args.table_json, args.table_json_file)
            except ValueError as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                return 2
            if isinstance(loaded, dict) and isinstance(loaded.get("rows"), list):
                inline_rows = loaded["rows"]
            elif isinstance(loaded, list):
                inline_rows = loaded
            else:
                print("ERROR: issue-ledger JSON must be an array or {\"rows\": [...]}", file=sys.stderr)
                return 2
        run_dir = getattr(args, "run_dir", None)
        if inline_rows is None and run_dir is None:
            print("ERROR: --issue-ledger/--write-review-brief requires --run-dir or --table-json", file=sys.stderr)
            return 2
        rows = collect_issue_ledger(run_dir=run_dir, rows=inline_rows)
        if getattr(args, "write_review_brief", False):
            print(render_review_brief(rows), end="")
        else:
            print(render_issue_ledger(rows), end="")
        return 0

    if args.default_host_route:
        model = getattr(args, "model", None)
        if not model:
            print("ERROR: --default-host-route requires --model", file=sys.stderr)
            return 2
        print(
            json.dumps(
                default_agent_host_route(
                    model,
                    user_agent=args.user_agent,
                    available_hosts=_parse_available_hosts(args.available_hosts),
                ),
                indent=2,
            )
        )
        return 0

    if args.launch_policy:
        if not args.outcome:
            print("ERROR: --launch-policy requires --outcome", file=sys.stderr)
            return 2
        print(
            json.dumps(
                next_launch_action(
                    attempts=args.attempts,
                    outcome=args.outcome,
                    phase=args.policy_phase,
                    host=getattr(args, "host", None) or args.user_agent,
                ),
                indent=2,
            )
        )
        return 0

    if args.skip_artifact:
        if not args.outcome or args.rung_id is None:
            print("ERROR: --skip-artifact requires --rung-id and --outcome", file=sys.stderr)
            return 2
        payload = skip_retry_artifact(
            rung=args.rung_id,
            event="",
            outcome=args.outcome,
            attempts=args.attempts,
            next_rung=args.next_rung,
            phase=args.policy_phase,
            host=getattr(args, "host", None) or args.user_agent,
        )
        rung_dir = getattr(args, "rung_dir", None)
        if rung_dir is not None:
            path = Path(rung_dir)
            path.mkdir(parents=True, exist_ok=True)
            (path / "SKIPPED.md").write_text(str(payload.get("skipped_md") or ""), encoding="utf-8")
            payload["skipped_md_path"] = str(path / "SKIPPED.md")
        print(json.dumps(payload, indent=2))
        return 0

    if getattr(args, "write_policy_c", False):
        from rfl_policy_c import write_policy_c

        if getattr(args, "rung_dir", None) is None:
            print("ERROR: --write-policy-c requires --rung-dir", file=sys.stderr)
            return 2
        try:
            body = _load_json_arg(args.table_json, args.table_json_file)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        if not isinstance(body, dict):
            print("ERROR: Policy C JSON must be an object", file=sys.stderr)
            return 2
        result = write_policy_c(
            args.rung_dir,
            body,
            current_phase=getattr(args, "current_phase", None),
        )
        print(result["markdown"], end="")
        if not result["ok"]:
            print("ERROR: " + "; ".join(result["errors"]), file=sys.stderr)
            return 2
        return 0

    if getattr(args, "assert_policy_c", False):
        from rfl_policy_c import assert_policy_c

        if getattr(args, "rung_dir", None) is None:
            print("ERROR: --assert-policy-c requires --rung-dir", file=sys.stderr)
            return 2
        result = assert_policy_c(
            args.rung_dir,
            current_phase=getattr(args, "current_phase", None),
        )
        print(json.dumps({"ok": result["ok"], "errors": result["errors"], "rung_dir": result["rung_dir"]}, indent=2))
        return 0 if result["ok"] else 2

    if getattr(args, "record_rung_review_outcome", None):
        from rfl_policy_c import record_rung_review_outcome

        if getattr(args, "run_dir", None) is None:
            print("ERROR: --record-rung-review-outcome requires --run-dir", file=sys.stderr)
            return 2
        try:
            result = record_rung_review_outcome(
                args.run_dir,
                args.record_rung_review_outcome,
                rung_id=getattr(args, "rung_id", None),
            )
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        print(json.dumps(result, indent=2))
        return 0

    if getattr(args, "assert_rfl_advance", False) or getattr(args, "assert_consecutive_clean", False):
        from rfl_policy_c import assert_rfl_advance

        action = getattr(args, "next_action", "task") or "task"
        if getattr(args, "assert_consecutive_clean", False) and action == "task":
            action = "next_rung_review"
        result = assert_rfl_advance(
            getattr(args, "run_dir", None),
            rung_dir=getattr(args, "rung_dir", None),
            project_root=getattr(args, "project_root", None),
            next_action=action,
            current_phase=getattr(args, "current_phase", None),
            prompt=getattr(args, "prompt", "") or "",
        )
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 2

    try:
        payload = _load_json_arg(args.table_json, args.table_json_file)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if not isinstance(payload, list):
        print("ERROR: table JSON must be an array", file=sys.stderr)
        return 2
    if args.issue_table:
        print(render_issue_table(payload), end="")
        return 0
    if args.triage_table:
        print(render_triage_table(payload), end="")
        return 0
    if args.resolved_table:
        print(render_resolved_table(payload), end="")
        return 0
    if args.ladder_matrix:
        print(render_ladder_complete_matrix(payload), end="")
        return 0
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="RFL launcher policy helpers", allow_abbrev=False)
    parser.add_argument("--model", help="Model slug for --default-host-route")
    add_policy_arguments(parser)
    args = parser.parse_args()
    code = dispatch_policy_cli(args)
    if code is None:
        parser.error("one of --default-host-route/--launch-policy/--skip-artifact/--write-policy-c/--assert-policy-c/--assert-rfl-advance/--assert-consecutive-clean/--record-rung-review-outcome/--issue-table/--triage-table/--resolved-table/--ladder-matrix/--issue-ledger/--write-review-brief/--launcher-steps is required")
    return code


if __name__ == "__main__":
    sys.exit(main())
