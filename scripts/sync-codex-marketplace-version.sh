#!/usr/bin/env bash
# Sync the Codex marketplace version surface with the current SB release.
#
# Updates BOTH:
#   - plugins/silver-bullet/.codex-plugin/plugin.json (this repo's source copy)
#   - The unified agent-plugins Codex manifest (.agents/plugins/marketplace.json)
#
# Usage: scripts/sync-codex-marketplace-version.sh [version]
#
# Exit 0 = version already in sync or successfully synced
# Exit 1 = jq unavailable, JSON malformed, or the marketplace repo cannot be updated

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"
codex_plugin_json="$repo_root/plugins/silver-bullet/.codex-plugin/plugin.json"
marketplace_repo_url="$(resolve_agent_plugins_repo_url codex)"
marketplace_repo_root="${AGENT_PLUGINS_REPO_ROOT:-${CODEX_MARKETPLACE_REPO_ROOT:-}}"
codex_package_sync_script="$repo_root/scripts/sync-codex-package.sh"
requested_version="${1:-}"

command -v jq >/dev/null || { echo "jq required"; exit 1; }

if [[ -n "$requested_version" ]]; then
  plugin_v="${requested_version#v}"
else
  plugin_v=$(jq -r '.version' "$repo_root/package.json")
fi

update_version_file() {
  local manifest="$1"
  local current_version
  local current_config_version
  current_version=$(jq -r '.version' "$manifest")
  current_config_version=$(jq -r '.config_version' "$manifest")

  if [[ "$current_version" == "$plugin_v" && "$current_config_version" == "$plugin_v" ]]; then
    echo "✓ Version and config_version already in sync: $plugin_v ($manifest)"
    return 0
  fi

  tmp=$(mktemp)
  jq --arg v "$plugin_v" '.version = $v | .config_version = $v' "$manifest" > "$tmp"
  mv "$tmp" "$manifest"
  rm -f -- "$tmp"
  echo "✓ Updated version/config_version: $current_version/$current_config_version → $plugin_v ($manifest)"
}

sync_codex_marketplace_manifest() {
  local root="$1"
  local version="$2"
  local manifest="$root/.agents/plugins/marketplace.json"
  local remote_before
  local remote_after
  local release_ref="v${version}"

  [[ -d "$root/.git" ]] || {
    echo "ERROR: marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Codex marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  remote_before=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  tmp=$(mktemp)
  jq --arg v "$version" --arg ref "$release_ref" \
    '(.plugins[] | select(.name=="silver-bullet") | .version) = $v
     | (.plugins[] | select(.name=="silver-bullet") | .source.ref) = $ref' \
    "$manifest" > "$tmp"
  mv "$tmp" "$manifest"
  rm -f -- "$tmp"

  if git -C "$root" diff --quiet -- .agents/plugins/marketplace.json; then
    echo "✓ Codex marketplace manifest already at silver-bullet $version: $root"
    return 0
  fi

  git -C "$root" add .agents/plugins/marketplace.json
  agent_plugins_commit_push_if_dirty "$root" "Bump silver-bullet Codex manifest to $version"

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated Codex marketplace manifest: $remote_before → $remote_after"
}

update_version_file "$codex_plugin_json"

if [[ -x "$codex_package_sync_script" ]]; then
  bash "$codex_package_sync_script" >/dev/null
else
  echo "ERROR: Codex package sync script not found or not executable: $codex_package_sync_script" >&2
  exit 1
fi

if [[ -n "$marketplace_repo_root" ]]; then
  sync_codex_marketplace_manifest "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-codex.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone "$marketplace_repo_url" "$tmp_repo_root" >/dev/null
  sync_codex_marketplace_manifest "$tmp_repo_root" "$plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Codex marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The agent-plugins Codex manifest was updated for v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
