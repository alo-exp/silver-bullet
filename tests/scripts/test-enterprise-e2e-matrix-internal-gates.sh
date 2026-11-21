#!/usr/bin/env bash
# Rows 21-22 internal gates: derived from parent rows 3/4. With no parent evidence they FAIL and seed
# nothing (R14-02); with a passing ledger row for the parent they pass and write the marker.
set -euo pipefail

PASS=0
FAIL=0

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
FIXTURE="$(mktemp -d "${TMPDIR}/sb-matrix-internal-gates.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

# State of the checkout's own pass-at-version registry (operators' runs keep one there by
# design): the dry runs below must leave it exactly as it was.
CHECKOUT_REGISTRY="${REPO_ROOT}/.e2e-matrix-pass-at-version.tsv"
registry_state() { cksum <"$CHECKOUT_REGISTRY" 2>/dev/null || echo absent; }
registry_before="$(registry_state)"

mkdir -p "$FIXTURE/.planning/workflows" "$FIXTURE/.planning/enterprise-e2e"

out="$(SB_E2E_MATRIX_DRY_RUN=1 \
  SB_E2E_TEST_APP_BRANCH_ENFORCE=0 \
  SB_E2E_FIXTURE_BRANCH_LOCK=0 \
  SB_E2E_HOST_GIT_BRANCH_ENFORCE=0 \
  SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE" \
  SB_E2E_PASS_AT_VERSION_REGISTRY="$FIXTURE/.e2e-matrix-pass-at-version.tsv" \
  SB_E2E_ROW_PASS_REGISTRY="$FIXTURE/.planning/enterprise-e2e/.row-pass-registry.json" \
  bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 22 2>&1)" || true

assert_ok "dry-run row 22 internal FAILS without parent evidence" grep -q 'validate-substep (internal) FAIL' <<<"$out"
assert_ok "bugfix-health.md is not seeded without evidence" \
  test ! -e "$FIXTURE/.planning/workflows/bugfix-health.md"

out21="$(SB_E2E_MATRIX_DRY_RUN=1 \
  SB_E2E_TEST_APP_BRANCH_ENFORCE=0 \
  SB_E2E_FIXTURE_BRANCH_LOCK=0 \
  SB_E2E_HOST_GIT_BRANCH_ENFORCE=0 \
  SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE" \
  SB_E2E_PASS_AT_VERSION_REGISTRY="$FIXTURE/.e2e-matrix-pass-at-version.tsv" \
  SB_E2E_ROW_PASS_REGISTRY="$FIXTURE/.planning/enterprise-e2e/.row-pass-registry.json" \
  bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 21 2>&1)" || true

assert_ok "dry-run row 21 internal FAILS without parent evidence" grep -q 'post-exec-gates (internal) FAIL' <<<"$out21"
assert_ok "feature-currency.md is not seeded without evidence" \
  test ! -e "$FIXTURE/.planning/workflows/feature-currency.md"

# the parent rows passed in the ledger: markers are written and rows 21/22 pass
LEDGER="$FIXTURE/ledger.md"
cat >"$LEDGER" <<'EOL'
| 3 | `silver-feature` | wf | evidence | Pass | n | n | n | graph-ref | mem-ref |
| 4 | `silver-bugfix` | wf | evidence | Pass | n | n | n | graph-ref | mem-ref |
EOL
outp="$(SB_E2E_MATRIX_DRY_RUN=1 \
  SB_E2E_TEST_APP_BRANCH_ENFORCE=0 \
  SB_E2E_FIXTURE_BRANCH_LOCK=0 \
  SB_E2E_HOST_GIT_BRANCH_ENFORCE=0 \
  SB_E2E_LEDGER_FILE="$LEDGER" \
  SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE" \
  SB_E2E_PASS_AT_VERSION_REGISTRY="$FIXTURE/.e2e-matrix-pass-at-version.tsv" \
  SB_E2E_ROW_PASS_REGISTRY="$FIXTURE/.planning/enterprise-e2e/.row-pass-registry.json" \
  bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 21 22 2>&1)" || true
assert_ok "row 21 passes when the ledger records row 3 as Pass" grep -q 'post-exec-gates (internal) PASS' <<<"$outp"
assert_ok "row 22 passes when the ledger records row 4 as Pass" grep -q 'validate-substep (internal) PASS' <<<"$outp"
assert_ok "feature-currency.md seeded with post-exec-gates" \
  grep -q 'post-exec-gates' "$FIXTURE/.planning/workflows/feature-currency.md"
assert_ok "bugfix-health.md seeded with validate-substep" \
  grep -q 'validate-substep' "$FIXTURE/.planning/workflows/bugfix-health.md"

assert_ok "pass-at-version registry in the checkout is unchanged" \
  test "$registry_before" = "$(registry_state)"
assert_ok "dry-run rows were recorded in the fixture registry instead" \
  test -s "$FIXTURE/.e2e-matrix-pass-at-version.tsv"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
