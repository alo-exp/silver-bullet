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

    def test_runtime_placeholders(self):
        pairs = dict(r.runtime_placeholders("codex"))
        self.assertEqual(pairs["${SB_RUNTIME_HOME_ROOT}"], "$HOME/.codex")
        self.assertEqual(pairs["${SB_RUNTIME_STATE_DIR}"], "$HOME/.codex/.silver-bullet")
        self.assertEqual(pairs["${SB_RUNTIME_PLUGIN_CACHE_ROOT}"], "$HOME/.codex/plugins/cache")
        self.assertEqual(pairs["$HOME/.claude/"], "$HOME/.codex/")
        self.assertEqual(pairs["${HOME}/.cursor"], "${HOME}/.codex")
        self.assertEqual(pairs[os.path.join("~", ".claude") + "/"], "$HOME/.codex/")

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

    def test_sanitize_text_does_not_depend_on_the_renderers_home(self):
        # R8-04(b): output must not depend on who renders. A literal expansion
        # of the maintainer's own $HOME is left alone, whatever $HOME is.
        for home in ("/h/u", ""):
            with self.subTest(home=home), mock.patch("os.path.expanduser", return_value=home):
                self.assertEqual(r.sanitize_text("see /h/u/.codex/z", "codex"), "see /h/u/.codex/z")

    def test_flow_sequences_and_mappings_stay_yaml_collections_for_codex(self):
        # R8-04(d): `aliases: ["sb:doctor"]` must stay a list, not become a string.
        src = '---\nname: silver-doctor\naliases: ["sb:doctor"]\nmap: {a: "b:c"}\nhint: a:b\n---\nbody\n'
        out = r.sanitize_text(src, "codex")
        self.assertIn('aliases: ["sb:doctor"]\n', out)
        self.assertIn('map: {a: "b:c"}\n', out)
        self.assertIn('hint: "a:b"\n', out)

    def test_crlf_frontmatter_keeps_crlf_line_endings(self):
        # R8-04(c): rewritten lines keep the file's CRLF endings, inserted lines use them.
        src = "---\r\nname: silver-feature\r\ndescription: Read tool: x\r\n---\r\nUse the Read tool\r\n"
        out = r.sanitize_text(src, "codex")
        self.assertEqual(out.count("\r\n"), out.count("\n"))
        self.assertIn('name: "sb:feature"\r\n', out)
        self.assertIn('title: "Feature"\r\n', out)
        self.assertIn("Use the active runtime file-reading mechanism\r\n", out)
        claude = r.sanitize_text(src, "claude")
        self.assertIn("name: sb:feature\r\n", claude)


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
    def rewrite(self, path, agent, **kw):
        return r.rewrite_file(path, agent, root=self.tmp, **kw)

    def test_skips_hooks_runtime_paths_and_non_files(self):
        p = self.write("hooks/lib/runtime-paths.sh", "$HOME/.claude/x")
        self.assertFalse(self.rewrite(p, "codex"))
        self.assertEqual(p.read_text(), "$HOME/.claude/x")
        self.assertFalse(self.rewrite(self.tmp / "missing", "codex"))
        self.assertFalse(self.rewrite(self.tmp, "codex"))

    def test_runtime_paths_name_outside_hooks_is_rewritten(self):
        p = self.write("lib/runtime-paths.sh", "$HOME/.claude/x")
        self.assertTrue(self.rewrite(p, "codex"))
        self.assertEqual(p.read_text(), "$HOME/.codex/x")

    def test_hooks_detection_ignores_ancestors_above_the_root(self):
        # R8-04(a): a checkout under a directory named `hooks` must render like any other.
        root = self.tmp / "hooks" / "checkout"
        p = root / "lib" / "a.md"
        p.parent.mkdir(parents=True)
        p.write_text("${SB_RUNTIME_HOME_ROOT}/x\n")
        self.assertTrue(r.rewrite_file(p, "codex", root=root))
        self.assertEqual(p.read_text(), "$HOME/.codex/x\n")
        q = root / "hooks" / "lib" / "runtime-paths.sh"
        q.parent.mkdir(parents=True)
        q.write_text("$HOME/.claude/x")
        self.assertFalse(r.rewrite_file(q, "codex", root=root))

    def test_binary_file_untouched(self):
        p = self.write("b.bin", b"\xff\xfe\x00", binary=True)
        self.assertFalse(self.rewrite(p, "codex"))
        self.assertEqual(p.read_bytes(), b"\xff\xfe\x00")

    def test_rewrites_and_reports_change(self):
        p = self.write("a.md", "$HOME/.claude/x")
        self.assertTrue(self.rewrite(p, "cursor"))
        self.assertEqual(p.read_text(), "$HOME/.cursor/x")
        self.assertFalse(self.rewrite(p, "cursor"))  # idempotent

    def test_crlf_is_preserved_byte_for_byte(self):
        # R8-04(c): rewritten and untouched files both keep CRLF.
        p = self.write("a.md", b"Use the Read tool\r\nnext\r\n", binary=True)
        self.assertTrue(self.rewrite(p, "codex"))
        self.assertEqual(p.read_bytes(), b"Use the active runtime file-reading mechanism\r\nnext\r\n")
        q = self.write("plain.md", b"nothing to change\r\n", binary=True)
        self.assertFalse(self.rewrite(q, "codex"))
        self.assertEqual(q.read_bytes(), b"nothing to change\r\n")

    def test_docs_only_leaves_code_and_data_verbatim(self):
        # R8-04(e): skill code and data are not host prose.
        py = self.write("s/x.py", 'NAME = "Claude Code"  # run /compact\n')
        js = self.write("s/x.json", '{"name": "Claude Code", "p": "~/.claude/x"}\n')
        md = self.write("s/x.md", "Claude Code\n")
        for path in (py, js):
            self.assertFalse(self.rewrite(path, "cursor", docs_only=True))
        self.assertEqual(py.read_text(), 'NAME = "Claude Code"  # run /compact\n')
        self.assertTrue(self.rewrite(md, "cursor", docs_only=True))
        self.assertEqual(md.read_text(), "Cursor\n")
        # The install-time package sanitizer (docs_only=False) still rewrites code.
        self.assertTrue(self.rewrite(js, "codex"))
        self.assertIn("$HOME/.codex/x", js.read_text())

    def test_hooks_files_keep_runtime_placeholders(self):
        p = self.write("hooks/a.sh", "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        self.assertFalse(self.rewrite(p, "claude"))
        self.assertEqual(p.read_text(), "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        q = self.write("lib/a.sh", "${SB_RUNTIME_HOME_ROOT}/x $HOME/.codex/y")
        self.assertTrue(self.rewrite(q, "claude"))
        self.assertEqual(q.read_text(), "$HOME/.claude/x $HOME/.claude/y")

    def test_read_oserror_retries_then_gives_up(self):
        p = self.write("a.md", "x")
        with mock.patch.object(pathlib.Path, "read_bytes", side_effect=OSError("io")) as rd, \
             mock.patch.object(r.time, "sleep") as sl:
            self.assertFalse(self.rewrite(p, "codex"))
        self.assertEqual(rd.call_count, 3)
        self.assertEqual([round(c.args[0], 2) for c in sl.call_args_list], [0.05, 0.1])

    def test_read_oserror_then_success(self):
        p = self.write("a.md", "$HOME/.claude/x")
        real = pathlib.Path.read_bytes
        calls = []

        def flaky(self_, *a, **k):
            calls.append(1)
            if len(calls) == 1:
                raise OSError("io")
            return real(self_, *a, **k)

        with mock.patch.object(pathlib.Path, "read_bytes", flaky), mock.patch.object(r.time, "sleep"):
            self.assertTrue(self.rewrite(p, "cursor"))
        self.assertEqual(p.read_text(), "$HOME/.cursor/x")

    def test_write_oserror_retries_then_gives_up_leaving_file(self):
        p = self.write("a.md", "$HOME/.claude/x")
        with mock.patch.object(pathlib.Path, "write_bytes", side_effect=OSError("ro")) as wr, \
             mock.patch.object(r.time, "sleep") as sl:
            self.assertFalse(self.rewrite(p, "cursor"))
        self.assertEqual((wr.call_count, sl.call_count), (3, 2))
        self.assertEqual(p.read_text(), "$HOME/.claude/x")

    def test_write_oserror_then_success(self):
        p = self.write("a.md", "$HOME/.claude/x")
        real = pathlib.Path.write_bytes
        calls = []

        def flaky(self_, *a, **k):
            calls.append(1)
            if len(calls) == 1:
                raise OSError("ro")
            return real(self_, *a, **k)

        with mock.patch.object(pathlib.Path, "write_bytes", flaky), mock.patch.object(r.time, "sleep"):
            self.assertTrue(self.rewrite(p, "cursor"))
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
        with mock.patch.object(r, "rewrite_file", side_effect=lambda path, agent, **kw: seen.append(path.name)):
            r.sanitize_root(self.tmp / "s", "codex")
        self.assertEqual(seen, ["a.md", "b.md", "c.md"])

    def test_nested_directories_are_walked_depth_first_in_name_order(self):
        for rel in ("s/b/2.md", "s/b/1.md", "s/a/x.md", "s/z.md"):
            self.write(rel, "x")
        seen = []
        with mock.patch.object(r, "rewrite_file", side_effect=lambda path, agent, **kw: seen.append(path.relative_to(self.tmp / "s").as_posix())):
            r.sanitize_root(self.tmp / "s", "codex")
        self.assertEqual(seen, ["a/x.md", "b/1.md", "b/2.md", "z.md"])

    def test_root_and_docs_only_are_passed_to_rewrite_file(self):
        self.write("s/a.md", "x")
        calls = []
        with mock.patch.object(r, "rewrite_file", side_effect=lambda path, agent, **kw: calls.append(kw)):
            r.sanitize_root(self.tmp / "s", "codex", docs_only=True)
        self.assertEqual(calls, [{"root": self.tmp / "s", "docs_only": True}])

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

    def test_source_layout_uses_hyphen_dirs_for_every_host(self):
        for host in ("claude", "codex", "cursor"):
            root = self.tmp / f"src-{host}"
            for d in ("silver", "silver-feature"):
                (root / d).mkdir(parents=True)
            r.rename_route_skill_directories(root, host=host, layout="source")
            self.assertEqual(self.names(root), ["sb", "sb-feature"])

    def test_collision_raises_render_error(self):
        root = self.tmp / "c"
        (root / "silver-x").mkdir(parents=True)
        (root / "sb-x").mkdir()
        with self.assertRaisesRegex(r.RenderError, "codex skill rename collision: silver-x -> sb-x"):
            r.rename_route_skill_directories(root, host="codex")
        self.assertTrue((root / "silver-x").is_dir())


class RenderBundleTest(TmpCase):
    def make_source(self):
        src = self.tmp / "repo" / "skills"
        self.write("repo/skills/silver-feature/SKILL.md", "---\nname: silver-feature\ndescription: d\n---\n$HOME/.claude/x\n")
        self.write("repo/skills/silver-feature/agents/openai.yaml", "model: x\n")
        self.write("repo/skills/silver-feature/notes.md", "keep ~/.claude/y\n")
        self.write("repo/skills/silver/SKILL.md", "---\nname: silver\n---\nrouter\n")
        self.write("repo/skills/helper/SKILL.md", "---\nname: helper\n---\nplain\n")
        return src

    def test_missing_source_raises_render_error(self):
        with self.assertRaisesRegex(r.RenderError, "source root missing"):
            r.render_bundle(self.tmp / "none", self.tmp / "out", "codex")
        self.assertFalse((self.tmp / "out").exists())

    def test_collision_leaves_no_staging_tree(self):
        # R8-22: a route collision used to raise SystemExit, which the cleanup
        # (except Exception) missed, leaving .<name>.staging-<pid> behind.
        src = self.make_source()
        self.write("repo/skills/sb-feature/SKILL.md", "---\nname: sb-feature\n---\n")
        dest = self.tmp / "out" / "bundle"
        with self.assertRaisesRegex(r.RenderError, "skill rename collision: silver-feature -> sb-feature"):
            r.render_bundle(src, dest, "codex")
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), [".bundle.render.lock"])

    def test_interrupt_also_cleans_staging(self):
        src = self.make_source()
        dest = self.tmp / "out" / "bundle"
        with mock.patch.object(r, "sanitize_root", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                r.render_bundle(src, dest, "codex")
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), [".bundle.render.lock"])

    def test_render_under_a_hooks_ancestor_matches_a_normal_render(self):
        # R8-04(a): the hooks check must not see directories above the render root.
        src = self.make_source()
        normal = self.tmp / "a" / "out"
        hooked = self.tmp / "hooks" / "out"
        r.render_bundle(src, normal, "codex")
        r.render_bundle(src, hooked, "codex")
        for path in sorted(normal.rglob("*")):
            if path.is_file():
                rel = path.relative_to(normal)
                self.assertEqual(path.read_bytes(), (hooked / rel).read_bytes(), rel)

    def test_render_copies_code_and_data_verbatim(self):
        src = self.make_source()
        self.write("repo/skills/silver-feature/scripts/x.py", 'HOST = "Claude Code"  # ~/.claude\n')
        dest = self.tmp / "out" / "cursor"
        r.render_bundle(src, dest, "cursor")
        self.assertEqual((dest / "sb:feature" / "scripts" / "x.py").read_text(), 'HOST = "Claude Code"  # ~/.claude\n')

    def test_emptied_agents_dir_is_removed_but_a_populated_one_is_kept(self):
        src = self.make_source()
        self.write("repo/skills/helper/agents/openai.yaml", "model: y\n")
        self.write("repo/skills/helper/agents/other.md", "keep\n")
        dest = self.tmp / "out" / "claude"
        r.render_bundle(src, dest, "claude")
        self.assertFalse((dest / "sb:feature" / "agents").exists())
        self.assertEqual(sorted(p.name for p in (dest / "helper" / "agents").iterdir()), ["other.md"])

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

    def test_render_source_layout_mode(self):
        self.write("src/silver-x/SKILL.md", "---\nname: silver-x\n---\n")
        rc, _ = self.run_main("render", "--agent", "cursor", "--layout", "source",
                              "--source-root", str(self.tmp / "src"), "--dest-root", str(self.tmp / "dest"))
        self.assertEqual(rc, 0)
        self.assertTrue((self.tmp / "dest" / "sb-x" / "SILVER_SOURCE").is_file())

    def test_render_collision_reports_error_instead_of_traceback(self):
        self.write("src/silver-x/SKILL.md", "---\nname: silver-x\n---\n")
        self.write("src/sb-x/SKILL.md", "---\nname: sb-x\n---\n")
        rc, err = self.run_main("render", "--agent", "codex", "--source-root", str(self.tmp / "src"),
                                "--dest-root", str(self.tmp / "dest"))
        self.assertEqual(rc, 1)
        self.assertEqual(err, "ERROR: render failed: codex skill rename collision: silver-x -> sb-x\n")
        self.assertEqual(sorted(p.name for p in self.tmp.iterdir() if "staging" in p.name), [])

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
