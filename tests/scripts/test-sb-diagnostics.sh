#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/sb-diagnostics.sh"
PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc — missing $path"
  fi
}

assert_executable() {
  local desc="$1" path="$2"
  if [[ -x "$path" ]]; then
    pass "$desc"
  else
    fail "$desc — not executable: $path"
  fi
}

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF -- "$needle" "$path"; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $path"
  fi
}

assert_output_contains() {
  local desc="$1" needle="$2"
  shift 2
  local out
  out="$("$@" 2>&1 || true)"
  if grep -qF -- "$needle" <<<"$out"; then
    pass "$desc"
  else
    fail "$desc — output missing [$needle]"
  fi
}

assert_file_exists "sb-diagnostics script exists" "$SCRIPT"
chmod +x "$SCRIPT"
assert_executable "sb-diagnostics is executable" "$SCRIPT"

assert_file_contains "runtime compatibility documents capability tiers" \
  "$REPO_ROOT/docs/RUNTIME-COMPATIBILITY.md" "Runtime Capability Tiers"
assert_file_contains "evidence schema doc exists" \
  "$REPO_ROOT/docs/evidence-schema.md" "Canonical Finding Fields"
assert_file_contains "code intelligence contract exists" \
  "$REPO_ROOT/docs/code-intelligence-contract.md" "Capability Tiers"
assert_file_contains "external review policy exists" \
  "$REPO_ROOT/docs/external-review-policy.md" "authoritative"
assert_file_contains "interface state template exists" \
  "$REPO_ROOT/templates/interface/STATE.md.base" "Design Tokens"
assert_file_contains "silver-add documents fingerprinting" \
  "$REPO_ROOT/skills/silver-add/SKILL.md" "Structured Audit Findings"

assert_output_contains "diagnostics emits Results line" "Results:" bash "$SCRIPT"
assert_output_contains "diagnostics checks jq" "jq" bash "$SCRIPT"
assert_output_contains "diagnostics reports capability tier" "runtime-capability-tier" bash "$SCRIPT"
diag_out="$(bash "$SCRIPT" 2>&1 || true)"
if grep 'graphify-cli' >/dev/null <<<"$diag_out"; then
  pass "diagnostics checks graphify CLI"
elif grep -Eq 'graphify-cli|graphify[[:space:]]' >/dev/null <<<"$diag_out"; then
  pass "diagnostics reports graphify status when CLI absent"
else
  fail "diagnostics checks graphify CLI — output missing graphify status"
fi

grep -q 'optimize-score' "$SCRIPT" && pass "diagnostics includes optimize-score" || fail "diagnostics optimize-score"
grep -q 'stack-optimizer' "$SCRIPT" && pass "diagnostics sources stack-optimizer" || fail "diagnostics stack-optimizer"
grep -q 'optimize-gitleaks' "$SCRIPT" && pass "diagnostics includes optimize-gitleaks" || fail "diagnostics optimize-gitleaks"

json_out="$(SB_DIAG_FORMAT=json bash "$SCRIPT" 2>&1 || true)"
if jq -e '.capability_tier' >/dev/null <<<"$json_out"; then
  pass "json diagnostics includes capability_tier"
else
  fail "json diagnostics includes capability_tier"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
