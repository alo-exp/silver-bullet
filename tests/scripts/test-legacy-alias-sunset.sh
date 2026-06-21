#!/usr/bin/env bash
# Enforce gsd-* legacy alias sunset date (BLOCKED removal until 2026-09-01).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/legacy-skill-alias.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

today="$(date -u +%Y-%m-%d)"

if [[ -z "${SB_LEGACY_ALIAS_SUNSET_DATE:-}" ]]; then
  echo "FAIL: SB_LEGACY_ALIAS_SUNSET_DATE not defined in legacy-skill-alias.sh"
  FAIL=$((FAIL + 1))
else
  echo "PASS: sunset date declared ($SB_LEGACY_ALIAS_SUNSET_DATE)"
  PASS=$((PASS + 1))
fi

if [[ "$SB_LEGACY_ALIAS_SUNSET_DATE" == "2026-09-01" ]]; then
  echo "PASS: sunset date is 2026-09-01"
  PASS=$((PASS + 1))
else
  echo "FAIL: unexpected sunset date (expected 2026-09-01, got $SB_LEGACY_ALIAS_SUNSET_DATE)"
  FAIL=$((FAIL + 1))
fi

if [[ "$today" < "$SB_LEGACY_ALIAS_SUNSET_DATE" ]]; then
  echo "PASS: aliases remain active before sunset ($today < $SB_LEGACY_ALIAS_SUNSET_DATE)"
  PASS=$((PASS + 1))
  normalized="$(sb_legacy_skill_alias_normalize 'gsd-scan')"
  if [[ "$normalized" == "silver-orient" ]]; then
    echo "PASS: gsd-scan still maps to silver-orient before sunset"
    PASS=$((PASS + 1))
  else
    echo "FAIL: gsd-scan mapping broken before sunset (got $normalized)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "INFO: sunset date reached — post-sunset removal may proceed"
  PASS=$((PASS + 1))
fi

scenario_count="$(find "$REPO_ROOT/tests/skill-scenarios" -maxdepth 1 -name 'gsd-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$scenario_count" -ge 19 ]]; then
  echo "PASS: gsd-* skill scenarios present ($scenario_count) until sunset retirement"
  PASS=$((PASS + 1))
else
  echo "FAIL: expected >=19 gsd-* skill scenarios before sunset (found $scenario_count)"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
