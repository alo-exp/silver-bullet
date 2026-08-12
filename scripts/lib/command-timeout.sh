#!/usr/bin/env bash
# Portable command timeout for Silver Bullet scripts (macOS-safe).
#
# Prefers GNU `timeout` / Homebrew `gtimeout`, then python3 subprocess+killpg,
# then a background+kill watchdog. Exit 124 on timeout (GNU timeout convention).
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

# sb_run_with_timeout seconds label -- cmd...
sb_run_with_timeout() {
  local seconds="${1:-}"
  local label="${2:-command}"
  local bin rc=0 cmd_pid watchdog_pid
  shift 2 || true
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
      "$@" &
      cmd_pid=$!
      (
        sleep "$seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
          kill -TERM "$cmd_pid" 2>/dev/null || true
          sleep 2
          kill -KILL "$cmd_pid" 2>/dev/null || true
        fi
      ) &
      watchdog_pid=$!
      wait "$cmd_pid" || rc=$?
      kill "$watchdog_pid" 2>/dev/null || true
      wait "$watchdog_pid" 2>/dev/null || true
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
