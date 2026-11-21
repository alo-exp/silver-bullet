#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse — record site/** edits and site-intent prompts for session gates.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null || echo PostToolUse)"

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

sb_site_profile_load || exit 0
sb_site_set_cwd "$input"

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  # A prompt never starts a site session and never clears one: it only annotates a session that already holds
  # real site edits (R9-02, R9-12).
  prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
  if sb_site_prompt_is_site_intent "$prompt"; then
    sb_site_session_mark_site_intent
    if grep -qiE '\blive\b|publish|pushed to main|go live' <<<"$prompt"; then
      sb_site_session_mark_live_claim_pending
    fi
  fi
  exit 0
fi

[[ "$hook_event" == "PostToolUse" ]] || exit 0
tool_name="$(sb_tool_name "$input")"

# One counted edit per tool call that wrote under the site directory.
edited=""
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch)
    candidates="$({ sb_tool_file_path "$input"; sb_tool_patch_paths "$input"; })"
    ;;
  Bash|Shell|shell|exec_command)
    sb_tool_input_load "$input"
    candidates="${SB_SA_WRITE_PATHS:-}"
    # A push that is not provably a feature-branch push is a publish: it needs live evidence at Stop. It is
    # recorded here, after the host reports the command ran, never on the attempt (R9-06).
    if [[ "$(sb_site_shell_push_kind)" == final ]]; then
      sb_site_session_mark_push_intent
    fi
    ;;
  *) candidates="" ;;
esac
while IFS= read -r candidate; do
  if sb_site_session_path_is_site "$candidate"; then
    edited="$candidate"
    break
  fi
done <<<"$candidates"
if [[ -n "$edited" ]]; then
  sb_site_session_touch "edit:${edited}"
fi

exit 0
