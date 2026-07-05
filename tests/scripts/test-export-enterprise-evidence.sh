#!/usr/bin/env bash
# Smoke test for enterprise evidence export scaffold.
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXPORT="${REPO_ROOT}/scripts/export-enterprise-evidence.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

[[ -x "$EXPORT" ]] && pass "export script executable" || fail "export script not executable"

mkdir -p "$WORK/docs/sessions" "$WORK/.planning"
echo '{"ts":"test"}' >"$WORK/.planning/orchestrator-composition-log.jsonl"
cat >"$WORK/docs/sessions/2026-07-06-test.md" <<'EOF'
## Active Intent Ledger
- test intent claim
EOF

OUT_ZIP="$WORK/dist/test-evidence.zip"
if bash "$EXPORT" "$WORK" "$OUT_ZIP" >/dev/null 2>&1; then
  pass "export-enterprise-evidence exits 0"
else
  fail "export-enterprise-evidence failed"
fi

[[ -f "$OUT_ZIP" ]] && pass "export zip created" || fail "export zip missing"

manifest_ok=0
if unzip -p "$OUT_ZIP" manifest.json 2>/dev/null | jq -e '.schema_version' >/dev/null 2>&1; then
  manifest_ok=1
fi
if [[ "$manifest_ok" -eq 1 ]]; then
  pass "zip contains manifest.json"
else
  fail "zip missing manifest.json"
fi

if unzip -l "$OUT_ZIP" 2>/dev/null | grep -q 'apo-audit-entities.json'; then
  pass "zip contains apo-audit-entities.json"
else
  fail "zip missing apo-audit-entities.json"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
