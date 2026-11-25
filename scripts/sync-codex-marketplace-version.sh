#!/usr/bin/env bash
# Align the Codex marketplace version surface with the current SB release.
#
#   scripts/sync-codex-marketplace-version.sh [version]
#       Set version and config_version of plugins/silver-bullet/.codex-plugin/plugin.json
#       to package.json's version ([version], when given, must equal it), then regenerate
#       the Codex package. Nothing leaves the machine; commit the result with the release.
#   scripts/sync-codex-marketplace-version.sh --publish [version]
#       Publish that version to the unified agent-plugins Codex manifest
#       (.agents/plugins/marketplace.json, entry pinned to the release tag): commit only that
#       file, push it and confirm the push. Needs the release tag v<version>; the release
#       runs this through scripts/sync-release-marketplace-versions.sh --publish.
#
# Exit 0 = in sync or synced; exit 1 = jq missing, invalid JSON, or a precondition failed.

set -euo pipefail
trap 'exit 1' ERR

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"
codex_plugin_rel=plugins/silver-bullet/.codex-plugin/plugin.json
codex_plugin_json="$repo_root/$codex_plugin_rel"
marketplace_rel=.agents/plugins/marketplace.json
marketplace_repo_url="$(resolve_agent_plugins_repo_url codex)"
marketplace_repo_root="${AGENT_PLUGINS_REPO_ROOT:-${CODEX_MARKETPLACE_REPO_ROOT:-}}"
codex_package_sync_script="$repo_root/scripts/sync-codex-package.sh"

command -v jq >/dev/null || { echo "jq required"; exit 1; }
agent_plugins_parse_sync_args "$@"

# The Codex package takes its version from package.json (scripts/sync-codex-package.sh), so
# any other version would be published while the shipped package reports a different one.
package_v=$(jq -r '.version' "$repo_root/package.json")
plugin_v="${AGENT_PLUGINS_VERSION#v}"
if [[ -z "$plugin_v" ]]; then
  plugin_v="$package_v"
elif [[ "$plugin_v" != "$package_v" ]]; then
  echo "ERROR: package.json is $package_v but the release version is $plugin_v. Bump package.json first." >&2
  exit 1
fi

# manifest_versions: "<version> (config_version <config_version>)" of the Codex plugin manifest.
manifest_versions() {
  jq -r '"\(.version) (config_version \(.config_version))"' "$codex_plugin_json"
}

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

  # shellcheck disable=SC2016  # $v is a jq variable
  agent_plugins_json_rewrite "$manifest" --arg v "$plugin_v" '.version = $v | .config_version = $v'
  echo "✓ Updated version/config_version: $current_version/$current_config_version → $plugin_v ($manifest)"
}

if [[ "$AGENT_PLUGINS_PUBLISH" != "1" ]]; then
  update_version_file "$codex_plugin_json"
  if [[ -x "$codex_package_sync_script" ]]; then
    bash "$codex_package_sync_script" >/dev/null
  else
    echo "ERROR: Codex package sync script not found or not executable: $codex_package_sync_script" >&2
    exit 1
  fi
  if [[ "$(manifest_versions)" != "$plugin_v (config_version $plugin_v)" ]]; then
    echo "ERROR: $codex_plugin_rel is $(manifest_versions) after the package sync, expected $plugin_v" >&2
    exit 1
  fi
  printf "\nThis repository's Codex plugin manifest is at v%s.\n" "$plugin_v"
  exit 0
fi

publish_codex_marketplace_manifest() {
  local root="$1"
  local version="$2"
  local manifest="$root/$marketplace_rel"
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

  # A manifest that does not parse is a different problem from one without our entry.
  if ! jq -e . "$manifest" >/dev/null 2>&1; then
    echo "ERROR: $manifest is not valid JSON" >&2
    exit 1
  fi
  # Nothing to bump without a silver-bullet entry: fail instead of reporting a no-op as synced.
  if ! jq -e '[.plugins[]? | select(.name=="silver-bullet")] | length > 0' "$manifest" >/dev/null; then
    echo "ERROR: $manifest has no silver-bullet entry to sync" >&2
    exit 1
  fi
  # Batch runs (AGENT_PLUGINS_SKIP_PUSH=1) are checked once by the release wrapper.
  [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" == "1" ]] || agent_plugins_check_publishable "$root"
  agent_plugins_require_clean_path "$root" "$marketplace_rel"
  remote_before=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  # shellcheck disable=SC2016  # $v and $ref are jq variables
  agent_plugins_json_rewrite "$manifest" --arg v "$version" --arg ref "$release_ref" \
    '(.plugins[] | select(.name=="silver-bullet") | .version) = $v
     | (.plugins[] | select(.name=="silver-bullet") | .source.ref) = $ref'

  if git -C "$root" diff --quiet -- "$marketplace_rel"; then
    echo "✓ Codex marketplace manifest already at silver-bullet $version: $root"
    return 0
  fi

  agent_plugins_commit_paths "$root" "Bump silver-bullet Codex manifest to $version" "$marketplace_rel"
  agent_plugins_push "$root"

  remote_after=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest")
  echo "✓ Updated Codex marketplace manifest: $remote_before → $remote_after"
}

# --publish ships what the release commit carries: the in-repo manifest must already be
# aligned and the release tag must exist.
if [[ "$(manifest_versions)" != "$plugin_v (config_version $plugin_v)" ]]; then
  echo "ERROR: $codex_plugin_rel is $(manifest_versions), not $plugin_v: run scripts/sync-codex-marketplace-version.sh $plugin_v and commit the result before publishing" >&2
  exit 1
fi
agent_plugins_release_tag_commit "$repo_root" "$plugin_v" >/dev/null
agent_plugins_require_tag_on_origin "$repo_root" "$plugin_v"
agent_plugins_require_green_ci "$repo_root" "$plugin_v"

if [[ -n "$marketplace_repo_root" ]]; then
  publish_codex_marketplace_manifest "$marketplace_repo_root" "$plugin_v"
else
  tmp_repo_root=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-codex.XXXXXX")
  trap 'rm -rf -- "$tmp_repo_root"' EXIT
  git clone -q "$marketplace_repo_url" "$tmp_repo_root"
  publish_codex_marketplace_manifest "$tmp_repo_root" "$plugin_v"
fi

if [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" == "1" ]]; then
  echo "Codex marketplace manifest committed in the shared checkout (push pending: the release wrapper pushes every host once)."
else
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Codex marketplace publish complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The agent-plugins Codex manifest now offers silver-bullet v$plugin_v.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
fi
