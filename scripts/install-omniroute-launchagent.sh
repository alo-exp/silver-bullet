#!/usr/bin/env bash
# install-omniroute-launchagent.sh — macOS LaunchAgent for OmniRoute (127.0.0.1:20128).
set -euo pipefail

LABEL="com.omniroute.server"
PORT="${OMNIROUTE_PORT:-20128}"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
PLIST="${LAUNCH_AGENTS}/${LABEL}.plist"
DATA_DIR="${HOME}/.omniroute"
LOG_FILE="${DATA_DIR}/server.log"

die() {
  echo "install-omniroute-launchagent: $*" >&2
  exit 1
}

resolve_omniroute() {
  local bin
  bin="$(command -v omniroute 2>/dev/null || true)"
  [[ -n "${bin}" ]] || die "omniroute not found on PATH (npm install -g omniroute)"
  if [[ -L "${bin}" ]]; then
    readlink -f "${bin}" 2>/dev/null || realpath "${bin}" 2>/dev/null || {
      local target
      target="$(readlink "${bin}")"
      [[ "${target}" = /* ]] && printf '%s\n' "${target}" || printf '%s\n' "$(cd "$(dirname "${bin}")" && pwd)/${target}"
    }
  else
    printf '%s\n' "${bin}"
  fi
}

resolve_node() {
  local node
  node="$(command -v node 2>/dev/null || true)"
  [[ -n "${node}" ]] || die "node not found on PATH"
  printf '%s\n' "${node}"
}

OMNI_MJS="$(resolve_omniroute)"
NODE_BIN="$(resolve_node)"
mkdir -p "${DATA_DIR}" "${LAUNCH_AGENTS}"

cat >"${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_BIN}</string>
    <string>${OMNI_MJS}</string>
    <string>serve</string>
    <string>--port</string>
    <string>${PORT}</string>
    <string>--no-open</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>WorkingDirectory</key>
  <string>${DATA_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

# Stop any foreground/daemon instance so launchd owns the port.
if command -v omniroute >/dev/null 2>&1; then
  omniroute stop >/dev/null 2>&1 || true
fi
pkill -f 'omniroute.*serve' >/dev/null 2>&1 || true
for _ in $(seq 1 10); do
  if ! lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  die "port ${PORT} still in use after stop (check ~/.omniroute/server.log)"
fi

UID_NUM="$(id -u)"
if launchctl print "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/${UID_NUM}" "${PLIST}" >/dev/null 2>&1 || true
fi

launchctl bootstrap "gui/${UID_NUM}" "${PLIST}"
launchctl enable "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/${UID_NUM}/${LABEL}"

deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  if omniroute health >/dev/null 2>&1; then
    echo "OmniRoute LaunchAgent installed: ${PLIST}"
    echo "  label:  ${LABEL}"
    echo "  port:   ${PORT}"
    echo "  logs:   ${LOG_FILE}"
    echo "  verify: launchctl print gui/${UID_NUM}/${LABEL}"
    echo "          omniroute health"
    exit 0
  fi
  sleep 1
done

die "LaunchAgent loaded but omniroute health did not pass within 30s (see ${LOG_FILE})"
