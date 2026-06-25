#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — deny Read/Grep on files larger than read_deny_bytes when Context Mode opted in.
# Active only when recommended_tools.context_mode.enabled_by_user is true and not suspended.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/context-mode-read-deny.sh" ]] && source "$_lib_dir/context-mode-read-deny.sh"
[[ -f "$_lib_dir/hook-audit.sh" ]] && source "$_lib_dir/hook-audit.sh"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  sb_hook_audit_record "context-mode-read-deny" "$hook_event" "deny" "$reason" "${file_path:-}" 2>/dev/null || true
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

project_root="$(dirname "$config_file")"

trivial_path="${SB_RUNTIME_STATE_DIR}/trivial"
trivial_cfg="$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)"
if [[ -n "$trivial_cfg" ]]; then
  trivial_path="${trivial_cfg/#\~/$HOME}"
fi
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_path"
fi

sb_context_mode_required "$config_file" || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
case "$tool_name" in
  Read|Grep) ;;
  *) exit 0 ;;
esac

file_path="$(sb_context_mode_tool_read_path "$input" 2>/dev/null || true)"
deny_path=""
if deny_path="$(sb_context_mode_should_deny_read "$input" "$config_file" "$project_root" 2>/dev/null)"; then
  :
else
  exit 0
fi

threshold="$(sb_context_mode_read_deny_bytes "$config_file")"
size="$(sb_context_mode_file_size_bytes "$deny_path" || echo 0)"
emit_block "$(sb_context_mode_read_deny_message "$deny_path" "$size" "$threshold")"
exit 0
