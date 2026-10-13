#!/usr/bin/env bash
# Sync .cursor-plugin/marketplace.json version with plugin.json before tagging a release.
#
# Updates BOTH:
#   - .cursor-plugin/marketplace.json (self-hosted entry in this repo)
#   - The unified agent-plugins marketplace repo (defaults to alo-labs/agent-plugins),
#     then commits and pushes the version bump there
#
# Usage: scripts/sync-cursor-marketplace-version.sh [version]
#
# Exit 0 = versions already in sync or successfully synced
# Exit 1 = jq unavailable or JSON malformed

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"
plugin_json="$repo_root/.cursor-plugin/plugin.json"
marketplace_json="$repo_root/.cursor-plugin/marketplace.json"
marketplace_repo_url="$(resolve_agent_plugins_repo_url cursor)"
marketplace_repo_root="${AGENT_PLUGINS_REPO_ROOT:-${CURSOR_MARKETPLACE_REPO_ROOT:-}}"
requested_version="${1:-}"

command -v jq >/dev/null || { echo "jq required"; exit 1; }


resolve_release_commit_sha() {
  local version="$1"
  local tag_sha head_sha
  head_sha="$(git -C "$repo_root" rev-parse HEAD)"
  tag_sha="$(git -C "$repo_root" rev-parse "v${version}^{commit}" 2>/dev/null || git -C "$repo_root" rev-parse "v${version}" 2>/dev/null || true)"
  if [[ -n "$tag_sha" && "$head_sha" != "$tag_sha" ]]; then
    printf '%s\n' "$head_sha"
    return 0
  fi
  if [[ -n "$tag_sha" ]]; then
    printf '%s\n' "$tag_sha"
    return 0
  fi
  printf '%s\n' "$head_sha"
}

resolve_marketplace_source_ref() {
  local version="$1"
  local tag_sha head_sha
  head_sha="$(git -C "$repo_root" rev-parse HEAD)"
  tag_sha="$(git -C "$repo_root" rev-parse "v${version}^{commit}" 2>/dev/null || git -C "$repo_root" rev-parse "v${version}" 2>/dev/null || true)"
  if [[ -n "$tag_sha" && "$head_sha" != "$tag_sha" ]]; then
    printf 'main\n'
    return 0
  fi
  printf 'v%s\n' "$version"
}

update_marketplace_plugin_source() {
  local manifest="$1"
  local version="$2"
  local release_sha source_ref
  release_sha="$(resolve_release_commit_sha "$version")"
  source_ref="$(resolve_marketplace_source_ref "$version")"
  local tmp
  tmp=$(mktemp)
  jq --arg v "$version" --arg ref "$source_ref" --arg sha "$release_sha" --arg path "plugins/silver-bullet" '
    (.plugins[] | select(.name=="silver-bullet") | .version) = $v
    | (.plugins[] | select(.name=="silver-bullet") | .source.ref) = $ref
    | (.plugins[] | select(.name=="silver-bullet") | .source.sha) = $sha
    | (.plugins[] | select(.name=="silver-bullet") | .source.path) = $path
  ' "$manifest" > "$tmp"
  mv "$tmp" "$manifest"
  rm -f -- "$tmp"
}

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
  update_marketplace_plugin_source "$marketplace_json" "$plugin_v"
  echo "✓ Versions already in sync: $plugin_v"
else
  update_marketplace_plugin_source "$marketplace_json" "$plugin_v"
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
    echo "ERROR: marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Cursor marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  remote_before=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  update_marketplace_plugin_source "$manifest" "$version"

  if git -C "$root" diff --quiet -- .cursor-plugin/marketplace.json; then
    echo "✓ Cursor marketplace manifest already at silver-bullet $version: $root"
    return 0
  fi

  git -C "$root" add .cursor-plugin/marketplace.json
  agent_plugins_commit_push_if_dirty "$root" "Bump silver-bullet to $version"

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated Cursor marketplace manifest: $remote_before → $remote_after"
}

if [[ -n "$marketplace_repo_root" ]]; then
  sync_marketplace_repo "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-cursor.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone "$marketplace_repo_url" "$tmp_repo_root" >/dev/null
  sync_marketplace_repo "$tmp_repo_root" "$plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Cursor marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The agent-plugins Cursor manifest was updated for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
