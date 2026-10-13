#!/usr/bin/env bash
# Thin adapter: Codex host install + preflight for shared enterprise E2E harness.
set -euo pipefail

enterprise_e2e_adapter_install() {
  local sb_root="${1:-${SB_ROOT:-}}"
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 1
  if [[ "${SB_E2E_SKIP_CODEX_INSTALL:-}" == "1" ]]; then
    echo "SKIP: Codex plugin install (SB_E2E_SKIP_CODEX_INSTALL=1; hooks seeded per row)"
    return 0
  fi
  echo "Plugin install (Codex):"
  (cd "$sb_root" && bash scripts/install-codex.sh --purge-legacy-skills)
}

enterprise_e2e_adapter_preflight() {
  echo "Codex preflight: native CLI required (no Claude token gateway)"
}

enterprise_e2e_adapter_before_matrix_row() {
  local sb_root="${1:-${SB_ROOT:-}}"
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 0
  if declare -f enterprise_e2e_fixture_ensure_branch >/dev/null 2>&1; then
    enterprise_e2e_fixture_ensure_branch || return 1
  fi
  export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
  if [[ -f "${sb_root}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${sb_root}/hooks/lib/runtime-paths.sh"
  fi
  if [[ -f "${sb_root}/scripts/enterprise-e2e/lib/deterministic/matrix-quiesce.sh" ]]; then
    # shellcheck source=scripts/enterprise-e2e/lib/deterministic/matrix-quiesce.sh
    source "${sb_root}/scripts/enterprise-e2e/lib/deterministic/matrix-quiesce.sh"
    enterprise_e2e_matrix_quiesce_orchestrator_queue "$sb_root"
  fi
  # Re-seed hook trust hashes after prior rows or sync may invalidate Codex trust state.
  (cd "$sb_root" && bash scripts/install-codex.sh --hook-trust-seed-only 2>/dev/null) || true
}
