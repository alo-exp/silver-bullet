#!/usr/bin/env bash
# RFL rung 9: GPT-5.6 Sol Extra High REVIEW ONLY via /silver:agent-codex NI (codex exec).
# scripts/agent-codex/invoke.sh is absent at detached 1569b060; D7 native exec is the NI path.
set -euo pipefail
ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOGDIR="$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-09-gpt56-sol-xhigh"
export HOME="/Users/shafqat"
export CODEX_HOME="/Users/shafqat/.codex"
export SB_ROOT="$ROOT"
export CODEX_WORK_DIR="$ROOT"
export SB_AGENT_DELEGATE_V2=0
export SB_AGENT_DELEGATE_DIRECT_FALLBACK=1
export RTK_DISABLED=1
export SB_AGENT_CODEX_FIXTURE=0
export SB_AGENT_CODEX_LIGHTWEIGHT=1
export SB_ORCHESTRATOR_WORKER=1
export SB_ORCHESTRATOR_PARENT=0
export CODEX_MODEL="gpt-5.6-sol"
export CODEX_REASONING_EFFORT="xhigh"
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOGDIR/invoke-start.txt"
set +e
HOME="$HOME" CODEX_HOME="$CODEX_HOME" \
  /Users/shafqat/.local/bin/codex exec --skip-git-repo-check \
    -m gpt-5.6-sol -c model_reasoning_effort=xhigh \
    -C "$ROOT" \
    --sandbox workspace-write \
    --dangerously-bypass-hook-trust \
    - \
    < "$LOGDIR/brief.md" \
    > "$LOGDIR/codex-run.log" 2> "$LOGDIR/codex-run.err"
INVOKE_EXIT=$?
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "INVOKE_EXIT=$INVOKE_EXIT"
} > "$LOGDIR/invoke-end.txt"
exit "$INVOKE_EXIT"
