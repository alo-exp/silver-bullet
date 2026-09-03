#!/usr/bin/env bash
# Runtime integration: scheduler pending batch/join work blocks parent Stop; completed batches allow progress.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_CATALOG="$REPO_ROOT/tests/fixtures/scheduler/apo-scheduler-fixture.json"
LIB_SCHED="$REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-check.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/runtime-paths.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
# shellcheck source=/dev/null
source "$LIB_SCHED"

tmpdir="$(mktemp -d)"
repo_root="$(cd "$tmpdir" && pwd)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_APO_CATALOG_FILE="$FIXTURE_CATALOG"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SB_ORCHESTRATOR_PARENT=1
export SB_ORCHESTRATOR_PARALLEL_DISPATCH=1
export SB_RUNTIME_PRESERVE_STATE_DIR=1
mkdir -p "$SB_RUNTIME_STATE_DIR" "$tmpdir/.planning"

git -C "$repo_root" init -q
echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$SB_RUNTIME_STATE_DIR/state"'","trivial_file":"'"$SB_RUNTIME_STATE_DIR/trivial-nonexistent"'"}}' >"$repo_root/.silver-bullet.json"
echo '# SB' >"$repo_root/silver-bullet.md"
touch "$SB_RUNTIME_STATE_DIR/state"
printf 'silver-quality-gates\n' >"$SB_RUNTIME_STATE_DIR/state"

plan="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-READ-B"]')"
sb_orchestrator_seed_intent "scheduler stop fixture" "silver-feature" "$repo_root" >/dev/null
sb_scheduler_write_plan_to_state "$plan"

if sb_scheduler_parent_stop_blocked "$repo_root"; then
  pass "pending parallel batch blocks scheduler stop gate"
else
  fail "pending batch_dispatch should block parent stop"
fi

directive_file="$(sb_orchestrator_directive_file)"
if [[ -f "$directive_file" ]] && jq -e '.batch_dispatch.handoffs | length == 2' "$directive_file" >/dev/null 2>&1; then
  pass "batch directive records two parallel handoffs for parent"
else
  fail "orchestrator-directive.json missing batch_dispatch with 2 handoffs"
fi

mode="$(jq -r '.batch_dispatch.dispatch_mode // ""' "$directive_file" 2>/dev/null || true)"
if [[ "$mode" == "parallel" ]]; then
  pass "parallel host sees parallel dispatch_mode on directive"
else
  fail "expected parallel dispatch_mode (got $mode)"
fi

# Sequential host fallback: single handoff surface via directive next_skill
export SB_ORCHESTRATOR_PARALLEL_DISPATCH=0
sb_scheduler_refresh_active_batch_dispatch "$repo_root"
seq_mode="$(jq -r '.scheduler.batch_dispatch.dispatch_mode // ""' "$(sb_orchestrator_state_file)")"
if [[ "$seq_mode" == "sequential" ]]; then
  pass "non-parallel host flattens batch to sequential dispatch_mode"
else
  fail "sequential fallback expected dispatch_mode=sequential (got $seq_mode)"
fi
export SB_ORCHESTRATOR_PARALLEL_DISPATCH=1
sb_scheduler_refresh_active_batch_dispatch "$repo_root"

# stop-check.sh blocks parent Stop while batch pending
stop_out="$(cd "$repo_root" && printf '{"hook_event_name":"Stop"}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_TEST_HOOK_ENFORCED=1 SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" \
  SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state" \
  bash "$STOP_HOOK" 2>/dev/null || true)"
if printf '%s' "$stop_out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "stop-check blocks parent Stop while scheduler batch pending"
else
  fail "stop-check should block on pending scheduler batch"
fi

# Mark one handoff dispatched — still blocked until joins complete
sb_scheduler_mark_handoff_dispatched "AF-FIXTURE-READ-A" ""
if sb_scheduler_parent_stop_blocked "$repo_root"; then
  pass "partial dispatch still blocks stop (join pending)"
else
  fail "stop should remain blocked with one of two handoffs dispatched"
fi

# Complete both handoffs — scheduler stop gate clears
sb_scheduler_mark_handoff_joined "AF-FIXTURE-READ-A" ""
sb_scheduler_mark_handoff_joined "AF-FIXTURE-READ-B" ""
if ! sb_scheduler_parent_stop_blocked "$repo_root"; then
  pass "completed batch joins clear scheduler stop gate"
else
  fail "scheduler stop gate should clear after all handoffs joined"
fi

# Blocked join gate still blocks stop even without pending batch_dispatch handoffs
repo_root="$(cd "$tmpdir" && pwd)"
sb_orchestrator_seed_intent "join gate fixture" "silver-feature" "$repo_root" >/dev/null
sb_scheduler_set_step_vloop_status "AF-FIXTURE-EXECUTE" "FS-FIXTURE-EXECUTE-A" "pass"
sb_scheduler_refresh_join_gate "$tmpdir" "AF-FIXTURE-EXECUTE" >/dev/null
jq --arg atom "AF-FIXTURE-EXECUTE" '
  .scheduler.batch_dispatch = {status: "joined", handoffs: []} |
  .scheduler.join_gates[$atom] = "blocked" |
  .current_flow = ""
' "$(sb_orchestrator_state_file)" >"${SB_RUNTIME_STATE_DIR}/orch.tmp" \
  && mv "${SB_RUNTIME_STATE_DIR}/orch.tmp" "$(sb_orchestrator_state_file)"
if sb_scheduler_parent_stop_blocked "$repo_root"; then
  pass "blocked join gate blocks parent stop"
else
  fail "blocked join gate should block stop"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
