#!/usr/bin/env bash
# Detached background helpers for live / enterprise E2E harness (macOS-safe).
set -euo pipefail

_sb_detach_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prepend harness lib (setsid shim) ahead of PATH for Claude interactive sessions.
sb_prepend_harness_path() {
  local shim_dir="$_sb_detach_lib_dir"
  case ":${PATH}:" in
    *":${shim_dir}:"*) ;;
    *) export PATH="${shim_dir}:${PATH}" ;;
  esac
}

sb_detach_has_setsid() {
  command -v setsid >/dev/null 2>&1
}

sb_detach_has_controlling_tty() {
  [[ -t 0 && -t 1 ]]
}

sb_detach_has_script() {
  command -v script >/dev/null 2>&1
}

# When detached (no controlling TTY), wrap argv with `script -q /dev/null` so
# install-claude.sh and Claude interactive sessions receive a pseudo-TTY.
# macOS nohup drivers otherwise hang waiting on install-claude children.
sb_detach_needs_pty_wrapper() {
  ! sb_detach_has_controlling_tty && sb_detach_has_script
}

_sb_run_detached_inner() {
  local log_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        log_file="${2:?--log requires a path}"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done
  if (($# == 0)); then
    printf 'sb_run_detached: missing command\n' >&2
    return 2
  fi

  sb_prepend_harness_path

  if [[ -n "$log_file" ]]; then
    if sb_detach_has_setsid; then
      setsid "$@" >>"$log_file" 2>&1 &
    else
      nohup "$@" >>"$log_file" 2>&1 &
    fi
  else
    # Always detach stdio: callers often capture PID via $(sb_run_detached …) and
    # inherited PIPE stdout (e.g. monitor/watch) will stall the parent.
    if sb_detach_has_setsid; then
      setsid "$@" >/dev/null 2>&1 &
    else
      nohup "$@" >/dev/null 2>&1 &
    fi
  fi
  local pid=$!
  disown "$pid" 2>/dev/null || true
  printf '%s\n' "$pid"
}

# Run a command in a new session when possible; otherwise nohup or plain background.
# Usage: sb_run_detached [--log FILE] -- command [args...]
sb_run_detached() {
  _sb_run_detached_inner "$@"
}

# Like sb_run_detached but allocates a pseudo-TTY when the caller has none.
# Usage: sb_run_detached_pty [--log FILE] -- command [args...]
sb_run_detached_pty() {
  local log_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        log_file="${2:?--log requires a path}"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done
  if (($# == 0)); then
    printf 'sb_run_detached_pty: missing command\n' >&2
    return 2
  fi

  local -a cmd=("$@")
  if sb_detach_needs_pty_wrapper; then
    cmd=(script -q /dev/null "${cmd[@]}")
  fi

  if [[ -n "$log_file" ]]; then
    _sb_run_detached_inner --log "$log_file" -- "${cmd[@]}"
  else
    _sb_run_detached_inner -- "${cmd[@]}"
  fi
}
