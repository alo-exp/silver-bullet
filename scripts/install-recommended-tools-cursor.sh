#!/usr/bin/env bash
# Install Cursor always-on rules for all SB recommended tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RULES_DIR="${REPO_ROOT}/.cursor/rules"

install_rule() {
  local name="$1"
  local src="${RULES_DIR}/${name}"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing rule file %s\n' "$src" >&2
    return 1
  fi
  printf 'OK: %s\n' "$src"
}

if command -v graphify >/dev/null 2>&1; then
  graphify cursor install 2>/dev/null || true
fi

install_rule graphify.mdc
install_rule agentmemory.mdc
install_rule recommended-tools.mdc

printf '\nCursor recommended-tool rules installed under %s\n' "$RULES_DIR"
printf 'Verify agentmemory MCP in ~/.cursor/mcp.json (see docs/AGENTMEMORY.md)\n'
