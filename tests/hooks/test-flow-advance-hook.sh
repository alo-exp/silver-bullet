#!/usr/bin/env bash
# End-to-end tests for hooks/flow-advance.sh (PostToolUse/Skill): composer start, atom advance,
# devops workflow reset and the fail-open paths.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/flow-advance.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_PROJECT_ROOT
tl_stub sleep 'exit 0'

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ" '{"sb_initiated":true,"project":{"active_workflow":"full-dev-cycle"}}'
mkdir -p "$PROJ/scripts"
cat >"$PROJ/scripts/workflows.sh" <<'STUB'
#!/usr/bin/env bash
case "$1" in start) echo WF-HOOK-1 ;; esac
STUB
chmod +x "$PROJ/scripts/workflows.sh"
cd "$PROJ"
NOJQ="$(tl_path_without jq)"
INTENT="$SB_RUNTIME_STATE_DIR/orchestrator-intent.txt"
skill_json() { jq -cn --arg s "$1" '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:$s}}'; }
msg() { jq -r '.hookSpecificOutput.message // ""' <<<"$TL_OUT" 2>/dev/null || true; }

echo "=== fail-open paths ==="
tl_run_hook "$HOOK" ""
assert_eq "empty input: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" '{"tool_input":{}}'
assert_eq "no skill in the payload: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" 'not json'
assert_eq "invalid JSON: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(skill_json silver-brainstorm-unknown)"
assert_eq "skill that is neither composer nor atom: silent" "0|" "$TL_STATUS|$TL_OUT"
mkdir -p "$TL_TMP/plain/.git"
# The project-root cache (written by earlier runs) lets hooks resolve the project from anywhere; clear it.
ROOT_CACHE="$SB_RUNTIME_STATE_DIR/project-root"
rm -f "$ROOT_CACHE" "$(orch_state_file)"
( cd "$TL_TMP/plain" && tl_run_hook "$HOOK" "$(skill_json silver-feature)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "outside an SB project: silent" "0|" "$(cat "$TL_TMP/plain.out")"
assert_file_absent "outside an SB project: no state" "$(orch_state_file)"

echo "=== jq missing ==="
rm -f "$(orch_state_file)"
PATH="$NOJQ" tl_run_hook "$HOOK" "$(skill_json silver-feature)"
assert_eq "initiated project: visible warning" "0" "$TL_STATUS"
assert_contains "warning names the hook" "$TL_OUT" "ENFORCEMENT INACTIVE"
assert_contains "warning names flow-advance" "$TL_OUT" "flow-advance"
assert_file_absent "no state without jq" "$(orch_state_file)"
rm -f "$ROOT_CACHE"
( cd "$TL_TMP/plain" && PATH="$NOJQ" tl_run_hook "$HOOK" "$(skill_json silver-feature)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "jq missing outside a project: silent" "0|" "$(cat "$TL_TMP/plain.out")"
staged="$(orch_stage_hook flow-advance.sh)"
PATH="$NOJQ" tl_run_stdin "$(skill_json silver-feature)" bash "$staged"
assert_eq "jq missing without the shared libs: silent" "0|" "$TL_STATUS|$TL_OUT"

echo "=== composer start ==="
rm -f "$(orch_state_file)" "$INTENT"
tl_run_hook "$HOOK" "$(skill_json silver-feature)"
assert_eq "composer start message" "SB orchestrator ► Workflow WF-HOOK-1 started (autonomous; no composition approval required)" "$(msg)"
assert_eq "hook event named in the output" PostToolUse "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
assert_eq "queue seeded for the composer" silver-feature "$(orch_state_get .composer)"
assert_eq "workflow bound to the queue" WF-HOOK-1 "$(orch_state_get .workflow_id)"
assert_eq "state records the project root" "$PROJ" "$(orch_state_get .repo_root)"
assert_eq "no intent file: empty intent" "" "$(orch_state_get .active_intent)"
rm -f "$(orch_state_file)"
printf 'ship the report\nsecond line ignored\n' >"$INTENT"
tl_run_hook "$HOOK" "$(skill_json sb:feature)"
assert_eq "intent file first line seeds the intent" "ship the report" "$(orch_state_get .active_intent)"
assert_eq "namespaced composer is canonicalised" silver-feature "$(orch_state_get .composer)"
rm -f "$(orch_state_file)"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(skill_json silver-feature)"
assert_eq "worker re-reading a composer: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "worker never seeds the queue" "$(orch_state_file)"
mkdir -p "$TL_TMP/p2/.git"
orch_make_project "$TL_TMP/p2"
( cd "$TL_TMP/p2" && tl_run_hook "$HOOK" "$(skill_json silver-feature)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/p2.out"
assert_eq "composer without a workflow id: seeds the queue silently" "0|" "$(cat "$TL_TMP/p2.out")"
assert_eq "queue still seeded without a workflow id" silver-feature "$(orch_state_get .composer)"

echo "=== atom advance ==="
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,flow_queue:["silver-plan","silver-execute"],current_flow:"silver-plan",active_intent:"i"}')"
tl_run_hook "$HOOK" "$(skill_json silver-plan)"
assert_contains "advance message" "$(msg)" "Next flow: silver-execute"
assert_eq "state advanced" silver-execute "$(orch_state_get .current_flow)"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_eq "atom not in the queue: silent" "0|" "$TL_STATUS|$TL_OUT"

echo "=== devops workflow reset after ship ==="
orch_make_project "$PROJ" '{"sb_initiated":true,"project":{"active_workflow":"devops-cycle"}}'
rm -f "$(orch_state_file)"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_eq "active_workflow reset" full-dev-cycle "$(jq -r .project.active_workflow "$PROJ/.silver-bullet.json")"
assert_contains "reset note emitted" "$(msg)" "active_workflow reset to full-dev-cycle after devops ship"
assert_eq "config stays valid JSON" true "$(jq -r .sb_initiated "$PROJ/.silver-bullet.json")"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_eq "already full-dev-cycle: nothing to report" "0|" "$TL_STATUS|$TL_OUT"
# The note joins an advance message.
orch_make_project "$PROJ" '{"sb_initiated":true,"project":{"active_workflow":"devops-cycle"}}'
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,flow_queue:["silver-ship","silver-release"],current_flow:"silver-ship"}')"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_contains "advance and reset messages are combined" "$(msg)" " — SB ► active_workflow reset"
# No project.active_workflow key: defaults to full-dev-cycle, so no reset.
orch_make_project "$PROJ" '{"sb_initiated":true}'
rm -f "$(orch_state_file)"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_eq "no active_workflow key: nothing to do" "0|" "$TL_STATUS|$TL_OUT"
# The config rewrite fails: the original is untouched and no note is emitted.
orch_make_project "$PROJ" '{"sb_initiated":true,"project":{"active_workflow":"devops-cycle"}}'
real_jq="$(command -v jq)"
tl_stub jq "for a in \"\$@\"; do [[ \"\$a\" == *'= \"full-dev-cycle\"'* ]] && exit 1; done; exec $real_jq \"\$@\""
hash -r
mkdir -p "$TL_TMP/hook-tmp"
TMPDIR="$TL_TMP/hook-tmp" tl_run_hook "$HOOK" "$(skill_json silver-ship)"
rm -f "$TL_BIN/jq"
hash -r
assert_eq "failed rewrite: config untouched" devops-cycle "$(jq -r .project.active_workflow "$PROJ/.silver-bullet.json")"
assert_eq "failed rewrite: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "failed rewrite: temp file removed" 0 "$(find "$TL_TMP/hook-tmp" -type f | wc -l | tr -d ' ')"

echo "=== failure paths ==="
status=0
out="$(bash "$TL_REPO_ROOT/$HOOK" <"$TL_TMP")" || status=$?
assert_eq "unreadable stdin: silent" "0|" "$status|$out"

# Without the shared canonicaliser the hook strips the prefix and namespace itself.
tree="$(orch_stage_tree)"
rm -f "$tree/lib/skill-discovery.sh"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,flow_queue:["silver-plan","silver-execute"],current_flow:"silver-plan"}')"
tl_run_stdin "$(skill_json silver:plan)" bash "$tree/flow-advance.sh"
assert_contains "fallback canonicalisation maps silver:plan to silver-plan" "$(msg)" "Next flow: silver-execute"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,flow_queue:["silver-plan","silver-execute"],current_flow:"silver-plan"}')"
tl_run_stdin "$(skill_json sb:silver-plan)" bash "$tree/flow-advance.sh"
assert_contains "fallback canonicalisation strips the sb: prefix" "$(msg)" "Next flow: silver-execute"

# No project root resolver result: the working directory is the root.
tree="$(orch_stage_tree)"
cat >"$tree/lib/sb-project-gate.sh" <<'LIB'
sb_project_gate_or_exit() { :; }
sb_find_project_root() { return 1; }
sb_find_project_config() { return 1; }
LIB
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,flow_queue:["silver-plan","silver-execute"],current_flow:"silver-plan"}')"
tl_run_stdin "$(skill_json silver-plan)" bash "$tree/flow-advance.sh"
assert_contains "no root resolver: PWD used as the project root" "$(msg)" "Next flow: silver-execute"

# Unreadable intent file: composer still starts, with an empty intent.
rm -f "$(orch_state_file)"
printf 'my intent\n' >"$INTENT"
orch_stub_failing head orchestrator-intent
tl_run_hook "$HOOK" "$(skill_json silver-feature)"
orch_unstub head
assert_contains "unreadable intent: composer started" "$(msg)" "started"
assert_eq "unreadable intent: empty intent" "" "$(orch_state_get .active_intent)"
rm -f "$INTENT"

# Orchestrator entry points that fail are tolerated.
tree="$(orch_stage_tree)"
cat >"$tree/lib/orchestrator-state.sh" <<'LIB'
sb_orchestrator_is_composer_skill() { [[ "$1" == silver-feature ]]; }
sb_orchestrator_is_flow_atom() { [[ "$1" == silver-plan ]]; }
sb_orchestrator_on_composer_start() { return 1; }
sb_orchestrator_advance_on_atom() { return 1; }
LIB
tl_run_stdin "$(skill_json silver-feature)" bash "$tree/flow-advance.sh"
assert_eq "composer start failing: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_stdin "$(skill_json silver-plan)" bash "$tree/flow-advance.sh"
assert_eq "atom advance failing: silent" "0|" "$TL_STATUS|$TL_OUT"

# A corrupt project config cannot be inspected: the ship reset is skipped.
printf 'not json' >"$PROJ/.silver-bullet.json"
rm -f "$(orch_state_file)"
tl_run_hook "$HOOK" "$(skill_json silver-ship)"
assert_eq "corrupt config: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "corrupt config left alone" "not json" "$(cat "$PROJ/.silver-bullet.json")"

# The rewrite fails and the temp file cannot be removed either: still silent.
orch_make_project "$PROJ" '{"sb_initiated":true,"project":{"active_workflow":"devops-cycle"}}'
mkdir -p "$TL_TMP/hook-tmp2"
orch_stub_failing jq '= "full-dev-cycle"'
tl_stub rm "for a in \"\$@\"; do [[ \"\$a\" == *hook-tmp2* ]] && exit 1; done; exec $(command -v rm) \"\$@\""
hash -r
TMPDIR="$TL_TMP/hook-tmp2" tl_run_hook "$HOOK" "$(skill_json silver-ship)"
orch_unstub rm
orch_unstub jq
assert_eq "failed rewrite with an undeletable temp file: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "config untouched" devops-cycle "$(jq -r .project.active_workflow "$PROJ/.silver-bullet.json")"

tl_results
