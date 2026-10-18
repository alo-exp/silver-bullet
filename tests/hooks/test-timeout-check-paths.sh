#!/usr/bin/env bash
# hooks/timeout-check.sh: progress baseline, BSD stat flavour and guard fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/timeout-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset TIMEOUT_FLAG_OVERRIDE SILVER_BULLET_STATE_FILE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"

run_tc() { # [hook]
  tl_run_stdin '{}' bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "${1:-$HOOK}"
}
msg() { jq -r '.hookSpecificOutput.message // ""' <<<"$TL_OUT"; }
reset() {
  local f
  for f in mode session-start-time timeout call-count last-progress-call last-state-mtime state stall-block timeout-warn-count; do
    rm -f "${SD:?}/${f:?}"
  done
  printf 'autonomous' >"$SD/mode"
  printf '1000' >"$SD/session-start-time"
}

# ---- gating -----------------------------------------------------------------
reset
rm -f "$SD/mode"
run_tc
assert_eq "no mode file: silent" "" "$TL_OUT"
printf 'interactive' >"$SD/mode"
run_tc
assert_eq "interactive mode: silent" "" "$TL_OUT"
assert_file_absent "interactive mode: no counters" "$SD/call-count"
reset
rm -f "$SD/session-start-time"
run_tc
assert_eq "no session start: silent" "" "$TL_OUT"
printf 'garbage' >"$SD/session-start-time"
run_tc
assert_eq "non-numeric session start: silent" "" "$TL_OUT"
assert_file_absent "non-numeric session start: no counters" "$SD/call-count"

# ---- counters and progress baseline -----------------------------------------
reset
run_tc
assert_eq "first call counted" "1" "$(cat "$SD/call-count")"
run_tc
assert_eq "second call counted" "2" "$(cat "$SD/call-count")"
assert_file_absent "no state file: no baseline written" "$SD/last-state-mtime"

printf 'silver-plan\n' >"$SD/state"
run_tc
assert_eq "state change resets the progress baseline" "3" "$(cat "$SD/last-progress-call")"
assert_eq "state mtime recorded" "$(stat -c %Y "$SD/state")" "$(cat "$SD/last-state-mtime")"
# progress baseline is read back on later calls and the call count keeps growing
printf '49' >"$SD/call-count"
printf '10' >"$SD/last-progress-call"
touch -d @2000 "$SD/state"
printf '2000' >"$SD/last-state-mtime"
run_tc
assert_contains "40 calls since progress: check-in" "$(msg)" "Check-in: 40 tool calls"
printf '50' >"$SD/call-count"
run_tc
assert_eq "no output between thresholds" "" "$TL_OUT"
printf '69' >"$SD/call-count"
run_tc
assert_contains "stall warning at 60 calls" "$(msg)" "STALL WARNING — 60 tool calls"
printf '109' >"$SD/call-count"
run_tc
assert_contains "stall block at 100 calls" "$(msg)" "STALL BLOCK"
assert_eq "stall flag records the count" "100" "$(tr -d '[:space:]' <"$SD/stall-block")"

# stale per-session files (older than the session start) are ignored
reset
printf '99' >"$SD/call-count"
touch -d @500 "$SD/call-count"
printf '99' >"$SD/last-progress-call"
touch -d @500 "$SD/last-progress-call"
printf '99' >"$SD/last-state-mtime"
touch -d @500 "$SD/last-state-mtime"
run_tc
assert_eq "stale call count restarts from zero" "1" "$(cat "$SD/call-count")"

# ---- tier 1 wall clock ------------------------------------------------------
reset
printf 'TIMEOUT' >"$SD/timeout"
run_tc
assert_contains "timeout flag warns on the first call" "$(msg)" "running 10+ min"
assert_eq "warn counter" "1" "$(cat "$SD/timeout-warn-count")"
run_tc
assert_eq "rate limited on the second call" "" "$TL_OUT"
printf '5' >"$SD/timeout-warn-count"
run_tc
assert_contains "warns again on the 6th" "$(msg)" "running 10+ min"
touch -d @500 "$SD/timeout-warn-count"
printf '5' >"$SD/timeout-warn-count"
touch -d @500 "$SD/timeout-warn-count"
run_tc
assert_eq "stale warn counter restarts" "1" "$(cat "$SD/timeout-warn-count")"
reset
printf 'TIMEOUT' >"$SD/timeout"
touch -d @500 "$SD/timeout"
run_tc
assert_eq "flag older than the session is ignored" "" "$TL_OUT"
printf 'x' >"$TL_TMP/flag"
TIMEOUT_FLAG_OVERRIDE="$TL_TMP/flag" run_tc
assert_contains "flag path override" "$(msg)" "running 10+ min"

# ---- BSD stat flavour -------------------------------------------------------
REAL_STAT="$(command -v stat)"
tl_stub uname 'echo Darwin'
tl_stub stat "if [[ \"\$1\" == \"-f\" ]]; then shift 2; exec $REAL_STAT -c %Y \"\$@\"; fi; exec $REAL_STAT \"\$@\""
reset
printf 'x' >"$SD/state"
run_tc
assert_eq "BSD stat flavour: baseline written" "1" "$(cat "$SD/last-progress-call")"
tl_stub stat 'exit 1'
reset
printf 'TIMEOUT' >"$SD/timeout"
run_tc
assert_eq "stat failing: mtime treated as 0, flag older than session" "" "$TL_OUT"
rm -f "${TL_BIN:?}/stat" "${TL_BIN:?}/uname"; hash -r

# ---- guard fallback ---------------------------------------------------------
ec_stage_hooks "$TL_TMP/noguard" nofollow-guard.sh
reset
run_tc "$TL_TMP/noguard/hooks/timeout-check.sh"
assert_eq "fallback guard: counter written" "1" "$(cat "$SD/call-count")"
rm -f "${SD:?}/call-count"
ln -s "$TL_TMP/target" "$SD/call-count"
run_tc "$TL_TMP/noguard/hooks/timeout-check.sh"
assert_file_absent "fallback guard refuses the symlinked counter" "$TL_TMP/target"
rm -f "${SD:?}/call-count"

tl_results
