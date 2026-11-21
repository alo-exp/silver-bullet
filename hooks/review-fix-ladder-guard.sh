#!/usr/bin/env bash
# Review-fix ladder guard (SessionStart, UserPromptSubmit, PreToolUse and PostToolUse for the spawn and edit
# tools, Stop). A thin wrapper: every decision is made by the plugin's own scripts/review-fix-ladder.py --hook,
# run with `python3 -I` from the plugin root located relative to THIS file (never a project copy, R4-09).
# Inert unless this session started or resumed a run (runtime pointer rfl-live.json), so a repo-shipped
# .planning/rfl-* cannot trigger anything. While a run is live a guard failure fails closed.
set -euo pipefail
trap 'exit 0' ERR

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
for _lib in runtime-paths.sh sb-project-gate.sh hook-audit.sh hook-subproc-timeout.sh orchestrator-parent.sh orchestrator-directive.sh; do
  # shellcheck disable=SC1090
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
[[ -n "$input" ]] || exit 0

hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)"
live_dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.claude/.silver-bullet}/rfl-live"
# one pointer file per (session, project) while a run is live in this runtime
has_live() { compgen -G "$live_dir/*.json" >/dev/null; }

case "$hook_event" in
  SessionStart) ;;
  UserPromptSubmit)
    # one grep, no python unless the user's message is an abort/approve command or states rungs
    printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null \
      | grep -qE '^[[:space:]]*RFL (ABORT|APPROVE) [A-Za-z0-9._-]+[[:space:]]*$|[Rr][Uu][Nn][Gg][Ss][[:space:]]*:' || exit 0
    # provenance (R4-07): only the parent session's own typed prompt counts
    if declare -f sb_orchestrator_prompt_provenance_ok >/dev/null 2>&1 && ! sb_orchestrator_prompt_provenance_ok "$input"; then
      exit 0
    fi
    ;;
  PreToolUse | PostToolUse | Stop) has_live || exit 0 ;;
  *) exit 0 ;;
esac

config_file=""
if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
  config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
fi
[[ -n "$config_file" ]] || exit 0
project_root="$(dirname "$config_file")"
if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit 2>/dev/null
fi

plugin_root="$(cd "$_lib_dir/../.." && pwd)"
resolver="$plugin_root/scripts/review-fix-ladder.py"

fail_closed() {
  local reason="$1" json_reason
  has_live || exit 0
  json_reason="$(printf '%s' "$reason" | jq -Rs '.')"
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "review-fix-ladder-guard" "$hook_event" "deny" "$reason" ""
  fi
  case "$hook_event" in
    PreToolUse)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      ;;
    Stop)
      printf '{"decision":"block","reason":%s}' "$json_reason"
      ;;
  esac
  exit 0
}

command -v python3 >/dev/null 2>&1 || fail_closed "Review-fix ladder guard: python3 is missing while a run is live; install it, or ask the user to end the run by typing: RFL ABORT <run-id>"
[[ -f "$resolver" ]] || fail_closed "Review-fix ladder guard: ${resolver} is missing; reinstall the plugin."

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/sb-rfl-guard.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
printf '%s' "$input" >"$tmp_dir/in"
rc=0
sb_run_hooked_command 8 "$tmp_dir/in" "$tmp_dir/out" "$tmp_dir/err" \
  python3 -I "$resolver" --hook --project-root "$project_root" || rc=$?

if [[ "$rc" -ne 0 ]] || ! jq -e 'type == "object"' "$tmp_dir/out" >/dev/null 2>&1; then
  fail_closed "Review-fix ladder guard could not check this ${hook_event} event (exit ${rc}); run review-fix-ladder.py --status, or ask the user to end the run by typing: RFL ABORT <run-id>"
fi

audit_decision="$(jq -r '.audit.decision // empty' "$tmp_dir/out")"
if [[ -n "$audit_decision" ]] && declare -f sb_hook_audit_record >/dev/null 2>&1; then
  sb_hook_audit_record "review-fix-ladder-guard" "$hook_event" "$audit_decision" "$(jq -r '.audit.reason // ""' "$tmp_dir/out")" ""
fi
jq -c '.output // empty' "$tmp_dir/out"
exit 0
