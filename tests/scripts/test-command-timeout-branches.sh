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
# a command that finishes early must not leave the caller (e.g. inside $(...)) waiting for the watchdog's sleep
start=$SECONDS
run_to "$PATH_NO_PY" 20 lbl -- true
assert_eq "watchdog: quick command returns promptly" yes "$([[ $((SECONDS - start)) -lt 5 ]] && echo yes || echo no)"
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
run_to "$PATH_NO_PY" 1 lbl -- true
assert_eq "watchdog: fast command rc 0" 0 "$RC"; assert_eq "watchdog: no error output" "" "$ERR"

tl_results
