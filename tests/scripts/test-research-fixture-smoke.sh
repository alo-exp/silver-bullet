#!/usr/bin/env bash
# Smoke validators for canonical research/ fixture trees (see research/README.md).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS="$REPO_ROOT/skills/silver-deep-research/scripts"
LANDSCAPE="$REPO_ROOT/research/2026-07-09-fixture-landscape"
COMPARE="$REPO_ROOT/research/2026-07-09-fixture-compare"

PASS=0
FAIL=0

assert_pass() {
  local label="$1"
  shift
  local out
  if out="$("$@" 2>&1)"; then
    if printf '%s\n' "$out" | grep -q '"status": "pass"'; then
      echo "PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $label (unexpected output)"
      printf '%s\n' "$out"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "FAIL: $label"
    printf '%s\n' "$out"
    FAIL=$((FAIL + 1))
  fi
}

assert_pass "landscape fixture validates" \
  python3 "$SCRIPTS/validate_landscape.py" --dir "$LANDSCAPE"

assert_pass "compare fixture validates" \
  python3 "$SCRIPTS/validate_compare.py" --dir "$COMPARE"

assert_pass "landscape report.html SPA validates" \
  python3 "$SCRIPTS/validate_spa_report.py" --report "$LANDSCAPE/report.html" --profile general

assert_pass "compare report.html SPA validates" \
  python3 "$SCRIPTS/validate_spa_report.py" --report "$COMPARE/report.html" --profile general

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

