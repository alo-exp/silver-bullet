#!/usr/bin/env bash
# Attempt automatic SB prerequisite repair (Wave 0.2).
# Called from session-start when jq or plugin surfaces are missing.
set -euo pipefail

REPO_ROOT="${1:-$PWD}"

repaired=false

if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install jq 2>/dev/null && repaired=true || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y jq 2>/dev/null && repaired=true || true
  fi
fi

# Plugin cache cannot be auto-installed without host plugin manager — noop.

if command -v jq >/dev/null 2>&1; then
  exit 0
fi

exit 1
