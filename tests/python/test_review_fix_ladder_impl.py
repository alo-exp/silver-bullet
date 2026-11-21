"""Unit tests for scripts/_review_fix_ladder_impl.py (encoder CLI): resolver, lifecycle, policy, quota, hook."""
from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

from rflhelp import CLEAN_POLICY, RflCase, native
from sbtest import load_module

impl = load_module("scripts/_review_fix_ladder_impl.py", name="rfl_impl_under_test")


class CliCase(RflCase):
    def cli(self, *argv, stdin=""):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err), mock.patch.object(sys, "stdin", io.StringIO(stdin)):
            try:
                code = impl.main(["--project-root", str(self.root), *argv])
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def jcli(self, *argv, **kw):
        code, out, err = self.cli(*argv, **kw)
        return code, (json.loads(out) if out.strip().startswith(("{", "[")) else out), err


class ResolverTest(CliCase):
    def test_detect_host(self):
        for key in ("CODEX_CI", "CODEX_THREAD_ID", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE", "CLAUDE_PLUGIN_ROOT"):
            os.environ.pop(key, None)
        os.environ["SILVER_BULLET_RUNTIME"] = " Codex "
        self.assertEqual(impl.detect_host(), "codex")
        os.environ["SILVER_BULLET_RUNTIME"] = "cursor"  # not a host any more
        self.assertEqual(impl.detect_host(), "claude")
        del os.environ["SILVER_BULLET_RUNTIME"]
        self.assertEqual(impl.detect_host(), "claude")
        os.environ["CODEX_THREAD_ID"] = "t"
        self.assertEqual(impl.detect_host(), "codex")
        del os.environ["CODEX_THREAD_ID"]
        os.environ["CLAUDE_PLUGIN_ROOT"] = "/home/u/.codex/plugins/x"
        self.assertEqual(impl.detect_host(), "codex")
        os.environ["CLAUDE_PLUGIN_ROOT"] = "/home/u/.claude/plugins/x"
        self.assertEqual(impl.detect_host(), "claude")

    def test_claude_default_ladder(self):
        out = impl.resolve_ladder("claude", self.root)
        self.assertEqual((out["host"], out["source"], out["enabled"], out["spawn_tool"]), ("claude", "default", True, "Agent"))
        self.assertEqual([f"{r['model']}:{r['effort']}" for r in out["rungs"]],
                         ["haiku:xhigh", "sonnet:high", "sonnet:xhigh", "opus:low", "opus:medium", "opus:high"])
        self.assertTrue(out["effort_applied"])
        self.assertNotIn("fable", json.dumps(out))
        self.assertEqual(impl.resolve_ladder("CLAUDE")["total_rungs"], 6)

    def test_custom_ladder_from_the_prompt_flag_and_config(self):
        out = impl.resolve_ladder("claude", self.root, "rungs: +opus:xhigh -haiku:xhigh")
        self.assertEqual((out["source"], out["total_rungs"], out["rungs"][-1]["effort"]), ("config", 6, "xhigh"))
        (self.root / ".silver-bullet.json").write_text(json.dumps({"review_fix_ladder": {"rungs": ["sonnet:high"]}}))
        self.assertEqual(impl.resolve_ladder("claude", self.root)["total_rungs"], 1)

    def test_codex_is_disabled_with_documented_defaults(self):
        out = impl.resolve_ladder("codex")
        self.assertFalse(out["enabled"])
        self.assertEqual(out["rungs"], [])
        self.assertIn("not yet verified on Codex", out["message"])
        self.assertEqual(out["documented_defaults"]["terra"], ["high", "xhigh"])
        self.assertEqual(out["documented_defaults"]["excluded"], ["astra"])

    def test_cli_resolution_output(self):
        code, out, _ = self.cli()
        self.assertEqual(code, 0)
        self.assertIn("host: claude\nsource: default\ntotal_rungs: 6\nrungs:\n  1. haiku / xhigh", out)
        code, out, _ = self.jcli("--json", "--rungs", "opus:high")
        self.assertEqual((code, out["total_rungs"]), (0, 1))
        code, out, _ = self.jcli("--host", "codex")
        self.assertEqual((code, out["enabled"]), (0, False))
        code, _, err = self.cli("--rungs", "gpt:high")
        self.assertEqual((code, "bad rung" in err), (3, True))
        code, _, err = self.cli("--rungs", "fable:high")
        self.assertIn("Fable is never used", err)


class EntrypointTest(unittest.TestCase):
    def test_main_guard_and_sys_path_bootstrap(self):
        import runpy
        lib = str(Path(impl.__file__).resolve().parent / "lib")
        trimmed = [p for p in sys.path if p != lib]
        out = io.StringIO()
        with mock.patch.object(sys, "path", trimmed), mock.patch.object(sys, "argv", ["x", "--launcher-steps"]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as caught:
            runpy.run_path(impl.__file__, run_name="__main__")
        self.assertEqual(caught.exception.code, 0)
        self.assertIn(lib, trimmed)
        self.assertIn("steps", json.loads(out.getvalue()))


class QuotaCliTest(CliCase):
    def test_classify_contract_via_blob_file_and_host(self):
        code, out, _ = self.jcli("--classify-quota-window", "--subscription-output", "Error 429 rate limit", "--quota-host", "claude")
        self.assertEqual(code, 0)
        for key in ("quota_class", "should_schedule", "should_short_retry", "reset_seconds"):
            self.assertIn(key, out)
        self.assertEqual(out["quota_class"], "five_hour")
        blob = self.tmp / "blob.txt"
        blob.write_text("weekly limit reached")
        code, out, _ = self.jcli("--classify-quota-window", "--subscription-output-file", str(blob), "--model", "claude/opus",
                                 "--quota-now", "2030-01-01T00:00:00Z")
        self.assertEqual(out["quota_class"], "weekly")
        code, out, _ = self.jcli("--classify-quota-window", "--subscription-output", "429 too many")
        self.assertEqual((out["quota_class"], out["should_short_retry"]), ("unknown", True))

    def test_scheduler_flags_are_gone(self):
        for flag in ("--schedule-quota-retry", "--activate-quota-retry", "--quota-retry-due", "--quota-retry-wake",
                     "--mark-ladder-status", "--record-rung-review-outcome", "--decide-launch", "--default-host-route"):
            code, _, err = self.cli(flag, "x") if flag in ("--mark-ladder-status", "--record-rung-review-outcome") else self.cli(flag)
            self.assertEqual(code, 2, flag)


class LifecycleCliTest(CliCase):
    def test_full_rung_through_the_cli(self):
        charter = self.write_charter()
        code, out, _ = self.jcli("--start", "--charter-file", str(charter), "--run-id", "demo", "--rungs", "sonnet:high")
        self.assertEqual((code, out["run_id"]), (0, "demo"))
        run = ".planning/rfl-demo"
        run_dir = self.root / run
        self.run_dir = run_dir
        code, _, err = self.cli("--issue-ticket", "review", "--run-dir", str(run_dir))
        self.assertEqual((code, "Policy E" in err), (3, True))
        self.assertEqual(self.jcli("--approve", "--run-dir", str(run_dir))[0], 0)
        for cycle in range(2):
            code, out, _ = self.jcli("--issue-ticket", "review", "--run-dir", str(run_dir))
            self.assertEqual(code, 0)
            self.reply(out["ticket"], {"verdict": "CLEAN", "findings": []})
            self.write_policy(CLEAN_POLICY)
            self.assertEqual(self.jcli("--complete-triage", "--run-dir", str(run_dir))[0], 0)
            code, out, _ = self.jcli("--issue-ticket", "verify_1", "--run-dir", str(run_dir))
            self.reply(out["ticket"], {"verdict": "VERIFY_PASS", "checks": [], "gaps": []})
            code, out, _ = self.jcli("--run-signals", "--run-dir", str(run_dir))
            self.assertEqual(code, 0)
        code, out, _ = self.jcli("--issue-ticket", "verify_2", "--run-dir", str(run_dir))
        self.reply(out["ticket"], {"verdict": "VERIFY_PASS", "checks": [], "gaps": []})
        self.assertEqual(self.jcli("--run-signals", "--run-dir", str(run_dir))[0], 0)
        code, out, _ = self.jcli("--status", "--run-dir", str(run_dir))
        self.assertEqual((out["phase"], out["status"]), ("advance", "active"))
        code, out, _ = self.jcli("--advance", "--run-dir", str(run_dir))
        self.assertEqual((code, out["status"]), (0, "completed"))

    def test_failed_signals_exit_one_and_apply_loop_commands(self):
        self.start(signals=[{"id": "no", "argv": ["false"]}])
        self.review([{"id": "F1", "severity": "HIGH", "file": "src/a.py", "line": 1, "summary": "s"}])
        from rflhelp import accept_policy
        self.write_policy(accept_policy())
        self.assertEqual(self.jcli("--complete-triage", "--run-dir", str(self.run_dir))[0], 0)
        code, _, err = self.cli("--record-apply", "--run-dir", str(self.run_dir))
        self.assertEqual(code, 3)
        (self.root / "src" / "a.py").write_text("x = 2\n")
        self.assertEqual(self.jcli("--record-apply", "--run-dir", str(self.run_dir))[0], 0)
        issued = self.ticket("verify_1")
        self.reply(issued["ticket"], {"verdict": "VERIFY_PASS", "checks": [{"finding_id": "F1", "status": "resolved", "evidence": "e"}], "gaps": []})
        code, out, _ = self.jcli("--run-signals", "--run-dir", str(self.run_dir))
        self.assertEqual((code, out["ok"]), (1, False))
        self.assertEqual(self.status()["phase"], "apply")

    def test_cancel_resume_abort_cleanup_and_errors(self):
        self.start()
        self.ticket("review")
        code, out, _ = self.jcli("--cancel-ticket", "--run-dir", str(self.run_dir))
        self.assertEqual((code, out["outcome"]), (0, "cannot_launch"))
        native.clear_live()
        code, out, _ = self.jcli("--resume", "demo")
        self.assertEqual((code, out["run_id"]), (0, "demo"))
        code, out, err = self.jcli("--abort", "demo")
        self.assertEqual((code, "RFL ABORT demo" in err), (3, True))
        native.write_abort_token(self.root, "demo")
        self.assertEqual(self.jcli("--abort", "demo")[1]["status"], "aborted")
        code, out, _ = self.jcli("--cleanup-legacy-timers", "--dry-run")
        self.assertEqual((code, out["dry_run"], out["found"]), (0, True, []))
        code, _, err = self.cli("--abort", "ghost")
        self.assertEqual(code, 4)  # no signed status: treated as tamper
        code, _, _ = self.cli("--status")
        self.assertEqual(code, 2)  # --run-dir required
        code, _, err = self.cli("--start")
        self.assertEqual(code, 3)
        code, _, err = self.cli("--table-json-file", str(self.tmp / "x.json"), "--issue-table")
        self.assertEqual(code, 3)  # an unreadable input file is a refusal, not a traceback

    def test_hook_entry_point_reads_stdin(self):
        self.start()
        code, out, _ = self.jcli("--hook", stdin=json.dumps({"hook_event_name": "Stop"}))
        self.assertEqual(code, 0)
        self.assertEqual(out["output"]["decision"], "block")
        code, out, _ = self.jcli("--hook", stdin="not json")
        self.assertEqual(out, {"output": None, "audit": None})


class PolicyCliTest(CliCase):
    def write_file(self, name, text):
        path = self.tmp / name
        path.write_text(text)
        return path

    def test_steps_launch_policy_and_skip_artifact(self):
        self.assertIsInstance(self.jcli("--launcher-steps")[1]["steps"], list)
        code, out, _ = self.jcli("--launch-policy", "--outcome", "timeout", "--attempts", "2")
        self.assertEqual((code, out["action"]), (0, "skip"))
        self.assertEqual(self.cli("--launch-policy")[0], 2)
        code, out, _ = self.jcli("--skip-artifact", "--rung-id", "3", "--outcome", "timeout", "--attempts", "2", "--rung-dir", str(self.tmp / "r"))
        self.assertTrue((self.tmp / "r" / "SKIPPED.md").is_file())
        self.assertEqual(out["skipped_md_path"], str(self.tmp / "r" / "SKIPPED.md"))
        code, out, _ = self.jcli("--skip-artifact", "--rung-id", "3", "--outcome", "cannot_launch")
        self.assertNotIn("skipped_md_path", out)
        self.assertEqual(self.cli("--skip-artifact", "--outcome", "timeout")[0], 2)

    def test_tables(self):
        rows = '[{"id":"A","severity":"high","title":"t"}]'
        for flag, needle in (("--issue-table", "### HIGH"), ("--triage-table", "Triage"), ("--resolved-table", "Resolved"), ("--ladder-matrix", "Ladder-complete matrix")):
            code, out, _ = self.cli(flag, "--table-json", rows if flag != "--ladder-matrix" else "[]")
            self.assertEqual(code, 0, flag)
            self.assertIn(needle, out, flag)
        code, _, err = self.cli("--issue-table", "--table-json", "{}")
        self.assertEqual((code, "must be an array" in err), (2, True))
        code, _, err = self.cli("--issue-table")
        self.assertEqual(code, 3)

    def test_issue_ledger_and_brief(self):
        rows = '[{"id":"A","severity":"high","decision":"accept","summary":"s","sha":"abc"}]'
        code, out, _ = self.cli("--issue-ledger", "--table-json", rows)
        self.assertTrue(out.startswith("## Issue ledger"))
        self.assertIn("| A | HIGH | ACCEPT |", out)
        code, out, _ = self.cli("--write-review-brief", "--table-json", '{"rows": ' + rows + "}")
        self.assertTrue(out.startswith("## Hop review"))
        run = self.tmp / "run"
        run.mkdir()
        (run / "ISSUE-LEDGER.md").write_text("| ID | Severity | Status | Summary |\n| Z | low | accept | from md |\n")
        self.assertIn("| Z | LOW | ACCEPT |", self.cli("--issue-ledger", "--run-dir", str(run))[1])
        self.assertIn("| A |", self.cli("--issue-ledger", "--table-json-file", str(self.write_file("rows.json", rows)))[1])
        code, _, err = self.cli("--issue-ledger", "--table-json", '"x"')
        self.assertEqual((code, "array or" in err), (2, True))
        code, _, err = self.cli("--issue-ledger", "--table-json", '{"rows": 3}')
        self.assertEqual(code, 2)
        code, _, err = self.cli("--issue-ledger", "--table-json", "{bad")
        self.assertEqual((code, err.startswith("ERROR:")), (3, True))
        code, _, err = self.cli("--write-review-brief")
        self.assertEqual((code, "requires --run-dir or --table-json" in err), (2, True))

    def test_write_and_assert_policy_c_and_advance(self):
        rung = self.tmp / "rung-01-x"
        body = json.dumps(CLEAN_POLICY)
        code, out, _ = self.cli("--write-policy-c", "--rung-dir", str(rung), "--table-json", body, "--current-phase", "triage")
        self.assertEqual(code, 0)
        self.assertIn("Sonnet High", out)
        code, out, _ = self.jcli("--assert-policy-c", "--rung-dir", str(rung))
        self.assertEqual((code, out["ok"]), (0, True))
        (rung / "POLICY-C.json").unlink()
        code, out, _ = self.jcli("--assert-policy-c", "--rung-dir", str(rung))
        self.assertEqual((code, out["ok"]), (2, False))
        self.assertEqual(self.cli("--assert-policy-c")[0], 2)
        self.assertEqual(self.cli("--write-policy-c")[0], 2)
        code, _, err = self.cli("--write-policy-c", "--rung-dir", str(rung), "--table-json", "[1]")
        self.assertEqual((code, "must be an object" in err), (2, True))
        code, _, err = self.cli("--write-policy-c", "--rung-dir", str(rung), "--table-json", "{}")
        self.assertEqual((code, "ERROR:" in err), (2, True))
        code, out, _ = self.jcli("--assert-rfl-advance", "--project-root", str(self.root))
        self.assertEqual((code, out["ok"]), (0, True))
        code, out, _ = self.jcli("--assert-consecutive-clean", "--run-dir", str(self.tmp))
        self.assertIn("next_action", out)
        code, out, _ = self.jcli("--assert-consecutive-clean", "--next-action", "stop", "--run-dir", str(self.tmp))
        self.assertEqual(out["next_action"], "stop")


if __name__ == "__main__":
    unittest.main()
