#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — LeanCTX install/wiring/usage gate (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn LeanCTX off.
# Surface routing and double-compression guards live in stack-compression-coordinator.sh.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin leanctx-gate leanctx
# shellcheck source=lib/leanctx-gate.sh
source "$_lib_dir/leanctx-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_leanctx_required "$config_file" || exit 0

if ! sb_leanctx_cli_available "$config_file"; then
  reason="$(sb_leanctx_block_message_no_cli "$config_file")"
elif ! sb_leanctx_platform_artifact_present "$project_root"; then
  reason="$(sb_leanctx_block_message_no_mcp "$config_file")"
elif sb_leanctx_usage_is_fresh "$config_file"; then
  exit 0
else
  reason="$(sb_leanctx_block_message_stale_usage "$config_file")"
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_opt_in_shell_needs_gate leanctx "$command_str" || exit 0
else
  sb_opt_in_edit_targets_exempt sb_leanctx_edit_path_is_exempt && exit 0
fi

sb_opt_in_emit_block "$reason"
exit 0
