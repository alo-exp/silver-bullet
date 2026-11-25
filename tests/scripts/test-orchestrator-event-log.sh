#!/usr/bin/env bash
# Durable orchestration event log — append helpers and the size bound (tail/resume/saga helpers were removed: R4-28).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-state.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/orchestrator-event-log.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export SB_RUNTIME_STATE_DIR="$tmpdir/runtime"
mkdir -p "$SB_RUNTIME_STATE_DIR"

sb_orchestrator_event_record_dispatch "AF-PLAN" "silver-plan" "PLAN" 0
sb_orchestrator_event_record_join "AF-PLAN" "silver-plan" "joined"
sb_orchestrator_event_record_advance "silver-plan" "silver-execute" false
sb_orchestrator_event_record_stop_block "pending batch handoff"

logfile="$(sb_orchestrator_event_log_file)"
if [[ -f "$logfile" ]] && [[ "$(wc -l <"$logfile" | tr -d ' ')" -ge 4 ]]; then
  pass "event log appends dispatch/join/advance/stop_block"
else
  fail "event log missing expected entries"
fi

# The log stays bounded (R4-29).
export SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES=3000 SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES=20
for i in $(seq 1 200); do sb_orchestrator_event_record_advance "silver-$i" "silver-next" false; done
size="$(wc -c <"$logfile" | tr -d ' ')"
if [[ "$size" -le 4000 ]]; then
  pass "event log stays bounded ($size bytes after 200 events)"
else
  fail "event log grew to $size bytes"
fi
if [[ "$(tail -1 "$logfile" | jq -r '.payload.completed_skill')" == "silver-200" ]]; then
  pass "newest event survives the trim"
else
  fail "newest event lost"
fi
for removed in sb_orchestrator_event_tail_json sb_orchestrator_event_resume_hints_json sb_orchestrator_event_apply_resume_checkpoint sb_orchestrator_saga_begin; do
  if declare -f "$removed" >/dev/null 2>&1; then fail "dead helper $removed is back"; else pass "dead helper $removed stays removed"; fi
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
