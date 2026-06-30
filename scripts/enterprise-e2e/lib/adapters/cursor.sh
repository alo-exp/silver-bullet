#!/usr/bin/env bash
# Thin adapter: Cursor host install + preflight for shared enterprise E2E harness.
set -euo pipefail

enterprise_e2e_adapter_name() {
  printf 'cursor\n'
}

enterprise_e2e_adapter_agent_script() {
  local sb_root="${SB_ROOT:-}"
  printf '%s\n' "${sb_root}/tests/live/agents/cursor/agent.sh"
}

enterprise_e2e_adapter_install() {
  local sb_root="${1:-${SB_ROOT:-}}"
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 1
  echo "Plugin install (Cursor):"
  (cd "$sb_root" && bash scripts/install-cursor.sh)
}

enterprise_e2e_adapter_preflight() {
  echo "Cursor preflight: cursor-agent CLI or CURSOR_API_KEY required"
}
