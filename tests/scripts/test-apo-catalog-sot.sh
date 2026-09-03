#!/usr/bin/env bash
# Asserts docs/apo-catalog.json is the sole authoritative APO catalog (Phase 2 SOT).
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

if [[ ! -f "$CATALOG" ]]; then
  echo "FAIL: missing authoritative catalog at docs/apo-catalog.json"
  exit 1
fi

pass "authoritative catalog exists at docs/apo-catalog.json"

if command -v jq >/dev/null 2>&1; then
  sot=$(jq -r '.meta.source_of_truth // ""' "$CATALOG")
  if [[ "$sot" == "docs/apo-catalog.json" ]]; then
    pass "catalog meta declares itself as source_of_truth"
  else
    fail "catalog meta.source_of_truth must be docs/apo-catalog.json (got: $sot)"
  fi
else
  echo "WARN: jq not available; skipping meta.source_of_truth assertion"
fi

# No parallel catalog JSON files under docs/ (excluding schema and generated/).
shopt -s nullglob
parallel_catalogs=()
for f in "$REPO_ROOT"/docs/apo-catalog*.json; do
  base=$(basename "$f")
  case "$base" in
    apo-catalog.json) ;;
    apo-catalog.schema.json) ;;
    *)
      parallel_catalogs+=("$base")
      ;;
  esac
done
shopt -u nullglob

if [[ ${#parallel_catalogs[@]} -eq 0 ]]; then
  pass "no parallel apo-catalog*.json files under docs/"
else
  fail "parallel catalog files found: ${parallel_catalogs[*]}"
fi

# Generated views must not claim SOT authority.
for view in \
  "$REPO_ROOT/docs/composable-flows-contracts.md" \
  "$REPO_ROOT/docs/workflow-composition-matrix.md"; do
  if [[ -f "$view" ]]; then
    if grep -qiE 'authoritative source of truth|sole authoritative|canonical composition authority' "$view" 2>/dev/null; then
      if grep -q 'apo-catalog.json' "$view" 2>/dev/null; then
        pass "${view#$REPO_ROOT/} references apo-catalog.json as authority (transitional OK)"
      else
        fail "${view#$REPO_ROOT/} claims composition authority without apo-catalog.json reference"
      fi
    else
      pass "${view#$REPO_ROOT/} does not claim standalone composition SOT (transitional)"
    fi
  fi
done

# templates/ must not host a competing catalog SOT.
if find "$REPO_ROOT/templates" -name 'apo-catalog.json' 2>/dev/null | grep -q .; then
  fail "templates/ contains apo-catalog.json parallel SOT"
else
  pass "templates/ has no apo-catalog.json parallel SOT"
fi

# hooks/scripts must not hardcode a second catalog path as authoritative.
if grep -rEl 'apo-catalog\.json.*authoritative|authoritative.*apo-catalog' \
  "$REPO_ROOT/hooks" "$REPO_ROOT/scripts" 2>/dev/null | grep -v test-apo-catalog; then
  fail "hooks/scripts claim alternate authoritative apo-catalog path"
else
  pass "hooks/scripts do not declare alternate authoritative catalog paths"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
