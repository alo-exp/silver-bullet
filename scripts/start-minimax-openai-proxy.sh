#!/usr/bin/env bash
# start-minimax-openai-proxy.sh — background MiniMax OpenAI proxy for Alumnium.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROXY="${REPO_ROOT}/scripts/minimax-openai-proxy.mjs"
PORT="${MINIMAX_OPENAI_PROXY_PORT:-18721}"
# PID and log live in a private per-user directory, never at a fixed world-writable /tmp path.
RUN_DIR="${MINIMAX_OPENAI_PROXY_RUN_DIR:-${XDG_RUNTIME_DIR:-${HOME}/.silver-bullet}/minimax-openai-proxy}"
PID_FILE="${MINIMAX_OPENAI_PROXY_PID_FILE:-${RUN_DIR}/proxy.pid}"
LOG_FILE="${MINIMAX_OPENAI_PROXY_LOG:-${RUN_DIR}/proxy.log}"

umask 077
mkdir -p "$(dirname "${PID_FILE}")" "$(dirname "${LOG_FILE}")"
if [[ -L "${PID_FILE}" || -L "${LOG_FILE}" ]]; then
  echo "Refusing to use a symlinked pid or log file: ${PID_FILE} / ${LOG_FILE}" >&2
  exit 1
fi

# A pid counts as our proxy only when that process is a node running this script.
proxy_pid_is_ours() {
  local pid="$1" cmd
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || return 1
  cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$cmd" == *minimax-openai-proxy.mjs* ]]
}

if [[ -f "${PID_FILE}" ]]; then
  old_pid="$(cat "${PID_FILE}")"
  if proxy_pid_is_ours "${old_pid}"; then
    echo "Proxy already running (pid ${old_pid}) on http://127.0.0.1:${PORT}/v1"
    exit 0
  fi
  rm -f -- "${PID_FILE}"
fi

nohup env MINIMAX_OPENAI_PROXY_PORT="${PORT}" node "${PROXY}" >"${LOG_FILE}" 2>&1 &
echo $! >"${PID_FILE}"
sleep 0.3

if ! kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
  echo "Proxy failed to start — see ${LOG_FILE}" >&2
  exit 1
fi

echo "MiniMax proxy: http://127.0.0.1:${PORT}/v1"
echo "Set OPENAI_CUSTOM_URL=http://127.0.0.1:${PORT}/v1 in ~/.config/alumnium/env"
