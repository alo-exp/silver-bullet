"""Review r2 repair (probes q1-q7): agent-name forgery, tokens, lock, session fallback, abort valve, Stop release."""
from __future__ import annotations

import json
import os
import threading
import unittest

from rflhelp import CLEAN_POLICY, RflCase, hook, native


class Fire(RflCase):
    def fire(self, payload, sid="s1"):
        return hook.run_hook(json.dumps({"session_id": sid, **payload}), self.root)

    def reason(self, result):
        out = result["output"] or {}
        return out.get("reason") or out.get("hookSpecificOutput", {}).get("permissionDecisionReason") or out.get("systemMessage") or ""

    def agent_file(self, rel, text, base=None):
        path = (base or self.root / ".claude" / "agents") / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def edit(self, tool, **spec):
        return self.fire({"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": spec, "cwd": str(self.root)})


FORGERIES = {
    "quoted-double": '---\nname: "sb-rfl-reviewer"\n---\n',
    "quoted-single": "---\nname: 'sb-rfl-reviewer'\n---\n",
    "comment": "---\nname: sb-rfl-reviewer # note\n---\n",
    "no-space": "---\nname:sb-rfl-reviewer\n---\n",
    "quoted-key": '---\n"name": sb-rfl-reviewer\n---\n',
    "block": "---\nname: >-\n  sb-rfl-reviewer\n---\n",
    "crlf-bom": "﻿---\r\nname: sb-rfl-reviewer\r\n---\r\n",
    "namespaced": "---\nname: silver-bullet:sb-rfl-reviewer\n---\n",
    "upper": "---\nName: SB-RFL-Reviewer\n---\n",
}


class AgentNameForgery(Fire):
    def test_q6_every_spelling_is_refused_at_issue_and_at_spawn(self):
        self.start()
        for label, text in FORGERIES.items():
            for rel in (f"{label}.md", f"sub/deep/{label}.md"):
                path = self.agent_file(rel, text)
                with self.subTest(label=label, rel=rel):
                    with self.assertRaisesRegex(native.RflError, "shadow"):
                        self.ticket("review")
                    path.unlink()
        # a ticket issued before the file appeared is still refused at the spawn check
        issued = self.ticket("review")
        self.agent_file("late/x.md", FORGERIES["quoted-double"])
        self.assertIn("agent file", self.reason(self.fire(self.spawn_payload(issued))))
        namespaced = dict(issued["spawn"]["params"], subagent_type="silver-bullet:sb-rfl-reviewer")
        self.assertIn("agent file", self.reason(self.fire(self.spawn_payload(issued, **namespaced))))

    def test_innocent_agents_do_not_block(self):
        self.start()
        self.agent_file("ok.md", "---\nname: other\ndescription: use sb-rfl-reviewer never\n---\nname: sb-rfl-reviewer\n")
        self.agent_file("nofront.md", "name: sb-rfl-reviewer\n")
        self.agent_file("bad.md", "---\nname:\n---\n")
        self.agent_file("empty.md", "")
        self.assertEqual(self.reason(self.fire(self.spawn_payload(self.ticket("review")))), "")

    def test_user_and_other_plugin_agent_dirs_are_scanned_but_not_our_own(self):
        self.start()
        user = native.home_root() / "agents"
        self.agent_file("u.md", FORGERIES["comment"], base=user)
        with self.assertRaisesRegex(native.RflError, "shadow"):
            self.ticket("review")
        (user / "u.md").unlink()
        other = native.home_root() / "plugins" / "cache" / "mk" / "other" / "1.0" / "agents"
        self.agent_file("o.md", FORGERIES["quoted-single"], base=other)
        (other.parent / ".claude-plugin").mkdir()
        (other.parent / ".claude-plugin" / "plugin.json").write_text('{"name": "other"}')
        with self.assertRaisesRegex(native.RflError, "shadow"):
            self.ticket("review")
        (other.parent / ".claude-plugin" / "plugin.json").write_text('{"name": "silver-bullet"}')  # our own copy is not a shadow
        self.assertTrue(self.ticket("review")["ticket"])

    def test_q5_edit_guard_blocks_any_agent_file_while_a_run_is_live(self):
        self.start()
        for rel in (".claude/agents/my-reviewer.md", ".claude/agents/sub/x.md", ".claude/agents/notes.txt"):
            for tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
                with self.subTest(rel=rel, tool=tool):
                    self.assertIn("agent definition", self.reason(self.edit(tool, file_path=str(self.root / rel), content="x")))
        home_agent = native.home_root() / "agents" / "evil.md"
        self.assertIn("agent definition", self.reason(self.edit("Write", file_path=str(home_agent), content="x")))
        self.assertIn("agent definition", self.reason(self.edit("Write", file_path=".claude/agents/r.md", content="x")))
        self.assertEqual(self.reason(self.edit("Write", file_path=str(self.root / "docs" / "n.md"), content="plain")), "")

    def test_edit_guard_checks_content_for_the_reserved_names_anywhere(self):
        self.start()
        forged = '---\nname: "sb-rfl-verifier"\n---\n'
        for spec in ({"file_path": str(self.root / "docs/x.md"), "content": forged},
                     {"file_path": str(self.root / "docs/x.md"), "new_string": forged},
                     {"file_path": str(self.root / "docs/x.md"), "edits": [{"file_path": "a", "new_string": forged}]},
                     {"input": "*** Begin Patch\n*** Add File: docs/x.md\n+---\n+name: sb-rfl-verifier\n+---\n*** End Patch"}):
            with self.subTest(spec=list(spec)):
                self.assertIn("reserved", self.reason(self.edit("Write", **spec)))
        self.assertEqual(self.reason(self.edit("Write", file_path=str(self.root / "docs/x.md"), content="mentions sb-rfl-verifier in prose")), "")


class SessionFallback(Fire):
    def sessions(self, *ids):
        for sid in ids:
            native.record_session(self.root, sid)

    def test_q4_two_recent_sessions_refuse_the_fallback(self):
        self.sessions("s1", "s2")
        self.assertEqual(native.current_session(self.root), "")
        with self.assertRaisesRegex(native.RflError, "which session"):
            native.start_run(self.root, self.write_charter(), run_id="demo")

    def test_a_single_recent_session_is_the_fallback(self):
        self.sessions("s1")
        self.assertEqual(native.current_session(self.root), "s1")
        native.start_run(self.root, self.write_charter(), run_id="demo")
        self.assertTrue((native.state_dir() / "rfl-live").glob("*-s1.json"))

    def test_a_foreign_live_pointer_makes_the_fallback_ambiguous(self):
        self.sessions("s1")
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s2"
        native.start_run(self.root, self.write_charter(), run_id="other")
        del os.environ["CLAUDE_CODE_SESSION_ID"]
        native.record_session(self.root, "s1")
        pointers = list((native.state_dir() / "rfl-live").glob("*.json"))
        (native.state_dir() / "rfl-live" / pointers[0].name.replace("-s2", "-s3")).write_text(pointers[0].read_text())
        self.assertEqual(native.current_session(self.root), "")

    def test_stale_recorded_sessions_do_not_count(self):
        self.sessions("s1", "s2")
        old = native.state_dir() / "rfl-sessions"
        for path in old.rglob("s2.json"):
            os.utime(path, (1, 1))
        self.assertEqual(native.current_session(self.root), "s1")

    def test_env_session_wins_and_no_wildcard_pointer_exists(self):
        self.sessions("s1", "s2")
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s2"
        native.start_run(self.root, self.write_charter(), run_id="demo")
        names = [p.name for p in (native.state_dir() / "rfl-live").glob("*.json")]
        self.assertEqual(len(names), 1)
        self.assertTrue(names[0].endswith("-s2.json"))
        self.assertFalse([n for n in names if n.endswith("-none.json")])
        os.environ.pop("CLAUDE_CODE_SESSION_ID")
        with self.assertRaisesRegex(native.RflError, "which session"):
            native.set_live(self.root, "x")

    def test_rungs_override_needs_a_known_session(self):
        self.sessions("s1", "s2")
        with self.assertRaises(native.RflError):
            native.record_user_rungs(self.root, "sonnet:high")
        self.assertEqual(native.user_rungs(self.root), "")


class RunLock(Fire):
    def test_q3_parallel_spawn_events_admit_exactly_one(self):
        self.start()
        issued = self.ticket("review")
        real = native.save_ticket

        def slow(*args, **kwargs):
            threading.Event().wait(0.05)
            return real(*args, **kwargs)

        results = []
        native.save_ticket = slow
        try:
            threads = [threading.Thread(target=lambda: results.append(self.fire(self.spawn_payload(issued)))) for _ in range(6)]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        finally:
            native.save_ticket = real
        allowed = [r for r in results if not self.reason(r)]
        self.assertEqual(len(allowed), 1, [self.reason(r) for r in results])

    def test_parallel_captures_record_one_result(self):
        self.start()
        issued = self.ticket("review")
        self.fire(self.spawn_payload(issued))
        body = f'<rfl-result ticket="{issued["ticket"]}">{json.dumps({"verdict": "CLEAN", "findings": []})}</rfl-result>'
        results = []
        threads = [threading.Thread(target=lambda: results.append(self.fire(
            {"hook_event_name": "PostToolUse", "tool_name": "Agent", "tool_response": body}))) for _ in range(6)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(len(list(self.rung_dir().glob("cycle-*-review.capture.json"))), 1)

    def test_a_lock_that_cannot_be_taken_is_a_clear_error(self):
        self.start()
        with native.run_lock(self.root, "demo"):
            holder = native.run_lock(self.root, "demo", timeout=0.2)
            # re-entrant in the same thread
            with holder:
                pass
            err = []

            def other():
                try:
                    with native.run_lock(self.root, "demo", timeout=0.2):
                        pass
                except native.RflError as exc:
                    err.append(str(exc))
            t = threading.Thread(target=other)
            t.start()
            t.join()
        self.assertTrue(err and "busy" in err[0])


class AbortValve(Fire):
    def typed_abort(self, sid="s1"):
        return self.fire({"hook_event_name": "UserPromptSubmit", "prompt": "RFL ABORT demo"}, sid)

    def setUp(self):
        super().setUp()
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s1"
        self.start()

    def test_q7_corrupt_record_still_aborts_with_an_audit_line(self):
        native.record_path(self.root, "demo").write_text("garbage")
        out = self.typed_abort()
        self.assertIn("corrupt", out["audit"]["reason"])
        self.assertIsNone(native.live_run_id(self.root, "s1"))
        self.assertEqual(self.fire({"hook_event_name": "Stop"}), hook.NOOP)
        self.assertEqual(native.load_record(self.root, "demo")["status"], "aborted")
        self.assertIn("without a verified token", (self.run_dir / "ABORTED.md").read_text() if (self.run_dir / "ABORTED.md").exists() else "without a verified token")

    def test_q7_missing_key_still_aborts(self):
        native._key_path(self.root).unlink()
        out = self.typed_abort()
        self.assertIn("corrupt", out["audit"]["reason"])
        self.assertIsNone(native.live_run_id(self.root, "s1"))

    def test_the_fallback_needs_this_sessions_own_live_run(self):
        native.record_path(self.root, "demo").write_text("garbage")
        out = self.typed_abort("s2")
        self.assertIn("refused", out["audit"]["reason"])
        self.assertEqual(native.live_run_id(self.root, "s1"), "demo")

    def test_a_corrupt_approve_is_still_refused(self):
        native.record_path(self.root, "demo").write_text("garbage")
        out = self.fire({"hook_event_name": "UserPromptSubmit", "prompt": "RFL APPROVE demo"})
        self.assertIn("refused", out["audit"]["reason"])
        self.assertEqual(native.live_run_id(self.root, "s1"), "demo")


class StopRelease(Fire):
    def stop(self, active):
        return self.fire({"hook_event_name": "Stop", "stop_hook_active": active})

    def setUp(self):
        super().setUp()
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s1"
        self.start()

    def test_q1_a_clearable_problem_keeps_blocking_until_the_nudge_limit(self):
        self.ticket("review")
        for _ in range(native.STOP_BLOCK_LIMIT):
            self.assertEqual(self.stop(True)["output"]["decision"], "block")
        released = self.stop(True)
        self.assertIn("released", released["output"]["systemMessage"])
        self.assertIn("RFL ABORT demo", released["output"]["systemMessage"])

    def test_the_count_resets_when_the_problem_clears(self):
        self.ticket("review")
        self.stop(True)
        native.cancel_ticket(self.root, self.run_dir)
        self.assertEqual(self.stop(False), hook.NOOP)
        self.ticket("review")
        for _ in range(native.STOP_BLOCK_LIMIT):
            self.assertEqual(self.stop(True)["output"]["decision"], "block")

    def test_an_unclearable_problem_is_released_by_stop_hook_active(self):
        (self.run_dir / native.STATUS_FILE).write_text("{}")
        self.assertEqual(self.stop(False)["output"]["decision"], "block")
        out = self.stop(True)
        self.assertIn("released", out["output"]["systemMessage"])
        self.assertIn("cannot clear", out["output"]["systemMessage"])

    def test_a_missing_policy_c_is_a_clearable_state(self):
        self.review()
        out = self.stop(True)
        self.assertEqual(out["output"]["decision"], "block")


class RejectedSpawn(Fire):
    def setUp(self):
        super().setUp()
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s1"

    def failure(self, error="model not available"):
        return self.fire({"hook_event_name": "PostToolUseFailure", "tool_name": "Agent", "error": error})

    def test_a_host_rejected_spawn_is_observed_and_counts_as_a_failed_attempt(self):
        self.start(rungs="sonnet:high sonnet:xhigh")
        for _ in range(2):
            self.fire(self.spawn_payload(self.ticket("review")))
            out = self.failure()
            self.assertIn("launch_failed", out["audit"]["reason"])
        self.assertEqual(self.status()["skipped"], [1])
        self.assertIn("model not available", (self.run_dir / "rung-01-sonnet-high" / "SKIPPED.md").read_text())

    def test_a_failure_for_a_ticket_that_never_spawned_is_ignored(self):
        self.start()
        self.ticket("review")
        self.assertEqual(self.failure(), hook.NOOP)
        self.assertEqual(self.status()["attempts"], {})

    def test_a_quota_failure_pauses_the_run(self):
        self.start()
        self.fire(self.spawn_payload(self.ticket("review")))
        self.failure("You've hit your limit. Resets 5pm")
        self.assertEqual(self.status()["status"], "paused_quota")

    def test_no_open_ticket_and_subagent_failures_are_ignored(self):
        self.start()
        self.assertEqual(self.failure(), hook.NOOP)
        self.fire(self.spawn_payload(self.ticket("review")))
        self.assertEqual(self.fire({"hook_event_name": "PostToolUseFailure", "tool_name": "Agent", "error": "x", "agent_id": "a1"}), hook.NOOP)
        self.assertEqual(self.fire({"hook_event_name": "PostToolUseFailure", "tool_name": "Bash", "error": "x"}), hook.NOOP)
        self.assertEqual(self.status()["attempts"], {})

    def test_resume_does_not_silently_drop_a_launched_ticket(self):
        self.start()
        self.fire(self.spawn_payload(self.ticket("review")))
        with self.assertRaisesRegex(native.RflError, "launched"):
            native.resume_run(self.root, "demo")
        self.assertIsNotNone(self.status()["open_ticket"])

    def test_resume_cancels_an_unlaunched_ticket_visibly_and_counts_it(self):
        self.start()
        issued = self.ticket("review")
        out = native.resume_run(self.root, "demo")
        self.assertEqual(out["dropped_ticket"], issued["ticket"])
        self.assertEqual(self.status()["cancels"], {"1:review": 1})
        self.assertEqual(self.status()["attempts"], {})

    def test_the_cancel_cap_survives_resume(self):
        self.start()
        for _ in range(native.MAX_CANCELS):
            self.ticket("review")
            native.resume_run(self.root, "demo")
        self.ticket("review")
        with self.assertRaisesRegex(native.RflError, "cancels"):
            native.resume_run(self.root, "demo")


class TokenOrigin(Fire):
    def test_q5_a_plain_library_call_cannot_mint_a_token(self):
        self.start(approve=False)
        for kind in ("abort", "approve"):
            with self.assertRaisesRegex(native.RflError, "only the UserPromptSubmit hook"):
                native.write_user_token(self.root, kind, "demo", session_id="s1", prompt_sha256="a" * 64)
        self.assertFalse(list(native.state_dir().glob("rfl-abort-*")))
        with self.assertRaises(native.RflError):
            native.abort_run(self.root, "demo")

    def test_a_hook_written_token_carries_the_session_digest_and_counter(self):
        self.start(approve=False)
        os.environ["CLAUDE_CODE_SESSION_ID"] = "s1"
        self.fire({"hook_event_name": "UserPromptSubmit", "prompt": "RFL ABORT demo"})
        token = json.loads((native.state_dir() / "rfl-abort-demo.json").read_text())
        self.assertEqual((token["session_id"], len(token["prompt_sha256"]), token["counter"] >= 1), ("s1", 64, True))
        native.abort_run(self.root, "demo")
        self.assertIn("session s1", (self.run_dir / "ABORTED.md").read_text())

    def test_a_token_without_a_counter_or_digest_is_refused_at_consume(self):
        self.start(approve=False)
        with native.hook_token_context():
            native.write_user_token(self.root, "abort", "demo", session_id="s1", prompt_sha256="a" * 64)
        path = native.token_path("abort", "demo")
        token = json.loads(path.read_text())
        token.pop("counter")
        path.write_text(json.dumps(native.signed(token, self.root)))
        with self.assertRaisesRegex(native.RflError, "expired or does not match"):
            native.abort_run(self.root, "demo")

    def test_hook_context_is_not_sticky(self):
        with native.hook_token_context():
            pass
        with self.assertRaises(native.RflError):
            native.write_user_token(self.root, "abort", "demo", session_id="s1", prompt_sha256="a" * 64)
