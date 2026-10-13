#!/usr/bin/env bash
MAIN=/Users/shafqat/projects/silver-bullet/repo
SB_ROOT=/private/tmp/sb-main-row11-fp
TIMELINE="$MAIN/.e2e-r9-claude-timeline.md"
REG="$SB_ROOT/.planning/enterprise-e2e/.row-pass-registry.json"
FP=claude@89e2ab8f96a1+724a435c9991
TEST_APP=/Users/shafqat/projects/enterprise-grade-test-app-round9-claude
BASELINE=8482e60
LOG="$SB_ROOT/.e2e-r9-claude-matrix-live.log"
while kill -0 "$(cat "$MAIN/.e2e-r9-claude-driver.pid" 2>/dev/null)" 2>/dev/null; do
  d=$(cat "$MAIN/.e2e-r9-claude-driver.pid" 2>/dev/null)
  reg=$(jq -r --arg fp "$FP" '.installs[$fp].rows | length // 0' "$REG" 2>/dev/null)
  row=$(grep -E '^=== Row ' "$LOG" 2>/dev/null | tail -1 || true)
  commits=$(git -C "$TEST_APP" rev-list --count "${BASELINE}..HEAD" 2>/dev/null || echo 0)
  branch=$(git -C "$TEST_APP" branch --show-current 2>/dev/null)
  echo "- **$(date -u +%Y-%m-%dT%H:%M:%SZ)** driver=$d reg=${reg}/22 | branch=$branch commits=$commits | ${row:-preflight}" >> "$TIMELINE"
  sleep 75
done
echo "- **$(date -u +%Y-%m-%dT%H:%M:%SZ)** driver exited — monitor stop" >> "$TIMELINE"
