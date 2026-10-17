#!/usr/bin/env bash
# End-to-end tests for hooks/orchestrator-directive-guard.sh (PreToolUse).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/orchestrator-directive-guard.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_PARENT SB_ORCHESTRATOR_WORKER SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED SILVER_BULLET_PROJECT_ROOT \
  SB_ORCHESTRATOR_EDIT_WITHOUT_WORKFLOW_BLOCK SILVER_BULLET_STATE_FILE SB_ORCHESTRATOR_WORKER_MARKER_TTL_SECONDS
export SILVER_BULLET_RUNTIME=claude

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ" '{"sb_initiated":true}'
mkdir -p "$PROJ/.planning/workflows"
cd "$PROJ"
DIRF="$(orch_directive_file)"
MARKER="$SB_RUNTIME_STATE_DIR/orchestrator-worker-active.json"
COUNTER="$SB_RUNTIME_STATE_DIR/edit-without-workflow.count"
STATE_REC="$SB_RUNTIME_STATE_DIR/state"
export SILVER_BULLET_STATE_FILE="$STATE_REC"

tool_json() { tl_hook_json PreToolUse "$@"; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo bad-json; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT" 2>/dev/null || true; }
write_directive() { # write_directive SKILL [TEMPLATE] [BLOCKING] [ARGS]
  jq -n --arg s "$1" --arg t "${2:-}" --argjson b "${3:-true}" --arg a "${4:-}" \
    '{next_skill:$s,next_worker_template:(if $t=="" then null else $t end),args:$a,reason:"queued by test",blocking:$b}' >"$DIRF"
}
reset() { rm -f "$DIRF" "$MARKER" "$COUNTER" "$STATE_REC" "$PROJ/.planning/orchestrator-override-log.jsonl"; }


echo "=== failure paths ==="
reset
unset SB_ORCHESTRATOR_WORKER
status=0
out="$(SB_ORCHESTRATOR_PARENT=1 bash "$TL_REPO_ROOT/$HOOK" <"$TL_TMP")" || status=$?
assert_eq "unreadable stdin: silent" "0|" "$status|$out"

# A jq whose bare-filter probe fails but which otherwise works: the hook parses fields with grep/sed.
real_jq="$(command -v jq)"
tl_stub jq "if [[ \$# -eq 1 && \"\$1\" == . ]]; then exit 1; fi; exec $real_jq \"\$@\""
hash -r
export SB_ORCHESTRATOR_PARENT=1
write_directive silver-plan PLAN
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse"}'
assert_eq "no tool_name in the payload: parent mode fails closed" deny "$(decision)"
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{}}'
assert_eq "Skill call without a skill name: denied for the parent" deny "$(decision)"
assert_contains "denial mentions the empty skill" "$(reason)" "Do not invoke / directly"
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}}'
assert_eq "grep-parsed Bash command still classified as read-only" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf x"}}'
assert_eq "grep-parsed mutating Bash denied" deny "$(decision)"
orch_unstub jq
# tool-input helpers already loaded: the declared helper parses the command.
BASH_ENV="$(orch_bash_env_wrapper "$TL_REPO_ROOT/hooks/lib/tool-input.sh")" tl_run_hook "$HOOK" "$(tool_json Bash 'git status')"
assert_eq "preloaded tool-input helper: read-only Bash allowed" "0|" "$TL_STATUS|$TL_OUT"
BASH_ENV="$(orch_bash_env_wrapper "$TL_REPO_ROOT/hooks/lib/tool-input.sh")" tl_run_hook "$HOOK" "$(tool_json Bash 'rm -rf x')"
assert_eq "preloaded tool-input helper: mutating Bash denied" deny "$(decision)"

# Parent delegation with unreadable directive fields / unwritable marker.
rm -f "$MARKER"
orch_stub_failing jq '.next_worker_template'
tl_run_hook "$HOOK" "$(tool_json Agent "")"
orch_unstub jq
assert_eq "template unreadable: spawn still allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "template unreadable: marker still written" silver-plan "$(jq -r .skill "$MARKER")"
rm -f "$MARKER"
orch_stub_failing jq '.args'
tl_run_hook "$HOOK" "$(tool_json Agent "")"
orch_unstub jq
assert_eq "args unreadable: marker still written" silver-plan "$(jq -r .skill "$MARKER")"
rm -f "$MARKER"
mkdir -p "$MARKER.tmp"
tl_run_hook "$HOOK" "$(tool_json Agent "")"
rmdir "$MARKER.tmp"
assert_eq "marker cannot be written: spawn still allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "marker cannot be written: none created" "$MARKER"
orch_stub_failing jq '.next_worker_template'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub jq
assert_eq "template unreadable in the denial: still denied" deny "$(decision)"
assert_contains "template unreadable in the denial: generic worker template" "$(reason)" "(WORKER.md)"
unset SB_ORCHESTRATOR_PARENT

# Worker-mode enforcement paths with unreadable inputs.
export SB_ORCHESTRATOR_WORKER=1
write_directive silver-plan PLAN
jq '.state.state_file="x"' "$PROJ/.silver-bullet.json" >"$TL_TMP/cfg.json" && cp "$TL_TMP/cfg.json" "$PROJ/.silver-bullet.json"
orch_stub_failing jq '.state.state_file'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub jq
assert_eq "config state path unreadable: default state used, edit denied" deny "$(decision)"
printf '{"sb_initiated":true}\n' >"$PROJ/.silver-bullet.json"
printf 'silver-plan\n' >"$STATE_REC"
orch_stub_failing cat '.silver-bullet/state'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub cat
assert_eq "state file unreadable: skill not seen, edit denied" deny "$(decision)"
rm -f "$STATE_REC"
orch_stub_failing cat 'orchestrator-directive.json'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub cat
assert_eq "directive unreadable: still denied" deny "$(decision)"
assert_contains "directive unreadable: reason falls back to the generic text" "$(reason)" "Invoke /silver-plan before Edit"
orch_stub_failing jq '.reason // "Orchestrator'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub jq
assert_eq "directive reason unreadable: still denied" deny "$(decision)"
# The directive disappears between the blocking check and the skill lookup.
write_directive silver-plan PLAN
real_jq="$(command -v jq)"
cat >"$TL_BIN/jq" <<STUB
#!/usr/bin/env bash
$real_jq "\$@"; rc=\$?
if [[ "\$1" == "-e" ]]; then rm -f "$DIRF"; fi
exit \$rc
STUB
chmod +x "$TL_BIN/jq"
hash -r
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
orch_unstub jq
assert_eq "directive vanishing mid-check: not denied" "none" "$(decision)"
assert_contains "directive vanishing mid-check: falls through to the workflow rule" "$TL_OUT" "edit without active workflow"
# Override without a directive on disk and without a project-root cache hit.
rm -f "$DIRF"
ov="$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"a"},prompt:"SB OVERRIDE: no directive pending"}')"
tl_run_hook "$HOOK" "$ov"
assert_eq "override with no directive: allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "override logged with an empty expected skill" "" "$(jq -r .expected_skill "$PROJ/.planning/orchestrator-override-log.jsonl" | tail -1)"
# Project-root resolvers unavailable.
tree="$(orch_stage_tree)"
cat >"$tree/lib/sb-project-gate.sh" <<'LIB'
sb_find_project_config_walk_only() { printf '%s/.silver-bullet.json' "$PWD"; }
sb_find_project_root_walk_only() { return 1; }
sb_find_project_root() { return 1; }
sb_config_marked_initiated() { return 0; }
LIB
rm -f "$PROJ/.planning/orchestrator-override-log.jsonl"
tl_run_stdin "$ov" bash "$tree/orchestrator-directive-guard.sh"
assert_eq "override without a resolvable root: allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "override logged under the working directory" 1 "$(wc -l <"$PROJ/.planning/orchestrator-override-log.jsonl" | tr -d ' ')"
SB_ORCHESTRATOR_EDIT_WITHOUT_WORKFLOW_BLOCK=1 tl_run_stdin "$(tool_json Write src/a.txt)" bash "$tree/orchestrator-directive-guard.sh"
assert_eq "edit without a resolvable project root: allowed even at threshold 1" "0|" "$TL_STATUS|$TL_OUT"

# No workspace config resolvable although every other lib is present: the guard stands down.
tree="$(orch_stage_tree)"
cat >"$tree/lib/sb-project-gate.sh" <<'LIB'
sb_find_project_config_walk_only() { return 1; }
sb_find_project_root_walk_only() { printf '%s' "$PWD"; }
sb_find_project_root() { printf '%s' "$PWD"; }
sb_config_marked_initiated() { return 0; }
LIB
reset
rm -f "$PROJ/.planning/workflows/"*.md
SB_ORCHESTRATOR_EDIT_WITHOUT_WORKFLOW_BLOCK=1 tl_run_stdin "$(tool_json Write src/a.txt)" bash "$tree/orchestrator-directive-guard.sh"
assert_eq "no workspace config: silent even at threshold 1" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "no workspace config: counter untouched" "$COUNTER"

# Edit-without-workflow counter failures.
reset
rm -f "$PROJ/.planning/workflows/"*.md
orch_stub_failing cat 'edit-without-workflow.count'
printf '4' >"$COUNTER"
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
orch_unstub cat
assert_contains "unreadable counter restarts at one" "$TL_OUT" "(1/5 before block)"
rm -rf "$COUNTER"
mkdir -p "$COUNTER"
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)" 2>/dev/null
assert_eq "counter path blocked: edit still allowed (first warning)" "0" "$TL_STATUS"
touch "$PROJ/.planning/workflows/WF.md"
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
assert_eq "active workflow with an undeletable counter: allowed" "0|" "$TL_STATUS|$TL_OUT"
rm -rf "$COUNTER" "$PROJ/.planning/workflows/WF.md"


tl_results
