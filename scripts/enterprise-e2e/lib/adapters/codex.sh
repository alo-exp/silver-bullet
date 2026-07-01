#!/usr/bin/env bash
# Thin adapter: Codex host install + preflight for shared enterprise E2E harness.
set -euo pipefail

enterprise_e2e_adapter_name() {
  printf 'codex\n'
}

enterprise_e2e_adapter_agent_script() {
  local sb_root="${SB_ROOT:-}"
  printf '%s\n' "${sb_root}/tests/live/agents/codex/agent.sh"
}

enterprise_e2e_adapter_install() {
  local sb_root="${1:-${SB_ROOT:-}}"
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 1
  echo "Plugin install (Codex):"
  (cd "$sb_root" && bash scripts/install-codex.sh --purge-legacy-skills)
}

enterprise_e2e_adapter_preflight() {
  echo "Codex preflight: native CLI required (no Claude token gateway)"
}

enterprise_e2e_adapter_before_matrix_row() {
  local sb_root="${1:-${SB_ROOT:-}}"
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 0
  # Re-seed hook trust hashes after prior rows or sync may invalidate Codex trust state.
  (cd "$sb_root" && bash scripts/install-codex.sh --hook-trust-seed-only 2>/dev/null) || true
}
