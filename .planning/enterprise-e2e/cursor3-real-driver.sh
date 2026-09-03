#!/usr/bin/env bash
# Cursor-3 REAL live driver — T1 row 1 / T2 row 6 with strict-clean env (E2E-091/E2E-092).
# Usage:
#   bash .planning/enterprise-e2e/cursor3-real-driver.sh 1
#   bash .planning/enterprise-e2e/cursor3-real-driver.sh 6
# tmux:
#   tmux new-session -d -s cursor3-row6 \
#     "bash .planning/enterprise-e2e/cursor3-real-driver.sh 6 2>&1 | tee -a .e2e-cursor3-t2-row6-live.log"
set -euo pipefail

ROW="${1:-}"
if [[ ! "$ROW" =~ ^[0-9]+$ ]]; then
  echo "usage: $0 <row_number>" >&2
  exit 2
fi

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
export SB_ROOT
export SB_E2E_BRANCH=enterprise-e2e/cursor
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app-cursor
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
export SB_E2E_SURFACE_SKIP=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1
export SB_E2E_MATRIX_FORCE_ALL=1 SB_E2E_MATRIX_FORCE=1
export SB_E2E_TEST_APP_ROUND=3
export RTK_DISABLED=1
# E2E-087/E2E-092: explicit — matrix also enforces ≥1800 for cursor host.
export CLAUDE_INTERACTIVE_TIMEOUT=1800 CURSOR_AGENT_TIMEOUT=1800
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

case "$ROW" in
  1) LOG="$SB_ROOT/.e2e-cursor3-t1-row1-live.log" ;;
  6) LOG="$SB_ROOT/.e2e-cursor3-t2-row6-live.log" ;;
  *) LOG="$SB_ROOT/.e2e-cursor3-row${ROW}-live.log" ;;
esac

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT" || true

cd "$SB_ROOT"
current_branch="$(git branch --show-current 2>/dev/null || true)"
if [[ "$current_branch" != "$SB_E2E_BRANCH" ]]; then
  git checkout "$SB_E2E_BRANCH" >/dev/null 2>&1 || true
fi

echo "=== Cursor-3 REAL row ${ROW} $(date -u +%Y-%m-%dT%H:%M:%SZ) install=$(enterprise_e2e_sb_install_version_key) ===" | tee -a "$LOG"
echo "  SB_ROOT=$SB_ROOT fixture=$SB_TEST_ENTERPRISE_APP_ROOT timeout=${CLAUDE_INTERACTIVE_TIMEOUT}s" | tee -a "$LOG"

exec bash scripts/run-enterprise-e2e-matrix.sh "$ROW" 2>&1 | tee -a "$LOG"
