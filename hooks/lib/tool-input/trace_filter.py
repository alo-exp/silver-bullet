"""Filter an agent write trace (``files-written.<epoch>``, hooks/lib/agent-writes.sh) on a session rotation.

``trace_filter.py ROOT OLD NEW TRACE`` keeps an entry of TRACE only when it still describes pending work in the
project at ROOT: its path is under ROOT, it is still dirty there (modified or untracked per ``git status``), and it is
not part of the move from commit OLD to commit NEW (``git diff --name-only OLD NEW``; nothing moved when OLD is empty,
equal to NEW or unknown). A ``*`` entry cannot be checked against a path and is dropped. ``d`` and ``t`` entries and
entries with a glob character cover the paths below them (fixed-string prefix match). The trace is rewritten
atomically, or removed when nothing is kept. Any failure leaves the trace as it was and exits 1 (keeping a trace is
the conservative outcome).
"""

from __future__ import annotations

import bisect
import os
import subprocess
import sys
import tempfile

GIT_SECONDS = 15
GLOB_CHARS = "*?["


def _git(root, *args):
    out = subprocess.run(["git", "-C", root, *args], capture_output=True, timeout=GIT_SECONDS, check=True)
    return out.stdout


def dirty_paths(root):
    """Paths git reports as modified or untracked, relative to ROOT. Untracked directories end in ``/``."""
    records = _git(root, "status", "--porcelain=v1", "-z", "--untracked-files=normal").split(b"\0")
    paths = []
    i = 0
    while i < len(records):
        rec = records[i]
        i += 1
        if len(rec) < 4:
            continue
        paths.append(os.fsdecode(rec[3:]))
        if rec[0:1] in b"RC" or rec[1:2] in b"RC":
            # a rename or copy record is followed by a second NUL field: the old path
            if i < len(records) and records[i]:
                paths.append(os.fsdecode(records[i]))
            i += 1
    return paths


def moved_paths(root, old, new):
    if not old or not new or old == new:
        return []
    try:
        out = _git(root, "diff", "--name-only", "-z", old, new)
    except (subprocess.SubprocessError, OSError):
        return []
    return [os.fsdecode(p) for p in out.split(b"\0") if p]


class PathSet:
    """Sorted paths with exact, prefix and directory-ancestor queries."""

    def __init__(self, paths):
        self.members = set(paths)
        self.paths = sorted(self.members)
        self.dirs = [p for p in self.paths if p.endswith("/")]

    def has_exact(self, path):
        return path in self.members or any(path.startswith(d) for d in self.dirs)

    def has_under(self, prefix):
        i = bisect.bisect_left(self.paths, prefix)
        if i < len(self.paths) and self.paths[i].startswith(prefix):
            return True
        return any(prefix.startswith(d) for d in self.dirs)


def relative(path, roots):
    for root in roots:
        base = root.rstrip("/") + "/"
        if path.startswith(base):
            return path[len(base):]
    return None


def parse(line, roots):
    """(prefix_mode, relative_path) for a trace line, or None when it cannot be checked against a path."""
    if line == "*" or len(line) < 2:
        return None
    kind, path = line[0], line[1:]
    # d and t entries name a path literally; an f entry with a glob character covers what its static part leads to
    cut = min((path.find(c) for c in GLOB_CHARS if c in path), default=-1) if kind == "f" else -1
    prefix = kind in "dt" or cut >= 0
    if cut >= 0:
        path = path[:cut]
    rel = relative(path, roots) if path else None
    if rel is None:
        return None
    if kind in "dt" and rel:
        rel = rel.rstrip("/") + "/"
    return prefix, rel


def keep_entry(line, roots, dirty, moved):
    parsed = parse(line, roots)
    if parsed is None:
        return False
    prefix, rel = parsed
    if prefix:
        return dirty.has_under(rel) and not moved.has_under(rel)
    return dirty.has_exact(rel) and rel not in moved.members


def filter_trace(root, old, new, trace):
    with open(trace, "rb") as handle:
        lines = [os.fsdecode(x) for x in handle.read().split(b"\n") if x]
    roots = [root, os.path.realpath(root)]
    dirty = PathSet(dirty_paths(root))
    moved = PathSet(moved_paths(root, old, new))
    kept = [line for line in lines if keep_entry(line, roots, dirty, moved)]
    if not kept:
        os.unlink(trace)
        return
    fd, tmp = tempfile.mkstemp(prefix=os.path.basename(trace) + ".", dir=os.path.dirname(trace))
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(os.fsencode("\n".join(kept) + "\n"))
        os.replace(tmp, trace)
    except OSError:
        os.unlink(tmp)
        raise


def main(argv):
    if len(argv) != 5:
        return 2
    try:
        filter_trace(argv[1], argv[2], argv[3], argv[4])
    except (subprocess.SubprocessError, OSError):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
