#!/usr/bin/env bash
# Migrate legacy SB projects to explicit sb_initiated: true (P1).
set -euo pipefail

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
printf '%s\n' "$updated" >"${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
echo "Set sb_initiated: true in $CONFIG"
echo "Re-run /silver:init if hooks or workflows.sh are missing."
