# shellcheck shell=bash
# agentmemory probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

rt_probe_agentmemory_mcp_configured() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
      jq -e '.mcpServers.agentmemory // .mcpServers["user-agentmemory"]' "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

rt_repair_agentmemory_mcp_config() {
  local patch_py="${RT_REPO_ROOT}/scripts/lib/global-toolstack/patch-mcp.py"
  [[ -f "$patch_py" ]] || return 1
  if rt_mutation_allowed agentmemory; then
    export RT_PATCH_AGENTMEMORY=1
  else
    export RT_PATCH_AGENTMEMORY=0
  fi
  export RT_PATCH_GRAPHIFY=0 RT_PATCH_LEANCTX=0
  TOOLSTACK_REPO_ROOT="$RT_REPO_ROOT" python3 "$patch_py"
  local rc=$?
  unset RT_PATCH_AGENTMEMORY RT_PATCH_GRAPHIFY RT_PATCH_LEANCTX
  return "$rc"
}

rt_probe_agentmemory() {
  local tool_id="agentmemory" consent activation="none" canonical repairable=0
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
        elif ! sb_agentmemory_cli_available 2>/dev/null; then ff=1; evidence+=("cli_missing"); frp=1; repairable=1
        elif ! sb_agentmemory_server_healthy "$cfg" 2>/dev/null; then frp=1; repairable=1; evidence+=("server_unhealthy")
        elif ! rt_probe_agentmemory_mcp_configured; then frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
        elif ! sb_agentmemory_export_exists "${RT_PROJECT_ROOT:-}" "$cfg" 2>/dev/null; then frp=1; repairable=1; evidence+=("export_missing")
        else activation="full"; fr=1
        fi
        ;;
    esac
  fi
  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_agentmemory() {
  local actions=() failures=() restart=0
  if ! rt_mutation_allowed agentmemory; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  if ! sb_agentmemory_cli_available 2>/dev/null; then
    npm install -g @agentmemory/agentmemory 2>/dev/null && actions+=("npm_install_agentmemory") || failures+=("npm_install_failed")
  fi
  if ! sb_agentmemory_server_healthy "$(rt_project_config)" 2>/dev/null; then
    # The redirect creates the log file, not its parent — without this the
    # start fails with "No such file or directory" on a fresh HOME.
    mkdir -p "${HOME}/.agentmemory" 2>/dev/null || true
    nohup agentmemory >"${HOME}/.agentmemory/server.log" 2>&1 &
    sleep 1
    sb_agentmemory_server_healthy "$(rt_project_config)" 2>/dev/null && actions+=("server_started") || failures+=("server_start_failed")
  fi
  local export_root
  export_root="$(sb_agentmemory_export_rel_path "$(rt_project_config)" 2>/dev/null || echo .agentmemory)"
  mkdir -p "${RT_PROJECT_ROOT:-}/${export_root}/memory" "${RT_PROJECT_ROOT:-}/${export_root}/snapshots" 2>/dev/null \
    && actions+=("export_root_created") || failures+=("export_root_failed")
  if ! rt_probe_agentmemory_mcp_configured; then
    if rt_cross_tool_batch_active; then
      : # cross_tool batch owns agentmemory MCP when consented
    elif rt_repair_agentmemory_mcp_config; then
      actions+=("mcp_config_merged")
      restart=1
    else
      failures+=("mcp_config_merge_failed")
    fi
  fi
  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
