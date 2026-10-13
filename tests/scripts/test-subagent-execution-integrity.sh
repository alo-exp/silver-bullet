#!/usr/bin/env bash
# Validates atomic-flow execution metadata for one-subagent-per-atom scheduling.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/docs/apo-catalog.json"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required for subagent execution tests"
  exit 0
fi

results="$(python3 - "$CATALOG" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
flows = catalog.get("atomic_flows", [])
bad_dispatch = []
bad_records = []
bad_scopes = []

for flow in flows:
    execution = flow.get("execution", {})
    if execution.get("dispatch_mode") != "subagent":
        bad_dispatch.append(flow.get("id"))
    shape = execution.get("dispatch_record_shape", "")
    if not all(token in shape for token in ("subagent_id", "inputs", "outputs", "v_gate_result", "step_v_loop_status")):
        bad_records.append(flow.get("id"))
    if not execution.get("dependencies") or not execution.get("mutation_scopes"):
        bad_scopes.append(flow.get("id"))

checks = (
    ("every atomic flow dispatches as exactly one subagent", not bad_dispatch, ", ".join(bad_dispatch)),
    ("every dispatch record captures subagent, IO, step loop, and V-gate", not bad_records, ", ".join(bad_records)),
    ("every atomic flow declares dependencies and mutation scopes", not bad_scopes, ", ".join(bad_scopes)),
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
