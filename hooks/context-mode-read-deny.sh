#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — redirect the first full Read/Grep of a large file to Context Mode's
# sandboxed tools (see hooks/lib/context-mode-read-deny.sh for the exemptions). Active only
# with the user's own consent to Context Mode, once Context Mode is installed and wired.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin context-mode-read-deny context_mode
case "$tool_name" in
  Read|Grep) ;;
  *) exit 0 ;;
esac
# shellcheck source=lib/context-mode-read-deny.sh
source "$_lib_dir/context-mode-read-deny.sh"

sb_context_mode_required "$config_file" || exit 0

deny_path="$(sb_context_mode_should_deny_read "$input" "$config_file" "$project_root" 2>/dev/null)" || exit 0
file_path="$deny_path"
threshold="$(sb_context_mode_read_deny_bytes "$config_file")"
size="$(_sb_context_mode_read_bytes "$input" "$deny_path" || echo 0)"
sb_opt_in_emit_block "$(sb_context_mode_read_deny_message "$deny_path" "$size" "$threshold" "$config_file")"
exit 0
