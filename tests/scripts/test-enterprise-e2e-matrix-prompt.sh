#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    ((FAIL++)) || true
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc — unexpected [$needle]"
    ((FAIL++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${REPO_ROOT}/tests/e2e-live/lib/skill-prompt.sh"

row1_prompt="$(matrix_route_prompt '/silver' 'I need to add order validation to the API — route me.' '.planning/workflows/router-session.md' '')"
row2_prompt="$(matrix_route_prompt '/silver:research' 'Should we use Postgres or SQLite for orders?' 'docs/ADR-001-runtime.md' '')"

assert_contains "row 1 prompt starts with /silver slash command" "$row1_prompt" '/silver I need to add order validation'
assert_contains "row 1 prompt names evidence path" "$row1_prompt" '.planning/workflows/router-session.md'
assert_not_contains "row 1 prompt avoids legacy skill markdown link form" "$row1_prompt" 'Use the ['

assert_contains "row 2 prompt starts with /silver:research slash command" "$row2_prompt" '/silver:research Should we use Postgres'
assert_contains "row 2 prompt names evidence path" "$row2_prompt" 'docs/ADR-001-runtime.md'

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
