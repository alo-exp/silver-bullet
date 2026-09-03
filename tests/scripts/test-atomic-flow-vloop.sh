#!/usr/bin/env bash
# Validates every atomic flow has a concrete V-model contract.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for atomic-flow V-loop tests"
  exit 0
fi

results="$(python3 - "$CATALOG" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
flows = catalog.get("atomic_flows", [])
evidence_ids = {record.get("id") for record in catalog.get("evidence_records", [])}

required_vloop_paths = (
    ("input_contract",),
    ("work_product",),
    ("verification", "methods"),
    ("validation", "target"),
    ("validation", "methods"),
    ("repair", "behavior"),
    ("escalation", "condition"),
    ("evidence_refs",),
)

def get(obj, path):
    cur = obj
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur

bad_contracts = []
bad_evidence = []
bad_execution = []
bad_step_ownership = []

for flow in flows:
    v_loop = flow.get("v_loop", {})
    missing = ["/".join(path) for path in required_vloop_paths if not get(v_loop, path)]
    if missing:
        bad_contracts.append(f"{flow.get('id')}({','.join(missing)})")
    refs = set(v_loop.get("evidence_refs", []))
    if not refs or not refs <= evidence_ids:
        bad_evidence.append(flow.get("id"))
    execution = flow.get("execution", {})
    if (
        execution.get("dispatch_mode") != "subagent"
        or not execution.get("worker_template")
        or not execution.get("dispatch_record_shape")
        or not execution.get("merge_behavior")
        or "step V-loops" not in execution.get("join_condition", "")
    ):
        bad_execution.append(flow.get("id"))
    if not flow.get("flow_steps"):
        bad_step_ownership.append(flow.get("id"))

checks = (
    ("every atomic flow has full V-loop fields", not bad_contracts, "; ".join(bad_contracts)),
    ("every atomic flow references registered evidence", not bad_evidence, ", ".join(bad_evidence)),
    ("every atomic flow dispatches one subagent with step rollup join", not bad_execution, ", ".join(bad_execution)),
    ("every atomic flow owns at least one flow step", not bad_step_ownership, ", ".join(bad_step_ownership)),
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
