#!/usr/bin/env bash
# Tests for scripts/start-minimax-openai-proxy.sh (node is stubbed, no real ports).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/start-minimax-openai-proxy.sh"
export MINIMAX_OPENAI_PROXY_PID_FILE="$TL_TMP/run/proxy.pid"
export MINIMAX_OPENAI_PROXY_LOG="$TL_TMP/run/proxy.log"
export MINIMAX_OPENAI_PROXY_PORT=19999

cleanup_pids() {
  local p
  for p in "${PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done
}
PIDS=()
trap 'cleanup_pids; tl_cleanup' EXIT

# The script's `sleep 0.3` is replaced by a stub so timing never depends on machine load.
# With the marker file present the stub instead waits (bounded) until the launched
# process has exited, making the "node died immediately" case deterministic.
REAL_SLEEP="$(command -v sleep)"
tl_stub sleep 'if [[ -f "'"$TL_TMP"'/wait-for-exit" ]]; then
  for _ in $(seq 100); do kill -0 "$(cat "'"$MINIMAX_OPENAI_PROXY_PID_FILE"'")" 2>/dev/null || exit 0; "'"$REAL_SLEEP"'" 0.05; done
fi
exit 0'

# The script backgrounds node and returns at once (its sleep is stubbed), so the stubbed
# node may not have written node.args yet: wait for it, bounded, before reading it.
wait_for_node_args() {
  local _
  for _ in $(seq 200); do [[ -s "$TL_TMP/node.args" ]] && return 0; "$REAL_SLEEP" 0.05; done
  return 1
}

# 1. fresh start: node is launched with the proxy script and the port env.
tl_stub node 'echo "port=$MINIMAX_OPENAI_PROXY_PORT args=$*" >"'"$TL_TMP"'/node.args"; exec bash -c "\"'"$REAL_SLEEP"'\" 60; :" "$@"'
tl_run bash "$SCRIPT"
assert_eq "fresh start exits 0" 0 "$TL_STATUS"
assert_contains "announces url" "$TL_OUT" "MiniMax proxy: http://127.0.0.1:19999/v1"
assert_contains "mentions OPENAI_CUSTOM_URL" "$TL_OUT" "OPENAI_CUSTOM_URL=http://127.0.0.1:19999/v1"
assert_file_exists "pid file written" "$MINIMAX_OPENAI_PROXY_PID_FILE"
PID1="$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"
PIDS+=("$PID1")
wait_for_node_args || true
assert_match "pid is numeric" '^[0-9]+$' "$PID1"
ARGS="$(cat "$TL_TMP/node.args" 2>/dev/null || true)"
assert_contains "node got proxy script path" "$ARGS" "scripts/minimax-openai-proxy.mjs"
assert_contains "node got the port env" "$ARGS" "port=19999"

# 2. already running: reuses pid, does not start a second node.
rm -f "$TL_TMP/node.args"
tl_run bash "$SCRIPT"
assert_eq "already running exits 0" 0 "$TL_STATUS"
assert_contains "reports already running" "$TL_OUT" "Proxy already running (pid $PID1) on http://127.0.0.1:19999/v1"
assert_file_absent "node not started again" "$TL_TMP/node.args"
assert_eq "pid file untouched" "$PID1" "$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"

# 3. stale pid file: a dead pid is replaced by a fresh start.
kill "$PID1" 2>/dev/null || true
# a reaped child of this shell is a guaranteed-dead pid (the killed proxy may linger as a zombie)
true & DEAD=$!
wait "$DEAD"
echo "$DEAD" >"$MINIMAX_OPENAI_PROXY_PID_FILE"
tl_run bash "$SCRIPT"
assert_eq "stale pid restarts" 0 "$TL_STATUS"
PID2="$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"
PIDS+=("$PID2")
assert_contains "restart announces url" "$TL_OUT" "MiniMax proxy: http://127.0.0.1:19999/v1"
wait_for_node_args || true
assert_file_exists "node launched again" "$TL_TMP/node.args"
kill "$PID2" 2>/dev/null || true
wait "$PID2" 2>/dev/null || true

# 4. node dies immediately: failure message names the log, exit 1.
rm -f "$MINIMAX_OPENAI_PROXY_PID_FILE"
touch "$TL_TMP/wait-for-exit"
tl_stub node 'echo "boom" >&2; exit 3'
tl_run bash "$SCRIPT"
assert_eq "failed start exits 1" 1 "$TL_STATUS"
assert_contains "failed start message" "$TL_ERR" "Proxy failed to start — see $MINIMAX_OPENAI_PROXY_LOG"
assert_not_contains "no success banner" "$TL_OUT" "MiniMax proxy:"
assert_contains "node stderr went to log" "$(cat "$MINIMAX_OPENAI_PROXY_LOG")" "boom"

# 5. a live pid that is not our proxy (a reused or planted pid) does not block a start (R6-20)
rm -f "$MINIMAX_OPENAI_PROXY_PID_FILE" "$TL_TMP/wait-for-exit"
"$REAL_SLEEP" 30 &
UNRELATED=$!
PIDS+=("$UNRELATED")
echo "$UNRELATED" >"$MINIMAX_OPENAI_PROXY_PID_FILE"
rm -f "$TL_TMP/node.args"
tl_stub node 'echo started >"'"$TL_TMP"'/node.args"; exec bash -c "\"'"$REAL_SLEEP"'\" 60; :" "$@"'
tl_run bash "$SCRIPT"
assert_eq "an unrelated live pid does not count as the running proxy" 0 "$TL_STATUS"
assert_not_contains "no false 'already running'" "$TL_OUT" "already running"
PID5="$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"
PIDS+=("$PID5")
assert_eq "a new pid replaced the unrelated one" "yes" "$([[ "$PID5" != "$UNRELATED" ]] && echo yes || echo no)"
assert_eq "the unrelated process was left alone" "yes" "$(kill -0 "$UNRELATED" 2>/dev/null && echo yes || echo no)"
kill "$PID5" 2>/dev/null || true

# 5b. ps failing for a live pid: it is not our proxy, the start goes ahead
echo "$UNRELATED" >"$MINIMAX_OPENAI_PROXY_PID_FILE"
tl_stub ps 'exit 1'
rm -f "$TL_TMP/node.args"
tl_run bash "$SCRIPT"
assert_eq "ps failing: the pid is not treated as the proxy" 0 "$TL_STATUS"
assert_not_contains "ps failing: no false 'already running'" "$TL_OUT" "already running"
PID5B="$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"
PIDS+=("$PID5B")
kill "$PID5B" 2>/dev/null || true
rm -f "$TL_BIN/ps"
kill "$UNRELATED" 2>/dev/null || true

# 6. pid and log live in a private directory, never through a planted symlink
assert_eq "the run directory is private" "700" "$(stat -c %a "$TL_TMP/run" 2>/dev/null || stat -f %Lp "$TL_TMP/run")"
VICTIM="$TL_TMP/victim"
echo precious >"$VICTIM"
rm -f "$MINIMAX_OPENAI_PROXY_LOG"
ln -s "$VICTIM" "$MINIMAX_OPENAI_PROXY_LOG"
tl_run bash "$SCRIPT"
assert_eq "a symlinked log is refused" 1 "$TL_STATUS"
assert_contains "refusal names the symlink" "$TL_ERR" "symlinked pid or log file"
assert_eq "the symlink target is untouched" "precious" "$(cat "$VICTIM")"
rm -f "$MINIMAX_OPENAI_PROXY_LOG"

# 7. the default pid/log location is the per-user run directory, not /tmp
unset MINIMAX_OPENAI_PROXY_PID_FILE MINIMAX_OPENAI_PROXY_LOG
tl_stub node 'exit 3'
tl_stub sleep 'for _ in $(seq 100); do kill -0 "$(cat "'"$TL_TMP"'/xdg/minimax-openai-proxy/proxy.pid")" 2>/dev/null || exit 0; "'"$REAL_SLEEP"'" 0.05; done; exit 0'
tl_run env XDG_RUNTIME_DIR="$TL_TMP/xdg" bash "$SCRIPT"
assert_contains "the default log is under the runtime dir" "$TL_ERR" "$TL_TMP/xdg/minimax-openai-proxy/proxy.log"

tl_results
