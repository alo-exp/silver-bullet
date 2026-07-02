#!/usr/bin/env bash
# Thin adapter: Claude host install + preflight for shared enterprise E2E harness.
set -euo pipefail

enterprise_e2e_adapter_name() {
  printf 'claude\n'
}

enterprise_e2e_adapter_agent_script() {
  local sb_root="${SB_ROOT:-}"
  printf '%s\n' "${sb_root}/tests/live/agents/claude/agent.sh"
}

enterprise_e2e_adapter_install() {
  local sb_root="${1:-${SB_ROOT:-}}"
  enterprise_e2e_run_install_claude "$sb_root"
}

enterprise_e2e_adapter_preflight() {
  local sb_root="${1:-${SB_ROOT:-}}"
  enterprise_e2e_preflight_claude_token_gateway "$sb_root"
}
