"""Unit tests for scripts/lib/quota_window.py (classification only, no timers, no disk)."""
from __future__ import annotations

import os
import unittest
from datetime import datetime, timezone
from unittest import mock

from sbtest import load_module

q = load_module("scripts/lib/quota_window.py", name="quota_window_under_test")

NOW = datetime(2030, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
ENV_KEYS = ("SB_RFL_QUOTA_HOST", "PI_PROVIDER", "SB_RFL_MODEL", "PI_MODEL", "SB_RFL_NOW")


class Base(unittest.TestCase):
    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k not in ENV_KEYS}
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)


class TimeTest(Base):
    def test_parse_iso_datetime(self):
        self.assertIsNone(q.parse_iso_datetime(None))
        self.assertIsNone(q.parse_iso_datetime("  "))
        self.assertIsNone(q.parse_iso_datetime("not a date"))
        self.assertEqual(q.parse_iso_datetime("2030-01-01T12:00:00Z"), NOW)
        self.assertEqual(q.parse_iso_datetime("2030-01-01T12:00:00"), NOW)
        self.assertEqual(q.parse_iso_datetime("2030-01-01T14:00:00+02:00"), NOW)

    def test_isoformat_z(self):
        self.assertEqual(q.isoformat_z(NOW), "2030-01-01T12:00:00Z")

    def test_utcnow_uses_the_single_test_seam_or_the_clock(self):
        os.environ["SB_RFL_NOW"] = "2030-01-01T12:00:00Z"
        self.assertEqual(q.utcnow(), NOW)
        del os.environ["SB_RFL_NOW"]
        self.assertIsNotNone(q.utcnow().tzinfo)
        os.environ["SB_RFL_NOW"] = "garbage"
        self.assertIsNotNone(q.utcnow().tzinfo)


class ParseResetTest(Base):
    def test_cases(self):
        for text, want in (
            ("Resets in 3hr 6min", 3 * 3600 + 6 * 60),
            ("reset after 59m 36s", 59 * 60 + 36),
            ("resets after 90 seconds.", 90),
            ("Resets in 2.5 hours", 9000),
            ("no reset here", None),
            ("Resets in soon", None),
            ("", None),
            (None, None),
        ):
            self.assertEqual(q.parse_reset_seconds(text), want, text)


class ClassifyTest(Base):
    def check(self, blob, cls, schedule, delay, short=False, **kw):
        out = q.classify_quota_window(blob, **kw)
        self.assertEqual(
            (out["quota_class"], out["should_schedule"], out["schedule_delay_seconds"], out["should_short_retry"]),
            (cls, schedule, delay, short),
            blob,
        )
        return out

    def test_classes(self):
        self.check("You hit your 5-hour usage limit. Resets in 2hr", "five_hour", True, 7200)
        self.check("five hour quota exceeded", "five_hour", True, 5 * 3600)
        self.check("HTTP 401 unauthorized", "billing", False, None)
        self.check("insufficient_balance", "billing", False, None)
        self.check("weekly limit reached. Resets in 2h", "weekly", True, 7200)
        self.check("weekly limit reached. Resets in 30h", "weekly", False, None)
        self.check("monthly quota. resets in 1h", "monthly", True, 3600)
        self.check("monthly cap reached", "monthly", False, None)
        self.check("429 too many requests", "unknown", False, None, short=True)
        self.check("rate limit. resets in 4m", "unknown", True, 240, short=True)
        self.check("rate limit. resets in 1h", "unknown", True, 3600)
        self.check("rate limit. resets in 9h", "unknown", False, None)
        self.check("all fine", "not_quota", False, None)
        self.check(None, "not_quota", False, None)

    def test_contract_keys(self):
        out = q.classify_quota_window("rate limit. resets in 1h")
        for key in ("quota_class", "should_schedule", "should_short_retry", "reset_seconds"):
            self.assertIn(key, out)
        self.assertEqual(out["reset_seconds"], 3600)
        self.assertIs(out["reset_within_5h"], True)
        self.assertIs(out["same_named_model"], True)
        self.assertIsNone(out["substitute_model"])
        self.assertIs(q.classify_quota_window("weekly limit. resets in 30h")["reset_within_5h"], False)


class ClaudeFiveHourTest(Base):
    def test_generic_claude_429_becomes_five_hour(self):
        out = self.sub("Error 429 rate limit", host="claude")
        self.assertEqual(out["quota_class"], "five_hour")
        self.assertTrue(out["should_schedule"])
        self.assertFalse(out["should_short_retry"])
        self.assertEqual(out["schedule_delay_seconds"], 18000)
        self.assertFalse(out["reset_within_5h"])

    def sub(self, blob, **kw):
        return q.classify_quota_window(blob, **kw)

    def test_retry_after_sets_delay(self):
        out = self.sub("anthropic 429 retry-after: 90")
        self.assertEqual((out["quota_class"], out["schedule_delay_seconds"]), ("five_hour", 90))
        self.assertTrue(out["reset_within_5h"])

    def test_weekly_monthly_billing_stay(self):
        self.assertEqual(self.sub("claude weekly usage limit reached", host="claude")["quota_class"], "weekly")
        self.assertEqual(self.sub("claude monthly cap reached")["quota_class"], "monthly")
        self.assertEqual(self.sub("claude 401 unauthorized")["quota_class"], "billing")

    def test_non_claude_or_non_quota_not_upgraded(self):
        self.assertEqual(self.sub("429 rate limit", host="openai", now=NOW)["quota_class"], "unknown")
        self.assertEqual(self.sub("claude is fine")["quota_class"], "not_quota")
        self.assertEqual(self.sub("claude says hello")["quota_class"], "not_quota")

    def test_host_and_model_from_environment(self):
        os.environ["PI_PROVIDER"] = "claude"
        self.assertEqual(self.sub("429 rate limit")["quota_class"], "five_hour")
        del os.environ["PI_PROVIDER"]
        os.environ["SB_RFL_QUOTA_HOST"] = "other"
        os.environ["SB_RFL_MODEL"] = "claude/opus"
        self.assertEqual(self.sub("429 rate limit")["quota_class"], "five_hour")
        os.environ["SB_RFL_MODEL"] = ""
        os.environ["PI_MODEL"] = "anthropic/x"
        self.assertEqual(self.sub("429 rate limit")["quota_class"], "five_hour")


class EnrichTest(Base):
    def test_empty_and_none(self):
        self.assertEqual(q.enrich_quota_blob(""), "")
        self.assertEqual(q.enrich_quota_blob(None), "")
        self.assertEqual(q.enrich_quota_blob("nothing relevant"), "nothing relevant")

    def test_five_hour_shorthand(self):
        self.assertEqual(q.enrich_quota_blob("5hr quota hit"), "5hr quota hit\n5-hour usage limit")
        self.assertEqual(q.enrich_quota_blob("five hrs cap"), "five hrs cap\n5-hour usage limit")
        self.assertEqual(q.enrich_quota_blob("5hr limit, five hour limit"), "5hr limit, five hour limit")
        self.assertEqual(q.enrich_quota_blob("5hr"), "5hr")
        self.assertEqual(q.enrich_quota_blob("5hrsx limit"), "5hrsx limit")

    def test_retry_after(self):
        self.assertEqual(q.enrich_quota_blob("429 retry-after: 120"), "429 retry-after: 120\nResets in 120s")
        self.assertEqual(q.enrich_quota_blob("retry-after: 5"), "retry-after: 5")
        self.assertEqual(q.enrich_quota_blob("resets in 5m, retry-after: 120"), "resets in 5m, retry-after: 120")

    def test_iso_reset_relative_to_now(self):
        out = q.enrich_quota_blob('{"reset_at":"2030-01-01T13:00:00Z"}', NOW)
        self.assertTrue(out.endswith("\nResets in 3600s"))
        self.assertTrue(q.enrich_quota_blob("resets_at=2030-01-01T12:30Z", NOW).endswith("\nResets in 1800s"))
        self.assertTrue(q.enrich_quota_blob("reset_at: 2020-01-01T00:00:00Z", NOW).endswith("\nResets in 0s"))
        os.environ["SB_RFL_NOW"] = "2030-01-01T12:00:00Z"
        self.assertTrue(q.enrich_quota_blob("wake_at: 2030-01-01T12:00:10").endswith("\nResets in 10s"))

    def test_unparseable_iso_and_existing_prefix_ignored(self):
        self.assertEqual(q.enrich_quota_blob("reset_at: 2030-13-45T00:00:00Z"), "reset_at: 2030-13-45T00:00:00Z")
        text = "resets in 1h reset_at: 2030-01-01T13:00:00Z"
        self.assertEqual(q.enrich_quota_blob(text), text)


if __name__ == "__main__":
    unittest.main()
