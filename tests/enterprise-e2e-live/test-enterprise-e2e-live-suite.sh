#!/usr/bin/env bash
# Structural validation for enterprise E2E live test wiring (no interactive Claude).
# Full live matrix requires SB_ENTERPRISE_E2E_LIVE=1 via scripts/run-enterprise-e2e-live-test.sh
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    fail "$desc — unexpected [$needle] in $file"
  else
    pass "$desc"
  fi
}

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

# --- Docs and entrypoints ---
assert_file_exists "${REPO_ROOT}/docs/ENTERPRISE-E2E-LIVE-TEST.md" "live test runbook exists"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh" "live test entrypoint executable"
assert_file_exists "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh" "live test common lib exists"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" "matrix runner executable"
assert_executable "${REPO_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh" "matrix monitor executable"
assert_executable "${REPO_ROOT}/scripts/watch-enterprise-e2e-tui.sh" "TUI watch executable"

# --- Operational learnings encoded in runbook ---
RUNBOOK="${REPO_ROOT}/docs/ENTERPRISE-E2E-LIVE-TEST.md"
for needle in \
  "SB_ENTERPRISE_E2E_LIVE=1" \
  "NO login" \
  "NO logout" \
  "API key" \
  "settings.json" \
  "SB_E2E_MATRIX_CLEAN_ENV=0" \
  "SB_E2E_MATRIX_DRY_RUN" \
  "600" \
  "429" \
  "dual-role" \
  "monitor-enterprise-e2e-matrix" \
  "watch-enterprise-e2e-tui" \
  "install-claude.sh" \
  "review-fix-ladder" \
  "run-all-tests.sh" \
  "graphify" \
  "agentmemory" \
  "Resume" \
  "RTK_DISABLED" \
  "provider restart" \
  "cursor-hook-bridge" \
  "2 consecutive clean rounds" \
  "/silver:" \
  "interactive Claude TUI"
do
  assert_contains "runbook documents: $needle" "$RUNBOOK" "$needle"
done

# --- Live entrypoint constraints ---
LIVE="${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh"
assert_contains "live entrypoint requires SB_ENTERPRISE_E2E_LIVE" "$LIVE" "SB_ENTERPRISE_E2E_LIVE"
assert_contains "live entrypoint sets CLEAN_ENV=0" "$LIVE" "SB_E2E_MATRIX_CLEAN_ENV=0"
assert_contains "live entrypoint unsets DRY_RUN" "$LIVE" "env -u SB_E2E_MATRIX_DRY_RUN"
assert_contains "live entrypoint starts monitor" "$LIVE" "monitor-enterprise-e2e-matrix.sh"
assert_contains "live entrypoint starts tui watch" "$LIVE" "watch-enterprise-e2e-tui.sh"
assert_contains "live entrypoint runs install-claude" "$LIVE" "install-claude.sh"
assert_contains "live entrypoint quota 600s default" "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh" "SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-600"
assert_not_contains "live entrypoint forbids login" "$LIVE" "auth login"
assert_not_contains "live entrypoint forbids logout" "$LIVE" "auth logout"

# --- Matrix runner learnings ---
MATRIX="${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh"
assert_contains "matrix exports settings env" "$MATRIX" "claude_matrix_export_settings_env"
assert_contains "matrix quota retry 600" "$MATRIX" "SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-600"
assert_contains "matrix uses /silver slash prompts" "$MATRIX" "/silver"
assert_not_contains "matrix docs DRY_RUN as opt-in only" "$MATRIX" 'export SB_E2E_MATRIX_DRY_RUN=1'

# --- Monitor learnings ---
MONITOR="${REPO_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"
assert_contains "monitor resume incomplete rows" "$MONITOR" "incomplete_rows"
assert_contains "monitor 429 wait 600" "$MONITOR" "QUOTA_WAIT"
assert_contains "monitor network retry" "$MONITOR" "NETWORK_WAIT"
assert_contains "monitor forces CLEAN_ENV=0 on restart" "$MONITOR" "SB_E2E_MATRIX_CLEAN_ENV=0"
assert_contains "monitor unsets DRY_RUN on restart" "$MONITOR" "env -u SB_E2E_MATRIX_DRY_RUN"

# --- Watch continuation recovery ---
WATCH="${REPO_ROOT}/scripts/watch-enterprise-e2e-tui.sh"
assert_contains "watch restarts dead monitor" "$WATCH" "ensure_monitor_alive"
assert_contains "watch continuation offset scan" "$WATCH" "grew since last pass"

# --- RTK in SB scripts ---
assert_contains "rtk-compat exports RTK_DISABLED" "${REPO_ROOT}/hooks/lib/rtk-compat.sh" "RTK_DISABLED=1"

# --- Resume helper ---
TMP_LOG="$(mktemp)"
trap 'rm -f "$TMP_LOG"' EXIT
{
  echo "=== Row 1: silver-router (/silver) ==="
  echo "  PASS: evidence at .planning/workflows/router-session.md"
  echo "=== Row 2: silver-research (/silver:research) ==="
  echo "  FAIL: missing evidence"
} >"$TMP_LOG"
inc="$(enterprise_e2e_incomplete_rows "$TMP_LOG" | tr '\n' ' ' | xargs)"
if printf '%s\n' "$inc" | grep -qw 1; then
  fail "resume must not include row 1 when PASS"
else
  pass "resume excludes row 1 when PASS"
fi
if printf '%s\n' "$inc" | grep -qw 2; then
  pass "resume includes first incomplete row 2"
else
  fail "resume includes first incomplete row 2 — got [$inc]"
fi

# --- Opt-in gate in run-all-tests ---
assert_contains "run-all-tests documents opt-in" "${REPO_ROOT}/tests/run-all-tests.sh" "SB_ENTERPRISE_E2E_LIVE"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
