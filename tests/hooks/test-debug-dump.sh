#!/usr/bin/env bash
# Tests for hooks/debug-dump.sh
# Ensures the debug hook stays fail-open and only writes when explicitly enabled.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/debug-dump.sh"
PASS=0
FAIL=0

assert_pass() {
  local label="$1"
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$label"
}

assert_fail() {
  local label="$1" message="$2"
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n  %s\n' "$label" "$message"
}

assert_empty() {
  local label="$1" value="$2"
  if [[ -z "$value" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "expected empty output, got: $value"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
mkdir -p "$HOME_DIR/.claude/.silver-bullet"

payload='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo debug"}}'

run_hook() {
  HOME="$HOME_DIR" bash "$HOOK" 2>/dev/null <<EOF
$1
EOF
}

echo "=== debug-dump.sh tests ==="

echo "--- Test 1: disabled by default ---"
out="$(run_hook "$payload")"
assert_empty "disabled hook stays silent" "$out"
if [[ ! -e "$HOME_DIR/.claude/.silver-bullet/hook-dump.jsonl" ]]; then
  assert_pass "disabled hook does not create dump file"
else
  assert_fail "disabled hook does not create dump file" "unexpected hook-dump.jsonl file"
fi

echo "--- Test 2: enabled flag writes payload ---"
touch "$HOME_DIR/.claude/.silver-bullet/debug-dump"
out="$(run_hook "$payload")"
assert_empty "enabled hook stays silent" "$out"
dump_file="$HOME_DIR/.claude/.silver-bullet/hook-dump.jsonl"
if [[ -f "$dump_file" ]]; then
  assert_pass "enabled hook creates dump file"
  if grep -qF '"tool_name":"Bash"' "$dump_file" && grep -qF '"command":"echo debug"' "$dump_file"; then
    assert_pass "enabled hook writes payload JSON"
  else
    assert_fail "enabled hook writes payload JSON" "payload JSON missing from $dump_file"
  fi
else
  assert_fail "enabled hook creates dump file" "missing $dump_file"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
