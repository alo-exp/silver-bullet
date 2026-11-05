"""Shared JSONL plumbing for the research stores (sources, evidence, claims).

* Read-check-append and rewrites run under one advisory lock per run directory
  (``.jsonl.lock``), so parallel retrieval agents cannot create duplicate rows and a rewrite
  never races an append. The lock file is never replaced, so every writer locks one inode.
* Rewrites go to a temporary file in the same directory and are renamed into place: a crash
  or kill mid-write leaves the previous ledger intact.
* JSON payloads for ``add``-style commands come from ``--json -`` (stdin) or ``--json-file``
  as well as ``--json``, so untrusted web text never has to sit inside a shell quote.
"""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import json
import os
import stat
import sys
import tempfile
from typing import Iterator

LOCK_NAME = ".jsonl.lock"


class JsonlError(ValueError):
    """A JSONL file holds a line that is not a JSON object."""


def read_jsonl(path: str) -> list[dict]:
    rows: list[dict] = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise JsonlError(f"{path}:{number}: invalid JSON ({exc.msg})") from exc
            if not isinstance(row, dict):
                raise JsonlError(f"{path}:{number}: expected a JSON object")
            rows.append(row)
    return rows


def append_jsonl(path: str, obj: dict) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(obj, ensure_ascii=False) + "\n")


@contextlib.contextmanager
def locked(path: str) -> Iterator[None]:
    """Hold the run directory's store lock (exclusive) for the duration of the block."""
    directory = os.path.dirname(os.path.abspath(path))
    with open(os.path.join(directory, LOCK_NAME), "a", encoding="utf-8") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def append_unique(path: str, row: dict, key: str) -> dict | None:
    """Append ``row`` unless a row with the same ``key`` exists; return that existing row."""
    with locked(path):
        for existing in read_jsonl(path):
            if existing.get(key) == row[key]:
                return existing
        append_jsonl(path, row)
    return None


def write_jsonl_atomic(path: str, rows: list[dict]) -> None:
    """Replace ``path`` with ``rows`` via a same-directory temp file (keeps the file mode)."""
    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=directory, prefix="." + os.path.basename(path) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        if os.path.exists(path):
            os.chmod(tmp, stat.S_IMODE(os.stat(path).st_mode))
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise


def add_json_input_args(parser: argparse.ArgumentParser, help_text: str) -> None:
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--json",
        help=f"{help_text}; pass '-' to read it from stdin (use a quoted heredoc for retrieved text)",
    )
    group.add_argument("--json-file", help="Path to a file holding the JSON object")


def load_json_input(args: argparse.Namespace) -> dict:
    """Return the JSON object from --json-file, --json - (stdin) or --json; exit 1 if invalid."""
    if args.json_file:
        with open(args.json_file, encoding="utf-8") as handle:
            text = handle.read()
    elif args.json == "-":
        text = sys.stdin.read()
    else:
        text = args.json
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        print(json.dumps({"error": f"invalid JSON input: {exc.msg}"}), file=sys.stderr)
        sys.exit(1)
    if not isinstance(data, dict):
        print(json.dumps({"error": "invalid JSON input: expected an object"}), file=sys.stderr)
        sys.exit(1)
    return data
