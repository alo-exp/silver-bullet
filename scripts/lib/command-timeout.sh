#!/usr/bin/env bash
# Portable command timeout for Silver Bullet scripts (macOS-safe).
#
# Prefers GNU `timeout` / Homebrew `gtimeout`, then python3 subprocess+killpg,
# then a background+kill watchdog (the command runs in its own process group, via job
# control, so grandchildren are signalled too). Exit 124 on timeout (GNU timeout convention).
#
# Usage:
#   sb_run_with_timeout <seconds> <label> -- command [args...]
#   sb_timeout_bin   # prints timeout|gtimeout|python3|watchdog

sb_timeout_bin() {
  if command -v timeout >/dev/null 2>&1; then
    printf 'timeout\n'
  elif command -v gtimeout >/dev/null 2>&1; then
    printf 'gtimeout\n'
  elif command -v python3 >/dev/null 2>&1; then
    printf 'python3\n'
  else
    printf 'watchdog\n'
  fi
}

# _sb_timeout_signal <signal> <pid>: signal the command's process group, else the process alone.
_sb_timeout_signal() {
  kill "-$1" -- "-$2" 2>/dev/null || kill "-$1" "$2" 2>/dev/null || true
}

# sb_run_with_timeout seconds label -- cmd...
sb_run_with_timeout() {
  local seconds="${1:-}"
  local label="${2:-command}"
  local bin rc=0 cmd_pid watchdog_pid monitor_was_on=0
  shift "$(( $# < 2 ? $# : 2 ))"
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if [[ -z "$seconds" || ! "$seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "ERROR: sb_run_with_timeout: invalid seconds '${seconds}'" >&2
    return 2
  fi
  if [[ "$#" -lt 1 ]]; then
    echo "ERROR: sb_run_with_timeout: missing command for '${label}'" >&2
    return 2
  fi

  bin="$(sb_timeout_bin)"

  case "$bin" in
    timeout|gtimeout)
      "$bin" --signal=TERM --kill-after=2 "${seconds}s" "$@" || rc=$?
      ;;
    python3)
      python3 - "$seconds" "$@" <<'PY' || rc=$?
import os
import signal
import subprocess
import sys

timeout_sec = float(sys.argv[1])
cmd = sys.argv[2:]
if not cmd:
    sys.exit(2)

try:
    proc = subprocess.Popen(cmd, start_new_session=True)
except FileNotFoundError:
    sys.exit(127)

try:
    rc = proc.wait(timeout=timeout_sec)
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
    sys.exit(124)

sys.exit(rc if rc is not None else 1)
PY
      ;;
    *)
      # Background + kill watchdog (no timeout/gtimeout/python3).
      # Job control gives the background command its own process group (pgid == pid).
      if [[ $- == *m* ]]; then
        monitor_was_on=1
      fi
      set -m
      "$@" &
      cmd_pid=$!
      (
        # Run the delay as a child we can kill: killing only this subshell would leave
        # `sleep` holding the caller's stdout (e.g. inside $(...)) until it expires.
        # The trap is installed first so an early TERM (command already finished) is handled.
        # shellcheck disable=SC2064,SC2046
        trap 'kill $(jobs -p) 2>/dev/null; exit 0' TERM
        sleep "$seconds" &
        wait
        if kill -0 "$cmd_pid" 2>/dev/null; then
          _sb_timeout_signal TERM "$cmd_pid"
          sleep 2
          _sb_timeout_signal KILL "$cmd_pid"
        fi
      ) &
      watchdog_pid=$!
      if [[ "$monitor_was_on" -eq 0 ]]; then
        set +m
      fi
      wait "$cmd_pid" || rc=$?
      kill "$watchdog_pid" 2>/dev/null || true
      # Reap the watchdog. Its status is irrelevant, and a bare `wait` here can return 143 (when the
      # TERM lands mid-flight) and abort a caller running under `set -e`; the `if` keeps it errexit-safe.
      if wait "$watchdog_pid" 2>/dev/null; then :; fi
      # SIGTERM=143, SIGKILL=137 → normalize to GNU timeout 124.
      if [[ $rc -eq 143 || $rc -eq 137 ]]; then
        rc=124
      fi
      ;;
  esac

  if [[ $rc -eq 124 ]]; then
    echo "ERROR: timed out after ${seconds}s: ${label}" >&2
  fi
  return "$rc"
}
