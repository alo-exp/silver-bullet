#!/usr/bin/env python3
"""Resolve sibling skill script directories across install layouts."""

from __future__ import annotations

import sys
from pathlib import Path


def resolve_skill_scripts(skill_name: str, marker: str = "__init__.py") -> Path:
    """Return scripts/ dir for skill_name; marker file must exist (use multi_ai_core.py etc.)."""
    # Allow overriding marker for skills without __init__
    here = Path(__file__).resolve().parent
    skill_dir = here.parent
    alt_names = [skill_name]
    if skill_name.startswith("silver-"):
        alt_names.append("silver:" + skill_name.removeprefix("silver-"))

    for name in alt_names:
        sibling = skill_dir.parent / name / "scripts"
        probe = sibling / marker
        if probe.is_file():
            return sibling

    for parent in here.parents:
        candidate = parent / "skills" / skill_name / "scripts"
        probe = candidate / marker
        if probe.is_file():
            return candidate

    raise FileNotFoundError(
        f"{marker} not found for skill {skill_name!r} beside install or under skills/"
    )


def ensure_scripts_on_path(skill_name: str, marker: str) -> Path:
    """Resolve skill scripts/ and prepend it to sys.path once."""
    return ensure_dir_on_path(resolve_skill_scripts(skill_name, marker=marker))


def ensure_dir_on_path(directory: Path) -> Path:
    """Prepend a directory to sys.path once (local scripts/ or resolved sibling)."""
    scripts_s = str(directory.resolve())
    if scripts_s not in sys.path:
        sys.path.insert(0, scripts_s)
    return directory


def resolve_multi_ai_scripts() -> Path:
    """Prefer the authored skills/ tree so thin agent mirrors still get landscape builders."""
    here = Path(__file__).resolve().parent
    if (here / "synthesize_landscape.py").is_file() and (here / "landscape_preview_render.py").is_file():
        return here
    for parent in here.parents:
        candidate = parent / "skills" / "silver-deep-research-multi-ai" / "scripts"
        if (candidate / "synthesize_landscape.py").is_file():
            return candidate
    return here


def ensure_multi_ai_scripts_on_path() -> Path:
    """Prepend canonical multi-AI skill scripts (synthesize / materialize / SPA render)."""
    return ensure_dir_on_path(resolve_multi_ai_scripts())


