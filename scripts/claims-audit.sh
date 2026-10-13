#!/usr/bin/env bash
# CI audit: homepage marketing claims must be registered in docs/testing/claims-registry.json.
#
# Heuristics:
#   1. Every claim text in the registry must appear in site/index.html
#   2. Every data-claim="..." attribute on site/index.html must exist in the registry
#   3. Curated hero/mechanism phrases (registry texts) cover key promises
#
# Usage: RTK_DISABLED=1 bash scripts/claims-audit.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${REPO_ROOT}/docs/testing/claims-registry.json"
SITE="${REPO_ROOT}/site/index.html"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if [[ ! -f "$REGISTRY" ]]; then
  echo "FAIL: missing registry $REGISTRY" >&2
  exit 1
fi
if [[ ! -f "$SITE" ]]; then
  echo "FAIL: missing site $SITE" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required for claims-audit" >&2
  exit 1
fi

# Registry claim texts must appear on the homepage.
while IFS= read -r claim_text; do
  [[ -z "$claim_text" ]] && continue
  if grep -qF -- "$claim_text" "$SITE" 2>/dev/null; then
    pass "registry claim on site: ${claim_text:0:60}"
  else
    fail "registry claim missing from site: $claim_text"
  fi
done < <(jq -r '.claims[].text' "$REGISTRY")

# data-claim attributes must be registered.
while IFS= read -r claim_id; do
  [[ -z "$claim_id" ]] && continue
  if jq -e --arg id "$claim_id" '.claims[] | select(.claim_id == $id)' "$REGISTRY" >/dev/null 2>&1; then
    pass "data-claim registered: $claim_id"
  else
    fail "unregistered data-claim on site: $claim_id"
  fi
done < <(grep -oE 'data-claim="[^"]+"' "$SITE" 2>/dev/null | sed -E 's/data-claim="([^"]+)"/\1/' || true)

claim_count="$(jq '.claims | length' "$REGISTRY")"
if [[ "$claim_count" -ge 10 ]]; then
  pass "registry has ${claim_count} claims (minimum 10)"
else
  fail "registry too small (${claim_count} claims; need >= 10)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
