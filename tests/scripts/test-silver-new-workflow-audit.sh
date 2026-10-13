#!/usr/bin/env bash
# Tests for /sb:new-workflow Audit mode — compliance script + skill contract.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
PASS=0 FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

[[ -x scripts/audit-workflow-compliance.sh ]] && pass "audit script executable" || fail "audit script missing or not executable"
chmod +x scripts/audit-workflow-compliance.sh 2>/dev/null || true

grep -q 'Audit' skills/silver-new-workflow/SKILL.md && pass "skill Audit mode documented" || fail "skill missing Audit mode"
grep -q 'audit-workflow-compliance' skills/silver-new-workflow/SKILL.md && pass "skill references audit script" || fail "skill missing audit script ref"
grep -q 'audit workflow' skills/silver/SKILL.md && pass "router audit triggers" || fail "router missing audit triggers"
grep -q 'Audit (read-only)' docs/NEW-WORKFLOW.md && pass "runbook audit section" || fail "runbook missing audit section"

# Known-good workflow: silver-new-workflow (meta workflow)
if bash scripts/audit-workflow-compliance.sh --target WF-SILVER-NEW-WORKFLOW 2>&1 | grep -q 'VERDICT: PASS'; then
  pass "audit WF-SILVER-NEW-WORKFLOW PASS"
else
  fail "audit WF-SILVER-NEW-WORKFLOW expected PASS"
fi

# Known-good workflow: silver-feature via slug alias
if bash scripts/audit-workflow-compliance.sh --slug feature 2>&1 | grep -q 'VERDICT: PASS'; then
  pass "audit silver-feature PASS"
else
  fail "audit silver-feature expected PASS"
fi

# validate-workflow-authoring --audit delegation
if bash scripts/validate-workflow-authoring.sh --audit --target silver-new-workflow 2>&1 | grep -q 'VERDICT: PASS'; then
  pass "validate --audit delegation PASS"
else
  fail "validate --audit delegation expected PASS"
fi

echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
