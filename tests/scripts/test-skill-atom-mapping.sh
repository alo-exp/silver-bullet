#!/usr/bin/env bash
# Production catalog skill↔atom resolution via migration_map + fallbacks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROD_CATALOG="$REPO_ROOT/docs/apo-catalog.json"
FIXTURE="$REPO_ROOT/tests/fixtures/scheduler/apo-scheduler-fixture.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-skill-atom.sh"

resolve() {
  sb_scheduler_resolve_atom_id "$1" "$2" 2>/dev/null || true
}

for pair in \
  "silver-context:AF-ORIENT" \
  "silver-plan:AF-PLAN" \
  "silver-execute:AF-EXECUTE" \
  "FLOW-QUALITY-GATE:AF-QUALITY-GATE" \
  "silver-review-request:AF-REVIEW-REQUEST" \
  "silver-validate:AF-VALIDATE" \
  "security:AF-SECURE" \
  "AF-VERIFY:AF-VERIFY"; do
  token="${pair%%:*}"
  want="${pair##*:}"
  got="$(resolve "$PROD_CATALOG" "$token")"
  if [[ "$got" == "$want" ]]; then
    pass "production $token → $want"
  else
    fail "production $token expected $want (got ${got:-empty})"
  fi
done

# gsd alias fallback
got="$(resolve "$PROD_CATALOG" "verification-before-completion")"
if [[ "$got" == "AF-COMPLETION-AUDIT" ]]; then
  pass "gsd alias verification-before-completion → AF-COMPLETION-AUDIT"
else
  fail "gsd alias resolution (got ${got:-empty})"
fi

# Fixture slug-derived skill without explicit map entry (silver-fixture-serial → slug)
got="$(resolve "$FIXTURE" "silver-fixture-serial")"
if [[ "$got" == "AF-FIXTURE-SERIAL" ]]; then
  pass "slug fallback silver-fixture-serial → AF-FIXTURE-SERIAL"
else
  fail "slug fallback (got ${got:-empty})"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
