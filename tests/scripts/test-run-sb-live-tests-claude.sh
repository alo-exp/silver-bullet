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
WRAPPER="$REPO_ROOT/scripts/run-sb-live-tests-claude.sh"

echo "=== Claude-only SB live test wrapper checks ==="
assert_executable "wrapper is executable" "$WRAPPER"
assert_file_contains "wrapper sets claude live agent" "$WRAPPER" 'SB_LIVE_AGENT="${SB_LIVE_AGENT:-claude}"'
assert_file_contains "wrapper sets claude e2e agent" "$WRAPPER" 'SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-claude}"'
assert_file_contains "wrapper targets claude runtime for live suite" "$WRAPPER" 'SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-claude}"'
assert_file_contains "wrapper targets claude runtime for todo-app suite" "$WRAPPER" 'SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-claude}"'
assert_file_contains "wrapper skips OpenCode proxy settings export by default" "$WRAPPER" 'SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT="${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-1}"'
assert_file_contains "wrapper runs live agent suite" "$WRAPPER" 'tests/live/run-live-tests.sh'
assert_file_contains "wrapper runs todo-app suite" "$WRAPPER" 'tests/e2e-live/run-e2e-live-tests.sh'

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
