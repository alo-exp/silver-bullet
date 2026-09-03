#!/usr/bin/env bash
# Coverage matrix: verifies all hooks from hooks.json have integration test coverage
# Reads hooks.json to enumerate hooks, then checks for matching test files
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_JSON="${REPO_ROOT}/hooks/hooks.json"
INTEGRATION_DIR="${REPO_ROOT}/tests/integration"
UNIT_DIR="${REPO_ROOT}/tests/hooks"

echo "=== Hook Coverage Matrix ==="

TOTAL=0
COVERED=0
UNCOVERED=0
uncovered_list=""

# Extract hook script names from hooks.json
# hooks.json has hook objects with "command" fields like:
#   "bash hooks/foo.sh"  (most hooks, have .sh extension)
#   "${CLAUDE_PLUGIN_ROOT}/hooks/session-start"  (session-start, no .sh)
# Capture both patterns.

hook_scripts=$(jq -r '.. | .command? // empty' "$HOOKS_JSON" 2>/dev/null \
  | grep -oE 'hooks/[a-zA-Z0-9_-]+(\.sh)?' \
  | sed 's|hooks/||' \
  | sed 's|\.sh$||' \
  | sort -u)

for hook in $hook_scripts; do
  TOTAL=$((TOTAL + 1))
  has_coverage=false

  # Check integration tests (match hook name with or without .sh)
  if grep -rlqE "${hook}(\.sh)?" "$INTEGRATION_DIR"/test-*.sh 2>/dev/null; then
    has_coverage=true
  fi

  # Check unit tests
  if grep -rlqE "${hook}(\.sh)?" "$UNIT_DIR"/test-*.sh 2>/dev/null; then
    has_coverage=true
  fi

  if [[ "$has_coverage" == true ]]; then
    COVERED=$((COVERED + 1))
    printf 'COVERED: %s\n' "$hook"
  else
    UNCOVERED=$((UNCOVERED + 1))
    uncovered_list="${uncovered_list}  - ${hook}\n"
    printf 'MISSING: %s\n' "$hook"
  fi
done

printf '\n=== Coverage: %d/%d hooks covered ===\n' "$COVERED" "$TOTAL"

if [[ $UNCOVERED -gt 0 ]]; then
  printf '\nUncovered hooks:\n%b\n' "$uncovered_list"
  exit 1
fi

printf 'All hooks have test coverage.\n'
exit 0
