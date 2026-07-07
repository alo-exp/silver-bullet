#!/usr/bin/env python3
"""Compatibility shim — canonical generator lives in scripts/generate-cursor-hooks.py."""

from __future__ import annotations

import runpy
from pathlib import Path

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts" / "generate-cursor-hooks.py"))
