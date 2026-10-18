"""hooks/generate-cursor-hooks.py is a shim that delegates to scripts/generate-cursor-hooks.py.

The shim's delegate rewrites tracked files, so these tests execute the shim's
source with a recording stand-in for ``runpy.run_path`` instead of running it.
"""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT

SHIM = REPO_ROOT / "hooks" / "generate-cursor-hooks.py"


def run_shim(name: str) -> mock.MagicMock:
    code = compile(SHIM.read_text(encoding="utf-8"), str(SHIM), "exec")
    namespace = {"__name__": name, "__file__": str(SHIM)}
    with mock.patch.object(runpy, "run_path") as run_path:
        exec(code, namespace)  # noqa: S102 - executes the repository's own shim
    return run_path


class GenerateCursorHooksShimTest(unittest.TestCase):
    def test_main_delegates_to_the_canonical_generator(self) -> None:
        run_path = run_shim("__main__")
        run_path.assert_called_once_with(str(REPO_ROOT / "scripts" / "generate-cursor-hooks.py"))
        self.assertTrue(Path(run_path.call_args.args[0]).is_file())

    def test_import_does_not_run_the_generator(self) -> None:
        run_path = run_shim("hooks_generate_cursor_hooks")
        run_path.assert_not_called()


if __name__ == "__main__":
    unittest.main()
