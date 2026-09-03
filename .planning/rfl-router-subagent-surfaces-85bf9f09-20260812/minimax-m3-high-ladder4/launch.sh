#!/usr/bin/env bash
# RFL ladder 4 rung 3: MiniMax M3 High via /silver:agent-opencode.
set -euo pipefail
ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOGDIR="$ROOT/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/minimax-m3-high-ladder4"
export SB_ROOT="$ROOT"
export OPENCODE_WORK_DIR="$ROOT"
export SB_AGENT_DELEGATE_V2=0
export SB_AGENT_DELEGATE_DIRECT_FALLBACK=1
export OPENCODE_BIN="$LOGDIR/bin/opencode"
export SB_AGENT_OPENCODE_REAL_BIN="${HOME}/.opencode/bin/opencode"
export SB_AGENT_OPENCODE_ART_DIR="$LOGDIR"
export OPENCODE_RUN_TIMEOUT=3600
export OPENCODE_RUN_TAIL_IDLE_TIMEOUT=1800
export RTK_DISABLED=1
export SB_AGENT_OPENCODE_FIXTURE=0
export SB_AGENT_OPENCODE_LIGHTWEIGHT=1
export SB_AGENT_OPENCODE_ARGV_LOG="$LOGDIR/wrapper-argv.log"
# Do not set/unset XDG_CONFIG_HOME (prior MiniMax attempt hid auth).
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOGDIR/invoke-start.txt"
set +e
bash "$ROOT/scripts/agent-opencode/preflight.sh" --sb-root "$SB_ROOT" \
  > "$LOGDIR/preflight.stdout" 2> "$LOGDIR/preflight.stderr"
PRE_EXIT=$?
echo "PREFLIGHT_EXIT=$PRE_EXIT" >> "$LOGDIR/invoke-start.txt"
if [[ "$PRE_EXIT" -ne 0 ]]; then
  echo "PREFLIGHT_EXIT=$PRE_EXIT" > "$LOGDIR/invoke-end.txt"
  exit "$PRE_EXIT"
fi
bash "$ROOT/scripts/agent-opencode/invoke.sh" --skip-preflight \
  --work-dir "$OPENCODE_WORK_DIR" \
  --brief-file "$LOGDIR/brief.md" \
  --log "$LOGDIR/opencode-run.log" \
  --delegation-mode multi-ai-worker-v1 \
  --multi-ai-profile ocg-minimax-m3 \
  --multi-ai-pool regular
INVOKE_EXIT=$?
REVIEW="$LOGDIR/review.md"
REVIEW_OK=0
if [[ -f "$REVIEW" ]] && grep -qE '^VERDICT: (CLEAN|NOT CLEAN|QUOTA|HASH MISMATCH)' "$REVIEW"; then
  REVIEW_OK=1
fi
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "INVOKE_EXIT=$INVOKE_EXIT"
  echo "REVIEW_OK=$REVIEW_OK"
  if [[ "$REVIEW_OK" -eq 0 ]]; then
    echo "REVIEW_MD_MISSING_OR_NO_VERDICT"
  fi
} > "$LOGDIR/invoke-end.txt"
if [[ "$REVIEW_OK" -eq 0 ]]; then
  exit 2
fi
exit "$INVOKE_EXIT"
