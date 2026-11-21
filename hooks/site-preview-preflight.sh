#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — ensure the local site preview is healthy before site edits (Wave 3). The preview port and script
# come from the project's site_profile; without them there is nothing to check.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
# shellcheck disable=SC2034  # read by sb_orchestrator_is_worker_session (subagent identity)
SB_ORCH_HOOK_INPUT="$input"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0
sb_site_profile_load || exit 0
sb_site_set_cwd "$input"
SB_SITE_PREVIEW_PORT="${SB_SITE_PREVIEW_PORT:-$SB_SITE_PROFILE_PORT}"
[[ -n "$SB_SITE_PREVIEW_PORT" ]] || exit 0

if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
  source "$_lib_dir/orchestrator-parent.sh"
  sb_orchestrator_is_parent_session 2>/dev/null && exit 0
fi

# Every path this call writes: a file tool's path fields and patch targets, or a shell command's write targets.
sb_tool_input_load "$input"
if sb_tool_is_shell_like "$tool_name"; then
  candidates="${SB_SA_WRITE_PATHS:-}"
else
  candidates="$({ sb_tool_file_path "$input"; printf '%s\n' "$input" | jq -r '.tool_input.path // empty | strings'; sb_tool_patch_paths "$input"; })"
fi
site_write=false
while IFS= read -r candidate; do
  if sb_site_session_path_is_site "$candidate"; then
    site_write=true
    break
  fi
done <<<"$candidates"
[[ "$site_write" == true ]] || exit 0

if sb_site_preview_healthy; then
  exit 0
fi

reason="Site preview preflight — local preview server is not healthy on :${SB_SITE_PREVIEW_PORT}."
if [[ -n "$SB_SITE_PREVIEW_SCRIPT" ]]; then
  serve_script="${SB_SITE_ROOT}/${SB_SITE_PREVIEW_SCRIPT}"
  reason="${reason}

Before editing the site run:
  bash ${serve_script} start
  bash ${serve_script} status

Then retry the edit."
fi
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
[[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
exit 0
