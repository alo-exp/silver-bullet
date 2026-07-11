#!/usr/bin/env bash
# Attempt automatic SB prerequisite repair (Wave 0.2).
# Called from session-start when jq or plugin surfaces are missing.
set -euo pipefail

REPO_ROOT="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install jq 2>/dev/null || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y jq 2>/dev/null || true
  fi
fi

# Repair Claude plugin cache alias + hooks when a dev checkout is available.
if [[ -f "${SCRIPT_DIR}/lib/plugin-cache-version.sh" ]]; then
  # shellcheck source=scripts/lib/plugin-cache-version.sh
  source "${SCRIPT_DIR}/lib/plugin-cache-version.sh"
  sb_claude_ensure_plugin_cache_ready "$REPO_ROOT" 2>/dev/null || true
fi

if command -v jq >/dev/null 2>&1; then
  exit 0
fi

exit 1
