#!/usr/bin/env bash
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

# Hard gate: local CI-equivalent suite must be green before version bump/sync.
bash "${SCRIPT_DIR}/pre-release-gate.sh"

claude_sync_script="${SB_SYNC_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-marketplace-version.sh}"
codex_sync_script="${SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-codex-marketplace-version.sh}"
cursor_sync_script="${SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT:-${SCRIPT_DIR}/sync-cursor-marketplace-version.sh}"

bash "$claude_sync_script" "$release_version"
bash "$codex_sync_script" "$release_version"
bash "$cursor_sync_script" "$release_version"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Release marketplace sync complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Claude, Codex, and Cursor marketplace repos were updated and pushed for v$release_version.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
