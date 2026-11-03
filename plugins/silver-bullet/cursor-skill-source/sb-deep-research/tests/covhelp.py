"""Shared helpers for the coverage tests: in-process script runs, no network."""

import contextlib
import io
import runpy
import socket
import sys
from pathlib import Path
from unittest import mock

SKILL_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = SKILL_ROOT / "scripts"
EVAL = SKILL_ROOT / "eval"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


def _no_network(*args, **kwargs):
    raise AssertionError("network access attempted in a hermetic test")


_PATCHES = []


def block_network():
    """Make any socket connect fail loudly (call from setUpModule)."""
    for target in ("socket.socket.connect", "socket.create_connection"):
        p = mock.patch(target, _no_network)
        p.start()
        _PATCHES.append(p)


def unblock_network():
    while _PATCHES:
        _PATCHES.pop().stop()


def run_script(path, argv, as_main=True):
    """Run a script file in-process. Returns (exit_code, stdout, stderr)."""
    out, err = io.StringIO(), io.StringIO()
    code = 0
    with mock.patch.object(sys, "argv", [str(path)] + [str(a) for a in argv]), \
            contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            runpy.run_path(str(path), run_name="__main__" if as_main else "scriptmod")
        except SystemExit as exc:
            code = 0 if exc.code is None else exc.code  # str codes keep their message
    return code, out.getvalue(), err.getvalue()


def call_main(module, argv):
    """Call module.main() with patched argv. Returns (exit_code, stdout, stderr)."""
    out, err = io.StringIO(), io.StringIO()
    code = 0
    with mock.patch.object(sys, "argv", [module.__name__] + [str(a) for a in argv]), \
            contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            module.main()
        except SystemExit as exc:
            code = 0 if exc.code is None else exc.code  # str codes keep their message
    return code, out.getvalue(), err.getvalue()


SAMPLE_CONFIG = {
    "title": "Sample Matrix",
    "categories": [
        {"name": "Sec", "features": [
            {"name": "SSO", "priority": "Critical"},
            {"name": "Audit", "priority": "High"},
        ]},
        {"name": "Ops", "features": [
            {"name": "API", "priority": "Medium"},
            {"name": "CLI", "priority": "Low"},
        ]},
    ],
    "platforms": [
        {"name": "Alpha", "features": ["SSO", "API"]},
        {"name": "Beta", "features": ["SSO", "Audit", "API", "CLI"]},
        {"name": "Gamma", "features": []},
    ],
}


def build_sample_matrix(path, config=None):
    """Build a real XLSX with matrix_builder.build_matrix (needs openpyxl)."""
    import matrix_builder
    return matrix_builder.build_matrix(config or SAMPLE_CONFIG, str(path))
