#!/usr/bin/env bash
# Tests scripts/sb-migrate-initiated.sh sets sb_initiated: true (BE-03).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sb-migrate-initiated.sh"
PASS=0
FAIL=0

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$WORK/.silver-bullet.json"
echo '# SB' >"$WORK/silver-bullet.md"

if (cd "$WORK" && bash "$SCRIPT" >/dev/null); then
  echo "PASS: sb-migrate-initiated exits 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-migrate-initiated failed"
  FAIL=$((FAIL + 1))
fi

flag=$(jq -r '.sb_initiated' "$WORK/.silver-bullet.json")
if [[ "$flag" == "true" ]]; then
  echo "PASS: sb_initiated set true"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb_initiated is $flag"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
