#!/usr/bin/env bash
# Bounded Pi invoke for rung_10_review. First-byte window 600s; kill 0% CPU hangs; do not wait 13m.
# Avoid bash 3.2 + set -u empty-array EXTRA[@] unbound.
# work-dir is the rung folder (not work/). Do not export a 120s zero-byte idle override.
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-10-claude-opus-5-high"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
REPORT="${RUNG}/review.md"
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
mkdir -p "$LOGDIR"
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "START ${START}"
  echo "PI_PROVIDER=omniroute PI_MODEL=claude/claude-opus-5-high"
  echo "phase=rung_10_review attempt=${ATTEMPT}"
  echo "work-dir=${RUNG}"
} >"$OUT"
: >"$ERR"

export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-high
# bash 3.2 + set -u: empty arrays unbound; pass retry flags as a string.
# shellcheck disable=SC2086
bash "$INVOKE" \
  --work-dir "$RUNG" \
  --brief-file "${RUNG}/brief-review.md" \
  --expect-file "${RUNG}/review.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" \
  $RETRY_FLAGS >>"$OUT" 2>>"$ERR" &
INV_PID=$!
echo "INV_PID=${INV_PID}" >>"$OUT"

# First-byte window 600s; kill idle 0% CPU hangs; do not wait 13m.
HANG_SEC=600
POLL=15
elapsed=0
progress=0
while kill -0 "$INV_PID" 2>/dev/null; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  rsize=0
  if [[ -f "$REPORT" ]]; then
    rsize=$(wc -c <"$REPORT" | tr -d ' ')
  fi
  if [[ "$rsize" -ge 800 ]]; then
    progress=1
  fi
  cpu="$(ps -o pid=,pcpu=,comm= -p "$INV_PID" 2>/dev/null || true)"
  echo "WATCH elapsed=${elapsed}s progress=${progress} rsize=${rsize} inv=${cpu} report=$([ "$rsize" -ge 800 ] && echo yes || echo no)" >>"$OUT"
  if [[ "$progress" -eq 0 && "$elapsed" -ge "$HANG_SEC" ]]; then
    echo "HANG_KILLED after ${elapsed}s: no review.md >=800 bytes within 600s first-byte window" >>"$OUT"
    kill -TERM "$INV_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$INV_PID" 2>/dev/null || true
    wait "$INV_PID" 2>/dev/null || true
    echo "EXIT:143" >>"$OUT"
    echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
    exit 143
  fi
done
wait "$INV_PID"
RC=$?
if [[ -s "$REPORT" ]]; then
  echo "REPORT_BYTES=$(wc -c <"$REPORT" | tr -d ' ')" >>"$OUT"
else
  echo "NO_REPORT after EXIT:${RC}" >>"$OUT"
  echo "EXIT:${RC}" >>"$OUT"
fi
echo "EXIT:${RC}" >>"$OUT"
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
exit "$RC"
