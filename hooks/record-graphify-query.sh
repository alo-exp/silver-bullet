#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Bash — record a successful Graphify retrieval for the opt-in gate: one
# graphify query/explain/path/affected command, run on its own, that visibly succeeded.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin record-graphify-query graphify
case "$tool_name" in
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
# shellcheck source=lib/graphify-gate.sh
source "$_lib_dir/graphify-gate.sh"

sb_graphify_required "$config_file" || exit 0
sb_graphify_command_is_retrieval "$(sb_opt_in_command_string)" || exit 0
sb_opt_in_shell_succeeded || exit 0

if sb_graphify_record_query "$config_file"; then
  printf '{"hookSpecificOutput":{"message":"✅ Graphify query recorded"}}'
fi
exit 0
