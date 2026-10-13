#!/usr/bin/env bash
# Rung 10 verify_1 — standard invoke.sh recipe.
# work-dir is the rung folder (not work/).
# Do not export PI_NI_ZERO_BYTE_IDLE_SEC. No outer 800-byte 600s killer.
# EXIT 124 is returned to the caller; never --continue on 124 (harness already fail-fasts).
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-10-claude-opus-5-high"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
LOGDIR="${RUNG}/logs"
ATTEMPT="${1:-1}"
if test "$ATTEMPT" = "1"; then
  OUT="${LOGDIR}/verify-1-live-stdout.txt"
  ERR="${LOGDIR}/verify-1-live-stderr.txt"
else
  OUT="${LOGDIR}/verify-1-retry-stdout.txt"
  ERR="${LOGDIR}/verify-1-retry-stderr.txt"
fi
mkdir -p "$LOGDIR"
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "START ${START}"
  echo "PI_PROVIDER=omniroute PI_MODEL=claude/claude-opus-5-high"
  echo "phase=rung_10_verify_1 attempt=${ATTEMPT}"
  echo "work-dir=${RUNG}"
  echo "PI_EXPECT_FILE_MIN_BYTES=2500"
} >"$OUT"
: >"$ERR"

export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-high
export PI_EXPECT_FILE_MIN_BYTES=2500

bash "$INVOKE" \
  --work-dir "$RUNG" \
  --brief-file "${RUNG}/brief-verify-1.md" \
  --expect-file "${RUNG}/verify-1.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" >>"$OUT" 2>>"$ERR"
RC=$?
echo "EXIT:${RC}" >>"$OUT"
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
if test -f "${RUNG}/verify-1.md"; then
  BYTES=$(wc -c < "${RUNG}/verify-1.md" | tr -d ' ')
  echo "VERIFY1_BYTES=${BYTES}" >>"$OUT"
else
  echo "NO_VERIFY1" >>"$OUT"
fi
exit "$RC"
