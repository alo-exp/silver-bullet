#!/usr/bin/env bash
# Prune stale Silver Bullet hook entries from the Claude user settings (E2E-010): entries
# whose command runs a Silver Bullet hook script that no longer exists, typically an old
# plugin-cache version. Only entries Silver Bullet provably owns are considered; other
# hooks, including ones whose paths use $HOME or ${CLAUDE_PROJECT_DIR} and other tools'
# gsd-*.sh, are never touched, and no file under ~/.claude/hooks is deleted (R7-12, R8-16).
# See scripts/lib/prune-claude-settings.py for how the file is rewritten.
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
SETTINGS="${CLAUDE_HOME}/settings.json"

if [[ -f "$SETTINGS" ]] && command -v python3 >/dev/null 2>&1; then
  python3 "$(dirname "${BASH_SOURCE[0]}")/lib/prune-claude-settings.py" "$SETTINGS"
fi

exit 0
