#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse hook (matcher: Bash)
# Fires when Claude writes the session mode to ~/.claude/.silver-bullet/mode.
# Creates docs/sessions/<date>-<timestamp>.md skeleton and records path to
# ~/.claude/.silver-bullet/session-log-path so the documentation step can fill it in.
# In autonomous mode: also launches a 10-minute background sentinel.

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

# User-scoped state directory (avoids world-readable /tmp/)
SB_DIR="${HOME}/.claude/.silver-bullet"

# Validate test overrides (defense-in-depth: reject non-numeric sleep values)
if [[ -n "${SENTINEL_SLEEP_OVERRIDE:-}" ]] && ! [[ "$SENTINEL_SLEEP_OVERRIDE" =~ ^[0-9]+$ ]]; then
  SENTINEL_SLEEP_OVERRIDE=600
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') || true
[[ -z "$cmd" ]] && exit 0

# Only fire when command touches the session mode file
printf '%s' "$cmd" | grep -qE '\.silver-bullet(/mode|-mode)' || exit 0

# --- Locate project root (allow override for testing) ---
project_root="${PROJECT_ROOT_OVERRIDE:-}"
if [[ -z "$project_root" ]]; then
  search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]]; then
      project_root="$search_dir"
      break
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then break; fi
    search_dir=$(dirname "$search_dir")
  done
fi
[[ -z "$project_root" ]] && exit 0

# Allow sessions dir override for testing
sessions_dir="${SESSION_LOG_TEST_DIR:-$project_root/docs/sessions}"
mkdir -p "$sessions_dir"

# --- Step 4: Sentinel cleanup (unconditional, before dedup guard) ---
if [[ -f "$SB_DIR"/sentinel-pid && ! -L "$SB_DIR"/sentinel-pid ]]; then
  # M3 TOCTOU fix: sentinel file may contain "pid" (legacy) or "pid:start-time".
  # Only kill when start-time matches — PID recycling window defeats pid-only check.
  _sent_line=$(cat "$SB_DIR"/sentinel-pid 2>/dev/null || true)
  old_pid="${_sent_line%%:*}"
  old_start="${_sent_line#*:}"
  [[ "$old_start" == "$old_pid" ]] && old_start=""   # no colon → legacy format
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null \
     && ps -p "$old_pid" -o user= 2>/dev/null | grep -q "^$(whoami)$"; then
    if [[ -n "$old_start" ]]; then
      cur_start=$(ps -o lstart= -p "$old_pid" 2>/dev/null || true)
      if [[ -n "$cur_start" && "$cur_start" == "$old_start" ]]; then
        kill "$old_pid" 2>/dev/null || true
      fi
    else
      # Legacy sentinel format — still kill (previous behaviour)
      kill "$old_pid" 2>/dev/null || true
    fi
  fi
  rm -f -- "$SB_DIR"/sentinel-pid "$SB_DIR"/timeout \
        "$SB_DIR"/session-start-time "$SB_DIR"/timeout-warn-count
fi

# --- Step 5: Mode detection + dedup guard (combined) ---
today=$(date '+%Y-%m-%d')
existing=$(find "$sessions_dir" -maxdepth 1 -name "${today}*.md" -print 2>/dev/null | head -1 || true)

if [[ -n "$existing" ]]; then
  # Extract mode from existing log; validate against allowlist (security: log file could be tampered)
  mode=$(grep '^\*\*Mode:\*\*' "$existing" 2>/dev/null | awk '{print $NF}' | tr -d ' ') || true
  mode="${mode:-interactive}"
  [[ "$mode" == "autonomous" ]] || mode="interactive"

  # Add missing new sections at correct skeleton positions (idempotency for pre-update logs)
  # Helper: insert section_header + placeholder immediately before anchor line
  _insert_before() {
    local file="$1" anchor="$2" header="$3" placeholder="$4"
    local tmp
    tmp=$(mktemp)
    if awk -v anch="$anchor" -v hdr="$header" -v ph="$placeholder" '
      $0 == anch { printf "%s\n\n%s\n\n", hdr, ph }
      { print }
    ' "$file" > "$tmp"; then
      mv "$tmp" "$file"
    else
      rm -f -- "$tmp"
    fi
  }
  if ! grep -q "^## Pre-answers$" "$existing" 2>/dev/null; then
    _insert_before "$existing" "## Task" "## Pre-answers" \
      "(filled at Step 0 by Claude if autonomous mode)"
  fi
  if ! grep -q "^## Skills flagged at discovery$" "$existing" 2>/dev/null; then
    _insert_before "$existing" "## Agent Teams dispatched" \
      "## Skills flagged at discovery" "(filled at DISCUSS phase)"
    _insert_before "$existing" "## Agent Teams dispatched" \
      "## Skill gap check (post-plan)" "(filled after plan is written)"
  elif ! grep -q "^## Skill gap check" "$existing" 2>/dev/null; then
    _insert_before "$existing" "## Agent Teams dispatched" \
      "## Skill gap check (post-plan)" "(filled after plan is written)"
  fi
  if ! grep -q "^## Items Filed$" "$existing" 2>/dev/null; then
    _insert_before "$existing" "## Knowledge & Lessons additions" \
      "## Items Filed" "(none)"
  fi

  # Re-launch sentinel if autonomous (second-terminal re-trigger)
  if [[ "$mode" == "autonomous" ]]; then
    sb_guard_nofollow "$SB_DIR"/session-start-time
    sb_guard_nofollow "$SB_DIR"/timeout
    sb_guard_nofollow "$SB_DIR"/sentinel-pid
    date +%s > "$SB_DIR"/session-start-time
    (sleep "${SENTINEL_SLEEP_OVERRIDE:-600}" && echo "TIMEOUT" > "$SB_DIR"/timeout) </dev/null >/dev/null 2>&1 &
    sentinel_pid=$!
    disown "$sentinel_pid"
    _sent_start=$(ps -o lstart= -p "$sentinel_pid" 2>/dev/null || true)
    printf '%s:%s\n' "$sentinel_pid" "$_sent_start" > "$SB_DIR"/sentinel-pid
    # Insert note under ## Autonomous decisions (portable awk — no sed -i '' macOS dependency)
    _note_tmp=$(mktemp)
    if awk '/^## Autonomous decisions$/ { print; print ""; print "[Timeout sentinel restarted: session re-triggered from second terminal]"; next } { print }' \
      "$existing" > "$_note_tmp"; then
      mv "$_note_tmp" "$existing"
    else
      rm -f -- "$_note_tmp"
    fi
  fi

  sb_guard_nofollow "$SB_DIR"/session-log-path; printf '%s' "$existing" > "$SB_DIR"/session-log-path
  basename "$existing" | jq -Rs '{"hookSpecificOutput":{"message":("ℹ️ Session log already exists: " + .)}}' | tr -d '\n'
  exit 0
fi

# No existing log — read mode from mode file (ground truth)
mode_file="${SB_DIR}/mode"
if [[ -f "$mode_file" && ! -L "$mode_file" ]]; then
  mode=$(cat "$mode_file" 2>/dev/null || echo "interactive")
  # Validate against allowlist
  case "$mode" in
    interactive|autonomous) ;;
    *) mode="interactive" ;;
  esac
else
  mode="interactive"
fi

# --- Step 6: Create session log ---
timestamp=$(date '+%H-%M-%S')
log_file="$sessions_dir/${today}-${timestamp}.md"
sb_safe_write "$log_file"

cat > "$log_file" << LOGEOF
# Session Log — ${today}

**Date:** ${today}
**Mode:** ${mode}
**Model:** (filled at documentation step)
**Virtual cost:** (filled at documentation step)

---

## Pre-answers

(filled at Step 0 by Claude if autonomous mode)

## Task

(filled at documentation step)

## Approach

(filled at documentation step)

## Files changed

(filled at documentation step)

## Skills invoked

(filled at documentation step)

## Skills flagged at discovery

(filled at DISCUSS phase)

## Skill gap check (post-plan)

(filled after plan is written)

## Agent Teams dispatched

(filled at documentation step)

## Autonomous decisions

(none)

## Needs human review

(none)

## Outcome

(filled at documentation step)

## Items Filed

(none)

## Knowledge & Lessons additions

(filled at documentation step)
LOGEOF

# --- Step 7: Write session start timestamp ---
sb_guard_nofollow "$SB_DIR"/session-start-time
date +%s > "$SB_DIR"/session-start-time

# --- Step 8: Launch sentinel (autonomous mode only) ---
if [[ "$mode" == "autonomous" ]]; then
  sb_guard_nofollow "$SB_DIR"/timeout
  sb_guard_nofollow "$SB_DIR"/sentinel-pid
  (sleep "${SENTINEL_SLEEP_OVERRIDE:-600}" && echo "TIMEOUT" > "$SB_DIR"/timeout) </dev/null >/dev/null 2>&1 &
  sentinel_pid=$!
  disown "$sentinel_pid"
  _sent_start=$(ps -o lstart= -p "$sentinel_pid" 2>/dev/null || true)
  printf '%s:%s\n' "$sentinel_pid" "$_sent_start" > "$SB_DIR"/sentinel-pid
fi

sb_guard_nofollow "$SB_DIR"/session-log-path; printf '%s' "$log_file" > "$SB_DIR"/session-log-path
basename "$log_file" | jq -Rs '{"hookSpecificOutput":{"message":("📋 Session log created: docs/sessions/" + .)}}'
