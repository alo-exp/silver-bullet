#!/usr/bin/env bash
# scripts/audit-atomic-flow-compliance.sh against a fabricated catalog in a temp tree.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

T="$TL_TMP/tree"
mkdir -p "$T/scripts" "$T/docs" "$T/templates" "$T/skills/alpha" "$T/skills/silver-beta"
cp "$TL_REPO_ROOT/scripts/audit-atomic-flow-compliance.sh" "$T/scripts/"
echo w >"$T/templates/w.md"
touch "$T/skills/alpha/SKILL.md" "$T/skills/silver-beta/SKILL.md"
cat >"$T/docs/apo-catalog.json" <<'JSON'
{
  "atomic_flows": [
    {"id":"AF-good","v_loop":{"id":"VL-1","input_contract":"in","work_product":"wp","evidence_refs":["e1","e2"]},
     "owning_skills":["a"],"flow_steps":["FS-good"],
     "execution":{"dispatch_mode":"subagent","worker_template":"templates/w.md"},"dedup_gate_status":"passed"},
    {"id":"AF-bad","v_loop":{"evidence_refs":[]},"owning_skills":[],"flow_steps":["FS-missing"],
     "execution":{"dispatch_mode":"inline","worker_template":"templates/nofile.md"},"dedup_gate_status":"failed"},
    {"id":"AF-empty"},
    {"id":"AF-notpl","execution":{"dispatch_mode":"subagent"}}
  ],
  "flow_steps": [
    {"id":"FS-good","v_loop":{"id":"VL-2","input_contract":"in","work_product":"wp","evidence_refs":["e"]},
     "hierarchy_level":"flow_step","classification":"flow-step-skill","canonical_catalog_entity":"AF-good",
     "skill":"alpha","reusable_by_flows":["AF-good"]},
    {"id":"FS-bad","hierarchy_level":"x","classification":"zzz","canonical_catalog_entity":"AF-nope",
     "skill":"ghost","reusable_by_flows":["AF-orphan"]},
    {"id":"FS-silver","hierarchy_level":"flow_step","classification":"deprecated","skill":"beta","reusable_by_flows":[]},
    {"id":"FS-dist","hierarchy_level":"flow_step","classification":"distribution-only","skill":"distribution-only"},
    {"id":"FS-multi","skill":"a|b"},
    {"id":"FS-qd","skill":"security"},
    {"id":"FS-noskill"}
  ],
  "workflows": [ {"id":"WF","composition_tree":[{"ref":"AF-good"},{"ref":"other"}]} ]
}
JSON
S="$T/scripts/audit-atomic-flow-compliance.sh"

run() { tl_run bash "$S" "$@"; }

# usage / argument errors
run
assert_eq "no args -> usage exit 2" 2 "$TL_STATUS"
assert_contains "usage text" "$TL_OUT" "Usage: audit-atomic-flow-compliance.sh --target"
run -h
assert_eq "-h -> exit 2" 2 "$TL_STATUS"
run --target
assert_eq "--target without value -> exit 1 (shift 2 fails under errexit)" 1 "$TL_STATUS"
run XX-1
assert_eq "bad prefix exit 2" 2 "$TL_STATUS"
assert_contains "bad prefix message" "$TL_ERR" "target must be AF-* or FS-* (got: XX-1)"

# fully valid atomic flow (positional and --target forms)
run --target AF-good
assert_eq "AF-good passes" 0 "$TL_STATUS"
assert_contains "AF header" "$TL_OUT" "target: type=atomic_flow id=AF-good"
assert_contains "AF present" "$TL_OUT" "PASS [catalog]: atomic flow AF-good present"
assert_contains "AF vloop id" "$TL_OUT" "PASS [v_loop]: v_loop.id=VL-1"
assert_contains "AF evidence count" "$TL_OUT" "evidence_refs count=2"
assert_contains "AF owners" "$TL_OUT" "owning_skills count=1"
assert_contains "AF steps resolve" "$TL_OUT" "all flow_steps resolve in catalog"
assert_contains "AF dispatch" "$TL_OUT" "dispatch_mode=subagent"
assert_contains "AF template" "$TL_OUT" "worker_template exists: templates/w.md"
assert_contains "AF dedup" "$TL_OUT" "dedup_gate_status=passed"
assert_contains "AF composition" "$TL_OUT" "referenced in 1 workflow composition node(s)"
assert_contains "AF verdict" "$TL_OUT" "VERDICT: PASS"
run AF-good
assert_eq "positional target works" 0 "$TL_STATUS"

# failing atomic flow
run --target AF-bad
assert_eq "AF-bad fails" 1 "$TL_STATUS"
assert_contains "vloop id missing" "$TL_ERR" "FAIL [v_loop]: v_loop.id missing for AF-bad"
assert_contains "input_contract missing" "$TL_ERR" "input_contract missing"
assert_contains "work_product missing" "$TL_ERR" "work_product missing"
assert_contains "evidence empty" "$TL_ERR" "evidence_refs empty"
assert_contains "owners empty" "$TL_ERR" "owning_skills empty"
assert_contains "orphan steps" "$TL_ERR" "orphan flow_steps: FS-missing"
assert_contains "dispatch invalid" "$TL_ERR" "dispatch_mode invalid: inline"
assert_contains "template file missing" "$TL_ERR" "worker_template missing file: templates/nofile.md"
assert_contains "dedup failed" "$TL_ERR" "dedup_gate_status: failed"
assert_contains "not referenced" "$TL_ERR" "not referenced in any workflow composition_tree"
assert_contains "remediation printed" "$TL_OUT" "  → docs/apo-catalog.json — owning_skills per AF"
assert_contains "AF-bad verdict" "$TL_OUT" "VERDICT: FAIL"

run --target AF-empty
assert_eq "AF-empty fails" 1 "$TL_STATUS"
assert_contains "flow_steps empty" "$TL_ERR" "flow_steps empty"
assert_contains "dispatch MISSING" "$TL_ERR" "dispatch_mode invalid: MISSING"
assert_contains "dedup MISSING" "$TL_ERR" "dedup_gate_status: MISSING"
run --target AF-notpl
assert_contains "template undeclared" "$TL_ERR" "worker_template not declared"

# missing entries stop early
run --target AF-nope
assert_eq "missing AF exit 1" 1 "$TL_STATUS"
assert_contains "missing AF message" "$TL_ERR" "atomic flow AF-nope missing"
assert_contains "missing AF verdict" "$TL_OUT" "VERDICT: FAIL"
run --target FS-nope
assert_eq "missing FS exit 1" 1 "$TL_STATUS"
assert_contains "missing FS message" "$TL_ERR" "flow step FS-nope missing"

# flow steps
run --target FS-good
assert_eq "FS-good passes" 0 "$TL_STATUS"
assert_contains "FS header" "$TL_OUT" "type=flow_step id=FS-good"
assert_contains "FS level" "$TL_OUT" "hierarchy_level=flow_step"
assert_contains "FS class" "$TL_OUT" "classification=flow-step-skill"
assert_contains "FS canonical" "$TL_OUT" "canonical_catalog_entity=AF-good"
assert_contains "FS skill dir" "$TL_OUT" "skill surface exists for alpha"
assert_contains "FS reusable" "$TL_OUT" "reusable_by_flows count=1"
assert_contains "FS reusable resolve" "$TL_OUT" "all reusable_by_flows resolve"
assert_contains "FS owned" "$TL_OUT" "owned by 1 atomic flow(s)"

run --target FS-bad
assert_eq "FS-bad fails" 1 "$TL_STATUS"
assert_contains "level invalid" "$TL_ERR" "hierarchy_level invalid: x"
assert_contains "class invalid" "$TL_ERR" "classification invalid: zzz"
assert_contains "canonical not in catalog" "$TL_ERR" "canonical_catalog_entity AF-nope not in catalog"
assert_contains "ghost skill" "$TL_ERR" "skill ghost has no SKILL.md"
assert_contains "orphan reusable" "$TL_ERR" "orphan reusable_by_flows: AF-orphan"
assert_contains "not owned" "$TL_ERR" "not owned by any atomic flow flow_steps[]"

run --target FS-silver
assert_contains "silver- prefixed skill" "$TL_OUT" "skill surface exists for beta"
assert_contains "canonical missing" "$TL_ERR" "canonical_catalog_entity missing"
assert_contains "reusable empty" "$TL_ERR" "reusable_by_flows empty"
run --target FS-dist
assert_contains "distribution-only skill" "$TL_OUT" "distribution-only / multi-host step distribution-only"
assert_contains "dist classification" "$TL_OUT" "classification=distribution-only"
run --target FS-multi
assert_contains "multi-host skill" "$TL_OUT" "multi-host step a|b"
assert_contains "MISSING level" "$TL_ERR" "hierarchy_level invalid: MISSING"
assert_contains "MISSING class" "$TL_ERR" "classification invalid: MISSING"
run --target FS-qd
assert_contains "quality dimension skill" "$TL_OUT" "quality-dimension step security"
run --target FS-noskill
assert_contains "skill field missing" "$TL_ERR" "skill field missing"

# catalog file absent -> entity reported missing
rm "$T/docs/apo-catalog.json"
run --target AF-good
assert_eq "no catalog -> exit 1" 1 "$TL_STATUS"
assert_contains "no catalog message" "$TL_ERR" "atomic flow AF-good missing"

# jq failing while listing orphan reusable_by_flows (a malformed atomic_flows entry) is tolerated
# by the `|| true` guard; the later composition query then aborts the script under errexit.
jq -n '{atomic_flows:[5],flow_steps:[{id:"FS-w",skill:"alpha",reusable_by_flows:["AF-x"]}],workflows:[]}' >"$T/docs/apo-catalog.json"
run --target FS-w
assert_contains "malformed AF list: resolve line still printed" "$TL_OUT" "PASS [enforcement]: all reusable_by_flows resolve"
assert_eq "malformed AF list aborts at composition query" 5 "$TL_STATUS"

tl_results
