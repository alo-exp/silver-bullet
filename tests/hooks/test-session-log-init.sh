#!/usr/bin/env bash
# Tests for hooks/session-log-init.sh
# Tests PostToolUse session log creation, dedup guard, JSON encoding, and path safety.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-log-init.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

TMPDIR_TEST=""
SESSION_LOG_DIR=""

cleanup_all() {
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  SESSION_LOG_DIR="${TMPDIR_TEST}/sessions"
  mkdir -p "$SESSION_LOG_DIR"
  # Write a minimal .silver-bullet.json so hook finds project root
  printf '{"project":{"src_pattern":"/src/"}}\n' > "${TMPDIR_TEST}/.silver-bullet.json"
  # Write mode file (hook reads this, not the command string)
  printf 'interactive' > "${SB_TEST_DIR}/mode"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  TMPDIR_TEST=""
  SESSION_LOG_DIR=""
}

run_hook() {
  local json="$1"
  (
    export PROJECT_ROOT_OVERRIDE="$TMPDIR_TEST"
    export SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR"
    export SENTINEL_SLEEP_OVERRIDE=1
    printf '%s' "$json" | bash "$HOOK" 2>/dev/null
  )
}

MODE_CMD_JSON='{"tool_name":"Bash","tool_input":{"command":"echo x > ~/.claude/.silver-bullet/mode"}}'
UNRELATED_JSON='{"tool_name":"Bash","tool_input":{"command":"git status"}}'

assert_valid_json() {
  local label="$1"
  local output="$2"
  if printf '%s' "$output" | jq . >/dev/null 2>&1; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — not valid JSON: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_empty() {
  local label="$1"
  local output="$2"
  if [[ -z "$output" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected empty output, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists_in() {
  local label="$1"
  local dir="$2"
  local pattern="$3"
  local found
  found=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1 || true)
  if [[ -n "$found" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — no file matching '$pattern' in $dir"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_file_in() {
  local label="$1"
  local dir="$2"
  local pattern="$3"
  local found
  found=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1 || true)
  if [[ -z "$found" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — unexpected file '$found' found"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== session-log-init.sh tests ==="

# Test 1: Unrelated command — exits silently (no session log, no output)
echo "--- Test 1: Unrelated command ignored ---"
setup
out=$(run_hook "$UNRELATED_JSON")
assert_empty "unrelated command produces no output" "$out"
assert_no_file_in "unrelated command creates no session log" "$SESSION_LOG_DIR" "*.md"
teardown

# Test 2: Mode command with existing session log for today — outputs valid JSON with "already exists"
echo "--- Test 2: Mode command with existing session log ---"
setup
today=$(date '+%Y-%m-%d')
existing_log="${SESSION_LOG_DIR}/${today}-00-00-00.md"
printf '# Session Log\n\n**Date:** %s\n**Mode:** interactive\n\n## Pre-answers\n\n(n/a)\n\n## Task\n\n(n/a)\n\n## Approach\n\n(n/a)\n\n## Files changed\n\n(n/a)\n\n## Skills invoked\n\n(n/a)\n\n## Skills flagged at discovery\n\n(n/a)\n\n## Skill gap check (post-plan)\n\n(n/a)\n\n## Agent Teams dispatched\n\n(n/a)\n\n## Autonomous decisions\n\n(none)\n\n## Needs human review\n\n(none)\n\n## Outcome\n\n(n/a)\n\n## Knowledge & Lessons additions\n\n(n/a)\n' "$today" > "$existing_log"
out=$(run_hook "$MODE_CMD_JSON")
assert_valid_json "existing log: output is valid JSON" "$out"
assert_contains "existing log: message mentions 'already exists'" "$out" "already exists"
teardown

# Test 3: Mode command with no existing log — creates new log file, outputs JSON with "Session log created"
echo "--- Test 3: Mode command creates new session log ---"
setup
out=$(run_hook "$MODE_CMD_JSON")
assert_valid_json "new log: output is valid JSON" "$out"
assert_contains "new log: message mentions 'Session log created'" "$out" "Session log created"
assert_file_exists_in "new log: session log file created" "$SESSION_LOG_DIR" "*.md"
teardown

# Test 4: JSON output is valid (pipe through jq . and expect exit 0) — tests jq-Rs encoding fix
echo "--- Test 4: JSON output validity (jq-Rs encoding) ---"
setup
out=$(run_hook "$MODE_CMD_JSON")
if [[ -n "$out" ]]; then
  if printf '%s' "$out" | jq . >/dev/null 2>&1; then
    echo "  ✅ output passes jq . validation"
    PASS=$((PASS + 1))
  else
    echo "  ❌ output fails jq . validation: $out"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ❌ no output to validate"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 5: Existing log filename containing date characters — output is still valid JSON
echo "--- Test 5: Existing log with date-formatted filename — still valid JSON ---"
setup
today=$(date '+%Y-%m-%d')
# The hook uses basename of the existing log file in its message; test that result is valid JSON
existing_log="${SESSION_LOG_DIR}/${today}-10-30-00.md"
printf '# Session Log\n\n**Date:** %s\n**Mode:** interactive\n\n## Pre-answers\n\n(n/a)\n\n## Task\n\n(n/a)\n\n## Approach\n\n(n/a)\n\n## Files changed\n\n(n/a)\n\n## Skills invoked\n\n(n/a)\n\n## Skills flagged at discovery\n\n(n/a)\n\n## Skill gap check (post-plan)\n\n(n/a)\n\n## Agent Teams dispatched\n\n(n/a)\n\n## Autonomous decisions\n\n(none)\n\n## Needs human review\n\n(none)\n\n## Outcome\n\n(n/a)\n\n## Knowledge & Lessons additions\n\n(n/a)\n' "$today" > "$existing_log"
out=$(run_hook "$MODE_CMD_JSON")
assert_valid_json "date-formatted filename: output is valid JSON" "$out"
# The message should reference the filename or today's date
if printf '%s' "$out" | jq -r '.hookSpecificOutput.message // ""' | grep -q "${today}"; then
  echo "  ✅ message contains today's date (filename reference)"
  PASS=$((PASS + 1))
else
  echo "  ❌ message does not contain today's date: $out"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Legacy coverage (same tests as before, counter-based) ─────────────────────

# Test 6: dedup — second trigger same day must NOT create a second file
echo "--- Test 6: Dedup guard prevents second session log ---"
setup
run_hook "$MODE_CMD_JSON" > /dev/null 2>&1 || true
run_hook "$MODE_CMD_JSON" > /dev/null 2>&1 || true
file_count=$(find "$SESSION_LOG_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$file_count" -eq 1 ]]; then
  echo "  ✅ dedup guard prevents second session log"
  PASS=$((PASS + 1))
else
  echo "  ❌ expected 1 session log, found: $file_count"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 7: New skeleton contains required sections
echo "--- Test 7: Session log skeleton contains required sections ---"
setup
run_hook "$MODE_CMD_JSON" > /dev/null 2>&1 || true
log_file=$(find "$SESSION_LOG_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | head -1 || true)
if [[ -n "$log_file" ]]; then
  if grep -q "## Pre-answers" "$log_file" && \
     grep -q "## Skills flagged at discovery" "$log_file" && \
     grep -q "## Skill gap check" "$log_file"; then
    echo "  ✅ skeleton contains all required new sections"
    PASS=$((PASS + 1))
  else
    echo "  ❌ skeleton missing one or more required sections"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ❌ no log file created to inspect"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 8: Autonomous mode creates sentinel PID file
echo "--- Test 8: Autonomous mode launches sentinel ---"
setup
printf 'autonomous' > "${SB_TEST_DIR}/mode"
rm -f "${SB_TEST_DIR}/sentinel-pid"
AUT_JSON='{"tool_name":"Bash","tool_input":{"command":"echo autonomous > ~/.claude/.silver-bullet/mode"}}'
(
  export PROJECT_ROOT_OVERRIDE="$TMPDIR_TEST"
  export SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR"
  export SENTINEL_SLEEP_OVERRIDE=3600
  printf '%s' "$AUT_JSON" | bash "$HOOK" 2>/dev/null
) > /dev/null || true
if [[ -f "${SB_TEST_DIR}/sentinel-pid" ]]; then
  echo "  ✅ autonomous mode creates sentinel PID file"
  PASS=$((PASS + 1))
  _sentinel_contents=$(cat "${SB_TEST_DIR}/sentinel-pid" 2>/dev/null || true)
  _sentinel_pid="${_sentinel_contents%%:*}"
  [[ -n "$_sentinel_pid" ]] && kill "$_sentinel_pid" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/sentinel-pid" "${SB_TEST_DIR}/timeout" \
        "${SB_TEST_DIR}/session-start-time" "${SB_TEST_DIR}/timeout-warn-count"
else
  echo "  ❌ expected sentinel PID file, not found"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 9: Interactive mode does NOT create sentinel PID file
echo "--- Test 9: Interactive mode does not launch sentinel ---"
setup
printf 'interactive' > "${SB_TEST_DIR}/mode"
rm -f "${SB_TEST_DIR}/sentinel-pid"
run_hook "$MODE_CMD_JSON" > /dev/null 2>&1 || true
if [[ ! -f "${SB_TEST_DIR}/sentinel-pid" ]]; then
  echo "  ✅ interactive mode does not create sentinel PID file"
  PASS=$((PASS + 1))
else
  echo "  ❌ interactive mode should not create sentinel PID file"
  FAIL=$((FAIL + 1))
  _sentinel_contents=$(cat "${SB_TEST_DIR}/sentinel-pid" 2>/dev/null || true)
  _sentinel_pid="${_sentinel_contents%%:*}"
  [[ -n "$_sentinel_pid" ]] && kill "$_sentinel_pid" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/sentinel-pid"
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
