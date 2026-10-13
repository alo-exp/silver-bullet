#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
# shellcheck source=tests/e2e-live/lib/recommended-tools-e2e.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/recommended-tools-e2e.sh"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$REPO_ROOT/hooks/lib/recommended-tools.sh" ]] && source "$REPO_ROOT/hooks/lib/recommended-tools.sh"
# shellcheck source=/dev/null
[[ -f "$REPO_ROOT/hooks/lib/alumnium-gate.sh" ]] && source "$REPO_ROOT/hooks/lib/alumnium-gate.sh"
# shellcheck source=/dev/null
[[ -f "$REPO_ROOT/hooks/lib/rtk-gate.sh" ]] && source "$REPO_ROOT/hooks/lib/rtk-gate.sh"
# shellcheck source=/dev/null
[[ -f "$REPO_ROOT/hooks/lib/context-mode-gate.sh" ]] && source "$REPO_ROOT/hooks/lib/context-mode-gate.sh"

export SILVER_BULLET_RUNTIME="${SB_E2E_LIVE_RUNTIME:-cursor}"

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
  echo "SKIP: no WORK_DIR/.silver-bullet.json (preflight runs before scenario workspace)"
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

if sb_alumnium_npx_available 2>/dev/null; then
  echo "PASS: alumnium npm package reachable"
  PASS=$((PASS + 1))
else
  echo "FAIL: alumnium npm package not reachable"
  FAIL=$((FAIL + 1))
fi

if sb_alumnium_platform_artifact_present "$REPO_ROOT" 2>/dev/null; then
  echo "PASS: alumnium MCP wired for ${SILVER_BULLET_RUNTIME}"
  PASS=$((PASS + 1))
else
  echo "FAIL: alumnium MCP not wired for ${SILVER_BULLET_RUNTIME}"
  FAIL=$((FAIL + 1))
fi

export PATH="${HOME}/.local/bin:${PATH}"
if sb_rtk_cli_available 2>/dev/null; then
  echo "PASS: rtk CLI available"
  PASS=$((PASS + 1))
else
  echo "FAIL: rtk CLI missing for E2E"
  FAIL=$((FAIL + 1))
fi

if sb_context_mode_cli_available 2>/dev/null; then
  echo "PASS: context-mode CLI available"
  PASS=$((PASS + 1))
else
  echo "FAIL: context-mode CLI missing for E2E"
  FAIL=$((FAIL + 1))
fi

print_results
