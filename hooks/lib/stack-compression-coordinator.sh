# shellcheck shell=bash
# Five-tool stack compression coordinator — surface ownership, MCP blocks, mutual-exclusion state.
# Sourced by: stack-compression-coordinator.sh, context-mode-read-deny.sh,
# token-compression-tools-gate.sh, semantic-compress.sh

_sb_stack_default_profile="five_tool_routed"
_sb_stack_mutex_reason="sb_stack_double_compression"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_stack_coordinator_state_path() {
  printf '%s/stack-compression-coordinator' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
}

sb_stack_mutex_state_path() {
  printf '%s/stack-compression-mutex' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
}

sb_stack_lifecycle_state_path() {
  printf '%s/stack-compression-lifecycle' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
}

sb_stack_compression_tools_enabled_count() {
  local config_file="${1:-}"
  local count=0
  local tool_id
  for tool_id in rtk context_mode leanctx; do
    if sb_recommended_tool_enforced "$config_file" "$tool_id" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  printf '%s' "$count"
}

sb_stack_coordinator_needed() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  if sb_stack_leanctx_active "$config_file"; then
    return 0
  fi
  [[ "$(sb_stack_compression_tools_enabled_count "$config_file")" -ge 2 ]]
}

sb_stack_default_route_owner() {
  local route="${1:-}"
  case "$route" in
    sb_wire|sb_read|sb_pathjail|sb_injection) printf 'leanctx' ;;
    sb_grep|sb_slice|sb_webfetch) printf 'context_mode' ;;
    sb_shell) printf 'rtk' ;;
    sb_graph) printf 'graphify' ;;
    sb_remember) printf 'agentmemory' ;;
    *) return 1 ;;
  esac
}

sb_stack_route_owner() {
  local config_file="${1:-}" route="${2:-}"
  local profile owner

  [[ -n "$config_file" && -f "$config_file" && -n "$route" ]] || return 1

  if sb_stack_leanctx_active "$config_file"; then
    profile="$(jq -r --arg def "$_sb_stack_default_profile" \
      '.recommended_tools.leanctx.optimization_profile // $def' "$config_file" 2>/dev/null || echo "$_sb_stack_default_profile")"
    owner="$(jq -r --arg p "$profile" --arg r "$route" \
      '.optimization_profiles[$p].routes[$r] // empty' "$config_file" 2>/dev/null || true)"
    if [[ -n "$owner" && "$owner" != "null" ]]; then
      printf '%s' "$owner"
      return 0
    fi
    sb_stack_default_route_owner "$route"
    return $?
  fi

  case "$route" in
    sb_read|sb_grep|sb_slice|sb_webfetch) printf 'context_mode'; return 0 ;;
    sb_shell) printf 'rtk'; return 0 ;;
    sb_graph) printf 'graphify'; return 0 ;;
    sb_remember) printf 'agentmemory'; return 0 ;;
    *) return 1 ;;
  esac
}

sb_stack_record_surface_owner() {
  local config_file="${1:-}" route="${2:-}" owner="${3:-}"
  local state_path
  [[ -n "$route" && -n "$owner" ]] || return 1
  state_path="$(sb_stack_coordinator_state_path)"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  if [[ -f "$state_path" ]]; then
    jq --arg route "$route" --arg owner "$owner" --argjson epoch "$(date +%s)" \
      '.surfaces[$route] = {owner: $owner, epoch: $epoch}' "$state_path" >"${state_path}.tmp" 2>/dev/null \
      && mv "${state_path}.tmp" "$state_path"
  else
    jq -n --arg route "$route" --arg owner "$owner" --argjson epoch "$(date +%s)" \
      '{surfaces: {($route): {owner: $owner, epoch: $epoch}}}' >"$state_path" 2>/dev/null || return 1
  fi
}

sb_stack_surface_recorded_owner() {
  local config_file="${1:-}" route="${2:-}"
  local state_path
  state_path="$(sb_stack_coordinator_state_path)"
  [[ -f "$state_path" ]] || return 1
  jq -r --arg route "$route" '.surfaces[$route].owner // empty' "$state_path" 2>/dev/null || true
}

sb_stack_record_double_compression() {
  local config_file="${1:-}" route="${2:-}" attempted_owner="${3:-}" incumbent_owner="${4:-}"
  local state_path reason
  state_path="$(sb_stack_mutex_state_path)"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  reason="${_sb_stack_mutex_reason}"
  if [[ -f "$state_path" ]]; then
    jq --arg route "$route" --arg attempted "$attempted_owner" --arg incumbent "$incumbent_owner" \
      --arg reason "$reason" --argjson epoch "$(date +%s)" \
      '.violations += [{route: $route, attempted: $attempted, incumbent: $incumbent, reason: $reason, epoch: $epoch}]' \
      "$state_path" >"${state_path}.tmp" 2>/dev/null && mv "${state_path}.tmp" "$state_path"
  else
    jq -n --arg route "$route" --arg attempted "$attempted_owner" --arg incumbent "$incumbent_owner" \
      --arg reason "$reason" --argjson epoch "$(date +%s)" \
      '{violations: [{route: $route, attempted: $attempted, incumbent: $incumbent, reason: $reason, epoch: $epoch}]}' \
      >"$state_path" 2>/dev/null || return 1
  fi
}

sb_stack_clear_mutex_violations() {
  local state_path
  state_path="$(sb_stack_mutex_state_path)"
  rm -f -- "$state_path" 2>/dev/null || true
}

sb_stack_record_routed_owner_success() {
  local config_file="${1:-}" route="${2:-}" owner="${3:-}"
  sb_stack_clear_mutex_violations "$config_file"
  if [[ -n "$route" && -n "$owner" ]]; then
    sb_stack_record_surface_owner "$config_file" "$route" "$owner"
  fi
}

# Returns 0 when tool matches configured route owner and would not hit deny paths.
# Mutex recovery: Bash and routed MCP only (native Read/Grep/WebFetch cannot clear violations).
# Prints "route owner" on stdout when compliant.
sb_stack_tool_is_compliant_routed_owner() {
  local config_file="${1:-}" tool_name="${2:-}" mcp_server="${3:-}" mcp_tool="${4:-}"
  local command_str="${5:-}" mcp_args="${6:-}"
  local route owner=""

  [[ -n "$config_file" && -n "$tool_name" ]] || return 1
  sb_stack_coordinator_needed "$config_file" || return 1

  case "$tool_name" in
    Bash|Shell|shell|exec_command)
      route="sb_shell"
      owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
      [[ -n "$owner" ]] || return 1
      if sb_stack_should_deny_bash_double_wrap "$config_file" "$command_str"; then
        return 1
      fi
      printf '%s %s\n' "$route" "$owner"
      return 0
      ;;
    CallMcpTool|MCP)
      [[ -n "$mcp_tool" ]] || return 1
      route="$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)"
      [[ -n "$route" ]] || return 1
      if sb_stack_should_deny_mcp_tool "$config_file" "$mcp_server" "$mcp_tool" "$mcp_args"; then
        return 1
      fi
      owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
      [[ -n "$owner" ]] || return 1
      printf '%s %s\n' "$route" "$owner"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sb_stack_mutual_exclusion_is_clean() {
  local config_file="${1:-}"
  local state_path count
  state_path="$(sb_stack_mutex_state_path)"
  [[ -f "$state_path" ]] || return 0
  count="$(jq -r '.violations | length' "$state_path" 2>/dev/null || echo 0)"
  [[ "${count:-0}" -eq 0 ]]
}

sb_stack_mutual_exclusion_required() {
  local config_file="${1:-}"
  sb_stack_coordinator_needed "$config_file"
}

sb_stack_mutual_exclusion_block_message() {
  cat <<EOF
🚫 STACK COMPRESSION CONFLICT — double-compression detected (sb_stack_double_compression).

Two compression tools attempted the same surface in one session. Resolve by using the routed owner only:
  sb_read → LeanCTX lctx_read_ast (not raw Read + CM)
  sb_shell → RTK (LeanCTX shell rewrite OFF)
  sb_webfetch → Context Mode ctx_fetch_and_index (LeanCTX fetch MCP OFF)
  sb_graph → graphify query (not lctx_graph for code)
  sb_remember → agentmemory memory_save (not lctx_remember)

Clear state by completing one routed tool call on the owned surface, then retry.
See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}

sb_stack_bash_rtk_rewritten() {
  local command_str="${1:-}"
  local unwrapped
  [[ -n "$command_str" ]] || return 1
  if ! declare -f sb_shell_command_unwrap_rtk >/dev/null 2>&1; then
    return 1
  fi
  unwrapped="$(sb_shell_command_unwrap_rtk "$command_str" 2>/dev/null || true)"
  [[ -n "$unwrapped" && "$unwrapped" != "$command_str" ]]
}

sb_stack_bash_leanctx_shell_marker() {
  local command_str="${1:-}"
  [[ -n "$command_str" ]] || return 1
  if printf '%s' "$command_str" | grep -qE 'SB_LEANCTX_SHELL=1'; then
    return 0
  fi
  if printf '%s' "$command_str" | grep -qE '(^|[[:space:]|&;])(lean-ctx|leanctx)[[:space:]]+shell\b'; then
    return 0
  fi
  if printf '%s' "$command_str" | grep -qE '\blctx_shell\b'; then
    return 0
  fi
  return 1
}

sb_stack_mcp_tool_route() {
  local mcp_tool="${1:-}"
  case "$mcp_tool" in
    lctx_read_ast|lctx_read*) printf 'sb_read' ;;
    lctx_graph*) printf 'sb_graph' ;;
    lctx_remember*) printf 'sb_remember' ;;
    lctx_fetch*|lctx_webfetch*) printf 'sb_webfetch' ;;
    lctx_shell*) printf 'sb_shell' ;;
    ctx_execute|ctx_execute_file|ctx_batch_execute|ctx_search|ctx_index|ctx_fetch_and_index)
      printf 'sb_slice' ;;
    *) ;;
  esac
}

sb_stack_mcp_query_looks_like_code() {
  local payload="${1:-}"
  [[ -n "$payload" ]] || return 1
  if printf '%s' "$payload" | grep -qiE 'graphify|codebase|symbol|dependency|import |function |class |hooks/|\.tsx?|\.py|\.sh'; then
    return 0
  fi
  return 1
}

# Returns 0 when MCP tool should be denied on this surface.
sb_stack_should_deny_mcp_tool() {
  local config_file="${1:-}" mcp_server="${2:-}" mcp_tool="${3:-}" tool_args="${4:-}"
  local route owner incumbent

  [[ -n "$config_file" && -n "$mcp_tool" ]] || return 1
  sb_stack_coordinator_needed "$config_file" || return 1

  route="$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)"
  [[ -n "$route" ]] || return 1

  owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
  [[ -n "$owner" ]] || return 1

  case "$mcp_tool" in
    lctx_remember*)
      [[ "$owner" == "agentmemory" ]]
      return
      ;;
    lctx_graph*)
      if [[ "$owner" == "graphify" ]] && sb_stack_mcp_query_looks_like_code "$tool_args"; then
        return 0
      fi
      return 1
      ;;
    lctx_fetch*|lctx_webfetch*)
      [[ "$owner" == "context_mode" ]]
      return
      ;;
    lctx_shell*)
      [[ "$owner" == "rtk" ]]
      return
      ;;
    ctx_fetch_and_index)
      [[ "$owner" == "leanctx" ]]
      return
      ;;
  esac

  if [[ "$mcp_tool" == lctx_* ]] && [[ "$owner" != "leanctx" ]]; then
    case "$route" in
      sb_slice|sb_grep) [[ "$owner" == "context_mode" ]] && return 0 ;;
      sb_shell) [[ "$owner" == "rtk" ]] && return 0 ;;
      sb_webfetch) [[ "$owner" == "context_mode" ]] && return 0 ;;
      sb_graph) [[ "$owner" == "graphify" ]] && return 0 ;;
      sb_remember) [[ "$owner" == "agentmemory" ]] && return 0 ;;
    esac
  fi

  incumbent="$(sb_stack_surface_recorded_owner "$config_file" "$route" 2>/dev/null || true)"
  if [[ -n "$incumbent" && "$incumbent" != "$owner" ]]; then
    return 0
  fi

  return 1
}

sb_stack_mcp_deny_message() {
  local config_file="${1:-}" mcp_tool="${2:-}" route="${3:-}" owner="${4:-}"
  route="${route:-$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)}"
  owner="${owner:-$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)}"
  cat <<EOF
🚫 STACK ROUTING — ${mcp_tool} blocked on ${route} (owner: ${owner}).

Use the routed surface owner for this project:
  sb_read → lctx_read_ast (LeanCTX AST)
  sb_grep/sb_slice → ctx_execute / ctx_search (Context Mode)
  sb_shell → RTK shell rewrite (LeanCTX shell OFF)
  sb_webfetch → ctx_fetch_and_index (LeanCTX fetch MCP OFF)
  sb_graph → graphify query / path / explain
  sb_remember → agentmemory memory_save

Reason: ${_sb_stack_mutex_reason}
See docs/LEANCTX.md.
EOF
}

sb_stack_should_deny_bash_double_wrap() {
  local config_file="${1:-}" command_str="${2:-}"
  local shell_owner incumbent

  sb_stack_coordinator_needed "$config_file" || return 1
  shell_owner="$(sb_stack_route_owner "$config_file" "sb_shell" 2>/dev/null || true)"
  [[ "$shell_owner" == "rtk" ]] || return 1

  if sb_stack_bash_rtk_rewritten "$command_str"; then
    sb_stack_record_surface_owner "$config_file" "sb_shell" "rtk"
    if sb_stack_bash_leanctx_shell_marker "$command_str"; then
      sb_stack_record_double_compression "$config_file" "sb_shell" "leanctx" "rtk"
      return 0
    fi
    return 1
  fi

  if sb_stack_bash_leanctx_shell_marker "$command_str"; then
    incumbent="$(sb_stack_surface_recorded_owner "$config_file" "sb_shell" 2>/dev/null || true)"
    if [[ "$incumbent" == "rtk" ]]; then
      sb_stack_record_double_compression "$config_file" "sb_shell" "leanctx" "rtk"
      return 0
    fi
  fi

  return 1
}

sb_stack_bash_deny_message() {
  cat <<EOF
🚫 STACK ROUTING — Bash double-compression blocked (sb_stack_double_compression).

RTK owns sb_shell in the five-tool routed profile. LeanCTX shell rewrite is disabled when RTK is active.

Use RTK-compressed shell output only. Do not invoke LeanCTX shell hooks on the same command.
See docs/LEANCTX.md.
EOF
}

sb_stack_read_deny_defer_to_leanctx() {
  local config_file="${1:-}"
  sb_stack_leanctx_active "$config_file" || return 1
  [[ "$(sb_stack_surface_owner "$config_file" "Read" 2>/dev/null || true)" == "leanctx" ]]
}

sb_stack_read_deny_message_leanctx() {
  local file_path="${1:-}" size="${2:-}" threshold="${3:-}"
  cat <<EOF
🚫 LEANCTX READ ROUTING — native Read blocked (${size} bytes > ${threshold} byte threshold).

LeanCTX owns sb_read in the five-tool routed profile. Use AST read instead of raw Read for analysis:

  CallMcpTool → lctx_read_ast (leanctx server)

Native Read is still correct when you will Edit the same file next (exact bytes required).

Path: ${file_path}
See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}

# Lifecycle ordering markers (SessionStart compact): CM → AM → LeanCTX → stop-check.
sb_stack_lifecycle_mark() {
  local phase="${1:-}"
  local state_path
  [[ -n "$phase" ]] || return 1
  state_path="$(sb_stack_lifecycle_state_path)"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  date +%s >"${state_path}.${phase}" 2>/dev/null || return 1
}

sb_stack_lifecycle_phase_epoch() {
  local phase="${1:-}"
  local state_path="${2:-$(sb_stack_lifecycle_state_path)}"
  [[ -f "${state_path}.${phase}" ]] || return 1
  sed -n '1p' "${state_path}.${phase}" 2>/dev/null
}

sb_stack_lifecycle_order_ok() {
  local cm_epoch am_epoch lc_epoch
  cm_epoch="$(sb_stack_lifecycle_phase_epoch "context_mode_precompact" 2>/dev/null || true)"
  am_epoch="$(sb_stack_lifecycle_phase_epoch "agentmemory_snapshot" 2>/dev/null || true)"
  lc_epoch="$(sb_stack_lifecycle_phase_epoch "leanctx_compact" 2>/dev/null || true)"
  [[ -n "$cm_epoch" && -n "$am_epoch" && -n "$lc_epoch" ]] || return 0
  [[ "$cm_epoch" -le "$am_epoch" && "$am_epoch" -le "$lc_epoch" ]]
}
