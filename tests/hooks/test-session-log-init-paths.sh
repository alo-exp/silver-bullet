#!/usr/bin/env bash
# hooks/session-log-init.sh: sentinel lifecycle, pre-update log migration, project
# discovery and library fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/session-log-init.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset PROJECT_ROOT_OVERRIDE SESSION_LOG_TEST_DIR SENTINEL_SLEEP_OVERRIDE

ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
SESS="$EC_PROJ/docs/sessions"
TODAY="2026-01-15"
ec_freeze_date "$TODAY"
PAYLOAD="$(jq -cn --arg c "echo autonomous > $SB_RUNTIME_HOME_ROOT/.silver-bullet/mode" '{tool_name:"Bash",tool_input:{command:$c}}')"
SLEEPERS=()

run_log() { # [payload] [hook]  (cwd = $EC_RUN_DIR)
  local payload="${1:-$PAYLOAD}" hook="${2:-$HOOK}"
  tl_run_stdin "$payload" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "$hook"
}
reset_logs() {
  local f
  rm -rf "${SESS:?}"
  for f in mode sentinel-pid timeout session-start-time timeout-warn-count session-log-path; do rm -f "${SD:?}/${f:?}"; done
  for f in "$SD"/sentinel-lock-*; do [[ -e "$f" ]] && rm -f "$f"; done
  EC_RUN_DIR="$EC_PROJ"
}
cleanup_sleepers() {
  local p
  for p in "${SLEEPERS[@]}"; do kill "$p" 2>/dev/null || true; done
  if [[ -f "$SD/sentinel-pid" ]]; then
    p="$(cut -d: -f1 "$SD/sentinel-pid")"
    kill "$p" 2>/dev/null || true
  fi
}
trap 'cleanup_sleepers; tl_cleanup' EXIT
new_log() { find "$SESS" -maxdepth 1 -name "${TODAY}*.md" | head -1; }

# ---- gating -----------------------------------------------------------------
reset_logs
run_log '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
assert_eq "non-shell tool ignored" "" "$TL_OUT"
run_log '{"tool_name":"Bash","tool_input":{"command":""}}'
assert_eq "empty command ignored" "" "$TL_OUT"
run_log '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
assert_eq "unrelated command ignored" "" "$TL_OUT"
PATH="$(tl_path_without jq)" run_log
assert_eq "no jq: silent" "" "$TL_OUT"
assert_eq "no jq: exit 0" "0" "$TL_STATUS"
EC_RUN_DIR="$TL_TMP"
run_log
assert_eq "outside any SB project: nothing" "" "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"
PROJECT_ROOT_OVERRIDE="$TL_TMP" run_log
assert_eq "override root without config: nothing" "" "$TL_OUT"
assert_file_absent "override root without config: no log dir" "$TL_TMP/docs"

# ---- creation: interactive, invalid mode file, subdirectory discovery --------
reset_logs
mkdir -p "$EC_PROJ/deep/er"
EC_RUN_DIR="$EC_PROJ/deep/er"
printf 'bogus' >"$SD/mode"
run_log
assert_contains "created from a subdirectory (walk up)" "$TL_OUT" "Session log created: docs/sessions/"
assert_contains "invalid mode file coerced to interactive" "$(cat "$(new_log)")" "**Mode:** interactive"
assert_file_exists "session-log-path recorded" "$SD/session-log-path"
assert_file_absent "no sentinel in interactive mode" "$SD/sentinel-pid"
EC_RUN_DIR="$EC_PROJ"
rm -rf "${EC_PROJ:?}/deep"

# ---- autonomous creation starts a sentinel ----------------------------------
reset_logs
printf 'autonomous' >"$SD/mode"
SENTINEL_SLEEP_OVERRIDE='not-a-number' run_log
assert_contains "autonomous log created" "$TL_OUT" "Session log created"
assert_contains "mode recorded" "$(cat "$(new_log)")" "**Mode:** autonomous"
assert_file_exists "sentinel pid file" "$SD/sentinel-pid"
pid="$(cut -d: -f1 "$SD/sentinel-pid")"
tok="$(cut -d: -f2 "$SD/sentinel-pid")"
assert_file_exists "lock named by the token" "$SD/sentinel-lock-$tok"
if kill -0 "$pid" 2>/dev/null; then tl_pass "sentinel is running (non-numeric override fell back)"; else tl_fail "sentinel is running"; fi
assert_file_exists "session start time written" "$SD/session-start-time"
kill "$pid" 2>/dev/null || true

# uuid fallbacks
reset_logs
printf 'autonomous' >"$SD/mode"
tl_stub uuidgen 'exit 1'
SENTINEL_SLEEP_OVERRIDE=30 run_log
tok="$(cut -d: -f2 "$SD/sentinel-pid")"
assert_match "kernel uuid used when uuidgen fails" '^[0-9a-f-]{36}$' "$tok"
kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true
reset_logs
printf 'autonomous' >"$SD/mode"
REAL_CAT="$(command -v cat)"
tl_stub cat "for a in \"\$@\"; do case \"\$a\" in /proc/*) exit 1;; esac; done; exec $REAL_CAT \"\$@\""
SENTINEL_SLEEP_OVERRIDE=30 run_log
tok="$(cut -d: -f2 "$SD/sentinel-pid")"
assert_match "pid-time token when both uuid sources fail" '^[0-9]+-[0-9]+$' "$tok"
kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true
rm -f "${TL_BIN:?}/uuidgen" "${TL_BIN:?}/cat"

# lock creation failure kills the sentinel and leaves no pid file
reset_logs
printf 'autonomous' >"$SD/mode"
tl_stub touch 'exit 1'
SENTINEL_SLEEP_OVERRIDE=30 run_log
rm -f "${TL_BIN:?}/touch"
assert_file_absent "no sentinel-pid when the lock cannot be created" "$SD/sentinel-pid"
assert_contains "log still created" "$TL_OUT" "Session log created"

# ---- existing log: dedup, mode from log, sentinel restart -------------------
reset_logs
printf 'interactive' >"$SD/mode"
run_log
first="$(new_log)"
run_log
assert_contains "second run reports the existing log" "$TL_OUT" "Session log already exists"
EXPECT_MSG="$(printf '{  "hookSpecificOutput": {    "message": "\xe2\x84\xb9\xef\xb8\x8f Session log already exists: %s\\n"  }}' "$(basename "$first")")"
assert_eq "already-exists output is the pretty JSON with every newline stripped (byte exact)" "$EXPECT_MSG" "$TL_OUT"
assert_eq "no second log" "1" "$(find "$SESS" -maxdepth 1 -name "${TODAY}*.md" | wc -l | tr -d ' ')"
assert_eq "session-log-path points at the existing log" "$first" "$(cat "$SD/session-log-path")"

# tampered Mode line is coerced
sed -i 's/^\*\*Mode:\*\* .*/**Mode:** evil/' "$first"
run_log
assert_file_absent "tampered mode does not start a sentinel" "$SD/sentinel-pid"

# autonomous existing log: sentinel restarted + note, old sentinel killed
sed -i 's/^\*\*Mode:\*\* .*/**Mode:** autonomous/' "$first"
sleep 300 &
old=$!
SLEEPERS+=("$old")
oldtok="tok-old-1"
printf '%s:%s\n' "$old" "$oldtok" >"$SD/sentinel-pid"
: >"$SD/sentinel-lock-$oldtok"
printf '1' >"$SD/timeout-warn-count"
SENTINEL_SLEEP_OVERRIDE=30 run_log
assert_contains "restart reports existing log" "$TL_OUT" "Session log already exists"
if kill -0 "$old" 2>/dev/null; then tl_fail "old sentinel with matching lock killed"; else tl_pass "old sentinel with matching lock killed"; fi
assert_file_absent "old lock removed" "$SD/sentinel-lock-$oldtok"
assert_contains "restart note written" "$(cat "$first")" "[Timeout sentinel restarted"
assert_file_absent "stale timeout-warn-count cleared" "$SD/timeout-warn-count"
newpid="$(cut -d: -f1 "$SD/sentinel-pid")"
if kill -0 "$newpid" 2>/dev/null; then tl_pass "new sentinel running"; else tl_fail "new sentinel running"; fi
kill "$newpid" 2>/dev/null || true

# token without a lock file: process is left alone
sleep 300 &
old=$!
SLEEPERS+=("$old")
printf '%s:%s\n' "$old" "no-lock-token" >"$SD/sentinel-pid"
SENTINEL_SLEEP_OVERRIDE=30 run_log
if kill -0 "$old" 2>/dev/null; then tl_pass "sentinel without lock file is not killed"; else tl_fail "sentinel without lock file is not killed"; fi
kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true

# legacy pid-only sentinel file: killed on user match
sleep 300 &
old=$!
SLEEPERS+=("$old")
printf '%s\n' "$old" >"$SD/sentinel-pid"
SENTINEL_SLEEP_OVERRIDE=30 run_log
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$old" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$old" 2>/dev/null; then tl_fail "legacy pid-only sentinel killed"; else tl_pass "legacy pid-only sentinel killed"; fi
kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true

# a ps that keeps writing after the matching line must not hide the owner match
sleep 300 &
old=$!
SLEEPERS+=("$old")
printf '%s:%s\n' "$old" "tok-big" >"$SD/sentinel-pid"
: >"$SD/sentinel-lock-tok-big"
tl_stub ps 'whoami; head -c 300000 /dev/zero | tr "\\0" "x"; echo'
SENTINEL_SLEEP_OVERRIDE=30 run_log
rm -f "${TL_BIN:?}/ps"; hash -r
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$old" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$old" 2>/dev/null; then tl_fail "owner match survives a long ps output"; else tl_pass "owner match survives a long ps output"; fi
kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true

# ---- pre-update logs gain the new sections ----------------------------------
reset_logs
mkdir -p "$SESS"
old_log="$SESS/${TODAY}-00-00-00.md"
cat >"$old_log" <<'EOF'
# Session Log

**Mode:** interactive

## Task

x

## Agent Teams dispatched

y

## Outcome
EOF
run_log
body="$(cat "$old_log")"
assert_contains "Pre-answers added" "$body" "## Pre-answers"
assert_contains "Skills flagged added" "$body" "## Skills flagged at discovery"
assert_contains "Skill gap check added" "$body" "## Skill gap check (post-plan)"
assert_contains "Active Intent Ledger added" "$body" "## Active Intent Ledger"
assert_eq "pre-answers precede task" "1" "$(awk '/^## Pre-answers$/{p=NR} /^## Task$/{t=NR} END{print (p<t)?1:0}' "$old_log")"
# skill-flagged present but gap check missing
cat >"$old_log" <<'EOF'
**Mode:** interactive
## Pre-answers
## Task
## Skills flagged at discovery
## Agent Teams dispatched
## Active Intent Ledger
EOF
run_log
assert_contains "gap check added next to existing flagged section" "$(cat "$old_log")" "## Skill gap check (post-plan)"
# no anchors: file untouched
printf '**Mode:** interactive\nplain\n' >"$old_log"
before="$(cat "$old_log")"
run_log
assert_eq "no anchors: log unchanged" "$before" "$(cat "$old_log")"
# awk failing: temp file dropped, log unchanged
printf '**Mode:** interactive\n## Task\n## Agent Teams dispatched\n' >"$old_log"
before="$(cat "$old_log")"
tl_stub awk 'exit 1'
run_log
rm -f "${TL_BIN:?}/awk"
assert_eq "awk failure: log unchanged" "$before" "$(cat "$old_log")"

# ---- library fallbacks ------------------------------------------------------
ec_stage_hooks "$TL_TMP/noguard" nofollow-guard.sh
reset_logs
mkdir -p "$SESS"
run_log '' "$TL_TMP/noguard/hooks/session-log-init.sh"
assert_contains "fallback guard: log created" "$TL_OUT" "Session log created"
rm -f "${SD:?}/session-log-path"
ln -s "$TL_TMP/elsewhere" "$SD/session-log-path"
run_log '' "$TL_TMP/noguard/hooks/session-log-init.sh"
assert_eq "fallback guard refuses a symlinked session-log-path" "1" "$TL_STATUS"
assert_contains "fallback guard explains" "$TL_ERR" "refusing to write through symlink"
rm -f "${SD:?}/session-log-path"

ec_stage_hooks "$TL_TMP/nolib" -
run_log '' "$TL_TMP/nolib/hooks/session-log-init.sh"
assert_eq "no lib dir: fails open silently" "0" "$TL_STATUS"

ec_stage_hooks "$TL_TMP/nogate" sb-project-gate.sh
reset_logs
run_log '' "$TL_TMP/nogate/hooks/session-log-init.sh"
assert_contains "no project gate lib: still creates the log" "$TL_OUT" "Session log created"
ec_stage_hooks "$TL_TMP/legacygate" sb-project-gate.sh project-active.sh
printf '%s\n' 'sb_project_is_initiated() { return 1; }' >"$TL_TMP/legacygate/hooks/lib/sb-project-gate.sh"
reset_logs
run_log '' "$TL_TMP/legacygate/hooks/session-log-init.sh"
assert_eq "legacy initiated gate rejecting: silent" "" "$TL_OUT"
assert_file_absent "legacy initiated gate rejecting: no log" "$SESS"
ec_stage_hooks "$TL_TMP/toolinput" tool-input.sh
reset_logs
run_log '' "$TL_TMP/toolinput/hooks/session-log-init.sh"
assert_contains "no tool-input lib: jq extraction path" "$TL_OUT" "Session log created"
run_log '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$TL_TMP/toolinput/hooks/session-log-init.sh"
assert_eq "no tool-input lib: unrelated command ignored" "" "$TL_OUT"

tl_results
