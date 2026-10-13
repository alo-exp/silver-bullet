#!/usr/bin/env bash
# Recover named-model review.md via /silver:agent-pi. Review-only. No freeze edits.
# Hang-kill ~9m if no official review.md (do not treat events.jsonl as progress).
set -u
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
RUNG="${1:?rung dir}"
PI_MODEL="${2:?PI_MODEL slug}"
ATTEMPT="${3:-1}"
PHASE="${4:-review}"

LOGDIR="${RUNG}/logs"
WORK="${RUNG}/work"
REPORT="${RUNG}/review.md"
mkdir -p "$LOGDIR" "$WORK"

if [[ "$ATTEMPT" == "1" ]]; then
  OUT="${LOGDIR}/recover-a1-stdout.txt"
  ERR="${LOGDIR}/recover-a1-stderr.txt"
  EXTRA_FLAGS=""
else
  OUT="${LOGDIR}/recover-a${ATTEMPT}-stdout.txt"
  ERR="${LOGDIR}/recover-a${ATTEMPT}-stderr.txt"
  EXTRA_FLAGS="--use-print"
fi

START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "START ${START}"
  echo "PI_PROVIDER=omniroute PI_MODEL=${PI_MODEL}"
  echo "phase=${PHASE} attempt=${ATTEMPT}"
  echo "hang_sec=540 progress=review.md_only"
} >"$OUT"
: >"$ERR"

# If a leftover grok/empty review.md is present, do not count it as named success.
named_report_ok() {
  [[ -s "$REPORT" ]] || return 1
  if grep -qiE 'Grok 4\.6 High substitute|In-session substitute|written as \*\*Grok' "$REPORT" 2>/dev/null; then
    return 1
  fi
  # Require some substance (not a one-liner stub).
  local bytes
  bytes="$(wc -c <"$REPORT" | tr -d ' ')"
  [[ "$bytes" -ge 800 ]] || return 1
  return 0
}

export PI_PROVIDER=omniroute
export PI_MODEL
export PI_RUN_TIMEOUT="${PI_RUN_TIMEOUT:-900}"
export PI_RUN_TAIL_IDLE_TIMEOUT="${PI_RUN_TAIL_IDLE_TIMEOUT:-600}"

# shellcheck disable=SC2086
bash "$INVOKE" \
  --work-dir "$WORK" \
  --brief-file "${RUNG}/brief-review.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" \
  $EXTRA_FLAGS >>"$OUT" 2>>"$ERR" &
INV_PID=$!

HANG_SEC="${HANG_SEC:-540}"
POLL=15
elapsed=0
while kill -0 "$INV_PID" 2>/dev/null; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  cpu="$(ps -o pid=,pcpu=,comm= -p "$INV_PID" 2>/dev/null || true)"
  kids="$(pgrep -P "$INV_PID" 2>/dev/null || true)"
  kidcpu=""
  if [[ -n "$kids" ]]; then
    # shellcheck disable=SC2046,SC2086
    kidcpu="$(ps -o pid=,pcpu=,comm= -p $(echo "$kids" | tr '\n' ',') 2>/dev/null || true)"
  fi
  if named_report_ok; then
    echo "WATCH elapsed=${elapsed}s progress=1 inv=${cpu} kids=${kidcpu} report=yes" >>"$OUT"
  else
    echo "WATCH elapsed=${elapsed}s progress=0 inv=${cpu} kids=${kidcpu} report=$([ -s "$REPORT" ] && echo stub_or_missing || echo no)" >>"$OUT"
  fi
  if ! named_report_ok && [[ "$elapsed" -ge "$HANG_SEC" ]]; then
    echo "HANG_KILLED after ~$((elapsed/60))m: no named review.md (events.jsonl ignored)" >>"$OUT"
    kill -TERM "$INV_PID" 2>/dev/null || true
    sleep 2
    pkill -TERM -P "$INV_PID" 2>/dev/null || true
    kill -KILL "$INV_PID" 2>/dev/null || true
    # also reap pi children that may have been reparented
    pkill -f "pi -p --provider omniroute --model ${PI_MODEL}" 2>/dev/null || true
    wait "$INV_PID" 2>/dev/null || true
    echo "EXIT:143" >>"$OUT"
    echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
    exit 143
  fi
done
wait "$INV_PID"
RC=$?
if named_report_ok; then
  echo "NAMED_REVIEW_OK bytes=$(wc -c <"$REPORT" | tr -d ' ')" >>"$OUT"
  echo "EXIT:${RC}" >>"$OUT"
else
  echo "NO_NAMED_REVIEW EXIT:${RC}" >>"$OUT"
fi
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
if named_report_ok; then
  exit 0
fi
exit "$RC"
