#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="$(jq -r '.version // "0.0.0"' "${REPO_ROOT}/package.json" 2>/dev/null || echo 0.0.0)"
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
DEST_ROOT="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${VERSION}"
MERGE_HOOKS="${REPO_ROOT}/skills/silver-init/scripts/merge-cursor-hooks.py"

usage() {
  cat <<'USAGE'
Usage: scripts/install-cursor.sh [--merge-hooks-only]

Synchronizes the Silver Bullet plugin tree into the Cursor plugin cache and
merges SB hooks into ~/.cursor/hooks.json.
USAGE
}

MERGE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --merge-hooks-only) MERGE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

sync_plugin_tree() {
  mkdir -p "${DEST_ROOT}"
  rsync -a --delete \
    --exclude '.git' --exclude '.planning' --exclude 'tests' --exclude 'site' --exclude 'forge' \
    "${REPO_ROOT}/hooks/" "${DEST_ROOT}/hooks/"
  rsync -a --delete "${REPO_ROOT}/skills/" "${DEST_ROOT}/skills/"
  rsync -a --delete "${REPO_ROOT}/scripts/" "${DEST_ROOT}/scripts/"
  rsync -a --delete "${REPO_ROOT}/templates/" "${DEST_ROOT}/templates/"
  if [[ -d "${REPO_ROOT}/agents/cursor" ]]; then
    rsync -a --delete "${REPO_ROOT}/agents/cursor/" "${DEST_ROOT}/agents/cursor/"
  fi
  python3 "${REPO_ROOT}/hooks/generate-cursor-hooks.py"
  cp "${REPO_ROOT}/hooks/cursor-hooks.json" "${DEST_ROOT}/hooks/cursor-hooks.json"
}

[[ "$MERGE_ONLY" -eq 0 ]] && sync_plugin_tree
python3 "$MERGE_HOOKS" "$DEST_ROOT"
ln -sfn "$DEST_ROOT" "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"
printf 'Silver Bullet Cursor plugin synced to %s\n' "$DEST_ROOT"
