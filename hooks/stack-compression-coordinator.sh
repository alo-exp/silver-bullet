#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — five-tool stack compression coordinator.
# Routes Read/Grep/Bash/WebFetch/MCP surfaces; blocks double-compression and wrong-owner
# lctx_* tools. Active only with the user's own consent to LeanCTX, or to two or more of
# RTK, Context Mode and LeanCTX; state is scoped to this project and host session.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
# The coordinator holds even for trivial work: a double-wrapped command is wrong either way.
SB_OPT_IN_TRIVIAL_BYPASS=0
sb_opt_in_hook_begin stack-compression-coordinator leanctx rtk context_mode
# shellcheck source=lib/stack-compression-coordinator.sh
source "$_lib_dir/stack-compression-coordinator.sh"

sb_stack_coordinator_needed "$config_file" || exit 0
sb_stack_set_session "$input"

command_str=""
mcp_server=""
mcp_tool=""
mcp_args="{}"
case "$tool_name" in
  Bash|Shell|shell|exec_command) command_str="$(sb_opt_in_command_string)" ;;
  Read|Grep|WebFetch) ;;
  *)
    sb_opt_in_mcp_call || exit 0
    # Only the routed compression tools (lctx_*, ctx_*) are this hook's business; an unrelated
    # MCP tool (a browser, a database) is never blocked by a compression conflict.
    [[ -n "$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)" ]] || exit 0
    ;;
esac

mutex_was_clean=1
if ! sb_stack_mutual_exclusion_is_clean "$config_file"; then
  mutex_was_clean=0
  recovery_pair="$(sb_stack_tool_is_compliant_routed_owner \
    "$config_file" "$tool_name" "$mcp_server" "$mcp_tool" "$command_str" "$mcp_args" 2>/dev/null || true)"
  if [[ -n "$recovery_pair" ]]; then
    sb_stack_clear_mutex_violations "$config_file"
  else
    sb_opt_in_emit_block "$(sb_stack_mutual_exclusion_block_message)"
    exit 0
  fi
fi

record_owner() { # route owner
  sb_stack_record_surface_owner "$config_file" "$1" "$2"
  if [[ "$mutex_was_clean" -eq 1 ]]; then
    sb_stack_record_routed_owner_success "$config_file" "$1" "$2"
  fi
  return 0
}

case "$tool_name" in
  Bash|Shell|shell|exec_command)
    [[ -n "$command_str" ]] || exit 0
    if sb_stack_should_deny_bash_double_wrap "$config_file" "$command_str"; then
      sb_opt_in_emit_block "$(sb_stack_bash_deny_message)"
      exit 0
    fi
    owner="$(sb_stack_route_owner "$config_file" "sb_shell" 2>/dev/null || true)"
    if [[ -n "$owner" ]]; then record_owner sb_shell "$owner"; fi
    ;;
  Read|Grep)
    route="sb_read"
    [[ "$tool_name" == "Grep" ]] && route="sb_grep"
    owner="$(sb_stack_surface_owner "$config_file" "$tool_name" 2>/dev/null || true)"
    if [[ -n "$owner" ]]; then record_owner "$route" "$owner"; fi
    ;;
  WebFetch)
    owner="$(sb_stack_surface_owner "$config_file" "WebFetch" 2>/dev/null || true)"
    if [[ -n "$owner" ]]; then record_owner sb_webfetch "$owner"; fi
    ;;
  *)
    route="$(sb_stack_mcp_tool_route "$mcp_tool")"
    owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
    if sb_stack_should_deny_mcp_tool "$config_file" "$mcp_server" "$mcp_tool" "$mcp_args"; then
      sb_opt_in_emit_block "$(sb_stack_mcp_deny_message "$config_file" "$mcp_tool" "$route" "$owner")"
      exit 0
    fi
    if [[ -n "$owner" ]]; then record_owner "$route" "$owner"; fi
    ;;
esac

exit 0
