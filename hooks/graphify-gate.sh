#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — Graphify retrieval gate before substantive work (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn Graphify off.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin graphify-gate graphify
# shellcheck source=lib/graphify-gate.sh
source "$_lib_dir/graphify-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_graphify_required "$config_file" || exit 0

# Readiness first (cheap): when Graphify is ready nothing needs classifying.
if ! sb_graphify_cli_available; then
  reason="$(sb_graphify_block_message_no_cli "$config_file")"
elif ! sb_graphify_index_exists "$project_root" "$config_file"; then
  reason="$(sb_graphify_block_message_no_index "$(sb_graphify_graph_rel_path "$config_file")")"
elif sb_graphify_query_is_fresh "$config_file"; then
  exit 0
else
  reason="$(sb_graphify_block_message_stale_query "$(sb_graphify_graph_rel_path "$config_file")" \
    "$(sb_graphify_query_ttl_seconds "$config_file")")"
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_opt_in_shell_needs_gate graphify "$command_str" || exit 0
else
  sb_opt_in_edit_targets_exempt sb_graphify_edit_path_is_exempt && exit 0
fi

sb_opt_in_emit_block "$reason"
exit 0
