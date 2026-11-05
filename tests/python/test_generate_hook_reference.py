"""Unit tests for scripts/generate-hook-reference.py, on scratch hook trees."""
from __future__ import annotations

import contextlib
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path

from sbtest import REPO_ROOT, load_module

g = load_module("scripts/generate-hook-reference.py")


def command(name: str) -> str:
    return f'bash "${{CLAUDE_PLUGIN_ROOT}}/hooks/{name}"'


class Tree:
    """A scratch repository layout the generator is pointed at."""

    def __init__(self, root: Path, hooks: dict, data: dict, files=(), lib=()):
        self.root = root
        (root / "hooks" / "lib").mkdir(parents=True)
        (root / "docs").mkdir()
        (root / "hooks" / "hooks.json").write_text(json.dumps({"hooks": hooks}), encoding="utf-8")
        (root / "docs" / "hooks-purpose.json").write_text(json.dumps(data), encoding="utf-8")
        for name in files:
            (root / "hooks" / name).write_text("#!/bin/sh\n", encoding="utf-8")
        for name in lib:
            path = root / "hooks" / "lib" / name
            if name.endswith("/"):
                path.mkdir()
            else:
                path.write_text("x\n", encoding="utf-8")


class GeneratorCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def point_at(self, tree: Tree):
        saved = {k: getattr(g, k) for k in ("HOOKS_DIR", "HOOKS_JSON", "DATA_JSON", "OUT", "REPO_ROOT")}
        self.addCleanup(lambda: [setattr(g, k, v) for k, v in saved.items()])
        g.REPO_ROOT = tree.root
        g.HOOKS_DIR = tree.root / "hooks"
        g.HOOKS_JSON = g.HOOKS_DIR / "hooks.json"
        g.DATA_JSON = tree.root / "docs" / "hooks-purpose.json"
        g.OUT = tree.root / "docs" / "HOOKS.md"

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        saved = sys.argv
        sys.argv = ["generate-hook-reference.py", *argv]
        self.addCleanup(setattr, sys, "argv", saved)
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = g.main()
        sys.argv = saved
        return code, out.getvalue(), err.getvalue()


def simple_data(**extra):
    data = {"purposes": {"a.sh": "Does A | with pipe"}, "unregistered": {"README": "notes", "hooks.json": "registry"}}
    data.update(extra)
    return data


SIMPLE_HOOKS = {"PreToolUse": [{"matcher": "Bash|Edit", "hooks": [{"type": "command", "command": command("a.sh"), "timeout": 5}]}]}


class HelperTest(unittest.TestCase):
    def test_script_name_parses_and_rejects(self):
        self.assertEqual(g.script_name('bash "${CLAUDE_PLUGIN_ROOT}/hooks/sub/x.sh" --flag'), "sub/x.sh")
        with self.assertRaises(SystemExit) as ctx:
            g.script_name("echo nothing")
        self.assertIn("cannot parse hook command: echo nothing", str(ctx.exception))

    def test_md_cell_escapes_pipes(self):
        self.assertEqual(g.md_cell("a|b"), "a\\|b")


class LibEntriesTest(GeneratorCase):
    def test_skips_dotfiles_and_pycache_and_marks_directories(self):
        tree = Tree(self.root, {}, simple_data(), lib=[".hidden", "__pycache__/", "b.sh", "sub/", "a.sh"])
        self.point_at(tree)
        self.assertEqual(g.lib_entries(), ["a.sh", "b.sh", "sub/"])


class RenderTest(GeneratorCase):
    def render(self, hooks, data, files=("a.sh",), lib=()):
        tree = Tree(self.root, hooks, data, files=files, lib=lib)
        self.point_at(tree)
        return g.render()

    def test_clean_tree_renders_tables(self):
        text, problems = self.render(SIMPLE_HOOKS, simple_data(wiring=["Wired by hooks.json."]), files=("a.sh", "README"))
        self.assertEqual(problems, [])
        self.assertIn("registers **1 hook commands** backed by **1 scripts** across 1 events. No registrations are async", text)
        self.assertIn("- Wired by hooks.json.", text)
        self.assertIn("| 1 | `Bash\\|Edit` | `a.sh` | 5 |", text)
        self.assertIn("| `a.sh` | PreToolUse `Bash\\|Edit` | Does A \\| with pipe |", text)
        self.assertIn("| `README` | notes |", text)
        self.assertNotIn("event_notes", text)

    def test_event_notes_async_flag_and_default_matcher(self):
        hooks = {
            "Stop": [
                {"hooks": [
                    {"type": "command", "command": command("a.sh"), "async": True},
                    {"type": "command", "command": command("a.sh")},
                ]},
            ],
        }
        text, problems = self.render(hooks, simple_data(event_notes={"Stop": "Stop note."}), files=("a.sh", "README"))
        self.assertEqual(problems, [])
        self.assertIn("### Stop\n\nStop note.\n\n| # | Matcher", text)
        self.assertIn("| 1 | `*` | `a.sh` (async) |  |", text)
        self.assertIn("| 2 | `*` | `a.sh` |  |", text)
        self.assertIn("1 registration is async", text)
        # The same script on the same event and matcher is listed once.
        self.assertEqual(text.count("| `a.sh` | Stop `*` |"), 1)

    def test_several_async_registrations_are_plural(self):
        hooks = {"Stop": [{"hooks": [
            {"command": command("a.sh"), "async": True},
            {"command": command("a.sh"), "async": True},
        ]}]}
        text, _ = self.render(hooks, simple_data())
        self.assertIn("2 registrations are async", text)

    def test_registered_script_without_purpose_or_file(self):
        hooks = {"Stop": [{"hooks": [{"command": command("ghost.sh")}]}]}
        _, problems = self.render(hooks, {"purposes": {}, "unregistered": {}}, files=())
        self.assertIn("registered hook has no purpose in docs/hooks-purpose.json: ghost.sh", problems)
        self.assertIn("hooks.json registers a missing file: hooks/ghost.sh", problems)

    def test_purpose_for_unregistered_script(self):
        data = simple_data()
        data["purposes"]["stale.sh"] = "stale"
        _, problems = self.render(SIMPLE_HOOKS, data, files=("a.sh", "README"))
        self.assertEqual(
            problems,
            ["docs/hooks-purpose.json has a purpose for a script hooks.json does not register: stale.sh"],
        )

    def test_unregistered_entry_for_missing_file(self):
        _, problems = self.render(SIMPLE_HOOKS, simple_data(), files=("a.sh",))
        self.assertEqual(problems, ["docs/hooks-purpose.json describes a missing file: hooks/README"])

    def test_file_neither_registered_nor_described(self):
        tree = Tree(self.root, SIMPLE_HOOKS, simple_data(), files=("a.sh", "README", "stray.sh", ".dotfile"))
        (tree.root / "hooks" / "subdir").mkdir()
        self.point_at(tree)
        _, problems = g.render()
        self.assertEqual(
            problems,
            ["hooks/stray.sh is neither registered in hooks.json nor described in docs/hooks-purpose.json"],
        )

    def test_lib_groups_other_and_footer(self):
        data = simple_data(
            lib_groups=[
                {"title": "Core", "members": ["a.sh", "missing.sh"]},
                {"title": "Empty", "members": ["nope.sh"]},
            ],
            lib_footer="Footer text.",
        )
        text, problems = self.render(SIMPLE_HOOKS, data, files=("a.sh", "README"), lib=["a.sh", "z.sh", "dir/"])
        self.assertEqual(
            problems,
            [
                "docs/hooks-purpose.json lib_groups lists a missing hooks/lib entry: missing.sh",
                "docs/hooks-purpose.json lib_groups lists a missing hooks/lib entry: nope.sh",
            ],
        )
        self.assertIn("- **Core:** `a.sh`", text)
        self.assertNotIn("**Empty:**", text)
        self.assertIn("- **Other:** `dir/`, `z.sh`", text)
        self.assertTrue(text.rstrip("\n").endswith("Footer text."))

    def test_no_other_lib_entries_and_no_footer(self):
        data = simple_data(lib_groups=[{"title": "Core", "members": ["a.sh"]}])
        text, problems = self.render(SIMPLE_HOOKS, data, files=("a.sh", "README"), lib=["a.sh"])
        self.assertEqual(problems, [])
        self.assertNotIn("**Other:**", text)
        self.assertNotIn("Footer", text)


class MainTest(GeneratorCase):
    def tree(self, **kwargs):
        tree = Tree(self.root, SIMPLE_HOOKS, simple_data(), files=("a.sh", "README"), **kwargs)
        self.point_at(tree)
        return tree

    def test_write_then_check_up_to_date(self):
        self.tree()
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("Wrote docs/HOOKS.md", out)
        self.assertIn("# Hook Reference", g.OUT.read_text(encoding="utf-8"))
        code, out, err = self.run_main("--check")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("docs/HOOKS.md is up to date", out)

    def test_check_reports_stale_and_missing_output(self):
        self.tree()
        code, out, err = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("docs/HOOKS.md is out of date", err)
        self.assertFalse(g.OUT.exists())
        g.OUT.write_text("old\n", encoding="utf-8")
        code, _, err = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("out of date", err)
        self.assertEqual(g.OUT.read_text(encoding="utf-8"), "old\n")

    def test_problems_fail_both_modes_without_writing(self):
        tree = self.tree()
        (tree.root / "hooks" / "stray.sh").write_text("x", encoding="utf-8")
        for argv in ((), ("--check",)):
            code, out, err = self.run_main(*argv)
            self.assertEqual(code, 1)
            self.assertEqual(out, "")
            self.assertIn("ERROR: hooks/stray.sh is neither registered", err)
        self.assertFalse(g.OUT.exists())


class EntryPointTest(unittest.TestCase):
    def test_script_run_as_main_checks_the_real_reference(self):
        saved = sys.argv
        sys.argv = ["generate-hook-reference.py", "--check"]
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as ctx:
                runpy.run_path(str(REPO_ROOT / "scripts" / "generate-hook-reference.py"), run_name="__main__")
        finally:
            sys.argv = saved
        self.assertEqual(ctx.exception.code, 0)
        self.assertIn("up to date", out.getvalue())


if __name__ == "__main__":
    unittest.main()
