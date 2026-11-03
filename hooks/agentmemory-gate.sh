#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — agentmemory capture gate before substantive work (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn agentmemory off.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin agentmemory-gate agentmemory
# shellcheck source=lib/agentmemory-gate.sh
source "$_lib_dir/agentmemory-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_agentmemory_required "$config_file" || exit 0

# Readiness first (cheap): a ready export root plus fresh usage (or Graphify synergy)
# needs no classification.
reason=""
if ! sb_agentmemory_cli_available; then
  reason="$(sb_agentmemory_block_message_no_cli "$config_file")"
elif sb_agentmemory_export_exists "$project_root" "$config_file" \
  && { sb_agentmemory_graphify_synergy_active "$config_file" || sb_agentmemory_usage_is_fresh "$config_file"; }; then
  exit 0
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_opt_in_shell_needs_gate agentmemory "$command_str" || exit 0
else
  sb_opt_in_edit_targets_exempt sb_agentmemory_edit_path_is_exempt && exit 0
fi

if [[ -z "$reason" ]]; then
  if ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
    # AC-5: the first substantive call after the auto-scaffold proceeds.
    sb_agentmemory_scaffold_export_root "$project_root" "$config_file" && exit 0
    reason="$(sb_agentmemory_block_message_no_export "$(sb_agentmemory_export_rel_path "$config_file")")"
  else
    # A down server or missing MCP wiring no longer skips the usage requirement (the agent
    # could cause either); the message says how to restore them.
    reason="$(sb_agentmemory_block_message_stale_usage "$(sb_agentmemory_usage_ttl_seconds "$config_file")")"
    if ! sb_agentmemory_server_healthy "$config_file"; then
      reason="${reason}"$'\n\n'"$(sb_agentmemory_block_message_no_server "$config_file")"
    elif ! sb_agentmemory_platform_artifact_present "$project_root"; then
      reason="${reason}"$'\n\n'"$(sb_agentmemory_block_message_no_mcp "$config_file")"
    fi
  fi
fi

sb_opt_in_emit_block "$reason"
exit 0
