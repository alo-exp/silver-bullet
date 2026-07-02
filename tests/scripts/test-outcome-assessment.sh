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
  if jq -e '.blocking_criteria | length >= 4' "$REGISTRY" >/dev/null 2>&1; then
    pass "registry blocking_criteria has >=4 entries"
  else
    fail "registry blocking_criteria missing"
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
cat >"$FIXTURE/.planning/CLARIFY.md" <<'EOF'
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

session_scores_r3="$(enterprise_e2e_outcome_assess_session "$SESSION_LOG_R3" "$STATE_DIR" "$FIXTURE" "" 3)"
if printf '%s\n' "$session_scores_r3" | grep -q 'OUT-SKILL-01 pass'; then
  pass "fixture row 3 session OUT-SKILL-01 pass"
else
  fail "fixture row 3 session OUT-SKILL-01 expected pass"
fi
rm -f "$SESSION_LOG_R3"

# --- Fixture: row 1 router tailoring ---
SESSION_LOG_R1="$(mktemp)"
printf 'silver-context\n' >"$STATE_DIR/state"
rm -f "$FIXTURE/.planning/workflows/router-session.md" 2>/dev/null || true
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session
EOF
score_tailor="$(enterprise_e2e_outcome_score_criterion OUT-TAILOR-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_tailor" == "pass" ]] && pass "fixture row 1 OUT-TAILOR-01 pass" || fail "fixture row 1 OUT-TAILOR-01 got $score_tailor"

# --- Fixture: row 1 routing-only world composite ---
printf 'Enterprise E2E routing validation only\nrouting completes\n/silver composed workflow skill\n' >"$SESSION_LOG_R1"
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session evidence
EOF
score_super="$(enterprise_e2e_outcome_score_criterion OUT-SUPER-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_super" == "n/a" ]] && pass "fixture row 1 OUT-SUPER-01 n/a (routing-only)" || fail "fixture row 1 OUT-SUPER-01 got $score_super (expected n/a)"
score_handoff="$(enterprise_e2e_outcome_score_criterion OUT-HANDOFF-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_handoff" == "n/a" ]] && pass "fixture row 1 OUT-HANDOFF-01 n/a (routing-only)" || fail "fixture row 1 OUT-HANDOFF-01 got $score_handoff"
score_hook="$(enterprise_e2e_outcome_score_criterion OUT-HOOK-01 "$FIXTURE" "$STATE_DIR" "$SESSION_LOG_R1" 1)"
[[ "$score_hook" == "pass" ]] && pass "fixture row 1 OUT-HOOK-01 pass (routing-only)" || fail "fixture row 1 OUT-HOOK-01 got $score_hook"
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

# --- Fixture: row 6/7/8/11 FORCE-resume outcome patterns (retained log signals) ---
ROW67_LEDGER="$(mktemp)"
cat >"$ROW67_LEDGER" <<'LEDGER'
| # | WF slug | Session date | Claude model | Pass/Fail | failure_class | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
| 6 | `silver-fast` | 2026-06-30 | haiku | **Fail** | expect regex | | | silver-fast routes hooks skills orchestrator | |
| 7 | `silver-test` | 2026-06-30 | haiku | **Fail** | expect regex | | | silver-test routes hooks skills orchestrator | |
| 8 | `silver-refactor` | 2026-06-30 | haiku | **Fail** | expect regex | | | silver-refactor routes hooks skills orchestrator | |
| 11 | `silver-devops` | 2026-06-30 | haiku | **Fail** | expect regex | | | silver-devops routes hooks skills orchestrator | |
LEDGER
ROW6_LOG="$(mktemp)"
printf 'Route through silver-fast workflow\ngraphify query silver-fast routes hooks skills orchestrator\nagentmemory - memory_save (MCP)(content: "README decision")\nautonomous orchestrator active\n' >"$ROW6_LOG"
mkdir -p "$FIXTURE/.planning/workflows"
cat >"$FIXTURE/.planning/workflows/fast-readme.md" <<'EOF'
# Fast README evidence
EOF
cat >"$STATE_DIR/orchestrator-directive.json" <<'EOF'
{"next_skill":"silver-fast","next_worker_template":"fast"}
EOF
score_km6="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$ROW6_LOG" 6 "" "$ROW67_LEDGER")"
[[ "$score_km6" == "pass" ]] && pass "fixture row 6 OUT-KM-01 pass (graphify ref + agentmemory MCP in log)" || fail "fixture row 6 OUT-KM-01 got $score_km6"
score_skill6="$(enterprise_e2e_outcome_score_criterion OUT-SKILL-01 "$FIXTURE" "$STATE_DIR" "$ROW6_LOG" 6)"
[[ "$score_skill6" == "pass" ]] && pass "fixture row 6 OUT-SKILL-01 pass from log slug fallback" || fail "fixture row 6 OUT-SKILL-01 got $score_skill6"
rm -f "$STATE_DIR/state"
if enterprise_e2e_outcome_row_passes 6 "$FIXTURE" "$STATE_DIR" "$ROW6_LOG" "$ROW67_LEDGER" ".planning/workflows/fast-readme.md"; then
  pass "fixture row 6 enterprise_e2e_outcome_row_passes (KM + skill log fallback)"
else
  fail "fixture row 6 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 6 "$FIXTURE" "$STATE_DIR" "$ROW6_LOG" "$ROW67_LEDGER" ".planning/workflows/fast-readme.md" || true
fi
ROW7_LOG="$(mktemp)"
printf 'silver-test workflow\ngraphify query silver-test routes hooks skills orchestrator\nagentmemory - memory_smart_search (MCP)(query: "test-orders-integration")\n' >"$ROW7_LOG"
cat >"$FIXTURE/.planning/workflows/test-orders-integration.md" <<'EOF'
# Test orders integration evidence
EOF
printf 'silver-test\n' >"$STATE_DIR/state"
cat >"$STATE_DIR/orchestrator-directive.json" <<'EOF'
{"next_skill":"silver-test","next_worker_template":"test"}
EOF
score_km7="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$ROW7_LOG" 7 "" "$ROW67_LEDGER")"
[[ "$score_km7" == "pass" ]] && pass "fixture row 7 OUT-KM-01 pass (graphify ref + agentmemory MCP in log)" || fail "fixture row 7 OUT-KM-01 got $score_km7"
if enterprise_e2e_outcome_row_passes 7 "$FIXTURE" "$STATE_DIR" "$ROW7_LOG" "$ROW67_LEDGER" ".planning/workflows/test-orders-integration.md"; then
  pass "fixture row 7 enterprise_e2e_outcome_row_passes (KM-only gap fixed)"
else
  fail "fixture row 7 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 7 "$FIXTURE" "$STATE_DIR" "$ROW7_LOG" "$ROW67_LEDGER" ".planning/workflows/test-orders-integration.md" || true
fi
ROW8_LOG="$(mktemp)"
printf 'silver-refactor workflow\ngraphify query silver-refactor routes hooks skills orchestrator\nagentmemory - memory_save (MCP)(content: "refactor validation")\n' >"$ROW8_LOG"
cat >"$FIXTURE/.planning/workflows/refactor-order-validation.md" <<'EOF'
# Refactor order validation evidence
EOF
cat >"$FIXTURE/.planning/PLAN-refactor.md" <<'EOF'
# Plan — refactor
EOF
printf 'silver-refactor\n' >"$STATE_DIR/state"
cat >"$STATE_DIR/orchestrator-directive.json" <<'EOF'
{"next_skill":"silver-refactor","next_worker_template":"refactor"}
EOF
if enterprise_e2e_outcome_row_passes 8 "$FIXTURE" "$STATE_DIR" "$ROW8_LOG" "$ROW67_LEDGER" ".planning/workflows/refactor-order-validation.md"; then
  pass "fixture row 8 enterprise_e2e_outcome_row_passes (KM-only gap fixed)"
else
  fail "fixture row 8 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 8 "$FIXTURE" "$STATE_DIR" "$ROW8_LOG" "$ROW67_LEDGER" ".planning/workflows/refactor-order-validation.md" || true
fi
ROW11_LOG="$(mktemp)"
printf 'silver-devops terraform validation\ngraphify query silver-devops routes hooks skills orchestrator\nagentmemory - memory_smart_search (MCP)(query: "devops terraform")\n◯ general-purpose SB orchestrator worker — ROUTER for terraform env valid\nMinimum next action: Ask the user to decide whether to accept the current evidence\n' >"$ROW11_LOG"
mkdir -p "$FIXTURE/infra/terraform"
touch "$FIXTURE/infra/terraform/main.tf"
cat >"$FIXTURE/.planning/workflows/devops-terraform-validation.md" <<'EOF'
# Devops terraform validation
Terraform environment variable validation for IaC blast-radius review.
EOF
cat >"$FIXTURE/.planning/PLAN-devops.md" <<'EOF'
# Plan — devops
EOF
printf 'silver-devops\n' >"$STATE_DIR/state"
cat >"$STATE_DIR/orchestrator-directive.json" <<'EOF'
{"next_skill":"silver-devops","next_worker_template":"devops"}
EOF
score_blast11="$(enterprise_e2e_outcome_score_criterion OUT-BLAST-01 "$FIXTURE" "$STATE_DIR" "$ROW11_LOG" 11)"
[[ "$score_blast11" == "pass" ]] && pass "fixture row 11 OUT-BLAST-01 pass (devops evidence + terraform)" || fail "fixture row 11 OUT-BLAST-01 got $score_blast11"
score_noop11="$(enterprise_e2e_outcome_score_criterion OUT-NOOP-01 "$FIXTURE" "$STATE_DIR" "$ROW11_LOG" 11)"
[[ "$score_noop11" == "pass" ]] && pass "fixture row 11 OUT-NOOP-01 pass (planning Ask-the-user not babysitting)" || fail "fixture row 11 OUT-NOOP-01 got $score_noop11"
score_auto11="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$FIXTURE" "$STATE_DIR" "$ROW11_LOG" 11 "" ".planning/workflows/devops-terraform-validation.md")"
[[ "$score_auto11" == "pass" ]] && pass "fixture row 11 OUT-AUTO-01 pass (evidence + orchestrator worker log)" || fail "fixture row 11 OUT-AUTO-01 got $score_auto11"
if enterprise_e2e_outcome_row_passes 11 "$FIXTURE" "$STATE_DIR" "$ROW11_LOG" "$ROW67_LEDGER" ".planning/workflows/devops-terraform-validation.md"; then
  pass "fixture row 11 enterprise_e2e_outcome_row_passes (devops resume set)"
else
  fail "fixture row 11 enterprise_e2e_outcome_row_passes expected pass"
  enterprise_e2e_outcome_row_failures 11 "$FIXTURE" "$STATE_DIR" "$ROW11_LOG" "$ROW67_LEDGER" ".planning/workflows/devops-terraform-validation.md" || true
fi

# --- Live TUI log patterns: ANSI noise + fragmented graphify/agentmemory tokens ---
TUI7_LOG="$(mktemp)"
printf '\x1b[5Gagentmeory -memory_save (MCP)(concepts:"silver-test")\rquery "orders integration test" --graph\r    graphify-out/graph.json\rEvidence written to .planning/workflows/test-orders-integration.md\r' >"$TUI7_LOG"
score_km_tui7="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI7_LOG" 7 "" "$ROW67_LEDGER")"
[[ "$score_km_tui7" == "pass" ]] && pass "TUI-noisy row 7 OUT-KM-01 pass (ANSI + agentmeory typo)" || fail "TUI-noisy row 7 OUT-KM-01 got $score_km_tui7"
TUI8_LOG="$(mktemp)"
printf 'WROTE:.planning/workflows/refactor-order-validation.md\r|graphify-out/graph.json|AST cache\r' >"$TUI8_LOG"
mkdir -p "$FIXTURE/graphify-out"
touch "$FIXTURE/graphify-out/graph.json"
score_km_tui8="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI8_LOG" 8 "$ROW67_LEDGER" "")"
[[ "$score_km_tui8" == "pass" ]] && pass "TUI-noisy row 8 OUT-KM-01 pass (work_dir graphify-out + evidence written)" || fail "TUI-noisy row 8 OUT-KM-01 got $score_km_tui8"
TUI11_LOG="$(mktemp)"
printf 'graphify query "terraform validation"\rFull verdict persisted to agentmemory\r.planning/workflows/devops-terraform-validation.md\r' >"$TUI11_LOG"
score_km_tui11="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI11_LOG" 11 "" "$ROW67_LEDGER")"
[[ "$score_km_tui11" == "pass" ]] && pass "TUI-noisy row 11 OUT-KM-01 pass (graphify query + persisted capture)" || fail "TUI-noisy row 11 OUT-KM-01 got $score_km_tui11"
TUI2_LOG="$(mktemp)"
printf 'graphify query "silver-research routes hooks skills orchestrator"\rsaved the decision to agentmemory as mem_mr0ghyhm_78cf4b75a677\rWROTE: docs/ADR-001-runtime.md\r' >"$TUI2_LOG"
mkdir -p "$FIXTURE/docs"
touch "$FIXTURE/docs/ADR-001-runtime.md"
score_km_tui2="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI2_LOG" 2 "" "$ROW67_LEDGER")"
[[ "$score_km_tui2" == "pass" ]] && pass "TUI-noisy row 2 OUT-KM-01 pass (mem_mr id + graphify query)" || fail "TUI-noisy row 2 OUT-KM-01 got $score_km_tui2"
TUI5_MATRIX_LOG="$(mktemp)"
printf 'graphify query "silver-ui routes hooks skills orchestrator"\r' >"$TUI5_MATRIX_LOG"
mkdir -p "$FIXTURE/ui/src" "$FIXTURE/graphify-out"
touch "$FIXTURE/ui/src/App.jsx" "$FIXTURE/graphify-out/graph.json"
score_km_tui5="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI5_MATRIX_LOG" 5 "" "ui/src/App.jsx")"
[[ "$score_km_tui5" == "pass" ]] && pass "matrix harness row 5 OUT-KM-01 pass (graphify preamble + evidence path)" || fail "matrix harness row 5 OUT-KM-01 got $score_km_tui5"
TUI15_MATRIX_LOG="$(mktemp)"
printf 'codex TUI scrollback only\r' >"$TUI15_MATRIX_LOG"
mkdir -p "$FIXTURE/.planning/reviews" "$FIXTURE/graphify-out"
touch "$FIXTURE/.planning/reviews/triad-currency.md" "$FIXTURE/graphify-out/graph.json"
export SB_E2E_ENTERPRISE_MATRIX=1
score_km_tui15="$(enterprise_e2e_outcome_score_criterion OUT-KM-01 "$FIXTURE" "$STATE_DIR" "$TUI15_MATRIX_LOG" 15 "" ".planning/reviews/triad-currency.md")"
[[ "$score_km_tui15" == "pass" ]] && pass "matrix row 15 OUT-KM-01 pass (evidence + graph.json, log preamble lost)" || fail "matrix row 15 OUT-KM-01 got $score_km_tui15"
unset SB_E2E_ENTERPRISE_MATRIX
score_orch_tui2="$(enterprise_e2e_outcome_score_criterion OUT-ORCH-01 "$FIXTURE" "$STATE_DIR" "$TUI2_LOG" 2 "$FIXTURE" "docs/ADR-001-runtime.md")"
[[ "$score_orch_tui2" == "pass" ]] && pass "TUI-noisy row 2 OUT-ORCH-01 pass (evidence + graphify query)" || fail "TUI-noisy row 2 OUT-ORCH-01 got $score_orch_tui2"
TUI_HEAL_BYPASS_LOG="$(mktemp)"
printf '⚠ `--dangerously-bypass-hook-trust` is enabled. Enabled hooks may run without\n' >"$TUI_HEAL_BYPASS_LOG"
score_heal_bypass="$(enterprise_e2e_outcome_score_heal "$REPO_ROOT" "$TUI_HEAL_BYPASS_LOG" 2)"
[[ "$score_heal_bypass" == "n/a" ]] && pass "Codex bypass-hook-trust banner does not trigger OUT-HEAL-01 partial" || fail "Codex bypass-hook-trust OUT-HEAL-01 got $score_heal_bypass"
TUI_HEAL_FRICTION_LOG="$(mktemp)"
printf '[WARN] hook-trust prompt blocking session completion\n' >"$TUI_HEAL_FRICTION_LOG"
score_heal_friction="$(enterprise_e2e_outcome_score_heal "$REPO_ROOT" "$TUI_HEAL_FRICTION_LOG" 2)"
[[ "$score_heal_friction" == "partial" ]] && pass "real hook-trust friction still scores OUT-HEAL-01 partial" || fail "hook-trust friction OUT-HEAL-01 got $score_heal_friction"
export SB_E2E_MATRIX_EVIDENCE_PATH="docs/ADR-001-runtime.md"
ROW2_LIVE_LOG="$(mktemp)"
cp "$TUI2_LOG" "$ROW2_LIVE_LOG"
printf 'autonomous Task worker spawned\r' >>"$ROW2_LIVE_LOG"
score_auto_row2_env="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$FIXTURE" "$STATE_DIR" "$ROW2_LIVE_LOG" 2 "$ROW67_LEDGER" "")"
[[ "$score_auto_row2_env" == "pass" ]] && pass "row 2 OUT-AUTO-01 pass via SB_E2E_MATRIX_EVIDENCE_PATH" || fail "row 2 OUT-AUTO-01 env fallback got $score_auto_row2_env"
unset SB_E2E_MATRIX_EVIDENCE_PATH

rm -f "$ROW6_LOG" "$ROW7_LOG" "$ROW8_LOG" "$ROW11_LOG" "$ROW67_LEDGER" "$TUI7_LOG" "$TUI8_LOG" "$TUI11_LOG" "$TUI2_LOG" "$TUI5_MATRIX_LOG" "$ROW2_LIVE_LOG" "$TUI_HEAL_BYPASS_LOG" "$TUI_HEAL_FRICTION_LOG"

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
