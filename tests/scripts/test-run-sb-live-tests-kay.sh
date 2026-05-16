#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $path"
    (( FAIL++ )) || true
  fi
}

assert_file_not_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "FAIL: $desc — found unexpected [$needle] in $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_executable() {
  local desc="$1" path="$2"
  if [[ -x "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — not executable: $path"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/run-sb-live-tests-kay.sh"

echo "=== Kay-only SB live test wrapper checks ==="
assert_executable "wrapper is executable" "$WRAPPER"
assert_file_contains "wrapper pins MiniMax provider" "$WRAPPER" 'SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"'
assert_file_contains "wrapper pins MiniMax M2.7" "$WRAPPER" 'SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M2.7}"'
assert_file_contains "wrapper runs live runtime suite" "$WRAPPER" 'tests/live/run-live-tests.sh'
assert_file_contains "wrapper runs todo-app suite" "$WRAPPER" 'tests/e2e-live/run-e2e-live-tests.sh'

assert_file_not_contains "kay isolation helper does not fall back to codex" "$REPO_ROOT/tests/live/lib/kay-codex-isolation.sh" 'command -v codex'
assert_file_not_contains "codex runtime adapter does not fall back to codex" "$REPO_ROOT/tests/live/runtimes/codex.sh" 'command -v codex'
assert_file_not_contains "interactive launcher does not fall back to codex" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'command -v codex'

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
