#!/usr/bin/env bash
# scripts/audit-workflow-compliance.sh against a fabricated tree (catalog, guard, orchestrator lib, skills).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

T="$TL_TMP/tree"
mkdir -p "$T/scripts" "$T/docs" "$T/hooks/lib" "$T/.planning"
cp "$TL_REPO_ROOT/scripts/audit-workflow-compliance.sh" "$T/scripts/"
S="$T/scripts/audit-workflow-compliance.sh"

mkskill() { mkdir -p "$T/skills/$1"; cat >"$T/skills/$1/SKILL.md"; }

cat >"$T/scripts/validate-workflow-authoring.sh" <<'EOF2'
#!/usr/bin/env bash
echo "stub-validate $*"
exit "${STRUCT_RC:-0}"
EOF2

cat >"$T/docs/apo-catalog.json" <<'JSON'
{
  "workflows": [
    {"id":"WF-SILVER-ALPHA","slug":"silver-alpha","owning_skill":"silver-alpha","enforcement_queue":["a"],
     "composition_tree":[{"kind":"atomic_flow","ref":"AF-1"},{"kind":"workflow","ref":"WF-COMP"}]},
    {"id":"WF-SILVER-BAD","slug":"silver-bad","owning_skill":"silver-bad",
     "composition_tree":[]},
    {"id":"WF-SILVER-ORPHAN","slug":"silver-orphan","owning_skill":"silver-orphan","enforcement_queue":["a"],
     "composition_tree":[{"kind":"atomic_flow","ref":"AF-GONE"},{"kind":"workflow","ref":"WF-GONE"},{"kind":"other","ref":"x"}]},
    {"id":"WF-SILVER-NOOWN","slug":"silver-noown","enforcement_queue":["a"],"composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]},
    {"id":"WF-SILVER-BETA","slug":"beta","enforcement_queue":["a"],"composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]},
    {"id":"WF-COMP","slug":"comp","composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]},
    {"id":"WF-OWNED","slug":"owned","owning_skill":"custom-skill","composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]},
    {"id":"WF-GAMMA","slug":"silver-gamma","composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]},
    {"id":"WF-SILVER-NOENT","slug":"silver-noent","owning_skill":"silver-noent","enforcement_queue":["a"],"composition_tree":[{"kind":"atomic_flow","ref":"AF-1"}]}
  ],
  "atomic_flows": [
    {"id":"AF-1","v_loop":{"id":"VL-1"}},
    {"id":"AF-REF","v_loop":{"ref":"VL-REF"}},
    {"id":"AF-NOV"}
  ],
  "migration_map": {"skill_to_entity": {
    "silver-alpha":"AF-1","silver-bad":"AF-NOPE","silver-orphan":"AF-NOV","silver-noown":"WF-SILVER-X","silver-ref":"AF-REF"
  }}
}
JSON

cat >"$T/hooks/lib/orchestrator-state.sh" <<'EOF2'
# registers: silver-alpha silver-bad silver-orphan silver-noown silver-feature silver-fast silver-release
# silver-deep-research silver-new-workflow silver-devops silver-mismatch silver-noent silver-eq2
sb_orchestrator_default_queue_for_composer() {
  case "$1" in
    silver-alpha) echo "silver-quality-gates,silver-clarify,silver-spec,silver-plan,silver-execute,silver-verify" ;;
    silver-feature) echo "silver-quality-gates,silver-plan,silver-validate,silver-execute" ;;
    silver-fast) echo "silver-quality-gates,silver-plan,silver-validate,silver-execute" ;;
    silver-release) echo "silver-quality-gates,silver-ship" ;;
    silver-devops) echo "silver-devops-quality-gates,silver-validate,silver-execute" ;;
    silver-mismatch) echo "silver-plan,silver-execute" ;;
    *) echo "" ;;
  esac
}
EOF2

cat >"$T/hooks/workflow-chain-guard.sh" <<'EOF2'
case "$composer" in
  silver-alpha)
    required_markers=(silver-quality-gates silver-plan silver-spec silver-clarify)
  ;;
  silver-feature)
    required_markers=(silver-quality-gates silver-plan)
  ;;
  silver-fast)
    required_markers=(silver-quality-gates silver-plan)
  ;;
  silver-release)
    required_markers=(silver-quality-gates)
  ;;
  silver-deep-research)
    required_markers=(silver-clarify silver-deep-research)
  ;;
  silver-new-workflow)
    required_markers=(silver-clarify silver-scan silver-plan)
  ;;
  silver-devops)
    required_markers=(silver-devops-quality-gates)
  ;;
  silver-mismatch)
    required_markers=(silver-context)
  ;;
esac
EOF2

mkskill silver-alpha <<'EOF2'
# alpha
**Pre-execution:** `silver-quality-gates` then `FLOW-QUALITY-GATE`, `sb:spec`, `spec`, `sb:clarify --spec`, `silver-plan`
and more `silver-plan`.
**Post-execution:** `silver-verify`
EOF2
mkskill silver-feature <<'EOF2'
# feature
## Enforcement queue
`silver-quality-gates` `silver-plan` `conditional-thing` `silver-validate` `silver-extra`
## Next
EOF2
mkskill silver-fast <<'EOF2'
# fast
Tier 1 text.
for Tier 2 requires silver-quality-gates, silver-plan and silver-validate
EOF2
mkskill silver-release <<'EOF2'
# release
nothing parseable here
EOF2
mkskill silver-deep-research <<'EOF2'
**Pre-execution:** `silver-clarify` `silver-deep-research`
**Post-execution:** done
EOF2
mkskill silver-new-workflow <<'EOF2'
**Pre-execution:** `silver-clarify` `silver-scan` `silver-plan` `silver-validate`
**Post-execution:** done
EOF2
mkskill silver-devops <<'EOF2'
## Enforcement queue
`FLOW-DEVOPS-QUALITY-GATE-PRESHIP` `silver-validate`
EOF2
mkskill silver-mismatch <<'EOF2'
**Pre-execution:** `silver-plan`
**Post-execution:** done
EOF2
mkskill silver-bare <<'EOF2'
# bare composer without any section
EOF2
mkskill silver-eq2 <<'EOF2'
## Enforcement queue
no backticks on any line here
EOF2

run() { tl_run bash "$S" "$@"; }
out_all() { printf '%s\n%s' "$TL_OUT" "$TL_ERR"; }

# --- usage and argument errors -----------------------------------------------------------
run
assert_eq "no args -> usage 2" 2 "$TL_STATUS"; assert_contains "usage" "$TL_OUT" "Usage: audit-workflow-compliance.sh"
run -h
assert_eq "-h -> 2" 2 "$TL_STATUS"
run --target nonsense-target
assert_eq "unresolvable target -> 2" 2 "$TL_STATUS"; assert_contains "cannot resolve" "$TL_ERR" "cannot resolve target: nonsense-target"
run --target audit
assert_eq "prefix-only target -> 2" 2 "$TL_STATUS"
run --target WF-NOT-IN-CATALOG
assert_eq "unknown WF id -> 2" 2 "$TL_STATUS"

# --- target resolution forms ------------------------------------------------------------------
run --target WF-SILVER-ALPHA
assert_contains "WF + owning skill" "$TL_OUT" "target: skill=silver-alpha slug=alpha wf_id=WF-SILVER-ALPHA composer=1"
run --target "--audit WF-SILVER-ALPHA"
assert_contains "--audit prefix stripped" "$TL_OUT" "wf_id=WF-SILVER-ALPHA composer=1"
run --target "validate silver-alpha"
assert_contains "validate prefix + silver- name" "$TL_OUT" "skill=silver-alpha slug=alpha wf_id=WF-SILVER-ALPHA"
run --target WF-SILVER-NOOWN
assert_contains "WF-SILVER, no owner, silver- slug" "$TL_OUT" "skill=silver-noown slug=noown wf_id=WF-SILVER-NOOWN composer=1"
run --target WF-SILVER-BETA
assert_contains "WF-SILVER, no owner, bare slug" "$TL_OUT" "skill=silver-beta slug=beta wf_id=WF-SILVER-BETA composer=1"
run --target WF-OWNED
assert_contains "owner without silver- prefix" "$TL_OUT" "skill=custom-skill slug=custom-skill wf_id=WF-OWNED composer=0"
run --target WF-COMP
assert_contains "component workflow, no owner" "$TL_OUT" "skill=N/A slug=comp wf_id=WF-COMP composer=0"
run --target "$T/skills/silver-alpha/SKILL.md"
assert_contains "SKILL.md path" "$TL_OUT" "skill=silver-alpha slug=alpha wf_id=WF-SILVER-ALPHA"
run --target alpha
assert_contains "bare slug with local skill" "$TL_OUT" "skill=silver-alpha slug=alpha"
run --target gamma
assert_contains "bare slug via catalog slug" "$TL_OUT" "skill=silver-gamma slug=gamma wf_id=WF-GAMMA"
run --slug alpha
assert_contains "--slug option" "$TL_OUT" "skill=silver-alpha slug=alpha wf_id=WF-SILVER-ALPHA composer=1"
run silver-alpha
assert_contains "positional target" "$TL_OUT" "skill=silver-alpha"

# --- full pass for a consistent composer ----------------------------------------------------------------
run --target silver-alpha
assert_eq "alpha passes" 0 "$TL_STATUS"
assert_contains "structural ran validator" "$TL_OUT" "stub-validate --slug alpha"
assert_contains "structural pass" "$TL_OUT" "PASS [structural]: validate-workflow-authoring.sh"
assert_contains "migration entity" "$TL_OUT" "PASS [migration_map]: skill_to_entity silver-alpha → AF-1"
assert_contains "catalog present" "$TL_OUT" "PASS [catalog]: workflow WF-SILVER-ALPHA present"
assert_contains "tree nodes" "$TL_OUT" "composition_tree has 2 node(s)"
assert_contains "queue declared" "$TL_OUT" "enforcement_queue declared"
assert_contains "refs resolve" "$TL_OUT" "composition_tree refs resolve"
assert_contains "skill == guard" "$TL_OUT" "SKILL pre-exec == guard markers"
assert_contains "guard == orchestrator" "$TL_OUT" "guard markers == orchestrator pre-execute"
assert_contains "orchestrator registered" "$TL_OUT" "composer registered in orchestrator-state.sh"
assert_contains "flow step v_loop id" "$TL_OUT" "atomic flow AF-1 has v_loop VL-1"
assert_contains "verdict" "$TL_OUT" "VERDICT: PASS"

# SPEC.md present: clarify/spec tokens are not required by the SKILL, so the sets diverge
echo spec >"$T/.planning/SPEC.md"
run --target silver-alpha
assert_eq "SPEC present -> mismatch" 1 "$TL_STATUS"
assert_contains "mismatch reported" "$TL_ERR" "SKILL pre-exec [plan,quality-gates] != guard [clarify,plan,quality-gates,spec]"
assert_contains "mismatch remediation" "$TL_OUT" "hooks/workflow-chain-guard.sh — required_markers for silver-alpha"
rm "$T/.planning/SPEC.md"

# structural failure
STRUCT_RC=1 tl_run bash "$S" --target silver-alpha
assert_eq "structural failure -> 1" 1 "$TL_STATUS"
assert_contains "structural failure msg" "$TL_ERR" "FAIL [structural]: validate-workflow-authoring.sh"
assert_contains "structural remediation" "$TL_OUT" "docs/NEW-WORKFLOW.md"

# --- other composers' triple alignment ----------------------------------------------------------------------
tri() { run --target "$1"; out_all; }
t="$(tri silver-feature)"
assert_contains "feature: enforcement-queue parse + validate marker" "$t" "PASS [triple_alignment]: SKILL pre-exec == guard markers"
assert_contains "feature: orchestrator stops before execute" "$t" "PASS [triple_alignment]: guard markers == orchestrator pre-execute"
t="$(tri silver-fast)"
assert_contains "fast: tier-2 line parse" "$t" "PASS [triple_alignment]: SKILL pre-exec == guard markers"
t="$(tri silver-release)"
assert_contains "release: skill side" "$t" "PASS [triple_alignment]: SKILL pre-exec == guard markers"
assert_contains "release: orchestrator first queue entry" "$t" "PASS [triple_alignment]: guard markers == orchestrator pre-execute"
t="$(tri silver-deep-research)"
assert_contains "deep-research: fixed orchestrator set" "$t" "PASS [triple_alignment]: guard markers == orchestrator pre-execute"
t="$(tri silver-new-workflow)"
assert_contains "new-workflow: fixed orchestrator set" "$t" "PASS [triple_alignment]: guard markers == orchestrator pre-execute"
t="$(tri silver-devops)"
assert_contains "devops: FLOW-DEVOPS token normalised" "$t" "PASS [triple_alignment]: SKILL pre-exec == guard markers"
assert_contains "devops: orchestrator matches" "$t" "PASS [triple_alignment]: guard markers == orchestrator pre-execute"
t="$(tri silver-mismatch)"
assert_contains "mismatch: skill vs guard" "$t" "FAIL [triple_alignment]: SKILL pre-exec [plan] != guard [context]"
assert_contains "mismatch: guard vs orchestrator" "$t" "FAIL [triple_alignment]: guard [context] != orchestrator [plan]"
assert_contains "orchestrator remediation" "$t" "sb_orchestrator_default_queue_for_composer silver-mismatch"
t="$(tri silver-bare)"
assert_contains "bare: SKILL not parseable" "$t" "SKILL pre-exec markers not parseable"
assert_contains "bare: remediation" "$t" "skills/silver-bare/SKILL.md — Enforcement queue / Pre-execution section"
assert_contains "bare: orchestrator not registered" "$t" "composer missing from orchestrator-state.sh"
assert_contains "bare: remediation 2" "$t" "hooks/lib/orchestrator-state.sh"
t="$(tri silver-eq2)"
assert_contains "empty enforcement queue not parseable" "$t" "SKILL pre-exec markers not parseable"
t="$(tri silver-nofile)"
assert_contains "missing SKILL.md" "$t" "FAIL [triple_alignment]: missing skills/silver-nofile/SKILL.md"

# --- catalog category -------------------------------------------------------------------------------------------------
t="$(tri silver-bad)"
assert_contains "empty tree" "$t" "composition_tree empty for WF-SILVER-BAD"
assert_contains "empty tree remediation" "$t" "docs/composable-flows-contracts.md — composition_tree"
assert_contains "enforcement_queue missing" "$t" "enforcement_queue missing for WF-SILVER-BAD"
assert_contains "queue remediation" "$t" "docs/APO-AUTHORING-COMPLIANCE.md — enforcement_queue"
assert_contains "skill_to_entity AF not in catalog" "$t" "atomic flow AF-NOPE not in catalog"
t="$(tri silver-orphan)"
assert_contains "orphan refs" "$t" "orphan composition refs: AF:AF-GONE,WF:WF-GONE"
assert_contains "orphan remediation" "$t" "composer purity"
assert_contains "AF without v_loop" "$t" "atomic flow AF-NOV missing v_loop"
assert_contains "v_loop remediation" "$t" "V-loop per AF"
t="$(tri silver-noent)"
assert_contains "no entity for composer" "$t" "skill_to_entity empty for composer silver-noent"
assert_contains "migration_map missing" "$t" "skill_to_entity missing for silver-noent"
assert_contains "migration remediation" "$t" "migration_map.skill_to_entity"
t="$(tri silver-noown)"
assert_contains "workflow-level entity" "$t" "skill maps to workflow-level entity WF-SILVER-X"
t="$(tri silver-ref)"
assert_contains "workflow absent from catalog" "$t" "FAIL [catalog]: workflow WF-SILVER-REF missing"
assert_contains "absent catalog remediation" "$t" "regenerate via scripts/generate-apo-catalog.py"
assert_contains "v_loop ref accepted" "$t" "atomic flow AF-REF has v_loop VL-REF"

# component workflows skip composer-only checks
run --target WF-COMP
assert_eq "component workflow passes" 0 "$TL_STATUS"
assert_contains "component structural N/A" "$TL_OUT" "component workflow — composer structural checks N/A"
assert_contains "component migration N/A" "$TL_OUT" "component workflow — skill_to_entity N/A"
assert_contains "component queue N/A" "$TL_OUT" "component workflow — enforcement_queue N/A"
assert_contains "component triple N/A" "$TL_OUT" "component workflow — triple alignment N/A"
assert_contains "component orchestrator N/A" "$TL_OUT" "component workflow — orchestrator registration N/A"
assert_contains "component entity N/A" "$TL_OUT" "component workflow — entity mapping N/A"

tl_results
