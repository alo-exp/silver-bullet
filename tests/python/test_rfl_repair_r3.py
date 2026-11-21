"""Review r3 repair: conservative agent-file scan, exact spawn parameters, token replay, tamper budget."""
from __future__ import annotations

import json
import os
import random
import unittest

from rflhelp import RflCase, hook, mint_token, native
from test_rfl_repair_r2 import Fire

BASES = ("sb-rfl-reviewer", "sb-rfl-verifier", "sb-rfl-")


def spellings(name):
    """Every YAML spelling of ``name`` the review found (and the transformations they are built from)."""
    uni = "".join(f"\\u{ord(c):04x}" for c in name)
    hexed = "".join(f"\\x{ord(c):02x}" for c in name)
    octal = "".join(f"\\{ord(c):o}" for c in name)
    half = name[:6] + "\\u0072" + name[7:]
    return {
        "after-long-description": f"---\ndescription: {'x' * 5000}\nname: {name}\n---\n",
        "flow": f"---\n{{name: {name}, description: d}}\n---\n",
        "flow-quoted": f'---\n{{"name": "{name}"}}\n---\n',
        "u-escape": f'---\nname: "{name[:7]}\\u0072{name[8:]}"\n---\n',
        "all-u": f'---\nname: "{uni}"\n---\n',
        "x-escape": f'---\nname: "{hexed}"\n---\n',
        "octal": f'---\nname: "{octal}"\n---\n',
        "mixed": f'---\nname: "{half}"\n---\n',
        "tag": f"---\nname: !!str {name}\n---\n",
        "complex-key": f"---\n? name\n: {name}\n---\n",
        "anchor": f"---\nx: &n {name}\nname: *n\n---\n",
        "folded-quote": f'---\nname: "{name[:4]}\n  {name[4:]}"\n---\n',
        "zero-width": f"---\nname: {name[:3]}​{name[3:]}\n---\n",
        "soft-hyphen": f"---\nname: {name[:3]}­{name[3:]}\n---\n",
        "fullwidth": f"---\nname: {name.replace('s', chr(0xff53))}\n---\n",
        "unicode-hyphen": f"---\nname: {name.replace('-', chr(0x2010))}\n---\n",
        "uppercase": f"---\nname: {name.upper()}\n---\n",
        "bom": f"﻿---\nname: {name}\n---\n",
        "plain-prose": f"I act as {name} sometimes",
    }


class ConservativeScan(Fire):
    def test_every_probe_spelling_is_refused_at_issue_and_at_spawn(self):
        self.start()
        for base in BASES:
            for label, text in spellings(base).items():
                path = self.agent_file(f"{label}.md", text)
                with self.subTest(base=base, label=label):
                    self.assertTrue(native.shadow_agent_files(self.root), "scan missed it")
                    with self.assertRaisesRegex(native.RflError, "over-broad"):
                        self.ticket("review")
                path.unlink()

    def test_fuzz_random_spellings_never_pass(self):
        rng = random.Random(7)
        escapes = [
            lambda t: "".join(f"\\u{ord(c):04x}" if rng.random() < 0.5 else c for c in t),
            lambda t: "".join(f"\\x{ord(c):02x}" if rng.random() < 0.5 else c for c in t),
            lambda t: "".join(f"\\{ord(c):o}" if rng.random() < 0.3 else c for c in t),
            lambda t: t,
        ]
        cosmetic = [
            lambda t: t.upper(),
            lambda t: "".join(c + ("\u200b" if rng.random() < 0.4 else "") for c in t),
            lambda t: t.replace("-", "\u2011"),
            lambda t: "".join(chr(ord(c) + 0xfee0) if c.isalpha() and rng.random() < 0.5 else c for c in t),
        ]
        wrappers = ('name: "{}"', "name: {}", "{{name: {}}}", "? name\n: {}", "name: !!str {}", "x: &a {}\nname: *a", "name: '{}'")
        for i in range(200):
            text = rng.choice(escapes)(rng.choice(BASES))  # at most one escape layer, as YAML has
            for fn in rng.sample(cosmetic, rng.randint(0, 3)):
                text = fn(text)
            body = rng.choice(wrappers).format(text)
            doc = f"---\ndescription: {'d' * rng.randint(0, 6000)}\n{body}\n---\nbody\n"
            self.assertTrue(native.mentions_reserved_agent(doc), (i, body))

    def test_unreadable_oversized_and_non_utf8_files_fail_closed(self):
        self.start()
        self.agent_file("big.md", "x" * (native.MAX_AGENT_FILE_BYTES + 1))
        self.assertTrue(native.shadow_agent_files(self.root))
        (self.root / ".claude" / "agents" / "big.md").unlink()
        (self.root / ".claude" / "agents" / "bin.md").write_bytes(b"\xff\xfe\x00bad")
        self.assertTrue(native.shadow_agent_files(self.root))
        (self.root / ".claude" / "agents" / "bin.md").unlink()
        link = self.root / ".claude" / "agents" / "dangling.md"
        link.symlink_to(self.tmp / "nowhere")
        self.assertTrue(native.shadow_agent_files(self.root))

    def test_more_agent_files_than_the_cap_fail_closed(self):
        old = native.MAX_AGENT_FILES
        native.MAX_AGENT_FILES = 3
        try:
            for i in range(5):
                self.agent_file(f"a{i}.md", "---\nname: a\n---\n")
            self.assertIn("more than 3", native.shadow_agent_files(self.root)[-1])
        finally:
            native.MAX_AGENT_FILES = old

    def test_a_filename_with_the_reserved_name_is_a_match(self):
        self.agent_file("SB-RFL-Verifier.md", "---\nname: harmless\n---\n")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_a_late_file_is_caught_at_the_spawn_check(self):
        self.start()
        issued = self.ticket("review")
        self.agent_file("late.md", spellings("sb-rfl-reviewer")["after-long-description"])
        self.assertIn("over-broad", self.reason(self.fire(self.spawn_payload(issued))))

    def test_the_edit_guard_applies_the_same_scan_to_content(self):
        self.start()
        for label, text in spellings("sb-rfl-reviewer").items():
            with self.subTest(label=label):
                self.assertIn("over-broad", self.reason(self.edit("Write", file_path=str(self.root / "docs/n.md"), content=text)))


class ExactSpawnParameters(Fire):
    def test_r2_isolation_and_every_other_extra_key_is_denied(self):
        self.start()
        issued = self.ticket("review")
        for key, value in (("isolation", "worktree"), ("name", "x"), ("resume", "a1"), ("mode", "plan"), ("cwd", "/tmp"),
                           ("working_directory", "/tmp"), ("subagent", "sb-rfl-reviewer"), ("max_turns", 3), ("tools", ["Bash"])):
            with self.subTest(key=key):
                self.assertIn("allows only the issued spawn parameters", self.reason(self.fire(self.spawn_payload(issued, **{key: value}))))
        self.assertEqual(self.status()["open_ticket"], issued["ticket"])
        self.assertFalse(native.read_ticket(self.root, self.run_dir, issued["ticket"])["spawned"])

    def test_a_differing_value_is_denied_and_the_issued_params_pass(self):
        self.start()
        issued = self.ticket("review")
        self.assertIn("issued description", self.reason(self.fire(self.spawn_payload(issued, description="something else"))))
        self.assertIn("foreground", self.reason(self.fire(self.spawn_payload(issued, run_in_background="yes"))))
        self.assertEqual(self.reason(self.fire(self.spawn_payload(issued, run_in_background=False))), "")


class TokenReplayAndBinding(Fire):
    def test_a_restored_token_is_refused(self):
        self.start(approve=False)
        mint_token(self.root, "approve", "demo")
        path = native.token_path("approve", "demo")
        saved = path.read_text()
        native.approve(self.root, self.run_dir)
        path.write_text(saved)
        with self.assertRaisesRegex(native.RflError, "already used"):
            native.approve(self.root, self.run_dir)

    def test_a_token_older_than_a_consumed_one_is_refused(self):
        self.start(approve=False)
        mint_token(self.root, "approve", "demo")
        old = native.token_path("approve", "demo").read_text()
        mint_token(self.root, "approve", "demo")
        native.approve(self.root, self.run_dir)
        native.token_path("approve", "demo").write_text(old)
        with self.assertRaisesRegex(native.RflError, "already used"):
            native.approve(self.root, self.run_dir)

    def test_an_approval_typed_for_another_charter_is_refused(self):
        self.start(approve=False)
        with native.hook_token_context():
            native.write_user_token(self.root, "approve", "demo", session_id="s1", prompt_sha256="a" * 64, bound="0" * 64)
        with self.assertRaisesRegex(native.RflError, "different charter"):
            native.approve(self.root, self.run_dir)

    def test_the_hook_binds_the_approval_to_the_sealed_charter(self):
        self.start(approve=False)
        self.fire({"hook_event_name": "UserPromptSubmit", "prompt": "RFL APPROVE demo"})
        token = json.loads(native.token_path("approve", "demo").read_text())
        self.assertEqual(token["bound"], native.load_record(self.root, "demo")["charter_sha256"])
        self.assertTrue(native.approve(self.root, self.run_dir)["approved"])


class TamperKeepsTheBudget(Fire):
    def stop(self, active):
        return self.fire({"hook_event_name": "Stop", "stop_hook_active": active})

    def test_r2_a_blanked_status_file_is_a_clearable_state_with_the_budget(self):
        self.start()
        (self.run_dir / native.STATUS_FILE).write_text("{}")
        self.assertEqual(self.stop(False)["output"]["decision"], "block")
        for _ in range(native.STOP_BLOCK_LIMIT - 1):
            self.assertEqual(self.stop(True)["output"]["decision"], "block")
        out = self.stop(True)
        self.assertIn("reminders were ignored", out["output"]["systemMessage"])

    def test_a_missing_status_file_is_the_same(self):
        self.start()
        (self.run_dir / native.STATUS_FILE).unlink()
        self.assertEqual(self.stop(True)["output"]["decision"], "block")

    def test_only_a_bad_sealed_record_is_unclearable(self):
        self.start()
        native.record_path(self.root, "demo").write_text("garbage")
        self.assertIn("cannot clear", self.stop(True)["output"]["systemMessage"])
