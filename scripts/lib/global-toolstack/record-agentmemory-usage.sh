#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
umask 0077
_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "$_LIB/common.sh"
command -v jq >/dev/null 2>&1 || exit 0
ts_sb_defer_to_bridge && exit 0
ts_config >/dev/null 2>&1 || exit 0
ts_tool_required agentmemory || exit 0
input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
[[ -n "$(ts_git_root 2>/dev/null || true)" ]] || exit 0
tool_name="$(ts_tool_name "$input")"
if [[ "$tool_name" == "CallMcpTool" ]] || [[ "$tool_name" == "MCP" ]]; then
  ts_agentmemory_mcp_is_save "$input" || exit 0
elif case "$tool_name" in Bash|Shell|shell|exec_command) true ;; *) false ;; esac; then
  cmd="$(ts_tool_command_string "$input")"
  [[ -n "$cmd" ]] || exit 0
  ts_agentmemory_command_is_retrieval "$cmd" || exit 0
  exit_code="$(printf '%s' "$input" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0' 2>/dev/null || echo 0)"
  [[ "$exit_code" == "0" ]] || exit 0
else
  exit 0
fi
ts_agentmemory_record_usage && printf '{"hookSpecificOutput":{"message":"✅ agentmemory usage recorded (toolstack)"}}'
exit 0
