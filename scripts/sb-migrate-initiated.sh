#!/usr/bin/env bash
# Migrate legacy SB projects to explicit sb_initiated: true (P1).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../hooks/lib/nofollow-guard.sh
source "$PLUGIN_ROOT/hooks/lib/nofollow-guard.sh"
REPO_ROOT="${1:-$PWD}"
CONFIG="$REPO_ROOT/.silver-bullet.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "No .silver-bullet.json in $REPO_ROOT" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

current="$(jq -r '.sb_initiated // false' "$CONFIG")"
if [[ "$current" == "true" ]]; then
  echo "Already sb_initiated: true"
  exit 0
fi

updated="$(jq '.sb_initiated = true' "$CONFIG")"
printf '%s\n' "$updated" | sb_atomic_write_file "$CONFIG" || { echo "Cannot update $CONFIG (symlink or unwritable directory)" >&2; exit 1; }
echo "Set sb_initiated: true in $CONFIG"
echo "Re-run /sb:init if hooks or workflows.sh are missing."
