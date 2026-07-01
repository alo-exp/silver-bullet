#!/usr/bin/env bash
# Structural tests for install-version row pass registry.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-row-pass-registry.XXXXXX")"
REGISTRY="${STATE_DIR}/.row-pass-registry.json"
trap 'rm -rf "$STATE_DIR"' EXIT

export SB_ROOT="$REPO_ROOT"
export SB_E2E_ROW_PASS_REGISTRY="$REGISTRY"
export SB_E2E_INSTALL_FP="claude@testsha12+testsurface12"
export SB_E2E_LIVE_RUNTIME=claude
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"

# shellcheck source=scripts/enterprise-e2e/lib/row-pass-registry.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/row-pass-registry.sh"

if [[ "$(enterprise_e2e_install_fingerprint)" == "claude@testsha12+testsurface12" ]]; then
  pass "install_fp honors SB_E2E_INSTALL_FP override"
else
  fail "install_fp override"
fi

enterprise_e2e_row_pass_registry_record 3 ".e2e-row3-attempt.log" true
if enterprise_e2e_row_pass_registry_has_pass 3; then
  pass "record + lookup row 3"
else
  fail "record + lookup row 3"
fi

if ! enterprise_e2e_row_pass_registry_has_pass 4; then
  pass "row 4 not registered"
else
  fail "row 4 should be absent"
fi

if [[ "$(enterprise_e2e_row_pass_registry_pass_count)" == "1" ]]; then
  pass "pass count = 1"
else
  fail "pass count expected 1 got $(enterprise_e2e_row_pass_registry_pass_count)"
fi

rows="$(enterprise_e2e_row_pass_registry_list_rows | tr '\n' ' ')"
if [[ "$rows" == "3 " || "$rows" == "3" ]]; then
  pass "list_rows returns 3"
else
  fail "list_rows got '${rows}'"
fi

# Legacy by_install migration → installs[canonical install_fp]
LEGACY_REG="${STATE_DIR}/legacy-registry.json"
export SB_E2E_ROW_PASS_REGISTRY="$LEGACY_REG"
cat >"$LEGACY_REG" <<'JSON'
{
  "version": 1,
  "by_install": {
    "claude:0.49.1": {
      "install_fp": "claude:0.49.1",
      "rows": {
        "1": {"passed_at": "2026-07-01T12:00:00Z", "log_ref": ".e2e-row1.log", "outcome_pass": true},
        "6": {"passed_at": "2026-07-01T12:10:00Z", "log_ref": ".e2e-row6.log", "outcome_pass": true}
      }
    }
  }
}
JSON
export SB_E2E_INSTALL_FP="claude@89e2ab8f96a1+724a435c9991"
migrated="$(enterprise_e2e_row_pass_registry_migrate_legacy)"
if [[ "${migrated:-0}" -eq 2 ]]; then
  pass "migrate_legacy copies 2 rows"
else
  fail "migrate_legacy expected 2 got ${migrated:-0}"
fi
if enterprise_e2e_row_pass_registry_has_pass 1 && enterprise_e2e_row_pass_registry_has_pass 6; then
  pass "migrated rows 1 and 6 on canonical install_fp"
else
  fail "migrated rows missing on canonical install_fp"
fi
if ! jq -e '.by_install' "$LEGACY_REG" >/dev/null 2>&1; then
  pass "migrate_legacy removes by_install key"
else
  fail "by_install should be removed after migration"
fi
migrated_again="$(enterprise_e2e_row_pass_registry_migrate_legacy)"
if [[ "${migrated_again:-0}" -eq 0 ]]; then
  pass "migrate_legacy is idempotent"
else
  fail "migrate_legacy should be idempotent got ${migrated_again:-0}"
fi

# Matrix dry-run: registry skip counts as PASS not SKIP
export SB_E2E_ROW_PASS_REGISTRY="$REGISTRY"
export SB_E2E_INSTALL_FP="claude@testsha12+testsurface12"
enterprise_e2e_row_pass_registry_record 3 ".e2e-row3-attempt.log" true
export SB_E2E_MATRIX_DRY_RUN=1
export SB_ENTERPRISE_E2E_LIVE=1
MATRIX_OUT="$(bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 3 2>&1)" || true
if printf '%s\n' "$MATRIX_OUT" | grep -q 'ROW_ALREADY_PASSED_SAME_INSTALL'; then
  pass "matrix emits ROW_ALREADY_PASSED_SAME_INSTALL for registered row"
else
  fail "matrix registry skip message missing"
fi
if printf '%s\n' "$MATRIX_OUT" | grep -q 'Pass:  1'; then
  pass "registry skip increments Pass not Skip"
else
  fail "registry skip should count as Pass"
fi

# Seed registry on main worktree
reg="${REPO_ROOT}/.planning/enterprise-e2e/.row-pass-registry.json"
[[ -f "$reg" ]] && pass "seed registry exists" || fail "seed registry exists"
CANONICAL_FP="claude@89e2ab8f96a1+724a435c9991"
if jq -e --arg fp "$CANONICAL_FP" '.installs[$fp].rows["1"]' "$reg" >/dev/null 2>&1; then
  pass "seed registry has row 1 @ canonical install_fp"
else
  fail "seed registry missing row 1 @ canonical install_fp"
fi
for row in 3 4 7; do
  if jq -e --arg fp "$CANONICAL_FP" --arg r "$row" '.installs[$fp].rows[$r]' "$reg" >/dev/null 2>&1; then
    pass "seed registry has row ${row} @ canonical install_fp"
  else
    fail "seed registry missing row ${row} @ canonical install_fp"
  fi
done

if [[ "$FAIL" -eq 0 ]]; then
  echo ""
  echo "All ${PASS} tests passed"
  exit 0
fi

echo ""
echo "${FAIL} test(s) failed, ${PASS} passed"
exit 1
