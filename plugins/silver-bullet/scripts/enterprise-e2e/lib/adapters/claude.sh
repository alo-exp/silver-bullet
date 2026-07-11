#!/usr/bin/env bash
# Thin adapter: Claude host install + preflight for shared enterprise E2E harness.
set -euo pipefail

enterprise_e2e_adapter_install() {
  local sb_root="${1:-${SB_ROOT:-}}"
  enterprise_e2e_run_install_claude "$sb_root"
}

enterprise_e2e_adapter_preflight() {
  local sb_root="${1:-${SB_ROOT:-}}"
  enterprise_e2e_preflight_claude_token_gateway "$sb_root"
}
