#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    (( FAIL++ )) || true
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ORIGINAL_HOME="$TMP/original-home"
mkdir -p "$ORIGINAL_HOME/.claude" "$ORIGINAL_HOME/.codex"

export HOME="$ORIGINAL_HOME"
TODO_APP_ROOT="$TMP/todo-app"
mkdir -p "$TODO_APP_ROOT"
export SB_TEST_TODO_APP_ROOT="$TODO_APP_ROOT"
export SB_E2E_LIVE_RUNTIME="claude"

# shellcheck source=tests/e2e-live/helpers.sh
source "${SCRIPT_DIR}/../e2e-live/helpers.sh"

mkdir -p "$SB_RUNTIME_HOME_ROOT"
cat > "${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.json" <<'EOF'
{"plugin:test:server":{"timestamp":123}}
EOF

backup_session_state

backup_file="${SB_TEST_DIR}/mcp-needs-auth-cache.e2e-live-backup-$$"
assert_file_exists "auth cache backup created" "$backup_file"
assert_eq "auth cache cleared for live run" "{}" "$(tr -d '\n\r\t ' < "${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.json")"

restore_session_state
assert_eq "auth cache restored after teardown" '{"plugin:test:server":{"timestamp":123}}' "$(tr -d '\n\r\t ' < "${SB_RUNTIME_HOME_ROOT}/mcp-needs-auth-cache.json")"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
