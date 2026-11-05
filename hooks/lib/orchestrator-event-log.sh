# shellcheck shell=bash
# Durable orchestration event log — append-only JSONL under SB runtime state (Phase B+D).
# Bounded: past SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES (default 1 MiB) the file is cut back to its
# newest SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES (default 2000) lines (R4-29).

_sb_event_log_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_sb_event_log_lib_dir}/orchestrator-state.sh" ]]; then
  # shellcheck source=lib/orchestrator-state.sh
  source "${_sb_event_log_lib_dir}/orchestrator-state.sh"
fi

sb_orchestrator_event_log_file() {
  printf '%s/orchestrator-events.jsonl' "${SB_RUNTIME_STATE_DIR:-/tmp}"
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
  [[ -L "$logfile" ]] && return 1
  printf '%s\n' "$entry" >>"$logfile" 2>/dev/null || return 1
  sb_orchestrator_event_log_trim "$logfile"
  return 0
}

# Keep the log bounded. Cheap check first; the rewrite is atomic and serialized by the lock.
sb_orchestrator_event_log_trim() {
  local logfile="$1" size max keep
  max="${SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES:-1048576}"
  keep="${SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES:-2000}"
  [[ "$max" =~ ^[0-9]+$ && "$keep" =~ ^[0-9]+$ ]] || return 0
  size="$(wc -c <"$logfile" 2>/dev/null | tr -d ' ')"
  [[ "${size:-0}" -gt "$max" ]] || return 0
  sb_orchestrator_with_lock _sb_orchestrator_event_log_cut "$logfile" "$keep"
}

_sb_orchestrator_event_log_cut() {
  local logfile="$1" keep="$2" tmp
  tmp="$(mktemp "${logfile}.XXXXXX" 2>/dev/null)" || return 0
  if tail -n "$keep" "$logfile" >"$tmp" 2>/dev/null && mv -f "$tmp" "$logfile" 2>/dev/null; then
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null || true
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
