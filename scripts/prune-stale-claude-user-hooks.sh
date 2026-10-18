#!/usr/bin/env bash
# Prune stale user-level Claude hooks that reference missing scripts (E2E-010).
# Removes gsd-session-state.sh and other broken SessionStart entries from
# ~/.claude/settings.json and deletes dangling files in ~/.claude/hooks/.
#
# When settings.json needs cleaning it is rewritten as a normalised JSON document
# (2-space indent, trailing newline): numbers are re-serialised (2.50 -> 2.5,
# 1e3 -> 1000.0) and duplicate object keys collapse to the last value. A file with
# nothing to prune is not touched. The rewrite goes through a temp file renamed over
# the real (symlink-resolved) path, so a failure never truncates the settings.
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
  python3 "$(dirname "${BASH_SOURCE[0]}")/lib/prune-claude-settings.py" "$SETTINGS"
fi

exit 0
