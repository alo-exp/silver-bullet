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
