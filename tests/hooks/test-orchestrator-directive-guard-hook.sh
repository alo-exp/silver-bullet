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
NOJQ="$(tl_path_without jq)"
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

echo "=== early exits ==="
staged="$(orch_stage_hook orchestrator-directive-guard.sh)"
tl_run_stdin "$(tool_json Edit src/a.txt)" bash "$staged"
assert_eq "partially installed plugin: allow silently" "0|" "$TL_STATUS|$TL_OUT"
mkdir -p "$TL_TMP/plain/.git"
( cd "$TL_TMP/plain" && SB_ORCHESTRATOR_PARENT=1 tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "non-SB workspace: allow" "0|" "$(cat "$TL_TMP/plain.out")"
SB_AGENT_CERT_RUN=1 SB_ORCHESTRATOR_PARENT=1 tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "cert run bypass: allow" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" ""
assert_eq "empty input: allow" "0|" "$TL_STATUS|$TL_OUT"
SB_ORCHESTRATOR_PARENT=1 tl_run_hook "$HOOK" "$(tl_hook_json PostToolUse Edit src/a.txt)"
assert_eq "PostToolUse ignored" "0|" "$TL_STATUS|$TL_OUT"
SB_ORCHESTRATOR_PARENT=1 tl_run_hook "$HOOK" 'not json at all'
assert_eq "unparsable payload has no tool name: parent mode fails closed" deny "$(decision)"

echo "=== parent mode: skills ==="
reset
export SB_ORCHESTRATOR_PARENT=1
tl_run_hook "$HOOK" "$(tool_json Skill silver)"
assert_eq "router skill allowed for the parent" "0|" "$TL_STATUS|$TL_OUT"
write_directive silver-plan PLAN
tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_eq "flow atom denied for the parent" deny "$(decision)"
assert_contains "denial names the template" "$(reason)" "template PLAN.md"
assert_contains "denial names the expected atom" "$(reason)" "flow atom silver-plan"
assert_contains "denial names the requested skill" "$(reason)" "Do not invoke /silver-plan directly"
rm -f "$DIRF"
tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_contains "no directive: generic worker template" "$(reason)" "template WORKER.md"
write_directive silver-plan ""
tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_contains "directive without template: generic worker template" "$(reason)" "template WORKER.md"
SB_KAY_HOOK_BRIDGE_INVOKED=1 tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_eq "bridge mode: exits 2 on deny" 2 "$TL_STATUS"
assert_eq "bridge mode: deny JSON still printed" deny "$(decision)"

echo "=== parent mode: delegation and tools ==="
reset
write_directive silver-plan PLAN true "the intent"
for t in Task Subagent Agent spawn_agent multi_agent_v1.spawn_agent; do
  rm -f "$MARKER"
  tl_run_hook "$HOOK" "$(tool_json "$t" "")"
  assert_eq "$t: delegation allowed" "0|" "$TL_STATUS|$TL_OUT"
  assert_eq "$t: worker marker written" silver-plan "$(jq -r .skill "$MARKER")"
done
assert_eq "marker carries the template" PLAN "$(jq -r .template "$MARKER")"
assert_eq "marker carries the directive args" "the intent" "$(jq -r .args "$MARKER")"
rm -f "$DIRF" "$MARKER"
tl_run_hook "$HOOK" "$(tool_json Agent "")"
assert_eq "no directive: ad-hoc worker marker" ad-hoc "$(jq -r .skill "$MARKER")"
for t in Read Grep Glob WebSearch; do
  tl_run_hook "$HOOK" "$(tool_json "$t" "x")"
  assert_eq "$t allowed for the parent" "0|" "$TL_STATUS|$TL_OUT"
done
write_directive silver-plan PLAN
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "Edit denied for the parent" deny "$(decision)"
assert_contains "denial offers the host spawn tool" "$(reason)" "Spawn Agent (Claude subagent) (PLAN.md) for /silver-plan"
SILVER_BULLET_RUNTIME=codex tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
assert_contains "denial follows the host" "$(reason)" "spawn_agent (multi_agent_v1.spawn_agent)"
rm -f "$DIRF"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_contains "no directive: generic next flow" "$(reason)" "for /next flow"
assert_contains "no directive: generic worker template" "$(reason)" "(WORKER.md)"
tl_run_hook "$HOOK" "$(tool_json Bash 'git status')"
assert_eq "read-only Bash allowed for the parent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json exec_command 'git log --oneline')"
assert_eq "read-only exec_command allowed" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json Bash 'rm -rf build')"
assert_eq "mutating Bash denied for the parent" deny "$(decision)"
tl_run_hook "$HOOK" "$(tool_json Shell 'touch x')"
assert_eq "mutating Shell denied for the parent" deny "$(decision)"
tl_run_hook "$HOOK" "$(tool_json Bash 'silver-bullet invoke-skill silver')"
assert_eq "router invoke-skill adapter allowed" "0|" "$TL_STATUS|$TL_OUT"
printf '{"sb_initiated":false}\n' >"$PROJ/.silver-bullet.json"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "project not initiated yet: allow" "0|" "$TL_STATUS|$TL_OUT"
printf '{"sb_initiated":true}\n' >"$PROJ/.silver-bullet.json"

echo "=== parent mode: no jq ==="
write_directive silver-plan PLAN
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-plan"}}'
assert_eq "no jq: skill denial exits 2" 2 "$TL_STATUS"
assert_contains "no jq: reason on stderr" "$TL_ERR" "ORCHESTRATOR PARENT"
assert_eq "no jq: no JSON on stdout" "" "$TL_OUT"
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver"}}'
assert_eq "no jq: router skill still allowed" "0|" "$TL_STATUS|$TL_OUT"
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
assert_eq "no jq: other events ignored" "0|" "$TL_STATUS|$TL_OUT"
PATH="$NOJQ" tl_run_hook "$HOOK" '{"tool_name":"Read","tool_input":{"file_path":"a"}}'
assert_eq "no jq: missing event name defaults to PreToolUse; Read allowed" "0|" "$TL_STATUS|$TL_OUT"
# Without jq the project cannot be proven initiated, so implementation tools fail open.
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"a"}}'
assert_eq "no jq: Edit fails open" "0|" "$TL_STATUS|$TL_OUT"
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf x"}}'
assert_eq "no jq: Bash fails open" "0|" "$TL_STATUS|$TL_OUT"
# A jq that exists but is broken: the denial transport fails with a non-blocking exit 1.
tl_stub jq 'exit 1'
hash -r
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-plan"}}'
assert_eq "broken jq: no denial JSON is emitted and the exit is non-blocking" "1|" "$TL_STATUS|$TL_OUT"
rm -f "$TL_BIN/jq"
hash -r

echo "=== worker mode: skill invocation clears the directive ==="
unset SB_ORCHESTRATOR_PARENT
export SB_ORCHESTRATOR_WORKER=1
reset
tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_eq "no directive: skill allowed" "0|" "$TL_STATUS|$TL_OUT"
write_directive silver-plan PLAN
tl_run_hook "$HOOK" "$(tool_json Skill silver-verify)"
assert_eq "other skill: allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_file_exists "other skill leaves the directive" "$DIRF"
tl_run_hook "$HOOK" "$(tool_json Skill sb:plan)"
assert_file_exists "unnormalised alias does not clear the directive" "$DIRF"
tl_run_hook "$HOOK" "$(tool_json Skill silver-plan)"
assert_file_absent "expected skill clears the directive" "$DIRF"
write_directive silver-plan PLAN
BASH_ENV="$(orch_bash_env_wrapper "$TL_REPO_ROOT/hooks/lib/skill-discovery.sh")" tl_run_hook "$HOOK" "$(tool_json Skill sb:plan)"
assert_file_absent "canonical alias clears the directive when the discovery lib is loaded" "$DIRF"

echo "=== worker mode: directive enforcement ==="
reset
write_directive silver-plan PLAN
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "blocking directive denies Edit" deny "$(decision)"
assert_contains "denial names the expected skill" "$(reason)" "Invoke /silver-plan before Edit"
assert_contains "denial includes the directive reason" "$(reason)" "queued by test"
assert_contains "denial explains the override" "$(reason)" "SB OVERRIDE: <reason>"
tl_run_hook "$HOOK" "$(tool_json Read src/a.txt)"
assert_eq "read-only tools are not gated" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json Bash 'rm x')"
assert_eq "worker Bash passes without a recorded skill" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json apply_patch src/a.txt)"
assert_eq "apply_patch is gated" deny "$(decision)"
printf 'silver-plan\n' >"$STATE_REC"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "skill recorded: Edit allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "recorded skill consumes the directive" "$DIRF"
# Config-provided state file (with ~ expansion) and the fallback for unscoped paths.
write_directive silver-plan PLAN
rm -f "$STATE_REC"
unset SILVER_BULLET_STATE_FILE
mkdir -p "$SB_RUNTIME_HOME_ROOT/.silver-bullet"
printf 'silver-plan\n' >"$SB_RUNTIME_HOME_ROOT/.silver-bullet/cfg-state"
jq '.state.state_file="~/.claude/.silver-bullet/cfg-state"' "$PROJ/.silver-bullet.json" >"$TL_TMP/cfg.json" && cp "$TL_TMP/cfg.json" "$PROJ/.silver-bullet.json"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "configured state file honoured" "0|" "$TL_STATUS|$TL_OUT"
write_directive silver-plan PLAN
jq '.state.state_file="/etc/not-scoped-state"' "$PROJ/.silver-bullet.json" >"$TL_TMP/cfg.json" && cp "$TL_TMP/cfg.json" "$PROJ/.silver-bullet.json"
printf 'silver-plan\n' >"$SB_RUNTIME_STATE_DIR/state"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "unscoped configured state falls back to the runtime state file" "0|" "$TL_STATUS|$TL_OUT"
write_directive silver-plan PLAN
rm -f "$SB_RUNTIME_STATE_DIR/state"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "fallback state file empty: denied" deny "$(decision)"
printf '{"sb_initiated":true}\n' >"$PROJ/.silver-bullet.json"
export SILVER_BULLET_STATE_FILE="$STATE_REC"
# Non-blocking and empty directives do not gate.
write_directive silver-plan PLAN false
touch "$PROJ/.planning/workflows/WF.md"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "non-blocking directive: allowed" "0|" "$TL_STATUS|$TL_OUT"
write_directive "" PLAN true
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "blocking directive without a skill: allowed" "0|" "$TL_STATUS|$TL_OUT"
# A queue that belongs to another project does not gate here.
write_directive silver-plan PLAN
orch_write_state '{"current_flow":"silver-plan","repo_root":"/another/project"}'
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "directive of another project: allowed" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$(orch_state_file)" "$PROJ/.planning/workflows/WF.md"

echo "=== worker mode: SB OVERRIDE ==="
reset
write_directive silver-plan PLAN
ov="$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"a"},prompt:"please SB OVERRIDE: hotfix in prod"}')"
tl_run_hook "$HOOK" "$ov"
assert_eq "override allows the edit" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "override clears the directive" "$DIRF"
log="$PROJ/.planning/orchestrator-override-log.jsonl"
assert_eq "override logged with its reason" "hotfix in prod" "$(jq -r .reason "$log")"
assert_eq "override logged with the skipped skill" silver-plan "$(jq -r .expected_skill "$log")"
write_directive silver-plan PLAN
np="$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"a"},prompt:"just edit it"}')"
tl_run_hook "$HOOK" "$np"
assert_eq "prompt without the marker does not bypass" deny "$(decision)"
reset
write_directive silver-plan PLAN
PATH="$NOJQ" tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"a"},"prompt":"SB OVERRIDE: because"}'
assert_eq "no jq: fails open before the override is evaluated" "0|" "$TL_STATUS|$TL_OUT"

echo "=== worker mode: edits without a workflow (P6) ==="
reset
rm -f "$PROJ/.planning/workflows/"*.md
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
assert_contains "first edit warns" "$TL_OUT" "edit without active workflow (1/5 before block)"
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
assert_eq "second edit is silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json Write src/a.txt)"
assert_contains "third edit warns" "$TL_OUT" "(3/5 before block)"
tl_run_hook "$HOOK" "$(tool_json MultiEdit src/a.txt)"
assert_eq "fourth edit is silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "fifth edit is blocked" deny "$(decision)"
assert_contains "block names the count" "$(reason)" "5 edits without an active composed workflow"
assert_eq "counter persisted" 5 "$(cat "$COUNTER")"
touch "$PROJ/.planning/workflows/WF.md"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "an active workflow allows edits" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "an active workflow resets the counter" "$COUNTER"
rm -f "$PROJ/.planning/workflows/WF.md"
SB_ORCHESTRATOR_EDIT_WITHOUT_WORKFLOW_BLOCK=1 tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_eq "threshold override blocks immediately" deny "$(decision)"
rm -f "$COUNTER"
tl_run_hook "$HOOK" "$(tool_json Bash 'echo hi')"
assert_eq "Bash is exempt from the workflow rule" "0|" "$TL_STATUS|$TL_OUT"
rm -rf "$PROJ/.planning/workflows"
ln -s "$TL_TMP" "$PROJ/.planning/workflows"
rm -f "$COUNTER"
tl_run_hook "$HOOK" "$(tool_json Edit src/a.txt)"
assert_contains "symlinked workflow dir counts as no workflow" "$TL_OUT" "(1/5 before block)"
rm -f "$PROJ/.planning/workflows"
mkdir -p "$PROJ/.planning/workflows"

echo "=== worker mode: unknown tools ==="
tl_run_hook "$HOOK" "$(tool_json WebFetch http://x)"
assert_eq "tools outside the edit set are ignored" "0|" "$TL_STATUS|$TL_OUT"

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
if [[ "\$1" == "-e" ]]; then rm -f "$DIRF"; fi
exec $real_jq "\$@"
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
tl_run_stdin "$(tool_json Write src/a.txt)" bash "$tree/orchestrator-directive-guard.sh"
assert_eq "edit without a resolvable project root: allowed" "0|" "$TL_STATUS|$TL_OUT"

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
