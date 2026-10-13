#!/usr/bin/env bash
# Tests site certification status regeneration and static mirror.
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REGEN="${REPO_ROOT}/scripts/regenerate-site-certification-status.sh"
SITE_JSON="${REPO_ROOT}/site/help/data/certification-status.json"
HTML="${REPO_ROOT}/site/help/concepts/autonomous-enterprise-status.html"
JS="${REPO_ROOT}/site/help/concepts/certification-status.js"

[[ -x "$REGEN" ]] && pass "regenerate script executable" || fail "regenerate script not executable"

REGEN_TMP="$(mktemp -d)"
trap 'rm -rf "$REGEN_TMP"' EXIT
if RTK_DISABLED=1 SB_CERT_ARTIFACT="${REGEN_TMP}/CERTIFICATION-STATUS.json" SB_CERT_SITE_COPY="${REGEN_TMP}/certification-status.json" bash "$REGEN" >/dev/null 2>&1; then
  pass "regenerate-site-certification-status exits 0"
else
  fail "regenerate-site-certification-status failed"
fi

[[ -f "$SITE_JSON" ]] && pass "site/help/data/certification-status.json exists" \
  || fail "site certification JSON missing"

if command -v jq >/dev/null 2>&1 && [[ -f "$SITE_JSON" ]]; then
  jq -e '.hosts | length == 3' "$SITE_JSON" >/dev/null && pass "site JSON has 3 hosts" \
    || fail "site JSON host count"
  jq -e '.conservative_summary.public_autonomous_enterprise_claim_ready == false' "$SITE_JSON" >/dev/null \
    && pass "site JSON conservatively marks claim not ready" \
    || fail "site JSON should not claim public ready"
fi

grep -qF 'cert-host-tbody' "$HTML" && pass "status HTML has cert-host-tbody" \
  || fail "status HTML missing cert-host-tbody"
grep -qF 'certification-status.js' "$HTML" && pass "status HTML loads certification-status.js" \
  || fail "status HTML missing certification-status.js script"
[[ -f "$JS" ]] && pass "certification-status.js exists" || fail "certification-status.js missing"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
