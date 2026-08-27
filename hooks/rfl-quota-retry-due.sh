#!/usr/bin/env bash
# SessionStart / UserPromptSubmit — activate due RFL quota-retry jobs.
# Fail-open and stay fast: no-op when no schedule files exist.
set -euo pipefail

emit_noop() {
  local event="${1:-SessionStart}"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg event "$event" '{hookSpecificOutput:{hookEventName:$event}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"%s"}}' "$event"
  fi
}

finish_noop() {
  emit_noop "${SB_RFL_HOOK_EVENT:-SessionStart}"
  exit 0
}

trap 'finish_noop' ERR

umask 0077

if [[ "${SB_RFL_QUOTA_RETRY_HOOK:-1}" == "0" ]]; then
  finish_noop
fi

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

event="SessionStart"
input=""
if [[ ! -t 0 ]]; then
  input="$(cat 2>/dev/null || true)"
fi
if [[ -n "$input" ]] && command -v jq >/dev/null 2>&1; then
  raw="$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)"
  case "$raw" in
    SessionStart|UserPromptSubmit) event="$raw" ;;
    sessionStart) event="SessionStart" ;;
    beforeSubmitPrompt) event="UserPromptSubmit" ;;
  esac
fi
event="${SB_RFL_HOOK_EVENT:-$event}"

project_root=""
if [[ -n "${SB_RFL_PROJECT_ROOT:-}" ]]; then
  project_root="$SB_RFL_PROJECT_ROOT"
elif declare -f sb_find_project_root_walk_only >/dev/null 2>&1; then
  project_root="$(sb_find_project_root_walk_only 2>/dev/null || true)"
fi
[[ -n "$project_root" ]] || finish_noop

# Fast skip: no RFL quota schedules in this project.
shopt -s nullglob
schedules=("$project_root"/.planning/rfl-*/quota-retry-schedule.json)
shopt -u nullglob
if [[ ${#schedules[@]} -eq 0 ]]; then
  finish_noop
fi

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || hook_dir=""
resolver="${SB_RFL_RESOLVER:-}"
if [[ -z "$resolver" ]]; then
  for candidate in \
    "$project_root/scripts/review-fix-ladder.py" \
    "${hook_dir}/../scripts/review-fix-ladder.py" \
    "${hook_dir}/../../scripts/review-fix-ladder.py"
  do
    if [[ -f "$candidate" ]]; then
      resolver="$candidate"
      break
    fi
  done
fi
[[ -n "$resolver" && -f "$resolver" ]] || finish_noop
command -v python3 >/dev/null 2>&1 || finish_noop

args=(python3 "$resolver" --quota-retry-wake --project-root "$project_root")
if [[ -n "${SB_RFL_QUOTA_NOW:-}" ]]; then
  args+=(--quota-now "$SB_RFL_QUOTA_NOW")
fi

export SB_RFL_NOTIFY="${SB_RFL_NOTIFY:-0}"
output="$("${args[@]}" 2>/dev/null || true)"
[[ -n "$output" ]] || finish_noop

ctx=""
if command -v jq >/dev/null 2>&1; then
  ctx="$(printf '%s' "$output" | jq -r '.hook_context // empty' 2>/dev/null || true)"
fi
if [[ -z "$ctx" ]]; then
  finish_noop
fi

jq -nc --arg event "$event" --arg ctx "$ctx" \
  '{hookSpecificOutput:{hookEventName:$event,additionalContext:$ctx}}'
exit 0
