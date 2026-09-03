#!/usr/bin/env bash
# Bounded Pi invoke for rung_10_review. Hang-kill ~4m if idle (0% CPU / no events / no review.md).
# Avoid bash 3.2 + set -u empty-array EXTRA[@] unbound.
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-10-claude-claude-opus-5-high"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
REPORT="${RUNG}/review.md"
WORK="${RUNG}/work"
LOGDIR="${RUNG}/logs"
ATTEMPT="${1:-1}"
RETRY_FLAGS=""
if [[ "$ATTEMPT" == "1" ]]; then
  OUT="${LOGDIR}/review-live-stdout.txt"
  ERR="${LOGDIR}/review-live-stderr.txt"
else
  OUT="${LOGDIR}/review-retry-stdout.txt"
  ERR="${LOGDIR}/review-retry-stderr.txt"
  RETRY_FLAGS="--use-print --idle-sec 180"
fi
mkdir -p "$LOGDIR" "$WORK"
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "START ${START}"
  echo "PI_PROVIDER=omniroute PI_MODEL=claude/claude-opus-5-high"
  echo "phase=rung_10_review attempt=${ATTEMPT}"
} >"$OUT"
: >"$ERR"

export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-high
# bash 3.2 + set -u: empty arrays unbound; pass retry flags as a string.
# shellcheck disable=SC2086
bash "$INVOKE" \
  --work-dir "$WORK" \
  --brief-file "${RUNG}/brief-review.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" \
  $RETRY_FLAGS >>"$OUT" 2>>"$ERR" &
INV_PID=$!

# Bounded idle: a few minutes, not unbounded.
HANG_SEC=240
POLL=15
elapsed=0
progress=0
while kill -0 "$INV_PID" 2>/dev/null; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  events="$(find "$WORK" -name 'events.jsonl' -size +0c 2>/dev/null | head -n 1 || true)"
  if [[ -s "$REPORT" ]]; then
    progress=1
  fi
  if [[ -n "$events" ]]; then
    progress=1
  fi
  cpu="$(ps -o pid=,pcpu=,comm= -p "$INV_PID" 2>/dev/null || true)"
  kids="$(pgrep -P "$INV_PID" 2>/dev/null || true)"
  kidcpu=""
  if [[ -n "$kids" ]]; then
    kidcpu="$(ps -o pid=,pcpu=,comm= -p $(echo "$kids" | tr '\n' ',') 2>/dev/null || true)"
  fi
  echo "WATCH elapsed=${elapsed}s progress=${progress} inv=${cpu} kids=${kidcpu} events=${events:-none} report=$([ -s "$REPORT" ] && echo yes || echo no)" >>"$OUT"
  if [[ "$progress" -eq 0 && "$elapsed" -ge "$HANG_SEC" ]]; then
    echo "HANG_KILLED after ~$((elapsed/60))m: pi idle, no events.jsonl, no review.md" >>"$OUT"
    kill -TERM "$INV_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$INV_PID" 2>/dev/null || true
    pkill -TERM -P "$INV_PID" 2>/dev/null || true
    wait "$INV_PID" 2>/dev/null || true
    echo "EXIT:143" >>"$OUT"
    echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
    exit 143
  fi
done
wait "$INV_PID"
RC=$?
if [[ -s "$REPORT" ]]; then
  echo "EXIT:${RC}" >>"$OUT"
else
  echo "NO_REPORT after EXIT:${RC}" >>"$OUT"
  echo "EXIT:${RC}" >>"$OUT"
fi
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
exit "$RC"
