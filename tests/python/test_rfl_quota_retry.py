"""Unit tests for scripts/lib/rfl_quota_retry.py (frozen clock, mocked timers/notifications)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

q = load_module("scripts/lib/rfl_quota_retry.py", name="rfl_quota_retry_under_test")

NOW = datetime(2030, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
ENV_KEYS = (
    "SB_RFL_TIMER_MODE", "SB_RFL_AT_BIN", "SB_RFL_LAUNCHD_DIR", "SB_RFL_LAUNCHCTL",
    "SB_RFL_PROJECT_ROOT", "SB_RFL_NOTIFY",
)


class Base(unittest.TestCase):
    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k not in ENV_KEYS}
        p = mock.patch.dict(os.environ, env, clear=True)
        p.start()
        self.addCleanup(p.stop)
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.tmp = Path(d.name).resolve()
        self.run_dir = self.tmp / ".planning" / "rfl-demo"
        self.run_dir.mkdir(parents=True)

    def store(self):
        return json.loads((self.run_dir / q.SCHEDULE_FILENAME).read_text())

    def put_store(self, jobs, **extra):
        (self.run_dir / q.SCHEDULE_FILENAME).write_text(json.dumps({"version": 1, "jobs": jobs, **extra}))


def job(**over):
    base = {
        "id": "rfl-demo::r1::gpt", "run_id": "rfl-demo", "rung": "r1", "model": "gpt",
        "status": "scheduled", "fire_at": "2030-01-01T11:00:00Z",
    }
    base.update(over)
    return base


class TimeHelpersTest(unittest.TestCase):
    def test_utcnow_is_aware_utc(self):
        class Fake(datetime):
            @classmethod
            def now(cls, tz=None):
                return cls(2031, 2, 3, 4, 5, 6, tzinfo=tz)

        with mock.patch.object(q, "datetime", Fake):
            self.assertEqual(q.utcnow(), datetime(2031, 2, 3, 4, 5, 6, tzinfo=timezone.utc))

    def test_parse_iso_datetime(self):
        self.assertIsNone(q.parse_iso_datetime(None))
        self.assertIsNone(q.parse_iso_datetime("  "))
        self.assertIsNone(q.parse_iso_datetime("not a date"))
        self.assertEqual(q.parse_iso_datetime("2030-01-01T00:00:00Z"), datetime(2030, 1, 1, tzinfo=timezone.utc))
        self.assertEqual(q.parse_iso_datetime("2030-01-01T00:00:00"), datetime(2030, 1, 1, tzinfo=timezone.utc))
        self.assertEqual(q.parse_iso_datetime("2030-01-01T02:00:00+02:00"), datetime(2030, 1, 1, tzinfo=timezone.utc))

    def test_isoformat_z(self):
        moment = datetime(2030, 1, 1, 2, 0, 0, tzinfo=timezone(timedelta(hours=2)))
        self.assertEqual(q.isoformat_z(moment), "2030-01-01T00:00:00Z")


class ParseResetTest(unittest.TestCase):
    def test_cases(self):
        cases = [
            (None, None),
            ("", None),
            ("no reset info", None),
            ("Resets in nothing useful", None),
            ("Resets in 3hr 6min", 3 * 3600 + 6 * 60),
            ("reset after 59m 36s", 59 * 60 + 36),
            ("resets after 1.5 hours", 5400),
            ("Resets in 2 hours. Later 9h", 7200),
            ("resets in 10 secs\nnext 5h", 10),
            ("resets in 4m; then 9h", 240),
            ("resets in 7 min [stderr] 3h", 420),
            ("quota hit. Resets in 1h", 3600),
        ]
        for blob, expected in cases:
            with self.subTest(blob=blob):
                self.assertEqual(q.parse_reset_seconds(blob), expected)


class ClassifyTest(unittest.TestCase):
    def check(self, blob, cls, schedule, delay, short=False):
        out = q.classify_quota_window(blob)
        self.assertEqual(
            (out["quota_class"], out["should_schedule"], out["schedule_delay_seconds"], out["should_short_retry"]),
            (cls, schedule, delay, short),
            blob,
        )
        return out

    def test_classes(self):
        self.check("You hit your 5-hour usage limit. Resets in 2hr", "five_hour", True, 7200)
        self.check("five hour quota exceeded", "five_hour", True, 5 * 3600)
        self.check("limit reached for the 5 hour window", "five_hour", True, 5 * 3600)
        self.check("HTTP 401 unauthorized", "billing", False, None)
        self.check("insufficient_balance", "billing", False, None)
        self.check("invalid api key given", "billing", False, None)
        self.check("weekly limit reached. Resets in 2h", "weekly", True, 7200)
        self.check("weekly limit reached. Resets in 30h", "weekly", False, None)
        self.check("weekly limit reached", "weekly", False, None)
        self.check("limit of the week: weekly", "weekly", False, None)
        self.check("monthly quota. resets in 1h", "monthly", True, 3600)
        self.check("monthly cap reached", "monthly", False, None)
        self.check("429 too many requests", "unknown", False, None, short=True)
        self.check("rate limit. resets in 4m", "unknown", True, 240, short=True)
        self.check("rate limit. resets in 1h", "unknown", True, 3600, short=False)
        self.check("rate limit. resets in 9h", "unknown", False, None, short=False)
        self.check("all fine", "not_quota", False, None)
        self.check(None, "not_quota", False, None)

    def test_payload_shape(self):
        out = q.classify_quota_window("rate limit. resets in 1h")
        self.assertEqual(out["reset_seconds"], 3600)
        self.assertIs(out["reset_within_5h"], True)
        self.assertIs(out["same_named_model"], True)
        self.assertIsNone(out["substitute_model"])
        self.assertIs(q.classify_quota_window("weekly limit. resets in 30h")["reset_within_5h"], False)

    def test_job_key(self):
        self.assertEqual(q.job_key(run_id="a", rung="b", model="c"), "a::b::c")


class ReadWriteTest(Base):
    def test_paths(self):
        self.assertEqual(q.schedule_path(self.run_dir), self.run_dir / "quota-retry-schedule.json")
        self.assertEqual(q.ladder_status_path(str(self.run_dir)), self.run_dir / "LADDER-STATUS.json")

    def test_read_json_variants(self):
        p = self.run_dir / "x.json"
        self.assertEqual(q._read_json(p), {})
        p.write_text("{bad")
        self.assertEqual(q._read_json(p), {})
        p.write_text("[1]")
        self.assertEqual(q._read_json(p), {})
        p.write_text('{"a": 1}')
        self.assertEqual(q._read_json(p), {"a": 1})
        d = self.run_dir / "dir.json"
        d.mkdir()
        self.assertEqual(q._read_json(d), {})
        with mock.patch.object(Path, "read_text", side_effect=OSError("io")):
            self.assertEqual(q._read_json(p), {})

    def test_write_json_creates_parent(self):
        p = self.tmp / "a" / "b" / "x.json"
        q._write_json(p, {"k": [1]})
        self.assertEqual(p.read_text(), '{\n  "k": [\n    1\n  ]\n}\n')

    def test_load_schedule_defaults(self):
        self.assertEqual(q.load_schedule(self.run_dir), {"jobs": [], "version": 1})
        (self.run_dir / q.SCHEDULE_FILENAME).write_text('{"jobs": "bad", "version": 7, "x": 1}')
        self.assertEqual(q.load_schedule(self.run_dir), {"jobs": [], "version": 7, "x": 1})
        self.put_store([job()])
        self.assertEqual(len(q.load_schedule(self.run_dir)["jobs"]), 1)


class LadderStatusTest(Base):
    def test_mark_active_records_fields(self):
        out = q.mark_ladder_status(
            self.run_dir, " Active ", reason="why", now=NOW, current_rung=" r2 ", current_phase=" p ", policy_d_written=False
        )
        self.assertEqual(out["ok"], True)
        self.assertEqual(out["path"], str(self.run_dir / "LADDER-STATUS.json"))
        on_disk = json.loads((self.run_dir / "LADDER-STATUS.json").read_text())
        self.assertEqual(on_disk, {
            "status": "active", "updated_at": "2030-01-01T12:00:00Z", "reason": "why",
            "policy_d_written": False, "current_rung": "r2", "current_phase": "p",
        })

    def test_mark_uses_clock_and_keeps_prior_fields(self):
        (self.run_dir / "LADDER-STATUS.json").write_text('{"keep": 1, "reason": "old"}')
        with mock.patch.object(q, "utcnow", return_value=NOW):
            q.mark_ladder_status(self.run_dir, "aborted")
        on_disk = json.loads((self.run_dir / "LADDER-STATUS.json").read_text())
        self.assertEqual(on_disk, {"keep": 1, "reason": "old", "status": "aborted", "updated_at": "2030-01-01T12:00:00Z"})

    def test_mark_rejects_unknown_status(self):
        for bad in ("bogus", "", None):
            with self.assertRaisesRegex(ValueError, "unsupported ladder status"):
                q.mark_ladder_status(self.run_dir, bad, now=NOW)
        self.assertFalse((self.run_dir / "LADDER-STATUS.json").exists())

    def test_completed_requires_policy_c_gate(self):
        import rfl_policy_c

        with mock.patch.object(rfl_policy_c, "assert_run_ready_for_complete", return_value={"ok": False, "errors": ["a", "b"]}):
            with self.assertRaisesRegex(ValueError, "cannot mark ladder completed: a; b"):
                q.mark_ladder_status(self.run_dir, "completed", now=NOW)
        with mock.patch.object(rfl_policy_c, "assert_run_ready_for_complete", return_value={"ok": False}):
            with self.assertRaisesRegex(ValueError, "cannot mark ladder completed: Policy C missing"):
                q.mark_ladder_status(self.run_dir, "done", now=NOW)
        self.assertFalse((self.run_dir / "LADDER-STATUS.json").exists())

    def test_completed_when_gate_passes_defaults_policy_d_written(self):
        import rfl_policy_c

        with mock.patch.object(rfl_policy_c, "assert_run_ready_for_complete", return_value={"ok": True}) as gate:
            out = q.mark_ladder_status(self.run_dir, "policy_d", now=NOW)
        gate.assert_called_once_with(self.run_dir)
        self.assertEqual((out["status"], out["policy_d_written"]), ("policy_d", True))
        with mock.patch.object(rfl_policy_c, "assert_run_ready_for_complete", return_value={"ok": True}):
            out = q.mark_ladder_status(self.run_dir, "finished", now=NOW, policy_d_written=False)
        self.assertIs(out["policy_d_written"], False)

    def test_detect(self):
        d = q.detect_ladder_status(self.run_dir)
        self.assertEqual((d["status"], d["over"], d["policy_d_written"], d["artifacts"]), ("active", False, False, []))
        self.assertEqual(d["path"], str(self.run_dir / "LADDER-STATUS.json"))
        (self.run_dir / "POLICY-D.md").write_text("x")
        (self.run_dir / "LADDER-COMPLETE.md").write_text("x")
        d = q.detect_ladder_status(self.run_dir)
        self.assertEqual((d["status"], d["over"], d["artifacts"]), ("completed", True, ["LADDER-COMPLETE.md", "POLICY-D.md"]))

    def test_detect_from_status_file(self):
        status = self.run_dir / "LADDER-STATUS.json"
        status.write_text('{"policy_d_written": true}')
        d = q.detect_ladder_status(self.run_dir)
        self.assertEqual((d["status"], d["over"], d["policy_d_written"]), ("completed", True, True))
        status.write_text('{"status": " Aborted "}')
        self.assertEqual((q.detect_ladder_status(self.run_dir)["status"], q.detect_ladder_status(self.run_dir)["over"]), ("aborted", True))
        status.write_text('{"status": "active"}')
        self.assertIs(q.detect_ladder_status(self.run_dir)["over"], False)
        status.write_text('{"status": "active", "policy_d_written": true}')
        self.assertIs(q.detect_ladder_status(self.run_dir)["over"], True)
        status.write_text('{"status": null}')
        self.assertEqual(q.detect_ladder_status(self.run_dir)["status"], "active")


class ScheduleTest(Base):
    def setUp(self):
        super().setUp()
        os.environ["SB_RFL_TIMER_MODE"] = "mock"

    def schedule(self, output="5-hour usage limit. Resets in 2hr", **kw):
        return q.schedule_quota_retry(
            run_dir=self.run_dir, run_id="rfl-demo", rung="r1", model="gpt", output=output, now=NOW, **kw
        )

    def test_not_quota_schedules_nothing(self):
        out = self.schedule("plain failure")
        self.assertEqual(out, {
            "ok": True, "deduped": False, "scheduled": False, "path": str(self.run_dir / q.SCHEDULE_FILENAME),
            "job": None, **q.classify_quota_window("plain failure"),
        })
        self.assertFalse((self.run_dir / q.SCHEDULE_FILENAME).exists())

    def test_new_job_is_persisted_and_armed(self):
        out = self.schedule()
        j = out["job"]
        timer = j["timer"]
        self.assertEqual(out, {
            "ok": True, "deduped": False, "scheduled": True, "armed": True, "timer": timer,
            "path": str(self.run_dir / q.SCHEDULE_FILENAME), "job": j,
            **q.classify_quota_window("5-hour usage limit. Resets in 2hr"),
        })
        self.assertEqual(j, {
            "id": "rfl-demo::r1::gpt", "run_id": "rfl-demo", "run_dir": str(self.run_dir), "rung": "r1", "model": "gpt",
            "quota_class": "five_hour", "reset_seconds": 7200, "schedule_delay_seconds": 7200,
            "fire_at": "2030-01-01T14:00:00Z", "created_at": "2030-01-01T12:00:00Z", "status": "scheduled",
            "same_named_model": True, "substitute_model": None, "timer": timer,
        })
        self.assertEqual((timer["armed"], timer["backend"], timer["fire_at"]), (True, "mock", "2030-01-01T14:00:00Z"))
        self.assertEqual(j["id"], "rfl-demo::r1::gpt")
        self.assertEqual(j["fire_at"], "2030-01-01T14:00:00Z")
        self.assertEqual(j["schedule_delay_seconds"], 7200)
        self.assertEqual(j["status"], "scheduled")
        self.assertEqual(j["timer"]["backend"], "mock")
        s = self.store()
        self.assertEqual((s["run_id"], s["run_dir"], s["updated_at"]), ("rfl-demo", str(self.run_dir), "2030-01-01T12:00:00Z"))
        self.assertEqual(s["jobs"], [j])
        self.assertEqual(out["quota_class"], "five_hour")

    def test_delay_defaults_to_five_hours(self):
        out = self.schedule("five-hour limit reached")
        self.assertEqual(out["job"]["schedule_delay_seconds"], 5 * 3600)
        self.assertEqual(out["job"]["fire_at"], "2030-01-01T17:00:00Z")

    def test_existing_run_id_in_store_wins(self):
        self.put_store([], run_id="original")
        self.schedule()
        self.assertEqual(self.store()["run_id"], "original")

    def test_duplicate_is_deduped_without_rewrite(self):
        self.schedule()
        before = (self.run_dir / q.SCHEDULE_FILENAME).read_bytes()
        out = self.schedule()
        stored_job = self.store()["jobs"][0]
        self.assertEqual(out, {
            "ok": True, "deduped": True, "scheduled": True, "armed": True, "timer": stored_job["timer"],
            "path": str(self.run_dir / q.SCHEDULE_FILENAME), "job": stored_job,
            **q.classify_quota_window("5-hour usage limit. Resets in 2hr"),
        })
        self.assertEqual((self.run_dir / q.SCHEDULE_FILENAME).read_bytes(), before)
        self.assertEqual(len(self.store()["jobs"]), 1)

    def test_duplicate_unarmed_scheduled_job_is_rearmed(self):
        self.put_store([job(timer={"armed": False})])
        out = self.schedule()
        self.assertEqual((out["deduped"], out["armed"]), (True, True))
        s = self.store()
        self.assertEqual(s["jobs"][0]["timer"]["backend"], "mock")
        self.assertEqual(s["updated_at"], "2030-01-01T12:00:00Z")

    def test_duplicate_with_non_dict_timer_is_rearmed(self):
        self.put_store([job(timer="garbage")])
        out = self.schedule()
        self.assertIs(out["armed"], True)

    def test_duplicate_of_finished_job_reports_not_scheduled(self):
        self.put_store([job(status="executed")])
        out = self.schedule()
        self.assertEqual(out, {
            "ok": True, "deduped": True, "scheduled": False, "armed": False, "timer": None,
            "path": str(self.run_dir / q.SCHEDULE_FILENAME), "job": job(status="executed"),
            **q.classify_quota_window("5-hour usage limit. Resets in 2hr"),
        })
        self.assertEqual(self.store()["jobs"][0].get("timer"), None)


class ActivateAndDueTest(Base):
    def activate(self, **kw):
        args = dict(run_dir=self.run_dir, run_id="rfl-demo", rung="r1", model="gpt", now=NOW)
        args.update(kw)
        return q.activate_quota_retry(**args)

    def test_is_due(self):
        self.assertTrue(q._job_due({"fire_at": "2030-01-01T12:00:00Z"}, NOW))
        self.assertFalse(q._job_due({"fire_at": "2030-01-01T12:00:01Z"}, NOW))
        self.assertTrue(q._job_due({}, NOW))
        self.assertTrue(q._job_due({"fire_at": "garbage"}, NOW))

    def test_ask_user_prompt(self):
        text = q.ask_user_prompt(run_id="R", rung="r", model="m", ladder_status="aborted")
        self.assertIn("`R` has already finished (status: aborted)", text)
        self.assertIn("rung `r` on model `m`", text)
        self.assertTrue(text.endswith("Do not execute until the user confirms."))

    def test_missing_job(self):
        out = self.activate()
        self.assertEqual(out, {"ok": False, "action": "missing", "execute": False, "ask": None, "error": "no schedule for rfl-demo::r1::gpt"})

    def test_alternate_run_id_lookup(self):
        self.put_store([job(id="stored::r1::gpt", run_id="stored")], run_id="stored")
        out = self.activate(run_id="something-else")
        self.assertEqual(out["action"], "retry_rung")
        self.assertEqual(out["job"]["id"], "stored::r1::gpt")

    def test_alternate_lookup_also_misses(self):
        self.put_store([job()], run_id="zzz")
        out = self.activate(run_id="other")
        self.assertEqual(out["action"], "missing")

    def test_run_id_defaults_from_store_then_dir_name(self):
        self.put_store([job(id="stored::r1::gpt", run_id="stored")], run_id="stored")
        self.assertEqual(self.activate(run_id=None)["action"], "retry_rung")
        (self.run_dir / q.SCHEDULE_FILENAME).unlink()
        self.put_store([job()])
        self.assertEqual(self.activate(run_id=None)["action"], "retry_rung")

    def test_already_consumed(self):
        self.put_store([job(status="executed")])
        out = self.activate()
        self.assertEqual(out, {"ok": True, "action": "already_consumed", "execute": False, "ask": None, "job": job(status="executed")})

    def test_not_due(self):
        self.put_store([job(fire_at="2030-01-01T13:00:00Z")])
        out = self.activate()
        self.assertEqual(out, {"ok": True, "action": "not_due", "execute": False, "ask": None, "job": job(fire_at="2030-01-01T13:00:00Z")})
        self.assertEqual(self.store()["jobs"][0]["status"], "scheduled")
        self.assertFalse((self.run_dir / q.EXECUTE_FILENAME).exists())

    def test_retry_rung_when_ladder_active(self):
        self.put_store([job()])
        out = self.activate()
        self.assertEqual(out, {
            "ok": True, "action": "retry_rung", "execute": True, "ask": None,
            "artifact": str(self.run_dir / q.EXECUTE_FILENAME), "rung": "r1", "model": "gpt",
            "same_named_model": True, "substitute_model": None, "ladder_status": "active",
            "job": job(status="executed", executed_at="2030-01-01T12:00:00Z"),
        })
        stored = self.store()["jobs"][0]
        self.assertEqual((stored["status"], stored["executed_at"]), ("executed", "2030-01-01T12:00:00Z"))
        body = (self.run_dir / q.EXECUTE_FILENAME).read_text()
        self.assertIn("- Run: `rfl-demo`", body)
        self.assertIn("same named model; do not substitute Grok", body)
        self.assertEqual(self.activate()["action"], "already_consumed")

    def test_asked_job_not_due_check_only_applies_to_scheduled(self):
        self.put_store([job(status="asked", fire_at="2030-01-01T13:00:00Z")])
        self.assertEqual(self.activate()["action"], "retry_rung")

    def test_ask_user_when_ladder_over(self):
        self.put_store([job()])
        (self.run_dir / "LADDER-STATUS.json").write_text('{"status": "completed"}')
        out = self.activate()
        expected_ask = q.ask_user_prompt(run_id="rfl-demo", rung="r1", model="gpt", ladder_status="completed")
        self.assertEqual(out, {
            "ok": True, "action": "ask_user", "execute": False, "ask": expected_ask,
            "artifact": str(self.run_dir / q.ASK_FILENAME), "ladder_status": "completed",
            "job": job(status="asked", asked_at="2030-01-01T12:00:00Z", ask=expected_ask),
        })
        self.assertIn("`rfl-demo` has already finished (status: completed)", out["ask"])
        stored = self.store()["jobs"][0]
        self.assertEqual((stored["status"], stored["asked_at"], stored["ask"]), ("asked", "2030-01-01T12:00:00Z", out["ask"]))
        self.assertIn("Do **not** execute this rung until the user answers yes.", (self.run_dir / q.ASK_FILENAME).read_text())

    def test_ask_user_falls_back_to_call_arguments_for_sparse_jobs(self):
        self.put_store([{"id": "rfl-demo::r1::gpt", "status": "asked"}])
        (self.run_dir / "POLICY-D.md").write_text("x")
        out = self.activate()
        self.assertIn("`rfl-demo` has already finished", out["ask"])
        self.assertIn("rung `r1` on model `gpt`", out["ask"])

    def test_due_quota_retries(self):
        self.put_store([
            job(id="a"), job(id="b", status="asked"), job(id="c", status="executed"),
            job(id="d", fire_at="2030-01-01T13:00:00Z"), job(id="e", fire_at=None),
        ])
        out = q.due_quota_retries(self.run_dir, now=NOW)
        self.assertEqual([j["id"] for j in out["due"]], ["a", "b", "e"])
        self.assertEqual((out["ok"], out["count"], out["path"]), (True, 3, str(self.run_dir / q.SCHEDULE_FILENAME)))
        with mock.patch.object(q, "utcnow", return_value=NOW):
            self.assertEqual(q.due_quota_retries(self.run_dir)["count"], 3)


class PathsAndWakeTest(Base):
    def test_infer_project_root(self):
        self.assertEqual(q.infer_project_root(self.run_dir), self.tmp)
        other = self.tmp / "elsewhere" / "run"
        other.mkdir(parents=True)
        os.environ["SB_RFL_PROJECT_ROOT"] = "/env/root"
        self.assertEqual(q.infer_project_root(other), Path("/env/root"))
        os.environ["SB_RFL_PROJECT_ROOT"] = "  "
        with mock.patch.object(Path, "cwd", return_value=Path("/cwd")):
            self.assertEqual(q.infer_project_root(other), Path("/cwd"))
        del os.environ["SB_RFL_PROJECT_ROOT"]
        with mock.patch.object(Path, "cwd", return_value=Path("/cwd")):
            self.assertEqual(q.infer_project_root(other), Path("/cwd"))

    def test_resolver_and_wake_argv(self):
        self.assertEqual(q.resolver_path(), REPO_ROOT / "scripts" / "review-fix-ladder.py")
        argv = q.wake_argv(project_root=self.tmp, run_dir=self.run_dir)
        self.assertEqual(argv, [sys.executable, str(REPO_ROOT / "scripts" / "review-fix-ladder.py"),
                                "--quota-retry-wake", "--project-root", str(self.tmp), "--run-dir", str(self.run_dir)])

    def test_xml_escape_and_at_timestamp(self):
        self.assertEqual(q._xml_escape('a&b<c>"d'), "a&amp;b&lt;c&gt;&quot;d")
        with mock.patch.dict(os.environ, {"TZ": "UTC"}):
            if hasattr(__import__("time"), "tzset"):
                __import__("time").tzset()
            self.assertEqual(q._at_timestamp(datetime(2030, 1, 2, 3, 4, 59, tzinfo=timezone.utc)), "203001020304")


class TimerTest(Base):
    def arm(self, **jobkw):
        j = job(**jobkw)
        return q.arm_quota_retry_timer(job=j, run_dir=self.run_dir, now=NOW)

    def test_mock_backend_and_command_line(self):
        os.environ["SB_RFL_TIMER_MODE"] = " MOCK "
        t = self.arm()
        self.assertEqual((t["armed"], t["backend"], t["fire_at"]), (True, "mock", "2030-01-01T11:00:00Z"))
        self.assertIn("--quota-retry-wake", t["command"])
        self.assertEqual(t["argv"][-1], str(self.run_dir))

    def test_existing_armed_timer_for_same_fire_time_is_reused(self):
        os.environ["SB_RFL_TIMER_MODE"] = "mock"
        existing = {"armed": True, "fire_at": "2030-01-01T11:00:00Z", "backend": "custom"}
        self.assertEqual(self.arm(timer=existing), existing)
        t = self.arm(timer={"armed": True, "fire_at": "other", "backend": "custom"})
        self.assertEqual(t["backend"], "mock")
        t = self.arm(timer={"armed": False, "fire_at": "2030-01-01T11:00:00Z"})
        self.assertEqual(t["backend"], "mock")

    def test_invalid_fire_at_falls_back_to_now(self):
        os.environ["SB_RFL_TIMER_MODE"] = "mock"
        with mock.patch.object(q, "utcnow", return_value=NOW):
            t = self.arm(fire_at="garbage")
        self.assertEqual(t["fire_at"], "garbage")
        self.assertTrue(t["armed"])

    def test_at_backend_success(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        proc = subprocess.CompletedProcess([], 0, stdout="", stderr=" job 5 at Tue \n")
        with mock.patch.object(Path, "is_file", return_value=True), \
             mock.patch.object(q.subprocess, "run", return_value=proc) as run:
            t = self.arm()
        self.assertEqual((t["armed"], t["backend"], t["at_bin"], t["stderr"]), (True, "at", "/bin/at-stub", "job 5 at Tue"))
        args, kwargs = run.call_args
        fire_local = datetime(2030, 1, 1, 11, 0, tzinfo=timezone.utc).astimezone().strftime("%Y%m%d%H%M")
        self.assertEqual(args, (["/bin/at-stub", "-t", fire_local],))
        self.assertEqual(kwargs, {"input": t["command"] + "\n", "text": True, "capture_output": True, "check": False})
        self.assertIn(str(self.run_dir), t["command"])

    def test_at_backend_found_on_path(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "at"
        proc = subprocess.CompletedProcess([], 0, stdout="", stderr=None)
        with mock.patch.object(q.shutil, "which", return_value="/usr/bin/at"), \
             mock.patch.object(Path, "is_file", return_value=False), \
             mock.patch.object(q.subprocess, "run", return_value=proc):
            t = self.arm()
        self.assertEqual((t["backend"], t["stderr"]), ("at", ""))

    def test_at_missing_binary_reports_no_backend(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "definitely-not-installed-at"
        with mock.patch.object(q.shutil, "which", return_value=None), \
             mock.patch.object(q.subprocess, "run") as run, \
             mock.patch.object(q.sys, "platform", "linux"):
            t = self.arm()
        run.assert_not_called()
        self.assertEqual((t["armed"], t["backend"], t["reason"]), (False, "unarmed", "no at/launchd backend available"))

    def test_at_failures_are_recorded(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        with mock.patch.object(Path, "is_file", return_value=True):
            proc = subprocess.CompletedProcess([], 1, stdout="out text", stderr="")
            with mock.patch.object(q.subprocess, "run", return_value=proc), mock.patch.object(q.sys, "platform", "linux"):
                t = self.arm()
            self.assertEqual((t["armed"], t["at_error"]), (False, "out text"))
            proc = subprocess.CompletedProcess([], 1, stdout="", stderr="bad time")
            with mock.patch.object(q.subprocess, "run", return_value=proc), mock.patch.object(q.sys, "platform", "linux"):
                self.assertEqual(self.arm()["at_error"], "bad time")
            with mock.patch.object(q.subprocess, "run", side_effect=OSError("exec failed")), mock.patch.object(q.sys, "platform", "linux"):
                t = self.arm()
            self.assertEqual((t["armed"], t["at_error"]), (False, "exec failed"))

    def launchd_env(self, mode="launchd-only", launchctl=None):
        os.environ["SB_RFL_TIMER_MODE"] = mode
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LaunchAgents")
        if launchctl is not None:
            os.environ["SB_RFL_LAUNCHCTL"] = launchctl

    def test_launchd_writes_plist_and_loads(self):
        self.launchd_env()
        loaded = subprocess.CompletedProcess([], 0)
        with mock.patch.object(q.subprocess, "run", return_value=loaded) as run:
            t = self.arm(id="a/b:c")
        self.assertEqual((t["armed"], t["backend"]), (True, "launchd"))
        self.assertEqual(t["label"], "dev.alolabs.sb.rfl-quota-retry.a-b-c")
        plist = Path(t["plist"])
        self.assertEqual(plist.parent, self.tmp / "LaunchAgents")
        body = plist.read_text()
        self.assertIn("<key>Label</key><string>dev.alolabs.sb.rfl-quota-retry.a-b-c</string>", body)
        self.assertIn("<string>--quota-retry-wake</string>", body)
        self.assertIn("<key>RunAtLoad</key><false/>", body)
        self.assertEqual([c.args for c in run.call_args_list], [(["launchctl", "unload", str(plist)],), (["launchctl", "load", str(plist)],)])
        self.assertEqual([c.kwargs for c in run.call_args_list], [{"capture_output": True, "check": False}] * 2)

    def test_launchd_label_defaults_when_job_has_no_id(self):
        self.launchd_env(launchctl="0")
        j = {"fire_at": "2030-01-01T11:00:00Z"}
        with mock.patch.object(q.subprocess, "run") as run:
            t = q.arm_quota_retry_timer(job=j, run_dir=self.run_dir)
        run.assert_not_called()
        self.assertEqual(t["label"], "dev.alolabs.sb.rfl-quota-retry.job")
        self.assertTrue(Path(t["plist"]).is_file())

    def test_launchd_default_directory_is_home_library(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        with mock.patch.object(Path, "home", return_value=self.tmp):
            t = self.arm()
        self.assertEqual(Path(t["plist"]).parent, self.tmp / "Library" / "LaunchAgents")

    def test_launchd_oserror_falls_through(self):
        self.launchd_env(launchctl="0")
        (self.tmp / "LaunchAgents").write_text("a file, not a directory")
        t = self.arm()
        self.assertEqual((t["armed"], t["backend"]), (False, "unarmed"))
        self.assertIn("launchd_error", t)
        self.assertEqual(t["reason"], "no at/launchd backend available")

    def test_darwin_prefers_launchd_then_at(self):
        os.environ["SB_RFL_TIMER_MODE"] = "auto"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        with mock.patch.object(q.sys, "platform", "darwin"):
            self.assertEqual(self.arm()["backend"], "launchd")
        (self.tmp / "LA2").write_text("file")
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA2")
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        proc = subprocess.CompletedProcess([], 0, stdout="", stderr="")
        with mock.patch.object(q.sys, "platform", "darwin"), mock.patch.object(Path, "is_file", return_value=True), \
             mock.patch.object(q.subprocess, "run", return_value=proc):
            self.assertEqual(self.arm()["backend"], "at")

    def test_at_only_on_darwin_skips_launchd_first_but_may_use_it_last(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/nonexistent/at"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        with mock.patch.object(q.sys, "platform", "darwin"):
            t = self.arm()
        # prefer_launchd is true on darwin but at-only skips the first launchd attempt,
        # tries `at` (missing here) and reports no backend.
        self.assertEqual((t["armed"], t["backend"]), (False, "unarmed"))

    def test_linux_auto_tries_at_then_non_darwin_launchd_is_inert(self):
        os.environ["SB_RFL_TIMER_MODE"] = "auto"
        os.environ["SB_RFL_AT_BIN"] = "/nonexistent/at"
        with mock.patch.object(q.sys, "platform", "linux"):
            t = self.arm()
        self.assertEqual((t["armed"], t["backend"], t["reason"]), (False, "unarmed", "no at/launchd backend available"))

    def test_linux_at_failure_never_reaches_launchd_unless_requested(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/nonexistent/at"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        with mock.patch.object(q.sys, "platform", "linux"):
            t = self.arm()
        self.assertFalse((self.tmp / "LA").exists())
        self.assertFalse(t["armed"])


class ArtifactAndNotifyTest(Base):
    def test_write_artifacts(self):
        root = self.tmp / "fresh"
        p = q.write_user_visible_artifact(root, action="ask_user", ask="Q?", job=job())
        self.assertEqual(p, root / q.ASK_FILENAME)
        self.assertIn("\nQ?\n", p.read_text())
        p = q.write_user_visible_artifact(root, action="ask_user", ask=None, job={})
        self.assertIn("The review-fix ladder run `` has already finished (status: over)", p.read_text())
        p = q.write_user_visible_artifact(root, action="retry_rung", ask=None, job=job())
        self.assertEqual(p, root / q.EXECUTE_FILENAME)
        self.assertIn("- Rung: `r1`", p.read_text())
        self.assertIsNone(q.write_user_visible_artifact(root, action="other", ask=None, job=job()))

    def test_notify_user(self):
        os.environ["SB_RFL_NOTIFY"] = "0"
        with mock.patch.object(q.subprocess, "run") as run:
            self.assertFalse(q.notify_user("t", "b"))
        run.assert_not_called()
        del os.environ["SB_RFL_NOTIFY"]
        with mock.patch.object(q.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertTrue(q.notify_user('ti"tle' + "x" * 100, 'bo"dy' + "y" * 300))
        script = run.call_args.args[0][2]
        self.assertTrue(script.startswith("display notification \"bo'dy"))
        self.assertIn('with title "ti\'tle', script)
        self.assertEqual(script.index('" with title "') - len('display notification "'), 180)
        with mock.patch.object(q.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            self.assertFalse(q.notify_user("t", "b"))
        with mock.patch.object(q.subprocess, "run", side_effect=OSError("no osascript")):
            self.assertFalse(q.notify_user("t", "b"))

    def test_discover_run_dirs(self):
        self.assertEqual(q.discover_run_dirs(self.tmp / "none"), [])
        self.assertEqual(q.discover_run_dirs(self.tmp), [])
        for name in ("rfl-b", "rfl-a", "other"):
            d = self.tmp / ".planning" / name
            d.mkdir(parents=True, exist_ok=True)
            (d / q.SCHEDULE_FILENAME).write_text("{}")
        (self.tmp / ".planning" / "rfl-empty").mkdir()
        self.assertEqual(q.discover_run_dirs(self.tmp), [self.tmp / ".planning" / "rfl-a", self.tmp / ".planning" / "rfl-b"])

    def test_visible_artifacts(self):
        self.assertEqual(q.visible_artifacts(self.run_dir), ([], []))
        (self.run_dir / q.EXECUTE_FILENAME).write_text("x")
        asks, execs = q.visible_artifacts(self.run_dir)
        self.assertEqual((asks, len(execs)), ([], 1))
        self.assertIn("Execute the deferred rung on the same named model", execs[0])
        (self.run_dir / q.ASK_FILENAME).write_text("# Title\n\n  Please confirm?  \nmore\n")
        self.assertEqual(q.visible_artifacts(self.run_dir), (["Please confirm?"], []))
        (self.run_dir / q.ASK_FILENAME).write_text("# only headings\n\n")
        self.assertEqual(q.visible_artifacts(self.run_dir), (["Quota retry is due; ask the user before executing."], []))
        (self.run_dir / "QUOTA-RETRY-ACK.md").write_text("ack")
        self.assertEqual(q.visible_artifacts(self.run_dir), ([], []))


class WakeTest(Base):
    def setUp(self):
        super().setUp()
        os.environ["SB_RFL_TIMER_MODE"] = "mock"
        p = mock.patch.object(q, "notify_user", return_value=True)
        self.notify = p.start()
        self.addCleanup(p.stop)

    def test_no_dirs(self):
        out = q.wake_due_jobs(now=NOW)
        self.assertEqual((out["run_dirs"], out["results"], out["user_visible"], out["hook_context"]), ([], [], [], ""))
        self.assertEqual(out["woke_at"], "2030-01-01T12:00:00Z")
        with mock.patch.object(q, "utcnow", return_value=NOW):
            self.assertEqual(q.wake_due_jobs()["woke_at"], "2030-01-01T12:00:00Z")

    def test_wakes_active_ladder_job_and_notifies(self):
        self.put_store([job(), job(id="x", status="executed"), job(id="n", rung="r2", fire_at="2030-01-01T13:00:00Z")])
        out = q.wake_due_jobs(run_dir=self.run_dir, now=NOW)
        self.assertEqual([r["action"] for r in out["results"]], ["retry_rung", "not_due"])
        self.assertEqual(out["results"][1], {"ok": True, "action": "not_due", "execute": False, "job_id": "n", "fire_at": "2030-01-01T13:00:00Z"})
        self.assertEqual(out["executes"], ["Execute rung r1 on gpt (same model)."])
        self.assertEqual(out["asks"], [])
        self.assertEqual(out["run_dirs"], [str(self.run_dir)])
        self.assertEqual(self.notify.call_args.args, ("RFL quota retry — execute", "Retry rung r1 on gpt"))
        self.assertIn("RFL SCHEDULED WORKER: Execute rung r1 on gpt (same model). The 5-hour", out["hook_context"])
        self.assertEqual(self.store()["jobs"][0]["status"], "executed")

    def test_wakes_finished_ladder_job_and_asks(self):
        self.put_store([job()])
        (self.run_dir / "LADDER-STATUS.json").write_text('{"status": "aborted"}')
        out = q.wake_due_jobs(run_dir=self.run_dir, now=NOW)
        self.assertEqual(len(out["asks"]), 1)
        self.assertEqual(out["executes"], [])
        self.assertEqual(self.notify.call_args.args[0], "RFL quota retry — confirm")
        self.assertEqual(out["user_visible"], out["asks"])
        self.assertTrue(out["hook_context"].startswith("RFL SCHEDULED WORKER (user-visible ask): "))

    def test_missing_job_result_is_reported_without_notification(self):
        self.put_store([job(run_id="", rung="", model="")])
        out = q.wake_due_jobs(run_dir=self.run_dir, now=NOW)
        self.assertEqual(out["results"], [{"ok": False, "action": "missing", "execute": False, "ask": None, "error": "no schedule for rfl-demo::::"}])
        self.notify.assert_not_called()

    def test_project_root_discovers_dirs_and_resurfaces_artifacts(self):
        self.put_store([job()])
        other = self.tmp / ".planning" / "rfl-other"
        other.mkdir()
        (other / q.SCHEDULE_FILENAME).write_text('{"jobs": []}')
        (other / q.ASK_FILENAME).write_text("# H\nStill waiting for you?\n")
        third = self.tmp / ".planning" / "rfl-third"
        third.mkdir()
        (third / q.SCHEDULE_FILENAME).write_text('{"jobs": []}')
        (third / q.EXECUTE_FILENAME).write_text("x")
        out = q.wake_due_jobs(project_root=self.tmp, now=NOW)
        self.assertEqual(out["run_dirs"], [str(self.run_dir), str(other), str(third)])
        self.assertEqual(out["executes"][0], "Execute rung r1 on gpt (same model).")
        self.assertEqual(out["asks"], ["Still waiting for you?"])
        self.assertEqual(len(out["executes"]), 2)
        # the dir that just surfaced its own retry does not re-surface the stale artifact it just wrote
        self.assertEqual(len(out["user_visible"]), 3)

    def test_resurfaced_items_are_deduplicated(self):
        dirs = [self.tmp / n for n in ("a", "b", "c", "d")]
        for d in dirs:
            d.mkdir()
            (d / q.SCHEDULE_FILENAME).write_text('{"jobs": []}')
        for d in dirs[:2]:
            (d / q.ASK_FILENAME).write_text("Same question\n")
        for d in dirs[2:]:
            (d / q.EXECUTE_FILENAME).write_text("x")
        with mock.patch.object(q, "discover_run_dirs", return_value=dirs):
            out = q.wake_due_jobs(project_root=self.tmp, now=NOW)
        self.assertEqual((out["asks"], len(out["executes"])), (["Same question"], 1))

    def test_hook_additional_context(self):
        self.assertEqual(q.hook_additional_context({}), "")
        text = q.hook_additional_context({"asks": ["A?"], "executes": ["E1", "E2"]})
        self.assertEqual(text, "\n\n".join([
            "RFL SCHEDULED WORKER (user-visible ask): A?",
            "RFL SCHEDULED WORKER: E1 The 5-hour (or ≤5h) quota window has ended. Do this now.",
            "RFL SCHEDULED WORKER: E2 The 5-hour (or ≤5h) quota window has ended. Do this now.",
        ]))


class ReviewFollowUpTest(Base):
    def test_ask_prompt_receives_job_fields_and_ladder_status(self):
        self.put_store([job(run_id="job-run", rung="r1", model="gpt")])
        (self.run_dir / "LADDER-STATUS.json").write_text('{"status": "aborted"}')
        with mock.patch.object(q, "ask_user_prompt", wraps=q.ask_user_prompt) as ask:
            out = q.activate_quota_retry(run_dir=self.run_dir, run_id="rfl-demo", rung="r1", model="gpt", now=NOW)
        self.assertEqual(ask.call_args.args, ())
        self.assertEqual(ask.call_args.kwargs, {"run_id": "job-run", "rung": "r1", "model": "gpt", "ladder_status": "aborted"})
        self.assertIn("`job-run` has already finished (status: aborted)", out["ask"])

    def test_ask_prompt_falls_back_to_call_arguments_for_sparse_job(self):
        self.put_store([{"id": "rfl-demo::r1::gpt", "status": "asked"}])
        (self.run_dir / "POLICY-D.md").write_text("x")
        with mock.patch.object(q, "ask_user_prompt", wraps=q.ask_user_prompt) as ask:
            q.activate_quota_retry(run_dir=self.run_dir, run_id="rfl-demo", rung="r1", model="gpt", now=NOW)
        self.assertEqual(ask.call_args.kwargs, {"run_id": "rfl-demo", "rung": "r1", "model": "gpt", "ladder_status": "completed"})

    def test_every_duration_unit_in_the_table_is_parsed(self):
        expected_units = {
            "h": 3600, "hr": 3600, "hrs": 3600, "hour": 3600, "hours": 3600,
            "m": 60, "min": 60, "mins": 60, "minute": 60, "minutes": 60,
            "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1,
        }
        self.assertEqual(q._UNIT_SECONDS, expected_units)
        for unit, seconds in q._UNIT_SECONDS.items():
            for text in (f"resets in 2 {unit}", f"Resets in 2{unit.upper()}", f"reset after 1.5 {unit}"):
                with self.subTest(text=text):
                    factor = 1.5 if "1.5" in text else 2
                    self.assertEqual(q.parse_reset_seconds(text), int(factor * seconds))


class TimerContractTest(Base):
    """Complete result dicts and artifacts of the at and launchd backends (fixed fire_at, TZ=UTC)."""

    FIRE = "2031-07-09T15:42:00Z"

    def setUp(self):
        super().setUp()
        import time
        os.environ["TZ"] = "UTC"
        time.tzset()
        self.addCleanup(time.tzset)
        self.addCleanup(lambda: os.environ.pop("TZ", None))
        self.argv = q.wake_argv(project_root=self.tmp, run_dir=self.run_dir)
        self.command = subprocess.list2cmdline(self.argv)

    def arm(self, **jobkw):
        return q.arm_quota_retry_timer(job=job(fire_at=self.FIRE, **jobkw), run_dir=self.run_dir, now=NOW)

    def test_wake_argv_shape(self):
        self.assertEqual(self.argv[2:], ["--quota-retry-wake", "--project-root", str(self.tmp), "--run-dir", str(self.run_dir)])

    def test_at_backend_complete_result(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        proc = subprocess.CompletedProcess([], 0, stdout="", stderr=" job 5 at Tue \n")
        with mock.patch.object(Path, "is_file", return_value=True), mock.patch.object(q.subprocess, "run", return_value=proc) as run:
            t = self.arm()
        self.assertEqual(t, {
            "armed": True, "backend": "at", "at_bin": "/bin/at-stub", "fire_at": self.FIRE,
            "command": self.command, "argv": self.argv, "stderr": "job 5 at Tue",
        })
        self.assertEqual(run.call_args.args[0], ["/bin/at-stub", "-t", "203107091542"])

    def test_at_stderr_is_truncated_to_300_chars(self):
        os.environ["SB_RFL_TIMER_MODE"] = "at-only"
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        proc = subprocess.CompletedProcess([], 0, stdout="", stderr="e" * 350)
        with mock.patch.object(Path, "is_file", return_value=True), mock.patch.object(q.subprocess, "run", return_value=proc):
            self.assertEqual(self.arm()["stderr"], "e" * 300)
        proc = subprocess.CompletedProcess([], 1, stdout="", stderr="f" * 350)
        with mock.patch.object(Path, "is_file", return_value=True), mock.patch.object(q.subprocess, "run", return_value=proc), \
             mock.patch.object(q.sys, "platform", "linux"):
            self.assertEqual(self.arm()["at_error"], "f" * 300)

    def test_default_mode_is_auto_and_default_at_binary_is_at(self):
        for value in (None, ""):
            with self.subTest(mode=value):
                if value is None:
                    os.environ.pop("SB_RFL_TIMER_MODE", None)
                else:
                    os.environ["SB_RFL_TIMER_MODE"] = value
                proc = subprocess.CompletedProcess([], 0, stdout="", stderr="")
                with mock.patch.object(q.sys, "platform", "linux"), \
                     mock.patch.object(q.shutil, "which", side_effect=lambda name: "/usr/bin/at" if name == "at" else None), \
                     mock.patch.object(Path, "is_file", return_value=False), \
                     mock.patch.object(q.subprocess, "run", return_value=proc) as run:
                    t = self.arm()
                self.assertEqual((t["backend"], t["at_bin"]), ("at", "at"))
                self.assertEqual(run.call_args.args[0], ["at", "-t", "203107091542"])

    def test_default_mode_auto_prefers_launchd_on_darwin(self):
        os.environ.pop("SB_RFL_TIMER_MODE", None)
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        with mock.patch.object(q.sys, "platform", "darwin"):
            self.assertEqual(self.arm()["backend"], "launchd")

    def test_launchd_only_never_tries_at(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "file-not-dir")
        (self.tmp / "file-not-dir").write_text("x")
        os.environ["SB_RFL_AT_BIN"] = "/bin/at-stub"
        with mock.patch.object(Path, "is_file", return_value=True), mock.patch.object(q.subprocess, "run") as run:
            t = self.arm()
        run.assert_not_called()
        self.assertEqual((t["armed"], t["backend"], t["reason"]), (False, "unarmed", "no at/launchd backend available"))
        self.assertNotIn("at_error", t)

    def test_launchd_backend_complete_result_and_plist_body(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA" / "nested")
        loaded = subprocess.CompletedProcess([], 0)
        with mock.patch.object(q.subprocess, "run", return_value=loaded):
            t = self.arm(id="a/b:c")
        label = "dev.alolabs.sb.rfl-quota-retry.a-b-c"
        plist = self.tmp / "LA" / "nested" / f"{label}.plist"
        self.assertEqual(t, {
            "armed": True, "backend": "launchd", "fire_at": self.FIRE, "command": self.command,
            "argv": self.argv, "label": label, "plist": str(plist), "launchctl_rc": 0,
        })
        args_xml = "".join(f"<string>{a}</string>" for a in self.argv)
        self.assertEqual(plist.read_text(), (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0">\n<dict>\n'
            f"  <key>Label</key><string>{label}</string>\n"
            "  <key>ProgramArguments</key>\n  <array>\n"
            f"    {args_xml}\n"
            "  </array>\n"
            "  <key>StartCalendarInterval</key>\n  <dict>\n"
            "    <key>Year</key><integer>2031</integer>\n"
            "    <key>Month</key><integer>7</integer>\n"
            "    <key>Day</key><integer>9</integer>\n"
            "    <key>Hour</key><integer>15</integer>\n"
            "    <key>Minute</key><integer>42</integer>\n"
            "  </dict>\n"
            "  <key>RunAtLoad</key><false/>\n"
            "</dict>\n</plist>\n"
        ))

    def test_launchd_without_launchctl_has_no_rc_key(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        t = self.arm(id="x")
        self.assertEqual((t["armed"], t["backend"]), (True, "launchd"))
        self.assertNotIn("launchctl_rc", t)

    def test_launchd_label_truncates_job_id_to_80_chars(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        os.environ["SB_RFL_LAUNCHCTL"] = "0"
        t = self.arm(id="a/" + "b" * 100)
        self.assertEqual(t["label"], "dev.alolabs.sb.rfl-quota-retry.a-" + "b" * 78)
        self.assertEqual(len(t["label"]) - len("dev.alolabs.sb.rfl-quota-retry."), 80)

    def test_failed_launchctl_load_is_not_reported_as_armed(self):
        os.environ["SB_RFL_TIMER_MODE"] = "launchd-only"
        os.environ["SB_RFL_LAUNCHD_DIR"] = str(self.tmp / "LA")
        results = [subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 5)]
        with mock.patch.object(q.subprocess, "run", side_effect=results):
            t = self.arm(id="x")
        self.assertEqual((t["armed"], t["backend"], t["launchctl_rc"]), (False, "launchd", 5))
        self.assertTrue(Path(t["plist"]).is_file())


if __name__ == "__main__":
    unittest.main()
