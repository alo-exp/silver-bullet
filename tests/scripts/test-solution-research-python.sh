#!/usr/bin/env bash
# Run silver-deep-research Python unit tests (solution compare, phase gate, SPA).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$REPO_ROOT/skills/silver-deep-research/tests"

PASS=0
FAIL=0

output="$(cd "$TEST_DIR" && python3 -m unittest discover -s . -p 'test_*.py' -v 2>&1)" || {
  printf '%s\n' "$output"
  printf '\nResults: 0 passed, 1 failed\n'
  exit 1
}

printf '%s\n' "$output"

# Count unittest results
passed=$(printf '%s\n' "$output" | grep -cE '^ok$' || true)
failed=$(printf '%s\n' "$output" | grep -cE '^(FAIL|ERROR)' || true)
errors=$(printf '%s\n' "$output" | grep -c '^ERROR:' || true)
failures=$(printf '%s\n' "$output" | grep -c '^FAIL:' || true)
total_fail=$((failed + errors + failures))

# unittest discover -v prints "Ran N tests" line
ran=$(printf '%s\n' "$output" | grep -oE 'Ran [0-9]+ tests' | grep -oE '[0-9]+' || echo "0")
if printf '%s\n' "$output" | grep -q '^FAILED '; then
  printf '\nResults: %s passed, suite failed\n' "$((ran - total_fail))"
  exit 1
fi

printf '\nResults: %s passed, 0 failed\n' "$ran"
exit 0

