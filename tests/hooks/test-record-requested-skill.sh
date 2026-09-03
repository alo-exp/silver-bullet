#!/usr/bin/env bash
# Tests for hooks/record-requested-skill.sh
# Verifies UserPromptSubmit route markers are recorded before the skill chain runs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/record-requested-skill.sh"
# shellcheck source=helpers/common.sh
source "$(dirname "$0")/helpers/common.sh"

hook_test_init_counters
PASS="${HOOK_TEST_PASS:-0}"
FAIL="${HOOK_TEST_FAIL:-0}"
TEST_RUN_ID="$$"
TMPLOG_PATH_FILE="${SB_RUNTIME_STATE_DIR}/session-log-path-${TEST_RUN_ID}"
SESSION_LOG_FILE=""

cleanup_all() {
  hook_test_teardown
  rm -f "${SB_RUNTIME_STATE_DIR}/requested-skill-${TEST_RUN_ID}" 2>/dev/null || true
  rm -f "${SB_RUNTIME_STATE_DIR}/requested-skill-${TEST_RUN_ID}.requested" 2>/dev/null || true
  rm -f "$TMPLOG_PATH_FILE" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  hook_test_setup "$TEST_RUN_ID"
  TMPSTATE="${SB_RUNTIME_STATE_DIR}/requested-skill-${TEST_RUN_ID}"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  SESSION_LOG_FILE="${HOOK_TEST_TMPDIR}/docs/sessions/requested-skill-${TEST_RUN_ID}.md"
  rm -f "$TMPSTATE" "${TMPSTATE}.requested"
  cat > "$HOOK_TEST_CFG" <<EOF
{
  "project": { "name": "test" },
  "state": { "state_file": "${TMPSTATE}" }
  }
EOF
  mkdir -p "$(dirname "$SESSION_LOG_FILE")"
  cat > "$SESSION_LOG_FILE" <<'EOF'
# Session Log — test

## Active Intent Ledger

(filled during the session as active requests are intercepted)

## Agent Teams dispatched

(none)
EOF
  printf '%s\n' "$SESSION_LOG_FILE" > "$TMPLOG_PATH_FILE"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_SESSION_LOG_PATH_FILE="$TMPLOG_PATH_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE" "${TMPSTATE}.requested"
  rm -f "$TMPLOG_PATH_FILE"
  SESSION_LOG_FILE=""
}

run_hook() {
  local prompt="$1"
  local input
  input=$(jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

assert_in_state() {
  local label="$1"
  local skill="$2"
  if grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' not found in state: $(cat "$TMPSTATE" 2>/dev/null || echo '(empty)')"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

assert_in_requested() {
  local label="$1"
  local skill="$2"
  if grep -qx "$skill" "${TMPSTATE}.requested" 2>/dev/null; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' not found in requested-state: $(cat "${TMPSTATE}.requested" 2>/dev/null || echo '(empty)')"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

assert_not_in_state() {
  local label="$1"
  local skill="$2"
  if ! grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' unexpectedly found in state"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

assert_not_in_requested() {
  local label="$1"
  local skill="$2"
  if ! grep -qx "$skill" "${TMPSTATE}.requested" 2>/dev/null; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' unexpectedly found in requested-state"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

assert_in_session_log() {
  local label="$1"
  local needle="$2"
  if grep -qF "$needle" "$SESSION_LOG_FILE" 2>/dev/null; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$needle' not found in session log: $(cat "$SESSION_LOG_FILE" 2>/dev/null || echo '(empty)')"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

assert_noop_json() {
  local label="$1"
  local output="$2"
  if printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and ((.hookSpecificOutput | keys) == ["hookEventName"])' >/dev/null 2>&1; then
    echo "  ✅ $label"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected no-op hook JSON, got: $output"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
    FAIL=$((FAIL + 1))
  fi
}

echo "=== record-requested-skill.sh tests ==="

setup
out="$(run_hook 'Use the [$silver](path/to/skill) skill as the only entrypoint. Route this request to `silver:scan` and then invoke `silver:plan`.')"
assert_noop_json "requested-skill hook returns valid no-op JSON after recording routes" "$out"
assert_in_requested "silver:scan request recorded as requested, not completed" "silver-scan"
assert_in_requested "silver:plan request recorded as requested, not completed" "silver-plan"
assert_not_in_state "silver:scan is not recorded as completed" "silver-scan"
assert_in_session_log "session ledger records the request block" "## Active Intent Ledger"
assert_in_session_log "session ledger records silver-scan as active" "  - [ ] silver-scan"
assert_in_session_log "session ledger records silver-plan as active" "  - [ ] silver-plan"
teardown

setup
rm -f "$TMPDIR_TEST/.silver-bullet.json"
rm -f "$TMPDIR_TEST/silver-bullet.md"
out="$(run_hook 'Use the [$silver](path/to/skill) skill as the only entrypoint. Route this request to `silver:init` and then stop.')"
assert_noop_json "requested-skill hook returns valid no-op JSON before scaffold exists" "$out"
assert_in_requested "silver:init request recorded before scaffold exists" "silver-init"
assert_not_in_state "silver:init is not recorded as completed before scaffold exists" "silver-init"
teardown

setup
out="$(run_hook 'hello world, no routed skill markers here')"
assert_noop_json "requested-skill hook returns valid no-op JSON for unrelated prompts" "$out"
assert_not_in_requested "non-SB prompt does not record requested routes" "silver-scan"
assert_not_in_state "non-SB prompt does not record completed routes" "silver-scan"
teardown

setup
out="$(run_hook 'Add a due date field to todos. Keep it simple: accept dueDate in the API payload and return it in todo responses.')"
assert_noop_json "bare feature prompt returns valid no-op JSON after recording router request" "$out"
assert_in_requested "bare feature prompt records Silver router as requested" "silver"
assert_not_in_state "bare feature prompt does not record Silver router as completed" "silver"
assert_in_session_log "session ledger records bare prompt routed through silver" "  - [ ] silver"
teardown

setup
out="$(run_hook 'What does Silver Bullet aim to achieve?')"
assert_noop_json "explanatory question returns valid no-op JSON" "$out"
assert_not_in_requested "explanatory question does not trigger Silver router" "silver"
assert_not_in_state "explanatory question does not complete Silver router" "silver"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
