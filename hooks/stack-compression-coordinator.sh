#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — five-tool stack compression coordinator.
# Routes Read/Grep/Bash/WebFetch/MCP surfaces; blocks double-compression and wrong-owner lctx_* tools.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/stack-compression-coordinator.sh" ]] && source "$_lib_dir/stack-compression-coordinator.sh"
[[ -f "$_lib_dir/hook-audit.sh" ]] && source "$_lib_dir/hook-audit.sh"
[[ -f "$_lib_dir/cert-bypass.sh" ]] && source "$_lib_dir/cert-bypass.sh"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  sb_hook_audit_record "stack-compression-coordinator" "$hook_event" "deny" "$reason" "${file_path:-${mcp_tool:-${command_str:-}}}" 2>/dev/null || true
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    if [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]]; then
      printf '%s\n' "$reason" >&2
      exit 2
    fi
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

command -v jq >/dev/null 2>&1 || exit 0
if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"

config_file=""
if declare -f sb_find_project_config >/dev/null 2>&1; then
  config_file="$(sb_find_project_config 2>/dev/null || true)"
fi
if [[ -z "$config_file" ]]; then
  search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
      config_file="$search_dir/.silver-bullet.json"
      break
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
fi
[[ -n "$config_file" ]] || exit 0

if declare -f sb_project_is_initiated >/dev/null 2>&1; then
  sb_project_is_initiated "$config_file" || exit 0
fi

sb_stack_coordinator_needed "$config_file" || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
file_path="$(sb_tool_file_path "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"
command_str="$(sb_tool_command_string "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.command // ""')"
mcp_server="$(printf '%s' "$input" | jq -r '.tool_input.server // .tool_input.mcpServer // ""' 2>/dev/null || true)"
mcp_tool="$(printf '%s' "$input" | jq -r '.tool_input.toolName // .tool_input.name // ""' 2>/dev/null || true)"
mcp_args="$(printf '%s' "$input" | jq -c '.tool_input.arguments // .tool_input.args // {}' 2>/dev/null || echo '{}')"

mutex_was_clean=1
if ! sb_stack_mutual_exclusion_is_clean "$config_file"; then
  mutex_was_clean=0
  recovery_pair="$(sb_stack_tool_is_compliant_routed_owner \
    "$config_file" "$tool_name" "$mcp_server" "$mcp_tool" "$command_str" "$mcp_args" 2>/dev/null || true)"
  if [[ -n "$recovery_pair" ]]; then
    sb_stack_clear_mutex_violations "$config_file"
  else
    emit_block "$(sb_stack_mutual_exclusion_block_message)"
    exit 0
  fi
fi

case "$tool_name" in
  Bash|Shell|shell|exec_command)
    if [[ -n "$command_str" ]] && sb_stack_should_deny_bash_double_wrap "$config_file" "$command_str"; then
      emit_block "$(sb_stack_bash_deny_message)"
      exit 0
    fi
    if [[ -n "$command_str" ]]; then
      owner="$(sb_stack_route_owner "$config_file" "sb_shell" 2>/dev/null || true)"
      if [[ -n "$owner" ]]; then
        sb_stack_record_surface_owner "$config_file" "sb_shell" "$owner"
        [[ "$mutex_was_clean" -eq 1 ]] && sb_stack_record_routed_owner_success "$config_file" "sb_shell" "$owner"
      fi
    fi
    ;;
  Read|Grep)
    owner="$(sb_stack_surface_owner "$config_file" "$tool_name" 2>/dev/null || true)"
    route="sb_read"
    [[ "$tool_name" == "Grep" ]] && route="sb_grep"
    if [[ -n "$owner" ]]; then
      sb_stack_record_surface_owner "$config_file" "$route" "$owner"
      [[ "$mutex_was_clean" -eq 1 ]] && sb_stack_record_routed_owner_success "$config_file" "$route" "$owner"
    fi
    ;;
  WebFetch)
    owner="$(sb_stack_surface_owner "$config_file" "WebFetch" 2>/dev/null || true)"
    if [[ -n "$owner" ]]; then
      sb_stack_record_surface_owner "$config_file" "sb_webfetch" "$owner"
      [[ "$mutex_was_clean" -eq 1 ]] && sb_stack_record_routed_owner_success "$config_file" "sb_webfetch" "$owner"
    fi
    ;;
  CallMcpTool|MCP)
    if [[ -n "$mcp_tool" ]] && sb_stack_should_deny_mcp_tool "$config_file" "$mcp_server" "$mcp_tool" "$mcp_args"; then
      route="$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)"
      owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
      emit_block "$(sb_stack_mcp_deny_message "$config_file" "$mcp_tool" "$route" "$owner")"
      exit 0
    fi
    if [[ -n "$mcp_tool" ]]; then
      route="$(sb_stack_mcp_tool_route "$mcp_tool" 2>/dev/null || true)"
      if [[ -n "$route" ]]; then
        owner="$(sb_stack_route_owner "$config_file" "$route" 2>/dev/null || true)"
        if [[ -n "$owner" ]]; then
          sb_stack_record_surface_owner "$config_file" "$route" "$owner"
          [[ "$mutex_was_clean" -eq 1 ]] && sb_stack_record_routed_owner_success "$config_file" "$route" "$owner"
        fi
      fi
    fi
    ;;
  *)
    exit 0
    ;;
esac

exit 0
