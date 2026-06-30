#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
VERSION="$(jq -r '.version // "0.0.0"' "${REPO_ROOT}/package.json" 2>/dev/null || echo 0.0.0)"
PUBLIC_RELEASE_ONLY=0
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
CURSOR_MARKETPLACE_SOURCE="${CURSOR_MARKETPLACE_SOURCE:-https://github.com/alo-labs/alo-labs-cursor-marketplace}"
CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="${CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE:-https://github.com/alo-labs/alo-labs-cursor-marketplace.git}"
CURSOR_MARKETPLACE_NAME="${CURSOR_MARKETPLACE_NAME:-alo-labs-cursor}"
CURSOR_MARKETPLACE_ROOT="${CURSOR_MARKETPLACE_ROOT:-${CURSOR_HOME}/plugins/marketplaces/${CURSOR_MARKETPLACE_NAME}}"
CURSOR_GITHUB_REPO_SLUG="${CURSOR_GITHUB_REPO_SLUG:-alo-exp/silver-bullet}"
CURSOR_GITHUB_REPO_URL="${CURSOR_GITHUB_REPO_URL:-https://github.com/alo-exp/silver-bullet.git}"
DEST_ROOT="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${VERSION}"
INSTALL_COMMIT_SHA=""
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
  local cursor_bundle
  cursor_bundle="$(sb_agent_bundle_root "$source_root" cursor)"
  if [[ -d "$cursor_bundle" ]]; then
    mkdir -p "${dest}/agents/cursor"
    rsync -a --delete "${cursor_bundle}/" "${dest}/agents/cursor/"
  fi
  python3 "${source_root}/hooks/generate-cursor-hooks.py" >/dev/null
  install -m 644 "${source_root}/hooks/cursor-hooks.json" "${dest}/hooks/cursor-hooks.json"
  install_cursor_plugin_manifest "$dest" "$version" "$source_root"
  printf '%s\n' "$dest"
}

install_cursor_plugin_manifest() {
  local dest="$1"
  local version="$2"
  local source_root="$3"
  local manifest_src="${source_root}/.cursor-plugin/plugin.json"
  local tmp

  mkdir -p "${dest}/.cursor-plugin"
  [[ -f "$manifest_src" ]] || manifest_src="${REPO_ROOT}/.cursor-plugin/plugin.json"
  [[ -f "$manifest_src" ]] || {
    printf 'ERROR: missing Cursor plugin manifest at %s\n' "$manifest_src" >&2
    exit 1
  }

  tmp="$(mktemp)"
  jq --arg v "$version" '
    .version = $v
    | .skills = "./agents/cursor"
    | .hooks = "./cursor-hooks.json"
  ' "$manifest_src" > "$tmp"
  install -m 644 "$tmp" "${dest}/.cursor-plugin/plugin.json"
  rm -f -- "$tmp"
  install -m 644 "${dest}/hooks/cursor-hooks.json" "${dest}/cursor-hooks.json"
}

cursor_github_marketplace_gitpath_root() {
  printf '%s/plugins/marketplaces/github.com/%s\n' "$CURSOR_HOME" "$CURSOR_GITHUB_REPO_SLUG"
}

resolve_install_commit_sha() {
  local source_root="$1"
  if [[ -d "${source_root}/.git" ]]; then
    git -C "$source_root" rev-parse HEAD
    return 0
  fi
  git -C "$REPO_ROOT" rev-parse HEAD
}

ensure_cursor_github_marketplace_gitpath() {
  local commit_sha="$1"
  local source_root="$2"
  local base_root dest_root

  [[ -n "$commit_sha" ]] || return 0

  base_root="$(cursor_github_marketplace_gitpath_root)"
  dest_root="${base_root}/${commit_sha}"

  if [[ -d "${dest_root}/.git" ]] && git -C "$dest_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1; then
    git -C "$dest_root" checkout -f "$commit_sha" >/dev/null 2>&1 || true
    return 0
  fi

  if [[ -d "$dest_root" ]]; then
    rm -rf "$dest_root"
  fi
  mkdir -p "$(dirname "$base_root")"

  if [[ -d "${source_root}/.git" ]] && [[ "$(git -C "$source_root" rev-parse HEAD)" == "$commit_sha" ]]; then
    git clone --local "$source_root" "$dest_root" >/dev/null
    return 0
  fi

  if ! git clone --depth 1 "$CURSOR_GITHUB_REPO_URL" "$dest_root" >/dev/null 2>&1; then
    git clone "$CURSOR_GITHUB_REPO_URL" "$dest_root" >/dev/null
  fi

  if ! git -C "$dest_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1; then
    git -C "$dest_root" fetch --depth 1 origin "$commit_sha" >/dev/null 2>&1 || \
      git -C "$dest_root" fetch origin "$commit_sha" >/dev/null 2>&1 || true
  fi

  git -C "$dest_root" checkout -f "$commit_sha" >/dev/null
}

ensure_cursor_installed_plugins_registry() {
  local dest="$1"
  local version="$2"
  local commit_sha="${3:-}"
  local registry_file="${CURSOR_HOME}/plugins/installed_plugins.json"
  local now
  local tmp

  now="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  mkdir -p "$(dirname "$registry_file")"

  python3 - "$registry_file" "$dest" "$version" "$now" "$commit_sha" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
install_path = str(pathlib.Path(sys.argv[2]).resolve())
version = sys.argv[3]
now = sys.argv[4]
commit_sha = sys.argv[5]
plugin_id = "silver-bullet@alo-labs"

data = {"version": 2, "plugins": {}}
if registry_path.is_file():
    try:
        data = json.loads(registry_path.read_text())
    except Exception:
        pass

plugins = data.setdefault("plugins", {})
entry = {
    "scope": "user",
    "installPath": install_path,
    "version": version,
    "installedAt": now,
    "lastUpdated": now,
    "enabled": True,
}
if commit_sha:
    entry["gitCommitSha"] = commit_sha

existing = plugins.get(plugin_id)
if isinstance(existing, list):
    if existing:
        existing[0].update(entry)
    else:
        plugins[plugin_id] = [entry]
elif isinstance(existing, dict):
    existing.update(entry)
    plugins[plugin_id] = existing
else:
    plugins[plugin_id] = entry

registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

sync_plugin_tree() {
  local dest

  mkdir -p "${REPO_ROOT}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" cursor)" >/dev/null 2>&1 || true
  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$REPO_ROOT")"
  dest="$(sync_plugin_tree_from_checkout "$REPO_ROOT" "$VERSION")"
  ensure_cursor_github_marketplace_gitpath "$INSTALL_COMMIT_SHA" "$REPO_ROOT"
  printf '%s\n' "$dest"
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

  mkdir -p "${checkout_dir}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${checkout_dir}/skills" \
    --dest-root "$(sb_agent_bundle_root "$checkout_dir" cursor)" >/dev/null

  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$checkout_dir")"
  VERSION="$release_version"
  DEST_ROOT="$(sync_plugin_tree_from_checkout "$checkout_dir" "$release_version")"
  ensure_cursor_github_marketplace_gitpath "$INSTALL_COMMIT_SHA" "$checkout_dir"
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
if [[ -z "$INSTALL_COMMIT_SHA" && -d "$REPO_ROOT/.git" ]]; then
  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$REPO_ROOT")"
fi
ensure_cursor_installed_plugins_registry "$DEST_ROOT" "$VERSION" "$INSTALL_COMMIT_SHA"

printf '\nCursor hook merge complete. SB hooks are in %s/hooks.json.\n' "$CURSOR_HOME"
printf 'If skills do not appear, reload the window or run: bash scripts/install-cursor.sh --merge-hooks-only\n'

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Silver Bullet Cursor plugin refreshed from %s at %s\n' "$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE" "$DEST_ROOT"
else
  printf 'Silver Bullet Cursor plugin synced to %s\n' "$DEST_ROOT"
fi
