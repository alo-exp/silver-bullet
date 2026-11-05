#!/usr/bin/env bash
# SB prerequisite repair (Wave 0.2), run by the SessionStart hook when jq or plugin surfaces
# are missing. It is report-only for anything that changes the machine: it never installs
# packages (no brew, apt or sudo) and never copies project files over the installed plugin.
# The only repair it performs is refreshing the plugin cache's own `current` alias. The user
# installs jq with the command printed below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'Silver Bullet needs jq. Install it, then restart the session:\n' >&2
  printf '  macOS: brew install jq\n  Linux: sudo apt install jq\n' >&2
fi

# Repair the Claude plugin cache alias (cache-internal; no project files are involved).
if [[ -f "${SCRIPT_DIR}/lib/plugin-cache-version.sh" ]]; then
  # shellcheck source=scripts/lib/plugin-cache-version.sh
  source "${SCRIPT_DIR}/lib/plugin-cache-version.sh"
  cache_root="${HOME}/.claude/plugins/cache/alo-labs/silver-bullet"
  if [[ -d "$cache_root" ]]; then
    sb_plugin_cache_prune_orphaned_dirs "$cache_root" 2>/dev/null || true
    sb_plugin_cache_refresh_current_alias "$cache_root" 2>/dev/null || true
  fi
fi

if command -v jq >/dev/null 2>&1; then
  exit 0
fi

exit 1
