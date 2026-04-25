#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/timeout-check.sh"
PASS=0
FAIL=0

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
  PASS=$((PASS + 1))
  printf 'PASS: current flag + autonomous → warning on call 1\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: expected warning, got: %s\n' "$out"
fi

# Test 2: second call → silent (count=2, 2 mod 5 != 1)
out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
if [[ -z "$out" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: second call → silent (rate-limit)\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: expected silence on call 2, got: %s\n' "$out"
fi

# Test 3: no flag file → silent
cleanup_tmp
write_mode "autonomous"
write_start_time
out=$(run_hook "")
if [[ -z "$out" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: absent flag → silent\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: expected silence with no flag, got: %s\n' "$out"
fi

# Test 4: interactive mode → silent even with flag
cleanup_tmp
write_mode "interactive"
write_start_time
sleep 1
touch /tmp/.sb-test-timeout-flag-$$
out=$(run_hook "/tmp/.sb-test-timeout-flag-$$")
if [[ -z "$out" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: interactive mode → silent\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: expected silence in interactive, got: %s\n' "$out"
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
    PASS=$((PASS + 1))
    printf 'PASS: stale flag → silent\n'
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: expected silence for stale flag, got: %s\n' "$out"
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
    PASS=$((PASS + 1))
    printf 'PASS: stale warn-count resets to 0 → warning fires on first call\n'
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: expected warning after stale warn-count reset, got: %s\n' "$out"
  fi
else
  printf 'SKIP: stale warn-count test is macOS-only\n'
fi

# ── Tier 2: Call-count based anti-stall tests ────────────────────────────────
SB_DIR="${HOME}/.claude/.silver-bullet"
T2_STATE_FILE="/tmp/.sb-t2-state-test-$$"

cleanup_tier2() {
  rm -f "${SB_DIR}/call-count" "${SB_DIR}/last-progress-call" \
        "${SB_DIR}/last-state-mtime" "${SB_DIR}/mode" \
        "${SB_DIR}/session-start-time" "$T2_STATE_FILE"
}

run_hook_tier2() {
  printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
    | SILVER_BULLET_STATE_FILE="$T2_STATE_FILE" bash "$HOOK"
}

# Test T2-1: 30-call warning fires ("Check-in" message)
cleanup_tmp; cleanup_tier2
mkdir -p "$SB_DIR"
echo "autonomous"  > "${SB_DIR}/mode"
date +%s           > "${SB_DIR}/session-start-time"
# call_count = 29 stored; hook increments to 30; last_progress_count=0; calls_since_progress=30
echo "29" > "${SB_DIR}/call-count"
echo "0"  > "${SB_DIR}/last-progress-call"
echo "0"  > "${SB_DIR}/last-state-mtime"
# Don't create a state file — current_state_mtime will be 0 = last_state_mtime, no reset
out=$(run_hook_tier2)
if printf '%s' "$out" | grep -q "Check-in"; then
  PASS=$((PASS + 1))
  printf 'PASS: T2-1: 30 calls since progress → Check-in warning fires\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: T2-1: expected "Check-in", got: %s\n' "$out"
fi

# Test T2-2: 60-call warning fires ("STALL WARNING" message)
cleanup_tier2
mkdir -p "$SB_DIR"
echo "autonomous"  > "${SB_DIR}/mode"
date +%s           > "${SB_DIR}/session-start-time"
echo "59" > "${SB_DIR}/call-count"
echo "0"  > "${SB_DIR}/last-progress-call"
echo "0"  > "${SB_DIR}/last-state-mtime"
out=$(run_hook_tier2)
if printf '%s' "$out" | grep -q "STALL WARNING"; then
  PASS=$((PASS + 1))
  printf 'PASS: T2-2: 60 calls since progress → STALL WARNING fires\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: T2-2: expected "STALL WARNING", got: %s\n' "$out"
fi

# Test T2-3: 100-call warning fires ("STALL DETECTED" message)
cleanup_tier2
mkdir -p "$SB_DIR"
echo "autonomous"  > "${SB_DIR}/mode"
date +%s           > "${SB_DIR}/session-start-time"
echo "99" > "${SB_DIR}/call-count"
echo "0"  > "${SB_DIR}/last-progress-call"
echo "0"  > "${SB_DIR}/last-state-mtime"
out=$(run_hook_tier2)
if printf '%s' "$out" | grep -q "STALL DETECTED"; then
  PASS=$((PASS + 1))
  printf 'PASS: T2-3: 100 calls since progress → STALL DETECTED fires\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: T2-3: expected "STALL DETECTED", got: %s\n' "$out"
fi

# Test T2-4: 31 calls → silent (not on a threshold boundary)
cleanup_tier2
mkdir -p "$SB_DIR"
echo "autonomous"  > "${SB_DIR}/mode"
date +%s           > "${SB_DIR}/session-start-time"
# call_count stored=30; hook increments to 31; last_progress=0; calls_since_progress=31
# 31 >= 30 but 31 mod 10 = 1 ≠ 0 → no message
echo "30" > "${SB_DIR}/call-count"
echo "0"  > "${SB_DIR}/last-progress-call"
echo "0"  > "${SB_DIR}/last-state-mtime"
out=$(run_hook_tier2)
if [[ -z "$out" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: T2-4: 31 calls (non-threshold) → silent\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: T2-4: expected silence at 31 calls, got: %s\n' "$out"
fi

cleanup_tier2
cleanup_tmp

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
