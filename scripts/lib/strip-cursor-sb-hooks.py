#!/usr/bin/env python3
"""Remove Silver Bullet hook entries from ~/.cursor/hooks.json; preserve non-SB hooks."""

from __future__ import annotations

import contextlib
import json
import os
import pathlib
import re
import stat
import sys
import tempfile

settings_path = pathlib.Path(
    sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), ".cursor", "hooks.json")
)

SB_HOOK_RE = re.compile(r"/silver-bullet/[^/]+/hooks/")
DEV_CHECKOUT_RE = re.compile(r"/plugins/silver-bullet/hooks/")


def is_sb_hook(entry: object) -> bool:
    if not isinstance(entry, dict):
        return False
    command = entry.get("command", "")
    if not isinstance(command, str):
        return False
    if "codex-hook-adapter" in command and "cursor-hook-bridge" in command:
        return True
    if "${CURSOR_PLUGIN_ROOT}/hooks/" in command:
        return True
    if DEV_CHECKOUT_RE.search(command):
        return True
    return bool(SB_HOOK_RE.search(command))


if not settings_path.is_file():
    print(f"SKIP: no hooks file at {settings_path}")
    raise SystemExit(0)

try:
    data = json.loads(settings_path.read_text())
except json.JSONDecodeError as exc:
    raise ValueError(f"{settings_path} is not valid JSON ({exc}); left unchanged") from exc
if not isinstance(data, dict):
    raise ValueError(f"{settings_path} must contain a JSON object at the top level; left unchanged")
hooks_by_event = data.get("hooks")
if not hooks_by_event:
    hooks_by_event = {}
elif not isinstance(hooks_by_event, dict):
    raise ValueError(f"{settings_path}: 'hooks' must be a JSON object; left unchanged")
changed = False

for event_name in list(hooks_by_event.keys()):
    entries = hooks_by_event[event_name]
    if not isinstance(entries, list):
        continue
    kept = [entry for entry in entries if not is_sb_hook(entry)]
    if len(kept) == len(entries):
        continue
    changed = True
    if kept:
        hooks_by_event[event_name] = kept
    else:
        del hooks_by_event[event_name]

if changed:
    # Write a temp file in the same directory and rename it over the target so a failed write
    # never truncates the user's hooks file; follow a symlinked file and keep its permissions.
    real_path = os.path.realpath(settings_path)
    tmp_name = None
    failure = None
    try:
        fd, tmp_name = tempfile.mkstemp(prefix=".hooks.", suffix=".tmp", dir=os.path.dirname(real_path))
        with os.fdopen(fd, "w") as handle:
            handle.write(json.dumps(data, indent=2) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, stat.S_IMODE(os.stat(real_path).st_mode))
        os.replace(tmp_name, real_path)
    except OSError as exc:
        failure = exc
    finally:
        # Any exit (including KeyboardInterrupt) removes a leftover temp file; the rename
        # consumes it on success, so a missing file is expected and ignored.
        if tmp_name is not None:
            with contextlib.suppress(OSError):
                os.unlink(tmp_name)
    if failure is not None:
        print(f"ERROR: cannot update {settings_path}: {failure}; left unchanged", file=sys.stderr)
        raise SystemExit(1)
    print(f"SB hooks stripped from {settings_path}")
else:
    print(f"No SB hooks found in {settings_path}")
