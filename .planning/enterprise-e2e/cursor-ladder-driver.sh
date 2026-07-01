#!/usr/bin/env bash
# Phase A live review-fix-ladder 8/8 — Cursor host.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-ladder-live.log"
cd "$SB_ROOT"

export SB_ROOT SILVER_BULLET_RUNTIME=cursor SB_LIVE_RUNTIME=cursor
export RTK_DISABLED=1
export SB_LIVE_REVIEW_FIX_LADDER_LIVE=1
export SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1
export SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

{
  echo "=== Phase A ladder start $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD) ==="
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh
  echo "=== Phase A ladder end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit:$? ==="
} 2>&1 | tee -a "$LOG"
