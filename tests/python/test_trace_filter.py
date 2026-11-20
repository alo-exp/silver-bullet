"""Unit tests for hooks/lib/tool-input/trace_filter.py (the write-trace rotation rule, G4 r8)."""

import os
import subprocess
import tempfile
import unittest
from unittest import mock

from sbtest import load_module

tf = load_module("hooks/lib/tool-input/trace_filter.py")


def git(root, *args):
    subprocess.run(["git", "-C", root, "-c", "user.email=a@b", "-c", "user.name=a", *args], check=True,
                   capture_output=True)


class FilterTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = os.path.realpath(self.tmp.name)
        git(self.root, "init", "-q", "-b", "main")
        self.write("src/a.js", "a")
        self.write("src/b[1].js", "b")
        self.write("src/old.js", "o")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "init")
        self.head = self.rev()
        self.trace = os.path.join(self.root, ".git", "trace")

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8", errors="surrogateescape") as handle:
            handle.write(text)

    def rev(self):
        return subprocess.run(["git", "-C", self.root, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()

    def run_filter(self, entries, old="", new=""):
        with open(self.trace, "wb") as handle:
            handle.write(os.fsencode("\n".join(entries) + "\n"))
        tf.filter_trace(self.root, old, new, self.trace)
        if not os.path.exists(self.trace):
            return []
        with open(self.trace, "rb") as handle:
            return [os.fsdecode(x) for x in handle.read().split(b"\n") if x]

    def p(self, rel):
        return os.path.join(self.root, rel)

    def test_dirty_file_kept_clean_and_star_dropped(self):
        self.write("src/a.js", "more")
        got = self.run_filter(["*", "f" + self.p("src/a.js"), "f" + self.p("src/old.js"), "f/elsewhere/x.js", "x", ""])
        self.assertEqual(got, ["f" + self.p("src/a.js")])

    def test_nothing_kept_removes_the_trace(self):
        self.assertEqual(self.run_filter(["*", "f" + self.p("src/a.js")]), [])
        self.assertFalse(os.path.exists(self.trace))

    def test_moved_entries_are_dropped(self):
        git(self.root, "checkout", "-q", "-b", "ahead")
        self.write("src/c.js", "c")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "ahead")
        ahead = self.rev()
        git(self.root, "checkout", "-q", "main")
        self.write("src/a.js", "dirty")
        self.write("src/c.js", "dirty")
        entries = ["f" + self.p("src/a.js"), "f" + self.p("src/c.js")]
        self.assertEqual(self.run_filter(entries, self.head, ahead), ["f" + self.p("src/a.js")])
        self.assertEqual(self.run_filter(entries, "", ahead), entries)
        self.assertEqual(self.run_filter(entries, ahead, ahead), entries)
        self.assertEqual(self.run_filter(entries, "deadbeef", ahead), entries)

    def test_bracket_directory_glob_and_tree_entries_use_fixed_prefixes(self):
        self.write("dir[x]/f.js", "1")
        self.write("src/b[1].js", "dirty")
        self.write("gen/one/two.js", "2")
        got = self.run_filter([
            "d" + self.p("dir[x]"),
            "f" + self.p("src/b[1].js"),
            "f" + self.p("gen/*.js"),
            "t" + self.p("gen/one"),
            "d" + self.p("clean"),
            "d" + self.p(""),
        ])
        self.assertEqual(got, ["d" + self.p("dir[x]"), "f" + self.p("src/b[1].js"), "f" + self.p("gen/*.js"),
                               "t" + self.p("gen/one"), "d" + self.p("")])

    def test_untracked_directory_covers_entries_below_it(self):
        self.write("fresh/deep/x.js", "x")
        got = self.run_filter(["f" + self.p("fresh/deep/x.js"), "d" + self.p("fresh/deep"), "f" + self.p("fresh/other.js")])
        # git collapses an untracked directory to one record, so every path below it counts as dirty
        self.assertEqual(got, ["f" + self.p("fresh/deep/x.js"), "d" + self.p("fresh/deep"), "f" + self.p("fresh/other.js")])

    def test_rename_records_and_odd_names(self):
        git(self.root, "mv", "src/old.js", "src/new.js")
        self.write("src/line\nbreak.js", "n")
        paths = tf.dirty_paths(self.root)
        self.assertIn("src/new.js", paths)
        self.assertIn("src/old.js", paths)
        self.assertIn("src/line\nbreak.js", paths)
        # an entry with a newline in its path cannot be a trace line: only the old path of the rename is kept
        self.assertEqual(self.run_filter(["f" + self.p("src/old.js")]), ["f" + self.p("src/old.js")])

    def test_symlinked_root_spelling_and_empty_old_path(self):
        link = os.path.join(self.tmp.name + "-link")
        os.symlink(self.root, link)
        self.addCleanup(os.unlink, link)
        self.write("src/a.js", "dirty")
        with open(self.trace, "wb") as handle:
            handle.write(os.fsencode("f" + os.path.join(link, "src/a.js") + "\n"))
        tf.filter_trace(link, "", "", self.trace)
        self.assertTrue(os.path.exists(self.trace))

    def test_short_records_are_skipped(self):
        with mock.patch.object(tf, "_git", return_value=b"\0 M\0R  new\0\0"):
            self.assertEqual(tf.dirty_paths(self.root), ["new"])

    def test_write_failure_leaves_the_trace_and_reports(self):
        self.write("src/a.js", "dirty")
        with open(self.trace, "wb") as handle:
            handle.write(os.fsencode("f" + self.p("src/a.js") + "\n"))
        with mock.patch.object(tf.os, "replace", side_effect=OSError("no")):
            with self.assertRaises(OSError):
                tf.filter_trace(self.root, "", "", self.trace)
        self.assertEqual(len([n for n in os.listdir(os.path.dirname(self.trace)) if n.startswith("trace.")]), 0)

    def test_main_status_codes(self):
        self.assertEqual(tf.main(["x"]), 2)
        self.assertEqual(tf.main(["x", self.root, "", "", os.path.join(self.root, "missing")]), 1)
        self.write("src/a.js", "dirty")
        with open(self.trace, "wb") as handle:
            handle.write(os.fsencode("f" + self.p("src/a.js") + "\n"))
        self.assertEqual(tf.main(["x", self.root, "", "", self.trace]), 0)
        with mock.patch.object(tf, "_git", side_effect=subprocess.SubprocessError("x")):
            self.assertEqual(tf.main(["x", self.root, "", "", self.trace]), 1)

    def test_moved_paths_git_failure_means_nothing_moved(self):
        self.assertEqual(tf.moved_paths(self.root, "deadbeef", self.head), [])


if __name__ == "__main__":
    unittest.main()
