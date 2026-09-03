#!/usr/bin/env bash
# Validates every skill-backed flow step has a complete local V-loop.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
SKILLS_DIR="$REPO_ROOT/skills"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for flow-step V-loop tests"
  exit 0
fi

results="$(python3 - "$CATALOG" "$SKILLS_DIR" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
skills_dir = Path(sys.argv[2])
repo_skills = sorted(path.parent.name for path in skills_dir.glob("*/SKILL.md"))
steps = catalog.get("flow_steps", [])
step_skills = sorted(step.get("skill") for step in steps)
flow_ids = {flow.get("id") for flow in catalog.get("atomic_flows", [])}
evidence_ids = {record.get("id") for record in catalog.get("evidence_records", [])}

def full_v_loop(step):
    v_loop = step.get("v_loop", {})
    return all([
        step.get("hierarchy_level") == "flow_step",
        v_loop.get("input_contract"),
        v_loop.get("work_product"),
        v_loop.get("verification", {}).get("methods"),
        v_loop.get("validation", {}).get("target"),
        v_loop.get("validation", {}).get("methods"),
        v_loop.get("repair", {}).get("behavior"),
        v_loop.get("escalation", {}).get("condition"),
        v_loop.get("evidence_refs"),
    ])

missing_skills = sorted(set(repo_skills) - set(step_skills))
pseudo_skills = {"distribution-only"}
extra_skills = sorted(
    skill for skill in set(step_skills) - set(repo_skills)
    if skill not in pseudo_skills and "|" not in (skill or "")
)
bad_vloops = [step.get("id") for step in steps if not full_v_loop(step)]
bad_reuse = [
    step.get("id")
    for step in steps
    if not step.get("reusable_by_flows") or not set(step.get("reusable_by_flows", [])) <= flow_ids
]
bad_evidence = [
    step.get("id")
    for step in steps
    if not set(step.get("v_loop", {}).get("evidence_refs", [])) <= evidence_ids
]

checks = (
    ("catalog flow_steps cover every skill", not missing_skills, ", ".join(missing_skills)),
    ("catalog has no flow_step for missing skills", not extra_skills, ", ".join(extra_skills)),
    ("every flow_step has complete local V-loop", not bad_vloops, ", ".join(bad_vloops)),
    ("every flow_step rolls up to canonical atomic flows", not bad_reuse, ", ".join(bad_reuse)),
    ("every flow_step references registered evidence", not bad_evidence, ", ".join(bad_evidence)),
)
for label, ok, detail in checks:
    print(("PASS" if ok else "FAIL") + "\t" + label + ("\t" + detail if detail else ""))
PY
)"

while IFS=$'\t' read -r status label detail; do
  if [[ "$status" == "PASS" ]]; then
    pass "$label"
  else
    fail "$label${detail:+: $detail}"
  fi
done <<<"$results"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
