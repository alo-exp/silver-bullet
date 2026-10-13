#!/usr/bin/env bash
set -euo pipefail
export PI_PROVIDER=omniroute
export PI_MODEL=cursor/grok-4.6-high
export PI_EXPECT_FILE_MIN_BYTES=800
R7="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-07-cursor-grok-4.6-high"
REPO="/Users/shafqat/projects/silver-bullet/repo"
LOG="$R7/logs/triage-fix-smoke.txt"
{
  echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PI_PROVIDER=$PI_PROVIDER PI_MODEL=$PI_MODEL PI_EXPECT_FILE_MIN_BYTES=$PI_EXPECT_FILE_MIN_BYTES"
  if test -f "$R7/review.md"; then
    echo "review.md_exists_before=yes"
  else
    echo "review.md_exists_before=no"
  fi
} | tee "$LOG"
set +e
bash "$REPO/scripts/agent-pi/invoke.sh" \
  --work-dir "$R7" \
  --brief-file "$R7/brief-review.md" \
  --expect-file "$R7/review.md" \
  --interaction-mode non-interactive \
  --sb-root "$REPO" \
  2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
set -e
echo "INVOKE_EXIT=$rc" | tee -a "$LOG"
if test -f "$R7/review.md"; then
  echo "review.md_exists_after=yes" | tee -a "$LOG"
  wc -c "$R7/review.md" | tee -a "$LOG"
else
  echo "review.md_exists_after=no" | tee -a "$LOG"
fi
echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG"
exit "$rc"
