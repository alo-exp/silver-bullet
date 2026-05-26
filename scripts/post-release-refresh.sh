#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_INSTALL_SCRIPT="${SB_POST_RELEASE_CLAUDE_INSTALL_SCRIPT:-${SCRIPT_DIR}/install-claude.sh}"
CODEX_INSTALL_SCRIPT="${SB_POST_RELEASE_CODEX_INSTALL_SCRIPT:-${SCRIPT_DIR}/install-codex.sh}"

run_refresh() {
  local label="$1"
  local script_path="$2"
  shift 2

  if [[ ! -f "$script_path" ]]; then
    printf 'ERROR: %s installer script missing at %s\n' "$label" "$script_path" >&2
    exit 1
  fi

  printf '[post-release-refresh] Refreshing %s install via %s\n' "$label" "$script_path"
  bash "$script_path" "$@"
}

run_refresh "Claude" "$CLAUDE_INSTALL_SCRIPT" --purge-legacy-plugins --public-release
run_refresh "Codex" "$CODEX_INSTALL_SCRIPT" --purge-legacy-skills --public-release

printf '[post-release-refresh] ✓ Public marketplace refresh complete for Claude and Codex\n'
