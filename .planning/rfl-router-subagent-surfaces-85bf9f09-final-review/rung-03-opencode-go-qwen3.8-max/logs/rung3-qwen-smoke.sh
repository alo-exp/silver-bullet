#!/usr/bin/env bash
# One-shot Pi Qwen smoke for rung 3. Does not write a Grok substitute review.md.
set -u
RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-03-opencode-go-qwen3.8-max"
LOGDIR="$RUNG/logs"
mkdir -p "$LOGDIR"
WRAP="$LOGDIR/rung3-qwen-smoke-fix.txt"
ARGV="$LOGDIR/rung3-qwen-smoke-argv.txt"
{
  echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PI_PROVIDER=omniroute PI_MODEL=opencode-go/qwen3.8-max"
  echo "phase=rung_03_review smoke-after-thinking-off-idle-kill"
  echo "expect-file=$RUNG/review.md idle=120 hard=600"
} | tee "$WRAP"
export PI_PROVIDER=omniroute
export PI_MODEL=opencode-go/qwen3.8-max
export SB_AGENT_HOST_ARGV_FILE="$ARGV"
export PI_NI_ZERO_BYTE_IDLE_SEC=120
export PI_RUN_TIMEOUT=600
set +e
bash /Users/shafqat/projects/silver-bullet/repo/scripts/agent-pi/invoke.sh \
  --non-interactive \
  --work-dir "$RUNG" \
  --expect-file "$RUNG/review.md" \
  --brief-file "$RUNG/brief-review.md" \
  --log "$LOGDIR/rung3-qwen-smoke-delegate.log" \
  >>"$WRAP" 2>&1
rc=$?
set -e
{
  echo "EXIT:$rc"
  if [[ -f "$RUNG/review.md" ]]; then
    echo "REVIEW_OK bytes=$(wc -c < "$RUNG/review.md" | tr -d ' ')"
  else
    echo "NO_REVIEW_MD"
  fi
  echo "ARGV:"
  if [[ -f "$ARGV" ]]; then
    cat "$ARGV"
  else
    echo "(no argv dump)"
  fi
  echo "END $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee -a "$WRAP"
exit "$rc"
