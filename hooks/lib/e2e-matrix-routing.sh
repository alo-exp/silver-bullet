# shellcheck shell=bash
# Enterprise E2E matrix row 1 (routing-only) — marker + Stop-hook coordination.
# Row 1 seeds an orchestrator feature queue via /silver; the harness verifies routing
# state/output, not full queue drain. The marker exempts Stop from parent-orchestrator block.

sb_e2e_matrix_routing_row_marker_file() {
  printf '%s/e2e-matrix-routing-row' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_e2e_matrix_routing_row_active() {
  local marker
  marker="$(sb_e2e_matrix_routing_row_marker_file)"
  # Harness sets this marker for matrix row 1 only. Claude TUI hooks may not
  # inherit SB_E2E_ENTERPRISE_MATRIX — marker alone exempts routing-only Stop.
  [[ -f "$marker" && ! -L "$marker" ]]
}

sb_e2e_matrix_set_routing_row_marker() {
  local marker
  marker="$(sb_e2e_matrix_routing_row_marker_file)"
  mkdir -p "$(dirname "$marker")" 2>/dev/null || true
  printf '1\n' >"${marker}.tmp" 2>/dev/null && mv "${marker}.tmp" "$marker"
}

sb_e2e_matrix_clear_routing_row_marker() {
  rm -f -- "$(sb_e2e_matrix_routing_row_marker_file)" 2>/dev/null || true
}
