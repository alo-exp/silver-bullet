#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
# shellcheck source=tests/e2e-live/lib/recommended-tools-e2e.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/recommended-tools-e2e.sh"

echo "=== E2E Live: Recommended Tools Preflight ==="

if [[ -n "${WORK_DIR:-}" && -f "${WORK_DIR}/.silver-bullet.json" ]]; then
  sb_e2e_enable_all_recommended_tools "${WORK_DIR}/.silver-bullet.json"
  if sb_e2e_assert_all_recommended_tools_enabled "${WORK_DIR}/.silver-bullet.json"; then
    echo "PASS: all recommended tools opted in for E2E workspace"
    PASS=$((PASS + 1))
  else
    echo "FAIL: E2E workspace missing full recommended_tools opt-in"
    FAIL=$((FAIL + 1))
  fi
else
  echo "SKIP: no WORK_DIR/.silver-bullet.json (run inside scenario after init scaffold)"
  PASS=$((PASS + 1))
fi

if command -v graphify >/dev/null 2>&1; then
  echo "PASS: graphify CLI available"
  PASS=$((PASS + 1))
else
  echo "FAIL: graphify CLI missing for E2E"
  FAIL=$((FAIL + 1))
fi

if command -v agentmemory >/dev/null 2>&1; then
  echo "PASS: agentmemory CLI available"
  PASS=$((PASS + 1))
else
  echo "FAIL: agentmemory CLI missing for E2E"
  FAIL=$((FAIL + 1))
fi

if curl -sf --max-time 3 http://localhost:3111/agentmemory/health >/dev/null 2>&1; then
  echo "PASS: agentmemory server healthy"
  PASS=$((PASS + 1))
else
  echo "FAIL: agentmemory server not healthy"
  FAIL=$((FAIL + 1))
fi

for tool_id in aluminum rtk context-mode; do
  if command -v "$tool_id" >/dev/null 2>&1; then
    echo "PASS: ${tool_id} CLI available (compression tool)"
    PASS=$((PASS + 1))
  else
    echo "WARN: ${tool_id} CLI not on PATH — E2E will use mock PATH when compression gates are tested"
    PASS=$((PASS + 1))
  fi
done

print_results
