#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SB_POST_RELEASE_VERIFY_SCRIPT:-${SCRIPT_DIR}/post-release-host-verify.sh}"

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
  printf 'ERROR: post-release verify script missing at %s\n' "$VERIFY_SCRIPT" >&2
  exit 1
fi

printf '[post-release-refresh] Delegating to post-release-host-verify.sh\n'
exec bash "$VERIFY_SCRIPT" "$@"
