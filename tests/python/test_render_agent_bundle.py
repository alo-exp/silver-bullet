"""Unit tests for scripts/render-agent-bundle.py (temp dirs only; no tracked file is written)."""
from __future__ import annotations

import contextlib
import errno
import io
import os
import pathlib
import runpy
import tempfile
import unittest
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/render-agent-bundle.py"
r = load_module(REL, name="rab_under_test")


class TmpCase(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.tmp = pathlib.Path(d.name).resolve()

    def write(self, rel, text="", binary=False):
        p = self.tmp / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if binary:
            p.write_bytes(text)
        else:
            p.write_text(text, encoding="utf-8")
        return p


class TextRewriteTest(unittest.TestCase):
    def test_host_agnostic_terms(self):
        t = "alo-labs-secondary host / .secondary host / secondary host / primary host"
        self.assertEqual(r.resolve_codex_host_agnostic_terms(t), "alo-labs-codex / .codex / Codex / primary host")
        self.assertEqual(r.resolve_cursor_host_agnostic_terms(t), "alo-labs / .cursor / Cursor / primary host")
        self.assertEqual(r.resolve_claude_host_agnostic_terms(t), "alo-labs / .claude / Codex / Claude Code")

    def test_rewrite_names(self):
        self.assertEqual(r.rewrite_names("name: silver\ndescription: d\n"), "name: sb\ndescription: d\n")
        self.assertEqual(r.rewrite_names("name:   silver-feature  \nname: silver-ui"), "name:   sb:feature\nname: silver-ui")
        self.assertEqual(r.rewrite_names("name: other"), "name: other")

    def test_humanize_and_titles(self):
        self.assertEqual(r.humanize_codex_skill_name("api-ci_tdd ui  foo"), "API CI TDD UI Foo")
        self.assertEqual(r.codex_title_for_name("sb"), "Router")
        self.assertEqual(r.codex_title_for_name("sb:devops-ui"), "DevOps UI")
        self.assertEqual(r.codex_title_for_name("helper", "SB: Old Name"), "SB: Old Name")
        self.assertEqual(r.codex_title_for_name("helper", "Silver: Other "), "SB: Other")
        self.assertEqual(r.codex_title_for_name("my-helper"), "SB: My Helper")

    def test_yaml_scalars(self):
        self.assertEqual(r.yaml_quote_scalar('a"b\\c'), '"a\\"b\\\\c"')
        self.assertEqual(r.yaml_unquote_scalar(' "x" '), "x")
        self.assertEqual(r.yaml_unquote_scalar("'y'"), "y")
        self.assertEqual(r.yaml_unquote_scalar("'mixed\""), "'mixed\"")
        self.assertEqual(r.yaml_unquote_scalar(' z '), "z")
        self.assertEqual(r.yaml_unquote_scalar('"'), '"')

    def test_quote_codex_frontmatter_scalars(self):
        self.assertEqual(r.quote_codex_frontmatter_scalars(""), "")
        self.assertEqual(r.quote_codex_frontmatter_scalars("no frontmatter: x\n"), "no frontmatter: x\n")
        src = (
            "---\n"
            "name: sb:x\n"
            "description: >\n"
            "  folded text: kept\n"
            "empty: \n"
            "q1: \"a: b\"\n"
            "q2: 'a: b'\n"
            "path: /abs/path\n"
            "at: @mention\n"
            "tick: `cmd`\n"
            "plain: just words\n"
            "not a key line\n"
            "pipe: |-\n"
            "crlf: a: b\r\n"
            "---\n"
            "body: x: y\n"
        )
        out = r.quote_codex_frontmatter_scalars(src)
        self.assertEqual(
            out,
            "---\n"
            "name: \"sb:x\"\n"
            "description: >\n"
            "  folded text: kept\n"
            "empty: \n"
            "q1: \"a: b\"\n"
            "q2: 'a: b'\n"
            "path: \"/abs/path\"\n"
            "at: \"@mention\"\n"
            "tick: \"`cmd`\"\n"
            "plain: just words\n"
            "not a key line\n"
            "pipe: |-\n"
            "crlf: \"a: b\"\r\n"
            "---\n"
            "body: x: y\n",
        )

    def test_quote_scalars_unterminated_frontmatter(self):
        self.assertEqual(r.quote_codex_frontmatter_scalars("---\nk: a: b\n"), "---\nk: \"a: b\"\n")

    def test_ensure_codex_picker_title(self):
        self.assertEqual(r.ensure_codex_picker_title("plain\n"), "plain\n")
        self.assertEqual(r.ensure_codex_picker_title(""), "")
        # no closing delimiter
        self.assertEqual(r.ensure_codex_picker_title("---\nname: sb:x\n"), "---\nname: sb:x\n")
        # no name
        self.assertEqual(r.ensure_codex_picker_title("---\ndescription: d\n---\n"), "---\ndescription: d\n---\n")
        # inserts a title after name
        self.assertEqual(
            r.ensure_codex_picker_title("---\nname: sb:release-ci\ndescription: d\n---\nbody\n"),
            '---\nname: sb:release-ci\ntitle: "Release CI"\ndescription: d\n---\nbody\n',
        )
        # replaces existing title; helper keeps current title; duplicate name/title lines ignored
        self.assertEqual(
            r.ensure_codex_picker_title('---\nname: "helper"\nname: other\ntitle: Silver: Old\ntitle: later\n---\n'),
            '---\nname: "helper"\nname: other\ntitle: "SB: Old"\ntitle: later\n---\n',
        )
        # title only after the frontmatter is not part of it
        self.assertEqual(
            r.ensure_codex_picker_title("---\nname: sb\n---\ntitle: body\n"),
            '---\nname: sb\ntitle: "Router"\n---\ntitle: body\n',
        )

    def test_mask_unmask_protected(self):
        text = "a templates/cursor-rules/x and .cursor/rules/y"
        masked, masks = r._mask_protected_runtime_subs(text)
        self.assertNotIn("templates/cursor-rules/", masked)
        self.assertNotIn(".cursor/rules/", masked)
        self.assertEqual(len(masks), 2)  # the longer "scripts/lib/..." prefix is absent
        self.assertEqual(r._unmask_protected_runtime_subs(masked, masks), text)
        self.assertEqual(r._mask_protected_runtime_subs("nothing"), ("nothing", []))

    def test_runtime_placeholders(self):
        pairs = dict(r.runtime_placeholders("codex"))
        self.assertEqual(pairs["${SB_RUNTIME_HOME_ROOT}"], "$HOME/.codex")
        self.assertEqual(pairs["${SB_RUNTIME_STATE_DIR}"], "$HOME/.codex/.silver-bullet")
        self.assertEqual(pairs["${SB_RUNTIME_PLUGIN_CACHE_ROOT}"], "$HOME/.codex/plugins/cache")
        self.assertEqual(pairs["$HOME/.claude/"], "$HOME/.codex/")
        self.assertEqual(pairs["${HOME}/.cursor"], "${HOME}/.codex")
        self.assertEqual(pairs[os.path.join("~", ".claude") + "/"], "$HOME/.codex/")

    def test_sanitize_cursor_text_preserves_cross_host_rows(self):
        text = (
            "Claude Code uses ${CLAUDE_PLUGIN_ROOT} and Claude settings via AskUserQuestion\n"
            "| **Claude Code** | row |\n"
            "when Claude Code TUI is the intended executor while Claude Code executes\n"
            "run `/compact` and secondary host\n"
        )
        out = r.sanitize_cursor_text(text)
        self.assertIn("Cursor uses ${CURSOR_PLUGIN_ROOT} and Cursor hooks.json via direct user interaction", out)
        self.assertIn("| **Claude Code** | row |", out)
        self.assertIn("when Claude Code TUI is the intended executor while Claude Code executes", out)
        self.assertIn("run context compaction and Cursor", out)

    def test_sanitize_codex_text(self):
        out = r.sanitize_codex_text("Use the Skill tool and /compact; Agent tool; secondary host; PostToolUse/Skill")
        self.assertEqual(
            out,
            "Use the runtime-native skill invocation channel and context compaction; active runtime delegation mechanism; Codex; PostToolUse/Skill or Codex invoke-skill receipt",
        )

    def test_sanitize_text_per_agent(self):
        src = "---\nname: silver-feature\n---\n${SB_RUNTIME_HOME_ROOT} ~/.claude/x primary host\n"
        claude = r.sanitize_text(src, "claude")
        self.assertIn("name: sb:feature", claude)
        self.assertIn("\n$HOME/.claude ~/.claude/x Claude Code\n", claude)
        self.assertIn("Claude Code", claude)
        self.assertNotIn("title:", claude)
        codex = r.sanitize_text(src, "codex")
        self.assertIn('title: "Feature"', codex)
        self.assertIn("name: \"sb:feature\"", codex)
        self.assertIn("$HOME/.codex/x", codex)
        cursor = r.sanitize_text(src, "cursor")
        self.assertIn("$HOME/.cursor/x", cursor)
        other = r.sanitize_text(src, "other")
        self.assertIn("name: silver-feature", other)
        self.assertIn("$HOME/.other", other)

    def test_sanitize_text_preserve_placeholders(self):
        src = "${SB_RUNTIME_HOME_ROOT} $HOME/.codex/x"
        self.assertEqual(r.sanitize_text(src, "claude", preserve_runtime_placeholders=True), src)
        self.assertEqual(r.sanitize_text(src, "claude"), "$HOME/.claude $HOME/.claude/x")

    def test_sanitize_text_codex_home_rewrite(self):
        with mock.patch("os.path.expanduser", return_value="/h/u"):
            self.assertEqual(r.sanitize_text("see /h/u/.codex/z", "codex"), "see $HOME/.codex/z")
        with mock.patch("os.path.expanduser", return_value=""):
            self.assertEqual(r.sanitize_text("see /h/u/.codex/z", "codex"), "see /h/u/.codex/z")


class SafeRmtreeTest(TmpCase):
    def test_missing_is_noop(self):
        r._safe_rmtree(self.tmp / "nope")

    def test_removes_file_symlink_dangling_symlink_and_tree(self):
        f = self.write("f.txt", "x")
        r._safe_rmtree(f)
        self.assertFalse(f.exists())
        target = self.write("t.txt", "x")
        link = self.tmp / "link"
        link.symlink_to(target)
        r._safe_rmtree(link)
        self.assertFalse(link.is_symlink())
        self.assertTrue(target.exists())
        dangling = self.tmp / "dangling"
        dangling.symlink_to(self.tmp / "gone")
        r._safe_rmtree(dangling)
        self.assertFalse(dangling.is_symlink())
        self.write("d/sub/x", "x")
        r._safe_rmtree(self.tmp / "d")
        self.assertFalse((self.tmp / "d").exists())

    def test_file_not_found_during_removal_is_ignored(self):
        self.write("d/x", "x")
        with mock.patch.object(r.shutil, "rmtree", side_effect=FileNotFoundError):
            r._safe_rmtree(self.tmp / "d")

    def test_transient_errors_are_retried_with_backoff(self):
        self.write("d/x", "x")
        calls = []

        def flaky(path):
            calls.append(path)
            if len(calls) < 3:
                raise OSError(errno.ENOTEMPTY, "busy")

        with mock.patch.object(r.shutil, "rmtree", side_effect=flaky), mock.patch.object(r.time, "sleep") as sl:
            r._safe_rmtree(self.tmp / "d", delay=0.5)
        self.assertEqual(len(calls), 3)
        self.assertEqual([c.args[0] for c in sl.call_args_list], [0.5, 1.0])

    def test_retries_exhausted_raises_last_error(self):
        self.write("d/x", "x")
        with mock.patch.object(r.shutil, "rmtree", side_effect=OSError(errno.EBUSY, "busy")) as rm, \
             mock.patch.object(r.time, "sleep"):
            with self.assertRaises(OSError) as cm:
                r._safe_rmtree(self.tmp / "d", retries=3)
        self.assertEqual(rm.call_count, 3)
        self.assertEqual(cm.exception.errno, errno.EBUSY)

    def test_zero_retries_attempts_nothing(self):
        d = self.write("d/x", "x").parent
        with mock.patch.object(r.shutil, "rmtree") as rm:
            self.assertIsNone(r._safe_rmtree(d, retries=0))
        rm.assert_not_called()
        self.assertTrue(d.exists())

    def test_other_errors_raise_immediately(self):
        self.write("d/x", "x")
        with mock.patch.object(r.shutil, "rmtree", side_effect=OSError(errno.EACCES, "denied")) as rm, \
             mock.patch.object(r.time, "sleep") as sl:
            with self.assertRaises(OSError):
                r._safe_rmtree(self.tmp / "d")
        self.assertEqual((rm.call_count, sl.call_count), (1, 0))


class RenderLockTest(TmpCase):
    def test_lock_file_created_beside_destination_and_released(self):
        dest = self.tmp / "out" / "bundle"
        with r._render_lock(dest):
            self.assertTrue((self.tmp / "out" / ".bundle.render.lock").is_file())
            with mock.patch.object(r.fcntl, "flock") as fl:
                pass
        with r._render_lock(dest):  # re-acquirable after release
            pass

    def test_flock_called_exclusive(self):
        with mock.patch.object(r.fcntl, "flock") as fl:
            with r._render_lock(self.tmp / "b"):
                pass
        self.assertEqual(fl.call_args.args[1], r.fcntl.LOCK_EX)


class RewriteFileTest(TmpCase):
    def test_skips_hooks_runtime_paths_and_non_files(self):
        p = self.write("hooks/lib/runtime-paths.sh", "$HOME/.claude/x")
        self.assertFalse(r.rewrite_file(p, "codex"))
        self.assertEqual(p.read_text(), "$HOME/.claude/x")
        self.assertFalse(r.rewrite_file(self.tmp / "missing", "codex"))
        self.assertFalse(r.rewrite_file(self.tmp, "codex"))

    def test_runtime_paths_name_outside_hooks_is_rewritten(self):
        p = self.write("lib/runtime-paths.sh", "$HOME/.claude/x")
        self.assertTrue(r.rewrite_file(p, "codex"))
        self.assertEqual(p.read_text(), "$HOME/.codex/x")

    def test_binary_file_untouched(self):
        p = self.write("b.bin", b"\xff\xfe\x00", binary=True)
        self.assertFalse(r.rewrite_file(p, "codex"))
        self.assertEqual(p.read_bytes(), b"\xff\xfe\x00")

    def test_rewrites_and_reports_change(self):
        p = self.write("a.md", "$HOME/.claude/x")
        self.assertTrue(r.rewrite_file(p, "cursor"))
        self.assertEqual(p.read_text(), "$HOME/.cursor/x")
        self.assertFalse(r.rewrite_file(p, "cursor"))  # idempotent

    def test_hooks_files_keep_runtime_placeholders(self):
        p = self.write("hooks/a.sh", "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        self.assertFalse(r.rewrite_file(p, "claude"))
        self.assertEqual(p.read_text(), "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        q = self.write("lib/a.sh", "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        self.assertTrue(r.rewrite_file(q, "claude"))
        self.assertEqual(q.read_text(), "$HOME/.claude/x $HOME/.claude/y")

    def test_read_oserror_retries_then_gives_up(self):
        p = self.write("a.md", "x")
        with mock.patch.object(pathlib.Path, "read_text", side_effect=OSError("io")) as rd, \
             mock.patch.object(r.time, "sleep") as sl:
            self.assertFalse(r.rewrite_file(p, "codex"))
        self.assertEqual(rd.call_count, 3)
        self.assertEqual([round(c.args[0], 2) for c in sl.call_args_list], [0.05, 0.1])

    def test_read_oserror_then_success(self):
        p = self.write("a.md", "$HOME/.claude/x")
        real = pathlib.Path.read_text
        calls = []

        def flaky(self_, *a, **k):
            calls.append(1)
            if len(calls) == 1:
                raise OSError("io")
            return real(self_, *a, **k)

        with mock.patch.object(pathlib.Path, "read_text", flaky), mock.patch.object(r.time, "sleep"):
            self.assertTrue(r.rewrite_file(p, "cursor"))
        self.assertEqual(p.read_text(), "$HOME/.cursor/x")

    def test_write_oserror_retries_then_gives_up_leaving_file(self):
        p = self.write("a.md", "$HOME/.claude/x")
        with mock.patch.object(pathlib.Path, "write_text", side_effect=OSError("ro")) as wr, \
             mock.patch.object(r.time, "sleep") as sl:
            self.assertFalse(r.rewrite_file(p, "cursor"))
        self.assertEqual((wr.call_count, sl.call_count), (3, 2))
        self.assertEqual(p.read_text(), "$HOME/.claude/x")

    def test_write_oserror_then_success(self):
        p = self.write("a.md", "$HOME/.claude/x")
        real = pathlib.Path.write_text
        calls = []

        def flaky(self_, *a, **k):
            calls.append(1)
            if len(calls) == 1:
                raise OSError("ro")
            return real(self_, *a, **k)

        with mock.patch.object(pathlib.Path, "write_text", flaky), mock.patch.object(r.time, "sleep"):
            self.assertTrue(r.rewrite_file(p, "cursor"))
        self.assertEqual(p.read_text(), "$HOME/.cursor/x")


class SanitizeRootTest(TmpCase):
    def test_missing_root_is_noop(self):
        r.sanitize_root(self.tmp / "nope", "codex")

    def test_walks_tree_skips_symlinks_and_special_files(self):
        a = self.write("s/a.md", "$HOME/.claude/a")
        b = self.write("s/deep/b.md", "$HOME/.claude/b")
        outside = self.write("outside/o.md", "$HOME/.claude/o")
        (self.tmp / "s" / "linkdir").symlink_to(self.tmp / "outside")
        (self.tmp / "s" / "linkfile").symlink_to(outside)
        os.mkfifo(self.tmp / "s" / "fifo")
        r.sanitize_root(self.tmp / "s", "codex")
        self.assertEqual(a.read_text(), "$HOME/.codex/a")
        self.assertEqual(b.read_text(), "$HOME/.codex/b")
        self.assertEqual(outside.read_text(), "$HOME/.claude/o")

    def test_children_are_visited_in_name_order(self):
        for name in ("c.md", "a.md", "b.md"):
            self.write(f"s/{name}", "x")
        seen = []
        with mock.patch.object(r, "rewrite_file", side_effect=lambda path, agent: seen.append(path.name)):
            r.sanitize_root(self.tmp / "s", "codex")
        self.assertEqual(seen, ["a.md", "b.md", "c.md"])

    def test_nested_directories_are_walked_depth_first_in_name_order(self):
        for rel in ("s/b/2.md", "s/b/1.md", "s/a/x.md", "s/z.md"):
            self.write(rel, "x")
        seen = []
        with mock.patch.object(r, "rewrite_file", side_effect=lambda path, agent: seen.append(path.relative_to(self.tmp / "s").as_posix())):
            r.sanitize_root(self.tmp / "s", "codex")
        self.assertEqual(seen, ["a/x.md", "b/1.md", "b/2.md", "z.md"])

    def test_root_that_is_a_symlink_is_skipped(self):
        real = self.write("real/a.md", "$HOME/.claude/a")
        (self.tmp / "lnk").symlink_to(self.tmp / "real")
        r.sanitize_root(self.tmp / "lnk", "codex")
        self.assertEqual(real.read_text(), "$HOME/.claude/a")


class RenameRoutesTest(TmpCase):
    def names(self, root):
        return sorted(p.name for p in root.iterdir())

    def test_missing_root(self):
        r.rename_route_skill_directories(self.tmp / "nope", host="claude")

    def test_renames_per_host(self):
        for host, expected in (
            ("claude", ["README.md", "other", "sb", "sb:bugfix", "sb:feature"]),
            ("cursor", ["README.md", "other", "sb", "sb:bugfix", "sb:feature"]),
            ("codex", ["README.md", "other", "sb", "sb-bugfix", "sb-feature"]),
        ):
            root = self.tmp / host
            for d in ("silver", "silver-feature", "silver-bugfix", "other"):
                (root / d).mkdir(parents=True)
            (root / "README.md").write_text("x")
            (root / "linked").parent.mkdir(exist_ok=True)
            (root / "silver-link").symlink_to(root / "other")
            r.rename_route_skill_directories(root, host=host)
            self.assertEqual([n for n in self.names(root) if n not in ("linked", "silver-link")], expected)
            self.assertTrue((root / "silver-link").is_symlink())

    def test_collision_exits(self):
        root = self.tmp / "c"
        (root / "silver-x").mkdir(parents=True)
        (root / "sb-x").mkdir()
        with self.assertRaisesRegex(SystemExit, "codex skill rename collision: silver-x -> sb-x"):
            r.rename_route_skill_directories(root, host="codex")
        self.assertTrue((root / "silver-x").is_dir())


class FrontmatterTest(TmpCase):
    def test_read_frontmatter(self):
        p = self.write("a.md", "---\nname: \"sb:x\"\nbad line\ndesc: 'q'\n  indented: no\nk-1: v: w\n---\nafter: no\n")
        self.assertEqual(r.read_skill_frontmatter(p), {"name": "sb:x", "desc": "q", "k-1": "v: w"})
        self.assertEqual(r.read_skill_frontmatter(self.write("b.md", "no fm\n")), {})
        self.assertEqual(r.read_skill_frontmatter(self.write("c.md", "")), {})
        self.assertEqual(r.read_skill_frontmatter(self.write("d.md", "---\nk: v\n")), {"k": "v"})

    def test_read_frontmatter_undecodable_falls_back(self):
        p = self.write("e.md", b"---\nname: caf\xe9\n---\n", binary=True)
        self.assertEqual(r.read_skill_frontmatter(p), {"name": "caf�"})

    def test_set_user_invocable_false_variants(self):
        # appended when missing, body and trailing newline kept
        p = self.write("a.md", "---\nname: x\n---\nbody\nmore\n")
        self.assertTrue(r.set_user_invocable_false(p))
        self.assertEqual(p.read_text(), "---\nname: x\nuser-invocable: false\n---\nbody\nmore\n")
        self.assertFalse(r.set_user_invocable_false(p))  # idempotent
        # true replaced
        p = self.write("b.md", "---\nuser-invocable: true\nname: x\n---\nb")
        self.assertTrue(r.set_user_invocable_false(p))
        self.assertEqual(p.read_text(), "---\nuser-invocable: false\nname: x\n---\nb")
        # no body, no trailing newline
        p = self.write("c.md", "---\nname: x\n---")
        self.assertTrue(r.set_user_invocable_false(p))
        self.assertEqual(p.read_text(), "---\nname: x\nuser-invocable: false\n---")
        # no frontmatter / unterminated / empty
        for name, text in (("d.md", "plain\n"), ("e.md", "---\nname: x\n"), ("f.md", "")):
            p = self.write(name, text)
            self.assertFalse(r.set_user_invocable_false(p))
            self.assertEqual(p.read_text(), text)

    def test_set_user_invocable_false_undecodable(self):
        p = self.write("g.md", b"---\nname: caf\xe9\n---\n", binary=True)
        self.assertTrue(r.set_user_invocable_false(p))
        self.assertEqual(p.read_text(encoding="utf-8"), "---\nname: caf�\nuser-invocable: false\n---\n")


class CommandStubTest(TmpCase):
    def make_commands(self):
        c = self.tmp / "plugins" / "silver-bullet" / "commands"
        c.mkdir(parents=True)
        (c / "feature.md").write_text("---\nname: sb-feature\n---\n")
        (c / "plain.md").write_text("no frontmatter\n")
        (c / "router.md").write_text("---\nname: sb\n---\n")
        (c / "colon.md").write_text("---\nname: sb:colon\n---\n")
        (c / "ignored.txt").write_text("x")
        return c

    def test_dotfile_stub_uses_its_stem(self):
        c = self.tmp / "commands"
        c.mkdir()
        (c / ".md").write_text("")
        self.assertEqual(r.command_stub_routes(c), {".md"})

    def test_routes(self):
        self.assertEqual(r.command_stub_routes(self.tmp / "none"), set())
        self.assertEqual(r.command_stub_routes(self.make_commands()), {"sb:feature", "plain", "sb", "sb:colon"})

    def skill_root(self):
        root = self.tmp / "skills"
        for d, name in (("a", "sb:feature"), ("b", "sb:other"), ("c", "plain")):
            self.write(f"skills/{d}/SKILL.md", f"---\nname: {name}\n---\nbody\n")
        self.write("skills/loose.md", "x")
        return root

    def test_suppress_marks_matching_skills_only(self):
        root = self.skill_root()
        r.suppress_command_stub_skills_from_picker(root, self.make_commands())
        self.assertIn("user-invocable: false", (root / "a" / "SKILL.md").read_text())
        self.assertIn("user-invocable: false", (root / "c" / "SKILL.md").read_text())
        self.assertNotIn("user-invocable", (root / "b" / "SKILL.md").read_text())

    def test_suppress_without_routes_is_noop(self):
        root = self.skill_root()
        before = (root / "a" / "SKILL.md").read_text()
        r.suppress_command_stub_skills_from_picker(root, self.tmp / "no-commands")
        self.assertEqual((root / "a" / "SKILL.md").read_text(), before)

    def test_exclude_removes_matching_skill_dirs(self):
        root = self.skill_root()
        r.exclude_command_stub_skills_from_cursor_subagent_surface(root, self.make_commands())
        self.assertFalse((root / "a").exists())
        self.assertFalse((root / "c").exists())
        self.assertTrue((root / "b" / "SKILL.md").is_file())

    def test_exclude_without_routes_is_noop(self):
        root = self.skill_root()
        r.exclude_command_stub_skills_from_cursor_subagent_surface(root, self.tmp / "no-commands")
        self.assertTrue((root / "a").is_dir())


class RenderBundleTest(TmpCase):
    def make_source(self):
        src = self.tmp / "repo" / "skills"
        self.write("repo/skills/silver-feature/SKILL.md", "---\nname: silver-feature\ndescription: d\n---\n$HOME/.claude/x\n")
        self.write("repo/skills/silver-feature/agents/openai.yaml", "model: x\n")
        self.write("repo/skills/silver-feature/notes.md", "keep ~/.claude/y\n")
        self.write("repo/skills/silver/SKILL.md", "---\nname: silver\n---\nrouter\n")
        self.write("repo/skills/helper/SKILL.md", "---\nname: helper\n---\nplain\n")
        return src

    def test_missing_source_exits(self):
        with self.assertRaisesRegex(SystemExit, "source root missing"):
            r.render_bundle(self.tmp / "none", self.tmp / "out", "codex")
        self.assertFalse((self.tmp / "out").exists())

    def test_renders_codex(self):
        src = self.make_source()
        dest = self.tmp / "out" / "bundle"
        r.render_bundle(src, dest, "codex")
        self.assertEqual(sorted(p.name for p in dest.iterdir()), ["helper", "sb", "sb-feature"])
        text = (dest / "sb-feature" / "SKILL.md").read_text()
        self.assertIn("name: \"sb:feature\"", text)
        self.assertIn('title: "Feature"', text)
        self.assertIn("$HOME/.codex/x", text)
        self.assertTrue((dest / "sb-feature" / "agents" / "openai.yaml").is_file())
        self.assertEqual((dest / "sb-feature" / "notes.md").read_text(), "keep $HOME/.codex/y\n")
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), [".bundle.render.lock", "bundle"])
        # source untouched
        self.assertIn("silver-feature", (src / "silver-feature" / "SKILL.md").read_text())

    def test_render_replaces_existing_destination(self):
        src = self.make_source()
        dest = self.tmp / "out" / "bundle"
        self.write("out/bundle/stale.txt", "old")
        r.render_bundle(src, dest, "claude")
        self.assertFalse((dest / "stale.txt").exists())
        self.assertEqual(sorted(p.name for p in dest.iterdir()), ["helper", "sb", "sb:feature"])
        self.assertFalse((dest / "sb:feature" / "agents" / "openai.yaml").exists())
        self.assertIn("$HOME/.claude/x", (dest / "sb:feature" / "SKILL.md").read_text())

    def test_render_cursor_drops_command_covered_skills(self):
        src = self.make_source()
        cmds = self.tmp / "repo" / "plugins" / "silver-bullet" / "commands"
        cmds.mkdir(parents=True)
        (cmds / "feature.md").write_text("---\nname: sb-feature\n---\n")
        dest = self.tmp / "out" / "cursor"
        r.render_bundle(src, dest, "cursor")
        self.assertEqual(sorted(p.name for p in dest.iterdir()), ["helper", "sb"])

    def test_render_cursor_without_commands_keeps_everything(self):
        src = self.make_source()
        dest = self.tmp / "out" / "cursor"
        r.render_bundle(src, dest, "cursor")
        self.assertEqual(sorted(p.name for p in dest.iterdir()), ["helper", "sb", "sb:feature"])

    def test_symlinks_in_the_source_are_copied_as_regular_files(self):
        src = self.make_source()
        (src / "silver-feature" / "linked.md").symlink_to(src / "silver-feature" / "notes.md")
        (src / "linked-dir").symlink_to(src / "helper")
        dest = self.tmp / "out" / "bundle"
        r.render_bundle(src, dest, "codex")
        linked = dest / "sb-feature" / "linked.md"
        self.assertFalse(linked.is_symlink())
        self.assertEqual(linked.read_text(), "keep $HOME/.codex/y\n")
        self.assertFalse((dest / "linked-dir").is_symlink())
        self.assertTrue((dest / "linked-dir" / "SKILL.md").is_file())
        self.assertTrue((src / "silver-feature" / "linked.md").is_symlink())  # source untouched

    def test_destination_parents_are_created_and_existing_parent_is_fine(self):
        src = self.make_source()
        deep = self.tmp / "p" / "q" / "r" / "bundle"
        r.render_bundle(src, deep, "codex")
        self.assertTrue((deep / "sb-feature" / "SKILL.md").is_file())
        r.render_bundle(src, deep, "codex")  # parent already exists
        self.assertTrue((deep / "sb-feature" / "SKILL.md").is_file())

    def test_openai_yaml_is_removed_for_cursor_and_claude_but_kept_for_codex(self):
        src = self.make_source()
        for agent, expect in (("cursor", False), ("claude", False), ("codex", True)):
            with self.subTest(agent=agent):
                dest = self.tmp / "out" / agent
                r.render_bundle(src, dest, agent)
                found = list(dest.glob("*/agents/openai.yaml"))
                self.assertEqual(bool(found), expect)

    def test_unknown_agent_is_copied_without_route_renames(self):
        src = self.make_source()
        dest = self.tmp / "out" / "x"
        r.render_bundle(src, dest, "other")
        self.assertEqual(sorted(p.name for p in dest.iterdir()), ["helper", "silver", "silver-feature"])
        self.assertTrue((dest / "silver-feature" / "agents" / "openai.yaml").is_file())

    def test_failure_cleans_staging_keeps_destination_and_reraises(self):
        src = self.make_source()
        dest = self.tmp / "out" / "bundle"
        self.write("out/bundle/keep.txt", "old")
        with mock.patch.object(r, "sanitize_root", side_effect=RuntimeError("boom")):
            with self.assertRaisesRegex(RuntimeError, "boom"):
                r.render_bundle(src, dest, "codex")
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), [".bundle.render.lock", "bundle"])
        self.assertEqual((dest / "keep.txt").read_text(), "old")

    def test_stale_staging_dir_is_replaced(self):
        src = self.make_source()
        dest = self.tmp / "out" / "bundle"
        self.write(f"out/.bundle.staging-{os.getpid()}/junk", "x")
        r.render_bundle(src, dest, "codex")
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), [".bundle.render.lock", "bundle"])
        self.assertFalse((dest / "junk").exists())


class MainTest(TmpCase):
    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("sys.argv", ["render-agent-bundle.py", *argv]), \
             contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                rc = r.main()
            except SystemExit as exc:
                rc = exc.code
        return rc, err.getvalue()

    def test_render_mode(self):
        self.write("src/silver-x/SKILL.md", "---\nname: silver-x\n---\n")
        rc, _ = self.run_main("render", "--agent", "codex", "--source-root", str(self.tmp / "src"), "--dest-root", str(self.tmp / "dest"))
        self.assertEqual(rc, 0)
        self.assertTrue((self.tmp / "dest" / "sb-x" / "SKILL.md").is_file())

    def test_render_requires_roots(self):
        for extra in ([], ["--source-root", "a"], ["--dest-root", "b"]):
            rc, err = self.run_main("render", "--agent", "codex", *extra)
            self.assertEqual(rc, 2)
            self.assertIn("render mode requires --source-root and --dest-root", err)

    def test_render_failure_cleans_staging_and_exits_nonzero_with_message(self):
        self.write("src/silver-x/SKILL.md", "---\nname: silver-x\n---\n")
        dest = self.tmp / "dest"
        with mock.patch.object(r, "sanitize_root", side_effect=RuntimeError("boom")):
            rc, err = self.run_main("render", "--agent", "codex", "--source-root", str(self.tmp / "src"), "--dest-root", str(dest))
        self.assertEqual(rc, 1)
        self.assertEqual(err, "ERROR: render failed: boom\n")
        self.assertFalse(dest.exists())
        self.assertEqual(sorted(p.name for p in self.tmp.iterdir() if "staging" in p.name), [])

    def test_sanitize_mode(self):
        f = self.write("root/a.md", "$HOME/.claude/x")
        rc, _ = self.run_main("sanitize", "--agent", "cursor", "--root", str(self.tmp / "root"))
        self.assertEqual(rc, 0)
        self.assertEqual(f.read_text(), "$HOME/.cursor/x")

    def test_sanitize_requires_root(self):
        rc, err = self.run_main("sanitize", "--agent", "codex")
        self.assertEqual(rc, 2)
        self.assertIn("sanitize mode requires --root", err)

    def test_agent_is_required(self):
        for argv in (["sanitize", "--root", "x"], ["render", "--source-root", "a", "--dest-root", "b"]):
            rc, err = self.run_main(*argv)
            self.assertEqual(rc, 2)
            self.assertIn("the following arguments are required: --agent", err)

    def test_every_documented_agent_is_accepted_and_choices_are_listed(self):
        for agent in ("claude", "codex", "cursor"):
            rc, _ = self.run_main("sanitize", "--agent", agent, "--root", str(self.tmp / "none"))
            self.assertEqual(rc, 0, agent)
        rc, err = self.run_main("sanitize", "--agent", "vim", "--root", "x")
        self.assertIn("choose from claude, codex, cursor", err.replace("'", ""))

    def test_bad_agent_rejected(self):
        rc, err = self.run_main("sanitize", "--agent", "vim", "--root", "x")
        self.assertEqual(rc, 2)
        self.assertIn("invalid choice", err)

    def test_entrypoint(self):
        f = self.write("root/a.md", "$HOME/.claude/x")
        with mock.patch("sys.argv", ["r", "sanitize", "--agent", "codex", "--root", str(self.tmp / "root")]):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(f.read_text(), "$HOME/.codex/x")


if __name__ == "__main__":
    unittest.main()
