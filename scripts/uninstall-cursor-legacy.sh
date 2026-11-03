#!/usr/bin/env bash
# One-time cleanup for people who installed an older Silver Bullet into Cursor.
# Cursor is no longer a Silver Bullet host. This script only removes what Silver Bullet wrote
# under ~/.cursor (hooks.json entries, generated sb agents, rules, MCP entries, the global
# toolstack, plugin copies). It never installs anything. See scripts/lib/uninstall_cursor_legacy.py.
#
# Usage: bash scripts/uninstall-cursor-legacy.sh [--dry-run] [--cursor-home DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'ERROR: python3 is required to clean up ~/.cursor; nothing was changed.\n' >&2
  exit 1
fi

exec python3 "${SCRIPT_DIR}/lib/uninstall_cursor_legacy.py" "$@"
