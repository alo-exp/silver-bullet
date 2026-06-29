#!/usr/bin/env bash
# Structural + fixture tests for enterprise E2E outcome assessment rubric.
# CI-safe — no live Claude TUI required.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SB_ROOT="$REPO_ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-outcome-assess.XXXXXX")"
OUT_DIR="$(mktemp -d "${TMPDIR}/sb-outcome-out.XXXXXX")"
trap 'rm -rf "$STATE_DIR" "$OUT_DIR"' EXIT

# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

# --- Structural wiring ---
if enterprise_e2e_outcome_assess_structural_wiring; then
  pass "outcome assessment structural wiring complete"
else
  fail "outcome assessment structural wiring incomplete"
fi

# --- Rubric documents all 18 criterion IDs ---
RUBRIC="${REPO_ROOT}/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md"
for cid in $(enterprise_e2e_outcome_criteria_ids); do
  if grep -q "$cid" "$RUBRIC" 2>/dev/null; then
    pass "rubric defines $cid"
  else
    fail "rubric missing $cid"
  fi
done

# --- Registry JSON validity ---
REGISTRY="${REPO_ROOT}/docs/testing/outcome-criteria-registry.json"
if command -v jq >/dev/null 2>&1; then
  if jq -e '.criteria | length >= 18' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry has >=18 criteria"
  else
    fail "registry criteria count < 18"
  fi
  if jq -e '.workflow_row_map["1"] | length >= 4' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry workflow_row_map row 1 populated"
  else
    fail "registry workflow_row_map row 1 missing"
  fi
  if jq -e '.session_criteria | length >= 5' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry session_criteria populated"
  else
    fail "registry session_criteria missing"
  fi
else
  pass "registry jq checks skipped (jq not installed)"
fi

# --- Fixture: row 3 feature workflow scoring ---
mkdir -p "$FIXTURE/.planning/workflows" "$FIXTURE/.planning/ship-readiness" 2>/dev/null || true
mkdir -p "$STATE_DIR"
printf 'silver-context\nsilver-feature\nsilver-quality-gates\n' >"$STATE_DIR/state"
cat >"$FIXTURE/.planning/PLAN-feature.md" <<'EOF'
# Plan — currency feature
EOF
cat >"$FIXTURE/.planning/VALIDATION-feature.md" <<'EOF'
# Validation — currency feature
EOF
cat >"$FIXTURE/.planning/QUALITY-GATES-feature.md" <<'EOF'
# Quality gates
EOF
cat >"$FIXTURE/.planning/workflows/feature-currency.md" <<'EOF'
# Feature currency
post-exec-gates evidence
Flow Log
| step | status |
| VALIDATE | pass |
EOF

row_scores="$(enterprise_e2e_outcome_assess_workflow_row 3 "$FIXTURE" "$STATE_DIR" "" "" "api/")"
if printf '%s\n' "$row_scores" | grep -q 'OUT-GATES-01 pass'; then
  pass "fixture row 3 OUT-GATES-01 pass"
else
  fail "fixture row 3 OUT-GATES-01 expected pass — got [$row_scores]"
fi
if printf '%s\n' "$row_scores" | grep -q 'OUT-VLOOP-01 pass'; then
  pass "fixture row 3 OUT-VLOOP-01 pass"
else
  fail "fixture row 3 OUT-VLOOP-01 expected pass"
fi
session_scores_r3="$(enterprise_e2e_outcome_assess_session "" "$STATE_DIR" "$FIXTURE")"
if printf '%s\n' "$session_scores_r3" | grep -q 'OUT-SKILL-01 pass'; then
  pass "fixture row 3 session OUT-SKILL-01 pass"
else
  fail "fixture row 3 session OUT-SKILL-01 expected pass"
fi

# --- Fixture: row 1 router tailoring ---
printf 'silver-context\n' >"$STATE_DIR/state"
rm -f "$FIXTURE/.planning/workflows/router-session.md" 2>/dev/null || true
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session
EOF
score_tailor="$(enterprise_e2e_outcome_score_criterion OUT-TAILOR-01 "$FIXTURE" "$STATE_DIR" "" 1)"
[[ "$score_tailor" == "pass" ]] && pass "fixture row 1 OUT-TAILOR-01 pass" || fail "fixture row 1 OUT-TAILOR-01 got $score_tailor"

# --- Fixture: row 6 fast path gates n/a ---
score_gates6="$(enterprise_e2e_outcome_score_criterion OUT-GATES-01 "$FIXTURE" "$STATE_DIR" "" 6)"
[[ "$score_gates6" == "pass" ]] && pass "fixture row 6 OUT-GATES-01 pass (fast-path skip)" || fail "fixture row 6 OUT-GATES-01 got $score_gates6"

# --- Session checklist scoring ---
SESSION_LOG="$(mktemp)"
printf 'graphify query silver-feature routes hooks\nTask worker spawned\n' >"$SESSION_LOG"
session_scores="$(enterprise_e2e_outcome_assess_session "$SESSION_LOG" "$STATE_DIR" "$FIXTURE")"
if printf '%s\n' "$session_scores" | grep -qE 'OUT-CODEINT-01 (pass|partial)'; then
  pass "session OUT-CODEINT-01 scored from log"
else
  fail "session OUT-CODEINT-01 not scored"
fi
if printf '%s\n' "$session_scores" | grep -qE 'OUT-SKILL-01 pass'; then
  pass "session OUT-SKILL-01 pass"
else
  fail "session OUT-SKILL-01 expected pass"
fi
rm -f "$SESSION_LOG"

# --- Workflow checklist writer ---
CHECKLIST="${OUT_DIR}/row-3-outcomes.md"
enterprise_e2e_outcome_write_workflow_checklist 3 "$CHECKLIST" "$FIXTURE" "$STATE_DIR" "" "" "api/"
if [[ -f "$CHECKLIST" ]] && grep -q 'OUT-GATES-01' "$CHECKLIST" && grep -q 'session' "$CHECKLIST"; then
  pass "workflow checklist writer emits workflow + session tables"
else
  fail "workflow checklist writer output invalid"
fi

# --- Round scoring fixture ---
LEDGER_FIXTURE="$(mktemp)"
cat >"$LEDGER_FIXTURE" <<'LEDGER'
## review-fix-ladder (8 rungs × 2 clean verify)
| 1 | composer-2.5 | **Pass** | **Pass** |
| 2 | composer-2.5 | **Pass** | **Pass** |
| 3 | composer-2.5 | **Pass** | **Pass** |
| 4 | composer-2.5 | **Pass** | **Pass** |
| 5 | gpt-5.5 | **Pass** | **Pass** |
| 6 | gpt-5.5 | **Pass** | **Pass** |
| 7 | gpt-5.5 | **Pass** | **Pass** |
| 8 | gpt-5.5 | **Pass** | **Pass** |

| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |
|---|---------|-----------|--------------------|------------------------|
| 1 | `silver-router` | Pass | gq-1 | am-1 |
LEDGER
round_review="$(enterprise_e2e_outcome_score_criterion OUT-REVIEW-01 "$FIXTURE" "$STATE_DIR" "" "" "$LEDGER_FIXTURE")"
[[ "$round_review" == "pass" ]] && pass "round OUT-REVIEW-01 pass from ladder fixture" || fail "round OUT-REVIEW-01 got $round_review"
rm -f "$LEDGER_FIXTURE"

# --- ROUND-N-OUTCOMES template references rubric ---
OUTCOMES_TEMPLATE="${REPO_ROOT}/.planning/enterprise-e2e/ROUND-N-OUTCOMES.md"
for needle in OUT-TAILOR-01 OUT-REVIEW-01 OUT-MEASURE-01 "Per-session checklist"; do
  if grep -qF "$needle" "$OUTCOMES_TEMPLATE" 2>/dev/null; then
    pass "ROUND-N-OUTCOMES template includes $needle"
  else
    fail "ROUND-N-OUTCOMES template missing $needle"
  fi
done

# --- Claim ID style WBS-VLOOP-01 alias: registry uses OUT-* prefix ---
if grep -q 'OUT-VLOOP-01' "$REGISTRY" && grep -q 'OUT-VLOOP-01' "$RUBRIC"; then
  pass "V-loop criterion OUT-VLOOP-01 registered (WBS-VLOOP-01 style)"
else
  fail "OUT-VLOOP-01 not in registry+rubric"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
