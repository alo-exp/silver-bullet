# shellcheck shell=bash
# Context Mode probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=vendor-doctor.sh
source "$(dirname "${BASH_SOURCE[0]}")/vendor-doctor.sh"

rt_probe_context_mode_mcp() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      rt_host_mcp_server_configured "$host" context-mode \
        || {
          [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
          jq -e '.mcpServers["user-context-mode"]' "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
        }
      ;;
    claude)
      sb_context_mode_platform_artifact_present "${RT_PROJECT_ROOT:-}" "$host" 2>/dev/null \
        || rt_host_mcp_server_configured "$host" context-mode
      ;;
    codex)
      rt_host_mcp_server_configured "$host" context-mode
      ;;
    opencode|pi)
      rt_host_mcp_server_configured "$host" context-mode
      ;;
    *) return 1 ;;
  esac
}

# Default D10 path: CONTEXT_MODE_PLATFORM=cursor context-mode doctor (bounded).
# 0=pass 1=fail 2=skip
rt_probe_context_mode_vendor_doctor() {
  local -a cmd
  if [[ -n "${RT_CONTEXT_MODE_DOCTOR_CMD:-}" ]]; then
    # Test seam — caller supplies a non-interactive argv string.
    # shellcheck disable=SC2206
    cmd=(${RT_CONTEXT_MODE_DOCTOR_CMD})
    rt_run_vendor_doctor "${cmd[@]}"
    return $?
  fi
  local context_mode_bin
  context_mode_bin="$(sb_context_mode_cli_path 2>/dev/null || true)"
  [[ -n "$context_mode_bin" ]] || return 2
  export CONTEXT_MODE_PLATFORM="${CONTEXT_MODE_PLATFORM:-${RT_HOST:-cursor}}"
  rt_run_vendor_doctor "$context_mode_bin" doctor
}

rt_probe_context_mode() {
  local tool_id="context_mode" consent activation="none" canonical repairable=0
  local cfg="${RT_CONFIG_FILE:-$(rt_project_config)}"
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0
  local vd_rc=0

  consent="$(rt_consent_for "$tool_id")"
  if ! rt_host_supported "${RT_HOST:-cursor}"; then fu=1
  else
    case "$consent" in
      disabled) fd=1 ;;
      pending|"") fp=1 ;;
      enabled)
        if rt_is_suspended "$tool_id"; then fs=1
        elif ! sb_context_mode_node_ok "$cfg" 2>/dev/null; then ff=1; evidence+=("node_version"); evidence+=("min_version"); frp=1; repairable=1
        elif ! sb_context_mode_cli_available 2>/dev/null; then frp=1; repairable=1; evidence+=("cli_missing")
        elif ! rt_probe_context_mode_mcp; then frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
        elif ! sb_context_mode_instruction_fragment_present "${RT_PROJECT_ROOT:-}" 2>/dev/null; then frp=1; repairable=1; evidence+=("instruction_fragment_missing")
        else
          # Opted-in default D10: vendor doctor FAIL (not --deep WARN).
          set +e
          rt_probe_context_mode_vendor_doctor
          vd_rc=$?
          set -e
          case "$vd_rc" in
            1) frp=1; repairable=1; evidence+=("vendor_doctor_failed") ;;
            2) evidence+=("vendor_skip"); activation="full"; fr=1 ;;
            *) activation="full"; fr=1 ;;
          esac
        fi
        ;;
    esac
  fi
  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_context_mode() {
  local actions=() failures=() restart=0
  if ! rt_mutation_allowed context_mode; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  if ! sb_context_mode_cli_available 2>/dev/null; then
    npm install -g context-mode 2>/dev/null && actions+=("npm_install_context_mode") || failures+=("npm_install_failed")
  fi
  local opt="${RT_REPO_ROOT}/scripts/optimize-rtk-context-mode.sh"
  if [[ -f "$opt" ]]; then
    local -a opt_args=(--host "${RT_HOST:-cursor}" --project-root "${RT_PROJECT_ROOT:-}")
    rt_cross_tool_batch_active && opt_args+=(--skip-rtk-init)
    rt_cross_tool_batch_active && opt_args+=(--skip-cm-doctor)
    if rt_cross_tool_batch_active; then
      TOOLSTACK_INSTALL_IN_PROGRESS=1 bash "$opt" "${opt_args[@]}" >&2 \
        && actions+=("optimize_rtk_context_mode") || failures+=("optimize_failed")
    else
      bash "$opt" "${opt_args[@]}" >&2 \
        && actions+=("optimize_rtk_context_mode") || failures+=("optimize_failed")
    fi
    restart=1
  fi
  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
