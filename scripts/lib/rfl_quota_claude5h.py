#!/usr/bin/env python3
"""Claude/Anthropic 5-hour quota: upgrade generic 429 and persist wake_at.

Wraps ``rfl_quota_retry.classify_quota_window`` / ``schedule_quota_retry`` so
Pi → OmniRoute → Claude exhaustion schedules a retry. Weekly/monthly stay
HOLD (never upgraded to five_hour, never given a 5h wake).
"""

from __future__ import annotations

import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import rfl_quota_retry as _qr

_CLAUDE_RE = re.compile(r"\b(?:claude|anthropic)\b", re.IGNORECASE)
_WEEKLY_HINT_RE = re.compile(
    r"\bweekly\b.{0,48}(?:limit|cap|quota)|(?:limit|cap|quota).{0,48}\bweekly\b",
    re.IGNORECASE | re.DOTALL,
)
_MONTHLY_HINT_RE = re.compile(
    r"\bmonthly\b.{0,48}(?:limit|cap|quota)|(?:limit|cap|quota).{0,48}\bmonthly\b",
    re.IGNORECASE | re.DOTALL,
)
_QUOTA_LIKE_RE = re.compile(
    r"\b429\b|rate[\s_-]*limit|rate_limit_error|token[\s_-]*plan|"
    r"out of quota|quota[\s_-]*(?:exhaust|exceed)|usage[\s_-]*(?:cap|limit)|"
    r"billed[\s_-]*quota|over[\s_-]*quota|\bquota\b|retry[-_ ]after|"
    r"x-ratelimit-reset|5[\s-]*h(?:ou)?rs?",
    re.IGNORECASE,
)
_RETRY_AFTER_INT_RE = re.compile(
    r"retry[-_ ]after[\"']?\s*[:=]\s*[\"']?(\d{2,7})\b",
    re.IGNORECASE,
)
_FIVE_HR_SHORTHAND_RE = re.compile(
    r"5[\s-]*hrs?(?![a-z])|five[\s-]*hrs?(?![a-z])",
    re.IGNORECASE,
)
_ISO_RESET_RE = re.compile(
    r"(?:reset[s_]*(?:at)?|wake_at)\s*[\"':=]+\s*"
    r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?Z?)",
    re.IGNORECASE,
)

FIVE_HOURS_SECONDS = _qr.FIVE_HOURS_SECONDS
_ORIG_CLASSIFY = _qr.classify_quota_window
_ORIG_SCHEDULE = _qr.schedule_quota_retry


def _is_claude(host: str, model: str, blob: str) -> bool:
    return bool(_CLAUDE_RE.search(" ".join((host or "", model or "", blob or ""))))


def _host_from_env(host: str = "", model: str = "") -> tuple[str, str]:
    host = (
        host
        or os.environ.get("SB_RFL_QUOTA_HOST", "")
        or os.environ.get("PI_PROVIDER", "")
    )
    model = (
        model
        or os.environ.get("SB_RFL_MODEL", "")
        or os.environ.get("PI_MODEL", "")
    )
    return host, model


def enrich_quota_blob(blob: str) -> str:
    """Normalize Omni/Claude wording so the core classifier sees 5-hour + reset."""
    text = blob or ""
    bits = [text]
    if _FIVE_HR_SHORTHAND_RE.search(text) and re.search(
        r"quota|limit|cap", text, re.IGNORECASE
    ):
        if not re.search(r"5[\s-]*hour|five[\s-]*hour", text, re.IGNORECASE):
            bits.append("5-hour usage limit")
    retry_after = _RETRY_AFTER_INT_RE.search(text)
    if retry_after is not None and not _qr._RESET_PREFIX_RE.search(text):
        bits.append(f"Resets in {int(retry_after.group(1))}s")
    iso = _ISO_RESET_RE.search(text)
    if iso and not _qr._RESET_PREFIX_RE.search(text):
        parsed = _qr.parse_iso_datetime(iso.group(1))
        if parsed is not None:
            delay = max(0, int((parsed - _qr.utcnow()).total_seconds()))
            bits.append(f"Resets in {delay}s")
    return "\n".join(bits)


def apply_claude_five_hour(
    result: dict[str, Any],
    *,
    blob: str,
    host: str = "",
    model: str = "",
) -> dict[str, Any]:
    """Generic 429 from Claude/Anthropic is a 5h window unless weekly/monthly."""
    quota_class = str(result.get("quota_class") or "")
    if quota_class in {"weekly", "monthly"}:
        return result
    if _WEEKLY_HINT_RE.search(blob or "") or _MONTHLY_HINT_RE.search(blob or ""):
        return result
    if quota_class == "five_hour":
        return result
    if quota_class == "billing":
        return result
    host, model = _host_from_env(host, model)
    if not _is_claude(host, model, blob):
        return result
    if not _QUOTA_LIKE_RE.search(blob or ""):
        return result
    upgraded = dict(result)
    upgraded["quota_class"] = "five_hour"
    upgraded["should_schedule"] = True
    upgraded["should_short_retry"] = False
    delay = upgraded.get("reset_seconds")
    upgraded["schedule_delay_seconds"] = (
        int(delay) if delay is not None else FIVE_HOURS_SECONDS
    )
    upgraded["reset_within_5h"] = delay is not None and int(delay) <= FIVE_HOURS_SECONDS
    return upgraded


def classify_quota_window(
    blob: str,
    host: str = "",
    model: str = "",
    now: datetime | None = None,
) -> dict[str, Any]:
    _ = now
    host, model = _host_from_env(host, model)
    enriched = enrich_quota_blob(blob)
    result = _ORIG_CLASSIFY(enriched)
    return apply_claude_five_hour(result, blob=blob, host=host, model=model)


def _override_wake_at(job: dict[str, Any], fire_at: datetime) -> None:
    iso = _qr.isoformat_z(fire_at)
    job["fire_at"] = iso
    job["wake_at"] = iso
    job["reset_at"] = iso


def _attach_wake_fields(
    result: dict[str, Any],
    *,
    run_dir: Path | None,
    now: datetime | None,
    host: str = "",
) -> dict[str, Any]:
    job = result.get("job")
    if not isinstance(job, dict):
        return result
    moment = now or _qr.utcnow()
    fire_at = _qr.parse_iso_datetime(str(job.get("fire_at") or "")) or moment
    reset_seconds = job.get("reset_seconds")
    if reset_seconds is not None:
        reset_at = moment + timedelta(seconds=int(reset_seconds))
    else:
        reset_at = fire_at
    job.setdefault("wake_at", _qr.isoformat_z(fire_at))
    job.setdefault("reset_at", _qr.isoformat_z(reset_at))
    if host:
        job.setdefault("host", host)

    wake_raw = (os.environ.get("SB_RFL_QUOTA_WAKE_AT") or "").strip()
    wake_at = _qr.parse_iso_datetime(wake_raw)
    if (
        wake_at is not None
        and result.get("quota_class") == "five_hour"
        and result.get("should_schedule")
        and str(job.get("quota_class") or result.get("quota_class")) == "five_hour"
    ):
        _override_wake_at(job, wake_at)
        delay = max(0, int((wake_at - moment).total_seconds()))
        job["schedule_delay_seconds"] = delay
        result["schedule_delay_seconds"] = delay
        if run_dir is not None:
            timer = _qr.arm_quota_retry_timer(job=job, run_dir=Path(run_dir), now=moment)
            job["timer"] = timer
            result["timer"] = timer
            result["armed"] = bool(timer.get("armed"))

    result["job"] = job
    result["wake_at"] = job.get("wake_at")
    result["reset_at"] = job.get("reset_at")
    if run_dir is not None and result.get("scheduled"):
        store = _qr.load_schedule(Path(run_dir))
        jobs = list(store.get("jobs") or [])
        key = job.get("id")
        replaced = False
        for idx, existing in enumerate(jobs):
            if existing.get("id") == key:
                jobs[idx] = job
                replaced = True
                break
        if not replaced:
            jobs.append(job)
        store["jobs"] = jobs
        store["updated_at"] = _qr.isoformat_z(moment)
        _qr._write_json(_qr.schedule_path(Path(run_dir)), store)
    return result


def schedule_quota_retry(
    *,
    run_dir: Path,
    run_id: str,
    rung: str,
    model: str,
    output: str,
    now: datetime | None = None,
    host: str = "",
    wake_at: datetime | None = None,
) -> dict[str, Any]:
    host, model = _host_from_env(host, model)
    if wake_at is not None:
        os.environ["SB_RFL_QUOTA_WAKE_AT"] = _qr.isoformat_z(wake_at)
    enriched = enrich_quota_blob(output)
    result = _ORIG_SCHEDULE(
        run_dir=run_dir,
        run_id=run_id,
        rung=rung,
        model=model,
        output=enriched,
        now=now,
    )
    return _attach_wake_fields(
        result, run_dir=Path(run_dir), now=now, host=host
    )


def install() -> None:
    """Patch the in-process ``rfl_quota_retry`` functions (same module object)."""
    _qr.classify_quota_window = classify_quota_window  # type: ignore[method-assign]
    _qr.schedule_quota_retry = schedule_quota_retry  # type: ignore[method-assign]


def bind_cli_env(*, host: str = "", model: str = "", wake_at: str = "") -> None:
    if host:
        os.environ["SB_RFL_QUOTA_HOST"] = host
    if model:
        os.environ.setdefault("SB_RFL_MODEL", model)
        os.environ.setdefault("PI_MODEL", os.environ.get("PI_MODEL") or model)
    if wake_at:
        os.environ["SB_RFL_QUOTA_WAKE_AT"] = wake_at
