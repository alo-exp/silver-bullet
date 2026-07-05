#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# SubagentStart (Cursor) / SessionStart worker branch — inject worker banner + tool requirements.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/orchestrator-parent.sh" ]] && source "$_lib_dir/orchestrator-parent.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "SubagentStart"' 2>/dev/null || echo SubagentStart)"
case "$hook_event" in
  SubagentStart|subagentStart|SessionStart) ;;
  *) exit 0 ;;
esac

config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

subagent_type="$(printf '%s' "$input" | jq -r '.subagent_type // .subagentType // ""' 2>/dev/null || true)"
prompt_preview="$(printf '%s' "$input" | jq -r '.prompt // .user_message // ""' 2>/dev/null | head -c 200 || true)"
assigned_skill=""
if [[ -n "$prompt_preview" ]]; then
  assigned_skill="$(printf '%s' "$prompt_preview" | grep -Eo 'silver:[a-z0-9:-]+|/silver:[a-z0-9-]+' | head -1 | tr -d '/' || true)"
fi

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
marker_file="$(sb_orchestrator_worker_marker_file)"
mkdir -p "$(dirname "$marker_file")" 2>/dev/null || true
jq -n \
  --arg at "$now" \
  --arg st "$subagent_type" \
  --arg skill "$assigned_skill" \
  --arg preview "$prompt_preview" \
  '{spawned_at:$at, subagent_type:$st, assigned_skill:$skill, prompt_preview:$preview, source:"subagent-start"}' \
  >"${marker_file}.tmp" 2>/dev/null && mv "${marker_file}.tmp" "$marker_file"

if [[ -f "$_lib_dir/orchestrator-scheduler.sh" ]]; then
  # shellcheck source=lib/orchestrator-scheduler.sh
  source "$_lib_dir/orchestrator-scheduler.sh"
  if [[ -n "$assigned_skill" ]]; then
    sb_scheduler_mark_handoff_dispatched "" "$assigned_skill" 2>/dev/null || true
  fi
fi

banner="SB WORKER SUBAGENT (mandatory)
  Set SB_ORCHESTRATOR_WORKER=1 for this session.
  1. graphify query before exploration (never skip when graphify-out/ exists).
  2. agentmemory MCP — save decisions/defects/evidence after meaningful work.
  3. Invoke assigned skill before substantive edits${assigned_skill:+: }${assigned_skill}.
  4. Write evidence artifact path (.planning/ or agentmemory export) before exit summary.
  5. RTK + Context Mode — follow project token-compression rules when opted in."

ctx="$(printf '%s' "$banner" | jq -Rs '.')"
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}' "$hook_event" "$ctx"
exit 0
