"""Unit tests for scripts/lib/rfl_launcher_policy.py (frozen clock, mocked Policy C)."""
from __future__ import annotations

import contextlib
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

load_module("scripts/lib/rfl_policy_c.py", "rfl_policy_c")  # registers the module the CLI imports lazily
lp = load_module("scripts/lib/rfl_launcher_policy.py")


class ModelAndHostTest(unittest.TestCase):
    def test_model_family(self):
        cases = {
            "": "other", None: "other", "  ": "other",
            "GPT-5.5": "gpt", "chatgpt-4o": "gpt", "sb-gpt-x": "gpt",
            "opus-5": "claude", "claude-sonnet": "claude", "sb-opus-5": "claude",
            "sb-claude-x": "claude",
            "gemini-3": "gemini", "cursor-grok-4.6": "grok", "grok-4.5": "grok",
            "composer-2.5": "composer", "my-composer": "composer",
            "llama": "other",
        }
        for model, family in cases.items():
            self.assertEqual(lp.model_family(model), family, model)

    def test_normalize_user_agent(self):
        self.assertIsNone(lp.normalize_user_agent(None))
        self.assertIsNone(lp.normalize_user_agent("   "))
        self.assertEqual(lp.normalize_user_agent(" /SB:Agent-Cursor "), "cursor")
        self.assertEqual(lp.normalize_user_agent("Gemini"), "gemini-cli")
        self.assertEqual(lp.normalize_user_agent("MyAgent"), "myagent")

    def route(self, model, **kw):
        return lp.default_agent_host_route(model, **kw)

    def test_user_override_wins(self):
        r = self.route("gpt-5", user_agent="pi")
        self.assertEqual((r["host"], r["source"], r["user_override"]), ("pi", "user_override", True))
        self.assertEqual(r["skill"], "silver-agent-pi")
        r = self.route("gpt-5", user_agent="Custom")
        self.assertEqual((r["host"], r["skill"], r["route"], r["invoke"]),
                         ("custom", "custom", "custom", ""))
        self.assertEqual(self.route("gpt-5", user_agent="  ")["host"], "codex")

    def test_family_defaults(self):
        for model, host in (("grok-4.6", "cursor"), ("composer-2.5", "cursor"),
                            ("gpt-5", "codex"), ("opus-5", "claude")):
            r = self.route(model)
            self.assertEqual((r["host"], r["source"], r["user_override"]), (host, "default", False))
            self.assertTrue(r["preserves_host_mode"])
        r = self.route("gpt-5")
        self.assertEqual((r["family"], r["model"], r["route"], r["invoke"]),
                         ("gpt", "gpt-5", "/sb:agent-codex", "scripts/agent-codex/invoke.sh"))

    def test_gemini_cascade(self):
        for avail, host in ((None, "gemini-cli"), (["pi", "opencode"], "pi"),
                            (["opencode", "cursor"], "opencode"), (["cursor"], "cursor"),
                            (["codex"], "cursor"), ([], "cursor")):
            r = self.route("gemini-3", available_hosts=avail)
            self.assertEqual((r["host"], r["source"]), (host, "gemini_cascade"), avail)

    def test_other_models(self):
        r = self.route("llama")
        self.assertEqual((r["host"], r["source"]), ("pi", "other_default"))
        r = self.route("llama", available_hosts=iter(["codex", "opencode"]))
        self.assertEqual((r["host"], r["source"]), ("opencode", "other_default"))
        r = self.route("llama", available_hosts=["codex", "cursor"])
        self.assertEqual((r["host"], r["source"]), ("codex", "other_fallback"))
        r = self.route("llama", available_hosts=[])
        self.assertEqual((r["host"], r["source"]), ("opencode", "other_fallback"))

    def test_attach_default_host_route(self):
        payload = {"keep": 1}
        out = lp.attach_default_host_route(payload, "opus-5")
        self.assertIs(out, payload)
        self.assertEqual(payload, {"keep": 1, "default_agent_host": "claude",
                                   "default_agent_skill": "silver-agent-claude",
                                   "default_agent_route": "/sb:agent-claude",
                                   "preserves_host_mode": True})


class LaunchActionTest(unittest.TestCase):
    def act(self, **kw):
        args = dict(attempts=1, outcome="timeout")
        args.update(kw)
        return lp.next_launch_action(**args)

    def test_validation(self):
        with self.assertRaisesRegex(ValueError, "attempts must be >= 1"):
            self.act(attempts=0)
        with self.assertRaisesRegex(ValueError, "unsupported phase"):
            self.act(phase="later")
        with self.assertRaisesRegex(ValueError, "unsupported outcome"):
            self.act(outcome="weird")
        with self.assertRaisesRegex(ValueError, "unsupported outcome"):
            self.act(outcome=None)

    def test_success(self):
        out = self.act(outcome=" SUCCESS ", attempts=3)
        self.assertEqual((out["action"], out["post_ladder_retry_done"], out["attempts"]),
                         ("continue", False, 3))
        out = self.act(outcome="success", phase="post_ladder")
        self.assertEqual((out["action"], out["post_ladder_retry_done"]), ("recovered", True))
        self.assertFalse(out["skipped"] or out["retry"])

    def test_first_failure_retries_immediately(self):
        for outcome in ("cannot_launch", "TIMEOUT"):
            out = self.act(outcome=outcome, host="opencode")
            self.assertEqual((out["action"], out["retry"], out["retry_kind"], out["skipped"]),
                             ("retry_immediate", True, "immediate", False))

    def test_exact_payloads(self):
        base = {"outcome": "timeout", "phase": "rung", "attempts": 1}
        self.assertEqual(self.act(), {
            **base, "action": "retry_immediate", "skipped": False, "retry": True,
            "retry_kind": "immediate", "post_ladder_retry_pending": False,
            "post_ladder_retry_done": False})
        self.assertEqual(self.act(attempts=2, host="x"), {
            **base, "attempts": 2, "action": "skip", "skipped": True, "retry": False,
            "retry_kind": None, "post_ladder_retry_pending": True,
            "post_ladder_retry_done": False})
        sub = self.act(attempts=2, host="pi")
        self.assertEqual((sub["post_ladder_retry_pending"], sub["post_ladder_retry_done"],
                          sub["retry_kind"]), (False, False, None))
        self.assertEqual(self.act(phase="post_ladder", attempts=2), {
            **base, "attempts": 2, "phase": "post_ladder", "action": "remain_skipped",
            "skipped": True, "retry": False, "retry_kind": None,
            "post_ladder_retry_pending": False, "post_ladder_retry_done": True})
        ok = self.act(outcome="success")
        self.assertEqual((ok["skipped"], ok["retry"], ok["retry_kind"],
                          ok["post_ladder_retry_pending"], ok["post_ladder_retry_done"]),
                         (False, False, None, False, False))

    def test_second_failure_substitutes_on_opencode_and_pi(self):
        for host in ("opencode", "pi", "Agent-Pi", "/sb:agent-opencode"):
            out = self.act(attempts=2, host=host)
            self.assertEqual(out["action"], "substitute_grok", host)
            self.assertEqual((out["substitute_host"], out["substitute_model"],
                              out["substitute_route"], out["substitute_skill"]),
                             ("cursor", "cursor-grok-4.6-high", "/sb:agent-cursor",
                              "silver-agent-cursor"))
            self.assertEqual(out["failed_host"], lp.normalize_user_agent(host))
            self.assertFalse(out["skipped"] or out["retry"])

    def test_second_failure_skips_elsewhere(self):
        for host in (None, "cursor", "claude", ""):
            out = self.act(attempts=2, host=host)
            self.assertEqual((out["action"], out["skipped"], out["post_ladder_retry_pending"]),
                             ("skip", True, True), host)
        out = self.act(attempts=7, host="pi")
        self.assertEqual(out["action"], "substitute_grok")

    def test_post_ladder_failure_remains_skipped(self):
        out = self.act(phase="post_ladder", attempts=5, host="pi")
        self.assertEqual((out["action"], out["skipped"], out["post_ladder_retry_pending"],
                          out["post_ladder_retry_done"]), ("remain_skipped", True, False, True))

    def test_phase_defaults_when_blank(self):
        self.assertEqual(self.act(phase=None)["phase"], "rung")
        with self.assertRaisesRegex(ValueError, "unsupported phase"):
            self.act(phase="  ")


class SkipArtifactTest(unittest.TestCase):
    def artifact(self, **kw):
        args = dict(rung=3, event="", outcome="timeout", attempts=2)
        args.update(kw)
        fake = mock.Mock()
        fake.now.return_value.strftime.return_value = "2030-01-01T00:00:00Z"
        with mock.patch.object(lp, "datetime", fake):
            return lp.skip_retry_artifact(**args)

    def test_skip_payload(self):
        out = self.artifact(next_rung="4")
        self.assertEqual(out["event"], "skip")
        self.assertEqual(out["timestamp"], "2030-01-01T00:00:00Z")
        self.assertEqual(out["action"], "skip")
        self.assertEqual(out["skipped_md"], (
            "# SKIPPED — rung 3\n\n- reason: `timeout`\n- event: `skip`\n- attempts: 2\n"
            "- phase: `rung`\n- timestamp: 2030-01-01T00:00:00Z\n- next_rung: 4\n"
            "- post_ladder_retry_pending: True\n"))

    def test_next_rung_zero_is_shown_and_none_is_na(self):
        self.assertIn("- next_rung: 0\n", self.artifact(next_rung=0)["skipped_md"])
        self.assertIn("- next_rung: n/a\n", self.artifact()["skipped_md"])

    def test_substitute_payload_and_explicit_event(self):
        out = self.artifact(host="pi", event="custom", next_rung=None)
        self.assertEqual(out["event"], "custom")
        self.assertEqual(out["action"], "substitute_grok")
        self.assertTrue(out["skipped_md"].startswith("# SUBSTITUTE GROK — rung 3\n"))
        self.assertIn("- substitute_model: `cursor-grok-4.6-high`\n", out["skipped_md"])
        self.assertIn("- next_rung: n/a\n", out["skipped_md"])

    def test_invalid_outcome_raises(self):
        with self.assertRaises(ValueError):
            self.artifact(outcome="success-ish")


class RenderTest(unittest.TestCase):
    def test_normalize_severity(self):
        for raw, want in (("high", "HIGH"), ("Blockers", "HIGH"), ("medium", "MED"),
                          ("lows", "LOW"), ("nitpicks", "NIT"), ("", "LOW"), (None, "LOW"),
                          ("weird", "LOW"), ("  nit ", "NIT")):
            self.assertEqual(lp.normalize_severity(raw), want, raw)

    def test_issue_table(self):
        out = lp.render_issue_table([
            {"id": "A|1", "title": "t\nx", "severity": "blocker"},
            {"id": "B", "title": "nit title", "severity": "nits"},
            {"id": "C"},
            {"id": "D", "severity": None},
            {"id": "E", "severity": "weird"},
        ])
        self.assertTrue(out.startswith("## Reported issues (by severity)\n\n### HIGH\n\n"))
        self.assertTrue(out.endswith("|\n"))
        self.assertIn("### HIGH\n\n| ID | Title |\n|----|-------|\n| A\\|1 | t x |\n", out)
        self.assertIn("### MED\n\n| ID | Title |\n|----|-------|\n| — | **none** |\n", out)
        self.assertIn("### LOW\n\n| ID | Title |\n|----|-------|\n| C |  |\n| D |  |\n| E |  |\n", out)
        self.assertIn("### NIT\n\n| ID | Title |\n|----|-------|\n| B | nit title |\n", out)

    def test_issue_table_empty(self):
        out = lp.render_issue_table([])
        self.assertEqual(out.count("| — | **none** |"), 4)

    def test_triage_table(self):
        self.assertIn("| — | — | — | **none** |", lp.render_triage_table([]))
        out = lp.render_triage_table([
            {"id": "A", "severity": "medium", "decision": " accept ", "reason": "a|b"},
            {},
        ])
        lines = out.splitlines()
        self.assertEqual(lines[-2], "| A | MED | ACCEPT | a\\|b |")
        self.assertEqual(lines[-1], "|  | LOW |  |  |")
        self.assertTrue(out.endswith("|\n"))

    def test_resolved_table(self):
        self.assertIn("| — | — | — | — | **none** |", lp.render_resolved_table([]))
        out = lp.render_resolved_table([
            {"id": "A", "severity": "high", "title": "T", "decision": "accept", "resolved": True},
            {"id": "B", "decision": "reject", "resolved": False},
            {"id": "C", "resolved": "n/a"},
            {"id": "D"},
        ])
        lines = out.splitlines()
        self.assertEqual(lines[-4:], [
            "| A | HIGH | T | ACCEPT | yes |",
            "| B | LOW |  | REJECT | no |",
            "| C | LOW |  |  | n/a |",
            "| D | LOW |  |  |  |",
        ])

    def test_ladder_matrix_totals_and_footnotes(self):
        out = lp.render_ladder_complete_matrix([
            {"rung": 1, "reviewer": "opus", "high": 1, "med": "2", "low": None, "nit": 3,
             "accepted": 4, "clean": True},
            {"rung": "2|b", "reviewer": "gpt", "reported": 9, "id_collision": True,
             "skipped_then_retried": True},
            {"rung": 3, "reported": 0, "high": 5},
        ])
        lines = out.splitlines()
        self.assertIn("| 1 | opus | 1 | 2 | 0 | 3 | 6 | 4 |", lines)
        self.assertIn("| 2\\|b | gpt | 0 | 0 | 0 | 0 | 9 | 0 |", lines)
        self.assertIn("| 3 |  | 5 | 0 | 0 | 0 | 0 | 0 |", lines)  # explicit reported=0 kept
        self.assertIn("| TOTAL | — | 6 | 2 | 0 | 3 | 15 | 4 |", lines)
        self.assertIn("Footnotes:", lines)
        self.assertIn("- Rung 1: CLEAN", lines)
        self.assertIn("- Rung 2\\|b: ID collision; skipped-then-retried", lines)
        self.assertNotIn("- Rung 3", "\n".join(lines))
        self.assertTrue(out.endswith("\n"))

    def test_ladder_matrix_empty(self):
        out = lp.render_ladder_complete_matrix([])
        self.assertIn("| TOTAL | — | 0 | 0 | 0 | 0 | 0 | 0 |", out)
        self.assertIn("Footnotes: none.", out)
        self.assertNotIn("Footnotes:\n", out)

    def test_ladder_matrix_non_numeric_count_raises(self):
        with self.assertRaises(ValueError):
            lp.render_ladder_complete_matrix([{"high": "many"}])

    def test_mandatory_steps_is_a_copy(self):
        steps = lp.launcher_mandatory_steps()
        self.assertEqual(steps, list(lp.LAUNCHER_MANDATORY_STEPS))
        steps.append("x")
        self.assertNotIn("x", lp.launcher_mandatory_steps())


class HelpersTest(unittest.TestCase):
    def test_parse_available_hosts(self):
        self.assertIsNone(lp._parse_available_hosts(None))
        self.assertIsNone(lp._parse_available_hosts(""))
        self.assertIsNone(lp._parse_available_hosts("  "))
        self.assertEqual(lp._parse_available_hosts("pi, cursor,,"), ("pi", "cursor"))
        self.assertEqual(lp._parse_available_hosts(","), ())

    def test_load_json_arg(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "a.json"
            f.write_text('{"k": 1}')
            self.assertEqual(lp._load_json_arg("[2]", f), {"k": 1})  # file wins
            self.assertEqual(lp._load_json_arg("[2]", None), [2])
            with self.assertRaisesRegex(ValueError, "JSON payload required"):
                lp._load_json_arg(None, None)
            with self.assertRaisesRegex(ValueError, "JSON payload required"):
                lp._load_json_arg("", None)
            with self.assertRaises(ValueError):
                lp._load_json_arg("{bad", None)
            with self.assertRaises(ValueError):
                lp._load_json_arg(None, Path(tmp) / "missing.json")


class CliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", ["rfl_launcher_policy.py", *argv]), \
             contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = lp.main()
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def write(self, name, text):
        path = self.tmp / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_no_flag_is_parser_error(self):
        code, out, err = self.cli()
        self.assertEqual(code, 2)
        self.assertIn("one of --default-host-route", err)

    def test_launcher_steps(self):
        code, out, _ = self.cli("--launcher-steps")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"steps": list(lp.LAUNCHER_MANDATORY_STEPS)})

    def test_default_host_route(self):
        code, out, _ = self.cli("--default-host-route", "--model", "grok-4.6")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["host"], "cursor")
        code, out, _ = self.cli("--default-host-route", "--model", "llama",
                                "--available-hosts", "codex,cursor", "--user-agent", "gemini")
        self.assertEqual(json.loads(out)["host"], "gemini-cli")
        code, out, _ = self.cli("--default-host-route", "--model", "llama",
                                "--available-hosts", "codex,cursor")
        self.assertEqual(json.loads(out)["host"], "codex")
        code, _, err = self.cli("--default-host-route")
        self.assertEqual((code, "requires --model" in err), (2, True))

    def test_launch_policy(self):
        code, out, _ = self.cli("--launch-policy", "--outcome", "timeout")
        self.assertEqual((code, json.loads(out)["action"]), (0, "retry_immediate"))
        code, out, _ = self.cli("--launch-policy", "--outcome", "cannot_launch",
                                "--attempts", "2", "--host", "pi")
        self.assertEqual(json.loads(out)["action"], "substitute_grok")
        code, out, _ = self.cli("--launch-policy", "--outcome", "cannot_launch",
                                "--attempts", "2", "--user-agent", "opencode")
        self.assertEqual(json.loads(out)["failed_host"], "opencode")
        code, out, _ = self.cli("--launch-policy", "--outcome", "timeout", "--attempts", "3",
                                "--policy-phase", "post_ladder")
        self.assertEqual(json.loads(out)["action"], "remain_skipped")
        code, _, err = self.cli("--launch-policy")
        self.assertEqual((code, "requires --outcome" in err), (2, True))

    def test_host_flag_beats_user_agent_for_launch_and_skip(self):
        for flag in ("--launch-policy", "--skip-artifact"):
            base = [flag, "--outcome", "timeout", "--attempts", "2"]
            if flag == "--skip-artifact":
                base += ["--rung-id", "r1"]
            for argv, action in ((["--host", "pi"], "substitute_grok"),
                                 (["--user-agent", "pi"], "substitute_grok"),
                                 (["--host", "cursor", "--user-agent", "pi"], "skip"),
                                 (["--host", "pi", "--user-agent", "cursor"], "substitute_grok")):
                code, out, _ = self.cli(*base, *argv)
                self.assertEqual(json.loads(out)["action"], action, (flag, argv))

    def test_skip_artifact(self):
        rung_dir = self.tmp / "rung" / "1"
        code, out, _ = self.cli("--skip-artifact", "--rung-id", "r1", "--outcome", "timeout",
                                "--attempts", "2", "--next-rung", "r2", "--rung-dir", str(rung_dir))
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertEqual((payload["rung"], payload["next_rung"], payload["action"]),
                         ("r1", "r2", "skip"))
        self.assertEqual(payload["skipped_md_path"], str(rung_dir / "SKIPPED.md"))
        self.assertEqual((rung_dir / "SKIPPED.md").read_text(), payload["skipped_md"])
        code, out, _ = self.cli("--skip-artifact", "--rung-id", "r1", "--outcome", "timeout")
        self.assertNotIn("skipped_md_path", json.loads(out))
        for argv in (["--skip-artifact", "--outcome", "timeout"],
                     ["--skip-artifact", "--rung-id", "r1"]):
            code, _, err = self.cli(*argv)
            self.assertEqual((code, "requires --rung-id and --outcome" in err), (2, True))

    def test_tables(self):
        cases = {
            "--issue-table": ('[{"id":"A","title":"T","severity":"high"}]', "## Reported issues"),
            "--triage-table": ('[{"id":"A","decision":"accept"}]', "## Triage"),
            "--resolved-table": ('[{"id":"A","resolved":true}]', "## Resolved"),
            "--ladder-matrix": ('[{"rung":1}]', "## Ladder-complete matrix"),
        }
        for flag, (payload, heading) in cases.items():
            code, out, _ = self.cli(flag, "--table-json", payload)
            self.assertEqual(code, 0, flag)
            self.assertTrue(out.startswith(heading), flag)
        f = self.write("t.json", '[{"id":"A"}]')
        code, out, _ = self.cli("--issue-table", "--table-json-file", str(f))
        self.assertEqual(code, 0)
        self.assertIn("| A |", out)

    def test_table_errors(self):
        code, _, err = self.cli("--issue-table")
        self.assertEqual((code, "JSON payload required" in err), (2, True))
        code, _, err = self.cli("--issue-table", "--table-json", "{bad")
        self.assertEqual(code, 2)
        self.assertTrue(err.startswith("ERROR:"))
        code, _, err = self.cli("--issue-table", "--table-json", '{"a":1}')
        self.assertEqual((code, "must be an array" in err), (2, True))
        code, _, err = self.cli("--issue-table", "--table-json-file", str(self.tmp / "nope.json"))
        self.assertEqual(code, 2)
        self.assertTrue(err.startswith("ERROR:"))

    def test_issue_ledger_and_brief(self):
        rows = '[{"id":"A","severity":"high","decision":"accept","summary":"s","sha":"abc"}]'
        code, out, _ = self.cli("--issue-ledger", "--table-json", rows)
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith("## Issue ledger"))
        self.assertIn("| A | HIGH | ACCEPT |", out)
        code, out, _ = self.cli("--write-review-brief", "--table-json", '{"rows": ' + rows + '}')
        self.assertTrue(out.startswith("## Hop review"))
        self.assertIn("| A | HIGH | ACCEPT |", out)
        run_dir = self.tmp / "run"
        run_dir.mkdir()
        (run_dir / "ISSUE-LEDGER.md").write_text(
            "| ID | Severity | Status | Summary |\n| Z | low | accept | from md |\n")
        code, out, _ = self.cli("--issue-ledger", "--run-dir", str(run_dir))
        self.assertIn("| Z | LOW | ACCEPT |", out)
        f = self.write("rows.json", rows)
        code, out, _ = self.cli("--issue-ledger", "--table-json-file", str(f))
        self.assertIn("| A |", out)

    def test_issue_ledger_errors(self):
        code, _, err = self.cli("--issue-ledger", "--table-json", '"x"')
        self.assertEqual((code, "array or" in err), (2, True))
        code, _, err = self.cli("--issue-ledger", "--table-json", '{"rows": 3}')
        self.assertEqual(code, 2)
        code, _, err = self.cli("--issue-ledger", "--table-json", "{bad")
        self.assertEqual((code, err.startswith("ERROR:")), (2, True))
        code, _, err = self.cli("--write-review-brief")
        self.assertEqual((code, "requires --run-dir or --table-json" in err), (2, True))

    def test_write_policy_c(self):
        with mock.patch.object(sys.modules["rfl_policy_c"], "write_policy_c",
                               return_value={"ok": True, "markdown": "MD\n", "errors": []}) as w:
            code, out, err = self.cli("--write-policy-c", "--rung-dir", str(self.tmp),
                                      "--table-json", '{"a": 1}', "--current-phase", "p1")
        self.assertEqual((code, out, err), (0, "MD\n", ""))
        w.assert_called_once_with(self.tmp, {"a": 1}, current_phase="p1")
        with mock.patch.object(sys.modules["rfl_policy_c"], "write_policy_c",
                               return_value={"ok": False, "markdown": "MD\n",
                                             "errors": ["e1", "e2"]}):
            code, out, err = self.cli("--write-policy-c", "--rung-dir", str(self.tmp),
                                      "--table-json", "{}")
        self.assertEqual((code, out, err), (2, "MD\n", "ERROR: e1; e2\n"))

    def test_write_policy_c_input_errors(self):
        code, _, err = self.cli("--write-policy-c", "--table-json", "{}")
        self.assertEqual((code, "requires --rung-dir" in err), (2, True))
        code, _, err = self.cli("--write-policy-c", "--rung-dir", str(self.tmp))
        self.assertEqual((code, "JSON payload required" in err), (2, True))
        code, _, err = self.cli("--write-policy-c", "--rung-dir", str(self.tmp),
                                "--table-json", "[1]")
        self.assertEqual((code, "must be an object" in err), (2, True))

    def test_assert_policy_c(self):
        ok = {"ok": True, "errors": [], "rung_dir": "/r", "extra": 1}
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_policy_c", return_value=ok) as a:
            code, out, _ = self.cli("--assert-policy-c", "--rung-dir", str(self.tmp))
        self.assertEqual((code, json.loads(out)), (0, {"ok": True, "errors": [], "rung_dir": "/r"}))
        a.assert_called_once_with(self.tmp, current_phase=None)
        bad = {"ok": False, "errors": ["x"], "rung_dir": "/r"}
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_policy_c", return_value=bad):
            code, out, _ = self.cli("--assert-policy-c", "--rung-dir", str(self.tmp))
        self.assertEqual((code, json.loads(out)["errors"]), (2, ["x"]))
        code, _, err = self.cli("--assert-policy-c")
        self.assertEqual((code, "requires --rung-dir" in err), (2, True))

    def test_record_rung_review_outcome(self):
        with mock.patch.object(sys.modules["rfl_policy_c"], "record_rung_review_outcome", return_value={"ok": 1}) as r:
            code, out, _ = self.cli("--record-rung-review-outcome", "clean",
                                    "--run-dir", str(self.tmp), "--rung-id", "r1")
        self.assertEqual((code, json.loads(out)), (0, {"ok": 1}))
        r.assert_called_once_with(self.tmp, "clean", rung_id="r1")
        with mock.patch.object(sys.modules["rfl_policy_c"], "record_rung_review_outcome", side_effect=ValueError("bad")):
            code, _, err = self.cli("--record-rung-review-outcome", "x", "--run-dir", str(self.tmp))
        self.assertEqual((code, err), (2, "ERROR: bad\n"))
        code, _, err = self.cli("--record-rung-review-outcome", "clean")
        self.assertEqual((code, "requires --run-dir" in err), (2, True))

    def test_assert_rfl_advance_and_consecutive_clean(self):
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_rfl_advance", return_value={"ok": True}) as a:
            code, out, _ = self.cli("--assert-rfl-advance", "--run-dir", str(self.tmp),
                                    "--next-action", "verify_1", "--prompt", "p",
                                    "--project-root", str(self.tmp), "--rung-dir", str(self.tmp),
                                    "--current-phase", "ph")
        self.assertEqual((code, json.loads(out)), (0, {"ok": True}))
        a.assert_called_once_with(self.tmp, rung_dir=self.tmp, project_root=self.tmp,
                                  next_action="verify_1", current_phase="ph", prompt="p")
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_rfl_advance", return_value={"ok": False}) as a:
            code, _, _ = self.cli("--assert-consecutive-clean", "--run-dir", str(self.tmp))
        self.assertEqual(code, 2)
        self.assertEqual(a.call_args.kwargs["next_action"], "next_rung_review")
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_rfl_advance", return_value={"ok": True}) as a:
            self.cli("--assert-consecutive-clean", "--next-action", "stop")
        self.assertEqual(a.call_args.kwargs["next_action"], "stop")
        self.assertIsNone(a.call_args.args[0])
        with mock.patch.object(sys.modules["rfl_policy_c"], "assert_rfl_advance", return_value={"ok": True}) as a:
            self.cli("--assert-rfl-advance", "--next-action", "")
        self.assertEqual(a.call_args.kwargs["next_action"], "task")

    def test_dispatch_returns_none_without_policy_flag(self):
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument("--model")
        lp.add_policy_arguments(parser)
        self.assertIsNone(lp.dispatch_policy_cli(parser.parse_args([])))
        # table flags absent but a table payload alone does not trigger anything
        self.assertIsNone(lp.dispatch_policy_cli(parser.parse_args(["--table-json", "[]"])))

    def test_dispatch_with_bare_namespace_uses_getattr_defaults(self):
        import argparse
        ns = argparse.Namespace(
            default_host_route=False, launch_policy=False, skip_artifact=False,
            issue_table=False, triage_table=False, resolved_table=False, ladder_matrix=False,
            launcher_steps=False, table_json=None, table_json_file=None)
        self.assertIsNone(lp.dispatch_policy_cli(ns))
        ns.issue_table = True
        ns.table_json = "[]"
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(lp.dispatch_policy_cli(ns), 0)
        self.assertIn("### HIGH", out.getvalue())

    def test_dunder_main(self):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["x", "--launcher-steps"]), \
             contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts/lib/rfl_launcher_policy.py"),
                               run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn("policy_c_artifact", out.getvalue())


if __name__ == "__main__":
    unittest.main()
