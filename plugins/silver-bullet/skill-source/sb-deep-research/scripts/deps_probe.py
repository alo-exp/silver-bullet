"""Shared optional-dependency probes for deep-research scripts."""
from __future__ import annotations


def openpyxl_importable() -> bool:
    try:
        import openpyxl  # noqa: F401
        return True
    except ImportError:
        return False
