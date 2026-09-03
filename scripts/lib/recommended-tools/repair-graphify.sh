# shellcheck shell=bash
# Graphify repair — package upgrade, MCP merge, worktree index.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=graphify-worktree.sh
source "$(dirname "${BASH_SOURCE[0]}")/graphify-worktree.sh"

rt_graphify_mcp_handshake() {
  command -v graphify-mcp >/dev/null 2>&1 || return 1
  local rc=0 pid waited=0
  graphify-mcp --transport stdio </dev/null >/dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 5 ]]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    return 1
  fi
  wait "$pid" || rc=$?
  [[ $rc -eq 0 || $rc -eq 1 ]]
}

rt_repair_graphify_packages() {
  local actions=() failures=()
  if ! sb_graphify_cli_available 2>/dev/null; then
    if command -v uv >/dev/null 2>&1; then
      uv tool install 'graphifyy[mcp]' 2>/dev/null && actions+=("uv_tool_install_graphifyy_mcp") \
        || failures+=("uv_tool_install_failed")
    elif command -v pipx >/dev/null 2>&1; then
      pipx install 'graphifyy[mcp]' 2>/dev/null && actions+=("pipx_install_graphifyy_mcp") \
        || failures+=("pipx_install_failed")
    else
      failures+=("no_uv_or_pipx")
    fi
  elif ! rt_probe_graphify_mcp_binary; then
    if command -v uv >/dev/null 2>&1; then
      uv tool install --force 'graphifyy[mcp]' 2>/dev/null && actions+=("uv_upgrade_graphifyy_mcp") \
        || failures+=("uv_upgrade_failed")
    elif command -v pipx >/dev/null 2>&1; then
      pipx install --force 'graphifyy[mcp]' 2>/dev/null && actions+=("pipx_upgrade_graphifyy_mcp") \
        || failures+=("pipx_upgrade_failed")
    fi
  fi
  if ((${#actions[@]} > 0)); then
    printf '%s\n' "${actions[@]}"
  fi
  printf '%s\n' '---FAILURES---'
  if ((${#failures[@]} > 0)); then
    printf '%s\n' "${failures[@]}"
  fi
}

rt_repair_graphify_mcp_config() {
  local patch_py="${RT_REPO_ROOT}/scripts/lib/global-toolstack/patch-mcp.py"
  [[ -f "$patch_py" ]] || return 1
  rt_graphify_mcp_handshake || return 1
  if rt_mutation_allowed graphify; then
    export RT_PATCH_GRAPHIFY=1
  else
    export RT_PATCH_GRAPHIFY=0
  fi
  export RT_PATCH_LEANCTX=0
  TOOLSTACK_REPO_ROOT="$RT_REPO_ROOT" python3 "$patch_py"
  local rc=$?
  unset RT_PATCH_GRAPHIFY RT_PATCH_LEANCTX
  return "$rc"
}

rt_repair_graphify_platform() {
  local host="${RT_HOST:-cursor}" cfg
  cfg="$(rt_project_config)" || return 1
  local cmd
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    eval "$cmd" >/dev/null 2>/dev/null || true
  done < <(sb_recommended_tool_platform_post_index_commands "$cfg" "graphify" "$host")
}

rt_repair_graphify() {
  local actions=() failures=() restart=0
  if ! rt_mutation_allowed graphify; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  local pkg_out action line
  pkg_out="$(rt_repair_graphify_packages)"
  while IFS= read -r line; do
    [[ "$line" == "---FAILURES---" ]] && break
    [[ -n "$line" ]] && actions+=("$line")
  done <<<"$pkg_out"
  while IFS= read -r line; do
    [[ -n "$line" ]] && failures+=("$line")
  done <<<"$(printf '%s\n' "$pkg_out" | sed -n '/---FAILURES---/,$p' | tail -n +2)"

  if sb_graphify_cli_available 2>/dev/null && rt_graphify_mcp_handshake; then
    if rt_cross_tool_batch_active; then
      : # host MCP batch owned by cross_tool repair
    elif rt_repair_graphify_mcp_config; then
      actions+=("mcp_config_merged")
      restart=1
    else
      failures+=("mcp_config_merge_failed")
    fi
  fi

  if sb_graphify_cli_available 2>/dev/null; then
    if rt_graphify_worktree_build_index "${RT_PROJECT_ROOT:-}" >&2; then
      actions+=("worktree_index_built")
    fi
    rt_repair_graphify_platform >&2 && actions+=("platform_artifacts_refreshed") || failures+=("platform_refresh_failed")
  fi

  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
