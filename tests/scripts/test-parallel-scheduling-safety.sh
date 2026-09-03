#!/usr/bin/env bash
# Runtime integration: parallelizable atoms batch safely; mutation-scope conflicts serialize.
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
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-directive.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_APO_CATALOG_FILE="$FIXTURE_CATALOG"
mkdir -p "$tmpdir/.planning" "$SB_RUNTIME_STATE_DIR"

# --- Fixture catalog: disjoint scopes parallelize ---
plan="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-READ-B"]')"
batch_count="$(jq '.batches | length' <<<"$plan")"
first_batch_len="$(jq '.batches[0] | length' <<<"$plan")"
if [[ "$batch_count" == "1" && "$first_batch_len" == "2" ]]; then
  pass "disjoint mutation scopes group into one parallel batch"
else
  fail "disjoint scopes should parallelize (batches=$batch_count len=$first_batch_len)"
fi

parallel_decisions="$(jq '[.scheduler_decisions[] | select(.decision == "parallel")] | length' <<<"$plan")"
if [[ "$parallel_decisions" == "2" ]]; then
  pass "parallel dispatch decisions cite DR-PARALLELIZE-INDEPENDENT-ATOMS"
else
  fail "expected 2 parallel decisions, got $parallel_decisions"
fi

# --- Fixture catalog: overlapping scopes serialize ---
plan_conflict="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-WRITE-A","AF-FIXTURE-WRITE-B"]')"
conflict_batches="$(jq '.batches | length' <<<"$plan_conflict")"
serialized="$(jq '[.scheduler_decisions[] | select(.decision == "serialized")] | length' <<<"$plan_conflict")"
if [[ "$conflict_batches" == "2" && "$serialized" == "1" ]]; then
  pass "overlapping mutation scopes serialize with rationale"
else
  fail "scope conflict should yield 2 batches (batches=$conflict_batches serialized=$serialized)"
fi
rationale="$(jq -r '.dispatch_records[1].serialization_rationale // ""' <<<"$plan_conflict")"
if [[ "$rationale" == *"mutation scope conflict"* ]]; then
  pass "serialization rationale recorded on dispatch record"
else
  fail "missing serialization rationale on dispatch record"
fi

# --- Non-parallelizable atom always serial ---
plan_serial="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-SERIAL"]')"
serial_batches="$(jq '.batches | length' <<<"$plan_serial")"
if [[ "$serial_batches" == "2" ]]; then
  pass "non-parallelizable atom forces separate batch"
else
  fail "expected 2 batches when mixing parallel and serial atoms (got $serial_batches)"
fi

# --- Production catalog: same-scope parallelizable atoms serialize ---
export SB_APO_CATALOG_FILE="$PROD_CATALOG"
plan_prod="$(sb_scheduler_plan_batches_json "$PROD_CATALOG" '["AF-ORIENT","AF-CLARIFY"]')"
prod_batches="$(jq '.batches | length' <<<"$plan_prod")"
if [[ "$prod_batches" == "2" ]]; then
  pass "catalog AF-ORIENT + AF-CLARIFY serialize on shared mutation scopes"
else
  fail "production atoms with shared scopes should not share a batch (batches=$prod_batches)"
fi

# --- Runtime state + composition log integration ---
export SB_APO_CATALOG_FILE="$FIXTURE_CATALOG"
mkdir -p "$tmpdir/.planning"
sb_orchestrator_seed_intent "parallel scheduling fixture" "silver-feature" "$tmpdir" >/dev/null
plan_runtime="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-READ-B"]')"
sb_scheduler_write_plan_to_state "$plan_runtime"
sb_scheduler_append_composition_log "$tmpdir" "$plan_runtime"

logfile="$(sb_orchestrator_composition_log "$tmpdir")"
if [[ -f "$logfile" ]]; then
  log_records="$(jq -s 'length' "$logfile" 2>/dev/null || echo 0)"
  has_dispatch="$(jq -s '.[-1].dispatch_records | length > 0' "$logfile" 2>/dev/null || echo false)"
  has_decisions="$(jq -s '.[-1].scheduler_decisions | length > 0' "$logfile" 2>/dev/null || echo false)"
  if [[ "$log_records" -ge 1 && "$has_dispatch" == "true" && "$has_decisions" == "true" ]]; then
    pass "composition log records runtime scheduler dispatch decisions"
  else
    fail "composition log missing dispatch_records or scheduler_decisions"
  fi
else
  fail "composition log file not created"
fi

state_file="$(sb_orchestrator_state_file)"
if [[ -f "$state_file" ]] && jq -e '.scheduler.batches | length > 0' "$state_file" >/dev/null 2>&1; then
  pass "orchestrator.json persists scheduler batch plan"
else
  fail "orchestrator.json missing .scheduler.batches"
fi

# --- Batch dispatch handoff metadata ---
sb_scheduler_refresh_active_batch_dispatch "$tmpdir"
state_file="$(sb_orchestrator_state_file)"
handoff_count="$(jq '.scheduler.batch_dispatch.handoffs | length' "$state_file" 2>/dev/null || echo 0)"
if [[ "$handoff_count" == "2" ]]; then
  pass "active batch dispatch records handoffs for parallel fixture batch"
else
  fail "expected 2 batch handoffs (got $handoff_count)"
fi
directive="$(sb_orchestrator_directive_file)"
if [[ -f "$directive" ]] && jq -e '.batch_dispatch | type == "object"' "$directive" >/dev/null 2>&1; then
  pass "batch directive written with batch_dispatch metadata"
else
  fail "orchestrator-directive.json missing batch_dispatch"
fi

# --- Scope conflict helper ---
if sb_scheduler_mutation_scopes_conflict '["scoped repository paths"]' '["scoped repository paths"]'; then
  pass "mutation scope conflict detector flags overlap"
else
  fail "mutation scope conflict detector should flag identical scopes"
fi
if ! sb_scheduler_mutation_scopes_conflict '["read-only planning artifacts"]' '["metrics-only artifacts"]'; then
  pass "mutation scope conflict detector allows disjoint scopes"
else
  fail "disjoint scopes should not conflict"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
