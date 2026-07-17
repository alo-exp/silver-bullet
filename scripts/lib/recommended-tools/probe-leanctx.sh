# shellcheck shell=bash
# LeanCTX probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

rt_probe_leanctx_mcp() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
      jq -e '.mcpServers.leanctx' "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

rt_probe_leanctx_lctx_prefix() {
  [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
  [[ "$(jq -r '.mcpServers.leanctx.env.LEANCTX_MCP_TOOL_PREFIX // ""' "${HOME}/.cursor/mcp.json" 2>/dev/null)" == "lctx_" ]]
}

rt_probe_leanctx_overlaps_disabled() {
  [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
  jq -e '
    .mcpServers.leanctx.env.LEANCTX_DISABLE_SHELL_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_SANDBOX_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_FETCH_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_FTS == "1"
  ' "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
}

rt_probe_leanctx() {
  local tool_id="leanctx" consent activation="none" canonical repairable=0
  local cfg="${RT_CONFIG_FILE:-$(rt_project_config)}"
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0

  consent="$(rt_consent_for "$tool_id")"
  if ! rt_host_supported "${RT_HOST:-cursor}"; then fu=1
  else
    case "$consent" in
      disabled) fd=1 ;;
      pending|"") fp=1 ;;
      enabled)
        if rt_is_suspended "$tool_id"; then fs=1
        elif ! sb_leanctx_cli_available "$cfg" 2>/dev/null; then ff=1; evidence+=("cli_missing"); frp=1; repairable=1
        elif ! rt_probe_leanctx_mcp; then frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
        elif ! rt_probe_leanctx_lctx_prefix; then frp=1; repairable=1; evidence+=("lctx_prefix_missing")
        elif ! rt_probe_leanctx_overlaps_disabled; then frp=1; repairable=1; evidence+=("overlap_surfaces_enabled")
        else activation="full"; fr=1
        fi
        ;;
    esac
  fi
  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_leanctx() {
  local actions=() failures=() restart=0
  if ! rt_mutation_allowed leanctx; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  local install="${RT_REPO_ROOT}/scripts/install-leanctx-sb.sh"
  if [[ -f "$install" ]]; then
    local -a install_args=(--host "${RT_HOST:-cursor}" --project-root "${RT_PROJECT_ROOT:-}")
    rt_cross_tool_batch_active && install_args+=(--skip-merge)
    bash "$install" "${install_args[@]}" >&2 \
      && actions+=("install_leanctx_sb") || failures+=("install_leanctx_failed")
    restart=1
  fi
  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
