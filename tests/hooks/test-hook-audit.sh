#!/usr/bin/env bash
# Tests for hooks/lib/hook-audit.sh
# Verifies the optional hook-audit sink only records when enabled.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/hook-audit.sh"
PASS=0
FAIL=0

assert_pass() {
  local label="$1"
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$label"
}

assert_fail() {
  local label="$1" detail="$2"
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n  %s\n' "$label" "$detail"
}

assert_file_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    assert_pass "$label"
  else
    assert_fail "$label" "expected pattern '$pattern' in $file"
  fi
}

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

HOME="$TMP_HOME"
export HOME SILVER_BULLET_RUNTIME=codex
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
mkdir -p "$SB_RUNTIME_STATE_DIR"

if [[ -f "$LIB" ]]; then
  # shellcheck source=hooks/lib/hook-audit.sh
  source "$LIB"
else
  assert_fail "hook-audit library exists" "missing $LIB"
fi

DEFAULT_LOG="${SB_RUNTIME_STATE_DIR}/hook-audit.jsonl"
EXPLICIT_LOG="${SB_RUNTIME_STATE_DIR}/hook-audit-explicit.jsonl"

echo "=== hook-audit.sh tests ==="

echo "--- Test 1: disabled by default ---"
rm -f "$DEFAULT_LOG" "$EXPLICIT_LOG"
unset SILVER_BULLET_HOOK_AUDIT_LOG
if declare -f sb_hook_audit_record >/dev/null 2>&1; then
  sb_hook_audit_record "dev-cycle-check" "PreToolUse" "deny" "disabled-default"
fi
if [[ ! -e "$DEFAULT_LOG" && ! -e "$EXPLICIT_LOG" ]]; then
  assert_pass "disabled audit does not create a log file"
else
  assert_fail "disabled audit does not create a log file" "unexpected audit file created"
fi

echo "--- Test 2: explicit log path records JSON lines ---"
export SILVER_BULLET_HOOK_AUDIT_LOG="$EXPLICIT_LOG"
if declare -f sb_hook_audit_record >/dev/null 2>&1; then
  sb_hook_audit_record "dev-cycle-check" "PreToolUse" "deny" "explicit-path"
fi
if [[ -f "$EXPLICIT_LOG" ]]; then
  assert_pass "explicit log path creates audit file"
  assert_file_contains "explicit log records hook name" "$EXPLICIT_LOG" '"hook_name":"dev-cycle-check"'
  assert_file_contains "explicit log records event" "$EXPLICIT_LOG" '"hook_event":"PreToolUse"'
  assert_file_contains "explicit log records decision" "$EXPLICIT_LOG" '"decision":"deny"'
  assert_file_contains "explicit log records detail" "$EXPLICIT_LOG" '"detail":"explicit-path"'
else
  assert_fail "explicit log path creates audit file" "missing $EXPLICIT_LOG"
fi

echo "--- Test 3: state flag enables default audit log ---"
unset SILVER_BULLET_HOOK_AUDIT_LOG
rm -f "$DEFAULT_LOG"
touch "${SB_RUNTIME_STATE_DIR}/hook-audit-enabled"
if declare -f sb_hook_audit_record >/dev/null 2>&1; then
  sb_hook_audit_record "completion-audit" "PreToolUse" "deny" "default-flag"
fi
if [[ -f "$DEFAULT_LOG" ]]; then
  assert_pass "flag file creates default audit log"
  assert_file_contains "default audit log records hook name" "$DEFAULT_LOG" '"hook_name":"completion-audit"'
  assert_file_contains "default audit log records detail" "$DEFAULT_LOG" '"detail":"default-flag"'
else
  assert_fail "flag file creates default audit log" "missing $DEFAULT_LOG"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
