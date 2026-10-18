#!/usr/bin/env bash
# site/serve.sh (start|stop|restart|status) against fakes: lsof, curl, launchctl, ps and
# sleep are stubs, `kill` is an exported shell function backed by a state file, and the
# daemon is a stub that only records a listener. No port is bound, no real process is
# signalled, and nothing keeps running after the test.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# serve.sh locates its pid/log files and daemon next to itself: run a copy in <tmp>/site.
SITE="$TL_TMP/site"
S="$TL_TMP/state"
mkdir -p "$SITE" "$S"
cp "$TL_REPO_ROOT/site/serve.sh" "$SITE/serve.sh"
SERVE="$SITE/serve.sh"
PID_FILE="$SITE/.preview-server.pid"
LOG_FILE="$SITE/.preview-server.log"
HOME_PLIST="$HOME/Library/LaunchAgents/com.alolabs.silver-bullet-site-preview.plist"

# Fake daemon: "starts listening" (pid 4242) unless DAEMON_FAIL_HOST matches PREVIEW_HOST,
# or DAEMON_NEVER=1.
cat >"$SITE/preview-server-daemon.sh" <<DAEMON
#!/usr/bin/env bash
printf '%s %s\n' "\${PREVIEW_HOST:-}" "\${PREVIEW_PORT:-}" >>"$S/daemon.calls"
[[ "\${DAEMON_NEVER:-0}" == 1 ]] && exit 0
[[ -n "\${DAEMON_FAIL_HOST:-}" && "\${PREVIEW_HOST:-}" == "\$DAEMON_FAIL_HOST" ]] && exit 0
echo 4242 >"$S/listeners"
DAEMON
chmod +x "$SITE/preview-server-daemon.sh"

tl_stub sleep 'exit 0'
# lsof prints $S/listeners and, like the real one, exits 1 when it prints nothing.
# LSOF_FROM_CALL=N hides the listener until the Nth lsof call; LSOF_ONLY_CALL=N shows it on
# the Nth call only (a listener that appears and vanishes between serve.sh's checks).
tl_stub lsof "n=\$(cat '$S/lsof.n' 2>/dev/null || echo 0); n=\$((n+1)); echo \$n >'$S/lsof.n'
if [[ -n \"\${LSOF_FROM_CALL:-}\" && \$n -lt \$LSOF_FROM_CALL ]]; then exit 1; fi
if [[ -n \"\${LSOF_ONLY_CALL:-}\" && \$n -ne \$LSOF_ONLY_CALL ]]; then exit 1; fi
[[ -s '$S/listeners' ]] && { cat '$S/listeners'; exit 0; }
exit 1"
# ps -p <pid> -o pid=,comm= : report the pid as a python3 process.
tl_stub ps "echo \"ps \$*\" >>'$S/ps.calls'; echo \"\$2 python3\""
# curl: CURL_CODE is the HTTP code to print, CURL_FAIL=1 makes it fail, CURL_GARBAGE=1 prints junk.
tl_stub curl "echo \"\$*\" >>'$S/curl.calls'
[[ \"\${CURL_FAIL:-0}\" == 1 ]] && exit 7
[[ \"\${CURL_GARBAGE:-0}\" == 1 ]] && { printf 'oops'; exit 0; }
printf '%s' \"\${CURL_CODE:-200}\""
# launchctl: print succeeds iff LA_LOADED=1; bootout fails iff LA_BOOTOUT_FAIL=1.
tl_stub launchctl "echo \"\$*\" >>'$S/launchctl.calls'
case \"\$1\" in
  print) [[ \"\${LA_LOADED:-0}\" == 1 ]] ;;
  bootout) [[ \"\${LA_BOOTOUT_FAIL:-0}\" != 1 ]] ;;
  *) exit 0 ;;
esac"

# `kill` function: -0 succeeds for pids listed in $S/alive; a plain/-9 kill removes the pid
# from that list (unless STUBBORN=1 for the plain kill) and is logged.
cat >"$TL_TMP/fakekill.sh" <<FAKE
kill() {
  local sig="" pid rc=0
  if [[ "\$1" == -* ]]; then sig="\$1"; shift; fi
  if [[ "\$sig" == "-0" ]]; then
    grep -qx "\$1" "$S/alive" 2>/dev/null
    return
  fi
  for pid in "\$@"; do
    echo "kill \${sig:-TERM} \$pid" >>"$S/kill.calls"
    [[ "\${KILL_FAIL:-0}" == 1 ]] && rc=1
    if [[ "\$sig" == "-9" || "\${STUBBORN:-0}" != 1 ]]; then
      if [[ -f "$S/alive" ]]; then
        grep -vx "\$pid" "$S/alive" >"$S/alive.new" || true
        mv "$S/alive.new" "$S/alive"
      fi
    fi
  done
  return \$rc
}
disown() { [[ "\${DISOWN_FAIL:-0}" != 1 ]]; }
FAKE
cat >"$TL_TMP/run-serve.sh" <<RUN
source "$TL_TMP/fakekill.sh"
export -f kill disown
exec bash "$SERVE" "\$@"
RUN

reset() {
  rm -f "${S:?}"/* "$PID_FILE" "$LOG_FILE"
  rm -rf "${HOME:?}/Library"
}
serve() { tl_run bash "$TL_TMP/run-serve.sh" "$@"; }

# --- usage ---------------------------------------------------------------
reset
serve
assert_eq "no command exits 1" "1" "$TL_STATUS"
assert_contains "no command prints usage" "$TL_ERR" "Usage: $SERVE {start|stop|restart|status}"
serve bogus
assert_eq "unknown command exits 1" "1" "$TL_STATUS"
assert_contains "unknown command prints usage" "$TL_ERR" "{start|stop|restart|status}"

# --- status: stopped -----------------------------------------------------
reset
serve status
assert_eq "status exits 0 when stopped" "0" "$TL_STATUS"
assert_contains "launchagent not loaded" "$TL_OUT" "launchagent: not loaded (run site/install-preview-launchagent.sh for persistence)"
assert_contains "reports stopped" "$TL_OUT" "stopped"
assert_contains "curl check root" "$TL_OUT" "HTTP GET / : 200"
assert_contains "curl check help page" "$TL_OUT" "HTTP GET /help/getting-started/ : 200"
assert_contains "curl hits the preview host and port" "$(cat "$S/curl.calls")" "http://127.0.0.1:8765/help/getting-started/"

# curl failing or printing junk reads as 000.
CURL_FAIL=1 serve status
assert_contains "failing curl reports 000" "$TL_OUT" "HTTP GET / : 000"
CURL_GARBAGE=1 serve status
assert_contains "non-numeric curl output reports 000" "$TL_OUT" "HTTP GET /help/getting-started/ : 000"

# --- status: launchagent loaded, running via pid file, stale pid cleanup ---
reset
echo 777 >"$PID_FILE"; echo 777 >"$S/alive"
LA_LOADED=1 serve status
assert_contains "launchagent loaded" "$TL_OUT" "launchagent: loaded (com.alolabs.silver-bullet-site-preview)"
assert_contains "running via live pid file" "$TL_OUT" "running (pid 777, http://127.0.0.1:8765/)"
assert_contains "open hint" "$TL_OUT" "Open in browser: open http://127.0.0.1:8765/"
assert_file_exists "live pid file kept" "$PID_FILE"

echo 888 >"$PID_FILE"      # not in the alive list
serve status
assert_file_absent "stale pid file removed by status" "$PID_FILE"
assert_contains "stale pid means stopped" "$TL_OUT" "stopped"

: >"$PID_FILE"             # empty pid file
serve status
assert_file_absent "empty pid file removed by status" "$PID_FILE"

# --- status: running via listener only ------------------------------------
echo 5150 >"$S/listeners"
serve status
assert_contains "listener without pid file counts as running" "$TL_OUT" "running (pid 5150, http://127.0.0.1:8765/)"
printf '5150\n5151\n' >"$S/listeners"
serve status
assert_contains "first listener pid is reported" "$TL_OUT" "running (pid 5150,"

# --- start: already running -------------------------------------------------
reset
echo 5150 >"$S/listeners"
serve start
assert_eq "start while a listener exists exits 1" "1" "$TL_STATUS"
assert_contains "already running message" "$TL_ERR" "Preview server already running (pid 5150)"
assert_contains "already running shows URL" "$TL_ERR" "Open: http://127.0.0.1:8765/"
assert_file_absent "no daemon started when running" "$S/daemon.calls"

# start with a stale pid file: the stale file is cleaned and the server starts
reset
echo 999 >"$PID_FILE"
serve start
assert_eq "start with stale pid file exits 0" "0" "$TL_STATUS"
assert_eq "stale pid file replaced by the new daemon pid" "1" "$([[ "$(cat "$PID_FILE")" != 999 ]] && echo 1 || echo 0)"

# --- start: success -----------------------------------------------------------
reset
CURL_CODE=200 serve start
assert_eq "start exits 0" "0" "$TL_STATUS"
assert_contains "start announces the server" "$TL_OUT" "Started preview server (pid 4242, http://127.0.0.1:8765/)"
assert_contains "start prints open hint" "$TL_OUT" "Open in browser: open http://127.0.0.1:8765/"
assert_not_contains "no warning on HTTP 200" "$TL_ERR" "Warning"
assert_eq "daemon launched once on loopback with the port" "127.0.0.1 8765" "$(cat "$S/daemon.calls")"
assert_file_exists "pid file written" "$PID_FILE"
assert_file_exists "log file created" "$LOG_FILE"

# HTTP code other than 200 warns but still succeeds.
reset
CURL_CODE=500 serve start
assert_eq "start with non-200 still exits 0" "0" "$TL_STATUS"
assert_contains "non-200 warns" "$TL_ERR" "Warning: server listening but GET / returned 500"
reset
CURL_FAIL=1 serve start
assert_contains "curl failure warns with 000" "$TL_ERR" "GET / returned 000"

# --- start: port taken between the checks -----------------------------------
reset
echo 6000 >"$S/listeners"
LSOF_FROM_CALL=2 serve start
assert_eq "foreign listener exits 1" "1" "$TL_STATUS"
assert_contains "foreign listener message" "$TL_ERR" "Port 8765 already in use by another process:"
assert_contains "foreign listener shows the holder" "$TL_ERR" "6000 python3"
assert_contains "foreign listener suggests stop" "$TL_ERR" "$SERVE stop"
assert_file_absent "no daemon started for a foreign listener" "$S/daemon.calls"

# disown failing (job already gone) does not stop the start.
reset
DISOWN_FAIL=1 serve start
assert_eq "failing disown is tolerated" "0" "$TL_STATUS"
assert_contains "start still announced after failing disown" "$TL_OUT" "Started preview server"

# The port holder vanishes before it can be described: still refuses to start.
reset
echo 6000 >"$S/listeners"
LSOF_FROM_CALL=2 LSOF_ONLY_CALL=2 serve start
assert_eq "vanished foreign listener still exits 1" "1" "$TL_STATUS"
assert_contains "vanished foreign listener message" "$TL_ERR" "Port 8765 already in use by another process:"
assert_not_contains "no holder line when it vanished" "$TL_ERR" "python3"

# --- start: loopback bind fails, 0.0.0.0 works --------------------------------
reset
DAEMON_FAIL_HOST=127.0.0.1 serve start
assert_eq "fallback bind exits 0" "0" "$TL_STATUS"
assert_contains "fallback announced" "$TL_ERR" "Bind 127.0.0.1:8765 failed; retrying on 0.0.0.0"
assert_contains "fallback security note" "$TL_ERR" "Note: listening on all interfaces"
assert_eq "daemon tried loopback then all interfaces" "127.0.0.1 8765
0.0.0.0 8765" "$(cat "$S/daemon.calls")"
assert_file_exists "pid file kept after successful fallback" "$PID_FILE"

# --- start: nothing ever listens ---------------------------------------------
reset
DAEMON_NEVER=1 serve start
assert_eq "total failure exits 1" "1" "$TL_STATUS"
assert_contains "total failure message" "$TL_ERR" "Failed to start preview server; see $LOG_FILE"
assert_file_absent "pid file removed after failure" "$PID_FILE"

# --- stop -----------------------------------------------------------------------
reset
serve stop
assert_eq "stop when nothing runs exits 0" "0" "$TL_STATUS"
assert_contains "nothing to stop" "$TL_OUT" "Preview server not running"
assert_file_absent "no kill issued" "$S/kill.calls"

# live pid file: terminated, pid file removed
echo 777 >"$PID_FILE"; echo 777 >"$S/alive"
serve stop
assert_contains "stop reports stopped" "$TL_OUT" "Stopped preview server"
assert_eq "TERM sent to the pid" "kill TERM 777" "$(cat "$S/kill.calls")"
assert_file_absent "pid file removed by stop" "$PID_FILE"

# stubborn process: TERM ignored, escalates to kill -9
reset
echo 777 >"$PID_FILE"; echo 777 >"$S/alive"
STUBBORN=1 serve stop
assert_eq "TERM then KILL for a stubborn pid" "kill TERM 777
kill -9 777" "$(cat "$S/kill.calls")"
assert_contains "stubborn stop still reports stopped" "$TL_OUT" "Stopped preview server"

# dead pid file: removed, nothing killed, nothing stopped
reset
echo 888 >"$PID_FILE"
serve stop
assert_file_absent "dead pid file removed" "$PID_FILE"
assert_contains "dead pid means not running" "$TL_OUT" "Preview server not running"
assert_file_absent "dead pid is not signalled" "$S/kill.calls"

# listeners on the port are terminated (several pids at once)
reset
printf '5150\n5151\n' >"$S/listeners"
serve stop
assert_contains "listeners announced" "$TL_ERR" "Stopping process(es) on port 8765: 5150"
assert_eq "each listener TERMed" "kill TERM 5150
kill TERM 5151" "$(cat "$S/kill.calls")"
assert_contains "listener stop reports stopped" "$TL_OUT" "Stopped preview server"

# kill failures are ignored: the pid is still reported stopped.
reset
echo 777 >"$PID_FILE"; echo 777 >"$S/alive"
STUBBORN=1 KILL_FAIL=1 serve stop
assert_eq "failing kill of the daemon is tolerated" "0" "$TL_STATUS"
assert_eq "TERM and KILL were both attempted" "kill TERM 777
kill -9 777" "$(cat "$S/kill.calls")"
reset
echo 5150 >"$S/listeners"
KILL_FAIL=1 serve stop
assert_eq "failing kill of listeners is tolerated" "0" "$TL_STATUS"
assert_contains "failing listener kill still reports stopped" "$TL_OUT" "Stopped preview server"

# launchagent: bootout succeeds / fails
reset
LA_LOADED=1 serve stop
assert_contains "bootout called with the plist" "$(cat "$S/launchctl.calls")" "bootout gui/$(id -u) $HOME_PLIST"
assert_contains "successful bootout counts as stopped" "$TL_OUT" "Stopped preview server"
reset
LA_LOADED=1 LA_BOOTOUT_FAIL=1 serve stop
assert_contains "failed bootout alone is not a stop" "$TL_OUT" "Preview server not running"

# --- restart ----------------------------------------------------------------------
reset
echo 777 >"$PID_FILE"; echo 777 >"$S/alive"
serve restart
assert_eq "restart exits 0" "0" "$TL_STATUS"
assert_contains "restart stops first" "$TL_OUT" "Stopped preview server"
assert_contains "restart then starts" "$TL_OUT" "Started preview server"
assert_eq "restart launched exactly one daemon" "127.0.0.1 8765" "$(cat "$S/daemon.calls")"

tl_results
