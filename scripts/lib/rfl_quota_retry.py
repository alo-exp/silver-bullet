#!/usr/bin/env python3
"""RFL quota-window classification and deferred retry scheduling.

Any model (not OpenCode-only). Persist jobs under the ladder run dir so a later
activation can retry the same named model, or ask the user if the run is over.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

FIVE_HOURS_SECONDS = 5 * 3600
SHORT_RETRY_MAX_SECONDS = 300
SCHEDULE_FILENAME = "quota-retry-schedule.json"
LADDER_STATUS_FILENAME = "LADDER-STATUS.json"
LADDER_OVER_STATUSES = frozenset({"completed", "aborted", "done", "finished", "policy_d"})
LADDER_OVER_ARTIFACTS = (
    "LADDER-COMPLETE.md",
    "POLICY-D.md",
    "POLICY-D-MATRIX.md",
)

_DURATION_TOKEN_RE = re.compile(
    r"(?P<n>\d+(?:\.\d+)?)\s*"
    r"(?P<u>hours?|hrs?|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b",
    re.IGNORECASE,
)
_RESET_PREFIX_RE = re.compile(
    r"(?:resets?\s+in|reset\s+after|resets?\s+after)\s+",
    re.IGNORECASE,
)
_FIVE_HOUR_RE = re.compile(
    r"(?:5[\s-]*hour|five[\s-]*hour).{0,48}(?:usage\s+)?(?:limit|cap|quota)|"
    r"(?:usage\s+)?(?:limit|cap|quota).{0,48}(?:5[\s-]*hour|five[\s-]*hour)",
    re.IGNORECASE | re.DOTALL,
)
_WEEKLY_RE = re.compile(
    r"\bweekly\b.{0,48}(?:limit|cap|quota)|"
    r"(?:limit|cap|quota).{0,48}\bweekly\b|"
    r"\bweek(?:ly)?\s+(?:usage\s+)?(?:limit|cap|quota)",
    re.IGNORECASE | re.DOTALL,
)
_MONTHLY_RE = re.compile(
    r"\bmonthly\b.{0,48}(?:limit|cap|quota)|"
    r"(?:limit|cap|quota).{0,48}\bmonthly\b|"
    r"\bmonth(?:ly)?\s+(?:usage\s+)?(?:limit|cap|quota)",
    re.IGNORECASE | re.DOTALL,
)
_BILLING_RE = re.compile(
    r"(?:^|[^0-9])401(?:[^0-9]|$)|"
    r"insufficient(?:_|\s+)(?:balance|credits|funds|quota)|"
    r"invalid_api_key|"
    r"invalid\s+api\s+key|"
    r"missing\s+api\s+key",
    re.IGNORECASE,
)
_QUOTA_LIKE_RE = re.compile(
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

_UNIT_SECONDS = {
    "h": 3600,
    "hr": 3600,
    "hrs": 3600,
    "hour": 3600,
    "hours": 3600,
    "m": 60,
    "min": 60,
    "mins": 60,
    "minute": 60,
    "minutes": 60,
    "s": 1,
    "sec": 1,
    "secs": 1,
    "second": 1,
    "seconds": 1,
}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def parse_iso_datetime(raw: str | None) -> datetime | None:
    text = (raw or "").strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def isoformat_z(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_reset_seconds(blob: str) -> int | None:
    """Parse 'Resets in 3hr 6min' / 'reset after 59m 36s' into seconds."""
    text = blob or ""
    match = _RESET_PREFIX_RE.search(text)
    if not match:
        return None
    rest = text[match.end() :]
    cut = re.search(r"[.\n;]|\[", rest)
    span = rest[: cut.start()] if cut else rest
    total = 0.0
    found = False
    for token in _DURATION_TOKEN_RE.finditer(span):
        found = True
        amount = float(token.group("n"))
        unit = token.group("u").lower()
        total += amount * _UNIT_SECONDS[unit]
    if not found:
        return None
    return int(total)


def classify_quota_window(blob: str) -> dict[str, Any]:
    """Classify 5-hour vs weekly vs monthly vs billing vs unknown.

    Scheduling:
    - five_hour: always schedule (parsed reset, else 5 hours).
    - weekly / monthly / unknown: only if parsed reset is <= 5 hours.
    - billing (401 / insufficient balance): never, unless the text is clearly a
      5-hour usage cap (those classify as five_hour first).
    """
    text = blob or ""
    reset_seconds = parse_reset_seconds(text)
    reset_within_5h = reset_seconds is not None and reset_seconds <= FIVE_HOURS_SECONDS

    if _FIVE_HOUR_RE.search(text):
        quota_class = "five_hour"
        should_schedule = True
        delay = reset_seconds if reset_seconds is not None else FIVE_HOURS_SECONDS
    elif _BILLING_RE.search(text):
        quota_class = "billing"
        should_schedule = False
        delay = None
    elif _WEEKLY_RE.search(text):
        quota_class = "weekly"
        should_schedule = bool(reset_within_5h)
        delay = reset_seconds if should_schedule else None
    elif _MONTHLY_RE.search(text):
        quota_class = "monthly"
        should_schedule = bool(reset_within_5h)
        delay = reset_seconds if should_schedule else None
    elif _QUOTA_LIKE_RE.search(text):
        quota_class = "unknown"
        should_schedule = bool(reset_within_5h)
        delay = reset_seconds if should_schedule else None
    else:
        quota_class = "not_quota"
        should_schedule = False
        delay = None

    should_short_retry = quota_class == "unknown" and (
        reset_seconds is None or reset_seconds <= SHORT_RETRY_MAX_SECONDS
    )
    return {
        "quota_class": quota_class,
        "reset_seconds": reset_seconds,
        "reset_within_5h": bool(reset_within_5h),
        "should_schedule": should_schedule,
        "schedule_delay_seconds": delay,
        "should_short_retry": should_short_retry,
        "same_named_model": True,
        "substitute_model": None,
    }


def job_key(*, run_id: str, rung: str, model: str) -> str:
    return f"{run_id}::{rung}::{model}"


def schedule_path(run_dir: Path) -> Path:
    return Path(run_dir) / SCHEDULE_FILENAME


def ladder_status_path(run_dir: Path) -> Path:
    return Path(run_dir) / LADDER_STATUS_FILENAME


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def load_schedule(run_dir: Path) -> dict[str, Any]:
    payload = _read_json(schedule_path(run_dir))
    jobs = payload.get("jobs")
    if not isinstance(jobs, list):
        payload["jobs"] = []
    payload.setdefault("version", 1)
    return payload


def mark_ladder_status(
    run_dir: Path,
    status: str,
    *,
    reason: str = "",
    policy_d_written: bool | None = None,
    now: datetime | None = None,
    current_rung: str | None = None,
    current_phase: str | None = None,
) -> dict[str, Any]:
    moment = now or utcnow()
    normalized = (status or "").strip().lower()
    if normalized not in {"active", "completed", "aborted", "done", "finished", "policy_d"}:
        raise ValueError(f"unsupported ladder status {status!r}")
    if normalized in {"completed", "done", "finished", "policy_d"}:
        from rfl_policy_c import assert_run_ready_for_complete

        gated = assert_run_ready_for_complete(Path(run_dir))
        if not gated.get("ok"):
            detail = "; ".join(gated.get("errors") or ["Policy C missing"])
            raise ValueError(f"cannot mark ladder completed: {detail}")
    path = ladder_status_path(run_dir)
    payload = _read_json(path)
    payload["status"] = normalized
    payload["updated_at"] = isoformat_z(moment)
    if reason:
        payload["reason"] = reason
    if policy_d_written is not None:
        payload["policy_d_written"] = bool(policy_d_written)
    elif normalized in {"completed", "done", "finished", "policy_d"}:
        payload["policy_d_written"] = True
    if current_rung:
        payload["current_rung"] = str(current_rung).strip()
    if current_phase:
        payload["current_phase"] = str(current_phase).strip()
    _write_json(path, payload)
    return {"ok": True, "path": str(path), **payload}


def detect_ladder_status(run_dir: Path) -> dict[str, Any]:
    root = Path(run_dir)
    payload = _read_json(ladder_status_path(root))
    status = str(payload.get("status") or "").strip().lower()
    artifacts = [name for name in LADDER_OVER_ARTIFACTS if (root / name).is_file()]
    if not status:
        if artifacts or payload.get("policy_d_written"):
            status = "completed"
        else:
            status = "active"
    over = status in LADDER_OVER_STATUSES or bool(artifacts) or bool(payload.get("policy_d_written"))
    return {
        "status": status,
        "over": over,
        "policy_d_written": bool(payload.get("policy_d_written")),
        "artifacts": artifacts,
        "path": str(ladder_status_path(root)),
    }


def schedule_quota_retry(
    *,
    run_dir: Path,
    run_id: str,
    rung: str,
    model: str,
    output: str,
    now: datetime | None = None,
) -> dict[str, Any]:
    moment = now or utcnow()
    classified = classify_quota_window(output)
    key = job_key(run_id=run_id, rung=str(rung), model=str(model))
    store = load_schedule(run_dir)
    store["run_id"] = store.get("run_id") or run_id
    store["run_dir"] = str(Path(run_dir))
    jobs: list[dict[str, Any]] = list(store.get("jobs") or [])
    existing = next((job for job in jobs if job.get("id") == key), None)
    if existing is not None:
        timer = existing.get("timer") if isinstance(existing.get("timer"), dict) else {}
        if existing.get("status") == "scheduled" and not timer.get("armed"):
            timer = arm_quota_retry_timer(job=existing, run_dir=run_dir, now=moment)
            existing["timer"] = timer
            store["jobs"] = jobs
            store["updated_at"] = isoformat_z(moment)
            _write_json(schedule_path(run_dir), store)
        return {
            "ok": True,
            "deduped": True,
            "scheduled": existing.get("status") == "scheduled",
            "armed": bool((existing.get("timer") or {}).get("armed")),
            "timer": existing.get("timer"),
            "path": str(schedule_path(run_dir)),
            "job": existing,
            **classified,
        }
    if not classified["should_schedule"]:
        return {
            "ok": True,
            "deduped": False,
            "scheduled": False,
            "path": str(schedule_path(run_dir)),
            "job": None,
            **classified,
        }
    delay = int(classified["schedule_delay_seconds"] or FIVE_HOURS_SECONDS)
    fire_at = moment + timedelta(seconds=delay)
    job = {
        "id": key,
        "run_id": run_id,
        "run_dir": str(Path(run_dir)),
        "rung": str(rung),
        "model": str(model),
        "quota_class": classified["quota_class"],
        "reset_seconds": classified["reset_seconds"],
        "schedule_delay_seconds": delay,
        "fire_at": isoformat_z(fire_at),
        "created_at": isoformat_z(moment),
        "status": "scheduled",
        "same_named_model": True,
        "substitute_model": None,
    }
    timer = arm_quota_retry_timer(job=job, run_dir=run_dir, now=moment)
    job["timer"] = timer
    jobs.append(job)
    store["jobs"] = jobs
    store["updated_at"] = isoformat_z(moment)
    _write_json(schedule_path(run_dir), store)
    return {
        "ok": True,
        "deduped": False,
        "scheduled": True,
        "armed": bool(timer.get("armed")),
        "timer": timer,
        "path": str(schedule_path(run_dir)),
        "job": job,
        **classified,
    }


def _job_due(job: dict[str, Any], now: datetime) -> bool:
    fire_at = parse_iso_datetime(str(job.get("fire_at") or ""))
    if fire_at is None:
        return True
    return fire_at <= now


def ask_user_prompt(*, run_id: str, rung: str, model: str, ladder_status: str) -> str:
    return (
        f"The review-fix ladder run `{run_id}` has already finished "
        f"(status: {ladder_status}). A quota retry for rung `{rung}` on model "
        f"`{model}` is due. Retry this rung now on the same named model? "
        "Do not execute until the user confirms."
    )


def activate_quota_retry(
    *,
    run_dir: Path,
    run_id: str | None = None,
    rung: str,
    model: str,
    now: datetime | None = None,
) -> dict[str, Any]:
    moment = now or utcnow()
    store = load_schedule(run_dir)
    resolved_run_id = run_id or str(store.get("run_id") or Path(run_dir).name)
    key = job_key(run_id=resolved_run_id, rung=str(rung), model=str(model))
    jobs: list[dict[str, Any]] = list(store.get("jobs") or [])
    job = next((item for item in jobs if item.get("id") == key), None)
    if job is None and resolved_run_id != Path(run_dir).name:
        alt = job_key(run_id=str(store.get("run_id") or ""), rung=str(rung), model=str(model))
        job = next((item for item in jobs if item.get("id") == alt), None)
    if job is None:
        return {
            "ok": False,
            "action": "missing",
            "execute": False,
            "ask": None,
            "error": f"no schedule for {key}",
        }
    if job.get("status") == "executed":
        return {
            "ok": True,
            "action": "already_consumed",
            "execute": False,
            "ask": None,
            "job": job,
        }
    if not _job_due(job, moment) and job.get("status") == "scheduled":
        return {
            "ok": True,
            "action": "not_due",
            "execute": False,
            "ask": None,
            "job": job,
        }
    ladder = detect_ladder_status(run_dir)
    if ladder["over"]:
        job["status"] = "asked"
        job["asked_at"] = isoformat_z(moment)
        ask = ask_user_prompt(
            run_id=str(job.get("run_id") or resolved_run_id),
            rung=str(job.get("rung") or rung),
            model=str(job.get("model") or model),
            ladder_status=str(ladder["status"]),
        )
        job["ask"] = ask
        store["jobs"] = jobs
        store["updated_at"] = isoformat_z(moment)
        _write_json(schedule_path(run_dir), store)
        artifact = write_user_visible_artifact(run_dir, action="ask_user", ask=ask, job=job)
        return {
            "ok": True,
            "action": "ask_user",
            "execute": False,
            "ask": ask,
            "artifact": str(artifact) if artifact else None,
            "ladder_status": ladder["status"],
            "job": job,
        }
    job["status"] = "executed"
    job["executed_at"] = isoformat_z(moment)
    store["jobs"] = jobs
    store["updated_at"] = isoformat_z(moment)
    _write_json(schedule_path(run_dir), store)
    artifact = write_user_visible_artifact(run_dir, action="retry_rung", ask=None, job=job)
    return {
        "ok": True,
        "action": "retry_rung",
        "execute": True,
        "ask": None,
        "artifact": str(artifact) if artifact else None,
        "rung": job.get("rung"),
        "model": job.get("model"),
        "same_named_model": True,
        "substitute_model": None,
        "ladder_status": ladder["status"],
        "job": job,
    }


def due_quota_retries(
    run_dir: Path,
    *,
    now: datetime | None = None,
) -> dict[str, Any]:
    moment = now or utcnow()
    store = load_schedule(run_dir)
    due = [
        job
        for job in list(store.get("jobs") or [])
        if job.get("status") in {"scheduled", "asked"} and _job_due(job, moment)
    ]
    return {
        "ok": True,
        "path": str(schedule_path(run_dir)),
        "due": due,
        "count": len(due),
    }

ASK_FILENAME = "QUOTA-RETRY-ASK.md"
EXECUTE_FILENAME = "QUOTA-RETRY-EXECUTE.md"


def infer_project_root(run_dir: Path) -> Path:
    path = Path(run_dir).resolve()
    if path.parent.name == ".planning":
        return path.parent.parent
    env = os.environ.get("SB_RFL_PROJECT_ROOT", "").strip()
    if env:
        return Path(env)
    return Path.cwd()


def resolver_path() -> Path:
    return Path(__file__).resolve().parent.parent / "review-fix-ladder.py"


def wake_argv(*, project_root: Path, run_dir: Path) -> list[str]:
    return [
        sys.executable,
        str(resolver_path()),
        "--quota-retry-wake",
        "--project-root",
        str(Path(project_root)),
        "--run-dir",
        str(Path(run_dir)),
    ]


def _attach_timer(run_dir: Path, job_id: str, timer: dict[str, Any]) -> None:
    store = load_schedule(run_dir)
    jobs = list(store.get("jobs") or [])
    for job in jobs:
        if job.get("id") == job_id:
            job["timer"] = timer
    store["jobs"] = jobs
    _write_json(schedule_path(run_dir), store)


def _xml_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _at_timestamp(fire_at: datetime) -> str:
    return fire_at.astimezone().strftime("%Y%m%d%H%M")


def arm_quota_retry_timer(
    *,
    job: dict[str, Any],
    run_dir: Path,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Arm an OS timer that runs --quota-retry-wake at fire_at.

    Backends: mock (tests), `at`, launchd. JSON remains the source of truth.
    """
    _ = now
    fire_at = parse_iso_datetime(str(job.get("fire_at") or "")) or utcnow()
    project_root = infer_project_root(run_dir)
    argv = wake_argv(project_root=project_root, run_dir=run_dir)
    command = subprocess.list2cmdline(argv)
    mode = (os.environ.get("SB_RFL_TIMER_MODE") or "auto").strip().lower()
    existing = job.get("timer") if isinstance(job.get("timer"), dict) else {}
    if existing.get("armed") and existing.get("fire_at") == job.get("fire_at"):
        return existing

    payload = {
        "armed": False,
        "backend": "unarmed",
        "fire_at": job.get("fire_at"),
        "command": command,
        "argv": argv,
    }
    if mode == "mock":
        payload.update({"armed": True, "backend": "mock"})
        return payload

    def _try_at() -> dict[str, Any] | None:
        at_bin = os.environ.get("SB_RFL_AT_BIN", "at")
        at_path = Path(at_bin) if "/" in at_bin else Path(shutil.which(at_bin) or "")
        if not at_path or not (at_path.is_file() or shutil.which(at_bin)):
            return None
        try:
            proc = subprocess.run(
                [at_bin, "-t", _at_timestamp(fire_at)],
                input=command + "\n",
                text=True,
                capture_output=True,
                check=False,
            )
        except OSError as exc:
            payload["at_error"] = str(exc)
            return None
        if proc.returncode == 0:
            return {
                "armed": True,
                "backend": "at",
                "at_bin": at_bin,
                "fire_at": job.get("fire_at"),
                "command": command,
                "argv": argv,
                "stderr": (proc.stderr or "").strip()[:300],
            }
        payload["at_error"] = (proc.stderr or proc.stdout or "").strip()[:300]
        return None

    def _try_launchd() -> dict[str, Any] | None:
        if sys.platform != "darwin" and mode not in {"launchd", "launchd-only"}:
            return None
        launchd_dir = Path(
            os.environ.get("SB_RFL_LAUNCHD_DIR")
            or (Path.home() / "Library" / "LaunchAgents")
        )
        label = "dev.alolabs.sb.rfl-quota-retry." + (
            str(job.get("id") or "job").replace("/", "-").replace(":", "-")[:80]
        )
        plist = launchd_dir / f"{label}.plist"
        local = fire_at.astimezone()
        args_xml = "".join(f"<string>{_xml_escape(arg)}</string>" for arg in argv)
        body = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
            '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            "<plist version=\"1.0\">\n<dict>\n"
            f"  <key>Label</key><string>{_xml_escape(label)}</string>\n"
            "  <key>ProgramArguments</key>\n  <array>\n"
            f"    {args_xml}\n"
            "  </array>\n"
            "  <key>StartCalendarInterval</key>\n  <dict>\n"
            f"    <key>Year</key><integer>{local.year}</integer>\n"
            f"    <key>Month</key><integer>{local.month}</integer>\n"
            f"    <key>Day</key><integer>{local.day}</integer>\n"
            f"    <key>Hour</key><integer>{local.hour}</integer>\n"
            f"    <key>Minute</key><integer>{local.minute}</integer>\n"
            "  </dict>\n"
            "  <key>RunAtLoad</key><false/>\n"
            "</dict>\n</plist>\n"
        )
        try:
            launchd_dir.mkdir(parents=True, exist_ok=True)
            plist.write_text(body, encoding="utf-8")
            if os.environ.get("SB_RFL_LAUNCHCTL") != "0":
                subprocess.run(
                    ["launchctl", "unload", str(plist)],
                    capture_output=True,
                    check=False,
                )
                loaded = subprocess.run(
                    ["launchctl", "load", str(plist)],
                    capture_output=True,
                    check=False,
                )
                payload["launchctl_rc"] = loaded.returncode
            return {
                "armed": True,
                "backend": "launchd",
                "fire_at": job.get("fire_at"),
                "command": command,
                "argv": argv,
                "label": label,
                "plist": str(plist),
            }
        except OSError as exc:
            payload["launchd_error"] = str(exc)
            return None

    # Darwin: launchd is the reliable wake (atrun is often disabled).
    # Linux/other: `at`. Hooks still activate due jobs when a session returns.
    prefer_launchd = sys.platform == "darwin" or mode in {"launchd", "launchd-only"}
    if prefer_launchd and mode != "at-only":
        launched = _try_launchd()
        if launched:
            return launched
    if mode != "launchd-only":
        queued = _try_at()
        if queued:
            return queued
    if not prefer_launchd:
        launched = _try_launchd()
        if launched:
            return launched

    payload["reason"] = "no at/launchd backend available"
    return payload


def write_user_visible_artifact(
    run_dir: Path,
    *,
    action: str,
    ask: str | None,
    job: dict[str, Any],
) -> Path | None:
    root = Path(run_dir)
    root.mkdir(parents=True, exist_ok=True)
    if action == "ask_user":
        path = root / ASK_FILENAME
        path.write_text(
            "# RFL quota retry — confirm with the user\n\n"
            f"{ask or ask_user_prompt(run_id=str(job.get('run_id') or ''), rung=str(job.get('rung') or ''), model=str(job.get('model') or ''), ladder_status='over')}\n\n"
            "Do **not** execute this rung until the user answers yes.\n",
            encoding="utf-8",
        )
        return path
    if action == "retry_rung":
        path = root / EXECUTE_FILENAME
        path.write_text(
            "# RFL quota retry — execute now\n\n"
            f"- Run: `{job.get('run_id')}`\n"
            f"- Rung: `{job.get('rung')}`\n"
            f"- Model: `{job.get('model')}` (same named model; do not substitute Grok)\n"
            "- The ladder run is still active. Execute this deferred rung now.\n",
            encoding="utf-8",
        )
        return path
    return None


def notify_user(title: str, body: str) -> bool:
    if os.environ.get("SB_RFL_NOTIFY", "1") == "0":
        return False
    text = body.replace('"', "'")[:180]
    heading = title.replace('"', "'")[:60]
    try:
        proc = subprocess.run(
            [
                "osascript",
                "-e",
                f'display notification "{text}" with title "{heading}"',
            ],
            capture_output=True,
            check=False,
        )
        return proc.returncode == 0
    except OSError:
        return False


def discover_run_dirs(project_root: Path) -> list[Path]:
    planning = Path(project_root) / ".planning"
    if not planning.is_dir():
        return []
    return sorted({path.parent for path in planning.glob("rfl-*/" + SCHEDULE_FILENAME)})


def visible_artifacts(run_dir: Path) -> tuple[list[str], list[str]]:
    """Re-surface ASK/EXECUTE files until QUOTA-RETRY-ACK.md exists."""
    root = Path(run_dir)
    if (root / "QUOTA-RETRY-ACK.md").is_file():
        return [], []
    ask_path = root / ASK_FILENAME
    exec_path = root / EXECUTE_FILENAME
    asks: list[str] = []
    executes: list[str] = []
    if ask_path.is_file():
        body = ask_path.read_text(encoding="utf-8")
        paragraph = next(
            (
                line.strip()
                for line in body.splitlines()
                if line.strip() and not line.startswith("#")
            ),
            "",
        )
        asks.append(paragraph or "Quota retry is due; ask the user before executing.")
        return asks, []
    if exec_path.is_file():
        executes.append(
            "A due quota retry is ready. Execute the deferred rung on the same named model."
        )
    return asks, executes


def wake_due_jobs(
    *,
    project_root: Path | None = None,
    run_dir: Path | None = None,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Activate every due job. This is what `at` / launchd / SessionStart call."""
    moment = now or utcnow()
    dirs: list[Path]
    if run_dir is not None:
        dirs = [Path(run_dir)]
    elif project_root is not None:
        dirs = discover_run_dirs(project_root)
    else:
        dirs = []
    results: list[dict[str, Any]] = []
    asks: list[str] = []
    executes: list[str] = []
    surfaced: set[str] = set()
    for directory in dirs:
        store = load_schedule(directory)
        for job in list(store.get("jobs") or []):
            if job.get("status") not in {"scheduled", "asked"}:
                continue
            if not _job_due(job, moment):
                results.append(
                    {
                        "ok": True,
                        "action": "not_due",
                        "execute": False,
                        "job_id": job.get("id"),
                        "fire_at": job.get("fire_at"),
                    }
                )
                continue
            activated = activate_quota_retry(
                run_dir=directory,
                run_id=str(job.get("run_id") or ""),
                rung=str(job.get("rung") or ""),
                model=str(job.get("model") or ""),
                now=moment,
            )
            if activated.get("action") == "ask_user" and activated.get("ask"):
                asks.append(str(activated["ask"]))
                surfaced.add(str(directory))
                notify_user("RFL quota retry — confirm", str(activated["ask"]))
            elif activated.get("action") == "retry_rung":
                executes.append(
                    f"Execute rung {activated.get('rung')} on {activated.get('model')} (same model)."
                )
                surfaced.add(str(directory))
                notify_user(
                    "RFL quota retry — execute",
                    f"Retry rung {activated.get('rung')} on {activated.get('model')}",
                )
            results.append(activated)
    for directory in dirs:
        if str(directory) in surfaced:
            continue
        extra_asks, extra_execs = visible_artifacts(directory)
        for item in extra_asks:
            if item not in asks:
                asks.append(item)
        for item in extra_execs:
            if item not in executes:
                executes.append(item)
    payload = {
        "ok": True,
        "woke_at": isoformat_z(moment),
        "run_dirs": [str(d) for d in dirs],
        "results": results,
        "asks": asks,
        "executes": executes,
        "user_visible": asks + executes,
    }
    payload["hook_context"] = hook_additional_context(payload)
    return payload


def hook_additional_context(wake: dict[str, Any]) -> str:
    parts: list[str] = []
    for ask in wake.get("asks") or []:
        parts.append(
            "RFL SCHEDULED WORKER (user-visible ask): " + str(ask)
        )
    for exe in wake.get("executes") or []:
        parts.append(
            "RFL SCHEDULED WORKER: " + str(exe)
            + " The 5-hour (or ≤5h) quota window has ended. Do this now."
        )
    return "\n\n".join(parts)
