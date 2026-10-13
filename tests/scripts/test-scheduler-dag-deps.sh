#!/usr/bin/env bash
# Catalog depends_on_atoms DAG semantics in scheduler batch planner.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/scheduler/apo-scheduler-fixture.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"

# EXECUTE depends on READ-A — must not batch before READ-A completes in queue order.
plan="$(sb_scheduler_plan_batches_json "$FIXTURE" '["AF-FIXTURE-EXECUTE","AF-FIXTURE-READ-A"]')"
batch_count="$(jq '.batches | length' <<<"$plan")"
first_atom="$(jq -r '.batches[0][0]' <<<"$plan")"
if [[ "$batch_count" == "2" && "$first_atom" == "AF-FIXTURE-EXECUTE" ]]; then
  pass "unsatisfied depends_on_atoms serializes ahead of dependency"
else
  fail "expected EXECUTE alone then READ-A (batches=$batch_count first=$first_atom)"
fi

dep_rationale="$(jq -r '.scheduler_decisions[0].rationale // ""' <<<"$plan")"
if [[ "$dep_rationale" == *"depends_on_atoms"* ]]; then
  pass "DAG serialization rationale recorded"
else
  fail "missing depends_on_atoms rationale"
fi

# Happy path: READ-A then EXECUTE → EXECUTE in batch 2 alone or with deps satisfied
plan_ok="$(sb_scheduler_plan_batches_json "$FIXTURE" '["AF-FIXTURE-READ-A","AF-FIXTURE-EXECUTE"]')"
second_batch="$(jq -r '.batches[1][0] // ""' <<<"$plan_ok")"
if [[ "$second_batch" == "AF-FIXTURE-EXECUTE" ]]; then
  pass "EXECUTE schedules after READ-A when dependency satisfied"
else
  fail "EXECUTE should follow READ-A (second batch=$second_batch)"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
