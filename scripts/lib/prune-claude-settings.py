#!/usr/bin/env python3
"""Prune stale legacy hooks from a Claude settings.json (helper of prune-stale-claude-user-hooks.sh).

Usage: prune-claude-settings.py <settings.json>

Drops hook commands that name a legacy hook script or point at a script that no longer
exists. When something is dropped the file is rewritten as a normalised JSON document
(2-space indent, trailing newline): numbers are re-serialised (2.50 -> 2.5, 1e3 -> 1000.0)
and duplicate object keys collapse to the last value. A file with nothing to prune is not
touched. The rewrite goes through a temp file renamed over the symlink-resolved path, so a
failure never truncates the settings. Exit 1, file unchanged, on an unreadable or
wrongly-typed settings file.
"""
import json, os, re, stat, sys, tempfile

path = sys.argv[1]


def fail(msg):
    print(f"prune-stale-claude-user-hooks: ERROR: {msg}; {path} left unchanged", file=sys.stderr)
    sys.exit(1)


try:
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
except (OSError, ValueError) as exc:
    fail(f"cannot read settings ({exc})")
if not isinstance(doc, dict):
    fail("settings.json is not a JSON object")
if doc.get("hooks") is not None and not isinstance(doc["hooks"], dict):
    fail('"hooks" in settings.json is not an object')

changed = False
hook_re = re.compile(r'gsd-session-state|gsd-[a-z-]+\.sh', re.I)

def hook_command_broken(cmd):
    if not isinstance(cmd, str):
        return False
    if hook_re.search(cmd):
        return True
    m = re.search(r'(["\'])([^"\']+\.(?:sh|js|mjs))\1', cmd)
    if m:
        p = os.path.expanduser(m.group(2))
        if not os.path.isfile(p):
            return True
    return False

def filter_hooks(hooks):
    global changed
    if not isinstance(hooks, list):
        return hooks
    kept = []
    for entry in hooks:
        if not isinstance(entry, dict):
            kept.append(entry)
            continue
        inner = entry.get("hooks")
        if not isinstance(inner, list) or not inner:
            # Not a populated hook group: foreign data, never ours to drop.
            kept.append(entry)
            continue
        new_inner = []
        for h in inner:
            if isinstance(h, dict) and hook_command_broken(h.get("command", "")):
                changed = True
                continue
            new_inner.append(h)
        if new_inner:
            entry = dict(entry)
            entry["hooks"] = new_inner
            kept.append(entry)
    return kept

for section in ("hooks",):
    for event, groups in list((doc.get(section) or {}).items()):
        if not isinstance(groups, list):
            continue
        doc[section][event] = filter_hooks(groups)

if changed:
    out = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    try:
        data = out.encode("utf-8")
    except UnicodeEncodeError:
        # A lone surrogate (e.g. "\ud800") cannot be written as UTF-8: keep it as an escape.
        data = (json.dumps(doc, indent=2, ensure_ascii=True) + "\n").encode("utf-8")
    # Write a temp file next to the real settings file and rename it over, so a failed
    # write can never leave a truncated settings.json (and a symlinked one stays a symlink).
    target = os.path.realpath(path)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target), prefix=".settings.json.")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, stat.S_IMODE(os.stat(target).st_mode))
        os.replace(tmp, target)
    except BaseException:
        os.unlink(tmp)
        raise
    print("prune-stale-claude-user-hooks: cleaned settings.json SessionStart hooks", file=sys.stderr)
