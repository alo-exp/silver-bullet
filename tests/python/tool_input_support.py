"""Run the hooks/lib/tool-input/*.py helper scripts in-process for unit tests.

The helpers are argv-driven scripts (``python3 helper.py ARG...``) sourced by
hooks/lib/tool-input.sh. Running them through ``runpy`` keeps them measurable by
coverage.py in-process and returns the script globals so individual helper
functions can be exercised directly afterwards.
"""

from __future__ import annotations

import contextlib
import io
import runpy
import sys
from dataclasses import dataclass, field

from sbtest import REPO_ROOT

TOOL_INPUT_DIR = REPO_ROOT / "hooks" / "lib" / "tool-input"


@dataclass
class ScriptResult:
    code: int
    stdout: str
    globals: dict = field(default_factory=dict)

    @property
    def lines(self) -> list[str]:
        return self.stdout.splitlines()


def run_tool_input_script(name: str, *args: str) -> ScriptResult:
    """Execute hooks/lib/tool-input/<name> with argv and capture exit code + stdout."""
    path = TOOL_INPUT_DIR / name
    saved_argv = sys.argv[:]
    buf = io.StringIO()
    code = 0
    script_globals: dict = {}
    sys.argv = [str(path), *args]
    try:
        with contextlib.redirect_stdout(buf):
            script_globals = runpy.run_path(str(path), run_name="__main__")
    except SystemExit as exc:  # scripts signal their verdict through SystemExit
        if exc.code is None:
            code = 0
        elif isinstance(exc.code, int):
            code = exc.code
        else:
            code = 1
    finally:
        sys.argv = saved_argv
    return ScriptResult(code=code, stdout=buf.getvalue(), globals=script_globals)
