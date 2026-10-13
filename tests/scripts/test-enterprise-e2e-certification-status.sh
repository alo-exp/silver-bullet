#!/usr/bin/env bash
# Structural tests for enterprise E2E certification status generator.
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SB_ROOT="$REPO_ROOT"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle]"
  fi
}

SCRIPT="${REPO_ROOT}/scripts/enterprise-e2e-certification-status.sh"
SOURCES="${REPO_ROOT}/docs/testing/host-certification-sources.json"
BASELINE="${REPO_ROOT}/docs/testing/autonomous-enterprise-proof-baseline.json"

assert_executable "$SCRIPT" "certification-status script executable"
assert_file_exists "$SOURCES" "host-certification-sources.json exists"
assert_file_exists "$BASELINE" "autonomous-enterprise-proof-baseline.json exists"

if command -v jq >/dev/null 2>&1; then
  for host in cursor codex claude; do
    if jq -e --arg h "$host" '.hosts[$h].canonical_ledger' "$SOURCES" >/dev/null 2>&1; then
      pass "sources registry has canonical ledger for $host"
    else
      fail "sources registry missing canonical ledger for $host"
    fi
  done
  if jq -e '.vision_claims | length >= 8' "$BASELINE" >/dev/null 2>&1; then
    pass "proof baseline has >=8 vision claims"
  else
    fail "proof baseline too small"
  fi
else
  pass "jq checks skipped (jq not installed)"
fi

assert_contains "certification script sources ledger reconcile" "$SCRIPT" "enterprise-e2e-ledger-reconcile.sh"
assert_contains "certification script uses strict-clean-check" "$SCRIPT" "strict-clean-check.sh"
assert_contains "certification script reads host sources" "$SCRIPT" "host-certification-sources.json"

# BSD/macOS mktemp only randomizes a trailing run of X's — never put a suffix
# after the X's (cert-status.XXXXXX.json would be taken literally).
TMP_ARTIFACT_BASE="$(mktemp "${TEST_TMP}/cert-status.XXXXXX")"
TMP_ARTIFACT="${TMP_ARTIFACT_BASE}.json"
mv "$TMP_ARTIFACT_BASE" "$TMP_ARTIFACT"
trap 'rm -f "$TMP_ARTIFACT"; rm -rf "$TEST_TMP"' EXIT

if RTK_DISABLED=1 SB_CERT_ARTIFACT="$TMP_ARTIFACT" bash "$SCRIPT" --json --write >/dev/null 2>&1; then
  pass "certification-status --json --write exits 0"
else
  fail "certification-status --json --write failed"
fi

assert_file_exists "$TMP_ARTIFACT" "CERTIFICATION-STATUS.json written"

if command -v jq >/dev/null 2>&1; then
  if jq -e '.hosts | length == 3' "$TMP_ARTIFACT" >/dev/null 2>&1; then
    pass "artifact has 3 host entries"
  else
    fail "artifact host count != 3"
  fi
  if jq -e '.conservative_summary.public_autonomous_enterprise_claim_ready == false' "$TMP_ARTIFACT" >/dev/null 2>&1; then
    pass "artifact conservatively marks public claim not ready"
  else
    fail "artifact should not claim public autonomous enterprise ready"
  fi
  for host in cursor codex claude; do
    if jq -e --arg h "$host" '.hosts[] | select(.host == $h) | .proof_level' "$TMP_ARTIFACT" >/dev/null 2>&1; then
      pass "artifact includes proof_level for $host"
    else
      fail "artifact missing proof_level for $host"
    fi
  done
fi

# Ledger reconcile CLI smoke
if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh" --summary >/dev/null 2>&1; then
  pass "ledger-reconcile --summary runs"
else
  fail "ledger-reconcile --summary failed"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

