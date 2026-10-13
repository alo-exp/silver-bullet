#!/usr/bin/env bash
# Shared quiesce helpers for enterprise E2E matrix rows (sourced, not executed).
set -euo pipefail

enterprise_e2e_matrix_quiesce_orchestrator_queue() {
  local sb_root="${1:-${SB_ROOT:-}}"
  local lib_dir="${sb_root}/hooks/lib"
  if [[ -f "${lib_dir}/orchestrator-state.sh" ]]; then
    # shellcheck source=hooks/lib/orchestrator-state.sh
    source "${lib_dir}/orchestrator-state.sh"
    sb_orchestrator_clear_queue 2>/dev/null || true
  else
    rm -f \
      "${SB_RUNTIME_STATE_DIR:-}/orchestrator.json" \
      "${SB_RUNTIME_STATE_DIR:-}/orchestrator-directive.json" \
      "${SB_RUNTIME_STATE_DIR:-}/orchestrator-worker-active.json" 2>/dev/null || true
  fi
  if [[ -f "${lib_dir}/e2e-matrix-routing.sh" ]]; then
    # shellcheck source=hooks/lib/e2e-matrix-routing.sh
    source "${lib_dir}/e2e-matrix-routing.sh"
    sb_e2e_matrix_clear_routing_row_marker 2>/dev/null || true
  fi
}

matrix_quiesce_active_workflows() {
  local wf_dir="${WORK_DIR}/.planning/workflows"
  local archive_dir="${wf_dir}/.archive"
  local f id base sb_root="${SB_ROOT:-}"

  [[ -d "$wf_dir" ]] || return 0
  mkdir -p "$archive_dir"

  shopt -s nullglob
  for f in "$wf_dir"/202*.md; do
    id="$(basename "$f" .md)"
    if [[ -n "$sb_root" && -x "${sb_root}/scripts/workflows.sh" ]]; then
      (cd "$WORK_DIR" && bash "${sb_root}/scripts/workflows.sh" complete "$id") 2>/dev/null \
        || mv -f "$f" "$archive_dir/" 2>/dev/null || true
    else
      mv -f "$f" "$archive_dir/" 2>/dev/null || true
    fi
  done
  for f in "$wf_dir"/*.md; do
    base="$(basename "$f")"
    [[ "$base" =~ ^202[0-9]{6}T ]] && continue
    mv -f "$f" "$archive_dir/$base" 2>/dev/null || true
  done
  shopt -u nullglob
}

matrix_write_router_session_evidence() {
  local evidence_path="$1"
  local state_file
  state_file="$(enterprise_e2e_routing_state_file 2>/dev/null || printf '%s' "${HOME}/.codex/.silver-bullet/state")"
  mkdir -p "$(dirname "${WORK_DIR}/${evidence_path}")"
  {
    printf '# Router session evidence (matrix row 1 — routing-only)\n\n'
    printf 'Routing validated via interactive TUI on %s.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -f "$state_file" ]]; then
      printf '\nSkills in %s:\n' "$state_file"
      sed '/^$/d' "$state_file" | sed 's/^/- /'
    fi
  } >"${WORK_DIR}/${evidence_path}"
}
