#!/usr/bin/env bash
# Durable orchestration event log — append, tail, resume, saga helpers.
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

tail="$(sb_orchestrator_event_tail_json 2)"
if jq -e 'length == 2' <<<"$tail" >/dev/null 2>&1; then
  pass "event tail returns last N entries"
else
  fail "event tail json invalid"
fi

sb_orchestrator_seed_intent "resume fixture" "silver-feature" "$tmpdir" >/dev/null
hints="$(sb_orchestrator_event_resume_hints_json)"
if jq -e '.resumable == true and (.recent_events | length) > 0' <<<"$hints" >/dev/null 2>&1; then
  pass "resume hints merge orchestrator.json + event tail"
else
  fail "resume hints missing resumable state"
fi

sb_orchestrator_saga_begin "silver-ship" "ship" '[".planning/STATE.md"]'
sb_orchestrator_saga_rollback_hint "silver-ship" "worker test failure" >/dev/null
if [[ -f "$(sb_orchestrator_event_log_saga_file)" ]] \
  && jq -e '.status == "rollback_required"' "$(sb_orchestrator_event_log_saga_file)" >/dev/null 2>&1; then
  pass "saga rollback records durable hint"
else
  fail "saga rollback state missing"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
