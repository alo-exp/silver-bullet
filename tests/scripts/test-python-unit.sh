#!/usr/bin/env bash
# Run the Python unit tests in tests/python (unittest discovery) and report
# them in the runner's "Results: N passed, M failed" format.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$REPO_ROOT/tests/python"

status=0
output="$(cd "$TEST_DIR" && python3 -m unittest discover -s . -t . -p 'test_*.py' 2>&1)" || status=$?
printf '%s\n' "$output"

ran=$(printf '%s\n' "$output" | grep -oE '^Ran [0-9]+ test' | grep -oE '[0-9]+' | tail -1 || true)
ran=${ran:-0}
failures=$(printf '%s\n' "$output" | grep -oE 'failures=[0-9]+' | grep -oE '[0-9]+' | tail -1 || true)
errors=$(printf '%s\n' "$output" | grep -oE 'errors=[0-9]+' | grep -oE '[0-9]+' | tail -1 || true)
failed=$(( ${failures:-0} + ${errors:-0} ))
if [[ $status -ne 0 && $failed -eq 0 ]]; then
  failed=1
fi
printf '\nResults: %d passed, %d failed\n' "$((ran - ${failures:-0} - ${errors:-0}))" "$failed"
[[ $status -eq 0 ]]
