#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-directive.sh (directive contract, flow->skill map,
# override helpers, context block, state/outcome sync, delegation seeding).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_AGENT_DELEGATE_GUARD
# shellcheck source=../../hooks/lib/orchestrator-state.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"
# shellcheck source=../../hooks/lib/orchestrator-directive.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh"

DIR="$(orch_directive_file)"

echo "=== paths ==="
assert_eq "directive file lives in the state dir" "$SB_RUNTIME_STATE_DIR/orchestrator-directive.json" "$(sb_orchestrator_directive_file)"
assert_eq "override log lives under .planning" "/r/.planning/orchestrator-override-log.jsonl" "$(sb_orchestrator_override_log /r)"
assert_eq "override log defaults to PWD" "$PWD/.planning/orchestrator-override-log.jsonl" "$(sb_orchestrator_override_log)"

echo "=== flow_to_skill ==="
while IFS='=' read -r flow want; do
  assert_eq "flow $flow" "$want" "$(sb_orchestrator_flow_to_skill "$flow")"
done <<'MAP'
FLOW-QUALITY-GATE=silver-quality-gates
FLOW-QUALITY-GATE-PRESHIP=silver-quality-gates
QUALITY GATE=silver-quality-gates
QUALITYGATE=silver-quality-gates
FLOW-DEVOPS-QUALITY-GATE-PRESHIP=devops-quality-gates
devops-quality-gates=devops-quality-gates
DEVOPS-QUALITY-GATES=devops-quality-gates
devops-skill-router=devops-skill-router
DEVOPS-SKILL-ROUTER=devops-skill-router
FLOW-DESIGN-HANDOFF=silver-handoff
DESIGN-HANDOFF=silver-handoff
DESIGN HANDOFF=silver-handoff
FLOW-BOOTSTRAP=silver-init
BOOTSTRAP=silver-init
FLOW-ORIENT=silver-context
ORIENT=silver-context
FLOW-CLARIFY=silver-clarify
CLARIFY=silver-clarify
FLOW-DECIDE=silver-deep-research
DECIDE=silver-deep-research
FLOW-SPECIFY=silver-spec
SPECIFY=silver-spec
FLOW-PLAN=silver-plan
PLAN=silver-plan
FLOW-DESIGN-CONTRACT=silver-ui-contract
DESIGN-CONTRACT=silver-ui-contract
DESIGN CONTRACT=silver-ui-contract
FLOW-EXECUTE=silver-execute
EXECUTE=silver-execute
FLOW-UI-QUALITY=silver-ui-review
UI-QUALITY=silver-ui-review
UI QUALITY=silver-ui-review
FLOW-REVIEW=silver-review
REVIEW=silver-review
FLOW-REVIEW-REQUEST=silver-review-request
REVIEW-REQUEST=silver-review-request
REVIEW REQUEST=silver-review-request
FLOW-REVIEW-TRIAGE=silver-review-triage
REVIEW-TRIAGE=silver-review-triage
REVIEW TRIAGE=silver-review-triage
FLOW-VERIFY=silver-verify
VERIFY=silver-verify
FLOW-SECURE=security
SECURE=security
FLOW-SHIP=silver-ship
SHIP=silver-ship
FLOW-DEBUG=silver-debug
DEBUG=silver-debug
FLOW-DOCUMENT=silver-ensure-docs
DOCUMENT=silver-ensure-docs
FLOW-RELEASE=silver-create-release
RELEASE=silver-create-release
FLOW-BLAST-RADIUS=silver-blast-radius
BLAST-RADIUS=silver-blast-radius
BLAST RADIUS=silver-blast-radius
FLOW-VALIDATE=silver-validate
VALIDATE=silver-validate
security=security
SECURITY=security
silver-anything=silver-anything
FLOW-DEVOPS-SKILL-ROUTER=devops-skill-router
FLOW-NOVEL-THING=silver-novel-thing
multi-word=silver-multi-word
Shout=silver-shout
MAP

echo "=== directive_write ==="
sb_orchestrator_directive_write "" && rc=0 || rc=$?
assert_eq "empty skill rejected" 1 "$rc"
assert_file_absent "nothing written for empty skill" "$DIR"
( PATH="$(tl_path_without jq)"; sb_orchestrator_directive_write silver-plan ) && rc=0 || rc=$?
assert_eq "no jq: write fails" 1 "$rc"
sb_orchestrator_directive_write silver-plan "the intent" "because" true
assert_eq "next_skill" silver-plan "$(orch_directive_get .next_skill)"
assert_eq "args" "the intent" "$(orch_directive_get .args)"
assert_eq "reason" because "$(orch_directive_get .reason)"
assert_eq "blocking" true "$(orch_directive_get .blocking)"
assert_eq "worker template derived from the skill" PLAN "$(orch_directive_get .next_worker_template)"
assert_match "updated_at is an ISO timestamp" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(orch_directive_get .updated_at)"
sb_orchestrator_directive_write silver-plan "" "" 1 EXPLICIT
assert_eq "explicit template wins" EXPLICIT "$(orch_directive_get .next_worker_template)"
assert_eq "blocking=1 means true" true "$(orch_directive_get .blocking)"
assert_eq "default reason" "Orchestrator queued next flow" "$(orch_directive_get .reason)"
sb_orchestrator_directive_write silver-plan "" "r" no
assert_eq "other blocking values mean false" false "$(orch_directive_get .blocking)"
# Without the parent lib loaded the mapper is sourced on demand; with an unmappable setup the template is null.
(
  unset -f sb_orchestrator_worker_template_for_skill
  sb_orchestrator_directive_write silver-verify
  [[ "$(jq -r .next_worker_template "$DIR")" == VERIFY ]]
) && rc=0 || rc=$?
assert_eq "mapper is loaded on demand" 0 "$rc"
staged="$TL_TMP/staged-lib"
mkdir -p "$staged"
cp "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh" "$staged/"
(
  unset -f sb_orchestrator_worker_template_for_skill
  # shellcheck disable=SC1091
  source "$staged/orchestrator-directive.sh"
  sb_orchestrator_directive_write silver-verify
  [[ "$(jq -r .next_worker_template "$DIR")" == null ]]
) && rc=0 || rc=$?
assert_eq "no mapper available: template is null" 0 "$rc"
# jq failure while building the document.
tl_stub jq 'exit 1'
sb_orchestrator_directive_write silver-plan && rc=0 || rc=$?
assert_eq "jq failure: write returns 1" 1 "$rc"
rm -f "$TL_BIN/jq"

echo "=== directive_write_batch ==="
rm -f "$DIR"
batch='{"dispatch_mode":"parallel","handoffs":[{"id":"a","join_status":"joined"},{"id":"b","join_status":"pending"}]}'
sb_orchestrator_directive_write_batch "" "" "" true "" "$batch" && rc=0 || rc=$?
assert_eq "batch: empty skill rejected" 1 "$rc"
sb_orchestrator_directive_write_batch silver-plan "" "" true "" "" && rc=0 || rc=$?
assert_eq "batch: empty batch rejected" 1 "$rc"
( PATH="$(tl_path_without jq)"; sb_orchestrator_directive_write_batch silver-plan "" "" true "" "$batch" ) && rc=0 || rc=$?
assert_eq "batch: no jq rejected" 1 "$rc"
sb_orchestrator_directive_write_batch silver-plan "" "" true "" "{not json" && rc=0 || rc=$?
assert_eq "batch: malformed batch JSON rejected" 1 "$rc"
assert_file_absent "batch: nothing written for malformed batch" "$DIR"
sb_orchestrator_directive_write_batch silver-plan "a" "why" true "" "$batch"
assert_eq "batch: dispatch_mode stored" parallel "$(orch_directive_get .batch_dispatch.dispatch_mode)"
assert_eq "batch: template derived" PLAN "$(orch_directive_get .next_worker_template)"
assert_eq "batch: blocking true" true "$(orch_directive_get .blocking)"
sb_orchestrator_directive_write_batch silver-plan "" "" 0 TPL "$batch"
assert_eq "batch: explicit template" TPL "$(orch_directive_get .next_worker_template)"
assert_eq "batch: blocking false" false "$(orch_directive_get .blocking)"
assert_eq "batch: default reason" "Orchestrator queued next flow" "$(orch_directive_get .reason)"
(
  unset -f sb_orchestrator_worker_template_for_skill
  sb_orchestrator_directive_write_batch silver-verify "" "" true "" "$batch"
  [[ "$(jq -r .next_worker_template "$DIR")" == VERIFY ]]
) && rc=0 || rc=$?
assert_eq "batch: mapper loaded on demand" 0 "$rc"
(
  unset -f sb_orchestrator_worker_template_for_skill
  # shellcheck disable=SC1091
  source "$staged/orchestrator-directive.sh"
  sb_orchestrator_directive_write_batch silver-verify "" "" true "" "$batch"
  [[ "$(jq -r .next_worker_template "$DIR")" == null ]]
) && rc=0 || rc=$?
assert_eq "batch: no mapper available gives null template" 0 "$rc"
# jq works for parsing the batch, then fails building the document.
tl_stub jq 'if [[ "$1" == "-c" ]]; then exec '"$(command -v jq)"' "$@"; fi; exit 1'
sb_orchestrator_directive_write_batch silver-plan "" "" true TPL "$batch" && rc=0 || rc=$?
assert_eq "batch: document build failure returns 1" 1 "$rc"
rm -f "$TL_BIN/jq"

echo "=== clear / read / next_skill / blocking ==="
sb_orchestrator_directive_clear
assert_file_absent "clear removes the directive" "$DIR"
sb_orchestrator_directive_clear
sb_orchestrator_directive_read && rc=0 || rc=$?
assert_eq "read without file fails" 1 "$rc"
sb_orchestrator_directive_next_skill && rc=0 || rc=$?
assert_eq "next_skill without file fails" 1 "$rc"
sb_orchestrator_directive_is_blocking && rc=0 || rc=$?
assert_eq "is_blocking without file fails" 1 "$rc"
sb_orchestrator_directive_write silver-plan "" "r" true
assert_contains "read prints the document" "$(sb_orchestrator_directive_read)" '"next_skill": "silver-plan"'
assert_eq "next_skill prints the skill" silver-plan "$(sb_orchestrator_directive_next_skill)"
sb_orchestrator_directive_is_blocking && rc=0 || rc=$?
assert_eq "blocking directive detected" 0 "$rc"
sb_orchestrator_directive_write silver-plan "" "r" false
sb_orchestrator_directive_is_blocking && rc=0 || rc=$?
assert_eq "non-blocking directive" 1 "$rc"
printf 'garbage' >"$DIR"
assert_eq "next_skill tolerates corrupt JSON" "" "$(sb_orchestrator_directive_next_skill)"
sb_orchestrator_directive_is_blocking && rc=0 || rc=$?
assert_eq "corrupt JSON is not blocking" 1 "$((rc != 0))"

echo "=== skill_recorded ==="
sb_orchestrator_directive_skill_recorded "" "x" && rc=0 || rc=$?
assert_eq "empty expected" 1 "$rc"
sb_orchestrator_directive_skill_recorded "x" "" && rc=0 || rc=$?
assert_eq "empty state" 1 "$rc"
sb_orchestrator_directive_skill_recorded silver-plan $'silver-context\nsilver-plan' && rc=0 || rc=$?
assert_eq "grep fallback matches a whole line" 0 "$rc"
sb_orchestrator_directive_skill_recorded silver-pla $'silver-context\nsilver-plan' && rc=0 || rc=$?
assert_eq "grep fallback needs the full line" 1 "$rc"
sb_required_skill_is_recorded() { [[ "$2" == silver-special ]]; }
sb_orchestrator_directive_skill_recorded silver-special "ignored" && rc=0 || rc=$?
assert_eq "delegates to sb_required_skill_is_recorded when present" 0 "$rc"
sb_orchestrator_directive_skill_recorded silver-plan "silver-plan" && rc=0 || rc=$?
assert_eq "delegate verdict is final" 1 "$rc"
unset -f sb_required_skill_is_recorded

echo "=== context block ==="
rm -f "$DIR"
assert_eq "no directive: empty block" "" "$(sb_orchestrator_directive_context_block)"
( PATH="$(tl_path_without jq)"; sb_orchestrator_directive_write silver-plan ) || true
sb_orchestrator_directive_write silver-plan "build it" "queued" true
out="$(PATH="$(tl_path_without jq)" sb_orchestrator_directive_context_block)"
assert_eq "no jq: empty block" "" "$out"
unset -f sb_orchestrator_spawn_tool_label
block="$(sb_orchestrator_directive_context_block)"
assert_contains "block names the skill" "$block" "next_skill: silver-plan"
assert_contains "block names the template" "$block" "next_worker_template: PLAN.md"
assert_contains "block shows args" "$block" "args: build it"
assert_contains "block shows reason" "$block" "reason: queued"
assert_contains "blocking block explains the contract" "$block" "blocking: true"
assert_contains "block keeps the generic spawn wording" "$block" "spawn Task worker"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"
block="$(SILVER_BULLET_RUNTIME=codex sb_orchestrator_directive_context_block)"
assert_contains "spawn wording follows the host" "$block" "spawn spawn_agent (multi_agent_v1.spawn_agent)"
sb_orchestrator_directive_write_batch silver-plan "" "r" false "" "$batch"
block="$(sb_orchestrator_directive_context_block)"
assert_contains "batch summary in block" "$block" "batch_dispatch: parallel batch (2 handoff(s); 1 pending join)"
assert_contains "non-blocking block" "$block" "blocking: false"
assert_not_contains "no args line when args empty" "$block" "args:"
printf '{"next_skill":"s","batch_dispatch":{"handoffs":[]},"blocking":true}' >"$DIR"
block="$(sb_orchestrator_directive_context_block)"
assert_contains "batch without dispatch_mode defaults to sequential" "$block" "batch_dispatch: sequential batch (0 handoff(s); 0 pending join)"
assert_contains "missing reason defaults" "$block" "reason: queued flow"
printf '{"next_skill":""}' >"$DIR"
assert_eq "empty next_skill: empty block" "" "$(sb_orchestrator_directive_context_block)"
printf 'garbage' >"$DIR"
assert_eq "corrupt directive: empty block" "" "$(sb_orchestrator_directive_context_block)"

echo "=== override helpers ==="
proj="$TL_TMP/proj"
mkdir -p "$proj/.planning"
sb_orchestrator_log_override "" "why" && rc=0 || rc=$?
assert_eq "log_override without root is a no-op" 0 "$rc"
sb_orchestrator_log_override "$TL_TMP/none" "why"
assert_file_absent "no .planning dir: nothing logged" "$TL_TMP/none/.planning"
( PATH="$(tl_path_without jq)"; sb_orchestrator_log_override "$proj" "why" )
assert_file_absent "no jq: nothing logged" "$proj/.planning/orchestrator-override-log.jsonl"
sb_orchestrator_log_override "$proj" "because" silver-plan
sb_orchestrator_log_override "$proj" "again"
log="$proj/.planning/orchestrator-override-log.jsonl"
assert_eq "two entries appended" 2 "$(wc -l <"$log" | tr -d ' ')"
assert_eq "entry kind" directive-override "$(sed -n 1p "$log" | jq -r .kind)"
assert_eq "entry reason" because "$(sed -n 1p "$log" | jq -r .reason)"
assert_eq "entry expected_skill" silver-plan "$(sed -n 1p "$log" | jq -r .expected_skill)"
sb_orchestrator_prompt_has_override "please SB OVERRIDE: skip it" && rc=0 || rc=$?
assert_eq "override marker detected" 0 "$rc"
sb_orchestrator_prompt_has_override "sb   override: lower case" && rc=0 || rc=$?
assert_eq "override marker is case-insensitive" 0 "$rc"
sb_orchestrator_prompt_has_override "no marker here" && rc=0 || rc=$?
assert_eq "no marker" 1 "$rc"
assert_eq "reason extracted" "skip the gate" "$(sb_orchestrator_extract_override_reason "hello SB OVERRIDE: skip the gate")"
assert_eq "reason extraction is case-insensitive" "go" "$(sb_orchestrator_extract_override_reason "sb override: go")"
assert_eq "no reason without marker" "" "$(sb_orchestrator_extract_override_reason "nothing")"

echo "=== sync from state ==="
rm -f "$DIR"
sb_orchestrator_sync_directive_from_state
assert_file_absent "no orchestrator state: no directive" "$DIR"
orch_write_state '{"current_flow":"","active_intent":"x"}'
sb_orchestrator_sync_directive_from_state
assert_file_absent "empty current_flow: no directive" "$DIR"
orch_write_state '{"current_flow":null}'
sb_orchestrator_sync_directive_from_state
assert_file_absent "null current_flow: no directive" "$DIR"
orch_write_state '{"current_flow":"FLOW-PLAN","active_intent":"ship the thing"}'
( PATH="$(tl_path_without jq)"; sb_orchestrator_sync_directive_from_state )
assert_file_absent "no jq: no directive" "$DIR"
sb_orchestrator_sync_directive_from_state
assert_eq "directive follows current_flow" silver-plan "$(orch_directive_get .next_skill)"
assert_eq "directive carries the intent" "ship the thing" "$(orch_directive_get .args)"
assert_contains "directive reason" "$(orch_directive_get .reason)" "complete silver-plan before other tools"

echo "=== pending outcome ==="
rm -f "$DIR"
sb_orchestrator_directive_from_pending_outcome
assert_file_absent "no outcomes file: nothing" "$DIR"
out="$SB_RUNTIME_STATE_DIR/outcomes-session.json"
for pair in route:silver scope:silver-context verify:silver-verify; do
  oid="${pair%%:*}"; want="${pair#*:}"
  jq -n --arg id "$oid" '{outcomes:[{id:"x0",status:"done"},{id:$id,status:"pending"}]}' >"$out"
  sb_orchestrator_directive_from_pending_outcome
  assert_eq "pending $oid outcome maps to $want" "$want" "$(orch_directive_get .next_skill)"
  rm -f "$DIR"
done
jq -n '{outcomes:[{id:"other",status:"pending"}]}' >"$out"
sb_orchestrator_directive_from_pending_outcome
assert_file_absent "unknown outcome id: no directive" "$DIR"
jq -n '{outcomes:[{id:"route",status:"done"}]}' >"$out"
sb_orchestrator_directive_from_pending_outcome
assert_file_absent "all outcomes done: no directive" "$DIR"
printf 'garbage' >"$out"
sb_orchestrator_directive_from_pending_outcome
assert_file_absent "corrupt outcomes file: no directive" "$DIR"
( PATH="$(tl_path_without jq)"; sb_orchestrator_directive_from_pending_outcome )
assert_file_absent "no jq: no directive" "$DIR"
sb_outcomes_session_file() { printf '%s/custom.json' "$TL_TMP"; }
jq -n '{outcomes:[{id:"scope",status:"pending"}]}' >"$TL_TMP/custom.json"
sb_orchestrator_directive_from_pending_outcome
assert_eq "honors sb_outcomes_session_file" silver-context "$(orch_directive_get .next_skill)"
unset -f sb_outcomes_session_file

echo "=== seed delegation directive ==="
rm -f "$DIR" "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
sb_orchestrator_seed_delegation_directive badhost T1 /b/brief.md && rc=0 || rc=$?
assert_eq "unknown host rejected" 1 "$rc"
sb_orchestrator_seed_delegation_directive codex "" /b/brief.md && rc=0 || rc=$?
assert_eq "empty task id rejected" 1 "$rc"
sb_orchestrator_seed_delegation_directive codex T1 "" && rc=0 || rc=$?
assert_eq "empty brief rejected" 1 "$rc"
( PATH="$(tl_path_without jq)"; sb_orchestrator_seed_delegation_directive codex T1 /b/brief.md ) && rc=0 || rc=$?
assert_eq "no jq rejected" 1 "$rc"
for host in codex cursor claude opencode pi; do
  sb_orchestrator_seed_delegation_directive "$host" "T-$host" "$TL_TMP/b/brief.md" "[\"$TL_TMP/b\"]"
  assert_eq "$host: skill" "silver-agent-$host" "$(orch_directive_get .next_skill)"
  assert_eq "$host: template" AGENT-DELEGATE "$(orch_directive_get .next_worker_template)"
done
args="$(orch_directive_get .args)"
assert_eq "args carry the atomic flow id" AF-AGENT-DELEGATE "$(jq -r .atomic_flow_id <<<"$args")"
assert_eq "args carry the ownership scope" "$TL_TMP/b" "$(jq -r '.ownership_scope[0]' <<<"$args")"
assert_eq "delegation state activated for the host" pi "$(jq -r .host "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json")"
assert_eq "delegation work_dir is the brief's directory" "$TL_TMP/b" "$(jq -r .work_dir "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json")"
# A lib directory without the delegation state lib still writes the directive.
cp "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh" "$staged/"
rm -f "$DIR" "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
(
  # shellcheck disable=SC1091
  source "$staged/orchestrator-directive.sh"
  sb_orchestrator_seed_delegation_directive codex T1 "$TL_TMP/b/brief.md"
)
assert_eq "lib-less staging still writes the directive" silver-agent-codex "$(orch_directive_get .next_skill)"
assert_file_absent "lib-less staging does not activate delegation" "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"

tl_results
