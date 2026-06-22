#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Bash — record successful agentmemory retrieval commands for the opt-in gate.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/agentmemory-gate.sh" ]] && source "$_lib_dir/agentmemory-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
case "$tool_name" in
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

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

sb_agentmemory_required "$config_file" || exit 0

cmd="$(sb_tool_command_string "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.command // ""')"
[[ -n "$cmd" ]] || exit 0

if ! sb_agentmemory_command_is_retrieval "$cmd"; then
  exit 0
fi

exit_code="$(printf '%s' "$input" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0' 2>/dev/null || echo 0)"
[[ "$exit_code" == "0" ]] || exit 0

if sb_agentmemory_record_usage "$config_file"; then
  printf '{"hookSpecificOutput":{"message":"✅ agentmemory usage recorded"}}'
else
  exit 0
fi
