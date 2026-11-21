#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Bash — record a successful agentmemory retrieval for the opt-in gate: one
# agentmemory search/recall command or a read-only curl of the loopback REST API's retrieval
# endpoints, run on its own, that visibly succeeded. MCP retrievals are recorded by
# record-recommended-mcp.sh.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin record-agentmemory-usage agentmemory
case "$tool_name" in
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
# shellcheck source=lib/agentmemory-gate.sh
source "$_lib_dir/agentmemory-gate.sh"

sb_agentmemory_required "$config_file" || exit 0
sb_agentmemory_command_is_retrieval "$(sb_opt_in_command_string)" || exit 0
sb_opt_in_shell_succeeded || exit 0

if sb_agentmemory_record_usage "$config_file"; then
  printf '{"hookSpecificOutput":{"message":"✅ agentmemory usage recorded"}}'
fi
exit 0
