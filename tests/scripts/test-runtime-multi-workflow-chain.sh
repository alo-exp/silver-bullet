#!/usr/bin/env bash
# Runtime wiring: multi-capability intent chains feature → devops → release.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_STATE="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
LIB_SCHED="${REPO_ROOT}/hooks/lib/orchestrator-scheduler.sh"
HOOK="${REPO_ROOT}/hooks/flow-advance.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_APO_CATALOG_FILE="${REPO_ROOT}/docs/apo-catalog.json"
mkdir -p "$tmpdir/.planning" "$SB_RUNTIME_STATE_DIR"

# shellcheck source=/dev/null
source "$LIB_SCHED"
# shellcheck source=/dev/null
source "$LIB_STATE"

intent='Deliver incident-ready waitlist SaaS: tenant API with SQLite, landing page, Docker Compose canary checklist, ship readiness PR.'
sb_scheduler_detect_multi_capability_intent "$intent" \
  && pass "multi-capability intent detected" || fail "multi-capability intent not detected"

mkdir -p "$tmpdir/scripts"
cp "$REPO_ROOT/scripts/workflows.sh" "$tmpdir/scripts/workflows.sh"
chmod +x "$tmpdir/scripts/workflows.sh"
git -C "$tmpdir" init -q 2>/dev/null || true
git -C "$tmpdir" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init 2>/dev/null || true
mkdir -p "$tmpdir/.planning"
cat >"$tmpdir/.silver-bullet.json" <<'EOF'
{"sb_initiated":true,"project":{"name":"t","src_pattern":"/src/","active_workflow":"full-dev-cycle"}}
EOF
echo '# SB' >"$tmpdir/silver-bullet.md"

sb_orchestrator_clear_queue 2>/dev/null || true
printf '%s\n' "$intent" >"${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt"

run_hook() {
  (cd "$tmpdir" && printf '{"tool_input":{"skill":"%s"}}' "$1" | \
    SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" \
    bash "$HOOK" 2>/dev/null) || true
}

run_hook "silver-feature"
chain_len="$(jq '.composer_chain | length' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || echo 0)"
[[ "${chain_len:-0}" -ge 2 ]] && pass "composer_chain seeded (devops+release)" || fail "composer_chain missing (got $chain_len)"

logfile="$(sb_orchestrator_composition_log "$tmpdir")"
insert_count="$(jq -s '[.[] | .operations[]? | select(.op=="insert")] | length' "$logfile" 2>/dev/null | tr -d '[:space:]' || echo 0)"
[[ "${insert_count:-0}" -ge 2 ]] && pass "runtime insert ops recorded" || fail "expected >=2 insert ops, got $insert_count"

drain_current_queue() {
  while IFS= read -r token; do
    skill="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || printf '%s' "$token")"
    run_hook "$skill"
  done < <(jq -r '.flow_queue[]?' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null)
}

drain_current_queue
composer="$(jq -r '.composer // ""' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)"
[[ "$composer" == "silver-devops" || "$composer" == "silver-release" ]] \
  && pass "chain advanced past feature (composer=$composer)" \
  || fail "chain did not advance (composer=$composer)"

if [[ "$composer" == "silver-devops" ]]; then
  drain_current_queue
fi
composer="$(jq -r '.composer // ""' "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true)"
[[ "$composer" == "silver-release" ]] && pass "chain advanced to release" || fail "release not reached (composer=$composer)"
drain_current_queue

wf_ids="$(python3 - "$tmpdir" "$SB_RUNTIME_STATE_DIR" <<'PY'
import json, sys
from pathlib import Path
work_dir, state_dir = sys.argv[1:3]
ids = set()
for path in [Path(work_dir)/".planning/orchestrator-composition-log.jsonl",
             Path(state_dir)/"orchestrator-events.jsonl"]:
    if not path.is_file():
        continue
    for line in path.read_text().splitlines():
        try:
            doc = json.loads(line)
        except json.JSONDecodeError:
            continue
        for k in ("selected_workflow", "workflow_id"):
            v = doc.get(k) or (doc.get("payload") or {}).get(k)
            if isinstance(v, str) and v.startswith("WF-SILVER-"):
                ids.add(v)
        comp = doc.get("composer") or (doc.get("payload") or {}).get("composer")
        mapping = {"silver-feature": "WF-SILVER-FEATURE", "silver-devops": "WF-SILVER-DEVOPS",
                   "silver-release": "WF-SILVER-RELEASE"}
        if comp in mapping:
            ids.add(mapping[comp])
print(len(ids))
PY
)"
[[ "${wf_ids:-0}" -ge 3 ]] && pass "≥3 distinct WF-SILVER-* ids ($wf_ids)" || fail "expected >=3 workflow ids, got $wf_ids"

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
