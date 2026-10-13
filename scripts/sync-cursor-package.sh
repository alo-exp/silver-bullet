#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"
ROOT_MANIFEST="${REPO_ROOT}/.cursor-plugin/plugin.json"

# Same hazard as sync-codex-package.sh: this prunes under plugins/silver-bullet
# before repopulating with rsync, so a missing rsync would leave the mirror
# short. Fail before anything is removed.
for _req in rsync python3; do
  if ! command -v "$_req" >/dev/null 2>&1; then
    printf 'ERROR: %s is required by sync-cursor-package.sh but is not in PATH.\n' "$_req" >&2
    exit 1
  fi
done
unset _req

log() {
  printf '[cursor-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.cursor-plugin"

if [[ ! -f "$ROOT_MANIFEST" ]]; then
  printf 'ERROR: missing Cursor plugin manifest at %s\n' "$ROOT_MANIFEST" >&2
  exit 1
fi

plugin_version="$(jq -r '.version' "$ROOT_MANIFEST")"

# Do not ship agents/cursor in the Cursor plugin package — cursor-agent TUI
# auto-discovers agents/<host>/*/SKILL.md for the / picker even without
# plugin.json skills. Internal workflows resolve from skill-source/ instead.
rm -rf "${DEST_DIR}/agents/cursor" "${DEST_DIR}/agents"

if [[ -d "${REPO_ROOT}/plugins/silver-bullet/commands" ]]; then
  mkdir -p "${DEST_DIR}/commands"
  rsync -a --delete "${REPO_ROOT}/plugins/silver-bullet/commands/" "${DEST_DIR}/commands/"
fi

python3 "${REPO_ROOT}/scripts/generate-cursor-hooks.py" >/dev/null
install -m 644 "${REPO_ROOT}/hooks/cursor-hooks.json" "${DEST_DIR}/cursor-hooks.json"

tmp="$(mktemp)"
if [[ -d "${DEST_DIR}/commands" ]]; then
  jq --arg v "$plugin_version" '
    .version = $v
    | .hooks = "./cursor-hooks.json"
    | .commands = "./commands"
    | del(.skills)
  ' "$ROOT_MANIFEST" > "$tmp"
else
  jq --arg v "$plugin_version" '
    .version = $v
    | .hooks = "./cursor-hooks.json"
    | del(.commands, .skills)
  ' "$ROOT_MANIFEST" > "$tmp"
fi
mv "$tmp" "$DEST_DIR/.cursor-plugin/plugin.json"

log "Cursor package manifest synchronized to ${DEST_DIR}"
