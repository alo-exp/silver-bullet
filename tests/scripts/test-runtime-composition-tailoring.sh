#!/usr/bin/env bash
# Runtime wiring: doc-only intent records substitute/prune via composer_start path.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_STATE="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
LIB_SCHED="${REPO_ROOT}/hooks/lib/orchestrator-scheduler.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
export SB_APO_CATALOG_FILE="${REPO_ROOT}/docs/apo-catalog.json"
mkdir -p "$tmpdir/.planning" "$SB_RUNTIME_STATE_DIR"

# shellcheck source=/dev/null
source "$LIB_SCHED"

intent='Add a single static README badge (shields.io) — documentation-only change, no API routes.'
sb_scheduler_detect_doc_only_intent "$intent" \
  && pass "doc-only intent detected" || fail "doc-only intent not detected"

sb_scheduler_apply_doc_only_tailoring "$tmpdir" "silver-fast" "$intent" 2>/dev/null || true
logfile="$(sb_orchestrator_composition_log "$tmpdir")"
if [[ -f "$logfile" ]]; then
  op_count="$(jq -s '[.[] | .operations[]?] | length' "$logfile" 2>/dev/null || echo 0)"
  sub_count="$(jq -s '[.[] | .operations[]? | select(.op=="substitute")] | length' "$logfile" 2>/dev/null || echo 0)"
  [[ "${op_count:-0}" -ge 2 ]] && pass "runtime recorded >=2 composition ops" || fail "expected >=2 ops, got $op_count"
  [[ "${sub_count:-0}" -ge 1 ]] && pass "runtime substitute op recorded" || fail "no substitute op"
  swf="$(jq -r 'select(.selected_workflow != null) | .selected_workflow' "$logfile" 2>/dev/null | head -1)"
  [[ "$swf" == "WF-SILVER-FAST" ]] && pass "selected_workflow WF-SILVER-FAST on seed" || fail "selected_workflow missing on seed (got ${swf:-empty})"
else
  fail "composition log not created"
fi

# composer_start seeds selected_workflow catalog id
if [[ -f "$LIB_STATE" ]]; then
  mkdir -p "$tmpdir/scripts"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "20260706T000000Z-test-silver-fast"\n' >"$tmpdir/scripts/workflows.sh"
  chmod +x "$tmpdir/scripts/workflows.sh"
  # shellcheck source=/dev/null
  source "$LIB_STATE"
  sb_orchestrator_clear_queue 2>/dev/null || true
  sb_orchestrator_on_composer_start "silver-fast" "$intent" "$tmpdir" >/dev/null 2>&1 || true
  if [[ -f "$logfile" ]]; then
    has_catalog="$(jq -s '[.[] | select(.selected_workflow == "WF-SILVER-FAST")] | length' "$logfile" 2>/dev/null || echo 0)"
    [[ "${has_catalog:-0}" -ge 1 ]] && pass "composer_start seeds WF-SILVER-FAST" || fail "composer_start missing catalog workflow_id"
  else
    fail "composer_start did not write composition log"
  fi
else
  fail "orchestrator-state.sh missing"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
