#!/usr/bin/env bash
# Enforces canonical, non-redundant AF-* promotion gates in docs/apo-catalog.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for atomic-flow dedup tests"
  exit 0
fi

while IFS=$'\t' read -r status label detail; do
  if [[ "$status" == "PASS" ]]; then
    pass "$label"
  else
    fail "$label${detail:+: $detail}"
  fi
done < <(python3 - "$CATALOG" <<'PY'
import json
import re
import sys
from collections import Counter
from pathlib import Path

catalog_path = Path(sys.argv[1])
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
flows = catalog.get("atomic_flows", [])
flow_ids = {flow.get("id") for flow in flows}
workflow_refs = set()

def collect_refs(nodes):
    for node in nodes or []:
        if node.get("kind") == "atomic_flow":
            workflow_refs.add(node.get("ref"))
        collect_refs(node.get("children"))

for workflow in catalog.get("workflows", []):
    collect_refs(workflow.get("composition_tree"))

checks = []
legacy_ids = [flow.get("id") for flow in flows if re.fullmatch(r"AF-FLOW-\d+", flow.get("id", ""))]
checks.append(("canonical AF IDs replace legacy AF-FLOW mirror", not legacy_ids, ", ".join(legacy_ids)))
statuses = [flow.get("id") for flow in flows if flow.get("dedup_gate_status") != "passed"]
checks.append(("every atomic flow has passed dedup gate", not statuses, ", ".join(statuses)))
classes = [flow.get("capability_class") for flow in flows]
duplicate_classes = sorted(name for name, count in Counter(classes).items() if name and count > 1)
checks.append(("no duplicate atomic-flow capability classes", not duplicate_classes, ", ".join(duplicate_classes)))
missing_gate_records = [
    flow.get("id")
    for flow in flows
    if not all(flow.get("dedup_gate", {}).get(key) for key in (
        "equivalence_review",
        "granularity_review",
        "usage_review",
        "v_loop_review",
        "step_review",
    ))
]
checks.append(("every promoted atom records the five-part dedup gate", not missing_gate_records, ", ".join(missing_gate_records)))
orphan_flows = sorted(flow_ids - workflow_refs)
checks.append(("every atomic flow is referenced by workflow composition", not orphan_flows, ", ".join(orphan_flows)))

for label, ok, detail in checks:
    print(("PASS" if ok else "FAIL") + "\t" + label + ("\t" + detail if detail else ""))
PY
)

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
