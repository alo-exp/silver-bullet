#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"
ROOT_MANIFEST="${REPO_ROOT}/.cursor-plugin/plugin.json"

log() {
  printf '[cursor-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.cursor-plugin"

if [[ ! -f "$ROOT_MANIFEST" ]]; then
  printf 'ERROR: missing Cursor plugin manifest at %s\n' "$ROOT_MANIFEST" >&2
  exit 1
fi

plugin_version="$(jq -r '.version' "$ROOT_MANIFEST")"
tmp="$(mktemp)"
jq --arg v "$plugin_version" '
  .version = $v
  | .skills = "./agents/cursor"
  | .hooks = "./cursor-hooks.json"
' "$ROOT_MANIFEST" > "$tmp"
mv "$tmp" "$DEST_DIR/.cursor-plugin/plugin.json"

cursor_bundle="$(sb_agent_bundle_root "$REPO_ROOT" cursor)"
mkdir -p "${DEST_DIR}/agents/cursor"
rsync -a --delete "${cursor_bundle}/" "${DEST_DIR}/agents/cursor/"

python3 "${REPO_ROOT}/hooks/generate-cursor-hooks.py" >/dev/null
install -m 644 "${REPO_ROOT}/hooks/cursor-hooks.json" "${DEST_DIR}/cursor-hooks.json"

log "Cursor package manifest synchronized to ${DEST_DIR}"
