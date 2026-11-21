#!/usr/bin/env bash
# PTY contract test: blocking decision_class clarify picker (row 6 harness).
# Runs against recorded ANSI fixture — no live Claude API.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="${REPO_ROOT}/tests/tui-contract/fixtures/blocking-decision-picker.ansi"
EXPECT_TEST="${REPO_ROOT}/tests/tui-contract/lib/blocking-decision-picker-contract.expect"

if [[ ! -f "$FIXTURE" ]]; then
  echo "FAIL: missing fixture $FIXTURE" >&2
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

if ! command -v expect >/dev/null 2>&1; then
  echo "FAIL: expect not installed (required for tui-contract)" >&2
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

if RTK_DISABLED=1 expect "$EXPECT_TEST"; then
  echo "PASS: test-blocking-decision-picker.sh"
  echo "Results: 1 passed, 0 failed"
else
  echo "FAIL: test-blocking-decision-picker.sh"
  echo "Results: 0 passed, 1 failed"
  exit 1
fi
