#!/usr/bin/env bash
# Read-only compliance audit for catalog atomic flows (AF-*) and flow steps (FS-*).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CATALOG="${REPO_ROOT}/docs/apo-catalog.json"

target=""
entity_id=""
entity_type="" # atomic_flow | flow_step
fail=0

pass_cat() { echo "PASS [$1]: $2"; }
fail_cat() { echo "FAIL [$1]: $2" >&2; fail=1; }
remediation() { echo "  → $1"; }

usage() {
  cat <<'EOF'
Usage: audit-atomic-flow-compliance.sh --target <AF-*|FS-*>
  Audits a single atomic flow or flow step catalog entry.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) target="$1"; shift ;;
  esac
done

[[ -n "$target" ]] || usage

if [[ "$target" =~ ^AF- ]]; then
  entity_id="$target"
  entity_type="atomic_flow"
elif [[ "$target" =~ ^FS- ]]; then
  entity_id="$target"
  entity_type="flow_step"
else
  echo "FAIL: target must be AF-* or FS-* (got: $target)" >&2
  exit 2
fi

echo "=== atomic-flow compliance audit ==="
echo "target: type=${entity_type} id=${entity_id}"
echo

# --- Category: catalog ---
echo "--- catalog ---"
if [[ "$entity_type" == "atomic_flow" ]]; then
  if jq -e --arg id "$entity_id" '.atomic_flows[] | select(.id == $id)' "$CATALOG" >/dev/null 2>&1; then
    pass_cat catalog "atomic flow ${entity_id} present"
  else
    fail_cat catalog "atomic flow ${entity_id} missing"
    remediation "docs/apo-catalog.json — regenerate via scripts/generate-apo-catalog.py"
    echo "VERDICT: FAIL"
    exit 1
  fi
else
  if jq -e --arg id "$entity_id" '.flow_steps[] | select(.id == $id)' "$CATALOG" >/dev/null 2>&1; then
    pass_cat catalog "flow step ${entity_id} present"
  else
    fail_cat catalog "flow step ${entity_id} missing"
    remediation "docs/apo-catalog.json — regenerate via scripts/generate-apo-catalog.py"
    echo "VERDICT: FAIL"
    exit 1
  fi
fi

# --- Category: v_loop ---
echo "--- v_loop ---"
vloop_id="$(jq -r --arg id "$entity_id" --arg t "$entity_type" \
  'if $t == "atomic_flow" then (.atomic_flows[] | select(.id == $id) | .v_loop.id // empty)
   else (.flow_steps[] | select(.id == $id) | .v_loop.id // empty) end' "$CATALOG")"
if [[ -n "$vloop_id" && "$vloop_id" != "null" ]]; then
  pass_cat v_loop "v_loop.id=${vloop_id}"
else
  fail_cat v_loop "v_loop.id missing for ${entity_id}"
  remediation "docs/composable-flows-contracts.md — V-loop per entity"
fi

for field in input_contract work_product; do
  val="$(jq -r --arg id "$entity_id" --arg t "$entity_type" --arg f "$field" \
    'if $t == "atomic_flow" then (.atomic_flows[] | select(.id == $id) | .v_loop[$f] // empty)
     else (.flow_steps[] | select(.id == $id) | .v_loop[$f] // empty) end' "$CATALOG")"
  if [[ -n "$val" && "$val" != "null" ]]; then
    pass_cat v_loop "${field} declared"
  else
    fail_cat v_loop "${field} missing"
    remediation "docs/APO-AUTHORING-COMPLIANCE.md — V-loop fields"
  fi
done

ev_refs="$(jq -r --arg id "$entity_id" --arg t "$entity_type" \
  'if $t == "atomic_flow" then (.atomic_flows[] | select(.id == $id) | .v_loop.evidence_refs // [] | length)
   else (.flow_steps[] | select(.id == $id) | .v_loop.evidence_refs // [] | length) end' "$CATALOG")"
if [[ "$ev_refs" -gt 0 ]]; then
  pass_cat v_loop "evidence_refs count=${ev_refs}"
else
  fail_cat v_loop "evidence_refs empty"
  remediation "docs/apo-catalog.json — evidence_records linkage"
fi

# --- Category: ownership / classification ---
echo "--- ownership ---"
if [[ "$entity_type" == "atomic_flow" ]]; then
  owners="$(jq -r --arg id "$entity_id" '.atomic_flows[] | select(.id == $id) | .owning_skills // [] | length' "$CATALOG")"
  if [[ "$owners" -gt 0 ]]; then
    pass_cat ownership "owning_skills count=${owners}"
  else
    fail_cat ownership "owning_skills empty"
    remediation "docs/apo-catalog.json — owning_skills per AF"
  fi

  steps="$(jq -r --arg id "$entity_id" '.atomic_flows[] | select(.id == $id) | .flow_steps // [] | length' "$CATALOG")"
  if [[ "$steps" -gt 0 ]]; then
    pass_cat ownership "flow_steps count=${steps}"
  else
    fail_cat ownership "flow_steps empty"
    remediation "docs/composable-flows-contracts.md — step ownership"
  fi

  bad_steps="$(jq -r --arg id "$entity_id" '
    (.flow_steps | map(.id)) as $all |
    .atomic_flows[] | select(.id == $id) | .flow_steps[] |
    select(. as $s | $all | index($s) | not)
  ' "$CATALOG" | paste -sd, - || true)"
  if [[ -z "$bad_steps" ]]; then
    pass_cat ownership "all flow_steps resolve in catalog"
  else
    fail_cat ownership "orphan flow_steps: ${bad_steps}"
    remediation "docs/apo-catalog.json — flow_steps refs"
  fi
else
  level="$(jq -r --arg id "$entity_id" '.flow_steps[] | select(.id == $id) | .hierarchy_level // empty' "$CATALOG")"
  class="$(jq -r --arg id "$entity_id" '.flow_steps[] | select(.id == $id) | .classification // empty' "$CATALOG")"
  if [[ "$level" == "flow_step" ]]; then
    pass_cat ownership "hierarchy_level=flow_step"
  else
    fail_cat ownership "hierarchy_level invalid: ${level:-MISSING}"
    remediation "scripts/check-apo-invariants.py skill-hierarchy-classification"
  fi
  allowed="flow-step-skill atomic-flow-implementation precomposed-workflow process-router reviewer-pack quality-dimension-step deprecated distribution-only"
  if [[ " $allowed " == *" $class "* ]]; then
    pass_cat ownership "classification=${class}"
  else
    fail_cat ownership "classification invalid: ${class:-MISSING}"
    remediation "docs/APO-AUTHORING-COMPLIANCE.md — flow step classification"
  fi

  canon="$(jq -r --arg id "$entity_id" '.flow_steps[] | select(.id == $id) | .canonical_catalog_entity // empty' "$CATALOG")"
  if [[ -n "$canon" ]]; then
    if jq -e --arg c "$canon" '.atomic_flows[] | select(.id == $c)' "$CATALOG" >/dev/null 2>&1; then
      pass_cat ownership "canonical_catalog_entity=${canon}"
    else
      fail_cat ownership "canonical_catalog_entity ${canon} not in catalog"
    fi
  else
    fail_cat ownership "canonical_catalog_entity missing"
  fi
fi

# --- Category: enforcement / execution ---
echo "--- enforcement ---"
if [[ "$entity_type" == "atomic_flow" ]]; then
  dispatch="$(jq -r --arg id "$entity_id" '.atomic_flows[] | select(.id == $id) | .execution.dispatch_mode // empty' "$CATALOG")"
  template="$(jq -r --arg id "$entity_id" '.atomic_flows[] | select(.id == $id) | .execution.worker_template // empty' "$CATALOG")"
  if [[ "$dispatch" == "subagent" ]]; then
    pass_cat enforcement "dispatch_mode=subagent"
  else
    fail_cat enforcement "dispatch_mode invalid: ${dispatch:-MISSING}"
    remediation "tests/scripts/test-atomic-flow-vloop.sh"
  fi
  if [[ -n "$template" && -f "${REPO_ROOT}/${template}" ]]; then
    pass_cat enforcement "worker_template exists: ${template}"
  elif [[ -n "$template" ]]; then
    fail_cat enforcement "worker_template missing file: ${template}"
    remediation "templates/orchestrator-workers/"
  else
    fail_cat enforcement "worker_template not declared"
  fi

  dedup="$(jq -r --arg id "$entity_id" '.atomic_flows[] | select(.id == $id) | .dedup_gate_status // empty' "$CATALOG")"
  if [[ "$dedup" == "passed" ]]; then
    pass_cat enforcement "dedup_gate_status=passed"
  else
    fail_cat enforcement "dedup_gate_status: ${dedup:-MISSING}"
    remediation "tests/scripts/test-atomic-flow-dedup.sh"
  fi
else
  skill="$(jq -r --arg id "$entity_id" '.flow_steps[] | select(.id == $id) | .skill // empty' "$CATALOG")"
  if [[ -n "$skill" ]]; then
    if [[ -f "${REPO_ROOT}/skills/${skill}/SKILL.md" || -f "${REPO_ROOT}/skills/silver-${skill}/SKILL.md" ]]; then
      pass_cat enforcement "skill surface exists for ${skill}"
    elif [[ "$skill" == distribution-only || "$skill" == *"|"* ]]; then
      pass_cat enforcement "distribution-only / multi-host step ${skill} (no single skill dir)"
    elif [[ "$skill" == ai-llm-safety || "$skill" == extensibility || "$skill" == modularity || "$skill" == reliability || "$skill" == reusability || "$skill" == scalability || "$skill" == security || "$skill" == testability || "$skill" == usability || "$skill" == tdd ]]; then
      pass_cat enforcement "quality-dimension step ${skill} (no local skill dir expected)"
    else
      fail_cat enforcement "skill ${skill} has no SKILL.md"
      remediation "skills/${skill}/SKILL.md or skills/silver-${skill}/SKILL.md"
    fi
  else
    fail_cat enforcement "skill field missing"
  fi

  reused="$(jq -r --arg id "$entity_id" '.flow_steps[] | select(.id == $id) | .reusable_by_flows // [] | length' "$CATALOG")"
  if [[ "$reused" -gt 0 ]]; then
    pass_cat enforcement "reusable_by_flows count=${reused}"
    bad_af="$(jq -r --arg id "$entity_id" '
      (.atomic_flows | map(.id)) as $all |
      .flow_steps[] | select(.id == $id) | .reusable_by_flows[] |
      select(. as $a | $all | index($a) | not)
    ' "$CATALOG" | paste -sd, - || true)"
    if [[ -z "$bad_af" ]]; then
      pass_cat enforcement "all reusable_by_flows resolve"
    else
      fail_cat enforcement "orphan reusable_by_flows: ${bad_af}"
    fi
  else
    fail_cat enforcement "reusable_by_flows empty"
  fi
fi

# --- Category: composition (AF referenced by workflows) ---
echo "--- composition ---"
if [[ "$entity_type" == "atomic_flow" ]]; then
  refs="$(jq -r --arg id "$entity_id" '
    [.workflows[] | .composition_tree[]? | select(.ref == $id) | .ref] | length
  ' "$CATALOG")"
  if [[ "$refs" -gt 0 ]]; then
    pass_cat composition "referenced in ${refs} workflow composition node(s)"
  else
    # AF may still be valid as reusable component only
    fail_cat composition "not referenced in any workflow composition_tree"
    remediation "docs/composable-flows-contracts.md — usage_review"
  fi
else
  owner_refs="$(jq -r --arg id "$entity_id" '
    [.atomic_flows[] | select(.flow_steps[]? == $id) | .id] | length
  ' "$CATALOG")"
  if [[ "$owner_refs" -gt 0 ]]; then
    pass_cat composition "owned by ${owner_refs} atomic flow(s)"
  else
    fail_cat composition "not owned by any atomic flow flow_steps[]"
    remediation "docs/apo-catalog.json — AF flow_steps ownership"
  fi
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "VERDICT: PASS"
  exit 0
fi
echo "VERDICT: FAIL"
exit 1
