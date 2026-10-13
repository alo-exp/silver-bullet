#!/usr/bin/env bash
# Foreground preview server for launchd (KeepAlive). Local dev only.
set -euo pipefail
SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SITE_DIR"
HOST="${PREVIEW_HOST:-127.0.0.1}"
PORT="${PREVIEW_PORT:-8765}"

find_python3() {
  local c
  for c in \
    "${PYTHON3:-}" \
    "$(command -v python3 2>/dev/null || true)" \
    /opt/homebrew/bin/python3 \
    /usr/local/bin/python3 \
    /usr/bin/python3; do
    [[ -n "$c" && -x "$c" ]] && echo "$c" && return 0
  done
  return 1
}

PY="$(find_python3)" || {
  echo "python3 not found (launchd PATH is minimal; install Python or set PYTHON3)" >&2
  exit 127
}
exec "$PY" -m http.server "$PORT" --bind "$HOST"
