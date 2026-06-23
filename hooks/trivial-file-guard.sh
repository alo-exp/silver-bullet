#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Silver Bullet legacy trivial-file guard.
#
# Codex agents must not arm the old touch-file bypass by writing to the
# configured trivial marker. Use /silver:fast for trivial changes instead.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so the guard follows the host runtime.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo "PreToolUse")
[[ "$hook_event" == "PreToolUse" ]] || exit 0

if declare -f sb_tool_file_path >/dev/null 2>&1; then
  file_path="$(sb_tool_file_path "$input")"
else
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
fi
if declare -f sb_tool_command_string >/dev/null 2>&1; then
  command_str="$(sb_tool_command_string "$input")"
else
  command_str=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
fi
[[ -z "$file_path" && -z "$command_str" ]] && exit 0

resolve_repo_config() {
  local dir="$PWD"
  while true; do
    if [[ -f "$dir/.silver-bullet.json" ]] && [[ -f "$dir/silver-bullet.md" ]]; then
      printf '%s' "$dir/.silver-bullet.json"
      return 0
    fi
    if [[ -d "$dir/.git" ]] || [[ "$dir" == "/" ]]; then
      return 1
    fi
    dir=$(dirname "$dir")
  done
}

config_file=""
config_file=$(resolve_repo_config 2>/dev/null || true)
[[ -n "$config_file" ]] || exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi
if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$config_file" || exit 0
elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
  sb_project_is_initiated "$config_file" || exit 0
fi

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
sb_default_trivial="${SB_STATE_DIR}/trivial"
trivial_file=$(jq -r --arg dt "$sb_default_trivial" '.state.trivial_file // $dt' "$config_file" 2>/dev/null || printf '%s' "$sb_default_trivial")
trivial_file="${trivial_file/#\~/$HOME}"
if ! sb_runtime_path_is_state_scoped "$trivial_file"; then
  trivial_file="${sb_default_trivial}"
fi
[[ -L "$trivial_file" ]] && trivial_file="${sb_default_trivial}"
trivial_file_tilde="${trivial_file/#$HOME/~}"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

norm_path() {
  python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$1" 2>/dev/null || printf '%s' "$1"
}

if [[ -n "$file_path" ]]; then
  resolved_file_path="$(norm_path "$file_path")"
  if [[ "$resolved_file_path" == "$trivial_file" ]]; then
    emit_block "🚫 LEGACY TRIVIAL BYPASS BLOCKED — Codex agents must not write the trivial marker file directly. Use /silver:fast for trivial work instead."
    exit 0
  fi
fi

if [[ -n "$command_str" ]]; then
  if printf '%s' "$command_str" | grep -qF "$trivial_file" || printf '%s' "$command_str" | grep -qF "$trivial_file_tilde"; then
    if printf '%s' "$command_str" | grep -qE '(^|[[:space:];|&])(touch|truncate|tee|cp|mv|install|sed|perl|python|python3|node|ruby|dd)\b|[[:space:]]>>|[[:space:]]>[^>&=]'; then
      emit_block "🚫 LEGACY TRIVIAL BYPASS BLOCKED — Codex agents must not arm the trivial marker file from Bash. Use /silver:fast for trivial work instead."
      exit 0
    fi
  fi
fi

exit 0
