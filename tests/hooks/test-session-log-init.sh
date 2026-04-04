#!/usr/bin/env bash
set -euo pipefail
# Test driver for hooks/session-log-init.sh
# Uses PROJECT_ROOT_OVERRIDE to bypass the .silver-bullet.json walk-up.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/session-log-init.sh"
SESSION_LOG_DIR="/tmp/sb-test-sessions-$$"
mkdir -p "$SESSION_LOG_DIR"

run_hook() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR" \
      bash "$HOOK"
}

# Test 1: mode file write — should create session log and emit path message
out=$(run_hook "echo autonomous > ${HOME}/.claude/.silver-bullet/mode")
if printf '%s' "$out" | grep -q "session"; then
  printf 'PASS: mode write triggers session log creation\n'
else
  printf 'FAIL: expected session in output, got: %s\n' "$out"
  exit 1
fi

# Test 2: unrelated command — must be silent
out=$(run_hook "git status")
if [[ -z "$out" ]]; then
  printf 'PASS: unrelated command silently ignored\n'
else
  printf 'FAIL: expected silence, got: %s\n' "$out"
  exit 1
fi

# Test 3: dedup — second trigger same day must NOT create a second file
run_hook "echo interactive > ${HOME}/.claude/.silver-bullet/mode" > /dev/null 2>&1 || true
file_count=$(ls "$SESSION_LOG_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$file_count" -eq 1 ]]; then
  printf 'PASS: dedup guard prevents second session log\n'
else
  printf 'FAIL: expected 1 session log, found: %s\n' "$file_count"
  exit 1
fi

rm -rf "$SESSION_LOG_DIR"

# Test 4: autonomous mode — sentinel PID file created
SESSION_LOG_DIR4="/tmp/sb-test-sessions-t4-$$"
mkdir -p "$SESSION_LOG_DIR4"
run_hook4() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR4")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR4" \
      SENTINEL_SLEEP_OVERRIDE="3600" \
      bash "$HOOK"
}
rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid
run_hook4 "echo autonomous > ${HOME}/.claude/.silver-bullet/mode" > /dev/null
if [[ -f ${HOME}/.claude/.silver-bullet/sentinel-pid ]]; then
  printf 'PASS: autonomous mode creates sentinel PID file\n'
  # Clean up sentinel
  kill "$(cat ${HOME}/.claude/.silver-bullet/sentinel-pid)" 2>/dev/null || true
  rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid ${HOME}/.claude/.silver-bullet/timeout \
        ${HOME}/.claude/.silver-bullet/session-start-time ${HOME}/.claude/.silver-bullet/timeout-warn-count
else
  printf 'FAIL: expected sentinel PID file, not found\n'
  rm -rf "$SESSION_LOG_DIR4"
  exit 1
fi
rm -rf "$SESSION_LOG_DIR4"

# Test 5: interactive mode — sentinel PID file NOT created
SESSION_LOG_DIR5="/tmp/sb-test-sessions-t5-$$"
mkdir -p "$SESSION_LOG_DIR5"
run_hook5() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR5")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR5" \
      bash "$HOOK"
}
rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid
run_hook5 "echo interactive > ${HOME}/.claude/.silver-bullet/mode" > /dev/null
if [[ ! -f ${HOME}/.claude/.silver-bullet/sentinel-pid ]]; then
  printf 'PASS: interactive mode does not create sentinel PID file\n'
else
  printf 'FAIL: interactive mode should not create sentinel PID file\n'
  kill "$(cat ${HOME}/.claude/.silver-bullet/sentinel-pid)" 2>/dev/null || true
  rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid
  rm -rf "$SESSION_LOG_DIR5"
  exit 1
fi
rm -rf "$SESSION_LOG_DIR5"

# Test 6: re-init (dedup path) with autonomous mode re-launches sentinel
SESSION_LOG_DIR6="/tmp/sb-test-sessions-t6-$$"
mkdir -p "$SESSION_LOG_DIR6"
run_hook6() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR6")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR6" \
      SENTINEL_SLEEP_OVERRIDE="3600" \
      bash "$HOOK"
}
rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid ${HOME}/.claude/.silver-bullet/timeout \
      ${HOME}/.claude/.silver-bullet/session-start-time ${HOME}/.claude/.silver-bullet/timeout-warn-count
# First trigger: creates log + sentinel
run_hook6 "echo autonomous > ${HOME}/.claude/.silver-bullet/mode" > /dev/null
pid1=$(cat ${HOME}/.claude/.silver-bullet/sentinel-pid 2>/dev/null || echo "")
# Second trigger: dedup path should kill old sentinel and re-launch
run_hook6 "echo autonomous > ${HOME}/.claude/.silver-bullet/mode" > /dev/null
pid2=$(cat ${HOME}/.claude/.silver-bullet/sentinel-pid 2>/dev/null || echo "")
if [[ -n "$pid2" ]] && [[ "$pid2" != "$pid1" ]]; then
  printf 'PASS: dedup path re-launches sentinel with new PID\n'
else
  printf 'FAIL: expected new sentinel PID after re-init, got pid1=%s pid2=%s\n' "$pid1" "$pid2"
  rm -rf "$SESSION_LOG_DIR6"
  exit 1
fi
kill "$pid2" 2>/dev/null || true
rm -f ${HOME}/.claude/.silver-bullet/sentinel-pid ${HOME}/.claude/.silver-bullet/timeout \
      ${HOME}/.claude/.silver-bullet/session-start-time ${HOME}/.claude/.silver-bullet/timeout-warn-count
rm -rf "$SESSION_LOG_DIR6"

# Test 7: new skeleton has ## Pre-answers section
SESSION_LOG_DIR7="/tmp/sb-test-sessions-t7-$$"
mkdir -p "$SESSION_LOG_DIR7"
run_hook7() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | PROJECT_ROOT_OVERRIDE="$(dirname "$SESSION_LOG_DIR7")" \
      SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR7" \
      bash "$HOOK"
}
run_hook7 "echo interactive > ${HOME}/.claude/.silver-bullet/mode" > /dev/null
log_file=$(ls "$SESSION_LOG_DIR7"/*.md 2>/dev/null | head -1)
if grep -q "## Pre-answers" "$log_file" && \
   grep -q "## Skills flagged at discovery" "$log_file" && \
   grep -q "## Skill gap check" "$log_file"; then
  printf 'PASS: skeleton contains all three new sections\n'
else
  printf 'FAIL: skeleton missing one or more new sections\n'
  rm -rf "$SESSION_LOG_DIR7"
  exit 1
fi
rm -rf "$SESSION_LOG_DIR7"

printf 'All tests passed.\n'
