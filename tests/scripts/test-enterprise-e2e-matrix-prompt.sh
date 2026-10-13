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

build_matrix_prompt() {
  local route="$1"
  local prompt_card="$2"
  local evidence_path="$3"
  local row_num="${4:-}"
  local slug="${5:-}"
  if [[ "$row_num" == "1" ]]; then
    printf '%s %s Enterprise E2E routing validation only. Route this request through the Silver Bullet orchestrator and invoke the composed workflow skill. Stop when routing completes.' \
      "$route" "$prompt_card"
    return 0
  fi
  matrix_router_workflow_prompt "$slug" "$prompt_card" "$evidence_path"
}

row1_prompt="$(build_matrix_prompt '/sb' 'I need to add order validation to the API — route me.' '.planning/workflows/router-session.md' '1' 'silver-router')"
row2_prompt="$(build_matrix_prompt '/sb:deep-research' 'Should we use Postgres or SQLite for orders?' 'docs/ADR-001-runtime.md' '2' 'silver-deep-research')"
row5_prompt="$(build_matrix_prompt '/sb:ui' 'Show API version in the admin UI badge.' 'ui/src/App.jsx' '5' 'silver-ui')"

assert_contains "row 1 prompt starts with /sb slash command" "$row1_prompt" '/sb I need to add order validation'
assert_contains "row 1 prompt is routing-only" "$row1_prompt" 'routing validation only'
assert_not_contains "row 1 prompt avoids evidence boilerplate" "$row1_prompt" 'Create workflow evidence'

assert_contains "row 2 prompt starts with /sb router slash command" "$row2_prompt" '/sb Should we use Postgres'
assert_contains "row 2 prompt names workflow slug" "$row2_prompt" 'silver-deep-research workflow'
assert_contains "row 2 prompt names evidence path" "$row2_prompt" 'docs/ADR-001-runtime.md'
assert_contains "row 2 prompt includes matrix autonomous clarify policy" "$row2_prompt" 'Matrix autonomous mode'
assert_not_contains "row 2 prompt avoids native /sb:deep-research subcommand" "$row2_prompt" '/sb:deep-research'
assert_not_contains "row 2 prompt avoids legacy skill markdown link form" "$row2_prompt" 'Use the ['

assert_contains "row 5 prompt starts with /sb router slash command" "$row5_prompt" '/sb Show API version'
assert_contains "row 5 prompt names silver-ui workflow" "$row5_prompt" 'silver-ui workflow'
assert_contains "row 5 prompt names ui artifact evidence path" "$row5_prompt" 'ui/src/App.jsx'
assert_not_contains "row 5 prompt avoids native /sb:ui subcommand" "$row5_prompt" '/sb:ui'
assert_not_contains "row 5 prompt avoids stale workflow md evidence" "$row5_prompt" 'ui-version-badge.md'

MATRIX_SCRIPT="${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh"
matrix_row5="$(grep -F "silver-ui" "$MATRIX_SCRIPT" | head -1 || true)"
assert_contains "matrix harness row 5 evidence matches WORKFLOW_E2E_MATRIX.md" "$matrix_row5" 'ui/src/App.jsx'

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
