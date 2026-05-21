#!/usr/bin/env bash
# Sync both release marketplace version surfaces before tagging a Silver Bullet release.
#
# This wrapper enforces that the Claude marketplace and the Codex marketplace are
# both updated together, using the finalized release version as the source of truth.
#
# Usage: scripts/sync-release-marketplace-versions.sh <version>

set -euo pipefail
trap 'exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

claude_sync_script="${SB_SYNC_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-marketplace-version.sh}"
codex_sync_script="${SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-codex-marketplace-version.sh}"

bash "$claude_sync_script" "$release_version"
bash "$codex_sync_script" "$release_version"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Release marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Claude and Codex marketplace repos were updated and pushed for v$release_version.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
