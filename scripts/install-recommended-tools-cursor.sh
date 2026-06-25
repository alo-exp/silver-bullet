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

if [[ -f "${RULES_DIR}/context-mode.mdc" ]]; then
  install_rule context-mode.mdc
elif command -v context-mode >/dev/null 2>&1; then
  cm_pkg="$(npm root -g 2>/dev/null)/context-mode"
  if [[ -f "${cm_pkg}/configs/cursor/context-mode.mdc" ]]; then
    cp "${cm_pkg}/configs/cursor/context-mode.mdc" "${RULES_DIR}/context-mode.mdc"
    install_rule context-mode.mdc
  fi
fi

printf '\nCursor recommended-tool rules installed under %s\n' "$RULES_DIR"
printf 'Verify agentmemory MCP in ~/.cursor/mcp.json (see docs/AGENTMEMORY.md)\n'
