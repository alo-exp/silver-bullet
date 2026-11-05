# shellcheck shell=bash
# Enterprise E2E matrix row 1 (routing-only) — marker + Stop-hook coordination.
# Row 1 seeds an orchestrator feature queue via /sb; the harness verifies routing
# state/output, not full queue drain. The marker exempts Stop from parent-orchestrator block.
#
# R5-06: the exemption is test scaffolding, so a bare file must never switch the Stop gates
# off. It takes BOTH the harness's own environment (SB_E2E_ENTERPRISE_MATRIX=1, which an
# agent's Bash call cannot add to the host's hook environment) AND a marker holding a
# future expiry epoch that the harness wrote (an empty or stale file from `touch` is
# ignored). With no resolved state directory there is no marker at all (no /tmp fallback).

# Seconds the harness marker stays valid.
SB_E2E_MATRIX_MARKER_TTL="${SB_E2E_MATRIX_MARKER_TTL:-3600}"

sb_e2e_matrix_routing_row_marker_file() {
  [[ -n "${SB_RUNTIME_STATE_DIR:-}" ]] || return 1
  printf '%s/e2e-matrix-routing-row' "$SB_RUNTIME_STATE_DIR"
}

sb_e2e_matrix_routing_row_active() {
  local marker expiry
  [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]] || return 1
  marker="$(sb_e2e_matrix_routing_row_marker_file)" || return 1
  [[ -f "$marker" && ! -L "$marker" ]] || return 1
  expiry="$(head -1 "$marker" 2>/dev/null)"
  [[ "$expiry" =~ ^[0-9]+$ ]] || return 1
  [[ "$expiry" -gt "$(date +%s)" ]]
}

sb_e2e_matrix_set_routing_row_marker() {
  local marker
  marker="$(sb_e2e_matrix_routing_row_marker_file)" || return 1
  mkdir -p "$(dirname "$marker")" 2>/dev/null || true
  printf '%s\n' "$(($(date +%s) + SB_E2E_MATRIX_MARKER_TTL))" 2>/dev/null >"${marker}.tmp" && mv "${marker}.tmp" "$marker"
}

sb_e2e_matrix_clear_routing_row_marker() {
  local marker
  marker="$(sb_e2e_matrix_routing_row_marker_file)" || return 0
  rm -f -- "$marker" 2>/dev/null || true
}
