"""Review r4 repair: symlinks and ancestors in the agent scan, content check scoped to agent targets, per-directory cap, strict booleans."""
from __future__ import annotations

import os
import unittest

from rflhelp import native
from test_rfl_repair_r2 import Fire

FORGED = "---\nname: sb-rfl-reviewer\n---\n"


class SymlinksAndAncestors(Fire):
    def setUp(self):
        super().setUp()
        self.agents = self.root / ".claude" / "agents"
        self.agents.mkdir(parents=True)
        self.elsewhere = self.tmp / "elsewhere"
        self.elsewhere.mkdir()

    def test_a_symlinked_folder_holding_the_name_is_a_match_and_blocks_the_ticket(self):
        self.start()
        (self.elsewhere / "x.md").write_text(FORGED)
        (self.agents / "sub").mkdir()
        (self.agents / "sub" / "deep").symlink_to(self.elsewhere)
        found = native.shadow_agent_files(self.root)
        self.assertTrue(found and "deep" in found[0])
        with self.assertRaisesRegex(native.RflError, "over-broad"):
            self.ticket("review")

    def test_symlinked_files_are_scanned_dangling_ones_are_refused(self):
        (self.elsewhere / "ok.md").write_text("harmless")
        (self.agents / "good.md").symlink_to(self.elsewhere / "ok.md")
        self.assertEqual(native.shadow_agent_files(self.root), [])
        (self.agents / "good.md").unlink()
        (self.agents / "dangling.md").symlink_to(self.tmp / "nowhere")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_links_in_the_user_and_plugin_agent_dirs_are_followed(self):
        (self.elsewhere / "x.md").write_text(FORGED)
        user = native.home_root() / "agents"
        user.mkdir(parents=True)
        (user / "l").symlink_to(self.elsewhere)
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)
        (user / "l").unlink()
        plugin = native.home_root() / "plugins" / "cache" / "mk" / "other" / "1.0" / "agents"
        plugin.mkdir(parents=True)
        (plugin / "l").symlink_to(self.elsewhere)
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_a_hardlink_is_an_ordinary_file_and_is_scanned(self):
        (self.elsewhere / "h.md").write_text(FORGED)
        os.link(self.elsewhere / "h.md", self.agents / "h.md")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_an_ancestor_agents_folder_is_scanned(self):
        parent = self.root.parent / ".claude" / "agents"
        parent.mkdir(parents=True)
        (parent / "p.md").write_text(FORGED)
        self.assertEqual(native.shadow_agent_files(self.root), [str(parent / "p.md")])

    def test_a_clean_ancestor_folder_does_not_block(self):
        parent = self.root.parent / ".claude" / "agents"
        parent.mkdir(parents=True)
        (parent / "p.md").write_text("harmless")
        self.assertEqual(native.shadow_agent_files(self.root), [])


    def test_the_agents_folder_itself_or_its_parent_being_a_link_is_resolved(self):
        (self.elsewhere / "a").mkdir()
        (self.elsewhere / "a" / "x.md").write_text(FORGED)
        self.agents.rmdir()
        (self.root / ".claude" / "agents").symlink_to(self.elsewhere / "a")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)
        (self.root / ".claude" / "agents").unlink()
        (self.root / ".claude").rmdir()
        (self.root / ".claude").symlink_to(self.elsewhere)
        (self.elsewhere / "agents").mkdir()
        (self.elsewhere / "agents" / "y.md").write_text(FORGED)
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)


class ContentCheckScope(Fire):
    def test_ordinary_files_mentioning_the_names_are_editable_during_a_run(self):
        self.start()
        text = "The sb-rfl-reviewer is the RFL reviewer."
        for rel in ("skills/silver-review-fix-ladder/SKILL.md", "docs/n.md", "src/a.py"):
            with self.subTest(rel=rel):
                self.assertEqual(self.reason(self.edit("Write", file_path=str(self.root / rel), content=text)), "")

    def test_the_same_text_under_any_agents_folder_is_blocked(self):
        self.start()
        for rel in (".claude/agents/x.md", "docs/agents/x.md", "plugins/p/agents/sub/x.md"):
            with self.subTest(rel=rel):
                self.assertIn("agent", self.reason(self.edit("Write", file_path=str(self.root / rel), content="sb-rfl-reviewer")))
        self.assertEqual(self.reason(self.edit("Write", file_path=str(self.root / "docs/agents/x.md"), content="harmless")), "")

    def test_malformed_edit_entries_are_ignored_safely(self):
        self.start()
        spec = {"file_path": str(self.root / "docs/agents/x.md"), "edits": [5, {"new_string": 3}, {"new_string": "fine"}]}
        self.assertEqual(self.reason(self.edit("MultiEdit", **spec)), "")

    def test_a_patch_adding_a_file_under_an_agents_folder_is_checked(self):
        self.start()
        patch = "*** Begin Patch\n*** Add File: docs/agents/x.md\n+name: sb-rfl-verifier\n*** End Patch"
        self.assertIn("reserved", self.reason(self.edit("apply_patch", input=patch)))


class CapAndBooleans(Fire):
    def test_the_cap_is_per_directory_names_it_and_ignores_our_own_copies(self):
        old = native.MAX_AGENT_FILES
        native.MAX_AGENT_FILES = 3
        try:
            own = native.home_root() / "plugins" / "cache" / "mk" / "silver-bullet" / "1" / "agents"
            for i in range(6):
                self.agent_file(f"o{i}.md", "harmless", base=own)
            (own.parent / ".claude-plugin").mkdir()
            (own.parent / ".claude-plugin" / "plugin.json").write_text('{"name": "silver-bullet"}')
            for i in range(2):
                self.agent_file(f"a{i}.md", "harmless")
            self.assertEqual(native.shadow_agent_files(self.root), [])  # two project files, six of ours: no cap
            for i in range(2, 5):
                self.agent_file(f"a{i}.md", "harmless")
            found = native.shadow_agent_files(self.root)
            self.assertIn("5 agent files", found[-1])
            self.assertIn(str(self.root / ".claude" / "agents"), found[-1])
        finally:
            native.MAX_AGENT_FILES = old

    def test_the_default_cap_is_sane(self):
        self.assertEqual(native.MAX_AGENT_FILES, 5000)

    def test_only_false_or_absent_run_in_background_passes(self):
        self.start()
        issued = self.ticket("review")
        for bad in (0, "", None, [], {}, 1, True, "false"):
            with self.subTest(value=bad):
                self.assertIn("foreground", self.reason(self.fire(self.spawn_payload(issued, run_in_background=bad))))
        self.assertEqual(self.reason(self.fire(self.spawn_payload(issued, run_in_background=False))), "")


if __name__ == "__main__":
    unittest.main()
