#!/usr/bin/env bash
# Pass 10 Claude High Pi launch. No set -u. No tee. No PIPESTATUS.
# Preserve invoke.sh exit code into review-attempt10-exit.txt.

export PI_PROVIDER=omniroute
export PI_MODEL=claude/claude-opus-5-high
export PI_CONTINUE_MAX=0
export PI_NI_ZERO_BYTE_IDLE_SEC=7200
export PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC=7200
export PI_RUN_TIMEOUT=7200
export PI_RUN_TAIL_IDLE_TIMEOUT=7200
export PI_EXPECT_FILE_MIN_BYTES=2500

RUNG="/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high"
LOG="$RUNG/logs/review-attempt10-stdout.txt"
EXITF="$RUNG/logs/review-attempt10-exit.txt"
REPO="/Users/shafqat/projects/silver-bullet/repo"

mkdir -p "$RUNG/logs"
rm -f "$RUNG/review-rerun-10.md" "$RUNG/review-rerun-10.md.IN_PROGRESS-stub-aside"

cd "$REPO"
bash "$REPO/scripts/agent-pi/invoke.sh" \
  --work-dir "$RUNG" \
  --brief-file "$RUNG/brief-review-rerun-10.md" \
  --expect-file "$RUNG/review-rerun-10.md" \
  --interaction-mode non-interactive \
  --mode permissive \
  > "$LOG" 2>&1
ec=$?
printf "%s\n" "$ec" > "$EXITF"
exit "$ec"
