#!/usr/bin/env bash
# Orchestrator flow with the SHIPPED catalog (docs/apo-catalog.json): composer start, atom
# completions, the SessionStart/prompt directive re-sync, re-runs of finished atoms, concurrent
# joins, out-of-order parallel joins and the Stop-block release. Review findings R4-05, R4-06,
# R4-18, R4-19, R4-30: the other scheduler tests use a fixture catalog only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED _lib_dir
export SILVER_BULLET_RUNTIME=claude
tl_stub sleep 'exit 0'
mkdir -p "$TL_TMP/cwd"
cd "$TL_TMP/cwd"
# shellcheck source=../../hooks/lib/orchestrator-scheduler.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"

STATE="$(orch_state_file)"
DIRF="$(orch_directive_file)"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/.planning"
printf '# SPEC\n' >"$PROJ/.planning/SPEC.md"

queue_tokens() { jq -r '.flow_queue[]' "$STATE"; }
skill_of() { sb_orchestrator_flow_to_skill "$1"; }

echo "=== every composer queue names real skills (R4-06) ==="
for composer in silver-feature silver-ui silver-bugfix silver-fast silver-refactor silver-test silver-release silver-devops silver-deploy silver-incident silver-benchmark silver-canary silver-content silver-forensics silver-retro silver-deep-research silver-new-workflow; do
  missing=""
  while IFS= read -r tok; do
    [[ -n "$tok" ]] || continue
    sk="$(skill_of "$tok")"
    [[ -f "$TL_REPO_ROOT/skills/$sk/SKILL.md" ]] || missing="$missing $tok=>$sk"
  done < <(sb_orchestrator_queue_for_composer "$composer" "$PROJ" | tr ',' '\n')
  assert_eq "$composer: every queue token maps to an installed skill" "" "$missing"
done

echo "=== silver-feature with the shipped catalog ==="
sb_orchestrator_on_composer_start silver-feature "add login" "$PROJ" >/dev/null
assert_eq "scheduler plan stored" true "$(jq -r '(.scheduler.batches | length) > 0' "$STATE")"
mapfile_q=()
while IFS= read -r t; do mapfile_q+=("$t"); done < <(queue_tokens)
assert_eq "the shipped catalog plans one atom per batch" "${#mapfile_q[@]}" "$(jq -r '.scheduler.batches | length' "$STATE")"
assert_eq "first directive is the first queue token's skill" "$(skill_of "${mapfile_q[0]}")" "$(orch_directive_get .next_skill)"
assert_eq "first handoff skill is the installed quality-gates skill (not silver-quality-gate)" silver-quality-gates "$(jq -r '.scheduler.batch_dispatch.handoffs[0].next_skill' "$STATE")"

n=${#mapfile_q[@]}
for ((i = 0; i < n; i++)); do
  tok="${mapfile_q[$i]}"
  sk="$(skill_of "$tok")"
  assert_eq "step $i: directive asks for ${sk}" "$sk" "$(orch_directive_get .next_skill)"
  assert_eq "step $i: handoff skill matches the directive" "$sk" "$(jq -r '[.scheduler.batch_dispatch.handoffs[] | select(.join_status != "joined")][0].next_skill // ""' "$STATE")"
  sb_orchestrator_advance_on_atom "$sk" "$PROJ" >/dev/null
  if ((i + 1 < n)); then
    assert_eq "step $i: current_flow advances to the next pending token" "${mapfile_q[$((i + 1))]}" "$(orch_state_get .current_flow)"
  fi
  if ((i == 4)); then
    # SessionStart(compact) / an ordinary prompt rebuild the directive from state.
    sb_orchestrator_sync_directive_from_state
    assert_eq "re-sync after five completions asks for the next pending atom" "$(skill_of "${mapfile_q[5]}")" "$(orch_directive_get .next_skill)"
    # The parent runs an already finished atom again: not a jump over review/verify/secure.
    before_idx="$(orch_state_get .last_completed_index)"
    sb_orchestrator_advance_on_atom silver-quality-gates "$PROJ" >/dev/null
    assert_eq "re-running a finished atom leaves last_completed_index" "$before_idx" "$(orch_state_get .last_completed_index)"
    assert_eq "re-running a finished atom leaves current_flow" "${mapfile_q[5]}" "$(orch_state_get .current_flow)"
    assert_eq "re-running a finished atom leaves the directive" "$(skill_of "${mapfile_q[5]}")" "$(orch_directive_get .next_skill)"
  fi
done
assert_eq "queue drained: current flow empty" "" "$(orch_state_get .current_flow)"
assert_eq "queue drained: no handoff left waiting" 0 "$(jq '[.scheduler.batch_dispatch.handoffs[] | select(.join_status != "joined")] | length' "$STATE")"
assert_eq "queue drained: last batch joined" joined "$(jq -r .scheduler.batch_dispatch.status "$STATE")"
assert_file_absent "queue drained: directive cleared" "$DIRF"

echo "=== concurrent joins keep every update (R4-18) ==="
CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
export SB_ORCHESTRATOR_PARALLEL_DISPATCH=1
lost=0
for _ in 1 2 3 4 5 6 7 8; do
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, active_intent:"i", flow_queue:["silver-fixture-read-a","silver-fixture-read-b","silver-plan"], current_flow:"silver-fixture-read-a",
    scheduler:{batches:[["AF-READ-A","AF-READ-B"],["AF-PLAN"]],batch_tokens:[["silver-fixture-read-a","silver-fixture-read-b"],["silver-plan"]],active_batch_index:0}}')"
  rm -f "$DIRF"
  sb_scheduler_refresh_active_batch_dispatch "$PROJ"
  ( sb_scheduler_mark_handoff_joined AF-READ-A "" ) &
  p1=$!
  ( sb_scheduler_mark_handoff_joined AF-READ-B "" ) &
  p2=$!
  wait "$p1" "$p2" || true
  idx="$(orch_state_get .scheduler.active_batch_index)"
  [[ "$idx" == 1 ]] || lost=$((lost + 1))
done
assert_eq "8 trials of two concurrent joins: no lost join, batch index advanced every time" 0 "$lost"
assert_eq "no temp files left in the state dir" 0 "$(find "$SB_RUNTIME_STATE_DIR" -name 'orchestrator.json.*' | wc -l | tr -d ' ')"
assert_eq "lock released" no "$([[ -d "$SB_RUNTIME_STATE_DIR/orchestrator.lock" ]] && echo yes || echo no)"

echo "=== parallel siblings finishing out of order ==="
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, active_intent:"i", flow_queue:["silver-fixture-read-a","silver-fixture-read-b","silver-plan"], current_flow:"silver-fixture-read-a",
  scheduler:{batches:[["AF-READ-A","AF-READ-B"],["AF-PLAN"]],batch_tokens:[["silver-fixture-read-a","silver-fixture-read-b"],["silver-plan"]],active_batch_index:0}}')"
rm -f "$DIRF"
sb_scheduler_refresh_active_batch_dispatch "$PROJ"
assert_eq "parallel batch directive" parallel "$(jq -r .batch_dispatch.dispatch_mode "$DIRF")"
sb_orchestrator_advance_on_atom silver-fixture-read-b "$PROJ" >/dev/null
assert_eq "second sibling finishes first: queue held" silver-fixture-read-a "$(orch_state_get .current_flow)"
assert_eq "second sibling finishes first: batch still active" 0 "$(orch_state_get .scheduler.active_batch_index)"
out="$(sb_orchestrator_advance_on_atom silver-fixture-read-a "$PROJ")"
assert_contains "last sibling completes the batch and chains on" "$out" "Next flow: silver-plan"
assert_eq "queue moved past the whole batch" silver-plan "$(orch_state_get .current_flow)"
assert_eq "next batch is dispatched" silver-plan "$(jq -r .next_skill "$DIRF")"
assert_eq "directive keeps the batch metadata" pending_dispatch "$(jq -r .batch_dispatch.status "$DIRF")"
unset SB_ORCHESTRATOR_PARALLEL_DISPATCH

echo "=== planner: dependencies and satisfied atoms (R4-19) ==="
PCAT="$TL_TMP/plan-cat.json"
cat >"$PCAT" <<'JSON'
{"atomic_flows":[
 {"id":"AF-A","slug":"a","execution":{"parallelizable":true,"mutation_scopes":["s1"]}},
 {"id":"AF-B","slug":"b","execution":{"parallelizable":true,"mutation_scopes":["s1"]}},
 {"id":"AF-C","slug":"c","execution":{"parallelizable":true,"mutation_scopes":["s2"],"depends_on_atoms":["AF-B"]}},
 {"id":"AF-P","slug":"p","execution":{"parallelizable":true,"mutation_scopes":["p"]}},
 {"id":"AF-S","slug":"s","execution":{"parallelizable":false}},
 {"id":"AF-D","slug":"d","execution":{"parallelizable":true,"mutation_scopes":["d"],"depends_on_atoms":["AF-P"]}}
],"migration_map":{"runtime_queue_tokens":{},"skill_to_entity":{}}}
JSON
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-A","AF-B","AF-C"]')"
assert_eq "an atom never shares a batch with its own dependency" '[["AF-A"],["AF-B"],["AF-C"]]' "$(jq -c .batches <<<"$plan")"
assert_eq "C is serialized because B is in the open batch" "depends_on_atoms in the same batch: AF-B" "$(jq -r '.scheduler_decisions[] | select(.atom_id=="AF-C") | .rationale' <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-P","AF-S","AF-D"]')"
assert_eq "dependency run in a flushed batch counts as satisfied" '[["AF-P"],["AF-S"],["AF-D"]]' "$(jq -c .batches <<<"$plan")"
assert_eq "D is not logged as unsatisfied" "dependency inputs satisfied and mutation scopes do not conflict" "$(jq -r '.scheduler_decisions[] | select(.atom_id=="AF-D") | .rationale' <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-D","AF-P"]')"
assert_eq "a dependency queued later is still unsatisfied" "catalog depends_on_atoms unsatisfied: AF-P" "$(jq -r '.scheduler_decisions[] | select(.atom_id=="AF-D") | .rationale' <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-P","AF-D"]')"
assert_eq "dependent follows its dependency in a new batch" '[["AF-P"],["AF-D"]]' "$(jq -c .batches <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-A","AF-P"]' '["tok-a","tok-p"]')"
assert_eq "independent atoms with distinct scopes share a batch" '[["AF-A","AF-P"]]' "$(jq -c .batches <<<"$plan")"
assert_eq "queue tokens travel with the batches" '[["tok-a","tok-p"]]' "$(jq -c .batch_tokens <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$PCAT" '["AF-A","AF-S","AF-B"]')"
assert_eq "a serial atom closes the open batch" '[["AF-A"],["AF-S"],["AF-B"]]' "$(jq -c .batches <<<"$plan")"

echo "=== Stop is released after repeated blocks with no progress (R4-05) ==="
orch_write_state '{"flow_queue":["silver-plan"],"current_flow":"silver-plan","repo_root":"/x"}'
rm -f "$SB_RUNTIME_STATE_DIR/orchestrator-stop-blocks.json"
SB_ORCHESTRATOR_STOP_BLOCK_LIMIT=3
export SB_ORCHESTRATOR_STOP_BLOCK_LIMIT
res=""
for _ in 1 2 3 4 5; do sb_orchestrator_stop_block_released && res="$res R" || res="$res B"; done
assert_eq "blocks up to the limit, then releases" " B B B R R" "$res"
orch_write_state '{"flow_queue":["silver-plan","silver-execute"],"current_flow":"silver-execute","repo_root":"/x"}'
sb_orchestrator_stop_block_released && res=R || res=B
assert_eq "progress in the queue restarts the count" B "$res"
SB_ORCHESTRATOR_STOP_BLOCK_LIMIT=junk sb_orchestrator_stop_block_released && res=R || res=B
assert_eq "a non-numeric limit falls back to 5" B "$res"
printf 'garbage' >"$SB_RUNTIME_STATE_DIR/orchestrator-stop-blocks.json"
sb_orchestrator_stop_block_released && res=R || res=B
assert_eq "a corrupt counter restarts at one" B "$res"
rm -f "$STATE"
sb_orchestrator_stop_block_released && res=R || res=B
assert_eq "no queue: nothing to release" B "$res"
( PATH="$(tl_path_without jq)"; orch_write_state '{}' 2>/dev/null; sb_orchestrator_stop_block_released ) && res=R || res=B
assert_eq "no jq: nothing to release" B "$res"
unset SB_ORCHESTRATOR_STOP_BLOCK_LIMIT

tl_results
