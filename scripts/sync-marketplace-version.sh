#!/usr/bin/env bash
# Align the Claude marketplace manifests with the release version.
#
#   scripts/sync-marketplace-version.sh [version]
#       Set the silver-bullet entry of this repository's .claude-plugin/marketplace.json to
#       the version of .claude-plugin/plugin.json ([version], when given, must equal it).
#       Nothing leaves the machine; commit the result with the release.
#   scripts/sync-marketplace-version.sh --publish [version]
#       Publish that version to the unified agent-plugins marketplace (defaults to
#       alo-labs/agent-plugins): commit only .claude-plugin/marketplace.json there, push it
#       and confirm the push. Needs the release tag v<version>; the release runs this
#       through scripts/sync-release-marketplace-versions.sh --publish (docs/RELEASE.md).
#
# Exit 0 = in sync or synced; exit 1 = jq missing, invalid JSON, or a precondition failed.

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"
marketplace_rel=.claude-plugin/marketplace.json
marketplace_repo_url="$(resolve_agent_plugins_repo_url claude)"
marketplace_repo_root="${AGENT_PLUGINS_REPO_ROOT:-${MARKETPLACE_REPO_ROOT:-}}"

command -v jq >/dev/null || { echo "jq required"; exit 1; }
agent_plugins_parse_sync_args "$@"
requested_version="$AGENT_PLUGINS_VERSION"

# A marketplace without a silver-bullet entry has nothing to bump: say so instead
# of reporting a sync that changed nothing.
require_silver_bullet_entry() {
  if ! jq -e . "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 is not valid JSON" >&2
    exit 1
  fi
  if ! jq -e '[.plugins[]? | select(.name=="silver-bullet")] | length > 0' "$1" >/dev/null; then
    echo "ERROR: $1 has no silver-bullet entry to sync" >&2
    exit 1
  fi
}

set_silver_bullet_version() {
  # shellcheck disable=SC2016  # $v is a jq variable
  agent_plugins_json_rewrite "$1" --arg v "$2" '(.plugins[] | select(.name=="silver-bullet") | .version) = $v'
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
require_silver_bullet_entry "$marketplace_json"
market_v=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$marketplace_json")

if [[ "$AGENT_PLUGINS_PUBLISH" != "1" ]]; then
  if [[ "$plugin_v" == "$market_v" ]]; then
    echo "✓ Versions already in sync: $plugin_v"
  else
    set_silver_bullet_version "$marketplace_json" "$plugin_v"
    echo "✓ Updated in-repo marketplace.json: $market_v → $plugin_v"
  fi
  printf "\nThis repository's Claude marketplace manifest is at v%s.\n" "$plugin_v"
  exit 0
fi

publish_marketplace_repo() {
  local root="$1"
  local version="$2"
  local manifest="$root/$marketplace_rel"
  local remote_before
  local remote_after

  [[ -d "$root/.git" ]] || {
    echo "ERROR: marketplace repo root is not a git repository: $root" >&2
    exit 1
  }
  [[ -f "$manifest" ]] || {
    echo "ERROR: Claude marketplace manifest not found in repo: $manifest" >&2
    exit 1
  }

  require_silver_bullet_entry "$manifest"
  # Batch runs (AGENT_PLUGINS_SKIP_PUSH=1) are checked once by the release wrapper.
  [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" == "1" ]] || agent_plugins_check_publishable "$root"
  agent_plugins_require_clean_path "$root" "$marketplace_rel"
  remote_before=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  if [[ "$remote_before" != "$version" ]]; then
    set_silver_bullet_version "$manifest" "$version"
  fi

  if git -C "$root" diff --quiet -- "$marketplace_rel"; then
    echo "✓ Claude marketplace manifest already at silver-bullet $version: $root"
    return 0
  fi

  agent_plugins_commit_paths "$root" "Bump silver-bullet Claude manifest to $version" "$marketplace_rel"
  agent_plugins_push "$root"

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated Claude marketplace manifest: $remote_before → $remote_after"
}

# --publish ships what the release commit carries: the in-repo manifest must already be
# aligned and the release tag must exist.
if [[ "$market_v" != "$plugin_v" ]]; then
  echo "ERROR: $marketplace_json is $market_v, not $plugin_v: run scripts/sync-marketplace-version.sh $plugin_v and commit the result before publishing" >&2
  exit 1
fi
agent_plugins_release_tag_commit "$repo_root" "$plugin_v" >/dev/null

if [[ -n "$marketplace_repo_root" ]]; then
  publish_marketplace_repo "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone -q "$marketplace_repo_url" "$tmp_repo_root"
  publish_marketplace_repo "$tmp_repo_root" "$plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Claude marketplace publish complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The agent-plugins Claude manifest now offers silver-bullet v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
