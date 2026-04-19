#!/usr/bin/env bash
set -euo pipefail

# Security: restrict file creation permissions (user-only)
umask 0077

# Source symlink-write guard (SEC-02)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_guard_nofollow() { [[ -L "$1" ]] && { printf 'ERROR: refusing to write through symlink: %s\n' "$1" >&2; exit 1; }; return 0; }
  sb_safe_write()    { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi

# Fail-visible: on unexpected error, exit 0 (silent no-op) rather than crash
trap 'exit 0' ERR

# PostToolUse hook (matcher: .*, async: false)
# Two-tier anti-stall protection in autonomous mode:
#   Tier 1 (wall-clock): Fires after 10-minute sentinel sets the timeout flag
#   Tier 2 (call-count): Fires at 30/60/100 tool calls with no skill recorded —
#                        catches tight loops that 10-minute wall time misses
# Supports macOS (stat -f %m) and Linux (stat --format=%Y).

# Consume stdin (required to avoid broken pipe)
cat > /dev/null

# User-scoped state directory
SB_DIR="${HOME}/.claude/.silver-bullet"

# Mode gate: only act in autonomous mode
mode_file="$SB_DIR/mode"
if [[ ! -f "$mode_file" || -L "$mode_file" ]]; then
  exit 0
fi
mode_file_content=$(cat "$mode_file" 2>/dev/null || echo "interactive")
[[ "$mode_file_content" != "autonomous" ]] && exit 0

# Platform-aware stat helper: returns file mtime as epoch seconds
# Validates output is a pure integer (guards against GNU stat multi-line output)
_mtime() {
  local _v
  if [[ "$(uname)" == "Darwin" ]]; then
    _v=$(stat -f %m "$1" 2>/dev/null || true)
  else
    _v=$(stat --format=%Y "$1" 2>/dev/null || true)
  fi
  [[ "$_v" =~ ^[0-9]+$ ]] && printf '%s' "$_v" || printf '0'
}

# ── Session start anchor ──────────────────────────────────────────────────────
session_start=$(cat "$SB_DIR/session-start-time" 2>/dev/null || echo "")
[[ -z "$session_start" ]] && exit 0
[[ "$session_start" =~ ^[0-9]+$ ]] || exit 0

# ── Tier 1: Wall-clock timeout check ─────────────────────────────────────────
flag_file="${TIMEOUT_FLAG_OVERRIDE:-$SB_DIR/timeout}"
tier1_triggered=false
if [[ -f "$flag_file" ]]; then
  flag_mtime=$(_mtime "$flag_file") || flag_mtime=0
  if [[ "$flag_mtime" -ge "$session_start" ]]; then
    tier1_triggered=true
  fi
fi

# ── Tier 2: Call-count based anti-stall ──────────────────────────────────────
# Track total tool calls since session start
call_count_file="$SB_DIR/call-count"
call_count=0
if [[ -f "$call_count_file" ]]; then
  cc_mtime=$(_mtime "$call_count_file") || cc_mtime=0
  if [[ "$cc_mtime" -ge "$session_start" ]]; then
    call_count=$(cat "$call_count_file" 2>/dev/null || echo "0")
  fi
fi
call_count=$((call_count + 1))
sb_guard_nofollow "$call_count_file"
echo "$call_count" > "$call_count_file"

# Track tool calls since last skill was recorded (progress marker)
# When the state file changes (new skill recorded), reset the progress baseline
state_file="$SB_DIR/state"
last_progress_file="$SB_DIR/last-progress-call"
last_progress_count=0
if [[ -f "$last_progress_file" ]]; then
  lp_mtime=$(_mtime "$last_progress_file") || lp_mtime=0
  if [[ "$lp_mtime" -ge "$session_start" ]]; then
    last_progress_count=$(cat "$last_progress_file" 2>/dev/null || echo "0")
  fi
fi

# Check if state file changed since last recorded progress
last_state_mtime_file="$SB_DIR/last-state-mtime"
last_state_mtime=0
if [[ -f "$last_state_mtime_file" ]]; then
  lsm_mtime=$(_mtime "$last_state_mtime_file") || lsm_mtime=0
  if [[ "$lsm_mtime" -ge "$session_start" ]]; then
    last_state_mtime=$(cat "$last_state_mtime_file" 2>/dev/null || echo "0")
  fi
fi

current_state_mtime=0
if [[ -f "$state_file" ]]; then
  current_state_mtime=$(_mtime "$state_file") || current_state_mtime=0
fi

if [[ "$current_state_mtime" -gt "$last_state_mtime" ]] && [[ "$current_state_mtime" -ge "$session_start" ]]; then
  # State file changed during this session — skill was recorded — reset progress baseline
  sb_guard_nofollow "$last_state_mtime_file"
  echo "$current_state_mtime" > "$last_state_mtime_file"
  sb_guard_nofollow "$last_progress_file"
  echo "$call_count" > "$last_progress_file"
  last_progress_count=$call_count
fi

calls_since_progress=$((call_count - last_progress_count))

# ── Rate-limiting for tier 1 ──────────────────────────────────────────────────
if [[ "$tier1_triggered" == true ]]; then
  count_file="$SB_DIR/timeout-warn-count"
  count=0
  if [[ -f "$count_file" ]]; then
    count_mtime=$(_mtime "$count_file") || count_mtime=0
    if [[ "$count_mtime" -ge "$session_start" ]]; then
      count=$(cat "$count_file" 2>/dev/null || echo "0")
    fi
  fi
  count=$((count + 1))
  sb_guard_nofollow "$count_file"
  echo "$count" > "$count_file"
  # Tier 1: Emit on 1st, 6th, 11th... call (count mod 5 == 1)
  if [[ $((count % 5)) -eq 1 ]]; then
    printf '{"hookSpecificOutput":{"message":"⚠️ Autonomous session running 10+ min. Check for stalls or log a blocker under Needs human review."}}'
    exit 0
  fi
fi

# ── Tier 2: Escalating call-count warnings ────────────────────────────────────
# Only emit at specific thresholds (not every call) to avoid spamming
# Thresholds: 30, 60, 100 calls since last skill recorded
if [[ "$calls_since_progress" -ge 100 ]] && [[ $((calls_since_progress % 25)) -eq 0 ]]; then
  printf '{"hookSpecificOutput":{"message":"🛑 STALL DETECTED — %d tool calls with no workflow progress (no new skill recorded).\n\nThis indicates a loop or planning failure. Take one of these actions:\n  1. Identify the blocking issue and log it in session log under ## Needs human review\n  2. Invoke the appropriate skill to advance the workflow\n  3. Stop and reassess — do not continue looping\n\nStall conditions (§4): repeated tool calls / no state change / per-step budget exceeded."}}' "$calls_since_progress"
  exit 0
elif [[ "$calls_since_progress" -ge 60 ]] && [[ $((calls_since_progress % 15)) -eq 0 ]]; then
  printf '{"hookSpecificOutput":{"message":"⚠️ STALL WARNING — %d tool calls since last skill was recorded. Are you stuck?\n\nIf you are not actively working through a skill, stop and:\n  • Identify which workflow skill is next\n  • Invoke it to advance the workflow\n  • Log any blockers under ## Needs human review"}}' "$calls_since_progress"
  exit 0
elif [[ "$calls_since_progress" -ge 30 ]] && [[ $((calls_since_progress % 10)) -eq 0 ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ Check-in: %d tool calls since last skill recorded. If you are looping or stuck, invoke the next workflow skill or log a blocker."}}' "$calls_since_progress"
  exit 0
fi

exit 0
