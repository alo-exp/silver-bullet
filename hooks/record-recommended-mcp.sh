#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse MCP — record Graphify and agentmemory MCP retrievals for the opt-in gates.
# The call must come from the tool's own MCP server (exact or namespaced name) and be one
# of its read tools: query_graph/get_node/get_neighbors/shortest_path for Graphify,
# memory_smart_search/memory_recall/memory_search/memory_file_history for agentmemory.
# Hosts name these mcp__<server>__<tool>, or send CallMcpTool/MCP with server and tool in the payload.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin record-recommended-mcp graphify agentmemory
sb_opt_in_mcp_call || exit 0
sb_opt_in_mcp_succeeded || exit 0

recorded=""
if [[ "$mcp_server" =~ ^([A-Za-z0-9_-]+[_-])?graphify$ ]]; then
  case "$mcp_tool" in
    query_graph | get_node | get_neighbors | shortest_path)
      # shellcheck source=lib/graphify-gate.sh
      source "$_lib_dir/graphify-gate.sh"
      if sb_graphify_required "$config_file" && sb_graphify_record_query "$config_file"; then
        recorded="Graphify query"
      fi
      ;;
  esac
else
  # shellcheck source=lib/agentmemory-gate.sh
  source "$_lib_dir/agentmemory-gate.sh"
  if sb_agentmemory_mcp_server_matches "$mcp_server" && sb_agentmemory_mcp_tool_is_retrieval "$mcp_tool" \
    && sb_agentmemory_required "$config_file" && sb_agentmemory_record_usage "$config_file"; then
    recorded="agentmemory usage"
  fi
fi

if [[ -n "$recorded" ]]; then
  printf '{"hookSpecificOutput":{"message":"✅ %s recorded"}}' "$recorded"
fi
exit 0
