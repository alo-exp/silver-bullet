# shellcheck shell=bash
# Five-tool stack compression coordinator — surface ownership, MCP blocks, mutual-exclusion state.
# Sourced by: stack-compression-coordinator.sh, context-mode-read-deny.sh,
# token-compression-tools-gate.sh, semantic-compress.sh, sb-doctor.sh
#
# Coordinator state (recorded surface owners and double-compression violations) is scoped
# to one project and one host session: a violation in one session never blocks another
# session or another project. Hooks set SB_STACK_SESSION from the payload's session id
# (sb_stack_set_session); without it the state is per project.

_sb_stack_default_profile="five_tool_routed"
_sb_stack_mutex_reason="sb_stack_double_compression"
_sb_stack_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_stack_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_stack_lib_dir}/opt-in-gate.sh"

# sb_stack_set_session PAYLOAD: remember the host session id (sanitized) for state scoping.
sb_stack_set_session() {
  local sid
  sid="$(printf '%s' "${1:-}" | jq -r '.session_id // .sessionId // .conversation_id // "" | strings' 2>/dev/null || true)"
  SB_STACK_SESSION="$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-128)"
}

_sb_stack_state_dir() {
  printf '%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
}

# Key of the project that CONFIG belongs to (cksum of its consent project key).
_sb_stack_project_sum() {
  local config_file="${1:-}" root key
  root="$(dirname "${config_file:-$PWD/x}")"
  key="$(sb_consent_project_key "$root" 2>/dev/null || printf '%s' "$root")"
  printf '%s' "$key" | cksum | awk '{print $1}'
}

_sb_stack_scoped_path() {
  local kind="$1" config_file="${2:-}" session_sum
  session_sum="$(printf '%s' "${SB_STACK_SESSION:-}" | cksum | awk '{print $1}')"
  printf '%s/%s.d/%s-%s.json' "$(_sb_stack_state_dir)" "$kind" "$(_sb_stack_project_sum "$config_file")" "$session_sum"
}

sb_stack_coordinator_state_path() {
  _sb_stack_scoped_path stack-compression-coordinator "${1:-}"
}

sb_stack_mutex_state_path() {
  _sb_stack_scoped_path stack-compression-mutex "${1:-}"
}

sb_stack_compression_tools_enabled_count() {
  local config_file="${1:-}" count=0 tool_id
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
  case "${1:-}" in
    sb_wire|sb_read|sb_pathjail|sb_injection) printf 'leanctx' ;;
    sb_grep|sb_slice|sb_webfetch) printf 'context_mode' ;;
    sb_shell) printf 'rtk' ;;
    sb_graph) printf 'graphify' ;;
    sb_remember) printf 'agentmemory' ;;
    *) return 1 ;;
  esac
}

sb_stack_route_owner() {
  local config_file="${1:-}" route="${2:-}" profile owner

  [[ -n "$config_file" && -f "$config_file" && -n "$route" ]] || return 1

  if sb_stack_leanctx_active "$config_file"; then
    profile="$(jq -r --arg def "$_sb_stack_default_profile" \
      '.recommended_tools.leanctx.optimization_profile // $def' "$config_file" 2>/dev/null || echo "$_sb_stack_default_profile")"
    owner="$(jq -r --arg p "$profile" --arg r "$route" \
      '.optimization_profiles[$p].routes[$r] // empty' "$config_file" 2>/dev/null || true)"
    if sb_stack_owner_valid "$owner"; then
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

# Atomic JSON update of a state file: FILTER applied to the current document (or {}).
_sb_stack_json_update() {
  local state_path="$1" filter="$2" tmp current='{}'
  shift 2
  [[ ! -d "$state_path" ]] || return 1
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || return 1
  [[ -f "$state_path" && ! -L "$state_path" ]] && current="$(cat "$state_path" 2>/dev/null || printf '{}')"
  tmp="$(mktemp "${state_path}.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s' "$current" | jq "$@" "$filter" >"$tmp" 2>/dev/null && mv -f -- "$tmp" "$state_path" 2>/dev/null; then
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null
  return 1
}

sb_stack_record_surface_owner() {
  local config_file="${1:-}" route="${2:-}" owner="${3:-}"
  [[ -n "$route" && -n "$owner" ]] || return 1
  # shellcheck disable=SC2016  # jq variables, not shell
  _sb_stack_json_update "$(sb_stack_coordinator_state_path "$config_file")" \
    '(if type == "object" then . else {} end) | .surfaces[$route] = {owner: $owner, epoch: $epoch}' \
    --arg route "$route" --arg owner "$owner" --argjson epoch "$(date +%s)"
}

sb_stack_surface_recorded_owner() {
  local config_file="${1:-}" route="${2:-}" state_path
  state_path="$(sb_stack_coordinator_state_path "$config_file")"
  [[ -f "$state_path" ]] || return 1
  jq -r --arg route "$route" '.surfaces[$route].owner // empty' "$state_path" 2>/dev/null || true
}

sb_stack_record_double_compression() {
  local config_file="${1:-}" route="${2:-}" attempted_owner="${3:-}" incumbent_owner="${4:-}"
  # shellcheck disable=SC2016  # jq variables, not shell
  _sb_stack_json_update "$(sb_stack_mutex_state_path "$config_file")" \
    '(if type == "object" then . else {} end)
     | .violations = ((.violations // []) + [{route: $route, attempted: $attempted, incumbent: $incumbent, reason: $reason, epoch: $epoch}])' \
    --arg route "$route" --arg attempted "$attempted_owner" --arg incumbent "$incumbent_owner" \
    --arg reason "$_sb_stack_mutex_reason" --argjson epoch "$(date +%s)"
}

# Clear violations: for this project and session, every session of CONFIG's project when no
# session is set (sb-doctor), or every project when CONFIG is omitted (sb-doctor --fix).
sb_stack_clear_mutex_violations() {
  local config_file="${1:-}" dir
  dir="$(_sb_stack_state_dir)/stack-compression-mutex.d"
  if [[ -z "$config_file" ]]; then
    rm -f -- "$dir"/*.json 2>/dev/null || true
  elif [[ -z "${SB_STACK_SESSION:-}" ]]; then
    rm -f -- "$dir/$(_sb_stack_project_sum "$config_file")"-*.json 2>/dev/null || true
  else
    rm -f -- "$(sb_stack_mutex_state_path "$config_file")" 2>/dev/null || true
  fi
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
  local command_str="${5:-}" mcp_args="${6:-}" route owner=""

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
    *)
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
  esac
}

# Clean when no violation is recorded for this project and session (or, with no session
# set, for any session of the project).
sb_stack_mutual_exclusion_is_clean() {
  local config_file="${1:-}" state_path count
  if [[ -z "${SB_STACK_SESSION:-}" ]]; then
    for state_path in "$(_sb_stack_state_dir)/stack-compression-mutex.d/$(_sb_stack_project_sum "$config_file")"-*.json; do
      [[ -f "$state_path" ]] || continue
      count="$(jq -r '.violations | length' "$state_path" 2>/dev/null || echo 0)"
      [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)) && return 1
    done
    return 0
  fi
  state_path="$(sb_stack_mutex_state_path "$config_file")"
  [[ -f "$state_path" ]] || return 0
  count="$(jq -r '.violations | length' "$state_path" 2>/dev/null || echo 0)"
  [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)) && return 1
  return 0
}

sb_stack_mutual_exclusion_required() {
  sb_stack_coordinator_needed "${1:-}"
}

sb_stack_mutual_exclusion_block_message() {
  cat <<EOF
🚫 STACK COMPRESSION CONFLICT — double-compression detected (sb_stack_double_compression).

Two compression tools attempted the same surface in this session. Resolve by using the routed owner only:
  sb_read → LeanCTX lctx_read_ast (not raw Read + CM)
  sb_shell → RTK (LeanCTX shell rewrite OFF)
  sb_webfetch → Context Mode ctx_fetch_and_index (LeanCTX fetch MCP OFF)
  sb_graph → graphify query (not lctx_graph for code)
  sb_remember → agentmemory memory_save (not lctx_remember)

Clear state by completing one routed tool call on the owned surface, then retry.
See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}

# The command (after optional env and NAME=value words) starts with the rtk wrapper.
sb_stack_bash_rtk_rewritten() {
  [[ "${1:-}" =~ ^[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*rtk[[:space:]] ]]
}

# LeanCTX shell wrapping in program position: lean-ctx shell / leanctx shell / lctx_shell as
# the command, or an SB_LEANCTX_SHELL=1 assignment prefix. A mention elsewhere (grep -rn
# lctx_shell docs/) is not a wrapper.
sb_stack_bash_leanctx_shell_marker() {
  local cmd="${1:-}"
  local prefix='^[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
  [[ "$cmd" =~ ${prefix}((lean-ctx|leanctx)[[:space:]]+shell|lctx_shell)([[:space:]]|$) ]] && return 0
  [[ "$cmd" =~ ^[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*SB_LEANCTX_SHELL=1([[:space:]]|$) ]] && return 0
  return 1
}

sb_stack_mcp_tool_route() {
  case "${1:-}" in
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
  grep -qiE 'graphify|codebase|symbol|dependency|import |function |class |hooks/|\.tsx?|\.py|\.sh' <<<"$payload"
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
      [[ "$owner" == "agentmemory" ]] && return 0
      return 1
      ;;
    lctx_graph*)
      if [[ "$owner" == "graphify" ]] && sb_stack_mcp_query_looks_like_code "$tool_args"; then
        return 0
      fi
      return 1
      ;;
    lctx_fetch*|lctx_webfetch*)
      [[ "$owner" == "context_mode" ]] && return 0
      return 1
      ;;
    lctx_shell*)
      [[ "$owner" == "rtk" ]] && return 0
      return 1
      ;;
    ctx_fetch_and_index)
      [[ "$owner" == "leanctx" ]] && return 0
      return 1
      ;;
  esac

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
  local config_file="${1:-}" command_str="${2:-}" shell_owner incumbent

  sb_stack_coordinator_needed "$config_file" || return 1
  shell_owner="$(sb_stack_route_owner "$config_file" "sb_shell" 2>/dev/null || true)"
  [[ "$shell_owner" == "rtk" ]] || return 1

  if sb_stack_bash_rtk_rewritten "$command_str"; then
    sb_stack_record_surface_owner "$config_file" "sb_shell" "rtk"
    if sb_stack_bash_leanctx_shell_marker "$(sb_opt_in_rtk_unwrap "$command_str")"; then
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
🚫 LEANCTX READ ROUTING — large native Read redirected once (${size} bytes > ${threshold} byte threshold).

LeanCTX owns sb_read in the five-tool routed profile. For analysis use the AST read instead of raw Read:

  lctx_read_ast (LeanCTX MCP server)

Need the exact bytes (for example to Edit this file)? Repeat the same Read: it is allowed for the next 30 minutes.

Path: ${file_path}
See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}
