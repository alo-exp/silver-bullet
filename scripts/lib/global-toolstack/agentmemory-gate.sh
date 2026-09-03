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
ts_enforcement_active || exit 0
ts_tool_required agentmemory || exit 0
input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
project_root="$(ts_git_root 2>/dev/null || true)"
[[ -n "$project_root" ]] || exit 0
tool_name="$(ts_tool_name "$input")"
file_path="$(ts_tool_file_path "$input")"
command_str="$(ts_tool_command_string "$input")"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
if [[ -n "$file_path" ]]; then
  ts_agentmemory_edit_path_is_exempt "$file_path" && exit 0
elif [[ -n "$command_str" ]]; then
  ts_agentmemory_command_is_exempt "$command_str" && exit 0
  ts_is_substantive_shell "$command_str" || exit 0
else exit 0; fi
export_rel="$(ts_effective_export_root)"
health_url="$(ts_effective_health_url)"
ttl="$(ts_effective_usage_ttl)"
if ! ts_agentmemory_cli_available; then
  ts_emit_deny "🚫 AGENTMEMORY REQUIRED — npm install -g @agentmemory/agentmemory" "$hook_event"
  exit 0
fi
if ! ts_agentmemory_server_healthy; then
  ts_emit_deny "🚫 AGENTMEMORY SERVER DOWN — nohup agentmemory > ~/.agentmemory/server.log 2>&1 & ; verify ${health_url}" "$hook_event"
  exit 0
fi
if ! ts_agentmemory_mcp_wired; then
  ts_emit_deny "🚫 AGENTMEMORY MCP NOT WIRED — run bash scripts/install-global-toolstack.sh" "$hook_event"
  exit 0
fi
_scaffolded=0
if ! ts_agentmemory_export_exists "$project_root"; then
  ts_agentmemory_scaffold_export "$project_root" && _scaffolded=1
fi
if ! ts_agentmemory_export_exists "$project_root"; then
  ts_emit_deny "🚫 AGENTMEMORY EXPORT MISSING — mkdir -p ${export_rel}/memory ${export_rel}/snapshots" "$hook_event"
  exit 0
fi
[[ "$_scaffolded" -eq 1 ]] && exit 0
ts_agentmemory_graphify_synergy_active && exit 0
ts_agentmemory_usage_is_fresh && exit 0
ts_emit_deny "🚫 AGENTMEMORY USAGE REQUIRED — memory_save via MCP or smart-search (TTL ${ttl}s). Synergy: fresh Graphify query passes gate." "$hook_event"
exit 0
