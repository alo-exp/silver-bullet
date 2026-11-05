#!/usr/bin/env python3
"""Atomic, ownership-aware writes for generated research artifacts.

A research directory holds both this skill's generated artifacts and files the host
controller or the user wrote (hand-written SCRs, notes, a synthesis worker's landscape
report). Every artifact written through ``write_generated_text`` is recorded in
``generated-files.json`` with its SHA-256. A later run replaces a file only when it is
absent or still byte-identical to what this tool wrote; anything else is preserved, never
overwritten or deleted, and the caller reports it.

All writes are atomic (temp file in the same directory, then ``os.replace``), stay inside
the research directory (a symlinked parent that escapes it is refused) and replace a
symlink at the target path rather than writing through it.
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import math
import os
import stat
import tempfile
from pathlib import Path
from typing import Any

REGISTRY_NAME = "generated-files.json"


def json_safe(value: Any) -> Any:
    """Copy of value with non-finite floats (NaN, Infinity) replaced by None.

    Python's json reads and re-emits NaN/Infinity, which strict JSON parsers (JSON.parse
    in the report viewer) reject, so one model emitting NaN could blank a report (R12-28).
    """
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    return value


def strict_json_dumps(value: Any, **kwargs: Any) -> str:
    """json.dumps of json_safe(value) that can never emit NaN/Infinity."""
    return json.dumps(json_safe(value), allow_nan=False, **kwargs)


def _default_mode() -> int:
    mask = os.umask(0)
    os.umask(mask)
    return 0o666 & ~mask


def atomic_write_text(path: Path, text: str) -> None:
    """Write `text` to `path` via a temp file and rename; keep an existing file's mode."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = _default_mode()
    if path.is_file() and not path.is_symlink():
        mode = stat.S_IMODE(path.stat().st_mode)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative_path(root: Path, path: Path) -> str:
    """`path` relative to `root`; refuses targets whose real parent leaves the root."""
    root_real = Path(root).resolve()
    parent_real = Path(path).parent.resolve()
    if parent_real != root_real and root_real not in parent_real.parents:
        raise ValueError(f"refusing to write outside the research directory: {path}")
    return (parent_real / Path(path).name).relative_to(root_real).as_posix()


def load_registry(root: Path) -> dict[str, str]:
    path = Path(root) / REGISTRY_NAME
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    files = data.get("files") if isinstance(data, dict) else None
    return {str(k): str(v) for k, v in files.items()} if isinstance(files, dict) else {}


def _save_registry(root: Path, files: dict[str, str]) -> None:
    payload = {
        "schema_id": "sb-generated-files-v1",
        "note": "Files this skill generated, by SHA-256. A file is regenerated only while it still matches.",
        "files": dict(sorted(files.items())),
    }
    atomic_write_text(Path(root) / REGISTRY_NAME, json.dumps(payload, indent=2) + "\n")


def is_replaceable(root: Path, path: Path) -> bool:
    """True when `path` is absent or byte-identical to the copy this tool last wrote."""
    path = Path(path)
    if path.is_symlink():
        return False
    if not path.exists():
        return True
    if not path.is_file():
        return False
    recorded = load_registry(root).get(relative_path(root, path))
    return recorded is not None and recorded == _sha256(path.read_bytes())


def write_generated_text(root: Path, path: Path, text: str, *, preserved: list[str] | None = None) -> bool:
    """Write a generated artifact unless a host/user-authored file is in the way.

    Returns True when written. When the existing file is not ours, leaves it untouched,
    appends its relative path to `preserved` (if given) and returns False.
    """
    rel = relative_path(root, path)
    if not is_replaceable(root, path):
        if preserved is not None:
            preserved.append(rel)
        return False
    atomic_write_text(path, text)
    files = load_registry(root)
    files[rel] = _sha256(text.encode("utf-8"))
    _save_registry(root, files)
    return True


def adopt_generated(root: Path, path: Path) -> None:
    """Record a file another generator wrote this run (e.g. compare_solutions) as ours."""
    path = Path(path)
    if not path.is_file() or path.is_symlink():
        return
    files = load_registry(root)
    files[relative_path(root, path)] = _sha256(path.read_bytes())
    _save_registry(root, files)
