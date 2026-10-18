# shellcheck shell=bash
# Helpers for the enterprise E2E monitor/supervisor/watcher script tests (package F-enterprise-4).
# Source after testlib.sh, enterprise-e2e-helpers.sh and tl_init.
#
# SAFETY: the scripts under test call pkill/pgrep/ps and signal PIDs read from files. Nothing here
# ever reaches a host process: pgrep/pkill/ps/sleep/date are PATH stubs that record their argv, and
# `kill` is replaced by a shell function injected through BASH_ENV (it only records; `kill -0`
# answers from a fake alive list). The only real signal is sent by the stub `sleep`, to its own
# parent, and only after checking that the parent's command line names the script under test.

# f4_setup: PATH stubs, kill function and control directory. Sets F4_CALLS, F4_CTL.
f4_setup() {
  export F4_CTL="$TL_TMP/ctl" F4_CALLS="$TL_TMP/calls"
  mkdir -p "$F4_CTL"
  : >"$F4_CALLS"
  # cd fails for the directory named in $F4_CD_FAIL (fault injection for `cd X || exit`).
  # kill: record only; `kill -0 PID` is true when PID is listed in $F4_CTL/alive
  # BASH_ENV is also how the coverage tracer is loaded, so chain to the previous value.
  {
    printf '[[ -z "%s" || ! -f "%s" ]] || source "%s"\n' "${BASH_ENV:-}" "${BASH_ENV:-}" "${BASH_ENV:-}"
    cat <<'EOS'
kill() {
  printf 'kill %s\n' "$*" >>"${F4_CALLS:?}"
  if [[ "${1:-}" == "-0" ]]; then
    grep -qx -- "${2:-}" "${F4_CTL:?}/alive" 2>/dev/null
    return
  fi
  return 0
}
cd() {
  if [[ -n "${F4_CD_FAIL:-}" && "${1:-}" == "$F4_CD_FAIL" ]]; then
    return 1
  fi
  builtin cd "$@"
}
EOS
  } >"$TL_TMP/kill-stub.sh"
  export BASH_ENV="$TL_TMP/kill-stub.sh"
  # pgrep: records argv, prints $F4_CTL/pgrep.<key> when the arguments contain <key>
  tl_stub pgrep 'printf "pgrep %s\n" "$*" >>"$F4_CALLS"
for f in "$F4_CTL"/pgrep.*; do
  [[ -e "$f" ]] || continue
  [[ "$*" == *"${f##*/pgrep.}"* ]] && { cat "$f"; exit 0; }
done
exit 1'
  tl_stub pkill 'printf "pkill %s\n" "$*" >>"$F4_CALLS"; exit 0'
  # ps -p PID -o FIELD=  -> $F4_CTL/ps.PID.FIELD ; missing -> exit 1
  tl_stub ps 'printf "ps %s\n" "$*" >>"$F4_CALLS"
field="${4%=}"
f="$F4_CTL/ps.$2.$field"
[[ -f "$f" ]] || exit 1
cat "$f"'
  # date: -u -> fixed stamp, +%s -> $F4_CTL/now (default 1000000)
  tl_stub date 'if [[ "$*" == *"+%s"* ]]; then cat "$F4_CTL/now" 2>/dev/null || echo 1000000
else echo 2026-01-01T00:00:00Z; fi'
  # sleep: records; on every loop sleep it also advances the fake clock by $F4_NOW_STEP and sources
  # $F4_CTL/on-loop-sleep (arg: call number) if present; when the argument equals $F4_LOOP_SLEEP and this is call number
  # $F4_LOOP_MAX (default 1), SIGTERM the parent -- but only a parent whose command line
  # contains $F4_PARENT_MARK (the script under test).
  tl_stub sleep 'printf "sleep %s\n" "$*" >>"$F4_CALLS"
if [[ -n "${F4_LOOP_SLEEP:-}" && "${1:-}" == "$F4_LOOP_SLEEP" ]]; then
  n=$(( $(cat "$F4_CTL/loop-count" 2>/dev/null || echo 0) + 1 ))
  echo "$n" >"$F4_CTL/loop-count"
  [[ -z "${F4_NOW_STEP:-}" ]] || echo $(( $(cat "$F4_CTL/now" 2>/dev/null || echo 1000000) + F4_NOW_STEP )) >"$F4_CTL/now"
  [[ ! -f "$F4_CTL/on-loop-sleep" ]] || source "$F4_CTL/on-loop-sleep" "$n"
  if (( n >= ${F4_LOOP_MAX:-1} )) && [[ -n "${F4_PARENT_MARK:-}" ]] \
     && tr "\0" " " <"/proc/$PPID/cmdline" | grep -qF -- "$F4_PARENT_MARK"; then
    builtin kill -TERM "$PPID"
  fi
fi
exit 0'
}

# f4_alive PID...: mark PIDs as alive for the fake `kill -0`.
f4_alive() { printf '%s\n' "$@" >>"$F4_CTL/alive"; }

# f4_calls_has PATTERN: success when a recorded call matches the ERE.
f4_calls_has() { grep -qE -- "$1" "$F4_CALLS"; }

# f4_stage ROOT: SB root whose scripts/ is a directory of symlinks to the repo scripts (so
# BASH_SOURCE-derived SB_ROOT is ROOT while coverage follows the symlinks), hooks/lib and
# tests/live/lib linked.
f4_stage() {
  local root="$1"
  e2e_stage_scripts "$root"
  mkdir -p "$root/hooks" "$root/tests/live"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$root/hooks/lib"
  ln -s "$TL_REPO_ROOT/tests/live/lib" "$root/tests/live/lib"
}

# f4_wait_file FILE: bounded wait (max ~5 s) for a file written by a short-lived background stub.
f4_wait_file() {
  local i
  for ((i = 0; i < 50; i++)); do
    [[ -s "$1" ]] && return 0
    /bin/sleep 0.1
  done
  return 1
}

# f4_mon_setup: stage an SB root for monitor-enterprise-e2e-matrix.sh and export its environment.
# Sets R, MON, MLOG, POLL, STATUS, BPID, MPID, LEDGER, STATE, APP. The batch runner is a stub that
# appends its argv/environment to $F4_CTL/batch-ran. Requires f4_setup first. Failure injection:
#   F4_NO_LOGBYTES=1  removes enterprise_e2e_matrix_log_bytes (fallback path in log_bytes)
f4_mon_setup() {
  R="$TL_TMP/root"
  f4_stage "$R"
  MON="$R/scripts/monitor-enterprise-e2e-matrix.sh"
  MLOG="$TL_TMP/matrix.log"
  POLL="$TL_TMP/poll.log"
  STATUS="$TL_TMP/status.txt"
  BPID="$TL_TMP/batch.pid"
  MPID="$TL_TMP/monitor.pid"
  LEDGER="$TL_TMP/ledger.md"
  APP="$TL_TMP/app"
  STATE="$R/.e2e-matrix-monitor-state"
  mkdir -p "$APP"
  e2e_stage_override "$R" scripts/run-enterprise-e2e-matrix.sh \
    'printf "rows=[%s] pwd=%s host=%s ledger=%s lock=%s pidfile=%s force=%s skipexp=%s clean=%s log=%s fixture=%s dry=%s strategy=%s\n" "$*" "$PWD" "$SB_E2E_LIVE_RUNTIME" "${SB_E2E_LEDGER_FILE-unset}" "${SB_E2E_LIVE_TEST_LOCK_FILE-unset}" "${SB_E2E_MATRIX_BATCH_PID_FILE-unset}" "$SB_E2E_MATRIX_FORCE" "$SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT" "$SB_E2E_MATRIX_CLEAN_ENV" "$SB_E2E_MATRIX_LOG" "$SB_TEST_ENTERPRISE_APP_ROOT" "${SB_E2E_MATRIX_DRY_RUN-unset}" "$CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY" >>"$F4_CTL/batch-ran"'
  rm -f "$R/scripts/lib/enterprise-e2e-live-common.sh"
  cat >"$R/scripts/lib/enterprise-e2e-live-common.sh" <<EOS
source "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-live-common.sh"
[[ -z "\${F4_NO_LOGBYTES:-}" ]] || unset -f enterprise_e2e_matrix_log_bytes
EOS
  export F4_LOOP_SLEEP=4242 F4_PARENT_MARK=monitor-enterprise-e2e-matrix.sh
  export SB_E2E_MATRIX_MONITOR_INTERVAL=4242 SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=7
  export SB_E2E_MATRIX_NETWORK_WAIT_MIN=11 SB_E2E_MATRIX_NETWORK_WAIT_MAX=11
  export SB_E2E_MATRIX_LOG="$MLOG" SB_E2E_MATRIX_BATCH_PID_FILE="$BPID" SB_E2E_MATRIX_MONITOR_PID_FILE="$MPID"
  export SB_E2E_MATRIX_MONITOR_POLL_LOG="$POLL" SB_E2E_MATRIX_MONITOR_STATUS_FILE="$STATUS"
  export SB_E2E_LEDGER_FILE="$LEDGER" SB_TEST_ENTERPRISE_APP_ROOT="$APP" SB_E2E_LIVE_RUNTIME=claude
  export SB_E2E_MATRIX_ROWS="1 5"
  unset SB_E2E_MONITOR_AUTO_RESTART SB_E2E_LIVE_TEST_LOCK_FILE SB_E2E_MATRIX_DRY_RUN F4_NO_LOGBYTES F4_CD_FAIL \
    F4_NOW_STEP F4_LOOP_MAX SB_E2E_MATRIX_STALL_SEC SB_E2E_MATRIX_HUNG_SEC || true
}

# f4_mon_reset: clean per-scenario state.
f4_mon_reset() {
  rm -rf "$MLOG" "$POLL" "$STATUS" "$BPID" "$MPID" "$LEDGER" "$STATE" "$R"/.e2e-row*.log "$F4_CTL"
  mkdir -p "$F4_CTL"
  : >"$F4_CALLS"
  unset F4_LOOP_MAX F4_NOW_STEP F4_NO_LOGBYTES
}

# f4_mon_ledger STATUS: write a 22-row ledger whose rows all carry STATUS (Pass/Fail), valid refs.
f4_mon_ledger() {
  local n specs=()
  for ((n = 1; n <= 22; n++)); do specs+=("$n:$1"); done
  e2e_mk_ledger "$LEDGER" "${specs[@]}"
}

# f4_mon_run [ENV-ARG...]: run the monitor once (the stub sleep ends the loop), result in TL_*.
f4_mon_run() {
  tl_run env "$@" timeout 30 bash "$MON"
}
