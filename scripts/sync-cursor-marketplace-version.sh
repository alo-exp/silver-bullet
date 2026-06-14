#!/usr/bin/env bash
# Sync .cursor-plugin/marketplace.json version with plugin.json before tagging a release.
#
# Updates BOTH:
#   - .cursor-plugin/marketplace.json (self-hosted entry in this repo)
#   - The upstream Cursor marketplace repo (defaults to alo-labs/alo-labs-cursor-marketplace),
#     then commits and pushes the version bump there
#
# Usage: scripts/sync-cursor-marketplace-version.sh [version]
#
# Exit 0 = versions already in sync or successfully synced
# Exit 1 = jq unavailable or JSON malformed

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
plugin_json="$repo_root/.cursor-plugin/plugin.json"
marketplace_json="$repo_root/.cursor-plugin/marketplace.json"
marketplace_repo_url="${CURSOR_MARKETPLACE_REPO_URL:-https://github.com/alo-labs/alo-labs-cursor-marketplace.git}"
marketplace_repo_root="${CURSOR_MARKETPLACE_REPO_ROOT:-}"
requested_version="${1:-}"

command -v jq >/dev/null || { echo "jq required"; exit 1; }

current_plugin_v=$(jq -r '.version' "$plugin_json")
if [[ -n "$requested_version" ]]; then
  plugin_v="${requested_version#v}"
  if [[ "$current_plugin_v" != "$plugin_v" ]]; then
    echo "ERROR: $plugin_json is $current_plugin_v but the release version is $plugin_v. Bump the plugin manifest first." >&2
    exit 1
  fi
else
  plugin_v="$current_plugin_v"
fi
market_v=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$marketplace_json")

if [[ "$plugin_v" == "$market_v" ]]; then
  echo "✓ Versions already in sync: $plugin_v"
else
  tmp=$(mktemp)
  jq --arg v "$plugin_v" '(.plugins[] | select(.name=="silver-bullet") | .version) = $v' \
    "$marketplace_json" > "$tmp"
  mv "$tmp" "$marketplace_json"
  rm -f -- "$tmp"
  echo "✓ Updated in-repo marketplace.json: $market_v → $plugin_v"
fi

cursor_package_sync_script="$repo_root/scripts/sync-cursor-package.sh"
if [[ -x "$cursor_package_sync_script" ]]; then
  bash "$cursor_package_sync_script" >/dev/null
else
  echo "ERROR: Cursor package sync script not found or not executable: $cursor_package_sync_script" >&2
  exit 1
fi

package_manifest="$repo_root/plugins/silver-bullet/.cursor-plugin/plugin.json"
package_v=$(jq -r '.version' "$package_manifest")
if [[ "$package_v" != "$plugin_v" ]]; then
  echo "ERROR: plugins/silver-bullet/.cursor-plugin/plugin.json is $package_v but release version is $plugin_v" >&2
  exit 1
fi

sync_marketplace_repo() {
  local root="$1"
  local version="$2"
  local manifest="$root/.cursor-plugin/marketplace.json"
  local remote_before
  local remote_after

  [[ -d "$root/.git" ]] || {
    echo "ERROR: Cursor marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Cursor marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  remote_before=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  if [[ "$remote_before" != "$version" ]]; then
    tmp=$(mktemp)
    jq --arg v "$version" '(.plugins[] | select(.name=="silver-bullet") | .version) = $v' \
      "$manifest" > "$tmp"
    mv "$tmp" "$manifest"
    rm -f -- "$tmp"
  fi

  if git -C "$root" diff --quiet -- .cursor-plugin/marketplace.json; then
    echo "✓ Cursor marketplace repo already at silver-bullet $version: $root"
    return 0
  fi

  git -C "$root" add .cursor-plugin/marketplace.json
  git -C "$root" commit -m "Bump silver-bullet to $version"
  git -C "$root" push

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated and pushed Cursor marketplace repo: $remote_before → $remote_after"
}

if [[ -n "$marketplace_repo_root" ]]; then
  sync_marketplace_repo "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-cursor-marketplace.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone "$marketplace_repo_url" "$tmp_repo_root" >/dev/null
  sync_marketplace_repo "$tmp_repo_root" "$plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Cursor marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Cursor marketplace repo was updated and pushed for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
