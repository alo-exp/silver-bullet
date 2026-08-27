#!/usr/bin/env bash
# Parent invoke recipe only — no extra 800-byte hang killer.
# Prior wrapper pass wrote a 686-byte IN_PROGRESS stub then was SIGTERM'd at 600s
# while OmniRoute was still returning HTTP 200. Archive that stub and re-run invoke.sh.
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-10-claude-opus-5-high"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
INVOKE="${SB_ROOT}/scripts/agent-pi/invoke.sh"
REPORT="${RUNG}/review.md"
LOGDIR="${RUNG}/logs"
OUT="${LOGDIR}/review-invoke-retry-stdout.txt"
ERR="${LOGDIR}/review-invoke-retry-stderr.txt"
mkdir -p "$LOGDIR"
if test -f "$REPORT"; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  mv "$REPORT" "${LOGDIR}/review.md.stub-archived-${ts}"
  echo "archived ${LOGDIR}/review.md.stub-archived-${ts}"
fi
unset PI_NI_ZERO_BYTE_IDLE_SEC
export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-high
{
  echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PI_PROVIDER=omniroute PI_MODEL=claude/claude-opus-5-high"
  echo "phase=rung_10_review attempt=invoke-recipe"
  echo "work-dir=${RUNG}"
} >"$OUT"
: >"$ERR"
set +e
bash "$INVOKE" \
  --work-dir "$RUNG" \
  --brief-file "${RUNG}/brief-review.md" \
  --expect-file "${RUNG}/review.md" \
  --interaction-mode non-interactive \
  --sb-root "$SB_ROOT" >>"$OUT" 2>>"$ERR"
RC=$?
set -e
if test -f "$REPORT"; then
  echo "REPORT_BYTES=$(wc -c <"$REPORT" | tr -d ' ')" >>"$OUT"
else
  echo "NO_REPORT after EXIT:${RC}" >>"$OUT"
fi
echo "EXIT:${RC}" >>"$OUT"
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$OUT"
exit "$RC"
