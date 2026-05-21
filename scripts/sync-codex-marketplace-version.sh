#!/usr/bin/env bash
# Sync the Codex marketplace version surface with the current SB release.
#
# Updates BOTH:
#   - plugins/silver-bullet/.codex-plugin/plugin.json (this repo's source copy)
#   - The upstream Codex marketplace repo clone (defaults to
#     ~/.codex/.tmp/marketplaces/alo-labs-codex), then commits/pushes the version
#     bump there
#
# Usage: scripts/sync-codex-marketplace-version.sh [version]
#
# Exit 0 = version already in sync or successfully synced
# Exit 1 = jq unavailable, JSON malformed, or the marketplace repo cannot be updated

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
codex_plugin_json="$repo_root/plugins/silver-bullet/.codex-plugin/plugin.json"
codex_marketplace_repo_root="${CODEX_MARKETPLACE_REPO_ROOT:-${HOME}/.codex/.tmp/marketplaces/alo-labs-codex}"
requested_version="${1:-}"

command -v jq >/dev/null || { echo "jq required"; exit 1; }

if [[ -n "$requested_version" ]]; then
  plugin_v="${requested_version#v}"
else
  plugin_v=$(jq -r '.version' "$codex_plugin_json")
fi

update_version_file() {
  local manifest="$1"
  local current_version
  current_version=$(jq -r '.version' "$manifest")

  if [[ "$current_version" == "$plugin_v" ]]; then
    echo "✓ Versions already in sync: $plugin_v ($manifest)"
    return 0
  fi

  tmp=$(mktemp)
  jq --arg v "$plugin_v" '.version = $v' "$manifest" > "$tmp"
  mv "$tmp" "$manifest"
  rm -f -- "$tmp"
  echo "✓ Updated version: $current_version → $plugin_v ($manifest)"
}

sync_marketplace_repo() {
  local root="$1"
  local manifest="$root/plugins/silver-bullet/.codex-plugin/plugin.json"
  local remote_before
  local remote_after

  [[ -d "$root/.git" ]] || {
    echo "ERROR: Codex marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Codex marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  remote_before=$(jq -r '.version' "$manifest")
  if [[ "$remote_before" != "$plugin_v" ]]; then
    update_version_file "$manifest"
  fi

  if git -C "$root" diff --quiet -- plugins/silver-bullet/.codex-plugin/plugin.json; then
    echo "✓ Codex marketplace repo already at silver-bullet $plugin_v: $root"
    return 0
  fi

  git -C "$root" add plugins/silver-bullet/.codex-plugin/plugin.json
  git -C "$root" commit -m "Bump silver-bullet to $plugin_v"
  git -C "$root" push

  remote_after=$(jq -r '.version' "$manifest")
  echo "✓ Updated and pushed Codex marketplace repo: $remote_before → $remote_after"
}

update_version_file "$codex_plugin_json"
sync_marketplace_repo "$codex_marketplace_repo_root"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Codex marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Codex marketplace repo was updated and pushed for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
