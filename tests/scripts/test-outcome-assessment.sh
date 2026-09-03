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
export SB_E2E_OUTCOME_ASSESS_FIXTURE=1
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-outcome-assess.XXXXXX")"
OUT_DIR="$(mktemp -d "${TMPDIR}/sb-outcome-out.XXXXXX")"
# shellcheck source=tests/scripts/lib/enterprise-e2e-fixture.sh
source "${REPO_ROOT}/tests/scripts/lib/enterprise-e2e-fixture.sh"
enterprise_e2e_test_fixture_init "$REPO_ROOT"
trap 'rm -rf "$STATE_DIR" "$OUT_DIR" ${enterprise_e2e_test_fixture_temp:+"$enterprise_e2e_test_fixture_temp"}' EXIT

# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

# --- Structural wiring ---
if enterprise_e2e_outcome_assess_structural_wiring; then
  pass "outcome assessment structural wiring complete"
else
  fail "outcome assessment structural wiring incomplete"
fi

# --- Rubric documents all criterion IDs ---
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
  if jq -e '.criteria | length >= 27' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry has >=27 criteria"
  else
    fail "registry criteria count < 27"
  fi
  if jq -e '.blocking_criteria | length >= 6' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry blocking_criteria has >=6 entries"
  else
    fail "registry blocking_criteria missing (need OUT-AUTO-01, OUT-CLARIFY-01, OUT-NOOP-01, OUT-ORCH-01, OUT-WORLD-01, OUT-MEASURE-01)"
  fi
  if jq -e '.blocking_criteria | index("OUT-ORCH-01")' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry blocking includes OUT-ORCH-01"
  else
    fail "registry blocking missing OUT-ORCH-01"
  fi
  if jq -e '.blocking_criteria | index("OUT-MEASURE-01")' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry blocking includes OUT-MEASURE-01"
  else
    fail "registry blocking missing OUT-MEASURE-01"
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
if [[ ! -f "$FIXTURE/.silver-bullet.json" ]]; then
  printf '%s\n' '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$FIXTURE/.silver-bullet.json"
fi
mkdir -p "$STATE_DIR"
if [[ ! -f "$FIXTURE/.silver-bullet.json" ]]; then
  cat >"$FIXTURE/.silver-bullet.json" <<'EOF'
{
  "recommended_tools": {
    "graphify": { "enabled_by_user": true },
    "agentmemory": { "enabled_by_user": true }
  }
}
EOF
fi
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
cat >"$FIXTURE/.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260716-20260716T000000Z.md" <<'EOF'
# Clarify — currency feature
locked decision: use ISO 4217 currency codes
decision_class: locked
EOF
cat >"$FIXTURE/.planning/workflows/feature-currency.md" <<'EOF'
# Feature currency
post-exec-gates evidence
deviation logged and realigned to prompt
Flow Log
| step | status |
| VALIDATE | pass |
EOF
mkdir -p "$FIXTURE/api"
touch "$FIXTURE/api/.gitkeep"
SESSION_LOG_R3="$(mktemp)"
printf 'autonomous orchestrator active\nTask worker spawned\nwbs-supervisor stub\n/silver:clarify locked decisions applied\ngraphify query silver-feature routes hooks\n' >"$SESSION_LOG_R3"
cat >"$STATE_DIR/orchestrator-worker-active.json" <<'EOF'
{"worker":"feature"}
EOF
cat >"$FIXTURE/.planning/SPEC-feature.md" <<'EOF'
# Spec — currency field
EOF
cat >"$FIXTURE/.planning/workflows/20260630T120000Z-feature-currency.md" <<'EOF'
# Feature currency dated workflow
deviation logged and realigned to prompt
Flow Log
| step | status |
| VALIDATE | pass |
EOF

row_scores="$(enterprise_e2e_outcome_assess_workflow_row 3 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R3" "" "api/")"
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
# --- Fixture: row 3 autonomy + clarify + world composite ---
score_auto="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R3" 3 "" "api/")"
[[ "$score_auto" == "pass" ]] && pass "fixture row 3 OUT-AUTO-01 pass" || fail "fixture row 3 OUT-AUTO-01 got $score_auto"
score_clarify="$(enterprise_e2e_outcome_score_criterion OUT-CLARIFY-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R3" 3)"
[[ "$score_clarify" == "pass" ]] && pass "fixture row 3 OUT-CLARIFY-01 pass" || fail "fixture row 3 OUT-CLARIFY-01 got $score_clarify"
score_world="$(enterprise_e2e_outcome_score_criterion OUT-WORLD-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R3" 3 "" "api/")"
[[ "$score_world" == "pass" ]] && pass "fixture row 3 OUT-WORLD-01 composite pass" || fail "fixture row 3 OUT-WORLD-01 got $score_world"
if enterprise_e2e_outcome_row_passes 3 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R3" "" "api/"; then
  pass "fixture row 3 enterprise_e2e_outcome_row_passes"
else
  fail "fixture row 3 enterprise_e2e_outcome_row_passes expected pass"
fi
# Negative: babysitting log fails AUTO + row_passes
BAD_LOG="$(mktemp)"
printf 'waiting for your input before continuing\n' >"$BAD_LOG"
score_auto_fail="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$FIXTURE" "$STATE_DIR" "$BAD_LOG" 3 "" "api/")"
[[ "$score_auto_fail" == "partial" || "$score_auto_fail" == "fail" ]] && pass "fixture OUT-AUTO-01 fails on babysitting log" || fail "fixture OUT-AUTO-01 babysitting got $score_auto_fail"
if enterprise_e2e_outcome_row_passes 3 "$FIXTURE" "$STATE_DIR" "$BAD_LOG" "" "api/"; then
  fail "fixture row 3 row_passes should fail on babysitting log"
else
  pass "fixture row 3 row_passes fails on babysitting log"
fi
rm -f "$BAD_LOG"
rm -f "$STATE_DIR/orchestrator-worker-active.json"

# E2E-096: negated autonomy summary must not trip babysitting (row 10 stream-json)
mkdir -p "$FIXTURE/docs"
touch "$FIXTURE/docs/API.md"
ROW10_FP_LOG="$(mktemp)"
cat >"$ROW10_FP_LOG" <<'LOG'
HARNESS graphify: graphify query "silver-content routes hooks skills orchestrator"
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"autonomous_default applied — no clarify menus or operator pauses"}]}}
{"type":"result","subtype":"success","result":"Workflow complete — matrix row 10 PASS. autonomous_default applied — no clarify menus or operator pauses"}
LOG
if enterprise_e2e_outcome_log_has_babysitting "$ROW10_FP_LOG"; then
  fail "E2E-096 negated operator-pause summary should not trigger babysitting"
else
  pass "E2E-096 negated operator-pause summary does not trigger babysitting"
fi
score_auto_r10="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$FIXTURE" "$STATE_DIR" "$ROW10_FP_LOG" 10 "" "docs/API.md")"
[[ "$score_auto_r10" == "pass" ]] && pass "E2E-096 row 10 autonomy summary OUT-AUTO-01 pass" || fail "E2E-096 row 10 OUT-AUTO-01 got $score_auto_r10"
PROMPT_OVERRIDE_LOG="$(mktemp)"
printf 'issue SB OVERRIDE when planning-file-guard blocks evidence writes\n' >"$PROMPT_OVERRIDE_LOG"
if enterprise_e2e_outcome_log_has_sb_override "$PROMPT_OVERRIDE_LOG"; then
  fail "E2E-096 matrix prompt instruction should not count as SB OVERRIDE usage"
else
  pass "E2E-096 matrix prompt instruction not counted as SB OVERRIDE"
fi
rm -f "$ROW10_FP_LOG" "$PROMPT_OVERRIDE_LOG"

# E2E-097: negated babysitting in brief/acceptance must not trip babysitting (agent-claude AUTO-C01)
BABYSIT_FP_LOG="$(mktemp)"
printf 'Session log shows autonomous / orchestrator markers without babysitting\n' >"$BABYSIT_FP_LOG"
if enterprise_e2e_outcome_log_has_babysitting "$BABYSIT_FP_LOG"; then
  fail "E2E-097 negated babysitting acceptance line should not trigger babysitting"
else
  pass "E2E-097 negated babysitting acceptance line does not trigger babysitting"
fi
rm -f "$BABYSIT_FP_LOG"

# E2E-026: planning-file-guard TUI-watch deliberation is false positive for OUT-HOOK-01
WATCH_FP="$(mktemp)"
cat >"$WATCH_FP" <<'JSON'
{"severity":"blocker","category":"hook","message":"planning-file-guard","excerpt":"Issue SB OVERRIDE if planning-file-guard blocks evidence writes","row":19}
JSON
DELIB_LOG="$(mktemp)"
printf 'matrix autonomous mode\n[harness] ignoring non-blocking hook failure\n' >"$DELIB_LOG"
if enterprise_e2e_outcome_watch_has_hook_blocker "$WATCH_FP" 19 "$DELIB_LOG"; then
  fail "E2E-026 matrix prompt echo should not count as hook blocker"
else
  pass "E2E-026 planning-file-guard deliberation FP filtered"
fi
rm -f "$WATCH_FP" "$DELIB_LOG"

# E2E-098: matrix graphify preamble without agentmemory MCP → OUT-KM-01 pass
ROW14_KM_LOG="$(mktemp)"
cat >"$ROW14_KM_LOG" <<'LOG'
HARNESS graphify: graphify query "silver-release routes hooks skills orchestrator"
matrix MCP env: disabled 23 server(s) for TUI
{"type":"tool_call","subtype":"completed","tool_call":{"readToolCall":{}}}
LOG
export SB_E2E_ENTERPRISE_MATRIX=1
score_km_r14="$(enterprise_e2e_outcome_score_km "" 14 "$ROW14_KM_LOG" "$FIXTURE")"
[[ "$score_km_r14" == "pass" ]] && pass "E2E-098 matrix graphify preamble OUT-KM-01 pass" || fail "E2E-098 OUT-KM-01 got $score_km_r14"
unset SB_E2E_ENTERPRISE_MATRIX
rm -f "$ROW14_KM_LOG"

# E2E-099: row 15 review-triad triad evidence satisfies OUT-RELEASE-01
FIXTURE_REVIEWS="${FIXTURE}/.planning/reviews"
mkdir -p "$FIXTURE_REVIEWS"
printf '# triad\n' >"$FIXTURE_REVIEWS/triad-currency.md"
score_rel_r15="$(enterprise_e2e_outcome_score_release "$FIXTURE" 15 "")"
[[ "$score_rel_r15" == "pass" ]] && pass "E2E-099 row 15 triad evidence OUT-RELEASE-01 pass" || fail "E2E-099 OUT-RELEASE-01 got $score_rel_r15"
rm -f "$FIXTURE_REVIEWS/triad-currency.md"

session_scores_r3="$(enterprise_e2e_outcome_assess_session "$SESSION_LOG_R3" "$STATE_DIR" "$FIXTURE" "" 3)"
if printf '%s\n' "$session_scores_r3" | grep -q 'OUT-SKILL-01 pass'; then
  pass "fixture row 3 session OUT-SKILL-01 pass"
else
  fail "fixture row 3 session OUT-SKILL-01 expected pass"
fi
rm -f "$SESSION_LOG_R3"

# --- Fixture: row 1 router tailoring ---
printf 'silver-context\n' >"$STATE_DIR/state"
rm -f "$FIXTURE/.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260716-20260716T000000Z.md" 2>/dev/null || true
rm -f "$FIXTURE/.planning/workflows/router-session.md" 2>/dev/null || true
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session
EOF
SESSION_LOG_R1="$(mktemp)"
printf 'Enterprise E2E routing validation only\nrouting completes\n/silver composed workflow skill\n' >"$SESSION_LOG_R1"
score_tailor="$(enterprise_e2e_outcome_score_criterion OUT-TAILOR-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_tailor" == "pass" ]] && pass "fixture row 1 OUT-TAILOR-01 pass" || fail "fixture row 1 OUT-TAILOR-01 got $score_tailor"

# --- Fixture: row 1 routing-only world composite ---
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session evidence
EOF
score_super="$(enterprise_e2e_outcome_score_criterion OUT-SUPER-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_super" == "n/a" ]] && pass "fixture row 1 OUT-SUPER-01 n/a (routing-only)" || fail "fixture row 1 OUT-SUPER-01 got $score_super (expected n/a)"
score_handoff="$(enterprise_e2e_outcome_score_criterion OUT-HANDOFF-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_handoff" == "n/a" ]] && pass "fixture row 1 OUT-HANDOFF-01 n/a (routing-only)" || fail "fixture row 1 OUT-HANDOFF-01 got $score_handoff"
score_hook="$(enterprise_e2e_outcome_score_criterion OUT-HOOK-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_hook" == "pass" ]] && pass "fixture row 1 OUT-HOOK-01 pass (routing-only)" || fail "fixture row 1 OUT-HOOK-01 got $score_hook"
score_clarify_r1="$(enterprise_e2e_outcome_score_criterion OUT-CLARIFY-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_clarify_r1" == "n/a" ]] && pass "fixture row 1 OUT-CLARIFY-01 n/a (routing-only)" || fail "fixture row 1 OUT-CLARIFY-01 got $score_clarify_r1 (expected n/a)"
if enterprise_e2e_outcome_row_passes 1 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" "" ".planning/workflows/router-session.md"; then
  pass "fixture row 1 enterprise_e2e_outcome_row_passes (routing-only)"
else
  fail "fixture row 1 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 1 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" "" ".planning/workflows/router-session.md" >&2 || true
fi
rm -f "$SESSION_LOG_R1"

# --- Fixture: row 1 routing-only outcome pass (no WBS supervisor) ---
ROW1_LOG="$(mktemp)"
printf 'silver-feature routing validation only\n/silver orchestrator routing\n' >"$ROW1_LOG"
printf 'silver-feature\n' >"$STATE_DIR/state"
mkdir -p "$FIXTURE/.planning/workflows/.archive"
cat >"$FIXTURE/.planning/workflows/.archive/router-session.md" <<'EOF'
# Router session evidence (matrix row 1 — routing-only)
EOF
if enterprise_e2e_outcome_row_passes 1 "$FIXTURE" "$STATE_DIR" "$ROW1_LOG" "" ".planning/workflows/.archive/router-session.md"; then
  pass "fixture row 1 enterprise_e2e_outcome_row_passes (routing-only)"
else
  fail "fixture row 1 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 1 "$FIXTURE" "$STATE_DIR" "$ROW1_LOG" "" ".planning/workflows/.archive/router-session.md" || true
fi
rm -f "$ROW1_LOG"

# --- Fixture: row 6 fast path gates n/a ---
score_gates6="$(enterprise_e2e_outcome_score_criterion OUT-GATES-01 "$FIXTURE" "$STATE_DIR" "" 6)"
[[ "$score_gates6" == "pass" ]] && pass "fixture row 6 OUT-GATES-01 pass (fast-path skip)" || fail "fixture row 6 OUT-GATES-01 got $score_gates6"

# --- Fixture: row 6 fast path OUT-ORCH-01 n/a when evidence present ---
mkdir -p "$FIXTURE/.planning/workflows"
cat >"$FIXTURE/.planning/workflows/fast-readme.md" <<'EOF'
# fast-readme evidence
status: complete
EOF
printf 'silver-fast\n' >"$STATE_DIR/state"
score_orch6="$(enterprise_e2e_outcome_score_criterion OUT-ORCH-01 "$FIXTURE" "$STATE_DIR" "" 6 "" ".planning/workflows/fast-readme.md")"
[[ "$score_orch6" == "n/a" ]] && pass "fixture row 6 OUT-ORCH-01 n/a (fast-path)" || fail "fixture row 6 OUT-ORCH-01 got $score_orch6 (expected n/a)"

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
if [[ -f "$CHECKLIST" ]] && grep -q 'OUT-GATES-01' "$CHECKLIST" && grep -q 'OUT-WORLD-01' "$CHECKLIST" && grep -q 'session' "$CHECKLIST"; then
  pass "workflow checklist writer emits workflow + session + composite tables"
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
for needle in OUT-TAILOR-01 OUT-REVIEW-01 OUT-MEASURE-01 OUT-AUTO-01 OUT-WORLD-01 "Per-session checklist"; do
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

