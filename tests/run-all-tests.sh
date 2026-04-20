#!/usr/bin/env bash
# Unified test runner: runs all hook unit tests, script unit tests, and integration scenario tests
# Usage: bash tests/run-all-tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_PASS=0
SUITE_FAIL=0

run_suite() {
  local label="$1" dir="$2"
  local suite_pass=0 suite_fail=0 file_count=0

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
    output=$(bash "$test_file" 2>&1) || exit_code=$?

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
      printf '  *** SUITE FAILED (exit %d) ***\n\n' "$exit_code"
    fi
  done

  printf '\n%s: %d files, %d passed, %d failed\n' "$label" "$file_count" "$suite_pass" "$suite_fail"
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
