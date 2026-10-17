#!/usr/bin/env bash
# Run the JavaScript/TypeScript unit tests in tests/js with Node's built-in test
# runner and report them in the runner's "Results: N passed, M failed" format.
# During coverage runs (SB_COV_MAIN_DIR set) Node's coverage is written as LCOV
# to $SB_COV_MAIN_DIR/js/ and folded into the report by tests/coverage/sbcov.py.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node not installed"
  echo "Results: 0 passed, 0 failed"
  exit 0
fi

shopt -s nullglob
tests=("$REPO_ROOT"/tests/js/*.test.mjs)
if [[ ${#tests[@]} -eq 0 ]]; then
  echo "Results: 0 passed, 0 failed"
  exit 0
fi

args=(--test --test-reporter=tap --test-reporter-destination=stdout)
if [[ -n "${SB_COV_MAIN_DIR:-}" ]]; then
  mkdir -p "$SB_COV_MAIN_DIR/js"
  args+=(--experimental-test-coverage
    --test-coverage-include="$REPO_ROOT/site/**/*.js"
    --test-coverage-include="$REPO_ROOT/scripts/**/*.mjs"
    --test-coverage-include="$REPO_ROOT/scripts/**/*.ts"
    --test-reporter=lcov --test-reporter-destination="$SB_COV_MAIN_DIR/js/lcov-$$.info")
fi

status=0
output="$(cd "$REPO_ROOT" && node "${args[@]}" "${tests[@]}" 2>&1)" || status=$?
printf '%s\n' "$output"
pass=$(printf '%s\n' "$output" | grep -oE '^# pass [0-9]+' | grep -oE '[0-9]+' | tail -1 || true)
fail=$(printf '%s\n' "$output" | grep -oE '^# fail [0-9]+' | grep -oE '[0-9]+' | tail -1 || true)
pass=${pass:-0}
fail=${fail:-0}
[[ $status -ne 0 && $fail -eq 0 ]] && fail=1
printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[[ $status -eq 0 ]]
