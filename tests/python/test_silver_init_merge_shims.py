"""skills/silver-init/scripts/merge-hooks.py and merge-host-hooks.py are host-neutral shims.

They locate the installer implementation under scripts/lib/install-*/ and run it with the
caller's arguments. The in-process tests execute the shim source with a recording stand-in
for ``runpy.run_path``; the subprocess tests run the real shims against a throwaway HOME
and a throwaway install tree, so no user hook configuration is ever touched.
"""

from __future__ import annotations

import contextlib
import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT

SCRIPTS = REPO_ROOT / "skills" / "silver-init" / "scripts"
CLAUDE_SHIM = SCRIPTS / "merge-hooks.py"
HOST_SHIM = SCRIPTS / "merge-host-hooks.py"
CLAUDE_LIB = REPO_ROOT / "scripts" / "lib" / "install-claude" / "merge-hooks.py"
CURSOR_LIB = REPO_ROOT / "scripts" / "lib" / "install-cursor" / "merge-cursor-hooks.py"


def exec_shim(shim: Path, argv: list[str], *, glob_result: list[Path] | None = None):
    """Run the shim source in-process; returns (run_path mock, resulting sys.argv)."""
    code = compile(shim.read_text(encoding="utf-8"), str(shim), "exec")
    namespace = {"__name__": "__main__", "__file__": str(shim)}
    seen: dict[str, list[str]] = {}

    def record(path: str, run_name: str | None = None):  # noqa: ANN202
        seen["argv"] = list(sys.argv)
        return {}

    patches = [mock.patch.object(sys, "argv", [str(shim), *argv]), mock.patch.object(runpy, "run_path", side_effect=record)]
    if glob_result is not None:
        patches.append(mock.patch.object(Path, "glob", return_value=glob_result))
    with contextlib.ExitStack() as stack:
        recorded = [stack.enter_context(p) for p in patches]
        exec(code, namespace)  # noqa: S102 - executes the repository's own shim
    return recorded[1], seen["argv"]


class ShimDelegationTests(unittest.TestCase):
    def test_claude_shim_runs_the_claude_installer_lib_with_forwarded_args(self) -> None:
        run_path, argv = exec_shim(CLAUDE_SHIM, ["/some/install"])
        run_path.assert_called_once_with(str(CLAUDE_LIB), run_name="__main__")
        self.assertEqual(argv, ["merge-hooks.py", "/some/install"])

    def test_host_shim_runs_the_last_matching_host_lib(self) -> None:
        run_path, argv = exec_shim(HOST_SHIM, ["/some/install", "extra"])
        run_path.assert_called_once_with(str(CURSOR_LIB), run_name="__main__")
        self.assertEqual(argv, ["merge-cursor-hooks.py", "/some/install", "extra"])

    def test_host_shim_prefers_the_last_sorted_match(self) -> None:
        fake = [Path("/x/install-a/merge-a-hooks.py"), Path("/x/install-z/merge-z-hooks.py")]
        run_path, argv = exec_shim(HOST_SHIM, [], glob_result=fake)
        run_path.assert_called_once_with("/x/install-z/merge-z-hooks.py", run_name="__main__")
        self.assertEqual(argv, ["merge-z-hooks.py"])

    def test_claude_shim_takes_the_first_sorted_match(self) -> None:
        fake = [Path("/x/install-b/merge-hooks.py"), Path("/x/install-a/merge-hooks.py")]
        run_path, _ = exec_shim(CLAUDE_SHIM, [], glob_result=fake)
        run_path.assert_called_once_with("/x/install-a/merge-hooks.py", run_name="__main__")

    def test_missing_installer_lib_exits_with_a_message(self) -> None:
        with self.assertRaises(SystemExit) as claude:
            exec_shim(CLAUDE_SHIM, ["/i"], glob_result=[])
        self.assertEqual(claude.exception.code, "merge-hooks shim: no installer merge-hooks.py found")
        with self.assertRaises(SystemExit) as host:
            exec_shim(HOST_SHIM, ["/i"], glob_result=[])
        self.assertEqual(host.exception.code, "merge-host-hooks shim: no installer hook merge script found")


class ShimEndToEndTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.install = self.tmp / "install"
        (self.install / "hooks").mkdir(parents=True)

    def run_shim(self, shim: Path, *args: str) -> subprocess.CompletedProcess[str]:
        env = {"PATH": os.environ.get("PATH", ""), "HOME": str(self.home), "TMPDIR": str(self.tmp)}
        return subprocess.run(
            [sys.executable, str(shim), *args], capture_output=True, text=True, env=env, check=False, timeout=60
        )

    # --- Claude ---------------------------------------------------------------------
    def claude_settings(self) -> Path:
        return self.home / ".claude" / "settings.json"

    def write_claude_hooks(self) -> None:
        hooks = {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/gate.sh"}]}]}}
        (self.install / "hooks" / "hooks.json").write_text(json.dumps(hooks))

    def test_claude_fresh_install_substitutes_the_plugin_root(self) -> None:
        self.write_claude_hooks()
        # The installer lib does not create ~/.claude itself (see report); the host creates it first.
        self.claude_settings().parent.mkdir()
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        settings = json.loads(self.claude_settings().read_text())
        command = settings["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        self.assertEqual(command, f"{self.install}/hooks/gate.sh")
        self.assertEqual(settings["hooks"]["PreToolUse"][0]["matcher"], "Bash")

    def test_claude_merge_keeps_user_entries_purges_stale_and_is_idempotent(self) -> None:
        self.write_claude_hooks()
        user_hook = {"type": "command", "command": "/home/me/bin/my-hook.sh"}
        stale = {"type": "command", "command": "/old/silver-bullet/1.0.0/hooks/gate.sh"}
        self.claude_settings().parent.mkdir()
        self.claude_settings().write_text(json.dumps({
            "theme": "dark",
            "hooks": {
                "PreToolUse": [{"matcher": "Bash", "hooks": [user_hook, stale]}, "foreign-entry"],
                "Stop": [{"matcher": "", "hooks": [stale]}],
                "Notification": [{"matcher": "", "hooks": [user_hook]}],
            },
        }))
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        settings = json.loads(self.claude_settings().read_text())
        self.assertEqual(settings["theme"], "dark")
        pre = settings["hooks"]["PreToolUse"]
        self.assertIn("foreign-entry", pre)
        bash_group = next(g for g in pre if isinstance(g, dict) and g["matcher"] == "Bash")
        commands = [h["command"] for h in bash_group["hooks"]]
        self.assertEqual(commands, ["/home/me/bin/my-hook.sh", f"{self.install}/hooks/gate.sh"])
        self.assertNotIn("Stop", settings["hooks"])  # only held a stale SB entry
        self.assertEqual(settings["hooks"]["Notification"], [{"matcher": "", "hooks": [user_hook]}])
        first = self.claude_settings().read_text()
        self.assertEqual(self.run_shim(CLAUDE_SHIM, str(self.install)).returncode, 0)
        self.assertEqual(self.claude_settings().read_text(), first)

    def test_claude_malformed_settings_fail_without_touching_the_file(self) -> None:
        self.write_claude_hooks()
        self.claude_settings().parent.mkdir()
        self.claude_settings().write_text("{not json")
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("JSONDecodeError", proc.stderr)
        self.assertEqual(self.claude_settings().read_text(), "{not json")

    def test_claude_wrong_shapes_are_refused(self) -> None:
        self.write_claude_hooks()
        self.claude_settings().parent.mkdir()
        for body, message in (
            ('["array"]', "expected a JSON object at the top level"),
            ('{"hooks": "text"}', "hooks must be a JSON object"),
            ('{"hooks": {"PreToolUse": "text"}}', "PreToolUse must be a JSON array"),
        ):
            self.claude_settings().write_text(body)
            proc = self.run_shim(CLAUDE_SHIM, str(self.install))
            self.assertNotEqual(proc.returncode, 0, body)
            self.assertIn(message, proc.stderr)
            self.assertEqual(self.claude_settings().read_text(), body)

    def test_claude_missing_hooks_json_creates_no_settings(self) -> None:
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("FileNotFoundError", proc.stderr)
        self.assertFalse(self.claude_settings().exists())

    def test_claude_without_arguments_fails(self) -> None:
        proc = self.run_shim(CLAUDE_SHIM)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("IndexError", proc.stderr)

    def test_claude_symlinked_settings_are_updated_in_place(self) -> None:
        self.write_claude_hooks()
        real = self.tmp / "dotfiles" / "claude-settings.json"
        real.parent.mkdir()
        real.write_text(json.dumps({"keep": True}))
        self.claude_settings().parent.mkdir()
        self.claude_settings().symlink_to(real)
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(self.claude_settings().is_symlink())
        data = json.loads(real.read_text())
        self.assertTrue(data["keep"])
        self.assertEqual(data["hooks"]["PreToolUse"][0]["hooks"][0]["command"], f"{self.install}/hooks/gate.sh")

    def test_claude_dangling_symlink_settings_start_from_empty(self) -> None:
        self.write_claude_hooks()
        self.claude_settings().parent.mkdir()
        target = self.tmp / "dotfiles" / "new.json"
        target.parent.mkdir()
        self.claude_settings().symlink_to(target)
        proc = self.run_shim(CLAUDE_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("PreToolUse", json.loads(target.read_text())["hooks"])

    # --- Cursor (merge-host-hooks.py) -------------------------------------------------
    def cursor_settings(self) -> Path:
        return self.home / ".cursor" / "hooks.json"

    def write_cursor_hooks(self) -> None:
        hooks = {"hooks": {"preToolUse": [{"command": "${CURSOR_PLUGIN_ROOT}/hooks/gate.sh", "matcher": "Shell"}]}}
        (self.install / "hooks" / "cursor-hooks.json").write_text(json.dumps(hooks))

    def test_host_fresh_install(self) -> None:
        self.write_cursor_hooks()
        proc = self.run_shim(HOST_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("SB hooks registered in ~/.cursor/hooks.json", proc.stdout)
        settings = json.loads(self.cursor_settings().read_text())
        self.assertEqual(settings["version"], 1)
        self.assertEqual(settings["hooks"]["preToolUse"], [{"command": f"{self.install}/hooks/gate.sh", "matcher": "Shell"}])

    def test_host_merge_keeps_user_entries_and_drops_stale_and_malformed(self) -> None:
        self.write_cursor_hooks()
        user = {"command": "/home/me/my-hook.sh"}
        self.cursor_settings().parent.mkdir()
        self.cursor_settings().write_text(json.dumps({
            "version": 1,
            "custom": {"keep": 1},
            "hooks": {
                "preToolUse": [
                    user,
                    {"command": "/old/silver-bullet/1.0.0/hooks/gate.sh"},
                    {"command": "/x/codex-hook-adapter.sh"},
                    "foreign-entry",
                ],
                "stop": [{"command": "/old/silver-bullet/1.0.0/hooks/stop.sh"}],
                "sessionStart": "not-a-list",
            },
        }))
        proc = self.run_shim(HOST_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        settings = json.loads(self.cursor_settings().read_text())
        self.assertEqual(settings["custom"], {"keep": 1})
        self.assertEqual(settings["hooks"]["preToolUse"], [user, "foreign-entry", {"command": f"{self.install}/hooks/gate.sh", "matcher": "Shell"}])
        self.assertNotIn("stop", settings["hooks"])
        self.assertEqual(settings["hooks"]["sessionStart"], "not-a-list")
        first = self.cursor_settings().read_text()
        self.assertEqual(self.run_shim(HOST_SHIM, str(self.install)).returncode, 0)
        self.assertEqual(self.cursor_settings().read_text(), first)

    def test_host_malformed_and_wrong_shaped_settings_are_refused(self) -> None:
        self.write_cursor_hooks()
        self.cursor_settings().parent.mkdir()
        for body, message in (
            ("{not json", "JSONDecodeError"),
            ('"text"', "expected a JSON object at the top level"),
            ('{"hooks": "text"}', "hooks must be a JSON object"),
        ):
            self.cursor_settings().write_text(body)
            proc = self.run_shim(HOST_SHIM, str(self.install))
            self.assertNotEqual(proc.returncode, 0, body)
            self.assertIn(message, proc.stderr)
            self.assertEqual(self.cursor_settings().read_text(), body)

    def test_host_requires_an_install_path(self) -> None:
        proc = self.run_shim(HOST_SHIM)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("usage: merge-cursor-hooks.py <sb_install_path>", proc.stderr)
        self.assertFalse(self.cursor_settings().exists())

    def test_host_missing_cursor_hooks_json_creates_no_settings(self) -> None:
        proc = self.run_shim(HOST_SHIM, str(self.install))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("FileNotFoundError", proc.stderr)
        self.assertFalse(self.cursor_settings().exists())

    def test_host_symlinked_settings_are_updated_in_place(self) -> None:
        self.write_cursor_hooks()
        real = self.tmp / "dotfiles" / "cursor-hooks.json"
        real.parent.mkdir()
        real.write_text(json.dumps({"version": 1, "hooks": {"stop": [{"command": "/mine.sh"}]}}))
        self.cursor_settings().parent.mkdir()
        self.cursor_settings().symlink_to(real)
        proc = self.run_shim(HOST_SHIM, str(self.install))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(self.cursor_settings().is_symlink())
        data = json.loads(real.read_text())
        self.assertEqual(data["hooks"]["stop"], [{"command": "/mine.sh"}])
        self.assertIn("preToolUse", data["hooks"])


if __name__ == "__main__":
    unittest.main()
