#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — RTK install/wiring gate (opt-in enforced).
# Active only when recommended_tools.rtk.enabled_by_user is true.
# Does NOT rewrite Bash — that is RTK's upstream PreToolUse hook.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/rtk-gate.sh" ]] && source "$_lib_dir/rtk-gate.sh"
[[ -f "$_lib_dir/hook-audit.sh" ]] && source "$_lib_dir/hook-audit.sh"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  sb_hook_audit_record "rtk-gate" "$hook_event" "deny" "$reason" "${file_path:-${command_str:-}}" 2>/dev/null || true
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

sb_rtk_required "$config_file" || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
file_path="$(sb_tool_file_path "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"
command_str="$(sb_tool_command_string "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.command // ""')"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

if [[ -n "$file_path" ]]; then
  if sb_rtk_edit_path_is_exempt "$file_path" "$config_file"; then
    exit 0
  fi
elif [[ -n "$command_str" ]]; then
  if sb_rtk_command_is_exempt "$command_str"; then
    exit 0
  fi
  if ! printf '%s' "$command_str" | grep -qE '\bgit commit\b|\bgh pr create\b|\bgh release create\b'; then
    if ! printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\bsed\b[^$]*-i|\bperl\b[^$]*-i)'; then
      exit 0
    fi
  fi
else
  exit 0
fi

if ! sb_rtk_cli_available; then
  if sb_rtk_cli_path >/dev/null 2>&1; then
    emit_block "$(sb_rtk_block_message_wrong_binary)"
  else
    emit_block "$(sb_rtk_block_message_no_cli "$config_file")"
  fi
  exit 0
fi

if ! sb_rtk_version_ok "$config_file"; then
  emit_block "$(sb_rtk_block_message_no_cli "$config_file")"
  exit 0
fi

if ! sb_rtk_platform_hook_present "$project_root"; then
  emit_block "$(sb_rtk_block_message_no_hook "$config_file")"
  exit 0
fi

exit 0
