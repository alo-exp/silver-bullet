#!/usr/bin/env python3
"""Detect and strip LeanCTX / Context Mode compression markers from durable text.

Patterns align with hooks/compression-marker-guard.sh — block the same artifacts
that must never appear in research reports, landscape markdown, or packaged HTML.
"""

from __future__ import annotations

import re
from pathlib import Path

# Detection patterns (aligned with compression-marker-guard.sh + ctx_read headers)
_MARKER_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"\[lean-ctx:", re.I),
    re.compile(r"\.\.\.\s*\[lean-ctx:", re.I),
    re.compile(r"^\s*\S+\s*\[\d+L\]\s*$", re.M),
    re.compile(r"\[\d+ more lines\]", re.I),
    re.compile(r"\[Archived\]", re.I),
    re.compile(r"omitted \d+ lines", re.I),
)

# Whole-line artifacts dropped during sanitization
_DROP_LINE_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"^\s*\S+\s*\[\d+L\]\s*$"),
    re.compile(r"^\s*\[\d+ more lines\]\s*$", re.I),
    re.compile(r"^\s*\.\.\.\s*\[lean-ctx:.*\]\s*$", re.I),
    re.compile(r"^\s*\[lean-ctx:.*\]\s*$", re.I),
    re.compile(r"^\s*\[Archived\]\s*$", re.I),
)

_INLINE_STRIP = re.compile(
    r"\.\.\.\s*\[lean-ctx:[^\]]*\]|\[lean-ctx:[^\]]*\]|\[Archived\]",
    re.I,
)


def contains_compression_markers(text: str) -> bool:
    if not text:
        return False
    return any(pattern.search(text) for pattern in _MARKER_PATTERNS)


def find_compression_marker_snippets(text: str, *, limit: int = 3) -> list[str]:
    snippets: list[str] = []
    for line in text.splitlines():
        if any(pattern.search(line) for pattern in _MARKER_PATTERNS):
            snippets.append(line.strip()[:120])
        if len(snippets) >= limit:
            break
    return snippets


def sanitize_compression_markers(text: str) -> str:
    """Remove compression marker lines and inline marker segments."""
    if not text or not contains_compression_markers(text):
        return text
    kept: list[str] = []
    for line in text.splitlines():
        if any(pattern.match(line) for pattern in _DROP_LINE_PATTERNS):
            continue
        if contains_compression_markers(line):
            cleaned = _INLINE_STRIP.sub("", line).strip()
            if cleaned and not contains_compression_markers(cleaned):
                kept.append(cleaned)
            continue
        kept.append(line)
    return "\n".join(kept)


def assert_no_compression_markers(text: str, *, context: str = "durable artifact") -> None:
    if contains_compression_markers(text):
        samples = find_compression_marker_snippets(text)
        raise ValueError(
            f"compression markers in {context}: "
            + "; ".join(samples or ["(marker detected)"])
        )


def assert_file_free_of_compression_markers(path: Path | str, *, label: str | None = None) -> None:
    p = Path(path)
    if not p.is_file():
        return
    text = p.read_text(encoding="utf-8")
    assert_no_compression_markers(text, context=label or str(p))
