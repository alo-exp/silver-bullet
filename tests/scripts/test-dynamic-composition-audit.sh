#!/usr/bin/env bash
# Runtime integration: dynamic composition operations require catalog rule refs in composition log.
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
mkdir -p "$tmpdir/.planning" "$SB_RUNTIME_STATE_DIR"

logfile="$(sb_orchestrator_composition_log "$tmpdir")"
: >"$logfile"

record_ops() {
  sb_scheduler_record_composition_operation "$tmpdir" "WF-FIXTURE" "$1" "$2" "$3" "$4"
}

record_ops "prune" "AF-FIXTURE-READ-A" "DR-PRUNE-SATISFIED-ATOM" "existing evidence proves atom satisfied"
record_ops "insert" "AF-FIXTURE-EXECUTE" "DR-INSERT-MISSING-EVIDENCE" "V-loop precondition lacks evidence"
record_ops "substitute" "WF-FIXTURE" "DR-SUBSTITUTE-LEANER-WORKFLOW" "narrow intent satisfied by smaller workflow"
record_ops "parallelize" "AF-FIXTURE-READ-B" "DR-PARALLELIZE-INDEPENDENT-ATOMS" "scopes disjoint and dependencies satisfied"
record_ops "loop" "AF-FIXTURE-EXECUTE" "DR-LOOP-FAILED-V-GATE" "repairable V-gate failure triggers repair loop"

entry_count="$(wc -l <"$logfile" | tr -d ' ')"
if [[ "$entry_count" == "5" ]]; then
  pass "runtime composition log records five dynamic operations"
else
  fail "expected 5 log entries, got $entry_count"
fi

bad_refs="$(jq -s '
  [.[] | .operations[]? | select((.catalog_rule_ref // "") == "" or (.rationale // "") == "")] | length
' "$logfile" 2>/dev/null || echo 1)"
if [[ "$bad_refs" == "0" ]]; then
  pass "every runtime operation has catalog_rule_ref and rationale"
else
  fail "$bad_refs operations missing catalog_rule_ref or rationale"
fi

ops_seen="$(jq -r -s '[.[].operations[0].op] | unique | sort | join(",")' "$logfile" 2>/dev/null || true)"
if [[ "$ops_seen" == "insert,loop,parallelize,prune,substitute" ]]; then
  pass "all dynamic operation types recorded in composition log"
else
  fail "unexpected operations in log: $ops_seen"
fi

# Scheduler dispatch plan also carries runtime decisions with rule refs
plan="$(sb_scheduler_plan_batches_json "$FIXTURE_CATALOG" '["AF-FIXTURE-READ-A","AF-FIXTURE-READ-B"]')"
bad_plan_refs="$(jq '[.scheduler_decisions[] | select((.catalog_rule_ref // "") == "" or (.rationale // "") == "")] | length' <<<"$plan")"
if [[ "$bad_plan_refs" == "0" ]]; then
  pass "scheduler dispatch decisions include catalog rule refs and rationale"
else
  fail "scheduler decisions missing rule refs ($bad_plan_refs)"
fi

sb_orchestrator_seed_intent "composition audit fixture" "silver-feature" "$tmpdir" >/dev/null
sb_scheduler_append_composition_log "$tmpdir" "$plan"
last_entry="$(tail -1 "$logfile")"
if jq -e '.scheduler_decisions and .dispatch_records' <<<"$last_entry" >/dev/null 2>&1; then
  pass "dispatch plan appended to composition log with scheduler_decisions and dispatch_records"
else
  fail "dispatch plan log entry missing scheduler_decisions or dispatch_records"
fi

# Catalog template still defines required dynamic rule coverage (preflight)
required_ops="prune insert substitute parallelize loop"
catalog_ops="$(jq -r '[.dynamic_rules[].operation] | unique | sort | join(" ")' "$PROD_CATALOG")"
missing=""
for op in $required_ops; do
  if ! jq -e --arg op "$op" '.dynamic_rules[] | select(.operation == $op)' "$PROD_CATALOG" >/dev/null 2>&1; then
    missing="${missing:+$missing,}$op"
  fi
done
if [[ -z "$missing" ]]; then
  pass "production catalog defines all dynamic rule operations"
else
  fail "catalog missing dynamic rules: $missing"
fi

template_bad="$(jq '[.composition_logs[] | .operations[]? | select((.catalog_rule_ref // "") == "" or (.rationale // "") == "")] | length' "$PROD_CATALOG")"
if [[ "$template_bad" == "0" ]]; then
  pass "catalog composition log template operations include rule refs"
else
  fail "catalog template has $template_bad operations without rule refs"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
