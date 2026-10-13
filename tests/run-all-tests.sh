#!/usr/bin/env bash
# Unified test runner: runs all hook unit tests, script unit tests, and integration scenario tests
# Usage: bash tests/run-all-tests.sh
set -euo pipefail

# Default to Claude runtime for live/E2E verification; Kay remains available via
# scripts/run-sb-live-tests-kay.sh when isolated Codex-compatible runs are needed.
: "${SILVER_BULLET_RUNTIME:=claude}"
export SILVER_BULLET_RUNTIME

export SB_LIVE_AGENT="${SB_LIVE_AGENT:-claude}"
export SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-claude}"
export SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-claude}"
export SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-claude}"
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT="${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-1}"

_repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$_repo_root/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$_repo_root/hooks/lib/runtime-paths.sh"
  export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_PASS=0
SUITE_FAIL=0

run_suite() {
  local label="$1" dir="$2"
  local suite_pass=0 suite_fail=0 file_count=0
  local -a failed_files=()

  printf '\n========================================\n'
  printf '  %s\n' "$label"
  printf '========================================\n\n'

  for test_file in "$dir"/test-*.sh; do
    [[ -f "$test_file" ]] || continue
    file_count=$((file_count + 1))
    local basename
    basename=$(basename "$test_file")
    echo "[ $basename ]"

    local output exit_code=0
    output=$(bash "$test_file" </dev/null 2>&1) || exit_code=$?

    printf '%s\n' "$output"

    # Extract PASS/FAIL counts from "Results: N passed, M failed" line
    local p f
    p=$(printf '%s' "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    f=$(printf '%s' "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    # Default to 0 if empty
    p=${p:-0}
    f=${f:-0}
    suite_pass=$((suite_pass + p))
    suite_fail=$((suite_fail + f))

    if [[ $exit_code -ne 0 ]]; then
      # Some contract tests fail before printing a Results line. Count the
      # non-zero file once when its own reported failure count is zero.
      if [[ $f -eq 0 ]]; then
        suite_fail=$((suite_fail + 1))
      fi
      failed_files+=("$basename")
      printf '  *** SUITE FAILED (exit %d) ***\n\n' "$exit_code"
    fi
  done

  printf '\n%s: %d files, %d passed, %d failed\n' "$label" "$file_count" "$suite_pass" "$suite_fail"
  if [[ ${#failed_files[@]} -gt 0 ]]; then
    printf 'Failed test files: %s\n' "${failed_files[*]}"
  fi
  TOTAL_PASS=$((TOTAL_PASS + suite_pass))
  TOTAL_FAIL=$((TOTAL_FAIL + suite_fail))
  if [[ $suite_fail -eq 0 ]]; then
    SUITE_PASS=$((SUITE_PASS + 1))
  else
    SUITE_FAIL=$((SUITE_FAIL + 1))
  fi
}

# Run all suites
run_suite "Hook Unit Tests" "$SCRIPT_DIR/hooks"
run_suite "Script Unit Tests" "$SCRIPT_DIR/scripts"
run_suite "Integration Scenario Tests" "$SCRIPT_DIR/integration"
run_suite "E2E Live Harness Tests" "$SCRIPT_DIR/e2e-live"
run_suite "TUI Contract Tests" "$SCRIPT_DIR/tui-contract"

# Optional enterprise E2E live wiring (interactive Claude TUI — operator-only).
# Set SB_ENTERPRISE_E2E_LIVE=1 to include structural validation in this runner.
# Full live matrix: bash scripts/run-enterprise-e2e-live-test.sh (see docs/ENTERPRISE-E2E-LIVE-TEST.md)
if [[ "${SB_ENTERPRISE_E2E_LIVE:-}" == "1" ]]; then
  run_suite "Enterprise E2E Live Tests" "$SCRIPT_DIR/enterprise-e2e-live"
fi

# Five-tool live Cursor validation (agent-cursor harness). Offline hook/script tests above always run.
# Pre-release gate (scripts/pre-release-gate.sh Stage 4c) invokes test-five-tool-prerelease-cursor.sh.
# Optional manual full live: SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full
if [[ "${SB_FIVE_TOOL_LIVE:-}" == "1" ]]; then
  printf '\n========================================\n'
  printf '  Five-Tool Live Tests (Cursor)\n'
  printf '========================================\n\n'
  live_file="$SCRIPT_DIR/live/test-live-five-tool-stack-cursor.sh"
  if [[ -f "$live_file" ]]; then
    echo "[ $(basename "$live_file") ]"
    live_exit=0
    live_output=$(bash "$live_file" </dev/null 2>&1) || live_exit=$?
    printf '%s\n' "$live_output"
    lp=$(printf '%s' "$live_output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    lf=$(printf '%s' "$live_output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    lp=${lp:-0}
    lf=${lf:-0}
    TOTAL_PASS=$((TOTAL_PASS + lp))
    TOTAL_FAIL=$((TOTAL_FAIL + lf))
    if [[ $live_exit -ne 0 || "$lf" -gt 0 ]]; then
      SUITE_FAIL=$((SUITE_FAIL + 1))
      printf '  *** SUITE FAILED (exit %d) ***\n\n' "$live_exit"
    else
      SUITE_PASS=$((SUITE_PASS + 1))
    fi
    printf '\nFive-Tool Live: %d passed, %d failed\n' "$lp" "$lf"
  fi
fi

# Run coverage matrix
printf '\n========================================\n'
printf '  Coverage Matrix\n'
printf '========================================\n\n'
coverage_exit=0
bash "$SCRIPT_DIR/integration/coverage-matrix.sh" || coverage_exit=$?
if [[ $coverage_exit -ne 0 ]]; then
  SUITE_FAIL=$((SUITE_FAIL + 1))
else
  SUITE_PASS=$((SUITE_PASS + 1))
fi

# Summary
printf '\n========================================\n'
printf '  TOTAL: %d passed, %d failed (%d/%d suites green)\n' \
  "$TOTAL_PASS" "$TOTAL_FAIL" "$SUITE_PASS" "$((SUITE_PASS + SUITE_FAIL))"
printf '========================================\n'

[[ $TOTAL_FAIL -eq 0 && $coverage_exit -eq 0 ]] && exit 0 || exit 1
