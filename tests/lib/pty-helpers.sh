# shellcheck shell=bash
# Run a command with a real pseudo-terminal on stdin, for tests of prompts that production
# code only shows to an interactive user. No override exists in production code; the test
# types the answer. Source after tests/lib/testlib.sh and tl_init.
#
# tl_run_pty <reply> <cmd...>: like tl_run, but stdin is a pty; <reply> (backslash escapes,
# "y\n", "\x04" for end of input) is typed once the command prints "[y/N]". Sets TL_STATUS
# (124 when the command hangs and is killed), TL_OUT and TL_ERR.
tl_run_pty() {
  local reply="$1"
  shift
  local out_file="$TL_TMP/.out" err_file="$TL_TMP/.err"
  TL_STATUS=0
  # shellcheck disable=SC2034  # TL_STATUS is read by the sourcing test
  python3 -I -B "$TL_REPO_ROOT/tests/lib/pty-run.py" --reply "$reply" \
    --stdout "$out_file" --stderr "$err_file" -- "$@" || TL_STATUS=$?
  # shellcheck disable=SC2034  # outputs read by the sourcing test
  TL_OUT="$(cat "$out_file")"
  # shellcheck disable=SC2034
  TL_ERR="$(cat "$err_file")"
}
