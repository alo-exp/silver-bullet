#!/usr/bin/env bash
# install-omniroute-launchagent.sh — macOS LaunchAgent for OmniRoute (127.0.0.1:20128).
#   bash scripts/install-omniroute-launchagent.sh              install (or reinstall) the agent
#   bash scripts/install-omniroute-launchagent.sh --uninstall  stop and remove it
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

if ! [[ "${PORT}" =~ ^[0-9]{1,5}$ ]] || ((PORT < 1 || PORT > 65535)); then
  die "OMNIROUTE_PORT must be a port number (1-65535)"
fi

# xml_escape TEXT: TEXT safe inside a plist <string> (sed, not ${//}: bash 5.2 expands "&" in a replacement).
xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

UID_NUM="$(id -u)"

if [[ "${1:-}" == "--uninstall" ]]; then
  if launchctl print "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1; then
    launchctl bootout "gui/${UID_NUM}" "${PLIST}" >/dev/null 2>&1 || true
  fi
  rm -f -- "${PLIST}"
  echo "OmniRoute LaunchAgent removed: ${PLIST}"
  exit 0
fi

resolve_omniroute() {
  local bin
  bin="$(command -v omniroute 2>/dev/null || true)"
  [[ -n "${bin}" ]] || die "omniroute not found on PATH (npm install -g omniroute)"
  if [[ -L "${bin}" ]]; then
    readlink -f "${bin}" 2>/dev/null || realpath "${bin}" 2>/dev/null || {
      local target
      target="$(readlink "${bin}")"
      if [[ "${target}" = /* ]]; then
        printf '%s\n' "${target}"
      else
        printf '%s\n' "$(cd "$(dirname "${bin}")" && pwd)/${target}"
      fi
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
    <string>$(xml_escape "${NODE_BIN}")</string>
    <string>$(xml_escape "${OMNI_MJS}")</string>
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
  <string>$(xml_escape "${DATA_DIR}")</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$(xml_escape "${LOG_FILE}")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "${LOG_FILE}")</string>
</dict>
</plist>
EOF

# Stop any foreground/daemon instance so launchd owns the port.
if command -v omniroute >/dev/null 2>&1; then
  omniroute stop >/dev/null 2>&1 || true
fi
# Stop only an omniroute process listening on our own port - never other processes by name.
for pid in $(lsof -ti ":${PORT}" -sTCP:LISTEN 2>/dev/null || true); do
  if [[ "$(ps -p "${pid}" -o command= 2>/dev/null || true)" == *omniroute* ]]; then
    kill -TERM "${pid}" >/dev/null 2>&1 || true
  fi
done
for _ in $(seq 1 10); do
  if ! lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  die "port ${PORT} still in use after stop (check ~/.omniroute/server.log)"
fi

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

# KeepAlive would restart a broken server forever: take the agent out again.
launchctl bootout "gui/${UID_NUM}" "${PLIST}" >/dev/null 2>&1 || true
die "LaunchAgent loaded but omniroute health did not pass within 30s; it was unloaded again (see ${LOG_FILE}; plist kept at ${PLIST})"
