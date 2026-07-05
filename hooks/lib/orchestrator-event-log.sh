# shellcheck shell=bash
# Durable orchestration event log — append-only JSONL under SB runtime state (Phase B+D).

_sb_event_log_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_sb_event_log_lib_dir}/orchestrator-state.sh" ]]; then
  # shellcheck source=lib/orchestrator-state.sh
  source "${_sb_event_log_lib_dir}/orchestrator-state.sh"
fi

sb_orchestrator_event_log_file() {
  printf '%s/orchestrator-events.jsonl' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_orchestrator_event_log_saga_file() {
  printf '%s/orchestrator-saga.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

# Append one orchestration event. payload_json must be valid JSON object.
sb_orchestrator_event_append() {
  local event_type="$1" payload_json="${2:-"{}"}"
  [[ -n "$event_type" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local logfile now entry dir
  logfile="$(sb_orchestrator_event_log_file)"
  dir="$(dirname "$logfile")"
  mkdir -p "$dir" 2>/dev/null || true
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  entry="$(jq -cn --arg type "$event_type" --arg at "$now" --arg payload "$payload_json" \
    '{at: $at, type: $type, payload: (try ($payload | fromjson) catch {})}' 2>/dev/null || true)"
  [[ -n "$entry" ]] || return 1
  printf '%s\n' "$entry" >>"$logfile" 2>/dev/null || return 1
  return 0
}

sb_orchestrator_event_record_dispatch() {
  local atom_id="${1:-}" skill="${2:-}" worker_template="${3:-}" batch_index="${4:-0}"
  sb_orchestrator_event_append "dispatch" "$(jq -nc \
    --arg atom "$atom_id" --arg skill "$skill" --arg tmpl "$worker_template" \
    --argjson batch "${batch_index:-0}" \
    '{atomic_flow_id: $atom, skill: $skill, worker_template: $tmpl, batch_index: $batch}')" || true
}

sb_orchestrator_event_record_join() {
  local atom_id="${1:-}" skill="${2:-}" status="${3:-joined}"
  sb_orchestrator_event_append "join" "$(jq -nc \
    --arg atom "$atom_id" --arg skill "$skill" --arg status "$status" \
    '{atomic_flow_id: $atom, skill: $skill, join_status: $status}')"
}

sb_orchestrator_event_record_advance() {
  local completed_skill="$1" next_flow="${2:-}" held_for_batch="${3:-false}"
  sb_orchestrator_event_append "advance" "$(jq -nc \
    --arg completed "$completed_skill" --arg next "$next_flow" \
    --argjson held "$([[ "$held_for_batch" == true ]] && echo true || echo false)" \
    '{completed_skill: $completed, next_flow: $next, held_for_batch: $held}')"
}

sb_orchestrator_event_record_stop_block() {
  local reason="$1"
  sb_orchestrator_event_append "stop_block" "$(jq -nc --arg reason "$reason" '{reason: $reason}')"
}

sb_orchestrator_event_record_retry() {
  local atom_id="$1" attempt="$2" reason="${3:-}"
  sb_orchestrator_event_append "retry" "$(jq -nc \
    --arg atom "$atom_id" --argjson attempt "$attempt" --arg reason "$reason" \
    '{atomic_flow_id: $atom, attempt: $attempt, reason: $reason}')"
}

# Returns JSON summary of last N events (default 20).
sb_orchestrator_event_tail_json() {
  local limit="${1:-20}"
  local logfile
  logfile="$(sb_orchestrator_event_log_file)"
  [[ -f "$logfile" ]] || { printf '[]'; return 0; }
  jq -s --argjson limit "$limit" '.[-$limit:]' "$logfile" 2>/dev/null || printf '[]'
}

# Resume hints from durable state + event log tail.
sb_orchestrator_event_resume_hints_json() {
  local file hints
  command -v jq >/dev/null 2>&1 || return 1
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  if [[ ! -f "$file" ]]; then
    printf '{"resumable":false,"reason":"no orchestrator.json"}'
    return 0
  fi
  hints="$(jq -c --argjson events "$(sb_orchestrator_event_tail_json 10)" '
    {
      resumable: ((.flow_queue // []) | length > 0),
      active_intent: (.active_intent // ""),
      current_flow: (.current_flow // ""),
      last_completed: (.last_completed // ""),
      workflow_id: (.workflow_id // ""),
      scheduler_status: (.scheduler.batch_dispatch.status // ""),
      pending_handoffs: ([.scheduler.batch_dispatch.handoffs[]? | select(.join_status != "joined")] | length),
      recent_events: $events
    }
  ' "$file" 2>/dev/null || true)"
  [[ -n "$hints" ]] && printf '%s' "$hints" || printf '{"resumable":false}'
}

# Apply resume checkpoint: restore scheduler batch index from last dispatch event when safe.
sb_orchestrator_event_apply_resume_checkpoint() {
  local logfile file updated now last_dispatch
  logfile="$(sb_orchestrator_event_log_file)"
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -f "$logfile" && -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  last_dispatch="$(jq -s '[.[] | select(.type == "dispatch")] | last | .payload.batch_index // 0' "$logfile" 2>/dev/null || echo 0)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --argjson idx "$last_dispatch" --arg now "$now" '
    .scheduler = (.scheduler // {}) |
    .scheduler.active_batch_index = $idx |
    .scheduler.resume_applied_at = $now |
    .updated_at = $now
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
}

# Minimal saga ledger for ship/deploy workers (rollback hints only).
sb_orchestrator_saga_begin() {
  local worker_skill="$1" action="${2:-ship}" artifacts_json="${3:-[]}"
  command -v jq >/dev/null 2>&1 || return 1
  local saga_file now entry
  saga_file="$(sb_orchestrator_event_log_saga_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  entry="$(jq -nc --arg skill "$worker_skill" --arg action "$action" --arg at "$now" \
    --argjson artifacts "$artifacts_json" \
    '{worker_skill: $skill, action: $action, started_at: $at, status: "in_progress", artifacts: $artifacts, rollback_steps: []}')"
  printf '%s' "$entry" >"${saga_file}.tmp" 2>/dev/null && mv "${saga_file}.tmp" "$saga_file"
  sb_orchestrator_event_append "saga_begin" "$(jq -nc --arg skill "$worker_skill" --arg action "$action" '{worker_skill: $skill, action: $action}')"
}

sb_orchestrator_saga_complete() {
  local worker_skill="$1" status="${2:-completed}"
  command -v jq >/dev/null 2>&1 || return 1
  local saga_file now updated
  saga_file="$(sb_orchestrator_event_log_saga_file)"
  [[ -f "$saga_file" ]] || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --arg status "$status" --arg at "$now" \
    '.status = $status | .completed_at = $at' "$saga_file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  printf '%s' "$updated" >"${saga_file}.tmp" 2>/dev/null && mv "${saga_file}.tmp" "$saga_file"
  sb_orchestrator_event_append "saga_complete" "$(jq -nc --arg skill "$worker_skill" --arg status "$status" '{worker_skill: $skill, status: $status}')"
}

sb_orchestrator_saga_rollback_hint() {
  local worker_skill="$1" reason="${2:-worker failure}"
  command -v jq >/dev/null 2>&1 || return 1
  local saga_file now updated hint
  saga_file="$(sb_orchestrator_event_log_saga_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [[ -f "$saga_file" ]]; then
    updated="$(jq --arg reason "$reason" --arg at "$now" \
      '.status = "rollback_required" |
       .rollback_steps += [{at: $at, reason: $reason, action: "revert_declared_artifacts"}]' \
      "$saga_file" 2>/dev/null || true)"
    [[ -n "$updated" ]] && printf '%s' "$updated" >"${saga_file}.tmp" 2>/dev/null && mv "${saga_file}.tmp" "$saga_file"
  fi
  sb_orchestrator_event_append "saga_rollback" "$(jq -nc --arg skill "$worker_skill" --arg reason "$reason" '{worker_skill: $skill, reason: $reason}')"
  hint="Saga rollback required for ${worker_skill}: ${reason}. Revert declared artifacts from .planning/ and git scope per worker contract before re-dispatch."
  printf '%s' "$hint"
}
