#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/timeout-check.sh"

# Ensure state directory exists
mkdir -p "${HOME}/.claude/.silver-bullet"

# Helpers
write_mode() { echo "$1" > "${HOME}/.claude/.silver-bullet/mode"; }
write_start_time() { date +%s > "${HOME}/.claude/.silver-bullet/session-start-time"; }
cleanup_tmp() {
  rm -f "${HOME}/.claude/.silver-bullet/mode" "${HOME}/.claude/.silver-bullet/session-start-time" \
        "${HOME}/.claude/.silver-bullet/timeout" "${HOME}/.claude/.silver-bullet/timeout-warn-count" \
        "/tmp/.sb-test-timeout-flag-$$"
}

run_hook() {
  local flag_override="${1:-}"
  printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
    | TIMEOUT_FLAG_OVERRIDE="$flag_override" bash "$HOOK"
}

cleanup_tmp

# Test 1: autonomous + current flag → warning on first call (count=1, 1 mod 5 == 1)
write_mode "autonomous"
write_start_time
sleep 1  # ensure flag mtime >= session-start-time
touch /tmp/.sb-test-timeout-flag-$$
rm -f "${HOME}/.claude/.silver-bullet/timeout-warn-count"
out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
if printf '%s' "$out" | grep -q "Autonomous session"; then
  printf 'PASS: current flag + autonomous → warning on call 1\n'
else
  printf 'FAIL: expected warning, got: %s\n' "$out"
  cleanup_tmp; exit 1
fi

# Test 2: second call → silent (count=2, 2 mod 5 != 1)
out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
if [[ -z "$out" ]]; then
  printf 'PASS: second call → silent (rate-limit)\n'
else
  printf 'FAIL: expected silence on call 2, got: %s\n' "$out"
  cleanup_tmp; exit 1
fi

# Test 3: no flag file → silent
cleanup_tmp
write_mode "autonomous"
write_start_time
out=$(run_hook "")
if [[ -z "$out" ]]; then
  printf 'PASS: absent flag → silent\n'
else
  printf 'FAIL: expected silence with no flag, got: %s\n' "$out"
  exit 1
fi

# Test 4: interactive mode → silent even with flag
cleanup_tmp
write_mode "interactive"
write_start_time
sleep 1
touch /tmp/.sb-test-timeout-flag-$$
out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
if [[ -z "$out" ]]; then
  printf 'PASS: interactive mode → silent\n'
else
  printf 'FAIL: expected silence in interactive, got: %s\n' "$out"
  cleanup_tmp; exit 1
fi

# Test 5: stale flag (mtime before session-start-time) → silent (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
  cleanup_tmp
  write_mode "autonomous"
  # Create flag file first, then write session-start-time after
  touch /tmp/.sb-test-timeout-flag-$$
  sleep 1
  write_start_time  # session started AFTER flag was written → flag is stale
  rm -f "${HOME}/.claude/.silver-bullet/timeout-warn-count"
  out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
  if [[ -z "$out" ]]; then
    printf 'PASS: stale flag → silent\n'
  else
    printf 'FAIL: expected silence for stale flag, got: %s\n' "$out"
    cleanup_tmp; exit 1
  fi
else
  printf 'SKIP: stale-flag test is macOS-only\n'
fi

# Test 6: stale warn-count file → count resets to 0 → warning fires on first call (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
  cleanup_tmp
  write_mode "autonomous"
  # Session starts first, then flag is created → flag mtime > session_start (current)
  write_start_time
  sleep 1
  touch /tmp/.sb-test-timeout-flag-$$
  rm -f "${HOME}/.claude/.silver-bullet/timeout-warn-count"
  # Pre-populate warn-count=4 with mtime BEFORE session-start-time (stale)
  echo "4" > "${HOME}/.claude/.silver-bullet/timeout-warn-count"
  touch -t 202001010000 "${HOME}/.claude/.silver-bullet/timeout-warn-count"
  out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
  if printf '%s' "$out" | grep -q "Autonomous session"; then
    printf 'PASS: stale warn-count resets to 0 → warning fires on first call\n'
  else
    printf 'FAIL: expected warning after stale warn-count reset, got: %s\n' "$out"
    cleanup_tmp; exit 1
  fi
else
  printf 'SKIP: stale warn-count test is macOS-only\n'
fi

cleanup_tmp
printf 'All tests passed.\n'
