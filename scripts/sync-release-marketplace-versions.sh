#!/usr/bin/env bash
set -euo pipefail
trap 'exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-plugins-common.sh
source "${repo_root}/scripts/lib/agent-plugins-common.sh"
requested_version="${1:-}"

if [[ -z "$requested_version" ]]; then
  echo "ERROR: usage: scripts/sync-release-marketplace-versions.sh <version>" >&2
  exit 1
fi

release_version="${requested_version#v}"
if [[ -z "$release_version" ]]; then
  echo "ERROR: release version cannot be empty" >&2
  exit 1
fi

if [[ "${SB_SKIP_PRE_RELEASE_GATE:-0}" != "1" ]]; then
  bash "${SCRIPT_DIR}/pre-release-gate.sh"
fi

claude_sync_script="${SB_SYNC_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-marketplace-version.sh}"
codex_sync_script="${SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-codex-marketplace-version.sh}"
cursor_sync_script="${SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-cursor-marketplace-version.sh}"

batch_root="${AGENT_PLUGINS_REPO_ROOT:-}"
batch_tmp=""
if [[ -z "$batch_root" ]]; then
  batch_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-release.XXXXXX")
  batch_root="$batch_tmp"
  git clone "$(agent_plugins_repo_url)" "$batch_root" >/dev/null 2>&1 || {
    echo "WARN: could not clone $(agent_plugins_repo_url); syncing in-repo manifests only" >&2
    batch_root=""
  }
fi

if [[ -n "$batch_root" ]]; then
  export AGENT_PLUGINS_REPO_ROOT="$batch_root"
  export AGENT_PLUGINS_SKIP_PUSH=1
  bash "$claude_sync_script" "$release_version"
  bash "$codex_sync_script" "$release_version"
  bash "$cursor_sync_script" "$release_version"
  unset AGENT_PLUGINS_SKIP_PUSH
  agent_plugins_commit_push_if_dirty "$batch_root" "Sync silver-bullet marketplace manifests to $release_version"
  [[ -n "$batch_tmp" ]] && rm -rf -- "$batch_tmp"
else
  bash "$claude_sync_script" "$release_version"
  bash "$codex_sync_script" "$release_version"
  bash "$cursor_sync_script" "$release_version"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Release marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The unified agent-plugins marketplace was updated for v$release_version.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
