#!/usr/bin/env bash
# Prune stale user-level Claude hooks that reference missing scripts (E2E-010).
# Removes gsd-session-state.sh and other broken SessionStart entries from
# ~/.claude/settings.json and deletes dangling files in ~/.claude/hooks/.
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
SETTINGS="${CLAUDE_HOME}/settings.json"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
pruned=0

if [[ -d "$HOOKS_DIR" ]]; then
  for f in "$HOOKS_DIR"/*; do
    [[ -e "$f" ]] || continue
    case "$(basename "$f")" in
      gsd-session-state.sh|gsd-*.sh)
        rm -f "$f" 2>/dev/null && pruned=$((pruned + 1)) && \
          echo "prune-stale-claude-user-hooks: removed ${f}" >&2
        ;;
    esac
  done
fi

if [[ -f "$SETTINGS" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" <<'PY'
import json, os, re, sys

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
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("prune-stale-claude-user-hooks: cleaned settings.json SessionStart hooks", file=sys.stderr)
PY
fi

exit 0
