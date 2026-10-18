#!/usr/bin/env bash
# Tests for scripts/start-minimax-openai-proxy.sh (node is stubbed, no real ports).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/start-minimax-openai-proxy.sh"
export MINIMAX_OPENAI_PROXY_PID_FILE="$TL_TMP/proxy.pid"
export MINIMAX_OPENAI_PROXY_LOG="$TL_TMP/proxy.log"
export MINIMAX_OPENAI_PROXY_PORT=19999

cleanup_pids() {
  local p
  for p in "${PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done
}
PIDS=()
trap 'cleanup_pids; tl_cleanup' EXIT

# 1. fresh start: node is launched with the proxy script and the port env.
tl_stub node 'echo "port=$MINIMAX_OPENAI_PROXY_PORT args=$*" >"'"$TL_TMP"'/node.args"; exec sleep 60'
tl_run bash "$SCRIPT"
assert_eq "fresh start exits 0" 0 "$TL_STATUS"
assert_contains "announces url" "$TL_OUT" "MiniMax proxy: http://127.0.0.1:19999/v1"
assert_contains "mentions OPENAI_CUSTOM_URL" "$TL_OUT" "OPENAI_CUSTOM_URL=http://127.0.0.1:19999/v1"
assert_file_exists "pid file written" "$MINIMAX_OPENAI_PROXY_PID_FILE"
PID1="$(cat "$MINIMAX_OPENAI_PROXY_PID_FILE")"
PIDS+=("$PID1")
assert_match "pid is numeric" '^[0-9]+$' "$PID1"
ARGS="$(cat "$TL_TMP/node.args")"
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
assert_file_exists "node launched again" "$TL_TMP/node.args"
kill "$PID2" 2>/dev/null || true
wait "$PID2" 2>/dev/null || true

# 4. node dies immediately: failure message names the log, exit 1.
rm -f "$MINIMAX_OPENAI_PROXY_PID_FILE"
tl_stub node 'echo "boom" >&2; exit 3'
tl_run bash "$SCRIPT"
assert_eq "failed start exits 1" 1 "$TL_STATUS"
assert_contains "failed start message" "$TL_ERR" "Proxy failed to start — see $MINIMAX_OPENAI_PROXY_LOG"
assert_not_contains "no success banner" "$TL_OUT" "MiniMax proxy:"
assert_contains "node stderr went to log" "$(cat "$MINIMAX_OPENAI_PROXY_LOG")" "boom"

tl_results
