#!/usr/bin/env python3
"""Quota-window classification: 5-hour vs weekly vs monthly vs billing vs unknown.

One module (the Claude/Anthropic 5-hour handling that used to monkey-patch the old
rfl_quota_retry classifier is folded in). Classification only: nothing here schedules
timers, wakes sessions or touches the disk. A native subagent shares the parent's account,
so a usage limit stops the parent too; callers record a pause and the user resumes.
The ``--classify-quota-window`` JSON contract (quota_class, should_schedule,
should_short_retry, reset_seconds, ...) is consumed by scripts/lib/agent-delegate-common.sh.
"""

from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from typing import Any

FIVE_HOURS_SECONDS = 5 * 3600
SHORT_RETRY_MAX_SECONDS = 300

_DURATION_TOKEN_RE = re.compile(
    r"(?P<n>\d+(?:\.\d+)?)\s*"
    r"(?P<u>hours?|hrs?|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b",
    re.IGNORECASE,
)
_RESET_PREFIX_RE = re.compile(r"(?:resets?\s+in|reset\s+after|resets?\s+after)\s+", re.IGNORECASE)
_FIVE_HOUR_RE = re.compile(
    r"(?:5[\s-]*hour|five[\s-]*hour).{0,48}(?:usage\s+)?(?:limit|cap|quota)|"
    r"(?:usage\s+)?(?:limit|cap|quota).{0,48}(?:5[\s-]*hour|five[\s-]*hour)",
    re.IGNORECASE | re.DOTALL,
)
_WEEKLY_RE = re.compile(
    r"\bweekly\b.{0,48}(?:limit|cap|quota)|(?:limit|cap|quota).{0,48}\bweekly\b|"
    r"\bweek(?:ly)?\s+(?:usage\s+)?(?:limit|cap|quota)",
    re.IGNORECASE | re.DOTALL,
)
_MONTHLY_RE = re.compile(
    r"\bmonthly\b.{0,48}(?:limit|cap|quota)|(?:limit|cap|quota).{0,48}\bmonthly\b|"
    r"\bmonth(?:ly)?\s+(?:usage\s+)?(?:limit|cap|quota)",
    re.IGNORECASE | re.DOTALL,
)
_BILLING_RE = re.compile(
    r"(?:^|[^0-9])401(?:[^0-9]|$)|insufficient(?:_|\s+)(?:balance|credits|funds|quota)|"
    r"invalid_api_key|invalid\s+api\s+key|missing\s+api\s+key",
    re.IGNORECASE,
)
_QUOTA_LIKE_RE = re.compile(
    r"\b429\b|rate[\s_-]*limit|token[\s_-]*plan|out of quota|quota[\s_-]*(?:exhaust|exceed)|"
    r"quota retries exhausted|usage[\s_-]*(?:cap|limit)|billed[\s_-]*quota|over[\s_-]*quota|\bquota\b",
    re.IGNORECASE,
)
_UNIT_SECONDS = {
    "h": 3600, "hr": 3600, "hrs": 3600, "hour": 3600, "hours": 3600,
    "m": 60, "min": 60, "mins": 60, "minute": 60, "minutes": 60,
    "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1,
}

_CLAUDE_RE = re.compile(r"\b(?:claude|anthropic)\b", re.IGNORECASE)
_CLAUDE_QUOTA_LIKE_RE = re.compile(
    r"\b429\b|rate[\s_-]*limit|rate_limit_error|token[\s_-]*plan|"
    r"out of quota|quota[\s_-]*(?:exhaust|exceed)|usage[\s_-]*(?:cap|limit)|"
    r"billed[\s_-]*quota|over[\s_-]*quota|\bquota\b|retry[-_ ]after|"
    r"x-ratelimit-reset|5[\s-]*h(?:ou)?rs?",
    re.IGNORECASE,
)
_RETRY_AFTER_INT_RE = re.compile(r"retry[-_ ]after[\"']?\s*[:=]\s*[\"']?(\d{2,7})\b", re.IGNORECASE)
_FIVE_HR_SHORTHAND_RE = re.compile(r"5[\s-]*hrs?(?![a-z])|five[\s-]*hrs?(?![a-z])", re.IGNORECASE)
_ISO_RESET_RE = re.compile(
    r"(?:reset[s_]*(?:at)?|wake_at)\s*[\"':=]+\s*"
    r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?Z?)",
    re.IGNORECASE,
)


def utcnow() -> datetime:
    """Current UTC time; SB_RFL_NOW (ISO-8601) is the single documented test seam."""
    seam = parse_iso_datetime(os.environ.get("SB_RFL_NOW"))
    return seam if seam is not None else datetime.now(timezone.utc)


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
    rest = text[match.end():]
    cut = re.search(r"\.(?:\s|$)|[\n;]|\[", rest)
    span = rest[: cut.start()] if cut else rest
    total = 0.0
    found = False
    for token in _DURATION_TOKEN_RE.finditer(span):
        found = True
        total += float(token.group("n")) * _UNIT_SECONDS[token.group("u").lower()]
    return int(total) if found else None


def enrich_quota_blob(blob: str | None, now: datetime | None = None) -> str:
    """Normalise Omni/Claude wording so the classifier sees '5-hour' and a reset phrase."""
    text = blob or ""
    bits = [text]
    if _FIVE_HR_SHORTHAND_RE.search(text) and re.search(r"quota|limit|cap", text, re.IGNORECASE):
        if not re.search(r"5[\s-]*hour|five[\s-]*hour", text, re.IGNORECASE):
            bits.append("5-hour usage limit")
    retry_after = _RETRY_AFTER_INT_RE.search(text)
    if retry_after is not None and not _RESET_PREFIX_RE.search(text):
        bits.append(f"Resets in {int(retry_after.group(1))}s")
    iso = _ISO_RESET_RE.search(text)
    if iso and not _RESET_PREFIX_RE.search(text):
        parsed = parse_iso_datetime(iso.group(1))
        if parsed is not None:
            delay = max(0, int((parsed - (now or utcnow())).total_seconds()))
            bits.append(f"Resets in {delay}s")
    return "\n".join(bits)


def _classify(text: str) -> dict[str, Any]:
    reset_seconds = parse_reset_seconds(text)
    reset_within_5h = reset_seconds is not None and reset_seconds <= FIVE_HOURS_SECONDS
    delay: int | None = None
    if _FIVE_HOUR_RE.search(text):
        quota_class, should_schedule = "five_hour", True
        delay = reset_seconds if reset_seconds is not None else FIVE_HOURS_SECONDS
    elif _BILLING_RE.search(text):
        quota_class, should_schedule = "billing", False
    elif _WEEKLY_RE.search(text):
        quota_class, should_schedule = "weekly", bool(reset_within_5h)
    elif _MONTHLY_RE.search(text):
        quota_class, should_schedule = "monthly", bool(reset_within_5h)
    elif _QUOTA_LIKE_RE.search(text):
        quota_class, should_schedule = "unknown", bool(reset_within_5h)
    else:
        quota_class, should_schedule = "not_quota", False
    if quota_class in {"weekly", "monthly", "unknown"} and should_schedule:
        delay = reset_seconds
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


def _host_from_env(host: str = "", model: str = "") -> tuple[str, str]:
    host = host or os.environ.get("SB_RFL_QUOTA_HOST", "") or os.environ.get("PI_PROVIDER", "")
    model = model or os.environ.get("SB_RFL_MODEL", "") or os.environ.get("PI_MODEL", "")
    return host, model


def _upgrade_claude_five_hour(result: dict[str, Any], blob: str, host: str, model: str) -> dict[str, Any]:
    """A generic 429 from Claude/Anthropic is a 5-hour window unless it says weekly/monthly."""
    if result["quota_class"] in {"weekly", "monthly", "five_hour", "billing"}:
        return result
    if not _CLAUDE_RE.search(" ".join((host, model, blob))) or not _CLAUDE_QUOTA_LIKE_RE.search(blob):
        return result
    delay = result.get("reset_seconds")
    upgraded = dict(result)
    upgraded.update(
        quota_class="five_hour",
        should_schedule=True,
        should_short_retry=False,
        schedule_delay_seconds=int(delay) if delay is not None else FIVE_HOURS_SECONDS,
        reset_within_5h=delay is not None and int(delay) <= FIVE_HOURS_SECONDS,
    )
    return upgraded


def classify_quota_window(
    blob: str | None,
    host: str = "",
    model: str = "",
    now: datetime | None = None,
) -> dict[str, Any]:
    host, model = _host_from_env(host, model)
    text = blob or ""
    result = _classify(enrich_quota_blob(text, now))
    return _upgrade_claude_five_hour(result, text, host, model)
