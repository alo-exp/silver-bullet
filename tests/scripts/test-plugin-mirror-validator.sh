#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
passed=0
failed=0

if bash "$REPO_ROOT/scripts/validate-plugin-mirror.sh" >/dev/null; then
  echo "PASS: plugin mirror validator"
  passed=1
else
  echo "FAIL: plugin mirror validator"
  failed=1
fi

printf 'Results: %d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
