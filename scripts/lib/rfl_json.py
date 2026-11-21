#!/usr/bin/env python3
"""Size- and depth-bounded JSON reads for review-fix-ladder artifacts.

Every RFL artifact is read through here: a hostile or corrupt file (huge, 200k levels deep,
not UTF-8, a symlink to something else) is reported as an error, never as an exception that a
caller might swallow into "no problem" (R4-15), and never as unbounded work.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

MAX_BYTES = 1_000_000
MAX_DEPTH = 32


class BadJson(ValueError):
    """The file is missing, too large, too deep, not valid JSON, or not an object."""


def depth_of(value: Any, limit: int = MAX_DEPTH) -> int:
    """Nesting depth of ``value`` (iterative, stops counting past ``limit``)."""
    deepest = 0
    stack: list[tuple[Any, int]] = [(value, 1)]
    while stack:
        item, level = stack.pop()
        if isinstance(item, dict):
            children = list(item.values())
        elif isinstance(item, list):
            children = item
        else:
            continue
        deepest = max(deepest, level)
        if deepest > limit:
            return deepest
        stack.extend((child, level + 1) for child in children)
    return deepest


def loads_bounded(text: str, *, max_bytes: int = MAX_BYTES, max_depth: int = MAX_DEPTH) -> dict[str, Any]:
    if len(text.encode("utf-8", "replace")) > max_bytes:
        raise BadJson(f"JSON larger than {max_bytes} bytes")
    try:
        value = json.loads(text)
    except (ValueError, RecursionError) as exc:
        raise BadJson(f"invalid JSON ({type(exc).__name__})") from exc
    if not isinstance(value, dict):
        raise BadJson("JSON is not an object")
    if depth_of(value, max_depth) > max_depth:
        raise BadJson(f"JSON nested deeper than {max_depth}")
    return value


def read_bounded(path: Path, *, max_bytes: int = MAX_BYTES, max_depth: int = MAX_DEPTH) -> dict[str, Any]:
    target = Path(path)
    if target.is_symlink() or not target.is_file():
        raise BadJson(f"{target.name} is missing or not a regular file")
    try:
        size = target.stat().st_size
        if size > max_bytes:
            raise BadJson(f"{target.name} larger than {max_bytes} bytes")
        text = target.read_text(encoding="utf-8")
    except (OSError, ValueError) as exc:
        raise BadJson(f"{target.name} unreadable ({type(exc).__name__})") from exc
    return loads_bounded(text, max_bytes=max_bytes, max_depth=max_depth)
