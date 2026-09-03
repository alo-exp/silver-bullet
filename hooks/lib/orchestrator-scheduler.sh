# shellcheck shell=bash
# Catalog-driven runtime scheduler — parallel batches, mutation-scope safety, join gates (Phase B).

_sb_scheduler_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${_sb_scheduler_lib_dir}/orchestrator-state.sh" ]]; then
  # shellcheck source=lib/orchestrator-state.sh
  source "${_sb_scheduler_lib_dir}/orchestrator-state.sh"
fi
if [[ -f "${_sb_scheduler_lib_dir}/orchestrator-skill-atom.sh" ]]; then
  # shellcheck source=lib/orchestrator-skill-atom.sh
  source "${_sb_scheduler_lib_dir}/orchestrator-skill-atom.sh"
fi
if [[ -f "${_sb_scheduler_lib_dir}/orchestrator-event-log.sh" ]]; then
  # shellcheck source=lib/orchestrator-event-log.sh
  source "${_sb_scheduler_lib_dir}/orchestrator-event-log.sh"
fi

# Runtime scheduler (catalog batches / join gates). Set SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 to disable.
sb_scheduler_runtime_enabled() {
  case "${SB_ORCHESTRATOR_RUNTIME_SCHEDULER:-1}" in
    0|false|no|FALSE|NO|off|OFF) return 1 ;;
    *) return 0 ;;
  esac
}

sb_scheduler_catalog_file() {
  local repo_root="${1:-}"
  sb_scheduler_runtime_enabled || return 1
  if [[ -n "${SB_APO_CATALOG_FILE:-}" && -f "${SB_APO_CATALOG_FILE}" ]]; then
    printf '%s' "${SB_APO_CATALOG_FILE}"
    return 0
  fi
  if [[ -n "$repo_root" && -f "$repo_root/docs/apo-catalog.json" ]]; then
    printf '%s/docs/apo-catalog.json' "$repo_root"
    return 0
  fi
  if [[ -f "${_sb_scheduler_lib_dir}/../../docs/apo-catalog.json" ]]; then
    printf '%s/../../docs/apo-catalog.json' "$_sb_scheduler_lib_dir"
    return 0
  fi
  return 1
}

# Resolve queue token or skill name to catalog atomic-flow id (AF-*).
# Implemented in orchestrator-skill-atom.sh (migration_map + fallbacks).

# Returns 0 when mutation scope sets overlap (must serialize).
sb_scheduler_mutation_scopes_conflict() {
  local scopes_a_json="$1" scopes_b_json="$2"
  command -v jq >/dev/null 2>&1 || return 1
  jq -en --argjson a "$scopes_a_json" --argjson b "$scopes_b_json" '
    [($a[] | select(. as $x | ($b | index($x)) != null))] | length > 0
  ' >/dev/null 2>&1
}

# Plan parallel-safe dispatch batches for ordered atom ids. Prints JSON plan to stdout.
sb_scheduler_plan_batches_json() {
  local catalog_file="$1" atoms_json="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$catalog_file" "$atoms_json" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
atom_ids = json.loads(sys.argv[2])
atoms = {item["id"]: item for item in catalog.get("atomic_flows", [])}

batches = []
decisions = []
dispatch_records = []

def scopes_for(aid):
    flow = atoms.get(aid, {})
    return set(flow.get("execution", {}).get("mutation_scopes", []))

def depends_on_atoms(aid):
    flow = atoms.get(aid, {})
    deps = flow.get("execution", {}).get("depends_on_atoms", [])
    return [d for d in deps if isinstance(d, str) and d.startswith("AF-")]

def dependencies_satisfied(aid, prior_atoms):
    return all(d in prior_atoms for d in depends_on_atoms(aid))

def batch_conflicts(batch, aid):
    s = scopes_for(aid)
    for other in batch:
        if s & scopes_for(other):
            return True, sorted(s & scopes_for(other))
    return False, []

current = []
prior_atoms = set()
for aid in atom_ids:
    flow = atoms.get(aid)
    if not flow:
        decisions.append({"atom_id": aid, "decision": "skip", "rationale": "unknown catalog atom"})
        continue
    if not dependencies_satisfied(aid, prior_atoms):
        if current:
            batches.append(current)
            prior_atoms.update(current)
            current = []
        batches.append([aid])
        execution = flow.get("execution", {})
        scopes = sorted(scopes_for(aid))
        worker = execution.get("worker_template", "")
        shape = execution.get("dispatch_record_shape", "")
        missing = [d for d in depends_on_atoms(aid) if d not in prior_atoms]
        decisions.append({
            "atom_id": aid,
            "decision": "serialized",
            "catalog_rule_ref": "DR-PARALLELIZE-INDEPENDENT-ATOMS",
            "rationale": f"catalog depends_on_atoms unsatisfied: {', '.join(missing)}",
            "mutation_scopes": scopes,
        })
        dispatch_records.append({
            "atomic_flow_id": aid,
            "worker_template": worker,
            "mutation_scopes": scopes,
            "scheduling": "serialized",
            "serialization_rationale": f"depends_on_atoms: {', '.join(missing)}",
            "join_status": "pending",
            "step_v_loop_status": "pending",
            "v_gate_result": "pending",
            "retries": 0,
            "dispatch_record_shape": shape,
        })
        prior_atoms.add(aid)
        continue
    execution = flow.get("execution", {})
    parallelizable = bool(execution.get("parallelizable", False))
    scopes = sorted(scopes_for(aid))
    worker = execution.get("worker_template", "")
    shape = execution.get("dispatch_record_shape", "")

    if not parallelizable:
        if current:
            batches.append(current)
            current = []
        batches.append([aid])
        decisions.append({
            "atom_id": aid,
            "decision": "serialized",
            "catalog_rule_ref": "DR-PARALLELIZE-INDEPENDENT-ATOMS",
            "rationale": "atom is not parallelizable per catalog execution metadata",
            "mutation_scopes": scopes,
        })
        dispatch_records.append({
            "atomic_flow_id": aid,
            "worker_template": worker,
            "mutation_scopes": scopes,
            "scheduling": "serialized",
            "serialization_rationale": "not parallelizable",
            "join_status": "pending",
            "step_v_loop_status": "pending",
            "v_gate_result": "pending",
            "retries": 0,
            "dispatch_record_shape": shape,
        })
        prior_atoms.add(aid)
        continue

    conflict, overlap = batch_conflicts(current, aid)
    if current and conflict:
        batches.append(current)
        prior_atoms.update(current)
        current = []
        decisions.append({
            "atom_id": aid,
            "decision": "serialized",
            "catalog_rule_ref": "DR-PARALLELIZE-INDEPENDENT-ATOMS",
            "rationale": f"mutation scope conflict with prior batch: {', '.join(overlap)}",
            "mutation_scopes": scopes,
        })
        dispatch_records.append({
            "atomic_flow_id": aid,
            "worker_template": worker,
            "mutation_scopes": scopes,
            "scheduling": "serialized",
            "serialization_rationale": f"mutation scope conflict: {', '.join(overlap)}",
            "join_status": "pending",
            "step_v_loop_status": "pending",
            "v_gate_result": "pending",
            "retries": 0,
            "dispatch_record_shape": shape,
        })
        current = [aid]
        prior_atoms.add(aid)
        continue

    current.append(aid)
    decisions.append({
        "atom_id": aid,
        "decision": "parallel",
        "catalog_rule_ref": "DR-PARALLELIZE-INDEPENDENT-ATOMS",
        "rationale": "dependency inputs satisfied and mutation scopes do not conflict",
        "mutation_scopes": scopes,
    })
    dispatch_records.append({
        "atomic_flow_id": aid,
        "worker_template": worker,
        "mutation_scopes": scopes,
        "scheduling": "parallel",
        "serialization_rationale": "",
        "join_status": "pending",
        "step_v_loop_status": "pending",
        "v_gate_result": "pending",
        "retries": 0,
        "dispatch_record_shape": shape,
    })

if current:
    batches.append(current)
    prior_atoms.update(current)

print(json.dumps({
    "batches": batches,
    "scheduler_decisions": decisions,
    "dispatch_records": dispatch_records,
}, separators=(",", ":")))
PY
}

# Merge scheduler plan into orchestrator.json under .scheduler.
sb_scheduler_write_plan_to_state() {
  local plan_json="$1"
  [[ -n "$plan_json" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local file now updated repo_root
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --argjson plan "$plan_json" --arg now "$now" '
    .scheduler = ($plan + {updated_at: $now, active_batch_index: 0})
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
  repo_root="$(jq -r '.repo_root // ""' "$file" 2>/dev/null || true)"
  sb_scheduler_refresh_active_batch_dispatch "${repo_root:-}" 2>/dev/null || true
}

# Plan and persist batches for flow_queue tokens in orchestrator state.
sb_scheduler_plan_queue_from_state() {
  local repo_root="${1:-}"
  local catalog_file file queue_json atom_ids_json plan
  catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
  [[ -n "$catalog_file" ]] || return 1
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  queue_json="$(jq -c '.flow_queue // []' "$file" 2>/dev/null || echo '[]')"
  atom_ids_json='[]'
  local token aid atoms_tmp=()
  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    aid="$(sb_scheduler_resolve_atom_id "$catalog_file" "$token" 2>/dev/null || true)"
    [[ -n "$aid" ]] && atoms_tmp+=("$aid")
  done < <(jq -r '.[]' <<<"$queue_json" 2>/dev/null || true)
  if [[ "${#atoms_tmp[@]}" -gt 0 ]]; then
    atom_ids_json="$(printf '%s\n' "${atoms_tmp[@]}" | jq -R . | jq -s .)"
  fi
  [[ -n "$atom_ids_json" && "$atom_ids_json" != "[]" ]] || return 1
  plan="$(sb_scheduler_plan_batches_json "$catalog_file" "$atom_ids_json" 2>/dev/null || true)"
  [[ -n "$plan" ]] || return 1
  sb_scheduler_write_plan_to_state "$plan"
  printf '%s' "$plan"
}

# Append a runtime composition-log entry with scheduler decisions and dispatch records.
sb_scheduler_append_composition_log() {
  local repo_root="$1" entry_json="$2"
  [[ -n "$repo_root" && -n "$entry_json" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local logfile now
  logfile="$(sb_orchestrator_composition_log "$repo_root")"
  mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -c --arg at "$now" '. + {at: $at, mode: "runtime-scheduler"}' <<<"$entry_json" >>"$logfile" 2>/dev/null
}

# Record a dynamic composition operation with required catalog rule ref + rationale.
sb_scheduler_record_composition_operation() {
  local repo_root="$1" workflow_id="$2" op="$3" target_ref="$4" rule_ref="$5" rationale="$6"
  [[ -n "$repo_root" && -n "$op" && -n "$target_ref" && -n "$rule_ref" && -n "$rationale" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local entry
  entry="$(jq -nc \
    --arg wf "${workflow_id:-WF-SCHEDULER-FIXTURE}" \
    --arg op "$op" \
    --arg target "$target_ref" \
    --arg rule "$rule_ref" \
    --arg why "$rationale" \
    '{
      selected_workflow: $wf,
      operations: [{op: $op, target_ref: $target, catalog_rule_ref: $rule, rationale: $why}],
      scheduler_decisions: ["recorded dynamic composition operation"],
      subagent_dispatch_records: []
    }')"
  sb_scheduler_append_composition_log "$repo_root" "$entry"
}

# Map composer skill slug to catalog workflow id (WF-SILVER-*).
sb_scheduler_composer_catalog_workflow_id() {
  local composer="${1#silver:}"
  composer="${composer//:/-}"
  case "$composer" in
    silver-feature) printf 'WF-SILVER-FEATURE' ;;
    silver-fast) printf 'WF-SILVER-FAST' ;;
    silver-devops) printf 'WF-SILVER-DEVOPS' ;;
    silver-release) printf 'WF-SILVER-RELEASE' ;;
    silver-new-workflow) printf 'WF-SILVER-NEW-WORKFLOW' ;;
    silver-ui) printf 'WF-SILVER-UI' ;;
    silver-bugfix) printf 'WF-SILVER-BUGFIX' ;;
    silver-router) printf 'WF-SILVER-ROUTER' ;;
    silver-research) printf 'WF-SILVER-DEEP-RESEARCH' ;;
    silver-ship) printf 'WF-SILVER-SHIP' ;;
    silver-*)
      local slug="${composer#silver-}"
      slug="$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
      printf 'WF-SILVER-%s' "$slug"
      ;;
    *) return 1 ;;
  esac
}

# Doc-only / README-badge intents should not run the full feature pipeline.
sb_scheduler_detect_doc_only_intent() {
  local intent="${1:-}"
  [[ -n "$intent" ]] || return 1
  printf '%s' "$intent" | grep -qiE \
    'documentation-only|doc-only|README badge|shields\.io|static README badge|readme only|badge visible in rendered README' \
    && return 0
  return 1
}

# Runtime dynamic composition: substitute feature → fast for narrow doc-only work.
sb_scheduler_apply_doc_only_tailoring() {
  local repo_root="$1" composer_skill="$2" intent="${3:-}"
  [[ -n "$repo_root" && -n "$composer_skill" ]] || return 1
  sb_scheduler_detect_doc_only_intent "$intent" || return 0
  local from_wf to_wf
  from_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-feature" 2>/dev/null || printf 'WF-SILVER-FEATURE')"
  to_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-fast" 2>/dev/null || printf 'WF-SILVER-FAST')"
  if [[ "$composer_skill" == "silver-fast" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "$to_wf" "substitute" "$from_wf" \
      "DR-SUBSTITUTE-LEANER-WORKFLOW" "README badge is documentation-only; substitute leaner workflow" 2>/dev/null || true
    sb_scheduler_record_composition_operation "$repo_root" "$to_wf" "prune" "AF-PLAN" \
      "DR-PRUNE-SATISFIED-ATOM" "No planning atoms required for shields.io badge" 2>/dev/null || true
    return 0
  fi
  if [[ "$composer_skill" == "silver-feature" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "$from_wf" "substitute" "$to_wf" \
      "DR-SUBSTITUTE-LEANER-WORKFLOW" "README badge is documentation-only; substitute lean fast path" 2>/dev/null || true
  fi
}

# Observability-only intents: structured logging + runbook, explicitly zero API/UI work.
sb_scheduler_detect_observability_only_intent() {
  local intent="${1:-}"
  [[ -n "$intent" ]] || return 1
  printf '%s' "$intent" | grep -qiE 'observability|structured logging|runbook|correlation.?id|log envelope' \
    && printf '%s' "$intent" | grep -qiE 'zero API|no API|no UI|no new routes|no database|no landing|documentation-only|README runbook' \
    && return 0
  return 1
}

# Runtime tailoring for observability-only work: lean path, prune execute/UI atoms.
sb_scheduler_apply_observability_tailoring() {
  local repo_root="$1" composer_skill="$2" intent="${3:-}"
  [[ -n "$repo_root" && -n "$composer_skill" ]] || return 1
  sb_scheduler_detect_observability_only_intent "$intent" || return 0
  local from_wf to_wf
  from_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-feature" 2>/dev/null || printf 'WF-SILVER-FEATURE')"
  to_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-fast" 2>/dev/null || printf 'WF-SILVER-FAST')"
  if [[ "$composer_skill" == "silver-fast" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "$to_wf" "substitute" "$from_wf" \
      "DR-SUBSTITUTE-LEANER-WORKFLOW" "observability-only change; substitute lean fast workflow" 2>/dev/null || true
    sb_scheduler_record_composition_operation "$repo_root" "$to_wf" "prune" "AF-EXECUTE" \
      "DR-PRUNE-SATISFIED-ATOM" "structured logging middleware already present; no execute atom required" 2>/dev/null || true
    sb_scheduler_record_composition_operation "$repo_root" "$to_wf" "prune" "AF-UI" \
      "DR-PRUNE-SATISFIED-ATOM" "explicit zero-UI constraint; prune UI atoms" 2>/dev/null || true
    return 0
  fi
  if [[ "$composer_skill" == "silver-feature" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "$from_wf" "substitute" "$to_wf" \
      "DR-SUBSTITUTE-LEANER-WORKFLOW" "observability-only intent routes to fast path not full feature pipeline" 2>/dev/null || true
  fi
}

# Multi-capability greenfield intents that require feature → devops → release chaining.
sb_scheduler_detect_multi_capability_intent() {
  local intent="${1:-}"
  [[ -n "$intent" ]] || return 1
  printf '%s' "$intent" | grep -qiE 'greenfield|incident-ready|waitlist|micro-SaaS|from scratch|tenant-scoped' \
    && printf '%s' "$intent" | grep -qiE 'docker|container|compose|devops|runtime|canary' \
    && printf '%s' "$intent" | grep -qiE 'ship|release|deploy|PR|readiness' \
    && printf '%s' "$intent" | grep -qiE 'API|endpoint|persistence|landing|SQLite' \
    && return 0
  return 1
}

# Record insert ops + composer_chain for autonomous multi-workflow advance after each WF drains.
sb_scheduler_apply_multi_workflow_chain() {
  local repo_root="$1" composer_skill="$2" intent="${3:-}"
  [[ -n "$repo_root" && -n "$composer_skill" ]] || return 1
  [[ "$composer_skill" == "silver-feature" ]] || return 0
  sb_scheduler_detect_multi_capability_intent "$intent" || return 0
  local feature_wf devops_wf release_wf file updated
  feature_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-feature" 2>/dev/null || printf 'WF-SILVER-FEATURE')"
  devops_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-devops" 2>/dev/null || printf 'WF-SILVER-DEVOPS')"
  release_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-release" 2>/dev/null || printf 'WF-SILVER-RELEASE')"
  sb_scheduler_record_composition_operation "$repo_root" "$feature_wf" "insert" "$devops_wf" \
    "DR-INSERT-MISSING-EVIDENCE" "greenfield SaaS lacks runtime packaging evidence; insert devops after feature delivery" 2>/dev/null || true
  sb_scheduler_record_composition_operation "$repo_root" "$devops_wf" "insert" "$release_wf" \
    "DR-INSERT-MISSING-EVIDENCE" "containerized deliverable requires ship readiness after runtime packaging" 2>/dev/null || true
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -n "$file" && -f "$file" ]] || return 0
  updated="$(jq --argjson chain '["silver-devops","silver-release"]' '.composer_chain = $chain' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
}

# Net-new workflow intents: no catalog WF fits; route through silver-new-workflow.
sb_scheduler_detect_net_new_workflow_intent() {
  local intent="${1:-}"
  [[ -n "$intent" ]] || return 1
  printf '%s' "$intent" | grep -qiE 'posture audit|compliance snapshot|compliance-bundle|SB posture|hook manifest|net-new workflow|no existing.*workflow|new reusable workflow' \
    && return 0
  return 1
}

# Record net-new route decision when parent would otherwise force-fit an existing WF.
sb_scheduler_apply_net_new_workflow_route() {
  local repo_root="$1" composer_skill="$2" intent="${3:-}"
  [[ -n "$repo_root" ]] || return 1
  sb_scheduler_detect_net_new_workflow_intent "$intent" || return 0
  local new_wf file updated
  new_wf="$(sb_scheduler_composer_catalog_workflow_id "silver-new-workflow" 2>/dev/null || printf 'WF-SILVER-NEW-WORKFLOW')"
  if [[ "$composer_skill" == "silver-new-workflow" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "$new_wf" "insert" "AF-PLAN" \
      "DR-INSERT-MISSING-EVIDENCE" "net-new workflow requires explicit plan atom before execute" 2>/dev/null || true
    if declare -f sb_orchestrator_event_append >/dev/null 2>&1; then
      sb_orchestrator_event_append "dispatch" "$(jq -nc \
        --arg skill "silver-new-workflow" \
        '{worker_template: "NEW-WORKFLOW", skill: $skill, workflow_id: "WF-SILVER-NEW-WORKFLOW"}')" 2>/dev/null || true
    fi
    return 0
  fi
  if [[ "$composer_skill" == "silver-feature" || "$composer_skill" == "silver-router" || "$composer_skill" == "silver" ]]; then
    sb_scheduler_record_composition_operation "$repo_root" "WF-SILVER-ROUTER" "substitute" "$new_wf" \
      "DR-SUBSTITUTE-LEANER-WORKFLOW" "no catalog workflow fits posture audit bundle; substitute net-new workflow path" 2>/dev/null || true
    file="$(sb_orchestrator_state_file 2>/dev/null || true)"
    [[ -n "$file" && -f "$file" ]] || return 0
    updated="$(jq --argjson chain '["silver-new-workflow"]' '.composer_chain = $chain' "$file" 2>/dev/null || true)"
    [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
  fi
}

# Owned flow-step ids for an atomic flow from catalog.
sb_scheduler_owned_step_ids_json() {
  local catalog_file="$1" atom_id="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" && -n "$atom_id" ]] || return 1
  jq -c --arg id "$atom_id" '.atomic_flows[] | select(.id == $id) | .flow_steps // []' "$catalog_file" 2>/dev/null
}

# Update step V-loop status in orchestrator.json (.scheduler.step_v_loops).
sb_scheduler_set_step_vloop_status() {
  local atom_id="$1" step_id="$2" status="$3"
  [[ -n "$atom_id" && -n "$step_id" && -n "$status" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local file now updated
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --arg atom "$atom_id" --arg step "$step_id" --arg st "$status" --arg now "$now" '
    .scheduler = (.scheduler // {}) |
    .scheduler.step_v_loops = (.scheduler.step_v_loops // {}) |
    .scheduler.step_v_loops[$atom] = ((.scheduler.step_v_loops[$atom] // {}) + {($step): $st}) |
    .scheduler.updated_at = $now
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
}

# Evaluate join gate for atom: open only when every owned step V-loop is pass.
# Prints: open | blocked | unknown
sb_scheduler_eval_join_gate() {
  local repo_root="$1" atom_id="$2"
  local catalog_file steps_json file gate
  catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
  [[ -n "$catalog_file" ]] || { printf 'unknown'; return 1; }
  steps_json="$(sb_scheduler_owned_step_ids_json "$catalog_file" "$atom_id" 2>/dev/null || echo '[]')"
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || { printf 'unknown'; return 1; }
  gate="$(jq -r --arg atom "$atom_id" --argjson steps "$steps_json" '
    (.scheduler.step_v_loops[$atom] // {}) as $step_map
    | if ($steps | length) == 0 then "open"
      elif ([ $steps[] | $step_map[.] // "pending" ] | all(. == "pass")) then "open"
      else "blocked"
      end
  ' "$file" 2>/dev/null || echo unknown)"
  printf '%s' "$gate"
}

# Persist join gate evaluation on orchestrator state.
sb_scheduler_refresh_join_gate() {
  local repo_root="$1" atom_id="$2"
  local gate file now updated
  gate="$(sb_scheduler_eval_join_gate "$repo_root" "$atom_id")"
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --arg atom "$atom_id" --arg gate "$gate" --arg now "$now" '
    .scheduler = (.scheduler // {}) |
    .scheduler.join_gates = ((.scheduler.join_gates // {}) + {($atom): $gate}) |
    .scheduler.updated_at = $now
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
  printf '%s' "$gate"
}

# Returns 0 when atomic-flow V-gate may pass (join open and no failing steps).
sb_scheduler_atom_vgate_ready() {
  local repo_root="$1" atom_id="$2"
  local gate
  gate="$(sb_scheduler_eval_join_gate "$repo_root" "$atom_id")"
  [[ "$gate" == "open" ]]
}

# Returns 0 when workflow completion should be blocked by step V-loop rollup failure.
sb_scheduler_workflow_completion_blocked() {
  local repo_root="$1" active_atom="${2:-}"
  local catalog_file file
  catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
  file="$(sb_orchestrator_state_file)"
  [[ -n "$catalog_file" && -f "$file" ]] || return 1
  if [[ -n "$active_atom" ]]; then
    sb_scheduler_atom_vgate_ready "$repo_root" "$active_atom" && return 1
    return 0
  fi
  local blocked
  blocked="$(jq -r '
    (.scheduler.join_gates // {}) | to_entries[] | select(.value == "blocked") | .key
  ' "$file" 2>/dev/null | head -1 || true)"
  [[ -n "$blocked" ]]
}

# Seed scheduler runtime state for tests/fixtures.
sb_scheduler_seed_runtime_state() {
  local intent="${1:-scheduler fixture}" composer="${2:-silver-feature}" repo_root="${3:-}"
  sb_orchestrator_seed_intent "$intent" "$composer" "$repo_root"
}

# Returns 0 when active batch_dispatch still has handoffs awaiting join.
sb_scheduler_active_batch_has_pending_joins() {
  local file
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '
    (.scheduler.batch_dispatch.handoffs // []) | length > 0
    and any(.join_status != "joined")
  ' "$file" >/dev/null 2>&1
}

# True when host can dispatch multiple Task workers for one scheduler batch.
sb_scheduler_host_supports_parallel_dispatch() {
  case "${SB_ORCHESTRATOR_PARALLEL_DISPATCH:-}" in
    0|false|no|FALSE|NO) return 1 ;;
    1|true|yes|TRUE|YES) return 0 ;;
  esac
  local _cap_lib
  _cap_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/capability-tier.sh"
  if [[ -f "$_cap_lib" ]]; then
    # shellcheck source=lib/capability-tier.sh
    source "$_cap_lib"
    local tier
    tier="$(sb_capability_tier_number 2>/dev/null || echo 0)"
    [[ "$tier" -ge 2 ]] && return 0
  fi
  return 1
}

# Resolve worker template basename for catalog atom (FIXTURE-READ-A, PLAN, …).
sb_scheduler_worker_template_for_atom() {
  local catalog_file="$1" atom_id="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" && -n "$atom_id" ]] || return 1
  local worker slug tmpl
  worker="$(jq -r --arg id "$atom_id" '.atomic_flows[] | select(.id == $id) | .execution.worker_template // ""' "$catalog_file" 2>/dev/null || true)"
  if [[ -n "$worker" && "$worker" != "null" ]]; then
    tmpl="$(basename "$worker" .md)"
    printf '%s' "$tmpl"
    return 0
  fi
  slug="$(jq -r --arg id "$atom_id" '.atomic_flows[] | select(.id == $id) | .slug // ""' "$catalog_file" 2>/dev/null || true)"
  [[ -n "$slug" && "$slug" != "null" ]] || return 1
  printf '%s' "$slug"
}

# Best-effort skill token for a catalog atom (queue token, migration map, or slug-derived).
sb_scheduler_skill_for_atom() {
  local catalog_file="$1" atom_id="$2"
  local token skill slug
  token="$(sb_scheduler_resolve_atom_id "$catalog_file" "$atom_id" 2>/dev/null || true)"
  [[ -n "$token" ]] || token="$atom_id"
  if declare -f sb_orchestrator_flow_to_skill >/dev/null 2>&1; then
    skill="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || true)"
    [[ -n "$skill" ]] && { printf '%s' "$skill"; return 0; }
  fi
  slug="$(jq -r --arg id "$atom_id" '.atomic_flows[] | select(.id == $id) | .slug // ""' "$catalog_file" 2>/dev/null || true)"
  if [[ -n "$slug" && "$slug" != "null" ]]; then
    printf 'silver-%s' "$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
    return 0
  fi
  printf '%s' "$token"
}

# Build JSON handoff array for a batch of atom ids.
sb_scheduler_build_handoffs_json() {
  local catalog_file="$1" batch_json="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$catalog_file" "$batch_json" <<'PY'
import json
import pathlib
import re
import sys

catalog = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
atoms = json.loads(sys.argv[2])
atoms_by_id = {item["id"]: item for item in catalog.get("atomic_flows", [])}
rt = catalog.get("migration_map", {}).get("runtime_queue_tokens", {})
skill_map = catalog.get("migration_map", {}).get("skill_to_entity", {})

def flow_to_skill(token: str) -> str:
    if token.startswith("silver-"):
        return token
    if token in rt:
        token = rt[token]
    if token in skill_map:
        token = skill_map[token]
    flow = token.upper().replace("-", "-")
    if token.startswith("FLOW-"):
        slug = token[5:].lower().replace("-", "-")
        return f"silver-{slug}"
    if re.match(r"^[A-Z]+-", token):
        return f"silver-{token.split('-', 1)[1].lower()}"
    return f"silver-{token.lower()}"

handoffs = []
for atom_id in atoms:
    flow = atoms_by_id.get(atom_id, {})
    execution = flow.get("execution", {})
    worker = execution.get("worker_template", "")
    tmpl = pathlib.Path(worker).stem if worker else flow.get("slug", atom_id)
    token = atom_id
    if atom_id in rt.values():
        for k, v in rt.items():
            if v == atom_id:
                token = k
                break
    skill = flow_to_skill(token)
    handoffs.append({
        "atomic_flow_id": atom_id,
        "next_skill": skill,
        "next_worker_template": tmpl,
        "dispatch_status": "pending",
        "join_status": "pending",
    })
print(json.dumps(handoffs, separators=(",", ":")))
PY
}

# Refresh .scheduler.batch_dispatch for the active batch index.
sb_scheduler_refresh_active_batch_dispatch() {
  local repo_root="${1:-}"
  local catalog_file file batch_index batches_json batch_atoms handoffs_json mode status now updated parallel_ok
  catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
  file="$(sb_orchestrator_state_file)"
  [[ -n "$catalog_file" && -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  batch_index="$(jq -r '.scheduler.active_batch_index // 0' "$file" 2>/dev/null || echo 0)"
  batches_json="$(jq -c --argjson idx "$batch_index" '.scheduler.batches[$idx] // []' "$file" 2>/dev/null || echo '[]')"
  [[ -n "$batches_json" && "$batches_json" != "[]" && "$batches_json" != "null" ]] || return 1
  handoffs_json="$(sb_scheduler_build_handoffs_json "$catalog_file" "$batches_json" 2>/dev/null || echo '[]')"
  [[ -n "$handoffs_json" && "$handoffs_json" != "[]" ]] || return 1
  if sb_scheduler_host_supports_parallel_dispatch && [[ "$(jq 'length' <<<"$batches_json")" -gt 1 ]]; then
    mode="parallel"
  else
    mode="sequential"
  fi
  status="pending_dispatch"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  parallel_ok="$(sb_scheduler_host_supports_parallel_dispatch && echo true || echo false)"
  updated="$(jq \
    --argjson handoffs "$handoffs_json" \
    --argjson batch_index "$batch_index" \
    --arg mode "$mode" \
    --arg status "$status" \
    --argjson host_parallel "$parallel_ok" \
    --arg now "$now" \
    '
    .scheduler = (.scheduler // {}) |
    .scheduler.batch_dispatch = {
      batch_index: $batch_index,
      dispatch_mode: $mode,
      host_parallel_capable: $host_parallel,
      status: $status,
      handoffs: $handoffs,
      updated_at: $now
    } |
    .scheduler.updated_at = $now
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
  sb_scheduler_write_batch_directive "$repo_root" 2>/dev/null || true
}

# Write orchestrator-directive.json from active batch dispatch (parent Task handoff contract).
sb_scheduler_write_batch_directive() {
  local repo_root="${1:-}"
  local file batch_json first_skill first_tmpl reason args
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  batch_json="$(jq -c '.scheduler.batch_dispatch // empty' "$file" 2>/dev/null || true)"
  [[ -n "$batch_json" && "$batch_json" != "null" ]] || return 1
  first_skill="$(jq -r '[.handoffs[] | select(.dispatch_status == "pending")][0].next_skill // .handoffs[0].next_skill // ""' <<<"$batch_json")"
  first_tmpl="$(jq -r '[.handoffs[] | select(.dispatch_status == "pending")][0].next_worker_template // .handoffs[0].next_worker_template // ""' <<<"$batch_json")"
  [[ -n "$first_skill" ]] || return 1
  args="$(jq -r '.active_intent // ""' "$file" 2>/dev/null | head -c 200 || true)"
  local mode count pending batch_index
  mode="$(jq -r '.dispatch_mode // "sequential"' <<<"$batch_json")"
  count="$(jq '.handoffs | length' <<<"$batch_json")"
  pending="$(jq '[.handoffs[] | select(.dispatch_status != "joined")] | length' <<<"$batch_json")"
  batch_index="$(jq -r '.batch_index // 0' <<<"$batch_json")"
  if [[ "$mode" == "parallel" && "$count" -gt 1 ]]; then
    reason="Scheduler batch ${batch_index:-0}: spawn ${count} Task workers in parallel (${pending} pending join)"
  else
    reason="Scheduler batch: spawn Task worker for ${first_skill} (${pending} handoff(s) remaining)"
  fi
  local _od_lib
  _od_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/orchestrator-directive.sh"
  if [[ -f "$_od_lib" ]]; then
    # shellcheck source=lib/orchestrator-directive.sh
    source "$_od_lib"
    if declare -f sb_orchestrator_directive_write_batch >/dev/null 2>&1; then
      sb_orchestrator_directive_write_batch "$first_skill" "$args" "$reason" true "$first_tmpl" "$batch_json"
      return $?
    fi
    sb_orchestrator_directive_write "$first_skill" "$args" "$reason" true "$first_tmpl"
  fi
}

# Mark a handoff dispatched when host spawns a worker (subagent-start).
sb_scheduler_mark_handoff_dispatched() {
  local atom_id="${1:-}" skill="${2:-}"
  [[ -n "$atom_id" || -n "$skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local file now updated repo_root catalog_file batch_index tmpl
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  repo_root="$(jq -r '.repo_root // ""' "$file" 2>/dev/null || true)"
  catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
  if [[ -z "$atom_id" && -n "$skill" && -n "$catalog_file" ]]; then
    atom_id="$(sb_scheduler_resolve_atom_id "$catalog_file" "$skill" 2>/dev/null || true)"
  fi
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --arg atom "$atom_id" --arg skill "$skill" --arg now "$now" '
    .scheduler = (.scheduler // {}) |
    (.scheduler.batch_dispatch // empty) as $bd |
    if ($bd | type) != "object" then . else
      .scheduler.batch_dispatch.handoffs = [
        $bd.handoffs[]?
        | if (
            ($atom != "" and .atomic_flow_id == $atom)
            or ($skill != "" and .next_skill == $skill)
            or ($skill != "" and ((.next_skill // "") | gsub("^silver:"; "silver-")) == ($skill | gsub("^silver:"; "silver-")))
          )
          then . + {dispatch_status: "dispatched", dispatched_at: $now}
          else .
          end
      ] |
      .scheduler.batch_dispatch.status = "dispatched" |
      .scheduler.batch_dispatch.updated_at = $now |
      .scheduler.updated_at = $now
    end
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
  batch_index="$(jq -r '.scheduler.batch_dispatch.batch_index // 0' <<<"$updated" 2>/dev/null || echo 0)"
  tmpl="$(jq -r --arg atom "$atom_id" '
    [.scheduler.batch_dispatch.handoffs[]? | select(.atomic_flow_id == $atom)][0].next_worker_template // ""
  ' <<<"$updated" 2>/dev/null || true)"
  if declare -f sb_orchestrator_event_record_dispatch >/dev/null 2>&1; then
    sb_orchestrator_event_record_dispatch "$atom_id" "$skill" "$tmpl" "$batch_index" 2>/dev/null || true
  fi
}

# Mark handoff joined after flow atom completes; advance batch when all joined.
sb_scheduler_mark_handoff_joined() {
  local atom_id="${1:-}" skill="${2:-}"
  [[ -n "$atom_id" || -n "$skill" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local file now updated repo_root all_joined catalog_file
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  repo_root="$(jq -r '.repo_root // ""' "$file" 2>/dev/null || true)"
  if [[ -z "$atom_id" && -n "$skill" ]]; then
    catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
    if [[ -n "$catalog_file" ]]; then
      atom_id="$(sb_scheduler_resolve_atom_id "$catalog_file" "$skill" 2>/dev/null || true)"
    fi
  fi
  updated="$(jq --arg atom "$atom_id" --arg skill "$skill" --arg now "$now" '
    .scheduler = (.scheduler // {}) |
    (.scheduler.batch_dispatch // empty) as $bd |
    if ($bd | type) != "object" then . else
      .scheduler.batch_dispatch.handoffs = [
        $bd.handoffs[]?
        | if (
            ($atom != "" and .atomic_flow_id == $atom)
            or ($skill != "" and .next_skill == $skill)
            or ($skill != "" and ((.next_skill // "") | gsub("^silver:"; "silver-")) == ($skill | gsub("^silver:"; "silver-")))
          )
          then . + {dispatch_status: "joined", join_status: "joined", joined_at: $now}
          else .
          end
      ] |
      .scheduler.batch_dispatch.updated_at = $now |
      .scheduler.updated_at = $now
    end
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] || return 1
  sb_orchestrator_write_json "$updated"
  if declare -f sb_orchestrator_event_record_join >/dev/null 2>&1; then
    sb_orchestrator_event_record_join "$atom_id" "$skill" "joined" 2>/dev/null || true
  fi
  local all_joined=false
  if jq -e '
    (.scheduler.batch_dispatch.handoffs // []) | length > 0
    and all(.join_status == "joined")
  ' <<<"$updated" >/dev/null 2>&1; then
    all_joined=true
  fi
  if [[ "$all_joined" == true ]]; then
    sb_scheduler_complete_active_batch "$repo_root" 2>/dev/null || true
  else
    sb_scheduler_write_batch_directive "$repo_root" 2>/dev/null || true
  fi
}

# Active batch fully joined — advance to next batch or clear dispatch state.
sb_scheduler_complete_active_batch() {
  local repo_root="${1:-}"
  local file now updated batch_count next_idx
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  batch_count="$(jq '.scheduler.batches | length' "$file" 2>/dev/null || echo 0)"
  next_idx="$(jq -r '(.scheduler.active_batch_index // 0) + 1' "$file" 2>/dev/null || echo 1)"
  if [[ "$next_idx" -lt "$batch_count" ]]; then
    updated="$(jq --argjson idx "$next_idx" --arg now "$now" '
      .scheduler.active_batch_index = $idx |
      .scheduler.batch_dispatch.status = "joined" |
      .scheduler.updated_at = $now
    ' "$file" 2>/dev/null || true)"
    [[ -n "$updated" ]] || return 1
    sb_orchestrator_write_json "$updated"
    sb_scheduler_refresh_active_batch_dispatch "$repo_root" 2>/dev/null || true
    return 0
  fi
  updated="$(jq --arg now "$now" '
    .scheduler.batch_dispatch.status = "joined" |
    .scheduler.batch_dispatch.updated_at = $now |
    .scheduler.updated_at = $now
  ' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
}

# True when scheduler state belongs to repo_root (mirrors orchestrator state scoping).
sb_scheduler_state_applies_to_project() {
  local repo_root="$1"
  [[ -n "$repo_root" ]] || return 1
  declare -f sb_orchestrator_normalize_repo_root >/dev/null 2>&1 || return 1
  local file stored_root norm_stored norm_current
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  stored_root="$(jq -r '.repo_root // ""' "$file" 2>/dev/null || true)"
  [[ -n "$stored_root" && "$stored_root" != "null" ]] || return 1
  norm_stored="$(sb_orchestrator_normalize_repo_root "$stored_root")"
  norm_current="$(sb_orchestrator_normalize_repo_root "$repo_root")"
  [[ "$norm_stored" == "$norm_current" ]]
}

# Returns 0 when parent Stop must remain blocked due to scheduler runtime work.
sb_scheduler_parent_stop_blocked() {
  local repo_root="${1:-}"
  local file
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  if [[ -n "$repo_root" ]] && ! sb_scheduler_state_applies_to_project "$repo_root" 2>/dev/null; then
    return 1
  fi

  local blocked_gate
  blocked_gate="$(jq -r '(.scheduler.join_gates // {}) | to_entries[] | select(.value == "blocked") | .key' "$file" 2>/dev/null | head -1 || true)"
  [[ -n "$blocked_gate" ]] && return 0

  if jq -e '
    (.scheduler.step_v_loops // {}) | to_entries[] as $atom
    | $atom.value | to_entries[] | select(.value == "fail") | .key
  ' "$file" >/dev/null 2>&1; then
    return 0
  fi

  local bd_status pending_handoffs
  bd_status="$(jq -r '.scheduler.batch_dispatch.status // ""' "$file" 2>/dev/null || true)"
  case "$bd_status" in
    pending_dispatch|dispatched|joining) return 0 ;;
  esac

  pending_handoffs="$(jq -r '
    .scheduler.batch_dispatch.handoffs[]?
    | select(.join_status != "joined")
    | .atomic_flow_id
  ' "$file" 2>/dev/null | head -1 || true)"
  [[ -n "$pending_handoffs" ]] && return 0

  return 1
}

# Human-readable Stop block reason for scheduler pending work.
sb_scheduler_parent_stop_block_reason() {
  local repo_root="${1:-}"
  local file spawn_label
  file="$(sb_orchestrator_state_file 2>/dev/null || true)"
  spawn_label="Task worker"
  if declare -f sb_orchestrator_spawn_tool_label >/dev/null 2>&1; then
    spawn_label="$(sb_orchestrator_spawn_tool_label)"
  fi
  [[ -f "$file" ]] || { printf 'Orchestrator scheduler: pending batch dispatch.'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'Orchestrator scheduler: pending batch dispatch.'; return 0; }

  local blocked_gate
  blocked_gate="$(jq -r '(.scheduler.join_gates // {}) | to_entries[] | select(.value == "blocked") | .key' "$file" 2>/dev/null | head -1 || true)"
  if [[ -n "$blocked_gate" ]]; then
    printf 'Orchestrator scheduler: join gate blocked for %s (step V-loop rollup incomplete or failed).' "$blocked_gate"
    return 0
  fi

  local bd_json mode pending count
  bd_json="$(jq -c '.scheduler.batch_dispatch // empty' "$file" 2>/dev/null || true)"
  if [[ -n "$bd_json" && "$bd_json" != "null" ]]; then
    mode="$(jq -r '.dispatch_mode // "sequential"' <<<"$bd_json")"
    pending="$(jq '[.handoffs[] | select(.join_status != "joined")] | length' <<<"$bd_json")"
    count="$(jq '.handoffs | length' <<<"$bd_json")"
    if [[ "$mode" == "parallel" && "$count" -gt 1 ]]; then
      printf 'Orchestrator scheduler: parallel batch (%s/%s joined) — spawn %s for each pending handoff in orchestrator-directive.json batch_dispatch before ending session.' "$((count - pending))" "$count" "$spawn_label"
      return 0
    fi
    local next_skill tmpl
    next_skill="$(jq -r '[.handoffs[] | select(.join_status != "joined")][0].next_skill // ""' <<<"$bd_json")"
    tmpl="$(jq -r '[.handoffs[] | select(.join_status != "joined")][0].next_worker_template // ""' <<<"$bd_json")"
    printf 'Orchestrator scheduler: pending handoff for /%s — spawn %s (%s.md) before ending session.' "$next_skill" "$spawn_label" "${tmpl:-WORKER}"
    return 0
  fi

  printf 'Orchestrator scheduler: pending dispatch or join work remains.'
}
