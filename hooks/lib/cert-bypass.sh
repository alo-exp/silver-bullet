# shellcheck shell=bash
# Agent-host cert runs — skip substantive tool gates so delegate workers can land README edits.
# Accepted values: SB_AGENT_CERT_RUN=1 or SB_AGENT_CERT_RUN=true (anything else, including 0, false, yes and
# empty, is NOT a cert run). Set SB_AGENT_CERT_RUN=1 in run-cert-cell.sh / agent-*-delegate.sh before Claude --print.
#
# The switch is honoured only inside a throw-away sandbox (R4-01, R1-36). HOME, the host runtime home and the
# runtime state directory must ALL live under a FIXED system temp root (/tmp, /var/tmp, /var/folders and their
# /private forms) and none may be under the user's passwd home. $TMPDIR is not a root (the agent chooses it), and
# SB_RUNTIME_PRESERVE_STATE_DIR / SB_RUNTIME_STATE_DIR alone cannot turn it on: a child started with the real HOME
# keeps its real HOME, so the switch stays off. The test runner (tests/run-all-tests.sh) and cert cells give each
# run a HOME under /tmp. Residual: a child with HOME pointed at /tmp has none of the user's auth, plugins or
# git credentials, which is what the bypass protects.

# _sb_passwd_home: the account's home from the passwd database (getent, else python3), empty when unknown.
_sb_passwd_home() {
  local home_dir=""
  if command -v getent >/dev/null 2>&1; then
    home_dir="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)"
  elif command -v python3 >/dev/null 2>&1; then
    home_dir="$(python3 -c 'import os,pwd;print(pwd.getpwuid(os.getuid()).pw_dir)' 2>/dev/null)"
  fi
  printf '%s' "$home_dir"
}

# _sb_path_in_temp_root PATH HOME_DIR: PATH is absolute, climbs nowhere, is not under the passwd home and is under a
# fixed temp root (by its literal or real path).
_sb_path_in_temp_root() {
  local path="$1" home_dir="$2" real root canon
  local roots="/tmp /var/tmp /private/tmp /var/folders /private/var/folders"
  [[ "$path" == /* && "$path" != *"/../"* && "$path" != */.. ]] || return 1
  real="$(cd "$path" 2>/dev/null && pwd -P)" || real="$path"
  for root in /tmp /var/tmp /var/folders; do
    canon="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    roots="$roots $canon"
  done
  case "$real" in
    "$home_dir" | "$home_dir"/*) [[ -z "$home_dir" || "$home_dir" == / ]] || return 1 ;;
  esac
  for root in $roots; do
    case "$real" in
      "$root"/*) return 0 ;;
    esac
  done
  return 1
}

# sb_runtime_in_test_sandbox: HOME, the runtime home root and the runtime state directory are all under a fixed temp root.
sb_runtime_in_test_sandbox() {
  local home_dir
  home_dir="$(_sb_passwd_home)"
  _sb_path_in_temp_root "${SB_RUNTIME_STATE_DIR:-}" "$home_dir" || return 1
  _sb_path_in_temp_root "${HOME:-}" "$home_dir" || return 1
  [[ -z "${SB_RUNTIME_HOME_ROOT:-}" ]] || _sb_path_in_temp_root "$SB_RUNTIME_HOME_ROOT" "$home_dir" || return 1
  return 0
}

sb_cert_run_bypass_active() {
  [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]] || return 1
  sb_runtime_in_test_sandbox
}

sb_cert_run_bypass() {
  if sb_cert_run_bypass_active; then
    exit 0
  fi
}
