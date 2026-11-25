"""scripts/lib/prune-claude-settings.py: only stale Silver Bullet hooks are pruned (R7-12, R8-16).

The command-line behaviour (atomic rewrite, refusals, foreign data) is covered by
tests/scripts/test-prune-stale-claude-user-hooks.sh; this pins the predicate itself.
"""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

prune = load_module("scripts/lib/prune-claude-settings.py")


class StaleSbHookTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.cache = Path(tmp.name) / "plugins" / "cache" / "alo-labs" / "silver-bullet"
        (self.cache / "1.0.0" / "hooks").mkdir(parents=True)
        (self.cache / "1.0.0" / "hooks" / "stop-check.sh").write_text("#!/bin/sh\n")

    def stale(self, command):
        return prune.stale_sb_hook({"type": "command", "command": command})

    def test_only_missing_silver_bullet_scripts_are_stale(self):
        self.assertTrue(self.stale(f'"{self.cache}/0.9.0/hooks/stop-check.sh"'))
        self.assertTrue(self.stale('"${CLAUDE_PLUGIN_ROOT}/hooks/session-start"'))
        self.assertFalse(self.stale(f'"{self.cache}/1.0.0/hooks/stop-check.sh"'))
        for foreign in ('node "$HOME/.claude/hooks/my-hook.js"', '"${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh"',
                        "bash gsd-session-state.sh", "bash ~/.claude/hooks/gsd-statusline.sh",
                        '"${CLAUDE_PLUGIN_ROOT}/hooks/other-plugin.sh"', "/usr/bin/true", 42, None):
            self.assertFalse(self.stale(foreign), foreign)
        self.assertFalse(prune.stale_sb_hook("not-a-dict"))

    def test_paths_that_cannot_be_judged_are_kept(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SB_NOT_SET_ROOT", None)
            self.assertFalse(self.stale('"${SB_NOT_SET_ROOT}/plugins/cache/m/silver-bullet/1/hooks/x.sh"'))
        self.assertFalse(self.stale("rel/plugins/cache/m/silver-bullet/1/hooks/x.sh"))

    def test_missing_settings_prunes_nothing(self):
        self.assertEqual(prune.prune(str(self.cache / "absent.json")), 0)


if __name__ == "__main__":
    unittest.main()
