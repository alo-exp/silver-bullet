#!/usr/bin/env bash
# Tri-criteria E2E scorer: evidence resolution + workflow-id counting from run artifacts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASSESS="${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"
RUN_TC01="${REPO_ROOT}/.planning/sb-tri-criteria-e2e/runs/20260705T220228Z-TC-01"
RUN_TC02="${REPO_ROOT}/.planning/sb-tri-criteria-e2e/runs/20260705T220511Z-TC-02"
WORK_DIR="${SB_TRI_CRITERIA_WORK_DIR:-/Users/shafqat/projects/enterprise-grade-test-app}"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$ASSESS"

export SB_E2E_ENTERPRISE_MATRIX=1

# TC-01: session log + run-dir composition log resolve evidence; multiwf passes.
export SB_TRI_CRITERIA_RUN_DIR="$RUN_TC01"
export SB_TRI_CRITERIA_SESSION_LOG="${RUN_TC01}/parent-session.log"
log="${RUN_TC01}/parent-session.log"
auto="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$WORK_DIR" "${HOME}/.cursor/.silver-bullet" "$log" "TC-01")"
[[ "$auto" == "pass" ]] && pass "TC-01 OUT-AUTO-01 pass" || fail "TC-01 OUT-AUTO-01 got $auto"
enterprise_e2e_outcome_evidence_resolved "$WORK_DIR" "" "TC-01" >/dev/null 2>&1 \
  && pass "TC-01 evidence_resolved" || fail "TC-01 evidence_resolved"
multiwf="$(enterprise_e2e_outcome_score_multiwf "$WORK_DIR" "${HOME}/.cursor/.silver-bullet" "$log")"
[[ "$multiwf" == "pass" ]] && pass "TC-01 OUT-MULTIWF-01 pass" || fail "TC-01 OUT-MULTIWF-01 got $multiwf"
wf_count="$(enterprise_e2e_outcome_count_distinct_workflow_ids "$WORK_DIR" "${HOME}/.cursor/.silver-bullet")"
[[ "${wf_count:-0}" -ge 3 ]] && pass "TC-01 distinct workflow ids >= 3 ($wf_count)" || fail "TC-01 workflow ids=$wf_count"

# TC-02: dynamic composition ops from run-dir log.
export SB_TRI_CRITERIA_RUN_DIR="$RUN_TC02"
export SB_TRI_CRITERIA_SESSION_LOG="${RUN_TC02}/parent-session.log"
log="${RUN_TC02}/parent-session.log"
dynamic="$(enterprise_e2e_outcome_score_dynamic "$WORK_DIR" "${HOME}/.cursor/.silver-bullet" "$log")"
[[ "$dynamic" == "pass" ]] && pass "TC-02 OUT-DYNAMIC-01 pass" || fail "TC-02 OUT-DYNAMIC-01 got $dynamic"
auto2="$(enterprise_e2e_outcome_score_criterion OUT-AUTO-01 "$WORK_DIR" "${HOME}/.cursor/.silver-bullet" "$log" "TC-02")"
[[ "$auto2" == "pass" ]] && pass "TC-02 OUT-AUTO-01 pass" || fail "TC-02 OUT-AUTO-01 got $auto2"

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
