#!/usr/bin/env bash
# Validates docs/apo-catalog.json structure against Phase 2 schema invariants.
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
SCHEMA="$REPO_ROOT/docs/apo-catalog.schema.json"

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq required for APO catalog schema tests"
  exit 0
fi

for f in "$CATALOG" "$SCHEMA"; do
  if [[ -f "$f" ]] && jq empty "$f" 2>/dev/null; then
    pass "valid JSON: ${f#$REPO_ROOT/}"
  else
    fail "invalid or missing JSON: ${f#$REPO_ROOT/}"
  fi
done

required_top=(
  catalog_version meta processes workflows atomic_flows flow_steps
  artifacts tool_policies migration_map
)
for key in "${required_top[@]}"; do
  if jq -e --arg k "$key" 'has($k)' "$CATALOG" >/dev/null; then
    pass "catalog has top-level key: $key"
  else
    fail "catalog missing top-level key: $key"
  fi
done

audit_entities=(evidence_records intent_ledgers v_loop_rollups composition_logs)
for key in "${audit_entities[@]}"; do
  count=$(jq --arg k "$key" '.[$k] | length' "$CATALOG")
  if [[ "$count" -ge 1 ]]; then
    pass "catalog defines audit entity array: $key ($count entries)"
  else
    fail "catalog missing or empty audit entity array: $key"
  fi
done

if [[ "$(jq -r '.meta.source_of_truth' "$CATALOG")" == "docs/apo-catalog.json" ]]; then
  pass "meta.source_of_truth points to catalog file"
else
  fail "meta.source_of_truth must be docs/apo-catalog.json"
fi

# Reject standalone nesting entity types at top level.
for forbidden in nesting workflow_nesting workflow_component nesting_entity; do
  if jq -e --arg k "$forbidden" 'has($k)' "$CATALOG" >/dev/null; then
    fail "forbidden standalone nesting entity type at top level: $forbidden"
  else
    pass "no standalone nesting entity type: $forbidden"
  fi
done

# Every workflow must express nesting only via composition_tree.
wf_missing_tree=$(jq -r '.workflows[] | select(.composition_tree == null or (.composition_tree | length) == 0) | .id' "$CATALOG")
if [[ -z "$wf_missing_tree" ]]; then
  pass "every workflow has non-empty composition_tree"
else
  fail "workflows missing composition_tree: $wf_missing_tree"
fi

# Atomic flows: required execution block and v_loop fields.
af_bad_exec=$(jq -r '
  .atomic_flows[] |
  select(
    .execution.dispatch_mode == null or
    .execution.worker_template == null or
    .execution.parallelizable == null or
    .execution.join_condition == null or
    .execution.retry_policy == null
  ) | .id
' "$CATALOG")
if [[ -z "$af_bad_exec" ]]; then
  pass "every atomic_flow has complete execution block"
else
  fail "atomic_flows missing execution fields: $af_bad_exec"
fi

af_bad_vloop=$(jq -r '
  .atomic_flows[] |
  select(
    .v_loop.input_contract == null or
    .v_loop.work_product == null or
    (.v_loop.verification.methods | length) == 0 or
    (.v_loop.validation.methods | length) == 0 or
    .v_loop.repair.behavior == null or
    .v_loop.escalation.condition == null
  ) | .id
' "$CATALOG")
if [[ -z "$af_bad_vloop" ]]; then
  pass "every atomic_flow has complete per-flow v_loop"
else
  fail "atomic_flows missing v_loop fields: $af_bad_vloop"
fi

# Flow steps: per-step v_loop required.
fs_bad=$(jq -r '
  .flow_steps[] |
  select(
    .hierarchy_level != "flow_step" or
    .v_loop.input_contract == null or
    .v_loop.work_product == null or
    (.v_loop.verification.methods | length) == 0 or
    (.v_loop.validation.methods | length) == 0 or
    .v_loop.repair.behavior == null or
    .v_loop.escalation.condition == null
  ) | .id
' "$CATALOG")
if [[ -z "$fs_bad" ]]; then
  pass "every flow_step has complete per-step v_loop"
else
  fail "flow_steps missing per-step v_loop: $fs_bad"
fi

# Legacy FLOW 1-18 migration map present.
for i in $(seq 1 18); do
  key="FLOW $i"
  if jq -e --arg k "$key" '.migration_map.legacy_flows | has($k)' "$CATALOG" >/dev/null; then
    pass "migration_map covers $key"
  else
    fail "migration_map missing $key"
  fi
done

# Subagent dispatch mode for all catalog atomic flows in skeleton.
inline_atoms=$(jq -r '.atomic_flows[] | select(.execution.dispatch_mode != "subagent") | .id' "$CATALOG")
if [[ -z "$inline_atoms" ]]; then
  pass "all atomic_flows use subagent dispatch_mode"
else
  fail "atomic_flows not using subagent dispatch: $inline_atoms"
fi

schema_dispatch_modes=$(jq -r '.["$defs"].execution.properties.dispatch_mode.enum[]?' "$SCHEMA" | paste -sd, -)
if [[ "$schema_dispatch_modes" == "subagent" ]]; then
  pass "schema only permits subagent dispatch_mode for atomic flows"
else
  fail "schema permits non-subagent atomic-flow dispatch modes: $schema_dispatch_modes"
fi

# Schema file documents workflow composition_tree (no nesting entity in $defs properties).
if grep -q '"composition_tree"' "$SCHEMA" && ! grep -q '"nesting"' "$SCHEMA"; then
  pass "schema defines composition_tree without nesting entity type"
else
  fail "schema must define composition_tree and must not add nesting entity type"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
