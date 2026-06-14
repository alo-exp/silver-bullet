#!/usr/bin/env bash
# Attempt automatic SB prerequisite repair (Wave 0.2).
# Called from session-start when jq or plugin surfaces are missing.
set -euo pipefail

# shellcheck disable=SC2034  # reserved for future project-scoped repair steps
REPO_ROOT="${1:-$PWD}"

if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install jq 2>/dev/null || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y jq 2>/dev/null || true
  fi
fi

# Plugin cache cannot be auto-installed without host plugin manager — noop.

if command -v jq >/dev/null 2>&1; then
  exit 0
fi

exit 1
