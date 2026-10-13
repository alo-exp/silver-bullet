#!/usr/bin/env bash
# Channel-timeline monitor for Claude delegation logs (parent supervision).
set -euo pipefail

LOG_FILE=""
INTERVAL="${AGENT_CLAUDE_MONITOR_INTERVAL:-30}"
STALL_SEC="${AGENT_CLAUDE_MONITOR_STALL_SEC:-300}"
ONCE=0

prompt_seen=0
floor_announced=0
stall_warned=0
last_bytes=0
last_growth_ts="$(date +%s)"

usage() {
  cat <<'EOF'
Usage: monitor.sh --log PATH [--interval SEC] [--stall-sec SEC] [--once]

Emits channel bullets while tailing a delegation log:
  • prompt submitted (once)
  • token / activity growth (no 0-token false-complete)
  • harness ERROR / quota / auth signals
  • idle stall (no byte growth between polls)

Parent uses this between checkpoints; not for matrix batch drivers.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) LOG_FILE="$2"; shift 2 ;;
    --interval)
      [[ "$2" =~ ^[0-9]+$ ]] || { printf 'ERROR: --interval must be numeric\n' >&2; exit 2; }
      INTERVAL="$2"; shift 2
      ;;
    --stall-sec)
      [[ "$2" =~ ^[0-9]+$ ]] || { printf 'ERROR: --stall-sec must be numeric\n' >&2; exit 2; }
      STALL_SEC="$2"; shift 2
      ;;
    --once) ONCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$LOG_FILE" ]] || { usage >&2; exit 2; }

emit_bullet() {
  printf '[agent-claude monitor] %s — %s\n' "$(date -u +%H:%M:%SZ)" "$1"
}

scan_log() {
  [[ -f "$LOG_FILE" ]] || return 0
  local bytes content floor
  bytes="$(wc -c <"$LOG_FILE" | tr -d ' ')"
  content="$(tail -n 120 "$LOG_FILE" 2>/dev/null || true)"

  if [[ "$prompt_seen" -eq 0 ]] && grep -qE 'prompt\.submitted|Prompt submitted|Submitted prompt|prompt submitted' <<<"$content" 2>/dev/null; then
    emit_bullet "• prompt submitted (checkpoint 1 satisfied)"
    prompt_seen=1
  fi

  if [[ "$bytes" -gt "$last_bytes" ]]; then
    emit_bullet "• activity +$((bytes - last_bytes)) B (total ${bytes} B)"
    last_bytes="$bytes"
    last_growth_ts="$(date +%s)"
    stall_warned=0
  else
    local idle=$(( $(date +%s) - last_growth_ts ))
    if [[ "$idle" -ge "$STALL_SEC" && "$stall_warned" -eq 0 ]]; then
      emit_bullet "• idle ${idle}s — prepare stuck escalation (checkpoint 2)"
      stall_warned=1
    fi
  fi

  if grep -qiE 'ERROR:|0-token|rate limit|429|token plan|not logged in|Queued follow-up' <<<"$content"; then
    emit_bullet "• signal: $(grep -oiE 'ERROR:[^[:space:]]+|0-token|rate limit|429|token plan|not logged in|Queued follow-up' <<<"$content" | tail -1 || echo anomaly)"
  fi

  floor="${SB_AGENT_CLAUDE_LOG_FLOOR:-512}"
  if [[ "$floor_announced" -eq 0 && "$bytes" -ge "$floor" ]]; then
    emit_bullet "• log floor met (${bytes} B ≥ ${floor} B)"
    floor_announced=1
  elif [[ "$bytes" -gt 0 && "$bytes" -lt "$floor" && "$stall_warned" -eq 1 ]]; then
    emit_bullet "• below log floor (${bytes} B < ${floor} B) — do not claim PASS"
  fi
}

if [[ "$ONCE" -eq 1 ]]; then
  scan_log
  exit 0
fi

emit_bullet "watching $LOG_FILE (interval ${INTERVAL}s, stall ${STALL_SEC}s)"
while true; do
  scan_log
  sleep "$INTERVAL"
done
