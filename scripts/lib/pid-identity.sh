#!/usr/bin/env bash
# Process identity records for the enterprise matrix harness (R14-10).
#
# A bare pid in a pid file is not an identity: the number can be reused after the process exits, and
# a pattern match on command lines finds other checkouts' and other operators' processes. The
# process that STARTS a harness process records "<pid>|<pgid>|<start time>" in "<pidfile>.id"
# (mode 0600). A signal may only go to a pid whose live start time and process group still equal
# that record; anything else (a missing record, a reused pid, a foreign process) is not ours.

sb_pid_start_token() {
  ps -p "$1" -o lstart= 2>/dev/null | sed 's/^ *//; s/ *$//'
}

sb_pid_group() {
  ps -p "$1" -o pgid= 2>/dev/null | tr -d '[:space:]'
}

# sb_pid_identity_write <pidfile> <pid>: record the identity of a process this run started.
sb_pid_identity_write() {
  local file="$1" pid="$2" token group
  token="$(sb_pid_start_token "$pid")"
  group="$(sb_pid_group "$pid")"
  [[ -n "$token" && -n "$group" ]] || return 1
  ( umask 077; printf '%s|%s|%s\n' "$pid" "$group" "$token" >"${file}.id" )
}

# sb_pid_identity_verify <pidfile>: prints the pid and succeeds only when the pid file names a live
# process whose start time and process group equal the recorded identity.
sb_pid_identity_verify() {
  local file="$1" pid rec rpid rgroup rtoken
  pid="$(tr -d '[:space:]' <"$file" 2>/dev/null)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  rec="$(cat "${file}.id" 2>/dev/null)"
  IFS='|' read -r rpid rgroup rtoken <<<"$rec"
  [[ "$rpid" == "$pid" && -n "$rtoken" ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ "$(sb_pid_start_token "$pid")" == "$rtoken" ]] || return 1
  [[ "$(sb_pid_group "$pid")" == "$rgroup" ]] || return 1
  printf '%s\n' "$pid"
}
