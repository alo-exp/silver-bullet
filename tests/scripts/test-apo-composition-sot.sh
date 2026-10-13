#!/usr/bin/env bash
# Ensures workflow composition authority lives only in docs/apo-catalog.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
GENERATOR="$REPO_ROOT/scripts/generate-apo-artifacts.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for APO composition SOT tests"
  exit 0
fi

results="$(python3 - "$CATALOG" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
flow_ids = {flow.get("id") for flow in catalog.get("atomic_flows", [])}
workflow_ids = {workflow.get("id") for workflow in catalog.get("workflows", [])}
bad_refs = []
missing_trees = []

def walk(nodes, workflow_id):
    for node in nodes or []:
        kind = node.get("kind")
        ref = node.get("ref")
        if kind == "atomic_flow" and ref not in flow_ids:
            bad_refs.append(f"{workflow_id}:{ref}")
        if kind == "workflow" and ref not in workflow_ids:
            bad_refs.append(f"{workflow_id}:{ref}")
        walk(node.get("children"), workflow_id)

for workflow in catalog.get("workflows", []):
    if not workflow.get("composition_tree"):
        missing_trees.append(workflow.get("id"))
    walk(workflow.get("composition_tree"), workflow.get("id"))

checks = (
    ("every workflow has a catalog composition_tree", not missing_trees, ", ".join(missing_trees)),
    ("every composition ref resolves inside catalog", not bad_refs, ", ".join(bad_refs)),
    ("generated views are listed in catalog metadata", set(catalog.get("meta", {}).get("generated_views", [])) >= {"docs/composable-flows-contracts.md", "docs/workflow-composition-matrix.md", "docs/generated/atomic-flow-index.json"}, ""),
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

if [[ -x "$GENERATOR" ]]; then
  if python3 "$GENERATOR" --check >/dev/null; then
    pass "generated composition views are fresh"
  else
    fail "generated composition views are stale; run scripts/generate-apo-artifacts.py"
  fi
else
  fail "missing executable generated-view builder: scripts/generate-apo-artifacts.py"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
