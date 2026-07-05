#!/usr/bin/env bash
# Runtime integration: step V-loop rollup blocks join gate and workflow completion until all steps pass.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_CATALOG="$REPO_ROOT/tests/fixtures/scheduler/apo-scheduler-fixture.json"
PROD_CATALOG="$REPO_ROOT/docs/apo-catalog.json"
LIB_SCHED="$REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/runtime-paths.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$LIB_SCHED"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_APO_CATALOG_FILE="$FIXTURE_CATALOG"
mkdir -p "$SB_RUNTIME_STATE_DIR"

sb_orchestrator_seed_intent "vloop rollup fixture" "silver-feature" "$tmpdir" >/dev/null

ATOM="AF-FIXTURE-EXECUTE"
STEP_A="FS-FIXTURE-EXECUTE-A"
STEP_B="FS-FIXTURE-EXECUTE-B"

gate_initial="$(sb_scheduler_eval_join_gate "$tmpdir" "$ATOM")"
if [[ "$gate_initial" == "blocked" ]]; then
  pass "join gate blocked before any step V-loop status recorded"
else
  fail "join gate should start blocked (got $gate_initial)"
fi

if sb_scheduler_workflow_completion_blocked "$tmpdir" "$ATOM"; then
  pass "workflow completion blocked while step V-loops pending"
else
  fail "workflow completion should block with pending step V-loops"
fi

sb_scheduler_set_step_vloop_status "$ATOM" "$STEP_A" "pass"
gate_partial="$(sb_scheduler_eval_join_gate "$tmpdir" "$ATOM")"
if [[ "$gate_partial" == "blocked" ]]; then
  pass "join gate remains blocked when only one owned step V-loop passes"
else
  fail "partial step rollup must not open join gate (got $gate_partial)"
fi

if sb_scheduler_workflow_completion_blocked "$tmpdir" "$ATOM"; then
  pass "workflow completion still blocked with partial step rollup"
else
  fail "workflow completion should remain blocked with one failing/pending step"
fi

sb_scheduler_set_step_vloop_status "$ATOM" "$STEP_B" "pass"
gate_open="$(sb_scheduler_refresh_join_gate "$tmpdir" "$ATOM")"
if [[ "$gate_open" == "open" ]]; then
  pass "join gate opens after all owned step V-loops pass"
else
  fail "join gate should open when all steps pass (got $gate_open)"
fi

if ! sb_scheduler_atom_vgate_ready "$tmpdir" "$ATOM"; then
  fail "atom V-gate should be ready after join opens"
else
  pass "atom V-gate ready after step V-loop rollup completes"
fi

# Failing step re-blocks join gate
sb_scheduler_set_step_vloop_status "$ATOM" "$STEP_B" "fail"
gate_fail="$(sb_scheduler_eval_join_gate "$tmpdir" "$ATOM")"
if [[ "$gate_fail" == "blocked" ]]; then
  pass "failing step V-loop re-blocks join gate"
else
  fail "failed step should block join gate (got $gate_fail)"
fi

if sb_scheduler_workflow_completion_blocked "$tmpdir" "$ATOM"; then
  pass "workflow completion blocked when step V-loop fails"
else
  fail "workflow completion should block on failing step V-loop"
fi

# Production catalog rollup semantics (catalog metadata sanity, not runtime-only)
rollup_text="$(jq -r '[.v_loop_rollups[].rollup_semantics] | join(" ")' "$PROD_CATALOG")"
if [[ "$rollup_text" == *"flow-step V-loops pass before parent atomic-flow gates"* ]]; then
  pass "catalog rollup semantics require step-before-flow ordering"
else
  fail "catalog missing step-before-flow rollup semantics"
fi

join_meta="$(jq -r '.atomic_flows[] | select(.id == "AF-EXECUTE") | .execution.join_condition' "$PROD_CATALOG")"
dispatch_shape="$(jq -r '.atomic_flows[] | select(.id == "AF-EXECUTE") | .execution.dispatch_record_shape' "$PROD_CATALOG")"
if [[ "$join_meta" == *"step V-loops"* && "$dispatch_shape" == *"step_v_loop_status"* ]]; then
  pass "AF-EXECUTE catalog join and dispatch record require step V-loop status"
else
  fail "AF-EXECUTE missing step V-loop join/dispatch metadata"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
