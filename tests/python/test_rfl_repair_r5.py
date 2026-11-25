"""Review r5 repair: links are resolved and their targets scanned; only unscannable or reserved-name cases refuse."""
from __future__ import annotations

import os
import unittest

from rflhelp import native
from test_rfl_repair_r2 import Fire

FORGED = "---\nname: sb-rfl-reviewer\n---\n"
HARMLESS = "---\nname: code-reviewer\ndescription: reviews code\n---\n"


class ResolvedLinks(Fire):
    def setUp(self):
        super().setUp()
        self.agents = self.root / ".claude" / "agents"
        self.outside = self.tmp / "dotfiles"
        self.outside.mkdir()

    def issues(self):
        return self.ticket("review")["ticket"]

    def test_s1_a_symlinked_agents_folder_with_harmless_agents_is_fine(self):
        (self.outside / "code-reviewer.md").write_text(HARMLESS)
        self.agents.parent.mkdir(parents=True)
        self.agents.symlink_to(self.outside)
        self.start()
        self.assertTrue(self.issues())
        self.assertEqual(native.shadow_agent_files(self.root), [])

    def test_s1_b_one_harmless_agent_file_symlinked_in_is_fine(self):
        (self.outside / "code-reviewer.md").write_text(HARMLESS)
        self.agents.mkdir(parents=True)
        (self.agents / "code-reviewer.md").symlink_to(self.outside / "code-reviewer.md")
        self.start()
        self.assertTrue(self.issues())

    def test_s1_c_a_regular_file_is_fine(self):
        self.agent_file("code-reviewer.md", HARMLESS)
        self.start()
        self.assertTrue(self.issues())

    def test_a_symlinked_dot_claude_and_a_symlinked_ancestor_are_resolved(self):
        (self.outside / "agents").mkdir()
        (self.outside / "agents" / "ok.md").write_text(HARMLESS)
        (self.root / ".claude").symlink_to(self.outside)
        self.assertEqual(native.shadow_agent_files(self.root), [])
        (self.outside / "agents" / "bad.md").write_text(FORGED)
        found = native.shadow_agent_files(self.root)
        self.assertEqual(len(found), 1)
        self.assertIn("bad.md", found[0])

    def test_a_link_to_a_folder_holding_the_reserved_name_is_refused_as_a_reserved_match(self):
        (self.outside / "x.md").write_text(FORGED)
        self.agents.mkdir(parents=True)
        (self.agents / "linked").symlink_to(self.outside)
        self.start()
        with self.assertRaisesRegex(native.RflError, "over-broad") as caught:
            self.ticket("review")
        self.assertIn("rename or move it", str(caught.exception))
        self.assertNotIn("cannot be scanned", str(caught.exception))

    def test_a_link_target_outside_the_project_is_still_scanned(self):
        (self.outside / "lone.md").write_text(FORGED)
        self.agents.mkdir(parents=True)
        (self.agents / "lone.md").symlink_to(self.outside / "lone.md")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_a_dangling_link_is_refused_with_its_own_message(self):
        self.agents.mkdir(parents=True)
        (self.agents / "gone.md").symlink_to(self.tmp / "nowhere")
        self.start()
        with self.assertRaises(native.RflError) as caught:
            self.ticket("review")
        text = str(caught.exception)
        self.assertIn("gone.md", text)
        self.assertIn(str(self.tmp / "nowhere"), text)
        self.assertIn("dangling", text)
        self.assertNotIn("rename or move it", text)

    def test_link_loops_terminate_and_are_refused(self):
        self.agents.mkdir(parents=True)
        (self.agents / "a").symlink_to(self.agents / "b")
        (self.agents / "b").symlink_to(self.agents / "a")
        found = native.shadow_agent_files(self.root)
        self.assertTrue(found and "loop" in found[0])
        for p in (self.agents / "a", self.agents / "b"):
            p.unlink()
        (self.agents / "sub").mkdir()
        (self.agents / "sub" / "back").symlink_to(self.agents)
        found = native.shadow_agent_files(self.root)
        self.assertTrue(found and "loop" in found[0])

    def test_a_duplicate_link_to_a_scanned_folder_is_not_a_loop(self):
        (self.outside / "ok.md").write_text(HARMLESS)
        self.agents.mkdir(parents=True)
        (self.agents / "one").symlink_to(self.outside)
        (self.agents / "two").symlink_to(self.outside)
        self.assertEqual(native.shadow_agent_files(self.root), [])

    def test_special_files_are_never_opened(self):
        self.agents.mkdir(parents=True)
        (self.agents / "zero.md").symlink_to("/dev/zero")
        os.mkfifo(self.agents / "pipe.md")
        found = native.shadow_agent_files(self.root)
        self.assertEqual(len(found), 2)
        self.assertTrue(all("not a regular file" in f for f in found))
        os.mkfifo(self.agents / "ignored.txt")  # a special file the host would not load as an agent is ignored
        self.assertEqual(len(native.shadow_agent_files(self.root)), 2)

    def test_a_chain_deeper_than_the_cap_is_refused(self):
        node = self.agents
        for i in range(native.MAX_LINK_DEPTH + 2):
            node = node / f"d{i}"
        node.mkdir(parents=True)
        (node / "ok.md").write_text(HARMLESS)
        found = native.shadow_agent_files(self.root)
        self.assertTrue(found and "too deep" in found[0])

    def test_hardlinks_are_ordinary_files(self):
        (self.outside / "h.md").write_text(FORGED)
        self.agents.mkdir(parents=True)
        os.link(self.outside / "h.md", self.agents / "h.md")
        self.assertEqual(len(native.shadow_agent_files(self.root)), 1)

    def test_the_total_cap_and_the_per_folder_cap_fail_closed(self):
        self.agents.mkdir(parents=True)
        old = native.MAX_AGENT_FILES_TOTAL
        native.MAX_AGENT_FILES_TOTAL = 2
        try:
            for i in range(3):
                (self.agents / f"a{i}.md").write_text(HARMLESS)
            self.assertTrue(any("total" in f for f in native.shadow_agent_files(self.root)))
        finally:
            native.MAX_AGENT_FILES_TOTAL = old

    def test_unreadable_and_non_utf8_and_oversized_targets_are_refused_with_the_reason(self):
        self.agents.mkdir(parents=True)
        (self.outside / "bin.md").write_bytes(b"\xff\xfe\x00")
        (self.agents / "bin.md").symlink_to(self.outside / "bin.md")
        (self.outside / "big.md").write_text("x" * (native.MAX_AGENT_FILE_BYTES + 1))
        (self.agents / "big.md").symlink_to(self.outside / "big.md")
        found = native.shadow_agent_files(self.root)
        self.assertEqual(len(found), 2)
        self.assertTrue(any("not UTF-8" in f for f in found))
        self.assertTrue(any("larger than" in f for f in found))

    def test_the_spawn_check_uses_the_same_messages(self):
        self.start()
        issued = self.ticket("review")
        self.agents.mkdir(parents=True)
        (self.agents / "gone.md").symlink_to(self.tmp / "nowhere")
        self.assertIn("dangling", self.reason(self.fire(self.spawn_payload(issued))))
        (self.agents / "gone.md").unlink()
        self.agent_file("evil.md", FORGED)
        self.assertIn("rename or move it", self.reason(self.fire(self.spawn_payload(issued))))


class SafeRead(ResolvedLinks):
    """The scan opens the resolved file O_NOFOLLOW|O_NONBLOCK, requires a regular file by fstat and reads at most limit+1."""

    def test_the_file_is_opened_without_following_links_and_without_blocking(self):
        self.agent_file("ok.md", HARMLESS)
        flags = []
        real_open = os.open

        def spy(path, fl, *a, **k):
            flags.append(fl)
            return real_open(path, fl, *a, **k)
        from unittest import mock
        with mock.patch.object(native.os, "open", side_effect=spy):
            self.assertEqual(native.shadow_agent_files(self.root), [])
        self.assertTrue(flags)
        self.assertTrue(all(f & os.O_NOFOLLOW and f & os.O_NONBLOCK for f in flags))

    def test_a_file_swapped_for_a_fifo_after_the_stat_is_refused_not_hung(self):
        from unittest import mock
        import stat as st
        self.agent_file("swap.md", HARMLESS)
        fake = os.stat_result((st.S_IFIFO | 0o644, 0, 0, 1, 0, 0, 0, 0, 0, 0))
        with mock.patch.object(native.os, "fstat", return_value=fake):
            found = native.shadow_agent_files(self.root)
        self.assertEqual(len(found), 1)
        self.assertIn("not a regular file", found[0])

    def test_a_real_fifo_is_never_blocked_on_even_when_it_replaces_the_file_after_the_stat(self):
        from unittest import mock
        self.agent_file("race.md", HARMLESS)
        victim = self.agents / "race.md"
        real_open = os.open

        def swap_then_open(path, fl, *a, **k):
            os.unlink(path)
            os.mkfifo(path)
            return real_open(path, fl, *a, **k)
        with mock.patch.object(native.os, "open", side_effect=swap_then_open):
            found = native.shadow_agent_files(self.root)
        self.assertTrue(victim.exists())
        self.assertIn("not a regular file", found[0])

    def test_a_file_that_grows_after_the_stat_is_cut_at_the_limit(self):
        from unittest import mock
        self.agent_file("grow.md", HARMLESS)
        real_open = os.open
        reads = []
        real_read = os.read

        def grow_then_open(path, fl, *a, **k):
            with open(path, "ab") as fh:
                fh.write(b"x" * (native.MAX_AGENT_FILE_BYTES + 4096))
            return real_open(path, fl, *a, **k)

        def spy_read(fd, n):
            data = real_read(fd, n)
            reads.append(len(data))
            return data
        with mock.patch.object(native.os, "open", side_effect=grow_then_open), mock.patch.object(native.os, "read", side_effect=spy_read):
            found = native.shadow_agent_files(self.root)
        self.assertEqual(len(found), 1)
        self.assertIn("larger than", found[0])
        self.assertLessEqual(sum(reads), native.MAX_AGENT_FILE_BYTES + 1)


class Corners(SafeRead):
    def test_other_stat_errors_are_reported_as_unreadable(self):
        import errno
        self.assertIn("unreadable", native._stat_reason(OSError(errno.EACCES, "Permission denied")))

    def test_an_agents_folder_that_is_dangling_or_a_file_is_refused(self):
        self.agents.parent.mkdir(parents=True)
        self.agents.symlink_to(self.tmp / "nowhere")
        self.assertIn("dangling", native.shadow_agent_files(self.root)[0])
        self.agents.unlink()
        self.agents.write_text("not a folder")
        self.assertIn("not a folder", native.shadow_agent_files(self.root)[0])

    def test_an_unscannable_folder_or_file_is_reported(self):
        from unittest import mock
        self.agents.mkdir(parents=True)
        (self.agents / "a.md").write_text(HARMLESS)
        with mock.patch.object(native.os, "scandir", side_effect=PermissionError(13, "denied")):
            self.assertIn("unreadable", native.shadow_agent_files(self.root)[0])
        with mock.patch.object(native.os, "open", side_effect=PermissionError(13, "denied")):
            self.assertIn("unreadable", native.shadow_agent_files(self.root)[0])

    def test_the_total_cap_is_reported_once(self):
        self.agents.mkdir(parents=True)
        old = native.MAX_AGENT_FILES_TOTAL
        native.MAX_AGENT_FILES_TOTAL = 1
        try:
            for i in range(4):
                (self.agents / f"a{i}.md").write_text(HARMLESS)
            self.assertEqual(len([f for f in native.shadow_agent_files(self.root) if "in total" in f]), 1)
        finally:
            native.MAX_AGENT_FILES_TOTAL = old


if __name__ == "__main__":
    unittest.main()
