#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse CallMcpTool — record agentmemory / graphify MCP usage for opt-in gates (Wave 3).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/agentmemory-gate.sh" ]] && source "$_lib_dir/agentmemory-gate.sh"
[[ -f "$_lib_dir/graphify-gate.sh" ]] && source "$_lib_dir/graphify-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
case "$tool_name" in
  CallMcpTool|MCP) ;;
  *) exit 0 ;;
esac

config_file=""
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
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

server="$(printf '%s' "$input" | jq -r '.tool_input.server // .tool_input.mcpServer // ""' 2>/dev/null || true)"
mcp_tool="$(printf '%s' "$input" | jq -r '.tool_input.toolName // .tool_input.name // ""' 2>/dev/null || true)"
[[ -n "$server" && -n "$mcp_tool" ]] || exit 0

recorded=0
case "$server" in
  *agentmemory*)
    if sb_agentmemory_required "$config_file" 2>/dev/null && declare -f sb_agentmemory_record_usage >/dev/null 2>&1; then
      sb_agentmemory_record_usage "$config_file" && recorded=1
    fi
    ;;
esac

case "$mcp_tool" in
  save_memory|capture|remember|store*)
    if sb_agentmemory_required "$config_file" 2>/dev/null && declare -f sb_agentmemory_record_usage >/dev/null 2>&1; then
      sb_agentmemory_record_usage "$config_file" && recorded=1
    fi
    ;;
esac

if [[ "$recorded" -eq 1 ]]; then
  printf '{"hookSpecificOutput":{"message":"✅ recommended MCP usage recorded"}}'
fi
exit 0
