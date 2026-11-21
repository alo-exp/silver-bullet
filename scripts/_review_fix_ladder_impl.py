#!/usr/bin/env python3
"""Resolve host-aware model/reasoning rungs for sb:review-fix-ladder."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

_LIB_DIR = Path(__file__).resolve().parent / "lib"
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))
import rfl_quota_retry  # noqa: E402
import rfl_quota_claude5h  # noqa: E402

REASONING_ORDER = ("low", "medium", "high", "xhigh")
CLAUDE_THINKING_ORDER = ("medium", "high", "xhigh")
CODEX_MINI_SLUG = "gpt-5.4-mini"

RFL_REVIEW_VERIFY_PHASES = frozenset({"review", "verify_1", "verify_2"})

CLAUDE_FALLBACK_MODELS = (
    "claude-sonnet-4-6",
    "claude-opus-4-7",
    "claude-opus-4-8",
)

CODEX_FALLBACK_MODELS = ("gpt-5.4", "gpt-5.5")

# Cursor GPT/Claude rungs try the subsidized host CLI first (Codex / Claude
# subscriptions). Cursor Task is allowed only after quota exhaustion.
SUBSCRIPTION_PLANS: dict[str, dict[str, str]] = {
    "gpt": {
        "subscription_host": "codex",
        "subscription_skill": "silver-agent-codex",
        "subscription_invoke": "scripts/agent-codex/invoke.sh",
    },
    "claude": {
        "subscription_host": "claude",
        "subscription_skill": "silver-agent-claude",
        "subscription_invoke": "scripts/agent-claude/invoke.sh",
    },
}

# Narrow quota classifier: billed-quota / rate-limit / usage-cap only.
# Bare "quota" matches in-repo agent_delegate_is_quota_error, but missing-CLI
# and HASH MISMATCH are classified first and never fall back to Cursor.
QUOTA_EXHAUSTION_RE = re.compile(
    r"\b429\b|"
    r"rate[\s_-]*limit|"
    r"token[\s_-]*plan|"
    r"out of quota|"
    r"quota[\s_-]*(?:exhaust|exceed)|"
    r"quota retries exhausted|"
    r"usage[\s_-]*(?:cap|limit)|"
    r"billed[\s_-]*quota|"
    r"over[\s_-]*quota|"
    r"\bquota\b",
    re.IGNORECASE,
)
MISSING_CLI_RE = re.compile(
    r"CLI not found|"
    r"native Codex CLI not found|"
    r"Claude CLI not found|"
    r"missing delegate|"
    r"not installed|"
    r"command not found",
    re.IGNORECASE,
)
HASH_MISMATCH_RE = re.compile(r"HASH\s*MISMATCH", re.IGNORECASE)


def detect_host() -> str:
    runtime = os.environ.get("SILVER_BULLET_RUNTIME", "").strip().lower()
    if runtime in {"claude", "codex"}:
        return runtime

    if any(
        os.environ.get(key)
        for key in (
            "CODEX_CI",
            "CODEX_THREAD_ID",
            "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
        )
    ):
        return "codex"

    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if plugin_root:
        if "/.codex/" in plugin_root:
            return "codex"

    return "claude"


def sanitize_model_for_agent_name(model: str) -> str:
    return model.replace(".", "-")


def subagent_name_for(model: str, effort: str, prefix: str = "sb") -> str:
    return f"{prefix}-{sanitize_model_for_agent_name(model)}-{effort}"


def subscription_family_for_model(model: str) -> str | None:
    """Return 'gpt' or 'claude' when the rung must try a subsidized CLI first."""
    slug = (model or "").strip().lower()
    if not slug:
        return None
    if slug.startswith(("opus-", "claude-", "sb-opus-", "sb-claude-")):
        return "claude"
    if slug.startswith(("gpt-", "chatgpt-", "sb-gpt-")):
        return "gpt"
    return None


def _first_regex_match(pattern: re.Pattern[str], blob: str) -> str | None:
    match = pattern.search(blob or "")
    if not match:
        return None
    return match.group(0).strip()


def subscription_fields_for_model(model: str) -> dict[str, Any]:
    family = subscription_family_for_model(model)
    if family is None:
        return {
            "subscription_first": False,
            "subscription_family": None,
            "subscription_host": None,
            "subscription_skill": None,
            "subscription_invoke": None,
            "cursor_fallback": None,
        }
    plan = SUBSCRIPTION_PLANS[family]
    return {
        "subscription_first": True,
        "subscription_family": family,
        "subscription_host": plan["subscription_host"],
        "subscription_skill": plan["subscription_skill"],
        "subscription_invoke": plan["subscription_invoke"],
        "cursor_fallback": "quota-exhaustion-only",
    }


def classify_subscription_attempt(exit_code: int, output: str) -> dict[str, Any]:
    """Classify a Codex/Claude CLI attempt. Cursor fallback only on quota."""
    blob = output or ""
    if int(exit_code) == 0:
        return {
            "quota_exhaustion": False,
            "cursor_fallback": False,
            "reason": "success",
            "signal": None,
        }
    if MISSING_CLI_RE.search(blob):
        return {
            "quota_exhaustion": False,
            "cursor_fallback": False,
            "reason": "missing-cli",
            "signal": _first_regex_match(MISSING_CLI_RE, blob),
        }
    if HASH_MISMATCH_RE.search(blob):
        return {
            "quota_exhaustion": False,
            "cursor_fallback": False,
            "reason": "hash-mismatch",
            "signal": _first_regex_match(HASH_MISMATCH_RE, blob),
        }
    if QUOTA_EXHAUSTION_RE.search(blob):
        return {
            "quota_exhaustion": True,
            "cursor_fallback": True,
            "reason": "quota-exhaustion",
            "signal": _first_regex_match(QUOTA_EXHAUSTION_RE, blob),
        }
    return {
        "quota_exhaustion": False,
        "cursor_fallback": False,
        "reason": "non-quota-failure",
        "signal": None,
    }


def decide_launch(
    model: str,
    reasoning: str,
    *,
    prefix: str = "sb",
    subscription_exit: int | None = None,
    subscription_output: str = "",
) -> dict[str, Any]:
    """Per-launch gate: GPT/Claude try subscription CLI; others stay on Cursor Task."""
    family = subscription_family_for_model(model)
    payload: dict[str, Any] = {
        "model": model,
        "reasoning": reasoning,
        "subagent_name": subagent_name_for(model, reasoning, prefix),
        **subscription_fields_for_model(model),
    }
    if family is None:
        payload.update(
            {
                "action": "cursor_task",
                "reason": "non-subscription-family",
                "quota_exhaustion": False,
                "signal": None,
            }
        )
        payload["cursor_fallback"] = False
        return payload
    if subscription_exit is None:
        payload.update(
            {
                "action": "invoke_subscription",
                "reason": "subscription-first",
                "quota_exhaustion": False,
                "signal": None,
            }
        )
        return payload
    classified = classify_subscription_attempt(subscription_exit, subscription_output)
    if classified["reason"] == "success":
        payload.update({"action": "accept_subscription", **classified})
        return payload
    if classified["cursor_fallback"]:
        payload.update({"action": "cursor_fallback", **classified})
        return payload
    payload.update({"action": "fail", **classified})
    return payload


def rfl_state_file() -> Path:
    state_dir = os.environ.get("SB_RUNTIME_STATE_DIR", "/tmp")
    return Path(state_dir) / "review-fix-ladder-state.json"


def mark_quota_cursor_fallback(*, host: str = "", signal: str = "") -> dict[str, Any]:
    path = rfl_state_file()
    payload = load_json_file(path) or {}
    payload["subscription_quota_fallback"] = True
    if host:
        payload["subscription_quota_host"] = host
    if signal:
        payload["subscription_quota_signal"] = signal
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return {
        "ok": True,
        "state_file": str(path),
        "subscription_quota_fallback": True,
        "subscription_quota_host": payload.get("subscription_quota_host"),
        "subscription_quota_signal": payload.get("subscription_quota_signal"),
    }


def load_json_file(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def reasoning_levels_for_model(model: dict[str, Any]) -> list[str]:
    levels = [
        entry.get("effort", "")
        for entry in model.get("supported_reasoning_levels", [])
        if isinstance(entry, dict) and entry.get("effort")
    ]
    ordered = [level for level in REASONING_ORDER if level in levels]
    return ordered or list(REASONING_ORDER)


def expand_model_rungs(models: list[str], reasoning_levels: list[str]) -> list[dict[str, str]]:
    rungs: list[dict[str, str]] = []
    for model in models:
        for reasoning in reasoning_levels:
            rungs.append({"model": model, "reasoning": reasoning})
    return rungs


def codex_dynamic_rungs(cache_path: Path) -> list[dict[str, str]] | None:
    if not cache_path.is_file():
        return None

    try:
        payload = json.loads(cache_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    models = payload.get("models")
    if not isinstance(models, list) or not models:
        return None

    listed = [model for model in models if model.get("visibility") == "list"]
    if not listed:
        return None

    listed.sort(key=lambda model: int(model.get("priority", 0)), reverse=True)

    usable = [model for model in listed if model.get("slug") != CODEX_MINI_SLUG]
    if not usable:
        return None

    rungs: list[dict[str, str]] = []
    for model in usable:
        slug = str(model.get("slug", "")).strip()
        if not slug:
            continue
        for reasoning in reasoning_levels_for_model(model):
            rungs.append({"model": slug, "reasoning": reasoning})

    return rungs or None


def codex_fallback_rungs() -> list[dict[str, str]]:
    return expand_model_rungs(list(CODEX_FALLBACK_MODELS), list(REASONING_ORDER))


def claude_fallback_rungs() -> list[dict[str, str]]:
    return expand_model_rungs(list(CLAUDE_FALLBACK_MODELS), list(CLAUDE_THINKING_ORDER))


def resolve_ladder(
    host: str,
    codex_home: Path | None = None,
    project_root: Path | None = None,
) -> dict[str, Any]:
    host = host.lower()
    if host == "codex":
        cache_path = (codex_home or Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))) / "models_cache.json"
        dynamic = codex_dynamic_rungs(cache_path)
        if dynamic:
            return {"host": "codex", "source": "dynamic", "total_rungs": len(dynamic), "rungs": dynamic}
        fallback = codex_fallback_rungs()
        return {"host": "codex", "source": "fallback", "total_rungs": len(fallback), "rungs": fallback}

    fallback = claude_fallback_rungs()
    return {
        "host": "claude",
        "source": "fallback",
        "total_rungs": len(fallback),
        "rungs": fallback,
    }


def resolve_rung_phase(
    payload: dict[str, Any],
    rung_index: int,
    phase: str,
) -> dict[str, Any]:
    rungs = payload.get("rungs", [])
    if rung_index < 1 or rung_index > len(rungs):
        raise ValueError(f"rung index {rung_index} out of range (1..{len(rungs)})")
    if phase not in RFL_REVIEW_VERIFY_PHASES:
        raise ValueError(f"unsupported phase {phase!r} (expected review|verify_1|verify_2)")

    rung = rungs[rung_index - 1]
    phase_payload: dict[str, Any] = {
        "host": payload.get("host"),
        "rung": rung_index,
        "rung_total": len(rungs),
        "phase": phase,
        "model": rung["model"],
        "reasoning": rung["reasoning"],
        "delegation": rung.get("delegation", "custom-subagent"),
        "subagent_name": rung.get("subagent_name"),
        "model_param": rung.get("model_param"),
        "task_slug": None,
        "agent_model": None,
    }
    phase_payload.update(subscription_fields_for_model(str(rung.get("model", ""))))
    return phase_payload


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Resolve review-fix ladder rungs for the active host.",
        allow_abbrev=False,
    )
    parser.add_argument("--host", choices=("codex", "claude"), help="Override host detection")
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
    parser.add_argument("--rung-dir", type=Path, help="Rung directory for Policy C / skip artifacts")
    parser.add_argument(
        "--current-phase",
        default="",
        help="Documented rung phase stored on --mark-ladder-status (e.g. rung_5_fix_parallel)",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON only")
    parser.add_argument(
        "--codex-home",
        type=Path,
        help="Override CODEX_HOME for models_cache.json discovery (tests)",
    )
    parser.add_argument("--project-root", type=Path, help="Project root for the ladder resolver")
    parser.add_argument("--rung", type=int, help="Rung index (1-based) for phase routing output")
    parser.add_argument(
        "--phase",
        choices=sorted(RFL_REVIEW_VERIFY_PHASES),
        help="Rung phase for routing (review, verify_1, verify_2)",
    )
    parser.add_argument(
        "--decide-launch",
        action="store_true",
        help="Emit subscription-first vs Cursor Task plan for one model/reasoning pair",
    )
    parser.add_argument("--model", help="Model slug for --decide-launch")
    parser.add_argument("--reasoning", help="Reasoning/effort for --decide-launch")
    parser.add_argument(
        "--subscription-exit",
        type=int,
        help="Exit code from agent-codex/agent-claude invoke (omit = not attempted yet)",
    )
    parser.add_argument(
        "--subscription-output",
        default="",
        help="Stdout/stderr from the subscription CLI attempt",
    )
    parser.add_argument(
        "--subscription-output-file",
        type=Path,
        help="Read subscription CLI output from a file",
    )
    parser.add_argument(
        "--classify-quota",
        action="store_true",
        help="Classify subscription CLI output as quota vs non-quota (no Cursor fallback unless quota)",
    )
    parser.add_argument(
        "--mark-quota-fallback",
        action="store_true",
        help="Record quota exhaustion on the active RFL state file so Cursor Task is allowed",
    )
    parser.add_argument("--quota-host", default="", help="Host that exhausted quota (codex|claude)")
    parser.add_argument("--quota-signal", default="", help="Matched quota signal to record")
    parser.add_argument(
        "--classify-quota-window",
        action="store_true",
        help="Classify 5-hour vs weekly vs monthly vs unknown quota and whether to schedule a retry",
    )
    parser.add_argument(
        "--schedule-quota-retry",
        action="store_true",
        help="Persist an idempotent quota-retry job under --run-dir",
    )
    parser.add_argument(
        "--activate-quota-retry",
        action="store_true",
        help="Fire a due quota-retry job: retry the rung if the ladder is active, else ask the user",
    )
    parser.add_argument(
        "--quota-retry-due",
        action="store_true",
        help="List due quota-retry jobs for --run-dir",
    )
    parser.add_argument(
        "--quota-retry-wake",
        action="store_true",
        help="Activate every due quota-retry job (at/launchd/SessionStart worker)",
    )
    parser.add_argument(
        "--mark-ladder-status",
        choices=("active", "completed", "aborted"),
        help="Record durable ladder status in --run-dir/LADDER-STATUS.json",
    )
    parser.add_argument("--run-dir", type=Path, help="RFL run directory for quota-retry / ladder status")
    parser.add_argument("--run-id", default="", help="Ladder run identity stored on quota-retry jobs")
    parser.add_argument("--rung-id", default="", help="Rung identity for quota-retry schedule/activate")
    parser.add_argument(
        "--quota-now",
        default="",
        help="ISO-8601 timestamp for quota-retry tests (default: now)",
    )
    args = parser.parse_args()

    quota_window_requested = any(
        (
            args.classify_quota_window,
            args.schedule_quota_retry,
            args.activate_quota_retry,
            args.quota_retry_due,
            args.quota_retry_wake,
            args.mark_ladder_status,
        )
    )
    if quota_window_requested:
        output = args.subscription_output
        if args.subscription_output_file is not None:
            output = args.subscription_output_file.read_text(encoding="utf-8")
        now = rfl_quota_retry.parse_iso_datetime(args.quota_now)
        if args.classify_quota_window:
            print(json.dumps(
                rfl_quota_claude5h.classify_quota_window(
                    output,
                    host=args.quota_host,
                    model=args.model or "",
                    now=now,
                ),
                indent=2,
            ))
            return 0
        if args.quota_retry_wake:
            if args.run_dir is None and args.project_root is None:
                parser.error("--quota-retry-wake requires --run-dir or --project-root")
            result = rfl_quota_retry.wake_due_jobs(
                project_root=args.project_root,
                run_dir=args.run_dir,
                now=now,
            )
            for ask in result.get("asks") or []:
                print(f"[rfl] ASK: {ask}", file=sys.stderr)
            print(json.dumps(result, indent=2))
            return 0
        if args.run_dir is None:
            parser.error("quota-retry / ladder-status commands require --run-dir")
        run_id = args.run_id or args.run_dir.name
        if args.mark_ladder_status:
            try:
                marked = rfl_quota_retry.mark_ladder_status(
                    args.run_dir,
                    args.mark_ladder_status,
                    now=now,
                    current_rung=args.rung_id or None,
                    current_phase=args.current_phase or None,
                )
            except ValueError as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                return 2
            print(json.dumps(marked, indent=2))
            return 0
        if args.quota_retry_due:
            print(json.dumps(rfl_quota_retry.due_quota_retries(args.run_dir, now=now), indent=2))
            return 0
        if not args.rung_id or not args.model:
            parser.error("quota-retry schedule/activate require --rung-id and --model")
        if args.schedule_quota_retry:
            result = rfl_quota_claude5h.schedule_quota_retry(
                run_dir=args.run_dir,
                run_id=run_id,
                rung=args.rung_id,
                model=args.model,
                output=output,
                now=now,
                host=args.quota_host,
            )
            print(json.dumps(result, indent=2))
            return 0
        result = rfl_quota_retry.activate_quota_retry(
            run_dir=args.run_dir,
            run_id=run_id,
            rung=args.rung_id,
            model=args.model,
            now=now,
        )
        if result.get("action") == "ask_user" and result.get("ask"):
            print(f"[rfl] ASK: {result['ask']}", file=sys.stderr)
        print(json.dumps(result, indent=2))
        return 0

    if args.classify_quota or args.decide_launch or args.mark_quota_fallback:
        output = args.subscription_output
        if args.subscription_output_file is not None:
            output = args.subscription_output_file.read_text(encoding="utf-8")
        if args.classify_quota:
            exit_code = 1 if args.subscription_exit is None else args.subscription_exit
            print(json.dumps(classify_subscription_attempt(exit_code, output), indent=2))
            return 0
        if args.mark_quota_fallback:
            print(json.dumps(mark_quota_cursor_fallback(host=args.quota_host, signal=args.quota_signal), indent=2))
            return 0
        if not args.model or not args.reasoning:
            parser.error("--decide-launch requires --model and --reasoning")
        print(
            json.dumps(
                decide_launch(
                    args.model,
                    args.reasoning,
                    subscription_exit=args.subscription_exit,
                    subscription_output=output,
                ),
                indent=2,
            )
        )
        return 0

    host = args.host or detect_host()
    project_root = args.project_root or Path.cwd()
    payload = resolve_ladder(host, codex_home=args.codex_home, project_root=project_root)

    if args.rung is not None or args.phase is not None:
        if args.rung is None or args.phase is None:
            parser.error("--rung and --phase must be used together")
        try:
            phase_payload = resolve_rung_phase(payload, args.rung, args.phase)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        print(json.dumps(phase_payload, indent=2))
        return 0

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"host: {payload['host']}")
    print(f"source: {payload['source']}")
    print(f"total_rungs: {payload.get('total_rungs', len(payload['rungs']))}")
    print("rungs:")
    for index, rung in enumerate(payload["rungs"], start=1):
        model = rung["model"]
        reasoning = rung["reasoning"]
        print(f"  {index}. {model} / {reasoning}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
