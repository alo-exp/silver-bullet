#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${SITE_DIR}/.preview-server.pid"
LOG_FILE="${SITE_DIR}/.preview-server.log"
PORT=8765
HOST=127.0.0.1

is_running() {
  if [[ ! -f "$PID_FILE" ]]; then
    return 1
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  return 1
}

cleanup_stale_pid() {
  if [[ -f "$PID_FILE" ]] && ! is_running; then
    rm -f "$PID_FILE"
  fi
}

curl_check() {
  local path="$1"
  local url="http://${HOST}:${PORT}${path}"
  local code
  code="$(curl -sf -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo '000')"
  echo "HTTP GET ${path} : ${code}"
}

cmd_start() {
  cleanup_stale_pid
  if is_running; then
    echo "Preview server already running (pid $(cat "$PID_FILE"))" >&2
    exit 1
  fi
  cd "$SITE_DIR"
  nohup python3 -m http.server "$PORT" --bind "$HOST" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 0.3
  if ! is_running; then
    echo "Failed to start preview server; see ${LOG_FILE}" >&2
    rm -f "$PID_FILE"
    exit 1
  fi
  echo "Started preview server (pid $(cat "$PID_FILE"), http://${HOST}:${PORT}/)"
}

cmd_stop() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "Preview server not running (no pid file)"
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    local i
    for i in $(seq 1 15); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
  echo "Stopped preview server"
}

cmd_status() {
  cleanup_stale_pid
  if is_running; then
    echo "running (pid $(cat "$PID_FILE"), http://${HOST}:${PORT}/)"
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
