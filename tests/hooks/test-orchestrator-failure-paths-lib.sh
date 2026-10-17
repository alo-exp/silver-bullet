#!/usr/bin/env bash
# Failure-path tests for the orchestrator libs: every degrade-gracefully fallback
# (`cmd || true`, `cmd || echo default`) is driven by injecting the failure it guards against
# and asserting the observable result (fallback value used, state untouched, status code).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED \
  SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT _lib_dir
export SILVER_BULLET_RUNTIME=claude
tl_stub sleep 'exit 0'
mkdir -p "$TL_TMP/cwd"
cd "$TL_TMP/cwd"
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh"
# shellcheck source=../../hooks/lib/orchestrator-scheduler.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"

CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
STATE="$(orch_state_file)"
DIRF="$(orch_directive_file)"
EVENTS="$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
MARKER="$(sb_orchestrator_worker_marker_file)"
NOTADIR="$TL_TMP/regular-file"
: >"$NOTADIR"
dirize() { rm -rf "$1"; mkdir -p "$1"; }
rc_of() { "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
# Reset per-case files.
reset() { rm -rf "$STATE" "$DIRF" "$EVENTS" "$MARKER" "$SB_RUNTIME_STATE_DIR/orchestrator-saga.json"; }

# ---------------------------------------------------------------------------------------

echo "=== directive lib ==="
reset
# The flow->skill table: mixed-case FLOW tokens fall through to the slug table.
assert_eq "FLOW-Quality-Gate slug" silver-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Quality-Gate)"
assert_eq "FLOW-Quality-Gate-Preship slug" silver-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Quality-Gate-Preship)"
assert_eq "FLOW-Devops-Quality-Gate-Preship slug" devops-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Devops-Quality-Gate-Preship)"
assert_eq "FLOW-Design-Handoff slug" silver-handoff "$(sb_orchestrator_flow_to_skill FLOW-Design-Handoff)"
assert_eq "FLOW-Secure slug" security "$(sb_orchestrator_flow_to_skill FLOW-Secure)"
assert_eq "FLOW-Novel slug" silver-novel "$(sb_orchestrator_flow_to_skill FLOW-Novel)"
assert_eq "bare lower-case name" silver-shout "$(sb_orchestrator_flow_to_skill SHOUT)"
# The worker-template mapper loads lazily; a lib whose directory vanished cannot load it.
gone="$(orch_stage_libs orchestrator-directive.sh)"
(
  unset -f sb_orchestrator_worker_template_for_skill
  # shellcheck disable=SC1091
  source "$gone/orchestrator-directive.sh"
  rm -rf "$gone"
  sb_orchestrator_directive_write silver-verify "" "" true
  [[ "$(jq -r .next_worker_template "$DIRF")" == null ]]
) && rc=0 || rc=$?
assert_eq "mapper dir gone: directive written without a template" 0 "$rc"
# The state directory cannot be created: nothing is written, the writers report failure.
rm -f "$DIRF"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_directive_write silver-plan ) 2>/dev/null && rc=0 || rc=$?
assert_eq "directive_write with an uncreatable state dir fails" 1 "$((rc != 0))"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_directive_write_batch silver-plan "" "" true "" '{"handoffs":[]}' ) 2>/dev/null && rc=0 || rc=$?
assert_eq "directive_write_batch with an uncreatable state dir fails" 1 "$((rc != 0))"
# jq cannot build the batch document.
orch_stub_failing jq 'batch_dispatch: $batch_dispatch'
sb_orchestrator_directive_write_batch silver-plan "" "" true TPL '{"handoffs":[]}' && rc=0 || rc=$?
assert_eq "batch document build failure" 1 "$rc"
assert_file_absent "no batch directive left behind" "$DIRF"
orch_unstub jq
# Override log: an unusable .planning/ directory is tolerated.
mkdir -p "$PROJ/.planning"
orch_stub_failing mkdir '.planning'
sb_orchestrator_log_override "$PROJ" "why" silver-plan && rc=0 || rc=$?
assert_eq "override log tolerates mkdir failure" 0 "$rc"
assert_eq "override entry still appended when the dir exists" 1 "$(wc -l <"$PROJ/.planning/orchestrator-override-log.jsonl" | tr -d ' ')"
orch_unstub mkdir
rm -f "$PROJ/.planning/orchestrator-override-log.jsonl"
mkdir -p "$PROJ/.planning/orchestrator-override-log.jsonl"
sb_orchestrator_log_override "$PROJ" "why" silver-plan && rc=0 || rc=$?
assert_eq "override log tolerates an unwritable log file" 0 "$rc"
rm -rf "$PROJ/.planning/orchestrator-override-log.jsonl"
# State sync: state file helper missing or jq failing degrade quietly.
orch_write_state '{"current_flow":"FLOW-PLAN","active_intent":"go"}'
sb_orchestrator_state_file() { return 1; }
sb_orchestrator_sync_directive_from_state
assert_eq "state_file helper failing: default path used" silver-plan "$(orch_directive_get .next_skill)"
rm -f "$DIRF"
sb_outcomes_session_file() { return 1; }
printf '%s' '{"outcomes":[{"id":"route","status":"pending"}]}' >"$SB_RUNTIME_STATE_DIR/outcomes-session.json"
sb_orchestrator_directive_from_pending_outcome
assert_eq "outcomes helper failing: default path used" silver "$(orch_directive_get .next_skill)"
unset -f sb_outcomes_session_file
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"
rm -f "$DIRF"
orch_stub_failing jq '.current_flow // ""'
sb_orchestrator_sync_directive_from_state
orch_unstub jq
assert_file_absent "jq failing on current_flow: no directive" "$DIRF"
tl_stub head "exit 1"
hash -r
sb_orchestrator_sync_directive_from_state
orch_unstub head
assert_eq "head failing while trimming the intent: directive still written" silver-plan "$(orch_directive_get .next_skill)"

# ---------------------------------------------------------------------------------------
echo "=== event log lib ==="
reset
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_event_append t '{}' ) 2>/dev/null && rc=0 || rc=$?
assert_eq "append with an uncreatable log dir fails" 1 "$rc"
dirize "$EVENTS"
sb_orchestrator_event_record_dispatch AF-A silver-a T 1 2>/dev/null && rc=0 || rc=$?
assert_eq "dispatch recorder swallows an append failure" 0 "$rc"
rm -rf "$EVENTS"
orch_write_state '{"flow_queue":["a"]}'
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_event_resume_hints_json ) >"$TL_TMP/hints.out" && rc=0 || rc=$?
assert_eq "resume hints with a failing state helper" '{"resumable":false,"reason":"no orchestrator.json"}' "$(cat "$TL_TMP/hints.out")"
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_event_apply_resume_checkpoint ) && rc=0 || rc=$?
assert_eq "resume checkpoint with a failing state helper" 1 "$rc"
# stdout that rejects writes: the failure surfaces as the exit status instead of being swallowed.
if [[ -w /dev/full ]]; then
  sb_orchestrator_event_resume_hints_json >/dev/full 2>/dev/null && rc=0 || rc=$?
  assert_eq "resume hints on an unwritable stdout report failure" 1 "$((rc != 0))"
fi

# ---------------------------------------------------------------------------------------
echo "=== parent lib ==="
reset
# Marker file with unparsable JSON and no usable spawned_at.
printf 'garbage' >"$MARKER"
sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "garbage marker is not a worker" 1 "$rc"
# grep -o failing after grep -q matched (no jq available for the first read).
printf '{"spawned_at":"%s"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$MARKER"
NOJQ="$(tl_path_without jq)"
orch_stub_failing grep '-oE'
nojq_dir="$TL_TMP/nojq-bin"
mkdir -p "$nojq_dir"
for b in "$NOJQ"/*; do n="${b##*/}"; [[ "$n" == grep ]] || ln -sf "$(readlink -f "$b")" "$nojq_dir/$n" 2>/dev/null || true; done
cp "$TL_BIN/grep" "$nojq_dir/grep"
PATH="$nojq_dir" sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "grep -o failing: no spawn time, not a worker" 1 "$rc"
orch_unstub grep
# grep -o succeeding with nothing: spawned_at stays empty.
tl_stub grep 'if [[ "$1" == "-oE" ]]; then exit 0; fi; exec '"$(PATH="$NOJQ" command -v grep)"' "$@"'
cp "$TL_BIN/grep" "$nojq_dir/grep"
PATH="$nojq_dir" sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "empty grep -o output: not a worker" 1 "$rc"
orch_unstub grep
# BSD date flavours where the first probe succeeds but the real conversion then fails.
real_date="$(command -v date)"
printf '{"spawned_at":"2024-01-01T00:00:00Z"}' >"$MARKER"
cnt="$TL_TMP/date-count"
for flag in -ju -j; do
  rm -f "$cnt"
  cat >"$TL_BIN/date" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"$flag -f"*)
    n=\$(cat "$cnt" 2>/dev/null || echo 0); echo \$((n+1)) >"$cnt"
    [[ \$n -eq 0 ]] && { echo 5; exit 0; }
    exit 1 ;;
  *"-ju -f"*|*"-j -f"*) exit 1 ;;
  "+%s") echo 100000 ;;
  *) exec "$real_date" "\$@" ;;
esac
STUB
  chmod +x "$TL_BIN/date"
  hash -r
  sb_orchestrator_is_worker_session && rc=0 || rc=$?
  assert_eq "date $flag probe ok, conversion fails: epoch 0 means not a worker" 1 "$rc"
done
orch_unstub date
rm -f "$MARKER"
# guard_applies: root resolver failing.
orch_make_project "$TL_TMP/gp"
( sb_find_project_root_walk_only() { return 1; }; cd "$TL_TMP/gp" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "root resolver failing: guard does not apply" 1 "$rc"
# mark / clear worker marker failure modes.
mkdir -p "$MARKER.tmp"
sb_orchestrator_mark_worker_spawn silver-plan 2>/dev/null && rc=0 || rc=$?
assert_eq "marker temp path blocked: spawn marking fails" 1 "$((rc != 0))"
rmdir "$MARKER.tmp"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_mark_worker_spawn silver-plan ) 2>/dev/null && rc=0 || rc=$?
assert_eq "uncreatable state dir: spawn marking fails" 1 "$((rc != 0))"
mkdir -p "$MARKER"
sb_orchestrator_clear_worker_marker && rc=0 || rc=$?
assert_eq "clearing a marker that is a directory is tolerated" 0 "$rc"
rmdir "$MARKER"
# state_applies_to_project fallbacks.
orch_write_state "$(jq -n --arg r "$PROJ" '{current_flow:"a",repo_root:$r}')"
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_state_applies_to_project "$PROJ" ) && rc=0 || rc=$?
assert_eq "state helper failing after the pending check" 1 "$rc"
orch_stub_failing jq '.repo_root'
sb_orchestrator_state_applies_to_project "$PROJ" && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing on repo_root: unprovable" 1 "$rc"
orch_write_state '{"current_flow":"a","workflow_id":"WF1"}'
orch_stub_failing jq '.workflow_id'
sb_orchestrator_state_applies_to_project "$PROJ" && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing on workflow_id: unprovable" 1 "$rc"
# jq disappears between the queue-pending check and the follow-up read.
orch_write_state "$(jq -n --arg r "$PROJ" '{current_flow:"a",repo_root:$r}')"
real_jq="$(command -v jq)"
vanish="$TL_TMP/vanish-bin"
mkdir -p "$vanish"
cat >"$vanish/jq" <<STUB
#!/usr/bin/env bash
rm -f "\$0"
exec "$real_jq" "\$@"
STUB
chmod +x "$vanish/jq"
( PATH="$vanish:$NOJQ"; hash -r; sb_orchestrator_state_applies_to_project "$PROJ" ) && rc=0 || rc=$?
hash -r
assert_eq "jq vanishing mid-check: unprovable" 1 "$rc"
# Bash classification without python.
assert_eq "no python3: unknown commands are not allowed" 1 "$((($(PATH="$(tl_path_without python3)" rc_of sb_orchestrator_parent_bash_allowed "ls")) != 0))"
# Without the classifier lib there is no read-only allowance.
nl="$(orch_stage_libs orchestrator-parent.sh)"
assert_eq "no classifier: refused" 1 "$(bash -c 'source "$1"; sb_orchestrator_parent_bash_allowed "git status" >/dev/null; echo $?' _ "$nl/orchestrator-parent.sh")"

# ---------------------------------------------------------------------------------------
echo "=== skill-atom lib ==="
GARB="$TL_TMP/garbage-catalog.json"
printf 'garbage' >"$GARB"
sb_scheduler_resolve_atom_id "$GARB" silver-thing >/dev/null && rc=0 || rc=$?
assert_eq "unreadable catalog resolves nothing" 1 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }; sb_scheduler_resolve_atom_id "$GARB" FLOW-THING ) >/dev/null && rc=0 || rc=$?
assert_eq "failing normaliser: nothing resolved" 1 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }; sb_scheduler_resolve_atom_id "$CAT" FLOW-PLAN ) >/dev/null && rc=0 || rc=$?
assert_eq "failing normaliser: only direct matches resolve" 1 "$rc"
# A reverse lookup can only ever return an AF id for AF tokens, which resolve earlier.
assert_eq "AF tokens never reach the reverse lookup" AF-PLAN "$(sb_scheduler_resolve_atom_id "$CAT" AF-PLAN)"

# ---------------------------------------------------------------------------------------

tl_results
