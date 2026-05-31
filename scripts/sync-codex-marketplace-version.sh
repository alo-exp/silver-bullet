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
codex_package_sync_script="$repo_root/scripts/sync-codex-package.sh"
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
  local upstream_ref
  local upstream_remote
  local upstream_branch

  [[ -d "$root/.git" ]] || {
    echo "ERROR: Codex marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Codex marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  remote_before=$(jq -r '.version' "$manifest")
  sync_marketplace_package_surface "$root"
  if [[ "$remote_before" != "$plugin_v" ]]; then
    update_version_file "$manifest"
  fi

  if git -C "$root" diff --quiet -- plugins/silver-bullet; then
    echo "✓ Codex marketplace repo already at silver-bullet $plugin_v: $root"
    return 0
  fi

  git -C "$root" add plugins/silver-bullet
  git -C "$root" commit -m "Sync silver-bullet Codex package to $plugin_v"

  upstream_ref="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)"
  if [[ "$upstream_ref" == */* ]]; then
    upstream_remote="${upstream_ref%%/*}"
    upstream_branch="${upstream_ref#*/}"
    git -C "$root" push "$upstream_remote" "HEAD:${upstream_branch}"
  else
    git -C "$root" push
  fi

  remote_after=$(jq -r '.version' "$manifest")
  echo "✓ Updated and pushed Codex marketplace repo: $remote_before → $remote_after"
}

update_version_file "$codex_plugin_json"

if [[ -x "$codex_package_sync_script" ]]; then
  bash "$codex_package_sync_script" >/dev/null
else
  echo "ERROR: Codex package sync script not found or not executable: $codex_package_sync_script" >&2
  exit 1
fi

sync_marketplace_package_surface() {
  local root="$1"
  local source_package="$repo_root/plugins/silver-bullet"
  local dest_package="$root/plugins/silver-bullet"

  [[ -d "$source_package" ]] || {
    echo "ERROR: source Codex package not found: $source_package" >&2
    exit 1
  }

  mkdir -p "$dest_package"

  # The Codex cache can drop symlink-backed package entries. Release the
  # marketplace package as materialized files so skill-picker discovery does not
  # depend on installer-side repair.
  rsync -aL --delete --exclude '.git/' "${source_package}/" "${dest_package}/"
}

sync_marketplace_repo "$codex_marketplace_repo_root"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Codex marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Codex marketplace repo was updated and pushed for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
