#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Silver Bullet Live AI E2E Test Suite"
echo "========================================"
echo ""
echo "WARNING: These tests invoke real Claude CLI."
echo "Estimated cost: \$0.10-\$0.60 per full run."
echo ""

# Check claude CLI exists
if ! /Users/shafqat/.local/bin/claude --version >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found or not working at /Users/shafqat/.local/bin/claude"
  exit 1
fi

TOTAL_FAIL=0

run_suite() {
  local name="$1" script="$2"
  echo ""
  echo "--- Running: $name ---"
  if bash "$script"; then
    echo "SUITE PASSED: $name"
  else
    echo "SUITE FAILED: $name"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

run_suite "Enforcement" "$SCRIPT_DIR/test-live-enforcement.sh"
run_suite "Skill Recording" "$SCRIPT_DIR/test-live-skill-recording.sh"
run_suite "Full Scenario" "$SCRIPT_DIR/test-live-full-scenario.sh"
run_suite "Doc Scheme" "$SCRIPT_DIR/test-live-doc-scheme.sh"

echo ""
echo "========================================"
if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo "  OVERALL: $TOTAL_FAIL suite(s) FAILED"
  exit 1
else
  echo "  OVERALL: ALL SUITES PASSED"
  exit 0
fi
