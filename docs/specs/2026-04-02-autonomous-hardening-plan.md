# Autonomous Mode Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement answer injection, timeout supervision (sentinel hook + anti-stall), and skill auto-discovery to harden Silver Bullet's autonomous mode.

**Architecture:** Three features across two layers. Hook layer: restructure `session-log-init.sh` (sentinel launch, new skeleton sections) and add `timeout-check.sh` (flag polling). Workflow/instruction layer: extend Step 0 with answer injection Q&A, add skill discovery before DISCUSS and after plan, add cleanup command at completion.

**Tech Stack:** bash, jq, Claude Code plugin hook system (PostToolUse), macOS `/tmp/`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `hooks/session-log-init.sh` | Restructure: cleanup before dedup, mode+dedup combined, sentinel launch with disown, three new skeleton sections |
| Modify | `tests/hooks/test-session-log-init.sh` | Add sentinel PID, interactive no-launch, re-init cleanup tests |
| Create | `hooks/timeout-check.sh` | Poll `/tmp/.silver-bullet-timeout`; mode gate; stale-flag check; rate-limit |
| Create | `tests/hooks/test-timeout-check.sh` | Tests: flag+current+autonomous→warn; rate-limit; absent→silent; interactive→silent; stale→silent |
| Modify | `hooks/hooks.json` | session-log-init async:true→false; add timeout-check entry (matcher:.*,async:false) |
| Modify | `CLAUDE.md` | Add per-step 10-call stall trigger to Section 4 autonomous mode rules |
| Modify | `templates/CLAUDE.md.base` | Same stall trigger in Section 4 |
| Modify | `templates/workflows/full-dev-cycle.md` | Step 0 answer injection; skill discovery before DISCUSS; gap check after Step 5; cleanup command at completion |
| Modify | `docs/workflows/full-dev-cycle.md` | Sync from template (cp) |

---

## Task 1: Restructure session-log-init.sh

**Files:**
- Modify: `hooks/session-log-init.sh`
- Modify: `tests/hooks/test-session-log-init.sh`

The hook needs: (a) sentinel cleanup unconditionally before dedup, (b) mode detection and dedup combined so `$existing` is available for mode-override before exit, (c) sentinel launch with `disown` after log creation, (d) three new skeleton sections (`## Pre-answers`, `## Skills flagged at discovery`, `## Skill gap check (post-plan)`), (e) idempotency: dedup path checks for missing sections and adds them for logs created before this update, (f) async:true stays in the hook itself — the hooks.json change is Task 5.

**TDD order: add tests first, run to confirm failure, then implement.**

- [ ] **Step 1.1: Read current hook to understand exact line positions**

```bash
cat -n /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh
```

- [ ] **Step 1.2: Add new test cases to test-session-log-init.sh (before implementation)**

Append after the existing Test 3 block (before `rm -rf` and `printf 'All tests passed'`):

```bash
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
rm -f /tmp/.silver-bullet-sentinel-pid
run_hook4 "echo autonomous > /tmp/.silver-bullet-mode" > /dev/null
if [[ -f /tmp/.silver-bullet-sentinel-pid ]]; then
  printf 'PASS: autonomous mode creates sentinel PID file\n'
  # Clean up sentinel
  kill "$(cat /tmp/.silver-bullet-sentinel-pid)" 2>/dev/null || true
  rm -f /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-timeout \
        /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
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
rm -f /tmp/.silver-bullet-sentinel-pid
run_hook5 "echo interactive > /tmp/.silver-bullet-mode" > /dev/null
if [[ ! -f /tmp/.silver-bullet-sentinel-pid ]]; then
  printf 'PASS: interactive mode does not create sentinel PID file\n'
else
  printf 'FAIL: interactive mode should not create sentinel PID file\n'
  kill "$(cat /tmp/.silver-bullet-sentinel-pid)" 2>/dev/null || true
  rm -f /tmp/.silver-bullet-sentinel-pid
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
rm -f /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-timeout \
      /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
# First trigger: creates log + sentinel
run_hook6 "echo autonomous > /tmp/.silver-bullet-mode" > /dev/null
pid1=$(cat /tmp/.silver-bullet-sentinel-pid 2>/dev/null || echo "")
# Second trigger: dedup path should kill old sentinel and re-launch
run_hook6 "echo autonomous > /tmp/.silver-bullet-mode" > /dev/null
pid2=$(cat /tmp/.silver-bullet-sentinel-pid 2>/dev/null || echo "")
if [[ -n "$pid2" ]] && [[ "$pid2" != "$pid1" ]]; then
  printf 'PASS: dedup path re-launches sentinel with new PID\n'
else
  printf 'FAIL: expected new sentinel PID after re-init, got pid1=%s pid2=%s\n' "$pid1" "$pid2"
  rm -rf "$SESSION_LOG_DIR6"
  exit 1
fi
kill "$pid2" 2>/dev/null || true
rm -f /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-timeout \
      /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
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
run_hook7 "echo interactive > /tmp/.silver-bullet-mode" > /dev/null
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
```

- [ ] **Step 1.3: Run tests to confirm new ones fail (hook not yet updated)**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh 2>&1 || true
```
Expected: Tests 1–3 pass; Tests 4–7 fail (sentinel and skeleton not yet implemented).

- [ ] **Step 1.4: Write the new session-log-init.sh**

Replace `hooks/session-log-init.sh` entirely with:

```bash
#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Bash)
# Fires when Claude writes the session mode to /tmp/.silver-bullet-mode.
# Creates docs/sessions/<date>-<timestamp>.md skeleton and records path to
# /tmp/.silver-bullet-session-log-path so the documentation step can fill it in.
# In autonomous mode: also launches a 10-minute background sentinel.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') || true
[[ -z "$cmd" ]] && exit 0

# Only fire when command touches .silver-bullet-mode
printf '%s' "$cmd" | grep -q '\.silver-bullet-mode' || exit 0

# --- Locate project root (allow override for testing) ---
project_root="${PROJECT_ROOT_OVERRIDE:-}"
if [[ -z "$project_root" ]]; then
  search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]]; then
      project_root="$search_dir"
      break
    fi
    [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]] && break
    search_dir=$(dirname "$search_dir")
  done
fi
[[ -z "$project_root" ]] && exit 0

# Allow sessions dir override for testing
sessions_dir="${SESSION_LOG_TEST_DIR:-$project_root/docs/sessions}"
mkdir -p "$sessions_dir"

# --- Step 4: Sentinel cleanup (unconditional, before dedup guard) ---
if [[ -f /tmp/.silver-bullet-sentinel-pid ]]; then
  old_pid=$(cat /tmp/.silver-bullet-sentinel-pid)
  kill "$old_pid" 2>/dev/null || true
  rm -f /tmp/.silver-bullet-sentinel-pid /tmp/.silver-bullet-timeout \
        /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
fi

# --- Step 5: Mode detection + dedup guard (combined) ---
today=$(date '+%Y-%m-%d')
existing=$(ls "$sessions_dir/${today}"*.md 2>/dev/null | head -1 || true)

if [[ -n "$existing" ]]; then
  # Extract mode from existing log
  mode=$(grep '^\*\*Mode:\*\*' "$existing" 2>/dev/null | awk '{print $NF}' | tr -d ' ') || true
  mode="${mode:-interactive}"

  # Add missing new sections at correct skeleton positions (idempotency for pre-update logs)
  # Helper: insert section_header + placeholder immediately before anchor line
  _insert_before() {
    local file="$1" anchor="$2" header="$3" placeholder="$4"
    local tmp
    tmp=$(mktemp)
    awk -v anch="$anchor" -v hdr="$header" -v ph="$placeholder" '
      $0 == anch { printf "%s\n\n%s\n\n", hdr, ph }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
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

  # Re-launch sentinel if autonomous (second-terminal re-trigger)
  if [[ "$mode" == "autonomous" ]]; then
    date +%s > /tmp/.silver-bullet-session-start-time
    (sleep "${SENTINEL_SLEEP_OVERRIDE:-600}" && echo "TIMEOUT" > /tmp/.silver-bullet-timeout) &
    sentinel_pid=$!
    disown "$sentinel_pid"
    echo "$sentinel_pid" > /tmp/.silver-bullet-sentinel-pid
    # Insert note under ## Autonomous decisions (portable awk — no sed -i '' macOS dependency)
    _note_tmp=$(mktemp)
    awk '/^## Autonomous decisions$/ { print; print ""; print "[Timeout sentinel restarted: session re-triggered from second terminal]"; next } { print }' \
      "$existing" > "$_note_tmp" && mv "$_note_tmp" "$existing"
  fi

  printf '%s' "$existing" > /tmp/.silver-bullet-session-log-path
  printf '{"hookSpecificOutput":{"message":"ℹ️ Session log already exists: %s"}}' \
    "$(basename "$existing")"
  exit 0
fi

# No existing log — extract mode from command string
mode="interactive"
printf '%s' "$cmd" | grep -q "autonomous" && mode="autonomous"

# --- Step 6: Create session log ---
timestamp=$(date '+%H-%M-%S')
log_file="$sessions_dir/${today}-${timestamp}.md"

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

## KNOWLEDGE.md additions

(filled at documentation step)
LOGEOF

# --- Step 7: Write session start timestamp ---
date +%s > /tmp/.silver-bullet-session-start-time

# --- Step 8: Launch sentinel (autonomous mode only) ---
if [[ "$mode" == "autonomous" ]]; then
  (sleep "${SENTINEL_SLEEP_OVERRIDE:-600}" && echo "TIMEOUT" > /tmp/.silver-bullet-timeout) &
  sentinel_pid=$!
  disown "$sentinel_pid"
  echo "$sentinel_pid" > /tmp/.silver-bullet-sentinel-pid
fi

printf '%s' "$log_file" > /tmp/.silver-bullet-session-log-path
printf '{"hookSpecificOutput":{"message":"📋 Session log created: docs/sessions/%s"}}' \
  "$(basename "$log_file")"
```

Note: `SENTINEL_SLEEP_OVERRIDE` env var allows tests to use a short sleep (e.g., `1`) instead of 600 seconds.

- [ ] **Step 1.5: Verify the file was written**

```bash
head -5 /Users/shafqat/Documents/Projects/silver-bullet/hooks/session-log-init.sh
```
Expected: `#!/usr/bin/env bash`

- [ ] **Step 1.6: Run all tests**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh
```
Expected: all 7 tests print PASS, `All tests passed.`

- [ ] **Step 1.7: Commit**

```bash
git add hooks/session-log-init.sh tests/hooks/test-session-log-init.sh
git commit -m "$(cat <<'EOF'
feat: restructure session-log-init with sentinel and new skeleton sections

- Sentinel cleanup before dedup guard (eliminates stale PID collisions)
- Mode+dedup combined: $existing available for mode-override before exit
- Dedup path re-launches sentinel in autonomous mode (second-terminal fix)
- Sentinel launched with disown after log creation
- session-start-time written before sentinel launch
- New skeleton sections: Pre-answers, Skills flagged at discovery, Skill gap check
- Idempotency: dedup path adds missing sections to pre-update logs
- Dedup path inserts sentinel note under ## Autonomous decisions (not at end)
- SENTINEL_SLEEP_OVERRIDE env var for testability

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create timeout-check.sh and its test

**Files:**
- Create: `hooks/timeout-check.sh`
- Create: `tests/hooks/test-timeout-check.sh`

- [ ] **Step 2.1: Write test driver first (TDD)**

Create `tests/hooks/test-timeout-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/timeout-check.sh"

# Helpers
write_mode() { echo "$1" > /tmp/.silver-bullet-mode; }
write_start_time() { date +%s > /tmp/.silver-bullet-session-start-time; }
cleanup_tmp() {
  rm -f /tmp/.silver-bullet-mode /tmp/.silver-bullet-session-start-time \
        /tmp/.silver-bullet-timeout /tmp/.silver-bullet-timeout-warn-count \
        /tmp/.sb-test-timeout-flag-$$
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
rm -f /tmp/.silver-bullet-timeout-warn-count
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
  rm -f /tmp/.silver-bullet-timeout-warn-count
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
  rm -f /tmp/.silver-bullet-timeout-warn-count
  # Pre-populate warn-count=4 with mtime BEFORE session-start-time (stale)
  echo "4" > /tmp/.silver-bullet-timeout-warn-count
  touch -t 202001010000 /tmp/.silver-bullet-timeout-warn-count
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
```

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-timeout-check.sh
```

- [ ] **Step 2.2: Run test to confirm it fails (hook not yet written)**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-timeout-check.sh 2>&1 || true
```
Expected: error (HOOK not found or permission denied).

- [ ] **Step 2.3: Write hooks/timeout-check.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: .*, async: false)
# Checks for /tmp/.silver-bullet-timeout flag set by session-log-init.sh sentinel.
# Emits a non-blocking warning in autonomous mode when the flag is current.
# macOS-only for stale-flag check (uses stat -f %m). Non-macOS: exits 0 silently.

# Consume stdin (required to avoid broken pipe)
input=$(cat)

# Mode gate: only act in autonomous mode
mode_file_content=$(cat /tmp/.silver-bullet-mode 2>/dev/null || echo "interactive")
[[ "$mode_file_content" != "autonomous" ]] && exit 0

# Check for timeout flag (allow override for testing)
flag_file="${TIMEOUT_FLAG_OVERRIDE:-/tmp/.silver-bullet-timeout}"
[[ -f "$flag_file" ]] || exit 0

# Non-macOS: exit 0 silently (stat -f %m is macOS-only)
[[ "$(uname)" != "Darwin" ]] && exit 0

# Stale-flag check (macOS)
session_start=$(cat /tmp/.silver-bullet-session-start-time 2>/dev/null || echo "")
[[ -z "$session_start" ]] && exit 0
flag_mtime=$(stat -f %m "$flag_file" 2>/dev/null) || exit 0
[[ "$flag_mtime" -lt "$session_start" ]] && exit 0

# Rate-limiting (macOS)
count_file="/tmp/.silver-bullet-timeout-warn-count"
count=0
if [[ -f "$count_file" ]]; then
  count_mtime=$(stat -f %m "$count_file" 2>/dev/null) || count_mtime=0
  if [[ "$count_mtime" -lt "$session_start" ]]; then
    # Stale count from prior session — reset
    count=0
  else
    count=$(cat "$count_file" 2>/dev/null || echo "0")
  fi
fi
count=$((count + 1))
echo "$count" > "$count_file"
# Emit only on 1st, 6th, 11th... call (count mod 5 == 1)
[[ $((count % 5)) -ne 1 ]] && exit 0

printf '{"hookSpecificOutput":{"message":"⚠️ Autonomous session running 10+ min. Check for stalls or log a blocker under Needs human review."}}'
```

```bash
chmod +x /Users/shafqat/Documents/Projects/silver-bullet/hooks/timeout-check.sh
```

- [ ] **Step 2.4: Run tests to confirm all pass**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-timeout-check.sh
```
Expected: all tests PASS, `All tests passed.`

- [ ] **Step 2.5: Commit**

```bash
git add hooks/timeout-check.sh tests/hooks/test-timeout-check.sh
git commit -m "$(cat <<'EOF'
feat: add timeout-check hook and test

PostToolUse hook (matcher:.*, async:false) warns when autonomous session
runs 10+ min. Stale-flag rejection via session-start-time mtime (macOS).
Rate-limited to emit on 1st/6th/11th... call (mod 5). TIMEOUT_FLAG_OVERRIDE
for testability.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update hooks.json

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 3.1: Read current hooks.json**

```bash
cat /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Confirm 6 PostToolUse entries. Confirm session-log-init entry has `"async": true`.

- [ ] **Step 3.2: Change session-log-init async:true → async:false**

In `hooks/hooks.json`, find the entry with `session-log-init.sh` and change `"async": true` to `"async": false`.

- [ ] **Step 3.3: Add timeout-check entry at end of PostToolUse array**

Add before the closing `]` of PostToolUse:

```json
      ,{
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/timeout-check.sh\"",
            "async": false
          }
        ]
      }
```

- [ ] **Step 3.4: Verify JSON is valid and PostToolUse has 7 entries**

```bash
jq '.hooks.PostToolUse | length' /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Expected: `7`

```bash
jq '.hooks.PostToolUse[] | select(.hooks[].command | contains("session-log-init")) | .hooks[].async' \
  /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Expected: `false`

- [ ] **Step 3.5: Commit**

```bash
git add hooks/hooks.json
git commit -m "$(cat <<'EOF'
feat: update hooks.json — session-log-init sync, add timeout-check

session-log-init: async:true → async:false (eliminates PID race).
timeout-check: new entry matcher:.*, async:false.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add anti-stall per-step budget to CLAUDE.md and template

**Files:**
- Modify: `CLAUDE.md`
- Modify: `templates/CLAUDE.md.base`

The existing anti-stall rules have two triggers. Add a third.

- [ ] **Step 4.1: Read current autonomous mode anti-stall rules in CLAUDE.md**

```bash
grep -n "Anti-stall\|stall\|tool calls" /Users/shafqat/Documents/Projects/silver-bullet/CLAUDE.md
```

- [ ] **Step 4.2: Update anti-stall in CLAUDE.md**

Find the `**Anti-stall**` line in Section 4. It currently reads:

```
- **Anti-stall** (non-blocker stalls only): a stall = the same tool call with identical args
  producing the same result 2+ times consecutively, OR 3+ tool calls in one step with no new
  state change (no file written, no new decision, no new information). On stall: make
  best-judgment decision, move on, log it.
```

Replace with:

```
- **Anti-stall** (non-blocker stalls only): a stall = any of these three conditions:
  1. Same tool call with identical args producing the same result 2+ times consecutively
  2. 3+ tool calls in one step with no new state change (no file written, no decision, no new info)
  3. Per-step budget: >10 tool calls in one step AND no file written (Write/Edit resets counter)
     AND no autonomous decision logged since step began. Counter resets on Write/Edit, on any
     decision log event, and when a new `/gsd:` command or skill is invoked (new step boundary).
  On any stall: make best-judgment decision, move on, log under "Autonomous decisions".
```

- [ ] **Step 4.3: Apply same update to templates/CLAUDE.md.base**

Find the same `**Anti-stall**` block in `templates/CLAUDE.md.base` and apply the identical replacement.

- [ ] **Step 4.4: Verify both files updated**

```bash
grep -c "Per-step budget" /Users/shafqat/Documents/Projects/silver-bullet/CLAUDE.md
grep -c "Per-step budget" /Users/shafqat/Documents/Projects/silver-bullet/templates/CLAUDE.md.base
```
Expected: `1` for each.

- [ ] **Step 4.5: Commit**

```bash
git add CLAUDE.md templates/CLAUDE.md.base
git commit -m "$(cat <<'EOF'
feat: add per-step tool-call budget as third anti-stall trigger

>10 calls with no Write/Edit and no decision logged = stall.
Counter resets on file write, decision log, or new step boundary.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update workflow template — answer injection, skill discovery, cleanup

**Files:**
- Modify: `templates/workflows/full-dev-cycle.md`
- Modify: `docs/workflows/full-dev-cycle.md`

Three insertions + one addition to the workflow.

- [ ] **Step 5.1: Read current Step 0 block in template**

```bash
grep -n "STEP 0\|SESSION MODE\|autonomous\|autonomous.*mode" \
  /Users/shafqat/Documents/Projects/silver-bullet/templates/workflows/full-dev-cycle.md | head -15
```

- [ ] **Step 5.2: Extend Step 0 with answer injection**

After the line `echo "interactive" > /tmp/.silver-bullet-mode   # or "autonomous"` closing fence, add:

```markdown
**If autonomous was chosen**, ask one follow-up before proceeding:

> Any decision points you want to pre-answer? Common ones:
> - Model routing — Planning phase: Sonnet or Opus?
> - Model routing — Design phase: Sonnet or Opus?
> - Worktree: use one for this task, or work on main?
> - Agent Teams: use worktree isolation, or main worktree throughout?
> Leave blank to use defaults (Sonnet for both phases, main, isolated).

Write answers into the `## Pre-answers` section of the session log immediately. Format each answer as:
`- Model routing — Planning: <value>`
`- Model routing — Design: <value>`
`- Worktree: <value>`
`- Agent Teams: <value>`

Omit any key the user left blank (default applies). Read pre-answers mid-session from the log
at `/tmp/.silver-bullet-session-log-path`, stripping the leading `- ` before splitting on `:`.
Log each applied pre-answer under "Autonomous decisions" with note `(pre-answered at Step 0)`.

**Fallback**: if the session log or `## Pre-answers` section is unreadable at any point,
use defaults: Sonnet for both phases, main, isolated.
```

- [ ] **Step 5.3: Add skill discovery before DISCUSS**

After the `MODEL ROUTING (once per session)` block and before `### DISCUSS`, insert:

```markdown
### SKILL DISCOVERY (once per task, before DISCUSS)

Scan installed skills from two sources:
1. `~/.claude/skills/` — flat `.md` files
2. `~/.claude/plugins/cache/` — glob `*/*/*/skills/*/SKILL.md` (layout: publisher/plugin/version/skills/skill-name)

Cross-reference the combined list against `all_tracked` in `.silver-bullet.json` and the
current task description. Surface candidates:
> Skills that may apply to this task: `/security` — auth changes; `/system-design` — new service

If no matches: log "Skill discovery: no candidates surfaced."
Write results to `## Skills flagged at discovery` in the session log. **Do not invoke yet.**
```

- [ ] **Step 5.4: Add skill gap check after Step 5 (plan)**

After the Step 5 (`/gsd:plan-phase`) block, add:

```markdown
   **Skill gap check (post-plan):** After the plan is written, cross-reference all installed
   skills (both sources, including `all_tracked`) against the plan content. Flag any skill
   covering a concern not explicitly in the plan.
   - Interactive: ask whether to add the flagged skill
   - Autonomous: add to plan or log omission as autonomous decision
   Write results to `## Skill gap check (post-plan)` in the session log.
```

- [ ] **Step 5.5: Add sentinel cleanup command to autonomous completion summary**

In `templates/workflows/full-dev-cycle.md`, after the SHIP section (step 19) and before the `## Review Loop Enforcement` section, insert:

```markdown
**Autonomous completion cleanup** (run after outputting structured summary):
```bash
rm -f /tmp/.silver-bullet-timeout /tmp/.silver-bullet-sentinel-pid \
      /tmp/.silver-bullet-session-start-time /tmp/.silver-bullet-timeout-warn-count
```
This clears the timeout sentinel so `timeout-check.sh` stops warning.
```

- [ ] **Step 5.6: Verify all four insertions present**

```bash
for term in "Pre-answers" "SKILL DISCOVERY" "Skill gap check (post-plan)" \
            "silver-bullet-sentinel-pid"; do
  count=$(grep -c "$term" \
    /Users/shafqat/Documents/Projects/silver-bullet/templates/workflows/full-dev-cycle.md \
    2>/dev/null || echo 0)
  if [[ "$count" -gt 0 ]]; then
    printf 'PASS: "%s" found\n' "$term"
  else
    printf 'FAIL: "%s" not found\n' "$term"
  fi
done
```
Expected: all 4 PASS.

- [ ] **Step 5.7: Sync to installed workflow**

```bash
cp /Users/shafqat/Documents/Projects/silver-bullet/templates/workflows/full-dev-cycle.md \
   /Users/shafqat/Documents/Projects/silver-bullet/docs/workflows/full-dev-cycle.md
```

- [ ] **Step 5.8: Commit**

```bash
git add templates/workflows/full-dev-cycle.md docs/workflows/full-dev-cycle.md
git commit -m "$(cat <<'EOF'
feat: add answer injection, skill discovery, cleanup to workflow

Step 0: answer injection Q&A for autonomous mode pre-answers.
Before DISCUSS: skill discovery scan (two sources, session log entry).
After Step 5: skill gap check against all installed skills.
After autonomous completion: sentinel cleanup command.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Final verification

- [ ] **Step 6.1: Run all hook tests**

```bash
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-session-log-init.sh && \
bash /Users/shafqat/Documents/Projects/silver-bullet/tests/hooks/test-timeout-check.sh
```
Expected: `All tests passed.` for each.

- [ ] **Step 6.2: Verify hooks.json**

```bash
jq '.hooks.PostToolUse | length' /Users/shafqat/Documents/Projects/silver-bullet/hooks/hooks.json
```
Expected: `7`

- [ ] **Step 6.3: Verify key strings in installed files**

```bash
grep -c "Per-step budget" /Users/shafqat/Documents/Projects/silver-bullet/CLAUDE.md
grep -c "SKILL DISCOVERY" /Users/shafqat/Documents/Projects/silver-bullet/docs/workflows/full-dev-cycle.md
grep -c "Pre-answers" /Users/shafqat/Documents/Projects/silver-bullet/docs/workflows/full-dev-cycle.md
grep -c "silver-bullet-sentinel-pid" /Users/shafqat/Documents/Projects/silver-bullet/docs/workflows/full-dev-cycle.md
```
Expected: `1` each.

- [ ] **Step 6.4: Check git log and status**

```bash
git log --oneline -8
git status
```
Expected: 5 new commits (Tasks 1–5), clean working tree.

---

*Generated: 2026-04-02 | Silver Bullet v0.2.0 | Spec: docs/specs/2026-04-02-autonomous-hardening-design.md*
