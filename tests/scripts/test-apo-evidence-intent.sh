#!/usr/bin/env bash
# Validates APO audit entities: evidence, intent ledgers, rollups, and composition logs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for APO evidence/intent tests"
  exit 0
fi

results="$(python3 - "$CATALOG" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
entities = {
    item.get("id")
    for key in ("processes", "workflows", "atomic_flows", "flow_steps", "artifacts", "tool_policies", "dynamic_rules")
    for item in catalog.get(key, [])
}
v_loop_ids = {
    item.get("v_loop", {}).get("id")
    for key in ("atomic_flows", "flow_steps")
    for item in catalog.get(key, [])
}
v_loop_ids |= {item.get("id") for item in catalog.get("v_loops", [])}
evidence_records = catalog.get("evidence_records", [])
intent_ledgers = catalog.get("intent_ledgers", [])
rollups = catalog.get("v_loop_rollups", [])
composition_logs = catalog.get("composition_logs", [])
evidence_ids = {record.get("id") for record in evidence_records}
intent_ids = {ledger.get("id") for ledger in intent_ledgers}

classes = {record.get("sufficiency_class") for record in evidence_records}
required_classes = {"inspection", "analysis", "demonstration", "testing", "artifact_review", "command_evidence", "tool_evidence"}
bad_evidence_refs = [
    record.get("id")
    for record in evidence_records
    if record.get("satisfies_v_loop_ref") not in v_loop_ids
]
bad_intents = [
    ledger.get("id")
    for ledger in intent_ledgers
    if not ledger.get("material_claims")
    or not set(ledger.get("mapped_entities", [])) <= entities
    or ledger.get("final_gate_result") not in {"pending", "pass", "fail", "blocked"}
]
bad_rollups = [
    rollup.get("id")
    for rollup in rollups
    if not rollup.get("child_v_loop_refs")
    or not set(rollup.get("child_v_loop_refs", [])) <= v_loop_ids
    or rollup.get("intent_ledger_ref") not in intent_ids
]
bad_logs = [
    log.get("id")
    for log in composition_logs
    if not log.get("operations")
    or any(not op.get("catalog_rule_ref") or not op.get("rationale") for op in log.get("operations", []))
    or not log.get("scheduler_decisions")
]
missing_evidence_links = [
    flow.get("id")
    for flow in catalog.get("atomic_flows", [])
    if not set(flow.get("v_loop", {}).get("evidence_refs", [])) <= evidence_ids
]

checks = (
    ("evidence registry covers every sufficiency class", required_classes <= classes, ", ".join(sorted(required_classes - classes))),
    ("evidence records satisfy known V-loops", not bad_evidence_refs, ", ".join(bad_evidence_refs)),
    ("intent ledgers map material claims to catalog entities", not bad_intents, ", ".join(bad_intents)),
    ("V-loop rollups aggregate child V-loops and intent ledger", not bad_rollups, ", ".join(bad_rollups)),
    ("composition logs require rule refs and scheduler decisions", not bad_logs, ", ".join(bad_logs)),
    ("atomic-flow evidence refs resolve to registry", not missing_evidence_links, ", ".join(missing_evidence_links)),
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
