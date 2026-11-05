#!/usr/bin/env bash
# Release marketplace sync, in the two steps of docs/RELEASE.md:
#
#   scripts/sync-release-marketplace-versions.sh <version>
#       Before the release commit: run the local pre-release gate, then align this
#       repository's Claude, Codex and Cursor manifests with <version>. Nothing leaves the
#       machine; commit the result as part of the release commit.
#   scripts/sync-release-marketplace-versions.sh --publish <version>
#       After the release tag v<version> is pushed and CI is green for its commit: publish
#       <version> to the unified alo-labs/agent-plugins marketplace (AGENT_PLUGINS_REPO_URL,
#       or the checkout in AGENT_PLUGINS_REPO_ROOT), pinned to the tag. One clone, one commit
#       per host, one push; the run fails unless the push reaches the remote.
set -euo pipefail
trap 'exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"

usage() {
  echo "ERROR: usage: scripts/sync-release-marketplace-versions.sh [--publish] <version>" >&2
  exit 1
}

agent_plugins_parse_sync_args "$@" || usage
[[ -n "$AGENT_PLUGINS_VERSION" ]] || usage
release_version="${AGENT_PLUGINS_VERSION#v}"
if [[ -z "$release_version" ]]; then
  echo "ERROR: release version cannot be empty" >&2
  exit 1
fi
tag="v${release_version}"

claude_sync_script="${SB_SYNC_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-marketplace-version.sh}"
codex_sync_script="${SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-codex-marketplace-version.sh}"
cursor_sync_script="${SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-cursor-marketplace-version.sh}"

if [[ "$AGENT_PLUGINS_PUBLISH" != "1" ]]; then
  if [[ "${SB_SKIP_PRE_RELEASE_GATE:-0}" != "1" ]]; then
    bash "${SCRIPT_DIR}/pre-release-gate.sh"
  fi
  bash "$claude_sync_script" "$release_version"
  bash "$codex_sync_script" "$release_version"
  bash "$cursor_sync_script" "$release_version"
  cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  In-repo marketplace manifests aligned with v$release_version
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Nothing was published. Next, in order (docs/RELEASE.md):
  1. Commit these manifests with the release and push the release commit.
  2. Wait for green CI: bash scripts/verify-release-commit-ci.sh
  3. Tag the release commit and push the tag: git tag -a $tag && git push origin $tag
  4. Publish the unified marketplace:
     bash scripts/sync-release-marketplace-versions.sh --publish $release_version
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
  exit 0
fi

# --publish: only a tagged release whose commit is green in CI reaches the marketplace.
tag_commit="$(agent_plugins_release_tag_commit "$repo_root" "$release_version")"
local_tag_ref="$(git -C "$repo_root" rev-parse "refs/tags/${tag}")"
remote_tag_ref="$(git -C "$repo_root" ls-remote origin "refs/tags/${tag}" 2>/dev/null | awk -v r="refs/tags/${tag}" '$2 == r { print $1 }' || true)"
if [[ "$remote_tag_ref" != "$local_tag_ref" ]]; then
  echo "ERROR: release tag $tag is not on origin (or origin holds a different $tag); push it first: git push origin $tag" >&2
  exit 1
fi
package_version="$(jq -r '.version' "$repo_root/package.json")"
if [[ "$package_version" != "$release_version" ]]; then
  echo "ERROR: package.json is $package_version, not $release_version; publish from the release checkout" >&2
  exit 1
fi
echo "Checking CI for $tag ($tag_commit)..."
if ! bash "${SCRIPT_DIR}/verify-release-commit-ci.sh" "$tag_commit"; then
  echo "ERROR: CI is not green for $tag ($tag_commit); nothing was published" >&2
  exit 1
fi

batch_root="${AGENT_PLUGINS_REPO_ROOT:-}"
batch_tmp=""
# Remove the temporary clone on every exit, including a failing host sync.
trap '[[ -n "$batch_tmp" ]] && rm -rf -- "$batch_tmp"' EXIT
if [[ -z "$batch_root" ]]; then
  batch_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-release.XXXXXX")
  batch_root="$batch_tmp"
  if ! git clone -q "$(agent_plugins_repo_url)" "$batch_root" 2>/dev/null; then
    echo "ERROR: could not clone $(agent_plugins_repo_url); nothing was published" >&2
    exit 1
  fi
fi

# Every host commits into the one checkout; the single push at the end publishes exactly
# those commits, so the checkout must not hold anyone else's.
agent_plugins_check_publishable "$batch_root"
export AGENT_PLUGINS_REPO_ROOT="$batch_root"
export AGENT_PLUGINS_SKIP_PUSH=1
bash "$claude_sync_script" --publish "$release_version"
bash "$codex_sync_script" --publish "$release_version"
bash "$cursor_sync_script" --publish "$release_version"
unset AGENT_PLUGINS_SKIP_PUSH
agent_plugins_push "$batch_root"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Release marketplace publish complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The unified agent-plugins marketplace offers silver-bullet v$release_version ($tag).
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
