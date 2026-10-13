#!/usr/bin/env bash
# Validates process_packs catalog overlays (≥3 packs, valid workflow refs).
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

count="$(jq '.process_packs | length' "$CATALOG")"
if [[ "$count" -ge 3 ]]; then
  pass "process_packs has >=3 entries ($count)"
else
  fail "process_packs needs >=3 entries (got $count)"
fi

for id in PP-SB-DEFAULT PP-SB-REGULATED PP-SB-STARTUP-FAST; do
  if jq -e --arg id "$id" '.process_packs[] | select(.id == $id)' "$CATALOG" >/dev/null; then
    pass "process pack exists: $id"
  else
    fail "missing process pack: $id"
  fi
done

bad_refs="$(jq -r '
  (.workflows | map(.id)) as $wfs |
  [.process_packs[] | . as $pp | .workflow_refs[] | select(. as $r | $wfs | index($r) | not) | "\($pp.id):\(.)"] | unique | .[]
' "$CATALOG")"
if [[ -z "$bad_refs" ]]; then
  pass "all process_pack workflow_refs resolve to catalog workflows"
else
  fail "invalid workflow_refs: $bad_refs"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
