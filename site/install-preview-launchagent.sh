#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SITE_DIR}/.." && pwd)"
TEMPLATE="${SITE_DIR}/com.alolabs.silver-bullet-site-preview.plist"
LABEL="com.alolabs.silver-bullet-site-preview"
DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOMAIN="gui/$(id -u)"
JOB="${DOMAIN}/${LABEL}"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"
# shellcheck disable=SC2016
sed "s|__REPO_ROOT__|${REPO_ROOT}|g" "$TEMPLATE" >"$DEST"

launchctl bootout "$DOMAIN" "$DEST" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$DEST"
launchctl kickstart -k "$JOB"

sleep 0.5
if ! lsof -iTCP:8765 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "LaunchAgent loaded but port 8765 not listening yet; check ${SITE_DIR}/.preview-server.log" >&2
  exit 1
fi

echo "Installed and loaded LaunchAgent: $DEST"
echo "Preview URL: http://127.0.0.1:8765/"
echo ""
echo "Reload after reboot or unload:"
echo "  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/${LABEL}.plist"
echo ""
echo "Status: ${REPO_ROOT}/site/serve.sh status"
echo "Unload: launchctl bootout gui/\$(id -u) ~/Library/LaunchAgents/${LABEL}.plist"
