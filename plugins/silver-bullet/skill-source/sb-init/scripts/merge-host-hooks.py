#!/usr/bin/env python3
"""Delegate to installer lib (host-neutral shim for skill bundle layout)."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[3]
matches = sorted((root / "scripts/lib").glob("install-*/merge-*-hooks.py"))
if not matches:
    raise SystemExit("merge-host-hooks shim: no installer hook merge script found")
_LIB = matches[-1]
sys.argv = [_LIB.name, *sys.argv[1:]]
runpy.run_path(str(_LIB), run_name="__main__")
