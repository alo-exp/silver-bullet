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

# Run a command in a new session when possible; otherwise nohup or plain background.
# Usage: sb_run_detached [--log FILE] -- command [args...]
sb_run_detached() {
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
    if sb_detach_has_setsid; then
      setsid "$@" &
    else
      nohup "$@" >/dev/null 2>&1 &
    fi
  fi
  local pid=$!
  disown "$pid" 2>/dev/null || true
  printf '%s\n' "$pid"
}
