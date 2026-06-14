#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="$(jq -r '.version // "0.0.0"' "${REPO_ROOT}/package.json" 2>/dev/null || echo 0.0.0)"
PUBLIC_RELEASE_ONLY=0
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
CURSOR_MARKETPLACE_SOURCE="${CURSOR_MARKETPLACE_SOURCE:-https://github.com/alo-labs/alo-labs-cursor-marketplace}"
CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="${CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE:-https://github.com/alo-labs/alo-labs-cursor-marketplace.git}"
CURSOR_MARKETPLACE_NAME="${CURSOR_MARKETPLACE_NAME:-alo-labs-cursor}"
CURSOR_MARKETPLACE_ROOT="${CURSOR_MARKETPLACE_ROOT:-${CURSOR_HOME}/plugins/marketplaces/${CURSOR_MARKETPLACE_NAME}}"
DEST_ROOT="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${VERSION}"
MERGE_HOOKS="${REPO_ROOT}/skills/silver-init/scripts/merge-cursor-hooks.py"
AGENT_RENDERER="${REPO_ROOT}/scripts/render-agent-bundle.py"

usage() {
  cat <<'USAGE'
Usage: scripts/install-cursor.sh [--merge-hooks-only] [--public-release]

Synchronizes the Silver Bullet plugin tree into the Cursor plugin cache and
merges SB hooks into ~/.cursor/hooks.json.

Options:
  --merge-hooks-only  Only merge hooks from the current install path
  --public-release    Refresh from the published Cursor marketplace instead of the local checkout
USAGE
}

marketplace_manifest_path() {
  printf '%s/.cursor-plugin/marketplace.json\n' "$CURSOR_MARKETPLACE_ROOT"
}

ensure_marketplace_checkout() {
  local source="${1:-$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE}"

  if [[ -d "${CURSOR_MARKETPLACE_ROOT}/.git" ]]; then
    git -C "$CURSOR_MARKETPLACE_ROOT" fetch --depth 1 origin main >/dev/null 2>&1 || \
      git -C "$CURSOR_MARKETPLACE_ROOT" fetch --depth 1 origin master >/dev/null 2>&1 || true
    git -C "$CURSOR_MARKETPLACE_ROOT" pull --ff-only >/dev/null 2>&1 || true
    return 0
  fi

  mkdir -p "$(dirname "$CURSOR_MARKETPLACE_ROOT")"
  git clone --depth 1 "$source" "$CURSOR_MARKETPLACE_ROOT" >/dev/null
}

read_marketplace_version() {
  local manifest
  manifest="$(marketplace_manifest_path)"
  [[ -f "$manifest" ]] || {
    printf 'ERROR: Cursor marketplace manifest not found at %s\n' "$manifest" >&2
    exit 1
  }
  jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest"
}

sync_plugin_tree_from_checkout() {
  local source_root="$1"
  local version="$2"
  local dest="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${version}"

  mkdir -p "${dest}"
  rsync -a --delete \
    --exclude '.git' --exclude '.planning' --exclude 'tests' --exclude 'site' --exclude 'forge' \
    "${source_root}/hooks/" "${dest}/hooks/"
  rsync -a --delete "${source_root}/skills/" "${dest}/skills/"
  rsync -a --delete "${source_root}/scripts/" "${dest}/scripts/"
  rsync -a --delete "${source_root}/templates/" "${dest}/templates/"
  if [[ -d "${source_root}/agents/cursor" ]]; then
    rsync -a --delete "${source_root}/agents/cursor/" "${dest}/agents/cursor/"
  fi
  python3 "${source_root}/hooks/generate-cursor-hooks.py" >/dev/null
  install -m 644 "${source_root}/hooks/cursor-hooks.json" "${dest}/hooks/cursor-hooks.json"
  printf '%s\n' "$dest"
}

sync_plugin_tree() {
  mkdir -p "${REPO_ROOT}/agents"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "${REPO_ROOT}/agents/cursor" >/dev/null 2>&1 || true
  sync_plugin_tree_from_checkout "$REPO_ROOT" "$VERSION"
}

sync_plugin_tree_from_public_release() {
  local release_version checkout_dir

  ensure_marketplace_checkout "$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE"
  release_version="$(read_marketplace_version)"
  checkout_dir="$(mktemp -d "${TMPDIR:-/tmp}/sb-cursor-release.XXXXXX")"

  git clone --depth 1 --branch "v${release_version}" \
    https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null 2>&1 || \
    git clone --depth 1 --branch "$release_version" \
      https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null 2>&1 || \
    git clone --depth 1 https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null

  mkdir -p "${checkout_dir}/agents"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${checkout_dir}/skills" \
    --dest-root "${checkout_dir}/agents/cursor" >/dev/null

  VERSION="$release_version"
  DEST_ROOT="$(sync_plugin_tree_from_checkout "$checkout_dir" "$release_version")"
  rm -rf -- "$checkout_dir"
}

MERGE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --merge-hooks-only) MERGE_ONLY=1 ;;
    --public-release) PUBLIC_RELEASE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

if [[ "$MERGE_ONLY" -eq 0 ]]; then
  if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
    sync_plugin_tree_from_public_release
  else
    DEST_ROOT="$(sync_plugin_tree)"
  fi
else
  DEST_ROOT="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"
  if [[ ! -d "$DEST_ROOT" ]]; then
    printf 'ERROR: no installed Cursor plugin at %s; run without --merge-hooks-only first\n' "$DEST_ROOT" >&2
    exit 1
  fi
fi

python3 "$MERGE_HOOKS" "$DEST_ROOT"
ln -sfn "$DEST_ROOT" "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"

printf '\nCursor hook merge complete. SB hooks are in %s/hooks.json.\n' "$CURSOR_HOME"
printf 'If skills do not appear, reload the window or run: bash scripts/install-cursor.sh --merge-hooks-only\n'

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Silver Bullet Cursor plugin refreshed from %s at %s\n' "$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE" "$DEST_ROOT"
else
  printf 'Silver Bullet Cursor plugin synced to %s\n' "$DEST_ROOT"
fi
