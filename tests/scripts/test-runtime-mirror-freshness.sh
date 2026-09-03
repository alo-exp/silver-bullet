#!/usr/bin/env bash
# Fail when plugins/silver-bullet scripts/hooks mirrors drift from canonical sources.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYNC="${REPO_ROOT}/scripts/sync-runtime-mirrors.sh"
PASS=0
FAIL=0

if [[ ! -x "$SYNC" ]]; then
  chmod +x "$SYNC" 2>/dev/null || true
fi

if bash "$SYNC" --check; then
  echo "PASS: runtime mirrors fresh"
  PASS=$((PASS + 1))
else
  echo "FAIL: runtime mirror drift — run: bash scripts/sync-runtime-mirrors.sh"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
