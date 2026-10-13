#!/usr/bin/env bash
# start-minimax-openai-proxy.sh — background MiniMax OpenAI proxy for Alumnium.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROXY="${REPO_ROOT}/scripts/minimax-openai-proxy.mjs"
PORT="${MINIMAX_OPENAI_PROXY_PORT:-18721}"
PID_FILE="${MINIMAX_OPENAI_PROXY_PID_FILE:-/tmp/minimax-openai-proxy.pid}"
LOG_FILE="${MINIMAX_OPENAI_PROXY_LOG:-/tmp/minimax-openai-proxy.log}"

if [[ -f "${PID_FILE}" ]]; then
  old_pid="$(cat "${PID_FILE}")"
  if kill -0 "${old_pid}" 2>/dev/null; then
    echo "Proxy already running (pid ${old_pid}) on http://127.0.0.1:${PORT}/v1"
    exit 0
  fi
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
