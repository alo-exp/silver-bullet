#!/usr/bin/env bash
# Behaviour tests for the log predicates of scripts/lib/enterprise-e2e-outcome-assessment.sh
# (babysitting, SB OVERRIDE, autonomy, agentmemory, graphify, evidence-written markers).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

# pred FUNCTION LINE...: run FUNCTION on a log made of LINEs; result in TL_STATUS.
n=0
pred() {
  local fn="$1"
  shift
  n=$((n + 1))
  oa_log "$TL_TMP/p$n.log" "$@"
  oa -- "enterprise_e2e_outcome_$fn" "$TL_TMP/p$n.log"
}
# expect NAME STATUS FUNCTION LINE...
expect() {
  local name="$1" want="$2"
  shift 2
  pred "$@"
  assert_eq "$name" "$want" "$TL_STATUS"
}

# --- babysitting ------------------------------------------------------------
expect "babysit: waiting for your input" 0 log_has_babysitting "agent is waiting for your input now"
expect "babysit: waiting for user to" 0 log_has_babysitting "Waiting for user to confirm"
expect "babysit: need your input before" 0 log_has_babysitting "I need your input before continuing"
expect "babysit: the word alone" 0 log_has_babysitting "this needed babysitting"
for neg in "without babysitting" "without operator babysit" "no babysit" "no operator babysit" "withoutbabysit" "nobabysit" "nooperatorbabysit" "withoutoperatorbabysit"; do
  expect "babysit: negated '$neg' is not babysitting" 1 log_has_babysitting "autonomy summary: $neg"
done
expect "babysit: negation elsewhere in the log excuses a mention" 1 log_has_babysitting "needed babysit" "all done without babysitting"
expect "babysit: operator pause" 0 log_has_babysitting "there was an operator pause here"
expect "babysit: operator pause negated by 'no clarify'" 1 log_has_babysitting "operator pause" "no clarify prompts"
expect "babysit: operator pause negated by 'no operator'" 1 log_has_babysitting "operator pause" "no operator needed"
expect "babysit: operator pause negated by 'without operator pause'" 1 log_has_babysitting "ran without operator pause"
expect "babysit: operator pause negated by autonomous_default" 1 log_has_babysitting "operator pause" "autonomous_default=1"
expect "babysit: unrelated log" 1 log_has_babysitting "all good"
oa -- enterprise_e2e_outcome_log_has_babysitting "$TL_TMP/absent.log"
assert_eq "babysit: missing log" 1 "$TL_STATUS"
oa -- enterprise_e2e_outcome_log_has_babysitting
assert_eq "babysit: no argument" 1 "$TL_STATUS"

# --- SB OVERRIDE ------------------------------------------------------------
expect "override: audited usage" 0 log_has_sb_override "SB OVERRIDE: because reasons"
expect "override: instruction text only" 1 log_has_sb_override "issue SB OVERRIDE when blocked"
expect "override: case-insensitive" 0 log_has_sb_override "sb override: lower"

# --- autonomous / worker completion ----------------------------------------
for line in "autonomous run" "orchestrator active" "SB ► feature composed" "worker spawned" "Task worker ran" "general-purpose agent Execute step" "general-purpose ROUTER" "SB orchestrator took over"; do
  expect "autonomous: '$line'" 0 log_has_autonomous "$line"
done
expect "autonomous: worker completion alone suffices" 0 log_has_autonomous "worker completed"
expect "autonomous: nothing" 1 log_has_autonomous "plain output"
for line in "worker completed" "delegated SB worker" "delegated Composer" "completed via a delegated agent" "workflow is complete" "Workflow complete" "workflow_complete: true" "workflow ran through" "completion-audit → SHIP" "completion-audit gate SHIP" "Review-triad done" "Review triad done" "Branch readiness workflow ok" "verdict: COMPLETE" "next_skill: null" "Verdict: **PASS" "Result: **PASS**" "0 BLOCK findings" "Workflow evidence was reconciled"; do
  expect "worker completion: '$line'" 0 log_has_worker_completion "$line"
done
expect "worker completion: unrelated" 1 log_has_worker_completion "still working"
oa -- enterprise_e2e_outcome_log_has_worker_completion "$TL_TMP/absent.log"
assert_eq "worker completion: missing log" 1 "$TL_STATUS"
oa -- enterprise_e2e_outcome_log_has_worker_completion
assert_eq "worker completion: no argument" 1 "$TL_STATUS"

# --- orchestrator handoff ---------------------------------------------------
W="$TL_TMP/w-handoff"
mkdir -p "$W/.planning"
oa_log "$TL_TMP/h1.log" "nothing"
oa_log "$TL_TMP/h2.log" "worker completed"
ho() { oa -- enterprise_e2e_outcome_log_has_orchestrator_handoff "$@"; }
ho "$TL_TMP/h2.log" ""
assert_eq "handoff: worker completion in the log" 0 "$TL_STATUS"
ho "$TL_TMP/h1.log" ""
assert_eq "handoff: nothing, no work dir" 1 "$TL_STATUS"
ho "$TL_TMP/h1.log" "$W"
assert_eq "handoff: work dir without composition log" 1 "$TL_STATUS"
: >"$W/.planning/orchestrator-composition-log.jsonl"
ho "$TL_TMP/h1.log" "$W"
assert_eq "handoff: empty composition log is not a handoff" 1 "$TL_STATUS"
echo '{}' >"$W/.planning/orchestrator-composition-log.jsonl"
ho "$TL_TMP/h1.log" "$W"
assert_eq "handoff: non-empty composition log" 0 "$TL_STATUS"

# --- agentmemory MCP --------------------------------------------------------
expect "am mcp: agentmemory memory_save" 0 log_has_agentmemory_mcp "calling agentmemory memory_save now"
expect "am mcp: agentmemory-memory_recall" 0 log_has_agentmemory_mcp "agentmemory-memory_recall"
expect "am mcp: agentmenory typo form" 0 log_has_agentmemory_mcp "agentmenory memory_capture"
expect "am mcp: tool (MCP) form" 0 log_has_agentmemory_mcp "memory_recall (MCP) returned"
expect "am mcp: agentmemory ... (MCP)" 0 log_has_agentmemory_mcp "agentmemory server tool (MCP)"
expect "am mcp: bare memory_save (codex TUI)" 0 log_has_agentmemory_mcp "memory_save ran"
expect "am mcp: mem_mr export id" 0 log_has_agentmemory_mcp "exported mem_mr12abc"
expect "am mcp: nothing" 1 log_has_agentmemory_mcp "no memory tools"
expect "am mcp: hidden tool-call body found by the raw fallback" 0 log_has_agentmemory_mcp 'HARNESS x' '{"type":"readToolCall","text":"agentmemory memory_save"}'
expect "am mcp: hidden (MCP) mention found by the raw fallback" 0 log_has_agentmemory_mcp 'HARNESS x' '{"type":"readToolCall","text":"agentmemory tool (MCP)"}'
expect "am mcp: stream log with nothing relevant" 1 log_has_agentmemory_mcp 'HARNESS x' '{"type":"readToolCall","text":"nothing"}'
oa -- enterprise_e2e_outcome_log_has_agentmemory_mcp "$TL_TMP/absent.log"
assert_eq "am mcp: missing log" 1 "$TL_STATUS"

# --- agentmemory capture ----------------------------------------------------
expect "am capture: persisted to agentmemory" 0 log_has_agentmemory_capture "verdict persisted to agentmemory"
expect "am capture: memory_save form" 0 log_has_agentmemory_capture "agentmemory - memory_save ok"
expect "am capture: smart_search form" 0 log_has_agentmemory_capture "agentmemory - memory_smart_search ok"
expect "am capture: saved to agentmemory" 0 log_has_agentmemory_capture "decision is saved to agentmemory"
expect "am capture: nothing" 1 log_has_agentmemory_capture "nothing stored"

# --- workflow evidence written ---------------------------------------------
expect "wf evidence: WROTE workflows" 0 log_has_workflow_evidence_written "WROTE: /x/.planning/workflows/a.md"
expect "wf evidence: Evidence written to" 0 log_has_workflow_evidence_written "Evidence   written   to   .planning/workflows/"
expect "wf evidence: workflow md path" 0 log_has_workflow_evidence_written "see .planning/workflows/feature-currency.md"
expect "wf evidence: WROTE reviews" 0 log_has_workflow_evidence_written "WROTE: out .planning/reviews/x"
expect "wf evidence: review md path" 0 log_has_workflow_evidence_written "triad in .planning/reviews/triad-currency.md"
expect "wf evidence: WROTE ship-readiness" 0 log_has_workflow_evidence_written "WROTE: out .planning/ship-readiness/x"
expect "wf evidence: ship-readiness md path" 0 log_has_workflow_evidence_written "checklist at .planning/ship-readiness/checklist.md"
expect "wf evidence: nothing" 1 log_has_workflow_evidence_written "wrote nothing"

# --- graphify activity ------------------------------------------------------
expect "graphify: graphify query" 0 log_has_graphify_activity "ran graphify query foo"
expect "graphify: query --graph" 0 log_has_graphify_activity 'query "what" --graph graph.json'
expect "graphify: graphify update" 0 log_has_graphify_activity "graphify update ."
expect "graphify: Skill(graphify)" 0 log_has_graphify_activity "Skill ( graphify )"
expect "graphify: graph.json path" 0 log_has_graphify_activity "read graphify-out/graph.json"
expect "graphify: hidden query found by the raw fallback" 0 log_has_graphify_activity 'HARNESS x' '{"type":"readToolCall","text":"graphify query inside body"}'
expect "graphify: nothing" 1 log_has_graphify_activity "plain"
oa -- enterprise_e2e_outcome_log_has_graphify_activity "$TL_TMP/absent.log"
assert_eq "graphify: missing log" 1 "$TL_STATUS"

# --- agentmemory unavailable ------------------------------------------------
expect "am unavailable: not available" 0 log_has_agentmemory_unavailable "agentmemory is not available"
expect "am unavailable: matrix MCP env disabled" 0 log_has_agentmemory_unavailable "matrix MCP env: disabled"
expect "am unavailable: hidden mention via raw fallback" 0 log_has_agentmemory_unavailable 'HARNESS x' '{"type":"readToolCall","text":"agentmemory MCP"}'
expect "am unavailable: hidden env disabled via raw fallback" 0 log_has_agentmemory_unavailable 'HARNESS x' '{"type":"readToolCall","text":"matrix MCP env: disabled"}'
expect "am unavailable: nothing" 1 log_has_agentmemory_unavailable "all fine"
oa -- enterprise_e2e_outcome_log_has_agentmemory_unavailable "$TL_TMP/absent.log"
assert_eq "am unavailable: missing log" 1 "$TL_STATUS"

tl_results
