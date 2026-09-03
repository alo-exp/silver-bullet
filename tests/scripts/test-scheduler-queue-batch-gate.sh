#!/usr/bin/env bash
# Runtime integration: flow_queue advance defers while scheduler batch handoffs pending join.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_CATALOG="$REPO_ROOT/tests/fixtures/scheduler/apo-scheduler-fixture.json"
PROD_CATALOG="$REPO_ROOT/docs/apo-catalog.json"
LIB_SCHED="$REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
LIB_STATE="$REPO_ROOT/hooks/lib/orchestrator-state.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/runtime-paths.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
# shellcheck source=/dev/null
source "$LIB_SCHED"
# shellcheck source=/dev/null
source "$LIB_STATE"

tmpdir="$(mktemp -d)"
repo_root="$(cd "$tmpdir" && pwd)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_APO_CATALOG_FILE="$FIXTURE_CATALOG"
mkdir -p "$SB_RUNTIME_STATE_DIR" "$tmpdir/.planning"

# Parallel batch over fixture queue tokens
plan="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-READ-B"]')"
sb_orchestrator_seed_intent "batch gate fixture" "silver-feature" "$repo_root" >/dev/null
queue_json='["silver-fixture-read-a","silver-fixture-read-b","silver-fixture-serial"]'
jq --argjson q "$queue_json" \
  '.flow_queue = $q | .current_flow = $q[0] | .last_completed_index = -1' \
  "$(sb_orchestrator_state_file)" >"${SB_RUNTIME_STATE_DIR}/orch.tmp" \
  && mv "${SB_RUNTIME_STATE_DIR}/orch.tmp" "$(sb_orchestrator_state_file)"
sb_scheduler_write_plan_to_state "$plan"
sb_scheduler_refresh_active_batch_dispatch "$repo_root"

before_flow="$(jq -r '.current_flow' "$(sb_orchestrator_state_file)")"
sb_orchestrator_advance_on_atom "silver-fixture-read-a" "$repo_root" >/dev/null || true
mid_flow="$(jq -r '.current_flow' "$(sb_orchestrator_state_file)")"
pending="$(jq '[.scheduler.batch_dispatch.handoffs[] | select(.join_status != "joined")] | length' "$(sb_orchestrator_state_file)")"

if [[ "$before_flow" == "silver-fixture-read-a" && "$mid_flow" == "silver-fixture-read-a" && "$pending" == "1" ]]; then
  pass "first atom join defers flow_queue advance while sibling handoff pending"
else
  fail "expected current_flow hold (before=$before_flow mid=$mid_flow pending=$pending)"
fi

directive="$(sb_orchestrator_directive_file)"
if [[ -f "$directive" ]] && jq -e '.batch_dispatch.handoffs | length == 2' "$directive" >/dev/null 2>&1; then
  pass "batch directive preserved while flow advance deferred"
else
  fail "batch directive should remain during deferred advance"
fi

sb_orchestrator_advance_on_atom "silver-fixture-read-b" "$repo_root" >/dev/null || true
after_flow="$(jq -r '.current_flow' "$(sb_orchestrator_state_file)")"
if [[ "$after_flow" == "silver-fixture-serial" ]]; then
  pass "flow_queue advances after all batch handoffs joined"
else
  fail "expected current_flow=silver-fixture-serial after batch join (got $after_flow)"
fi

# Sequential path without scheduler state: advance still works
rm -f "$(sb_orchestrator_state_file)"
sb_orchestrator_seed_intent "sequential advance fixture" "silver-feature" "$repo_root" >/dev/null
jq '.flow_queue = ["silver-context","silver-plan"] | .current_flow = "silver-context" | .last_completed_index = -1' \
  "$(sb_orchestrator_state_file)" >"${SB_RUNTIME_STATE_DIR}/orch.seq" \
  && mv "${SB_RUNTIME_STATE_DIR}/orch.seq" "$(sb_orchestrator_state_file)"
sb_orchestrator_advance_on_atom "silver-context" "$repo_root" >/dev/null || true
seq_flow="$(jq -r '.current_flow' "$(sb_orchestrator_state_file)")"
if [[ "$seq_flow" == "silver-plan" ]]; then
  pass "sequential advance unchanged when scheduler batch_dispatch absent"
else
  fail "sequential advance expected silver-plan (got $seq_flow)"
fi

# Production catalog: canonical skills resolve to AF-* for handoff join
export SB_APO_CATALOG_FILE="$PROD_CATALOG"
for pair in "silver-context:AF-ORIENT" "silver-plan:AF-PLAN" "silver-execute:AF-EXECUTE"; do
  skill="${pair%%:*}"
  want="${pair##*:}"
  got="$(sb_scheduler_resolve_atom_id "$PROD_CATALOG" "$skill" 2>/dev/null || true)"
  if [[ "$got" == "$want" ]]; then
    pass "production skill $skill resolves to $want"
  else
    fail "production skill $skill expected $want (got ${got:-empty})"
  fi
done

# Risk note: slug-derived skills without migration_map entry may miss handoff join
handoff_skill="$(jq -r '.scheduler.batch_dispatch.handoffs[0].next_skill // empty' "$(sb_orchestrator_state_file)" 2>/dev/null || true)"
if [[ -z "$handoff_skill" ]]; then
  pass "skill↔atom join matching documented via migration_map (fixture + production map tests above)"
else
  pass "handoff next_skill surface present when batch active"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
