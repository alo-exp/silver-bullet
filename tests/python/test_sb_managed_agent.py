"""Unit tests for the installer-managed Cursor subagent predicate."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from sbtest import REPO_ROOT, load_module  # noqa: E402

mod = load_module("scripts/lib/cursor-sb-agents/sb_managed_agent.py")
lib = load_module("scripts/lib/cursor-sb-agents/cursor_sb_agents_lib.py")
TEMPLATE = (REPO_ROOT / "scripts/lib/install-cursor/templates/cursor-agents/sb-agent.md.template").read_text(encoding="utf-8")


def render(model: str, effort: str = "high", prefix: str = "sb", param: str | None = None) -> tuple[str, str]:
    name = lib.agent_name(model, effort, prefix)
    return name, lib.render_agent_markdown(name, model, effort, param or model, TEMPLATE)


class PredicateTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name) / "agents"
        self.root.mkdir()

    def put(self, filename: str, text: str | bytes) -> Path:
        path = self.root / filename
        if isinstance(text, bytes):
            path.write_bytes(text)
        else:
            path.write_text(text, encoding="utf-8")
        return path

    def managed(self, path: Path) -> bool:
        return mod.is_installer_managed_agent(path, self.root)

    GOOD = (
        "---\nname: sb-x-high\ndescription: SB reusable ladder agent — x.\nmodel: m\n---\n"
        "body\n<!-- sb-managed: cursor-sb-agents -->\n"
    )

    def test_genuine_generated_output_is_managed_for_every_name_shape(self) -> None:
        for model, prefix in (
            ("composer-2.5", "sb"),
            ("gpt-5", "team"),
            ("Claude-4.5-Sonnet", "sb"),
            ("gemini 3", "sb"),
            ("opus-5", "my_team"),
        ):
            name, text = render(model, "high", prefix)
            path = self.put(f"{name}.md", text)
            self.assertTrue(self.managed(path), name)

    def test_crlf_and_trailing_whitespace_are_accepted(self) -> None:
        path = self.put("sb-x-high.md", self.GOOD.replace("\n", "\r\n"))
        self.assertTrue(self.managed(path))
        path = self.put("sb-y-high.md", self.GOOD.replace("sb-x-high", "sb-y-high").replace("---\n", "--- \n").replace("-->\n", "-->  \n\n\n"))
        self.assertTrue(self.managed(path))

    def test_bom_is_rejected(self) -> None:
        path = self.put("sb-x-high.md", b"\xef\xbb\xbf" + self.GOOD.encode("utf-8"))
        self.assertFalse(self.managed(path))

    def test_unreadable_or_malformed_files_are_not_managed(self) -> None:
        self.assertFalse(self.managed(self.put("sb-bad-high.md", b"\xff\xfe\x00bad")))  # invalid UTF-8
        (self.root / "sb-dir-high.md").mkdir()
        self.assertFalse(self.managed(self.root / "sb-dir-high.md"))  # a directory
        self.assertFalse(self.managed(self.root / "sb-missing-high.md"))  # does not exist
        self.assertFalse(self.managed(self.put("sb-empty-high.md", "")))
        self.assertFalse(self.managed(self.put("sb-nofm-high.md", "name: sb-nofm-high\n")))
        self.assertFalse(self.managed(self.put("sb-open-high.md", "---\nname: sb-open-high\ndescription: SB reusable ladder agent — x\n")))
        text = "---\nthis line has no colon\nname: sb-nocolon-high\ndescription: SB reusable ladder agent — x.\n---\n<!-- sb-managed: cursor-sb-agents -->\n"
        self.assertTrue(self.managed(self.put("sb-nocolon-high.md", text)))  # colon-less lines are ignored

    def test_each_requirement_is_enforced(self) -> None:
        self.assertFalse(self.managed(self.put("sb-x-high.md", self.GOOD.replace("name: sb-x-high", "name: sb-other-high"))))  # name != stem
        self.assertFalse(self.managed(self.put("sb-y-high.md", self.GOOD.replace("name: sb-x-high", "").replace("sb-x", "sb-y"))))  # no name
        self.assertFalse(self.managed(self.put("sb-z-high.md", self.GOOD.replace("name: sb-x-high", "name: sb-z-high").replace("SB reusable ladder agent", "Other"))))  # description
        mid = self.GOOD.replace("name: sb-x-high", "name: sb-m-high") + "trailing text\n"
        self.assertFalse(self.managed(self.put("sb-m-high.md", mid)))  # marker not last
        self.assertFalse(self.managed(self.put("sb-n-high.md", self.GOOD.replace("name: sb-x-high", "name: sb-n-high").replace("<!-- sb-managed: cursor-sb-agents -->\n", ""))))  # no marker
        # filename outside the generator's character set, everything else valid
        for bad in ("sb@evil.md", ".sb-hidden.md", "-sb.md", "sb$x.md"):
            stem = bad[:-3]
            self.assertFalse(self.managed(self.put(bad, self.GOOD.replace("sb-x-high", stem))), bad)
        self.assertFalse(self.managed(self.put("sb-x-high.txt", self.GOOD)))

    def test_location_and_links(self) -> None:
        sub = self.root / "sub"
        sub.mkdir()
        nested = sub / "sb-x-high.md"
        nested.write_text(self.GOOD, encoding="utf-8")
        self.assertFalse(self.managed(nested))
        real = self.put("sb-real-high.md", self.GOOD.replace("sb-x-high", "sb-real-high"))
        self.assertTrue(self.managed(real))
        link = self.root / "sb-link-high.md"
        link.symlink_to(real)
        self.assertFalse(self.managed(link))
        # a link whose name, description and marker all check out, pointing outside the agents dir
        outside = Path(self._tmp.name) / "elsewhere"
        outside.mkdir()
        (outside / "sb-ext-high.md").write_text(self.GOOD.replace("sb-x-high", "sb-ext-high"), encoding="utf-8")
        ext = self.root / "sb-ext-high.md"
        ext.symlink_to(outside / "sb-ext-high.md")
        self.assertFalse(self.managed(ext))

    def test_command_line_entry(self) -> None:
        real = self.put("sb-cli-high.md", self.GOOD.replace("sb-x-high", "sb-cli-high"))
        self.assertEqual(mod.main([str(real)]), 0)
        self.assertEqual(mod.main([str(self.put("note.md", "hello"))]), 1)
        self.assertEqual(mod.main([]), 2)

    def test_script_entry_point_exits_with_the_verdict(self) -> None:
        import runpy

        real = self.put("sb-run-high.md", self.GOOD.replace("sb-x-high", "sb-run-high"))
        script = str(REPO_ROOT / "scripts/lib/cursor-sb-agents/sb_managed_agent.py")
        saved = sys.argv
        try:
            sys.argv = [script, str(real)]
            with self.assertRaises(SystemExit) as ctx:
                runpy.run_path(script, run_name="__main__")
            self.assertEqual(ctx.exception.code, 0)
        finally:
            sys.argv = saved


if __name__ == "__main__":
    unittest.main()
