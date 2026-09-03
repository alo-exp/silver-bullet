#!/usr/bin/env bash
# Bounded Pi invoke for rung_11_verify_2. Hang-kill ~4m if idle (0% CPU / no verify-2.md).
# Wait for verify-2.md, not events.jsonl (verify_1 note: work-dir may lack events until report).
# Avoid bash 3.2 + set -u empty-array EXTRA[@] unbound.
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-11-claude-claude-opus-5-xhigh"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
REPORT="${RUNG}/verify-2.md"
WORK="${RUNG}/work"
LOGDIR="${RUNG}/logs"
ATTEMPT="${1:-1}"
RETRY_FLAGS=""
if [[ "$ATTEMPT" == "1" ]]; then
  OUT="${LOGDIR}/verify-2-live-stdout.txt"
  ERR="${LOGDIR}/verify-2-live-stderr.txt"
else
  OUT="${LOGDIR}/verify-2-retry-stdout.txt"
  ERR="${LOGDIR}/verify-2-retry-stderr.txt"
  RETRY_FLAGS="--use-print --idle-sec 180"
fi
mkdir -p "$LOGDIR" "$WORK"
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "START ${START}"
  echo "PI_PROVIDER=omniroute PI_MODEL=claude/claude-opus-5-xhigh"
  echo "phase=rung_11_verify_2 attempt=${ATTEMPT}"
} >"$OUT"
: >"$ERR"

export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-xhigh
# bash 3.2 + set -u: empty arrays unbound; pass retry flags as a string.
# shellcheck disable=SC2086
bash "$INVOKE" \
  --work-dir "$WORK" \
  --brief-file "${RUNG}/brief-verify-2.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" \
  $RETRY_FLAGS >>"$OUT" 2>>"$ERR" &
INV_PID=$!

# Bounded idle: a few minutes, not unbounded (not 13m).
HANG_SEC=240
POLL=15
elapsed=0
progress=0
while kill -0 "$INV_PID" 2>/dev/null; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  if [[ -s "$REPORT" ]]; then
    progress=1
  fi
  cpu="$(ps -o pid=,pcpu=,comm= -p "$INV_PID" 2>/dev/null || true)"
  kids="$(pgrep -P "$INV_PID" 2>/dev/null || true)"
  kidcpu=""
  if [[ -n "$kids" ]]; then
    # shellcheck disable=SC2086
    kidcpu="$(ps -o pid=,pcpu=,comm= -p $(echo "$kids" | tr '\n' ',') 2>/dev/null || true)"
  fi
  echo "WATCH elapsed=${elapsed}s progress=${progress} inv=${cpu} kids=${kidcpu} report=$([ -s "$REPORT" ] && echo yes || echo no)" >>"$OUT"
  if [[ "$progress" -eq 0 && "$elapsed" -ge "$HANG_SEC" ]]; then
    echo "HANG_KILLED after ~$((elapsed/60))m: pi idle, no verify-2.md" >>"$OUT"
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
