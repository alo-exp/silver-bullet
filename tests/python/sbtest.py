"""Shared helpers for Python unit tests under tests/python.

Repository scripts often have hyphenated file names or live outside a package,
so tests import them by path with ``load_module``.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

REPO_ROOT = Path(__file__).resolve().parents[2]


def load_module(rel_path: str, name: str | None = None) -> ModuleType:
    """Import a repository Python file by its repo-relative path."""
    path = REPO_ROOT / rel_path
    mod_name = name or "sbtest_" + path.stem.replace("-", "_")
    spec = importlib.util.spec_from_file_location(mod_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {rel_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[mod_name] = module
    parent = str(path.parent)
    if parent not in sys.path:
        sys.path.insert(0, parent)  # sibling imports used by the scripts
    spec.loader.exec_module(module)
    return module
