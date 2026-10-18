#!/usr/bin/env bash
# scripts/lib/command-timeout.sh: argument validation and all four implementations
# (timeout, gtimeout, python3, watchdog), selected by controlling PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

REAL_PY="$(command -v python3)"
REAL_SLEEP="$(command -v sleep)"

# `sleep 2` (hard-coded kill-after delays) is shortened so no test waits two seconds.
tl_stub sleep "if [[ \"\${1:-}\" == 2 ]]; then exec \"$REAL_SLEEP\" 0.2; fi; exec \"$REAL_SLEEP\" \"\$@\""
# python3 shim: shortens the embedded 2 s SIGTERM->SIGKILL grace period and can inject
# a vanished-process race into os.killpg via sitecustomize (SB_TEST_KILLPG_RAISE=<signal name>).
tl_stub python3 "sed 's/proc.wait(timeout=2)/proc.wait(timeout=0.2)/' | exec \"$REAL_PY\" \"\$@\""
mkdir -p "$TL_TMP/pyinject"
cat >"$TL_TMP/pyinject/sitecustomize.py" <<'PY'
import os, signal
_real = os.killpg
_name = os.environ.get("SB_TEST_KILLPG_RAISE")
def _killpg(pgid, sig):
    _real(pgid, sig)
    if _name and sig == getattr(signal, _name):
        raise ProcessLookupError()
if _name:
    os.killpg = _killpg
PY
export PYTHONPATH="$TL_TMP/pyinject"

# shellcheck source=../../scripts/lib/command-timeout.sh
source "$TL_REPO_ROOT/scripts/lib/command-timeout.sh"

# Minimal PATH directories (symlinks to just the tools the cases need); building a full
# tl_path_without copy of PATH takes seconds per variant. python3/sleep resolve to the shims above.
mkpath() { # name tool...
  local d="$TL_TMP/path-$1" t; shift
  mkdir -p "$d"
  for t in "$@"; do ln -sf "$(type -P "$t")" "$d/$t"; done
  printf '%s' "$d"
}
tl_stub gtimeout 'echo "GT $*"; shift 3; exec "$@"'
hash -r
PATH_GT="$(mkpath gt gtimeout bash env sleep true echo)"
PATH_NO_GNU="$(mkpath nognu bash env sleep true sed python3)"
PATH_NO_PY="$(mkpath nopy bash env sleep true)"

# --- sb_timeout_bin ---------------------------------------------------------
assert_eq "bin: timeout preferred" timeout "$(sb_timeout_bin)"
assert_eq "bin: gtimeout" gtimeout "$(PATH="$PATH_GT" sb_timeout_bin)"
assert_eq "bin: python3" python3 "$(PATH="$PATH_NO_GNU" sb_timeout_bin)"
assert_eq "bin: watchdog" watchdog "$(PATH="$PATH_NO_PY" sb_timeout_bin)"

# runner: sets RC/ERR/OUT for sb_run_with_timeout invoked with optional PATH override
run_to() { # <PATH> args...
  local p="$1"; shift
  RC=0
  OUT="$(PATH="$p" sb_run_with_timeout "$@" 2>"$TL_TMP/err")" || RC=$?
  ERR="$(cat "$TL_TMP/err")"
}

# --- argument validation ------------------------------------------------------
run_to "$PATH" "" lbl -- true
assert_eq "empty seconds rc" 2 "$RC"; assert_contains "empty seconds msg" "$ERR" "invalid seconds ''"
run_to "$PATH" abc lbl -- true
assert_eq "non-numeric rc" 2 "$RC"; assert_contains "non-numeric msg" "$ERR" "invalid seconds 'abc'"
run_to "$PATH" 1.2.3 lbl -- true
assert_eq "malformed decimal rc" 2 "$RC"
run_to "$PATH" 5 lbl --
assert_eq "no command rc" 2 "$RC"; assert_contains "no command msg" "$ERR" "missing command for 'lbl'"
run_to "$PATH" 5 onlylabel
assert_eq "label but no command rc" 2 "$RC"; assert_contains "label named in message" "$ERR" "missing command for 'onlylabel'"
# Only seconds given: no command to run (an executable literally named "5" must not be executed).
tl_stub 5 "touch \"$TL_TMP/five-ran\""; hash -r
run_to "$PATH" 5
assert_eq "seconds only -> rc 2" 2 "$RC"
assert_contains "seconds only -> missing command message" "$ERR" "missing command"
assert_file_absent "seconds only -> '5' not executed" "$TL_TMP/five-ran"
rm -f "$TL_BIN/5"; hash -r
RC=0; sb_run_with_timeout 2>"$TL_TMP/err" || RC=$?
assert_eq "no args rc" 2 "$RC"

# --- GNU timeout branch -------------------------------------------------------
run_to "$PATH" 5 lbl -- bash -c 'echo hi; exit 7'
assert_eq "timeout: propagates exit code" 7 "$RC"; assert_eq "timeout: output" hi "$OUT"
run_to "$PATH" 5 lbl bash -c 'echo nodash'
assert_eq "timeout: works without -- separator" nodash "$OUT"
run_to "$PATH" 0.15 slowcmd -- sleep 3
assert_eq "timeout: expiry rc 124" 124 "$RC"
assert_contains "timeout: expiry message" "$ERR" "timed out after 0.15s: slowcmd"

# --- gtimeout branch (stub records the arguments it was given) ----------------
run_to "$PATH_GT" 4 lbl -- echo go
assert_eq "gtimeout: rc" 0 "$RC"
assert_eq "gtimeout: invoked with GNU flags" "GT --signal=TERM --kill-after=2 4s echo go
go" "$OUT"

# --- python3 branch -----------------------------------------------------------
run_to "$PATH_NO_GNU" 5 lbl -- bash -c 'echo py; exit 5'
assert_eq "python3: exit code" 5 "$RC"; assert_eq "python3: output" py "$OUT"
run_to "$PATH_NO_GNU" 5 lbl -- definitely-not-a-command-xyz
assert_eq "python3: missing command -> 127" 127 "$RC"
run_to "$PATH_NO_GNU" 0.15 slowpy -- sleep 3
assert_eq "python3: timeout rc 124" 124 "$RC"
assert_contains "python3: timeout message" "$ERR" "timed out after 0.15s: slowpy"
# TERM ignored -> SIGKILL escalation after the (shortened) grace period
run_to "$PATH_NO_GNU" 0.15 stubborn -- bash -c 'trap "" TERM; while :; do :; done'
assert_eq "python3: SIGKILL escalation rc 124" 124 "$RC"
# process group vanished between timeout and killpg (race): TERM, then KILL
SB_TEST_KILLPG_RAISE=SIGTERM run_to "$PATH_NO_GNU" 0.15 raceterm -- sleep 3
assert_eq "python3: TERM race tolerated" 124 "$RC"
export SB_TEST_KILLPG_RAISE=SIGKILL
run_to "$PATH_NO_GNU" 0.15 racekill -- bash -c 'trap "" TERM; while :; do :; done'
assert_eq "python3: KILL race tolerated" 124 "$RC"
unset SB_TEST_KILLPG_RAISE

# --- watchdog branch ----------------------------------------------------------
run_to "$PATH_NO_PY" 5 lbl -- bash -c 'echo wd; exit 9'
assert_eq "watchdog: exit code" 9 "$RC"; assert_eq "watchdog: output" wd "$OUT"
# Orphan checks look for a leftover `sleep <unique duration>` process (the watchdog's delay or a
# grandchild): promptness is judged by what is left running, not by wall-clock timing.
sleepers() { ps -eo args= | awk -v d="$1" '$NF == d && $0 ~ /sleep/ {n++} END {print n+0}'; }
wait_gone() { for _ in 1 2 3 4 5 6 7 8 9 10; do [[ "$(sleepers "$1")" == 0 ]] && return 0; "$REAL_SLEEP" 0.1; done; return 1; }
reap_sleepers() { ps -eo pid=,args= | awk -v d="$1" '$NF == d && $0 ~ /sleep/ {print $1}' | while read -r p; do kill "$p" 2>/dev/null; done; }
reap_sleepers 21; reap_sleepers 23; reap_sleepers 27
PATH="$PATH_NO_PY" sb_run_with_timeout 21 lbl -- true >/dev/null 2>&1
assert_eq "watchdog: finished command leaves no watchdog sleep behind" yes "$(wait_gone 21 && echo yes || echo no)"
reap_sleepers 21
# the same with a command that runs for a while (output not captured with $(...): an orphaned
# sleep would hold that pipe open and stall the test instead of failing it)
PATH="$PATH_NO_PY" sb_run_with_timeout 23 lbl -- sleep 0.5 >/dev/null 2>&1
assert_eq "watchdog: slow command leaves no watchdog sleep behind" yes "$(wait_gone 23 && echo yes || echo no)"
reap_sleepers 23
# a bare call under a strict (set -euo pipefail) caller must never abort it
tl_run "$BASH" -c 'set -euo pipefail; source "$1"; for ((i = 0; i < 50; i++)); do PATH="$2" sb_run_with_timeout 30 x -- true; done; echo done50' _ "$TL_REPO_ROOT/scripts/lib/command-timeout.sh" "$PATH_NO_PY"
assert_eq "watchdog: 50 bare calls under set -euo pipefail" "done50" "$TL_OUT"
assert_eq "watchdog: strict caller exit status" 0 "$TL_STATUS"
reap_sleepers 30
# grandchildren die with the command on timeout (process group), as with the python3/timeout paths
# (no command substitution here: a surviving grandchild would keep a pipe open and stall the test)
RC=0; PATH="$PATH_NO_PY" sb_run_with_timeout 0.15 grand -- bash -c 'sleep 27 & wait' >/dev/null 2>&1 || RC=$?
assert_eq "watchdog: timeout rc with a backgrounded grandchild" 124 "$RC"
assert_eq "watchdog: grandchild killed with the command" yes "$(wait_gone 27 && echo yes || echo no)"
reap_sleepers 27
# a caller that already has job control enabled keeps it
tl_run "$BASH" -c 'source "$1"; set -m; PATH="$2" sb_run_with_timeout 5 x -- true; case $- in *m*) echo monitor-kept;; *) echo monitor-lost;; esac; set +m; PATH="$2" sb_run_with_timeout 5 x -- true; case $- in *m*) echo monitor-leaked;; *) echo monitor-off;; esac' _ "$TL_REPO_ROOT/scripts/lib/command-timeout.sh" "$PATH_NO_PY"
assert_contains "watchdog: job control left on when the caller had it" "$TL_OUT" "monitor-kept"
assert_contains "watchdog: job control not leaked when the caller had it off" "$TL_OUT" "monitor-off"
reap_sleepers 5
run_to "$PATH_NO_PY" 0.15 slowwd -- sleep 3
assert_eq "watchdog: TERM normalised to 124" 124 "$RC"
assert_contains "watchdog: timeout message" "$ERR" "timed out after 0.15s: slowwd"
run_to "$PATH_NO_PY" 0.15 stubwd -- bash -c 'trap "" TERM; while :; do :; done'
assert_eq "watchdog: KILL normalised to 124" 124 "$RC"
# kill(1) reporting failure (process raced away): the watchdog tolerates it. The shell
# function reports TERM as failed after really delivering it, and leaves the watchdog
# alive so its later KILL hits the already-dead command and fails too.
kill() {
  case "${1:-}" in
    -TERM) builtin kill "$@"; return 1 ;;
    -[A-Z]*|-0) builtin kill "$@" ;;
    *) return 0 ;;
  esac
}
run_to "$PATH_NO_PY" 0.15 racewd -- sleep 3
assert_eq "watchdog: failing kill tolerated, still 124" 124 "$RC"
"$REAL_SLEEP" 0.6   # let the detached watchdog subshell run its final KILL
unset -f kill
# kill(1) failing when asked to stop the watchdog itself (it already went away): tolerated
kill() { case "${1:-}" in -*) builtin kill "$@" ;; *) return 1 ;; esac; }
run_to "$PATH_NO_PY" 0.15 nokillwd -- true
assert_eq "watchdog: failing kill of the watchdog tolerated" 0 "$RC"
"$REAL_SLEEP" 0.3
unset -f kill
run_to "$PATH_NO_PY" 1 lbl -- true
assert_eq "watchdog: fast command rc 0" 0 "$RC"; assert_eq "watchdog: no error output" "" "$ERR"

tl_results
