#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="${REPO_ROOT}/scripts/validate-evidence-findings.sh"
PY_VALIDATOR="${REPO_ROOT}/scripts/validate-evidence-findings.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/.planning/phases/01"

cat > "$WORKDIR/.planning/phases/01/DOMAIN-AUDIT.md" <<'EOF'
# Domain Audit

## Findings

| domain | scope | severity | confidence | evidence | finding | required_action | owner_workflow | blocking_status |
|--------|-------|----------|------------|----------|---------|-----------------|----------------|-----------------|
| code-health | src/app.ts | BLOCK | HIGH | src/app.ts:42 | null deref risk | fix now | sb:bugfix | blocks ship |
EOF

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_file_exists "$VALIDATOR" "validate-evidence-findings.sh exists"
assert_file_exists "$PY_VALIDATOR" "validate-evidence-findings.py exists"
chmod +x "$VALIDATOR"

out="$(bash "$VALIDATOR" "$WORKDIR" 2>&1)"
if grep -q "Evidence schema validation passed" <<<"$out"; then
  pass "valid finding tables pass"
else
  fail "valid finding tables pass — got: $out"
fi

cat > "$WORKDIR/.planning/phases/01/REVIEW.md" <<'EOF'
# Review

## Findings

| domain | scope | severity | confidence | evidence | finding |
|--------|-------|----------|------------|----------|---------|
| code-health | src/app.ts | BLOCK | HIGH | src/app.ts:1 | missing required columns |
EOF

out="$(bash "$VALIDATOR" "$WORKDIR" 2>&1 || true)"
if grep -qi "missing required columns" <<<"$out"; then
  pass "malformed table warns on missing columns"
else
  fail "malformed table warns on missing columns — got: $out"
fi

json="$(python3 "$PY_VALIDATOR" --root "$WORKDIR" --json)"
if jq -e '.warnings | length > 0' >/dev/null <<<"$json"; then
  pass "json output includes warnings"
else
  fail "json output includes warnings"
fi

strict_rc=0
python3 "$PY_VALIDATOR" --root "$WORKDIR" --strict >/dev/null 2>&1 || strict_rc=$?
if [[ "$strict_rc" -ne 0 ]]; then
  pass "strict mode exits non-zero on warnings"
else
  fail "strict mode exits non-zero on warnings"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
