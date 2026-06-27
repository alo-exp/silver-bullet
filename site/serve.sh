#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${SITE_DIR}/.preview-server.pid"
LOG_FILE="${SITE_DIR}/.preview-server.log"
DAEMON_SCRIPT="${SITE_DIR}/preview-server-daemon.sh"
PORT=8765
HOST=127.0.0.1
LAUNCH_AGENT_LABEL="com.alolabs.silver-bullet-site-preview"
LAUNCH_AGENT_PLIST="${HOME}/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

listener_pids() {
  lsof -tiTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true
}

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  local pids
  pids="$(listener_pids)"
  if [[ -n "$pids" ]]; then
    return 0
  fi
  return 1
}

running_pid() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  listener_pids | head -1
}

cleanup_stale_pid() {
  if [[ ! -f "$PID_FILE" ]]; then
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE"
  fi
}

launchagent_loaded() {
  launchctl print "gui/$(id -u)/${LAUNCH_AGENT_LABEL}" &>/dev/null
}

port_holder_info() {
  local pids
  pids="$(listener_pids)"
  if [[ -z "$pids" ]]; then
    return 1
  fi
  ps -p "$pids" -o pid=,comm= 2>/dev/null | sed 's/^/  /'
}

curl_check() {
  local path="$1"
  local url="http://${HOST}:${PORT}${path}"
  local code="000"
  if code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null)" && [[ "$code" =~ ^[0-9]+$ ]]; then
    :
  else
    code="000"
  fi
  echo "HTTP GET ${path} : ${code}"
}

wait_for_listen() {
  local i
  for i in $(seq 1 30); do
    if [[ -n "$(listener_pids)" ]]; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

start_python_server() {
  local bind_host="$1"
  cd "$SITE_DIR"
  : >>"$LOG_FILE"
  nohup env PREVIEW_HOST="$bind_host" PREVIEW_PORT="$PORT" "$DAEMON_SCRIPT" >>"$LOG_FILE" 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true
  echo "$pid" >"$PID_FILE"
  if ! wait_for_listen; then
    return 1
  fi
  return 0
}

cmd_start() {
  cleanup_stale_pid
  if is_running; then
    echo "Preview server already running (pid $(running_pid))" >&2
    echo "Open: http://${HOST}:${PORT}/" >&2
    exit 1
  fi
  local foreign
  foreign="$(listener_pids)"
  if [[ -n "$foreign" ]]; then
    echo "Port ${PORT} already in use by another process:" >&2
    port_holder_info >&2 || true
    echo "Stop that process or run: $0 stop" >&2
    exit 1
  fi
  if ! start_python_server "$HOST"; then
    echo "Bind ${HOST}:${PORT} failed; retrying on 0.0.0.0 (local dev only)..." >&2
    rm -f "$PID_FILE"
    if ! start_python_server "0.0.0.0"; then
      echo "Failed to start preview server; see ${LOG_FILE}" >&2
      rm -f "$PID_FILE"
      exit 1
    fi
    HOST="0.0.0.0"
    echo "Note: listening on all interfaces — use only on trusted local networks." >&2
  fi
  sleep 0.2
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000)"
  if [[ "$code" != "200" ]]; then
    echo "Warning: server listening but GET / returned ${code}" >&2
  fi
  echo "Started preview server (pid $(running_pid), http://127.0.0.1:${PORT}/)"
  echo "Open in browser: open http://127.0.0.1:${PORT}/"
}

cmd_stop() {
  local stopped=0
  if launchagent_loaded; then
    launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" 2>/dev/null && stopped=1 || true
  fi
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      local i
      for i in $(seq 1 15); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
      done
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
      stopped=1
    fi
    rm -f "$PID_FILE"
  fi
  local pids
  pids="$(listener_pids)"
  if [[ -n "$pids" ]]; then
    echo "Stopping process(es) on port ${PORT}: ${pids}" >&2
    kill $pids 2>/dev/null || true
    stopped=1
  fi
  if [[ "$stopped" -eq 1 ]]; then
    echo "Stopped preview server"
  else
    echo "Preview server not running"
  fi
}

cmd_status() {
  cleanup_stale_pid
  if launchagent_loaded; then
    echo "launchagent: loaded (${LAUNCH_AGENT_LABEL})"
  else
    echo "launchagent: not loaded (run site/install-preview-launchagent.sh for persistence)"
  fi
  if is_running; then
    echo "running (pid $(running_pid), http://127.0.0.1:${PORT}/)"
    echo "Open in browser: open http://127.0.0.1:${PORT}/"
  else
    echo "stopped"
  fi
  curl_check /
  curl_check /help/getting-started/
}

cmd_restart() {
  cmd_stop
  cmd_start
}

usage() {
  echo "Usage: $0 {start|stop|restart|status}" >&2
  exit 1
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) cmd_status ;;
    *) usage ;;
  esac
}

main "$@"
