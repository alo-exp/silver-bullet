#!/usr/bin/env bash
# Sync marketplace.json version with plugin.json before tagging a release.
#
# Updates BOTH:
#   - .claude-plugin/marketplace.json (self-hosted entry in this repo)
#   - The upstream marketplace repo (defaults to alo-labs/claude-plugins),
#     then commits and pushes the version bump there
#
# Usage: scripts/sync-marketplace-version.sh [version]
#
# Exit 0 = versions already in sync or successfully synced
# Exit 1 = jq unavailable or JSON malformed

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"
marketplace_repo_url="${MARKETPLACE_REPO_URL:-https://github.com/alo-labs/claude-plugins.git}"
marketplace_repo_root="${MARKETPLACE_REPO_ROOT:-}"
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

sync_marketplace_repo() {
  local root="$1"
  local version="$2"
  local manifest="$root/.claude-plugin/marketplace.json"
  local remote_before
  local remote_after

  [[ -d "$root/.git" ]] || {
    echo "ERROR: marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: marketplace manifest not found in repo: $manifest" >&2
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

  if git -C "$root" diff --quiet -- .claude-plugin/marketplace.json; then
    echo "✓ Marketplace repo already at silver-bullet $version: $root"
    return 0
  fi

  git -C "$root" add .claude-plugin/marketplace.json
  git -C "$root" commit -m "Bump silver-bullet to $version"
  git -C "$root" push

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated and pushed marketplace repo: $remote_before → $remote_after"
}

if [[ -n "$marketplace_repo_root" ]]; then
  sync_marketplace_repo "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-marketplace.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone "$marketplace_repo_url" "$tmp_repo_root" >/dev/null
  sync_marketplace_repo "$tmp_repo_root" "$plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Remote marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The marketplace repo was updated and pushed for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
