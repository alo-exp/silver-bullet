"""Unit tests for scripts/lib/rfl_quota_claude5h.py (frozen clock, no real timers)."""
from __future__ import annotations

import json
import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from sbtest import load_module

c5 = load_module("scripts/lib/rfl_quota_claude5h.py")
qr = c5._qr

NOW = datetime(2030, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
ENV_KEYS = ("SB_RFL_QUOTA_HOST", "PI_PROVIDER", "SB_RFL_MODEL", "PI_MODEL", "SB_RFL_QUOTA_WAKE_AT")


class Base(unittest.TestCase):
    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k not in ENV_KEYS}
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        clock = mock.patch.object(qr, "utcnow", return_value=NOW)
        clock.start()
        self.addCleanup(clock.stop)
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.run_dir = Path(self._tmp.name) / "run-1"
        self.run_dir.mkdir()
        self.timers = []

        def fake_arm(*, job, run_dir, now):
            self.timers.append((job.get("id"), str(run_dir), now))
            return {"armed": True, "mechanism": "fake"}

        arm = mock.patch.object(qr, "arm_quota_retry_timer", side_effect=fake_arm)
        arm.start()
        self.addCleanup(arm.stop)


class HostEnvTest(Base):

    def test_claude_detection(self):
        self.assertTrue(c5._is_claude("Claude", "", ""))
        self.assertTrue(c5._is_claude("", "anthropic/sonnet", ""))
        self.assertTrue(c5._is_claude("", "", "error from Anthropic api"))
        self.assertFalse(c5._is_claude("openai", "gpt", "429"))
        self.assertFalse(c5._is_claude("", "", ""))
        self.assertFalse(c5._is_claude(None, None, None))
        self.assertFalse(c5._is_claude("claudette", "", ""))

    def test_host_from_env_precedence(self):
        self.assertEqual(c5._host_from_env(), ("", ""))
        os.environ.update({"PI_PROVIDER": "pi", "PI_MODEL": "pim"})
        self.assertEqual(c5._host_from_env(), ("pi", "pim"))
        os.environ.update({"SB_RFL_QUOTA_HOST": "sbh", "SB_RFL_MODEL": "sbm"})
        self.assertEqual(c5._host_from_env(), ("sbh", "sbm"))
        self.assertEqual(c5._host_from_env("arg", "argm"), ("arg", "argm"))


class EnrichTest(Base):

    def test_empty_and_none(self):
        self.assertEqual(c5.enrich_quota_blob(""), "")
        self.assertEqual(c5.enrich_quota_blob(None), "")
        self.assertEqual(c5.enrich_quota_blob("nothing relevant"), "nothing relevant")

    def test_five_hour_shorthand_adds_phrase_only_when_needed(self):
        self.assertEqual(c5.enrich_quota_blob("5hr quota hit"),
                         "5hr quota hit\n5-hour usage limit")
        self.assertEqual(c5.enrich_quota_blob("five hrs cap"),
                         "five hrs cap\n5-hour usage limit")
        # already spelled out -> unchanged
        self.assertEqual(c5.enrich_quota_blob("5hr limit, five hour limit"),
                         "5hr limit, five hour limit")
        # shorthand without a quota word -> unchanged
        self.assertEqual(c5.enrich_quota_blob("5hr"), "5hr")
        # "5hrs" followed by a letter is not the shorthand
        self.assertEqual(c5.enrich_quota_blob("5hrsx limit"), "5hrsx limit")

    def test_retry_after_becomes_reset_phrase(self):
        self.assertEqual(c5.enrich_quota_blob("429 retry-after: 120"),
                         "429 retry-after: 120\nResets in 120s")
        self.assertEqual(c5.enrich_quota_blob('Retry_After="3600"'),
                         'Retry_After="3600"\nResets in 3600s')
        # one-digit values are ignored; existing reset phrase wins
        self.assertEqual(c5.enrich_quota_blob("retry-after: 5"), "retry-after: 5")
        self.assertEqual(c5.enrich_quota_blob("resets in 5m, retry-after: 120"),
                         "resets in 5m, retry-after: 120")

    def test_iso_reset_converted_relative_to_now(self):
        out = c5.enrich_quota_blob('{"reset_at":"2030-01-01T13:00:00Z"}')
        self.assertTrue(out.endswith("\nResets in 3600s"))
        out = c5.enrich_quota_blob("resets_at=2030-01-01T12:30Z")
        self.assertTrue(out.endswith("\nResets in 1800s"))
        out = c5.enrich_quota_blob("wake_at: 2030-01-01T12:00:10.5")
        self.assertTrue(out.endswith("\nResets in 10s"))

    def test_iso_reset_in_the_past_clamps_to_zero(self):
        out = c5.enrich_quota_blob("reset_at: 2020-01-01T00:00:00Z")
        self.assertTrue(out.endswith("\nResets in 0s"))

    def test_unparseable_iso_and_existing_prefix_ignored(self):
        self.assertEqual(c5.enrich_quota_blob("reset_at: 2030-13-45T00:00:00Z"),
                         "reset_at: 2030-13-45T00:00:00Z")
        text = "resets in 1h reset_at: 2030-01-01T13:00:00Z"
        self.assertEqual(c5.enrich_quota_blob(text), text)


class ApplyTest(Base):
    def base(self, **kw):
        res = {"quota_class": "unknown", "reset_seconds": None, "should_schedule": False,
               "should_short_retry": True, "schedule_delay_seconds": None,
               "reset_within_5h": False}
        res.update(kw)
        return res

    def apply(self, res, blob="Claude 429 rate limit", **kw):
        return c5.apply_claude_five_hour(res, blob=blob, **kw)

    def test_passthrough_classes(self):
        for cls in ("weekly", "monthly", "five_hour", "billing"):
            res = self.base(quota_class=cls)
            self.assertIs(self.apply(res, host="claude"), res, cls)

    def test_weekly_or_monthly_hint_in_blob_blocks_upgrade(self):
        for blob in ("claude weekly usage limit 429", "claude 429 limit for monthly plan"):
            res = self.base()
            self.assertIs(self.apply(res, blob=blob), res)

    def test_non_claude_or_non_quota_not_upgraded(self):
        res = self.base()
        self.assertIs(self.apply(res, blob="429 rate limit", host="openai", model="gpt"), res)
        self.assertIs(self.apply(res, blob="claude says hello"), res)
        self.assertIs(self.apply(res, blob=None, host="claude"), res)

    def test_missing_quota_class_treated_as_unclassified(self):
        res = {"reset_seconds": None}
        out = self.apply(res)
        self.assertEqual(out["quota_class"], "five_hour")

    def test_upgrade_defaults_to_five_hours(self):
        res = self.base()
        out = self.apply(res)
        self.assertIsNot(out, res)
        self.assertEqual(res["quota_class"], "unknown")  # input untouched
        self.assertEqual(out["quota_class"], "five_hour")
        self.assertTrue(out["should_schedule"])
        self.assertFalse(out["should_short_retry"])
        self.assertEqual(out["schedule_delay_seconds"], 18000)
        self.assertFalse(out["reset_within_5h"])

    def test_upgrade_keeps_reset_seconds_and_5h_boundary(self):
        out = self.apply(self.base(reset_seconds=120))
        self.assertEqual((out["schedule_delay_seconds"], out["reset_within_5h"]), (120, True))
        out = self.apply(self.base(reset_seconds=18000))
        self.assertTrue(out["reset_within_5h"])
        out = self.apply(self.base(reset_seconds=18001))
        self.assertEqual((out["schedule_delay_seconds"], out["reset_within_5h"]), (18001, False))
        out = self.apply(self.base(reset_seconds=0))
        self.assertEqual((out["schedule_delay_seconds"], out["reset_within_5h"]), (0, True))

    def test_host_taken_from_environment(self):
        os.environ["PI_PROVIDER"] = "anthropic"
        self.assertEqual(self.apply(self.base(), blob="rate limit")["quota_class"], "five_hour")


class ClassifyTest(Base):

    def test_generic_claude_429_becomes_five_hour(self):
        out = c5.classify_quota_window("Error 429 rate limit", host="claude")
        self.assertEqual(out["quota_class"], "five_hour")
        self.assertTrue(out["should_schedule"])
        self.assertEqual(out["schedule_delay_seconds"], 18000)

    def test_retry_after_sets_delay(self):
        out = c5.classify_quota_window("anthropic 429 retry-after: 90")
        self.assertEqual(out["quota_class"], "five_hour")
        self.assertEqual(out["schedule_delay_seconds"], 90)

    def test_weekly_stays_weekly_without_wake(self):
        out = c5.classify_quota_window("claude weekly usage limit reached", host="claude")
        self.assertEqual(out["quota_class"], "weekly")
        self.assertFalse(out["should_schedule"])

    def test_non_claude_unchanged_and_now_ignored(self):
        out = c5.classify_quota_window("429 rate limit", host="openai", now=NOW)
        self.assertEqual(out["quota_class"], "unknown")
        self.assertFalse(out["should_schedule"])

    def test_not_quota(self):
        self.assertEqual(c5.classify_quota_window("claude is fine")["quota_class"], "not_quota")


class AttachWakeFieldsTest(Base):
    def result(self, **job_kw):
        job = {"id": "run-1::r::m", "quota_class": "five_hour", "fire_at": "2030-01-01T17:00:00Z"}
        job.update(job_kw)
        return {"quota_class": "five_hour", "should_schedule": True, "scheduled": True, "job": job}

    def test_no_job_returns_unchanged(self):
        for res in ({"job": None}, {"job": "x"}, {}):
            before = dict(res)
            self.assertEqual(c5._attach_wake_fields(res, run_dir=None, now=NOW), before)

    def test_fills_wake_reset_and_host_defaults(self):
        res = self.result(reset_seconds=3600)
        out = c5._attach_wake_fields(res, run_dir=None, now=NOW, host="claude")
        job = out["job"]
        self.assertEqual(job["wake_at"], "2030-01-01T17:00:00Z")
        self.assertEqual(job["reset_at"], "2030-01-01T13:00:00Z")
        self.assertEqual(job["host"], "claude")
        self.assertEqual((out["wake_at"], out["reset_at"]),
                         ("2030-01-01T17:00:00Z", "2030-01-01T13:00:00Z"))

    def test_existing_fields_not_overwritten_and_no_host_when_blank(self):
        res = self.result(wake_at="W", reset_at="R", host="keep")
        out = c5._attach_wake_fields(res, run_dir=None, now=NOW, host="other")
        self.assertEqual((out["wake_at"], out["reset_at"], out["job"]["host"]), ("W", "R", "keep"))
        res = self.result()
        out = c5._attach_wake_fields(res, run_dir=None, now=NOW)
        self.assertNotIn("host", out["job"])

    def test_missing_fire_at_and_reset_seconds_fall_back_to_now(self):
        res = self.result()
        del res["job"]["fire_at"]
        out = c5._attach_wake_fields(res, run_dir=None, now=None)  # utcnow patched to NOW
        self.assertEqual(out["wake_at"], "2030-01-01T12:00:00Z")
        self.assertEqual(out["reset_at"], "2030-01-01T12:00:00Z")

    def test_wake_override_arms_timer_and_persists(self):
        os.environ["SB_RFL_QUOTA_WAKE_AT"] = " 2030-01-01T14:00:00Z "
        res = self.result()
        out = c5._attach_wake_fields(res, run_dir=self.run_dir, now=NOW)
        job = out["job"]
        for field in ("fire_at", "wake_at", "reset_at"):
            self.assertEqual(job[field], "2030-01-01T14:00:00Z")
        self.assertEqual(job["schedule_delay_seconds"], 7200)
        self.assertEqual(out["schedule_delay_seconds"], 7200)
        self.assertEqual(out["timer"], {"armed": True, "mechanism": "fake"})
        self.assertTrue(out["armed"])
        self.assertEqual(job["timer"], out["timer"])
        self.assertEqual(self.timers, [("run-1::r::m", str(self.run_dir), NOW)])
        stored = json.loads((self.run_dir / "quota-retry-schedule.json").read_text())
        self.assertEqual(stored["jobs"][0]["wake_at"], "2030-01-01T14:00:00Z")
        self.assertEqual(stored["updated_at"], "2030-01-01T12:00:00Z")

    def test_wake_override_without_run_dir_skips_timer_and_store(self):
        os.environ["SB_RFL_QUOTA_WAKE_AT"] = "2030-01-01T11:00:00Z"  # in the past
        out = c5._attach_wake_fields(self.result(), run_dir=None, now=NOW)
        self.assertEqual(out["schedule_delay_seconds"], 0)
        self.assertNotIn("timer", out)
        self.assertEqual(self.timers, [])

    def test_wake_override_conditions(self):
        os.environ["SB_RFL_QUOTA_WAKE_AT"] = "2030-01-01T14:00:00Z"
        unchanged = "2030-01-01T17:00:00Z"
        cases = {
            "weekly result": lambda r: r.update(quota_class="weekly"),
            "not scheduled": lambda r: r.update(should_schedule=False),
            "job not five_hour": lambda r: r["job"].update(quota_class="weekly"),
        }
        for name, mutate in cases.items():
            res = self.result()
            mutate(res)
            out = c5._attach_wake_fields(res, run_dir=None, now=NOW)
            self.assertEqual(out["job"]["fire_at"], unchanged, name)
        # job without quota_class falls back to the result's class
        res = self.result()
        del res["job"]["quota_class"]
        out = c5._attach_wake_fields(res, run_dir=None, now=NOW)
        self.assertEqual(out["job"]["fire_at"], "2030-01-01T14:00:00Z")

    def test_invalid_or_blank_wake_env_ignored(self):
        for raw in ("not-a-date", "   ", ""):
            os.environ["SB_RFL_QUOTA_WAKE_AT"] = raw
            out = c5._attach_wake_fields(self.result(), run_dir=None, now=NOW)
            self.assertEqual(out["job"]["fire_at"], "2030-01-01T17:00:00Z")

    def test_store_updates_existing_job_in_place_or_appends(self):
        sched = self.run_dir / "quota-retry-schedule.json"
        sched.write_text(json.dumps({"jobs": [{"id": "other"}, {"id": "run-1::r::m", "old": 1}]}))
        res = self.result()
        c5._attach_wake_fields(res, run_dir=self.run_dir, now=NOW)
        jobs = json.loads(sched.read_text())["jobs"]
        self.assertEqual([j["id"] for j in jobs], ["other", "run-1::r::m"])
        self.assertNotIn("old", jobs[1])
        self.assertEqual(jobs[1]["wake_at"], "2030-01-01T17:00:00Z")
        sched.write_text(json.dumps({"jobs": [{"id": "other"}]}))
        c5._attach_wake_fields(self.result(), run_dir=self.run_dir, now=NOW)
        self.assertEqual([j["id"] for j in json.loads(sched.read_text())["jobs"]],
                         ["other", "run-1::r::m"])

    def test_store_not_written_when_not_scheduled(self):
        res = self.result()
        res["scheduled"] = False
        c5._attach_wake_fields(res, run_dir=self.run_dir, now=NOW)
        self.assertFalse((self.run_dir / "quota-retry-schedule.json").exists())


class ScheduleTest(Base):
    def setUp(self):
        super().setUp()
        # The CLI calls install(); the core scheduler then classifies via the Claude wrapper.
        patcher = mock.patch.object(qr, "classify_quota_window", c5.classify_quota_window)
        patcher.start()
        self.addCleanup(patcher.stop)

    def schedule(self, **kw):
        args = dict(run_dir=self.run_dir, run_id="run-1", rung="r1", model="claude-x",
                    output="Claude 429 rate limit", now=NOW)
        args.update(kw)
        return c5.schedule_quota_retry(**args)

    def sched_file(self):
        return json.loads((self.run_dir / "quota-retry-schedule.json").read_text())

    def test_claude_generic_429_schedules_five_hours(self):
        out = self.schedule()
        self.assertTrue(out["scheduled"])
        self.assertEqual(out["job"]["fire_at"], "2030-01-01T17:00:00Z")
        self.assertEqual(out["wake_at"], "2030-01-01T17:00:00Z")
        self.assertEqual(out["reset_at"], "2030-01-01T17:00:00Z")
        self.assertNotIn("host", out["job"])
        stored = self.sched_file()["jobs"][0]
        self.assertEqual(stored["wake_at"], "2030-01-01T17:00:00Z")

    def test_retry_after_and_host_param(self):
        out = self.schedule(output="429 rate limit retry-after: 600", model="opus", host="claude")
        self.assertEqual(out["job"]["fire_at"], "2030-01-01T12:10:00Z")
        self.assertEqual(out["job"]["host"], "claude")
        self.assertEqual(out["reset_at"], "2030-01-01T12:10:00Z")

    def test_explicit_wake_at_overrides_and_is_exported(self):
        wake = NOW + timedelta(hours=1)
        out = self.schedule(wake_at=wake)
        self.assertEqual(os.environ["SB_RFL_QUOTA_WAKE_AT"], "2030-01-01T13:00:00Z")
        self.assertEqual(out["job"]["fire_at"], "2030-01-01T13:00:00Z")
        self.assertEqual(out["schedule_delay_seconds"], 3600)
        self.assertTrue(out["armed"])

    def test_weekly_not_scheduled(self):
        out = self.schedule(output="claude weekly usage limit reached")
        self.assertFalse(out["scheduled"])
        self.assertIsNone(out["job"])
        self.assertFalse((self.run_dir / "quota-retry-schedule.json").exists())

    def test_second_call_is_deduped(self):
        first = self.schedule()
        second = self.schedule()
        self.assertTrue(second["deduped"])
        self.assertEqual(second["job"]["id"], first["job"]["id"])
        self.assertEqual(len(self.sched_file()["jobs"]), 1)

    def test_host_and_model_from_environment(self):
        os.environ.update({"SB_RFL_QUOTA_HOST": "anthropic", "SB_RFL_MODEL": "envmodel"})
        out = self.schedule(model="")
        self.assertEqual(out["job"]["model"], "envmodel")
        self.assertEqual(out["job"]["host"], "anthropic")


class InstallAndBindTest(Base):

    def test_install_patches_core_module_functions(self):
        with mock.patch.object(qr, "classify_quota_window", qr.classify_quota_window), \
             mock.patch.object(qr, "schedule_quota_retry", qr.schedule_quota_retry):
            c5.install()
            self.assertIs(qr.classify_quota_window, c5.classify_quota_window)
            self.assertIs(qr.schedule_quota_retry, c5.schedule_quota_retry)
            self.assertEqual(qr.classify_quota_window("claude 429 rate limit")["quota_class"],
                             "five_hour")
        self.assertIsNot(qr.classify_quota_window, c5.classify_quota_window)

    def test_bind_cli_env_empty_args_change_nothing(self):
        before = dict(os.environ)
        c5.bind_cli_env()
        self.assertEqual(dict(os.environ), before)

    def test_bind_cli_env_sets_values(self):
        c5.bind_cli_env(host="claude", model="opus", wake_at="2030-01-01T13:00:00Z")
        self.assertEqual(os.environ["SB_RFL_QUOTA_HOST"], "claude")
        self.assertEqual(os.environ["SB_RFL_MODEL"], "opus")
        self.assertEqual(os.environ["PI_MODEL"], "opus")
        self.assertEqual(os.environ["SB_RFL_QUOTA_WAKE_AT"], "2030-01-01T13:00:00Z")

    def test_bind_cli_env_keeps_existing_model(self):
        os.environ.update({"SB_RFL_MODEL": "keep", "PI_MODEL": "keep-pi"})
        c5.bind_cli_env(model="new")
        self.assertEqual((os.environ["SB_RFL_MODEL"], os.environ["PI_MODEL"]), ("keep", "keep-pi"))

    def test_bind_cli_env_treats_empty_model_vars_as_unset(self):
        os.environ.update({"SB_RFL_MODEL": "", "PI_MODEL": ""})
        c5.bind_cli_env(model="new")
        self.assertEqual((os.environ["SB_RFL_MODEL"], os.environ["PI_MODEL"]), ("new", "new"))


if __name__ == "__main__":
    unittest.main()
