"""Unit tests for scripts/lib/rfl_native.py (run state, tickets, captures, evidence, lifecycle)."""
from __future__ import annotations

import json
import os
import stat
import subprocess
import unittest
from pathlib import Path
from unittest import mock

from rflhelp import CLEAN_POLICY, RflCase, accept_policy, mint_token, native, pc, qw, rjson

NOW = "2030-01-01T12:00:00Z"
FINDING = {"id": "F1", "severity": "HIGH", "file": "src/a.py", "line": 1, "summary": "bad"}
PASS = {"verdict": "VERIFY_PASS", "checks": [], "gaps": []}


class KeysAndSigningTest(RflCase):
    def test_key_create_reuse_and_missing(self):
        self.assertIsNone(native.project_key(self.root))
        key = native.project_key(self.root, create=True)
        self.assertEqual(len(key), 32)
        self.assertEqual(native.project_key(self.root), key)
        path = native._key_path(self.root)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(native.project_key(self.root, create=True), key)

    def test_short_or_symlinked_key_is_unusable(self):
        path = native._key_path(self.root)
        path.parent.mkdir(parents=True)
        path.write_bytes(b"short")
        self.assertIsNone(native.project_key(self.root))
        path.unlink()
        target = self.tmp / "k"
        target.write_bytes(b"x" * 32)
        path.symlink_to(target)
        self.assertIsNone(native.project_key(self.root))

    def test_sign_verify_and_tamper(self):
        obj = native.signed({"a": 1}, self.root)
        native.verify_signed(obj, self.root, "thing")
        obj["a"] = 2
        with self.assertRaises(native.Tamper):
            native.verify_signed(obj, self.root, "thing")
        with self.assertRaises(native.Tamper):
            native.verify_signed({"a": 1}, self.root, "thing")  # no mac
        other = self.tmp / "other"
        other.mkdir()
        with self.assertRaises(native.Tamper):
            native.verify_signed(native.signed({"a": 1}, self.root), other, "thing")  # other project key

    def test_write_atomic_and_symlink_refusal(self):
        path = self.tmp / "d" / "f.txt"
        native.write_atomic(path, "hi")
        self.assertEqual(path.read_text(), "hi")
        link = self.tmp / "link"
        link.symlink_to(path)
        with self.assertRaises(native.RflError):
            native.write_atomic(link, "x")

    def test_read_signed_errors(self):
        native.project_key(self.root, create=True)
        with self.assertRaises(native.Tamper):
            native.read_signed(self.tmp / "missing.json", self.root, "x")
        path = self.tmp / "ok.json"
        native.write_json(path, {"k": 1}, self.root)
        self.assertEqual(native.read_signed(path, self.root, "x")["k"], 1)
        path.write_text(json.dumps({"k": 2, "mac": "00"}))
        with self.assertRaises(native.Tamper):
            native.read_signed(path, self.root, "x")


class ImportPathTest(unittest.TestCase):
    def test_lib_dir_is_added_to_sys_path_when_missing(self):
        import runpy
        import sys
        lib = str(Path(native.__file__).resolve().parent)
        trimmed = [p for p in sys.path if p != lib]
        with mock.patch.object(sys, "path", trimmed):
            runpy.run_path(native.__file__, run_name="rfl_native_fresh")
            self.assertIn(lib, trimmed)


class PathsTest(RflCase):
    def test_home_and_state_defaults(self):
        del os.environ["SB_RUNTIME_HOME_ROOT"], os.environ["SB_RUNTIME_STATE_DIR"]
        self.assertEqual(native.home_root(), self.tmp / "home" / ".claude")
        self.assertEqual(native.state_dir(), self.tmp / "home" / ".claude" / ".silver-bullet")
        os.environ["SB_RUNTIME_STATE_DIR"] = str(self.tmp / "s")
        self.assertEqual(native.state_dir(), self.tmp / "s")

    def test_now_uses_the_single_seam(self):
        os.environ["SB_RFL_NOW"] = NOW
        self.assertEqual(native.now_iso(), NOW)

    def test_run_path_validates_the_id(self):
        self.assertEqual(native.run_path(self.root, "a.b-1").name, "rfl-a.b-1")
        for bad in ("", "../x", "a/b", "x" * 65, "a b"):
            with self.assertRaises(native.RflError):
                native.run_path(self.root, bad)


class RungsTest(RflCase):
    def rungs(self, *args):
        return [f"{m}:{e}" for m, e in native.apply_rung_spec([native.parse_rung(t) for t in native.DEFAULT_RUNGS], *args)]

    def test_parse_rung(self):
        self.assertEqual(native.parse_rung(" Opus:HIGH "), ("opus", "high"))
        for bad in ("fable:high", "opus", "gpt:high", "opus:ultra", ""):
            with self.assertRaises(native.RflError):
                native.parse_rung(bad)
        with self.assertRaisesRegex(native.RflError, "Fable is never used"):
            native.parse_rung("fable:high")

    def test_defaults(self):
        self.assertEqual([f"{r['model']}:{r['effort']}" for r in native.configured_rungs(self.root)],
                         ["haiku:xhigh", "sonnet:high", "sonnet:xhigh", "opus:low", "opus:medium", "opus:high"])

    def test_plus_minus_and_prefix(self):
        out = self.rungs("rungs: +opus:xhigh -haiku:xhigh")
        self.assertEqual(out, ["sonnet:high", "sonnet:xhigh", "opus:low", "opus:medium", "opus:high", "opus:xhigh"])
        self.assertEqual(self.rungs("+haiku:high, -opus:low -opus:max"), ["haiku:high", "haiku:xhigh", "sonnet:high", "sonnet:xhigh", "opus:medium", "opus:high"])
        self.assertEqual(self.rungs("+opus:high"), list(native.DEFAULT_RUNGS))  # already present: no duplicate

    def test_explicit_list_replaces_in_the_given_order(self):
        self.assertEqual(self.rungs(["opus:high", "sonnet:high", "opus:high"]), ["opus:high", "sonnet:high"])
        self.assertEqual(self.rungs("opus:medium sonnet:high"), ["opus:medium", "sonnet:high"])

    def test_explicit_plus_minus_mix(self):
        self.assertEqual(self.rungs("sonnet:high +haiku:low"), ["sonnet:high", "haiku:low"])
        self.assertEqual(self.rungs("sonnet:high +sonnet:high"), ["sonnet:high"])

    def test_empty_result_is_refused(self):
        with self.assertRaisesRegex(native.RflError, "empty"):
            self.rungs(" ".join("-" + r for r in native.DEFAULT_RUNGS))

    def test_config_sources(self):
        cfg = self.root / ".silver-bullet.json"
        cfg.write_text(json.dumps({"review_fix_ladder": {"rungs": "+opus:xhigh"}}))  # additions are fine
        self.assertEqual(native.configured_rungs(self.root)[-1]["effort"], "xhigh")
        for dropping in ("-haiku:xhigh", ["opus:high"], {"claude": "sonnet:high"}):
            cfg.write_text(json.dumps({"review_fix_ladder": {"rungs": dropping}}))
            with self.assertRaisesRegex(native.RflError, "only the user"):
                native.configured_rungs(self.root)  # a repo config can never shorten the ladder
            self.assertGreater(len(native.configured_rungs(self.root, enforce=False)), 0)
        cfg.write_text(json.dumps({"review_fix_ladder": "nope"}))
        self.assertEqual(len(native.configured_rungs(self.root)), 6)
        cfg.write_text("not json")
        self.assertEqual(len(native.configured_rungs(self.root)), 6)
        native.record_user_rungs(self.root, "-haiku:xhigh")  # the user said so in their own message
        cfg.write_text(json.dumps({"review_fix_ladder": {"rungs": "-haiku:xhigh"}}))
        self.assertEqual(native.configured_rungs(self.root)[0]["model"], "sonnet")
        out = native.configured_rungs(self.root, "-haiku:xhigh")
        self.assertEqual(len(out), 5)
        with self.assertRaisesRegex(native.RflError, "must be what the user asked"):
            native.configured_rungs(self.root, "+opus:xhigh")


class CharterTest(RflCase):
    def test_normalize(self):
        out = native.normalize_charter({"scope": ["src"], "signals": [{"argv": ["true"], "timeout": 9999, "expect_exit": "1"}]})
        self.assertEqual(out["goal"], "")
        self.assertEqual(out["signals"][0]["timeout"], 600)
        self.assertEqual(out["signals"][0]["expect_exit"], 1)
        self.assertEqual(out["signals"][0]["id"], "signal-1")

    def test_rejections(self):
        bad = [
            {}, {"scope": []}, {"scope": ["a"] * (native.MAX_SCOPE + 1)}, {"scope": ["/abs"]}, {"scope": ["../x"]}, {"scope": ["-x"]},
            {"scope": ["a"], "signals": "x"}, {"scope": ["a"], "signals": [{"argv": "ls"}]}, {"scope": ["a"], "signals": ["ls"]},
            {"scope": ["a"], "signals": [{"argv": []}]}, {"scope": ["a"], "key_tasks": "x"}, {"scope": ["a"], "key_tasks": [1]},
            {"scope": ["a"], "signals": [{"argv": ["x"]}] * (native.MAX_SIGNALS + 1)},
        ]
        for raw in bad:
            with self.assertRaises(native.RflError, msg=raw):
                native.normalize_charter(raw)

    def test_hash_is_stable_and_content_sensitive(self):
        a = native.normalize_charter({"scope": ["src"], "key_tasks": ["a"]})
        b = native.normalize_charter({"scope": ["src"], "key_tasks": ["b"]})
        self.assertEqual(native.charter_hash(a), native.charter_hash(dict(a)))
        self.assertNotEqual(native.charter_hash(a), native.charter_hash(b))


class FingerprintTest(RflCase):
    def test_changes_with_content_and_covers_dirs_files_symlinks(self):
        before = native.fingerprint(self.root, ["src"])
        self.assertEqual(len(before["head"]), 40)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        after = native.fingerprint(self.root, ["src"])
        self.assertNotEqual(before["digest"], after["digest"])
        single = native.fingerprint(self.root, ["src/a.py"])
        self.assertEqual(list(single["files"]), ["src/a.py"])
        (self.root / "src" / "ln").symlink_to("a.py")
        (self.root / "src" / ".git").mkdir()
        (self.root / "src" / ".git" / "x").write_text("ignored")
        linked = native.fingerprint(self.root, ["src", "src/ln"])
        self.assertEqual(linked["files"]["src/ln"], "symlink:a.py")
        self.assertNotIn("src/.git/x", linked["files"])
        self.assertEqual(native.fingerprint(self.root, ["nothing"])["files"], {})

    def test_encoder_run_dirs_never_move_the_fingerprint(self):
        (self.root / ".planning" / "rfl-x").mkdir(parents=True)
        (self.root / ".planning" / "rfl-x" / "f").write_text("1")
        (self.root / ".planning" / "keep").mkdir()
        (self.root / ".planning" / "keep" / "g").write_text("1")
        before = native.fingerprint(self.root, ["."])
        (self.root / ".planning" / "rfl-x" / "f").write_text("2")
        self.assertEqual(native.fingerprint(self.root, ["."])["digest"], before["digest"])
        self.assertIn(".planning/keep/g", before["files"])
        self.assertNotIn(".planning/rfl-x/f", before["files"])

    def test_too_many_files_and_no_git(self):
        for i in range(3):
            (self.root / "src" / f"f{i}").write_text(str(i))
        with mock.patch.object(native, "MAX_FILES", 2), self.assertRaisesRegex(native.RflError, "narrow"):
            native.fingerprint(self.root, ["src"])
        with mock.patch.object(native.subprocess, "run", side_effect=OSError("no git")):
            self.assertEqual(native.fingerprint(self.root, ["src/a.py"])["head"], "")


class StartAndApproveTest(RflCase):
    def test_start_creates_a_signed_live_run(self):
        out = self.start(approve=False)
        self.assertEqual(out["run_id"], "demo")
        self.assertEqual(native.live_run_id(self.root), "demo")
        self.assertFalse(native._approved(self.run_dir))
        status = self.status()
        self.assertEqual((status["schema"], status["phase"], status["status"]), (native.SCHEMA, "review", "active"))
        self.assertEqual(status["current_rung"], "rung-01-sonnet-high")
        self.approve()
        self.assertTrue(native._approved(self.run_dir))

    def test_approval_is_regated_when_the_charter_changes(self):
        self.start()
        charter = json.loads((self.run_dir / native.CHARTER_FILE).read_text())
        charter["key_tasks"] = ["different"]
        (self.run_dir / native.CHARTER_FILE).write_text(json.dumps(charter))
        with self.assertRaises(native.Tamper):  # the charter hash is sealed in the run record at --start
            native._approved(self.run_dir)
        (self.run_dir / native.APPROVAL_FILE).unlink()
        with self.assertRaises(native.Tamper):
            native._approved(self.run_dir)

    def test_generated_run_id_and_second_start_refused(self):
        out = native.start_run(self.root, self.write_charter())
        self.assertRegex(out["run_id"], r"^r\d{14}[0-9a-f]{4}$")
        with self.assertRaisesRegex(native.RflError, "already live"):
            native.start_run(self.root, self.write_charter(), run_id="other")

    def test_start_refusals(self):
        with self.assertRaisesRegex(native.RflError, "--charter-file"):
            native.start_run(self.root, None)
        bad = self.tmp / "bad.json"
        bad.write_text("{")
        with self.assertRaisesRegex(native.RflError, "charter"):
            native.start_run(self.root, bad)
        self.start(run_id="x")
        native.clear_live(self.root)
        with self.assertRaisesRegex(native.RflError, "already exists"):
            native.start_run(self.root, self.write_charter(), run_id="x")

    def test_codex_is_disabled_with_the_documented_message(self):
        os.environ["SILVER_BULLET_RUNTIME"] = "codex"
        with self.assertRaisesRegex(native.RflError, "not yet verified on Codex"):
            native.start_run(self.root, self.write_charter())
        with self.assertRaisesRegex(native.RflError, "Astra excluded"):
            native.resume_run(self.root, "demo")
        self.assertFalse(native.CODEX_DEFAULTS["enabled"])

    def test_approve_requires_a_live_active_run(self):
        self.start(approve=False)
        native.clear_live(self.root)
        with self.assertRaisesRegex(native.RflError, "not live"):
            native.approve(self.root, self.run_dir)

    def test_live_pointer_rules(self):
        self.start()
        self.assertEqual(native.live_run_id(self.root), "demo")
        self.assertIsNone(native.live_run_id(self.tmp))  # another project
        pointer = native.pointer_path(self.root, "s1")
        for bad in ("not json", json.dumps({"project_root": str(self.root), "run_id": 5}),
                    json.dumps({"project_root": str(self.root), "run_id": "../x"}),
                    json.dumps({"project_root": str(self.root), "run_id": "ghost"}),
                    json.dumps({"project_root": "/elsewhere", "run_id": "demo"})):
            pointer.write_text(bad)
            self.assertIsNone(native.live_run_id(self.root), bad)
        native.clear_live(self.root)
        native.clear_live(self.root)  # idempotent

    def test_pointers_are_per_session_and_stale_ones_are_pruned(self):
        os.environ["SB_RFL_SESSION_ID"] = "s1"
        self.start()
        self.assertEqual(native.live_run_id(self.root), "demo")
        self.assertIsNone(native.live_run_id(self.root, "s2"))
        self.assertEqual(native.live_run_id(self.root, "s1"), "demo")
        native.prune_pointers(self.root, "s2")
        self.assertEqual(native.live_run_id(self.root, "s1"), "demo")  # another session's startup leaves it alone
        old = native.pointer_path(self.root, "s1")
        os.utime(old, (1, 1))
        native.prune_pointers(self.root, "s9")
        self.assertIsNone(native.live_run_id(self.root, "s1"))  # stale (a day untouched)
        native.prune_pointers(self.root, "s9")  # nothing left: still fine
        native.record_session(self.root, "bad session!")  # unsafe ids are never recorded
        native.record_session(self.root, "s5")
        del os.environ["SB_RFL_SESSION_ID"], os.environ["CLAUDE_CODE_SESSION_ID"]
        self.assertEqual(native.current_session(self.root), "s5")
        native.record_session(self.root, "s6")  # two recent sessions: no sound answer
        self.assertEqual(native.current_session(self.root), "")

    def test_clear_live_with_a_run_id_drops_every_session_pointer_to_it(self):
        os.environ["SB_RFL_SESSION_ID"] = "s1"
        self.start()
        other = native.pointer_path(self.root, "s2")
        other.write_text(native.pointer_path(self.root, "s1").read_text())
        unrelated = native.pointer_path(self.root, "s3")
        unrelated.write_text(json.dumps({"project_root": str(self.root), "run_id": "elsewhere"}))
        corrupt = native.pointer_path(self.root, "s4")
        corrupt.write_text("not json")
        native.clear_live(self.root, "demo")
        self.assertFalse(native.pointer_path(self.root, "s1").exists() or other.exists())
        self.assertTrue(unrelated.exists() and corrupt.exists())

    def test_user_rungs_expire_and_must_be_valid(self):
        native.record_user_rungs(self.root, "rungs: -haiku:xhigh")
        self.assertEqual(native.user_rungs(self.root), "-haiku:xhigh")
        with self.assertRaises(native.RflError):
            native.record_user_rungs(self.root, "gpt:high")
        os.environ["SB_RFL_NOW"] = "2099-01-01T00:00:00Z"
        self.assertEqual(native.user_rungs(self.root), "")

    def test_a_run_record_that_is_forged_or_missing_never_verifies(self):
        self.start()
        path = native.record_path(self.root, "demo")
        data = json.loads(path.read_text())
        data["approved_sha256"] = "x"
        path.write_text(json.dumps(data))
        with self.assertRaises(native.Tamper):
            native.load_record(self.root, "demo")
        path.unlink()
        with self.assertRaises(native.Tamper):
            native.load_record(self.root, "demo")
        self.assertIsNone(native.live_run_id(self.root))

    def test_status_load_errors(self):
        self.start()
        path = self.run_dir / native.STATUS_FILE
        data = json.loads(path.read_text())
        data["schema"] = "old"
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(native.Tamper, "legacy"):
            native.load_status(self.root, self.run_dir)
        path.write_text("[]")
        with self.assertRaises(native.Tamper):
            native.load_status(self.root, self.run_dir)
        data["schema"] = native.SCHEMA
        data["phase"] = "advance"
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(native.Tamper, "modified outside"):
            native.load_status(self.root, self.run_dir)

    def test_deep_status_file_is_tamper_not_a_crash(self):
        self.start()
        (self.run_dir / native.STATUS_FILE).write_text("[" * 200000 + "]" * 200000)
        with self.assertRaises(native.Tamper):
            native.load_status(self.root, self.run_dir)

    def test_save_status_requires_no_stale_open_state(self):
        self.start()
        status = self.status()
        self.assertEqual(status["consecutive_clean_reviews"], 0)
        self.assertEqual(native.status_report(self.root, self.run_dir)["live"], True)


class TicketTest(RflCase):
    def test_issue_review_ticket(self):
        self.start()
        issued = self.ticket("review")
        params = issued["spawn"]["params"]
        self.assertEqual((params["subagent_type"], params["model"], params["effort"]), ("sb-rfl-reviewer", "sonnet", "high"))
        self.assertIn(issued["ticket"], params["prompt"])
        self.assertIn("<untrusted-data", params["prompt"])
        self.assertIn("READ-ONLY", params["prompt"])
        ticket = native.read_ticket(self.root, self.run_dir, issued["ticket"])
        self.assertEqual(ticket["brief_sha256"], native.sha256_text(params["prompt"].strip()))
        self.assertEqual(self.status()["open_ticket"], issued["ticket"])

    def test_issue_refusals(self):
        self.start(approve=False)
        with self.assertRaisesRegex(native.RflError, "Policy E"):
            self.ticket("review")
        self.approve()
        with self.assertRaisesRegex(native.RflError, "one of"):
            native.issue_ticket(self.root, self.run_dir, "triage")
        with self.assertRaisesRegex(native.RflError, "next step on rung 1 is review, not verify_1"):
            self.ticket("verify_1")
        self.ticket("review")
        with self.assertRaisesRegex(native.RflError, "still open"):
            self.ticket("review")
        native.clear_live(self.root)
        with self.assertRaisesRegex(native.RflError, "not live"):
            self.ticket("review")

    def test_inactive_run_refuses(self):
        self.start()
        status = self.status()
        status["status"] = "paused_quota"
        native.save_status(self.root, self.run_dir, status)
        with self.assertRaisesRegex(native.RflError, "paused_quota"):
            self.ticket("review")

    def test_verify_needs_policy_c(self):
        self.start()
        self.review()
        self.write_policy(CLEAN_POLICY)
        native.complete_triage(self.root, self.run_dir)
        (self.rung_dir() / "POLICY-C.json").unlink()
        with self.assertRaisesRegex(native.RflError, "Policy C is incomplete"):
            self.ticket("verify_1")

    def test_attempt_cap_message(self):
        self.start()
        status = self.status()
        status["attempts"]["1:review"] = 2
        native.save_status(self.root, self.run_dir, status)
        with self.assertRaisesRegex(native.RflError, "two attempts"):
            self.ticket("review")

    def test_verify_brief_lists_accepted_findings_as_data(self):
        self.start()
        self.review([FINDING])
        self.write_policy(accept_policy())
        native.complete_triage(self.root, self.run_dir)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        native.record_apply(self.root, self.run_dir)
        prompt = self.ticket("verify_1")["spawn"]["params"]["prompt"]
        self.assertIn("accepted-findings", prompt)
        self.assertIn("F1:", prompt)
        self.assertIn("verifier", prompt)

    def test_bad_ticket_ids_are_tamper(self):
        self.start()
        for bad in ("", "../x", "T-" + "a" * 101, "X-1"):
            with self.assertRaises(native.Tamper, msg=bad):
                native.read_ticket(self.root, self.run_dir, bad)

    def test_hook_observed_failed_launches_skip_a_rung_and_record_the_captured_text(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        out = self.failed_launch()
        self.assertEqual((out["outcome"], out["attempts"], out["skipped"]), ("no_verdict", 1, False))
        out = self.failed_launch()
        self.assertTrue(out["skipped"])
        status = self.status()
        self.assertEqual((status["rung_index"], status["skipped"], status["phase"]), (2, [1], "review"))
        skipped = (self.run_dir / "rung-01-sonnet-high" / "SKIPPED.md").read_text()
        self.assertIn("no_verdict", skipped)
        self.assertIn("no verdict here", skipped)
        with self.assertRaisesRegex(native.RflError, "no open ticket"):
            native.cancel_ticket(self.root, self.run_dir)


class CaptureTest(RflCase):
    def test_shapes_and_last_block_wins(self):
        self.start()
        issued = self.ticket("review")
        t = issued["ticket"]
        echoed = f'<rfl-result ticket="{t}">{{ "verdict": "CLEAN" | "NOT CLEAN" }}</rfl-result>'
        real = f'<rfl-result ticket="{t}">{json.dumps({"verdict": "CLEAN", "findings": []})}</rfl-result>'
        other = '<rfl-result ticket="T-99-review-1-deadbeef">{"verdict":"NOT CLEAN","findings":[]}</rfl-result>'
        out = native.capture_response(self.root, self.run_dir, "Agent", [{"result": echoed}, {"output": [real, other]}])
        self.assertTrue(out["captured"])
        self.assertEqual(self.status()["phase"], "triage")
        capture = json.loads(next(self.rung_dir().glob("cycle-1-review.capture.json")).read_text())
        self.assertEqual((capture["captured_from"], capture["tool_name"]), ("hook", "Agent"))
        self.assertTrue(capture["mac"])
        self.assertIn("untrusted data", (self.rung_dir() / "review.md").read_text())

    def test_no_open_ticket_or_inactive(self):
        self.start()
        self.assertFalse(native.capture_response(self.root, self.run_dir, "Agent", "x")["captured"])
        self.ticket("review")
        status = self.status()
        status["status"] = "paused_quota"
        native.save_status(self.root, self.run_dir, status)
        self.assertEqual(native.capture_response(self.root, self.run_dir, "Agent", "x")["reason"], "no open ticket")

    def test_missing_malformed_or_oversized_blocks_are_a_failed_attempt(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        issued = self.ticket("review")
        t = issued["ticket"]
        out = native.capture_response(self.root, self.run_dir, "Agent", "Async agent launched successfully. agentId: a1")
        self.assertEqual((out["outcome"], out["attempts"]), ("no_verdict", 1))
        issued = self.ticket("review")
        t = issued["ticket"]
        big = "x" * (native.MAX_RESULT_BYTES + 10)
        out = native.capture_response(self.root, self.run_dir, "Agent", f'<rfl-result ticket="{t}">{big}</rfl-result>')
        self.assertTrue(out["skipped"])
        self.assertEqual(self.status()["rung_index"], 2)
        issued = self.ticket("review")
        out = native.capture_response(self.root, self.run_dir, "Agent", f'<rfl-result ticket="{issued["ticket"]}">{{"verdict":"CLEAN","findings":[{{}}]}}</rfl-result>')
        self.assertEqual(out["outcome"], "no_verdict")

    def test_quota_text_pauses_without_counting_an_attempt(self):
        self.start()
        issued = self.ticket("review")
        out = native.capture_response(self.root, self.run_dir, "Agent", "5-hour usage limit reached. Resets in 2hr")
        self.assertEqual((out["outcome"], out["quota_class"]), ("blocked_quota", "five_hour"))
        os.environ["SB_RFL_NOW"] = NOW
        status = self.status()
        self.assertEqual(status["status"], "paused_quota")
        self.assertIsNotNone(status["resume_after"])
        self.assertEqual(status["attempts"], {})
        self.assertIsNone(status["open_ticket"])
        self.assertTrue((self.rung_dir() / "BLOCKED.md").is_file())
        classify = json.loads((self.rung_dir() / "QUOTA-CLASSIFY.json").read_text())
        self.assertTrue(classify["should_schedule"])
        self.assertFalse(native.read_ticket(self.root, self.run_dir, issued["ticket"])["open"])

    def test_weekly_pause_has_no_resume_time(self):
        self.start()
        self.ticket("review")
        out = native.capture_response(self.root, self.run_dir, "Agent", "weekly usage limit reached")
        self.assertEqual(out["quota_class"], "weekly")
        self.assertIsNone(out["resume_after"])

    def test_short_unknown_429_is_just_a_failed_attempt(self):
        self.start()
        self.ticket("review")
        out = native.capture_response(self.root, self.run_dir, "Agent", "HTTP 429 too many requests")
        self.assertEqual(out["outcome"], "no_verdict")

    def test_flatten_text_is_bounded(self):
        self.assertEqual(native.flatten_text(None), "")
        self.assertEqual(native.flatten_text({"a": ["x", {"b": "y"}], "c": 5}), "x\ny")
        self.assertEqual(len(native.flatten_text("z" * 100, [10])), 10)

    def test_validate_result(self):
        v = native.validate_result
        self.assertEqual(v("review", {"verdict": "NOT CLEAN", "findings": [FINDING]})["findings"][0]["id"], "F1")
        bad_review = [
            {}, {"verdict": "OK", "findings": []}, {"verdict": "CLEAN", "findings": "x"},
            {"verdict": "CLEAN", "findings": [FINDING]}, {"verdict": "NOT CLEAN", "findings": []},
            {"verdict": "NOT CLEAN", "findings": ["x"]}, {"verdict": "NOT CLEAN", "findings": [{**FINDING, "severity": "BAD"}]},
            {"verdict": "NOT CLEAN", "findings": [{**FINDING, "id": "bad id"}]},
            {"verdict": "NOT CLEAN", "findings": [FINDING] * (native.MAX_FINDINGS + 1)},
        ]
        for raw in bad_review:
            with self.assertRaises(native.RflError, msg=raw):
                v("review", raw)
        ok = v("verify_1", {"verdict": "VERIFY_FAIL", "checks": [{"finding_id": "F1", "status": "open", "evidence": "e"}], "gaps": ["g"] * 80})
        self.assertEqual(len(ok["gaps"]), 50)
        self.assertEqual(v("verify_2", {"verdict": "VERIFY_PASS", "checks": []})["gaps"], [])
        for raw in ({}, {"verdict": "VERIFY_PASS", "checks": "x"}, {"verdict": "VERIFY_PASS", "checks": [{"status": "weird"}]},
                    {"verdict": "VERIFY_PASS", "checks": ["x"]}, {"verdict": "VERIFY_PASS", "checks": [], "gaps": "x"}):
            with self.assertRaises(native.RflError, msg=raw):
                v("verify_1", raw)

    def test_render_md_escapes_table_cells(self):
        ticket = {"ticket": "T", "model": "m", "effort": "e"}
        md = native.render_result_md("review", ticket, {"verdict": "NOT CLEAN", "findings": [{**FINDING, "summary": "a|b\nc"}]})
        self.assertIn("a\\|b c", md)
        md = native.render_result_md("verify_1", ticket, {"verdict": "VERIFY_PASS", "checks": [], "gaps": []})
        self.assertIn("- none", md)


class CycleTest(RflCase):
    def test_clean_cycles_build_the_streak_then_verify_two_then_advance(self):
        self.start()
        out = self.clean_cycle()
        self.assertEqual((out["ok"], out["next"]), (True, "review"))
        self.assertEqual(len(self.status()["streak"]), 1)
        out = self.clean_cycle()
        self.assertEqual(out["next"], "verify_2")
        issued = self.ticket("verify_2")
        self.reply(issued["ticket"], PASS)
        self.assertEqual(native.run_signals(self.root, self.run_dir)["next"], "advance")
        self.assertEqual(native.advance(self.root, self.run_dir)["status"], "completed")
        self.assertTrue((self.run_dir / "LADDER-COMPLETE.md").is_file())
        self.assertIsNone(native.live_run_id(self.root))
        for name in ("review.md", "verify-1.md", "verify-2.md", "signals-1.json", "signals-2.json"):
            self.assertTrue((self.rung_dir() / name).is_file(), name)

    def test_a_new_review_archives_the_previous_policy_c_so_triage_must_be_redone(self):
        self.start()
        self.clean_cycle()
        issued = self.ticket("review")
        self.reply(issued["ticket"], {"verdict": "CLEAN", "findings": []})
        self.assertFalse((self.rung_dir() / "POLICY-C.json").exists())
        self.assertTrue((self.rung_dir() / "POLICY-C-cycle-1.json").is_file())
        self.assertTrue((self.rung_dir() / "POLICY-C-cycle-1.md").is_file())
        with self.assertRaisesRegex(native.RflError, "write a valid POLICY-C"):
            native.complete_triage(self.root, self.run_dir)

    def test_file_change_between_clean_reviews_resets_the_streak(self):
        self.start()
        self.clean_cycle()
        (self.root / "src" / "a.py").write_text("x = 3\n")
        self.clean_cycle()
        self.assertEqual(len(self.status()["streak"]), 1)

    def test_change_during_a_clean_cycle_is_not_clean(self):
        self.start()
        self.review()
        self.write_policy(CLEAN_POLICY)
        native.complete_triage(self.root, self.run_dir)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], PASS)
        (self.root / "src" / "a.py").write_text("x = 9\n")
        native.run_signals(self.root, self.run_dir)
        self.assertEqual(self.status()["streak"], [])

    def test_claimed_clean_twice_without_captures_cannot_advance(self):
        self.start()
        with self.assertRaisesRegex(native.RflError, "next step on rung 1 is review"):
            self.ticket("verify_2")
        with self.assertRaisesRegex(native.RflError, "not advance"):
            native.advance(self.root, self.run_dir)

    def test_triage_needs_valid_policy_c_and_covers_findings(self):
        self.start()
        with self.assertRaisesRegex(native.RflError, "not triage"):
            native.complete_triage(self.root, self.run_dir)
        self.review([FINDING])
        with self.assertRaisesRegex(native.RflError, "valid POLICY-C"):
            native.complete_triage(self.root, self.run_dir)
        self.write_policy({**CLEAN_POLICY, "verdict": "NOT CLEAN", "issues": {"HIGH": [{"id": "F1", "title": "t"}], "MED": "none", "LOW": "none", "NIT": "none"},
                           "triage": [{"id": "F1", "decision": "REJECT-as-wrong", "reason": "r"}]})
        native.complete_triage(self.root, self.run_dir)  # the row decides the one finding
        self.assertEqual(self.status()["phase"], "verify_1")

    def test_triage_with_fewer_rows_than_findings_is_refused(self):
        self.start()
        self.review([FINDING, {**FINDING, "id": "F2"}])
        self.write_policy({**CLEAN_POLICY, "verdict": "NOT CLEAN", "issues": {"HIGH": [{"id": "F1", "title": "t"}], "MED": "none", "LOW": "none", "NIT": "none"},
                           "triage": [{"id": "F1", "decision": "REJECT-as-wrong", "reason": "r"}]})
        with self.assertRaisesRegex(native.RflError, "every captured finding"):
            native.complete_triage(self.root, self.run_dir)

    def test_accept_apply_verify_fail_loop(self):
        self.start()
        self.review([FINDING])
        self.write_policy(accept_policy())
        self.assertEqual(native.complete_triage(self.root, self.run_dir), {"ok": True, "accepts": 1, "next": "apply"})
        with self.assertRaisesRegex(native.RflError, "no in-scope file changed"):
            native.record_apply(self.root, self.run_dir)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        native.record_apply(self.root, self.run_dir)
        self.assertTrue((self.rung_dir() / "APPLY.md").is_file())
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], {"verdict": "VERIFY_FAIL", "checks": [{"finding_id": "F1", "status": "open", "evidence": "still"}], "gaps": []})
        status = self.status()
        self.assertEqual((status["phase"], status["streak"]), ("apply", []))
        with self.assertRaisesRegex(native.RflError, "no in-scope file changed"):
            native.record_apply(self.root, self.run_dir)
        (self.root / "src" / "a.py").write_text("x = 3\n")
        native.record_apply(self.root, self.run_dir)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], {"verdict": "VERIFY_PASS", "checks": [{"finding_id": "F1", "status": "resolved", "evidence": "ok"}], "gaps": []})
        out = native.run_signals(self.root, self.run_dir)
        self.assertEqual((out["ok"], out["next"]), (True, "review"))
        self.assertEqual(self.status()["streak"], [])  # an accepted fix never counts as clean

    def test_verify_pass_that_skips_an_accepted_id_is_a_fail(self):
        self.start()
        self.review([FINDING])
        self.write_policy(accept_policy())
        native.complete_triage(self.root, self.run_dir)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        native.record_apply(self.root, self.run_dir)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], PASS)  # claims PASS but never reports F1 resolved
        self.assertEqual(self.status()["phase"], "apply")

    def test_apply_row_naming_an_unchanged_file_is_refused(self):
        self.start()
        (self.root / "src" / "b.py").write_text("y = 1\n")
        self.review([FINDING])
        self.write_policy(accept_policy(file="src/a.py"))
        native.complete_triage(self.root, self.run_dir)
        (self.root / "src" / "b.py").write_text("y = 2\n")  # a different in-scope file changed
        with self.assertRaisesRegex(native.RflError, "did not change"):
            native.record_apply(self.root, self.run_dir)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        native.record_apply(self.root, self.run_dir)

    def test_apply_only_in_the_apply_phase(self):
        self.start()
        with self.assertRaisesRegex(native.RflError, "not apply"):
            native.record_apply(self.root, self.run_dir)

    def test_failing_signal_sends_the_run_back_to_apply(self):
        self.start(signals=[{"id": "never", "argv": ["false"]}, {"id": "gone", "argv": ["/nonexistent-binary"]},
                            {"id": "slow", "argv": ["sleep", "5"], "timeout": 1}])
        self.review()
        self.write_policy(CLEAN_POLICY)
        native.complete_triage(self.root, self.run_dir)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], PASS)
        out = native.run_signals(self.root, self.run_dir)
        self.assertFalse(out["ok"])
        self.assertEqual([s["passed"] for s in out["signals"]], [False, False, False])
        record = json.loads((self.rung_dir() / "signals-1.json").read_text())
        self.assertEqual([s["exit"] for s in record["signals"]], [1, 127, -1])
        self.assertEqual(self.status()["phase"], "apply")

    def test_signals_phase_guard_and_expected_exit(self):
        self.start(signals=[{"id": "one", "argv": ["sh", "-c", "exit 3"], "expect_exit": 3}])
        with self.assertRaisesRegex(native.RflError, "not signals"):
            native.run_signals(self.root, self.run_dir)

    def test_advance_requires_policy_c_artifacts(self):
        self.start()
        self.finish_rung()
        (self.rung_dir() / "verify-2.md").unlink()
        with self.assertRaisesRegex(native.RflError, "cannot advance"):
            native.advance(self.root, self.run_dir)

    def test_multi_rung_advance_and_completion(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        self.finish_rung()
        out = native.advance(self.root, self.run_dir)
        self.assertEqual((out["status"], out["rung"], out["next"]), ("active", 2, "review"))
        self.assertEqual(self.status()["streak"], [])
        self.finish_rung()
        self.assertEqual(native.advance(self.root, self.run_dir)["status"], "completed")

    def test_skipped_rungs_are_retried_once_after_the_ladder(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        for _ in range(2):
            self.failed_launch()
        self.assertEqual(self.status()["skipped"], [1])
        self.finish_rung()
        out = native.advance(self.root, self.run_dir)
        self.assertEqual((out["status"], out["rung"]), ("active", 1))
        status = self.status()
        self.assertTrue(status["retrying"])
        self.assertEqual(status["attempts"].get("1:review", 0), 0)
        self.finish_rung()
        self.assertEqual(native.advance(self.root, self.run_dir)["status"], "completed")
        self.assertEqual(self.status()["skipped"], [])
        self.assertIn("skipped-then-retried", (self.run_dir / "LADDER-COMPLETE.md").read_text())

    def test_a_rung_skipped_again_after_retry_stays_skipped_and_the_ladder_ends(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        for _ in range(2):
            self.failed_launch()
        self.finish_rung()
        native.advance(self.root, self.run_dir)
        for _ in range(2):
            self.failed_launch()
        status = self.status()
        self.assertEqual((status["status"], status["skipped"]), ("completed", [1]))
        self.assertIn("Skipped rungs: 1", (self.run_dir / "LADDER-COMPLETE.md").read_text())

    def test_two_skipped_rungs_retry_in_order(self):
        self.start(rungs="sonnet:high sonnet:xhigh opus:low")
        for rung in (1, 2):
            for _ in range(2):
                self.failed_launch()
        self.finish_rung()
        native.advance(self.root, self.run_dir)
        self.assertEqual(self.status()["rung_index"], 1)
        self.finish_rung()
        out = native.advance(self.root, self.run_dir)
        self.assertEqual(out["rung"], 2)

    def test_completion_when_the_run_is_not_live_does_not_touch_the_pointer(self):
        self.start()
        for _ in range(4):  # two attempts, then the post-ladder retry's two attempts
            self.ticket("review")
            native.clear_live(self.root)
            native.capture_response(self.root, self.run_dir, "Agent", "nothing")
            native.set_live(self.root, "demo")
        self.assertEqual(self.status()["status"], "completed")
        self.assertEqual(native.live_run_id(self.root), "demo")  # the pointer set after completion is untouched

    def test_stop_md_clears_when_the_failed_phase_reruns(self):
        self.start()
        issued = self.ticket("review")
        (self.rung_dir() / "STOP.md").write_text("check: x\n")
        self.reply(issued["ticket"], {"verdict": "CLEAN", "findings": []})
        self.assertFalse((self.rung_dir() / "STOP.md").exists())


class AbortTest(RflCase):
    def test_abort_needs_a_fresh_signed_token(self):
        self.start()
        with self.assertRaisesRegex(native.RflError, "RFL ABORT demo"):
            native.abort_run(self.root, "demo")
        mint_token(self.root, "abort", "demo")
        out = native.abort_run(self.root, "demo")
        self.assertEqual(out["status"], "aborted")
        self.assertEqual(self.status()["status"], "aborted")
        self.assertTrue((self.run_dir / "ABORTED.md").is_file())
        self.assertIsNone(native.live_run_id(self.root))
        self.assertFalse(native.abort_token_path("demo").exists())

    def test_expired_forged_or_other_run_token_is_refused(self):
        self.start()
        os.environ["SB_RFL_NOW"] = NOW
        mint_token(self.root, "abort", "demo")
        os.environ["SB_RFL_NOW"] = "2030-01-01T13:00:00Z"
        with self.assertRaisesRegex(native.RflError, "expired"):
            native.abort_run(self.root, "demo")
        native.abort_token_path("demo").write_text(json.dumps({"run_id": "demo", "expires_at": "2099-01-01T00:00:00Z", "mac": "bad"}))
        with self.assertRaises(native.Tamper):
            native.abort_run(self.root, "demo")
        native.write_json(native.abort_token_path("demo"), {"run_id": "other", "expires_at": "2099-01-01T00:00:00Z"}, self.root)
        with self.assertRaisesRegex(native.RflError, "does not match"):
            native.abort_run(self.root, "demo")
        native.write_json(native.abort_token_path("demo"), {"run_id": "demo", "expires_at": "garbage"}, self.root)
        with self.assertRaisesRegex(native.RflError, "expired"):
            native.abort_run(self.root, "demo")

    def test_abort_when_another_run_is_live_keeps_the_pointer(self):
        self.start()
        native.clear_live(self.root)
        self.run_dir = native.run_path(self.root, "second")
        native.start_run(self.root, self.write_charter(), run_id="second")
        native.set_live(self.root, "demo")  # the first run is the live one in this session again
        mint_token(self.root, "abort", "second")
        native.abort_run(self.root, "second")
        self.assertEqual(native.live_run_id(self.root), "demo")


class ResumeTest(RflCase):
    def test_resume_a_quota_paused_run(self):
        self.start()
        self.ticket("review")
        native.capture_response(self.root, self.run_dir, "Agent", "5-hour usage limit reached")
        native.clear_live(self.root)
        out = native.resume_run(self.root, "demo")
        self.assertEqual(out["note"], "resumed after a quota pause")
        self.assertEqual(self.status()["status"], "active")
        self.assertEqual(native.live_run_id(self.root), "demo")

    def test_resume_drops_a_stale_open_ticket_and_resets_a_changed_streak(self):
        self.start()
        self.clean_cycle()
        self.ticket("review")
        native.clear_live(self.root)
        (self.root / "src" / "a.py").write_text("x = 5\n")
        native.resume_run(self.root, "demo")
        status = self.status()
        self.assertIsNone(status["open_ticket"])
        self.assertEqual(status["streak"], [])

    def test_resume_refusals(self):
        with self.assertRaisesRegex(native.RflError, "no run"):
            native.resume_run(self.root, "ghost")
        self.start()
        other = native.run_path(self.root, "second")
        other.mkdir()
        with self.assertRaisesRegex(native.RflError, "is live"):
            native.resume_run(self.root, "second")
        self.finish_rung()
        native.advance(self.root, self.run_dir)
        with self.assertRaisesRegex(native.RflError, "completed"):
            native.resume_run(self.root, "demo")

    def test_legacy_run_is_migrated_restarting_at_rung_one(self):
        legacy = native.run_path(self.root, "old")
        (legacy / "rung-03-cursor-glm-high").mkdir(parents=True)
        (legacy / native.STATUS_FILE).write_text(json.dumps({"status": "active", "current_rung": "rung-03-cursor-glm-high", "consecutive_clean_reviews": 1}))
        with self.assertRaisesRegex(native.RflError, "CHARTER.json"):
            native.resume_run(self.root, "old")
        out = native.resume_run(self.root, "old", self.write_charter())
        self.assertTrue(out["legacy_migrated"])
        self.run_dir = legacy
        status = self.status()
        self.assertEqual((status["rung_index"], status["streak"], status["phase"]), (1, [], "review"))  # the old rung is never trusted
        self.assertTrue((legacy / "rung-03-cursor-glm-high").is_dir())  # history kept
        self.assertFalse(native._approved(legacy))  # Policy E is asked again

    def test_legacy_variants_and_unrecognised_files(self):
        bare = native.run_path(self.root, "bare")
        bare.mkdir(parents=True)
        (bare / native.STATUS_FILE).write_text("[" * 100000)
        with self.assertRaisesRegex(native.Tamper, "failed re-validation"):
            native.resume_run(self.root, "bare")  # unreadable is never migrated
        (bare / native.STATUS_FILE).write_text(json.dumps({"hello": "world"}))
        with self.assertRaisesRegex(native.Tamper, "not a run of this ladder"):
            native.resume_run(self.root, "bare")
        (bare / native.STATUS_FILE).write_text(json.dumps({"status": "active"}))
        (bare / native.CHARTER_FILE).write_text(json.dumps(self.CHARTER))
        native.resume_run(self.root, "bare")
        self.run_dir = bare
        self.assertEqual(self.status()["rung_index"], 1)
        native.clear_live(self.root)
        clamped = native.run_path(self.root, "clamp")
        clamped.mkdir()
        (clamped / native.STATUS_FILE).write_text(json.dumps({"status": "active", "current_rung": "rung-99-x"}))
        bad = self.tmp / "bad.json"
        bad.write_text("{")
        with self.assertRaisesRegex(native.RflError, "charter"):
            native.resume_run(self.root, "clamp", bad)
        native.resume_run(self.root, "clamp", self.write_charter())
        self.run_dir = clamped
        self.assertEqual(self.status()["rung_index"], 1)

    def test_status_report(self):
        self.start()
        report = native.status_report(self.root, self.run_dir)
        self.assertEqual((report["phase"], report["status"], report["streak"]), ("review", "active", 0))


class LegacyTimerCleanupTest(RflCase):
    def test_removes_only_the_scheduler_label_prefix(self):
        agents = self.tmp / "home" / "Library" / "LaunchAgents"
        agents.mkdir(parents=True)
        mine = agents / "dev.alolabs.sb.rfl-quota-retry.abc.plist"
        other = agents / "com.other.plist"
        mine.write_text("x")
        other.write_text("x")
        self.assertEqual(native.cleanup_legacy_timers(dry_run=True), [str(mine)])
        self.assertTrue(mine.exists())
        calls = []
        with mock.patch.object(native.shutil, "which", return_value="/bin/launchctl"), \
                mock.patch.object(native.subprocess, "run", side_effect=lambda *a, **k: calls.append(a[0])):
            self.assertEqual(native.cleanup_legacy_timers(), [str(mine)])
        self.assertFalse(mine.exists())
        self.assertTrue(other.exists())
        self.assertEqual(calls[0][:2], ["/bin/launchctl", "bootout"])

    def test_no_launchctl_and_no_directory(self):
        self.assertEqual(native.cleanup_legacy_timers(), [])
        agents = self.tmp / "home" / "Library" / "LaunchAgents"
        agents.mkdir(parents=True)
        plist = agents / "dev.alolabs.sb.rfl-quota-retry.x.plist"
        plist.write_text("x")
        with mock.patch.object(native.shutil, "which", return_value=None):
            native.cleanup_legacy_timers()
        self.assertFalse(plist.exists())
        plist.write_text("x")
        with mock.patch.object(native.shutil, "which", return_value=None), mock.patch.object(Path, "unlink", side_effect=OSError):
            self.assertEqual(native.cleanup_legacy_timers(), [str(plist)])


if __name__ == "__main__":
    unittest.main()
