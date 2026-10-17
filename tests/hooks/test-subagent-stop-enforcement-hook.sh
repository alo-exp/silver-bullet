#!/usr/bin/env bash
# End-to-end tests for hooks/subagent-stop-enforcement.sh (section 3c subagent completion gate).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/subagent-stop-enforcement.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_PROJECT_ROOT SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED \
  SILVER_BULLET_STATE_FILE SB_ORCHESTRATOR_WORKER_MARKER_TTL_SECONDS

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ" '{"sb_initiated":true}'
cd "$PROJ"
NOJQ="$(tl_path_without jq)"
STATE_REC="$SB_RUNTIME_STATE_DIR/state"
SPAWNS="$SB_RUNTIME_STATE_DIR/subagent-spawns.jsonl"
PENDING="$SB_RUNTIME_STATE_DIR/pending-completion-audit.json"
ROUTING="$SB_RUNTIME_STATE_DIR/e2e-matrix-routing-row"

ev() { jq -cn --arg e "$1" --arg t "${2:-}" --arg s "${3:-}" --arg c "${4:-}" \
  '{hook_event_name:$e, tool_name:$t, tool_input:({skill:$s, command:$c, description:"do the thing"})}'; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo bad; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT" 2>/dev/null || true; }
reset() { rm -f "$SPAWNS" "$PENDING" "$STATE_REC" "$ROUTING" "$SB_RUNTIME_STATE_DIR/trivial"; }
mark_pending() { printf '{"pending":true,"task_returned_at":"2024-01-01T00:00:00Z"}\n' >"$PENDING"; }

echo "=== early exits ==="
reset
PATH="$NOJQ" tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "no jq: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" ""
assert_eq "empty input: silent" "0|" "$TL_STATUS|$TL_OUT"
SB_AGENT_CERT_RUN=1 tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_eq "cert run bypass: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "cert run bypass: nothing recorded" "$PENDING"
mkdir -p "$TL_TMP/plain/.git"
( cd "$TL_TMP/plain" && tl_run_hook "$HOOK" "$(ev PostToolUse Task)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "outside an SB project: silent" "0|" "$(cat "$TL_TMP/plain.out")"
: >"$ROUTING"
tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_eq "e2e matrix routing row: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "e2e matrix routing row: nothing recorded" "$PENDING"
rm -f "$ROUTING"
tl_run_hook "$HOOK" '{"tool_name":"Read"}'
assert_eq "missing event name defaults to Stop; nothing spawned" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" 'not json'
assert_eq "invalid JSON defaults to Stop; nothing spawned" "0|" "$TL_STATUS|$TL_OUT"

echo "=== refusing project gate ==="
tree="$(orch_stage_tree)"
printf '%s\n' 'sb_project_gate_or_exit() { return 1; }' >"$tree/lib/sb-project-gate.sh"
reset
tl_run_stdin "$(ev PostToolUse Task)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "refusing project gate: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "refusing project gate: no pending marker" "$PENDING"

echo "=== PreToolUse: Task spawn is recorded ==="
reset
for t in Task Subagent Agent; do
  rm -f "$SPAWNS"
  tl_run_hook "$HOOK" "$(ev PreToolUse "$t")"
  assert_eq "$t spawn allowed" "0|" "$TL_STATUS|$TL_OUT"
  assert_eq "$t spawn recorded" 1 "$(wc -l <"$SPAWNS" | tr -d ' ')"
done
assert_contains "spawn log keeps a preview" "$(cat "$SPAWNS")" "do the thing"
rm -f "$SPAWNS"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev PreToolUse Task)"
assert_eq "worker spawns are not recorded" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "worker spawn: no log" "$SPAWNS"

echo "=== PreToolUse: pending audit blocks the next action ==="
mark_pending
for t in Task Edit Write MultiEdit Shell Bash; do
  tl_run_hook "$HOOK" "$(ev PreToolUse "$t" "" "ls")"
  assert_eq "$t denied while the audit is pending" deny "$(decision)"
done
assert_contains "denial points at the audit skill" "$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$TL_OUT")" "/sb:completion-audit"
SB_KAY_HOOK_BRIDGE_INVOKED=1 tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "bridge mode: exit 2" 2 "$TL_STATUS"
assert_contains "bridge mode: reason on stderr" "$TL_ERR" "Subagent completion gate"
assert_eq "bridge mode: deny JSON on stdout" deny "$(decision)"
tl_run_hook "$HOOK" "$(ev PreToolUse Read)"
assert_eq "read-only tool is not gated" "0|" "$TL_STATUS|$TL_OUT"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "worker edits are not gated" "0|" "$TL_STATUS|$TL_OUT"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev PreToolUse Task)"
assert_eq "worker spawns are not gated" "0|" "$TL_STATUS|$TL_OUT"
printf 'silver-completion-audit\n' >"$STATE_REC"
tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "audit recorded: edits allowed" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$STATE_REC"
printf 'silver-completion-audit\n' >"$TL_TMP/state-target"
ln -s "$TL_TMP/state-target" "$STATE_REC"
tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "a symlinked state file is not trusted" deny "$(decision)"
rm -f "$STATE_REC"
rm -f "$PENDING"
tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "nothing pending: edits allowed" "0|" "$TL_STATUS|$TL_OUT"
printf '{"pending":false}\n' >"$PENDING"
tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "pending=false: edits allowed" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$PENDING"
mark_pending
SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/alt-state" tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "state file override honoured (not recorded there)" deny "$(decision)"
printf 'silver-completion-audit\n' >"$SB_RUNTIME_STATE_DIR/alt-state"
SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/alt-state" tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
assert_eq "state file override honoured (recorded there)" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$SB_RUNTIME_STATE_DIR/alt-state"

echo "=== Skill invocation of the audit clears the gate ==="
for when in PreToolUse PostToolUse; do
  for sk in silver-completion-audit sb:completion-audit completion-audit; do
    mark_pending
    printf '{"spawned_at":"x"}\n' >"$SPAWNS"
    tl_run_hook "$HOOK" "$(ev "$when" Skill "$sk")"
    assert_eq "$when $sk: silent" "0|" "$TL_STATUS|$TL_OUT"
    assert_file_absent "$when $sk: pending cleared" "$PENDING"
    assert_file_absent "$when $sk: spawn log cleared" "$SPAWNS"
  done
  mark_pending
  tl_run_hook "$HOOK" "$(ev "$when" Skill silver-plan)"
  assert_file_exists "$when other skill leaves the pending marker" "$PENDING"
  rm -f "$PENDING"
done
mark_pending
tl_run_hook "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{name:"completion-audit"}}')"
assert_file_absent "skill named via tool_input.name clears the gate" "$PENDING"

echo "=== PostToolUse: a returning Task worker requires an audit ==="
reset
for t in Task Subagent Agent; do
  rm -f "$PENDING"
  tl_run_hook "$HOOK" "$(ev PostToolUse "$t")"
  assert_contains "$t return: reminder" "$(ctx)" "invoke /sb:completion-audit"
  assert_eq "$t return: pending marker written" true "$(jq -r .pending "$PENDING")"
done
assert_eq "reminder names the hook event" PostToolUse "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
rm -f "$PENDING"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_eq "worker return: nothing to audit" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "worker return: no pending marker" "$PENDING"
tl_run_hook "$HOOK" "$(ev PostToolUse Edit)"
assert_eq "other tool: ignored" "0|" "$TL_STATUS|$TL_OUT"

echo "=== UserPromptSubmit: pending audit blocks the reply ==="
reset
tl_run_hook "$HOOK" "$(ev UserPromptSubmit)"
assert_eq "no pending audit: silent" "0|" "$TL_STATUS|$TL_OUT"
mark_pending
rm -f "$SB_RUNTIME_STATE_DIR"/ups-coalesce-*
tl_run_hook "$HOOK" "$(ev UserPromptSubmit)"
assert_contains "pending audit: context injected" "$(ctx)" "Subagent completion gate"
assert_eq "output names UserPromptSubmit" UserPromptSubmit "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
tl_run_hook "$HOOK" "$(ev UserPromptSubmit)"
assert_eq "an identical notice within the same prompt turn is coalesced (no context repeated)" "" "$(ctx)"
# The Cursor bridge maps beforeSubmitPrompt to UserPromptSubmit; the raw name is not handled here.
tl_run_hook "$HOOK" "$(ev beforeSubmitPrompt)"
assert_eq "raw beforeSubmitPrompt is a no-op" "0|" "$TL_STATUS|$TL_OUT"
# Without the coalescing lib the notice is emitted directly.
stg="$TL_TMP/stg-nocoalesce"
mkdir -p "$stg/hooks"
cp "$TL_REPO_ROOT/hooks/subagent-stop-enforcement.sh" "$stg/hooks/"
cp -R "$TL_REPO_ROOT/hooks/lib" "$stg/hooks/lib"
rm -f "$stg/hooks/lib/ups-coalesce.sh"
rm -f "$SB_RUNTIME_STATE_DIR"/ups-coalesce-*
tl_run_stdin "$(ev UserPromptSubmit)" bash "$stg/hooks/subagent-stop-enforcement.sh"
assert_contains "no coalescing lib: context still injected" "$(ctx)" "Subagent completion gate"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev UserPromptSubmit)"
assert_eq "worker prompt: silent" "0|" "$TL_STATUS|$TL_OUT"

echo "=== Stop: workers ran, audit not recorded ==="
reset
tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "no spawns: stop allowed" "0|" "$TL_STATUS|$TL_OUT"
printf '{"spawned_at":"x"}\n' >"$SPAWNS"
tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "spawns without audit: stop blocked" block "$(decision)"
assert_contains "block reason" "$(jq -r .reason <<<"$TL_OUT")" "Task workers ran this session"
: >"$SPAWNS"
tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "empty spawn log: stop allowed" "0|" "$TL_STATUS|$TL_OUT"
printf '{"spawned_at":"x"}\n' >"$SPAWNS"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "worker stop: allowed" "0|" "$TL_STATUS|$TL_OUT"
: >"$SB_RUNTIME_STATE_DIR/trivial"
tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "legacy trivial marker bypasses the gate" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$SB_RUNTIME_STATE_DIR/trivial"
mark_pending
printf 'silver-completion-audit\n' >"$STATE_REC"
tl_run_hook "$HOOK" "$(ev Stop)"
assert_eq "audit recorded: stop allowed" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "audit recorded: spawn log cleared" "$SPAWNS"
assert_file_absent "audit recorded: pending marker cleared" "$PENDING"
tl_run_hook "$HOOK" "$(ev SessionEnd)"
assert_eq "unrelated events fall through" "0|" "$TL_STATUS|$TL_OUT"

echo "=== failure paths ==="
reset
status=0
out="$(bash "$TL_REPO_ROOT/$HOOK" <"$TL_TMP")" || status=$?
assert_eq "unreadable stdin: silent" "0|" "$status|$out"
# Plugin without its lib directory: the project gate is missing, so the hook fails open.
staged="$(orch_stage_hook subagent-stop-enforcement.sh)"
tl_run_stdin "$(ev PostToolUse Task)" bash "$staged"
assert_eq "no lib directory: fails open" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "no lib directory: nothing recorded" "$PENDING"
# Found from a nested working directory.
mkdir -p "$PROJ/a/b"
( cd "$PROJ/a/b" && tl_run_hook "$HOOK" "$(ev PostToolUse Task)" && printf '%s' "$TL_OUT" ) >"$TL_TMP/nested.out"
assert_contains "nested directory: project found, reminder emitted" "$(cat "$TL_TMP/nested.out")" "completion-audit"
reset
# State directory that cannot be created: still reminds the parent.
notdir="$TL_TMP/regular-file"
: >"$notdir"
SB_RUNTIME_STATE_DIR="$notdir/state" tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_contains "uncreatable state dir: reminder still emitted" "$(ctx)" "completion-audit"
# Unreadable state file: treated as no audit recorded.
reset
mark_pending
printf 'silver-completion-audit\n' >"$STATE_REC"
orch_stub_failing cat '.silver-bullet/state'
tl_run_hook "$HOOK" "$(ev PreToolUse Edit)"
orch_unstub cat
assert_eq "unreadable state file: audit not seen, edit denied" deny "$(decision)"
# jq failing on individual extractions.
reset
orch_stub_failing jq '.tool_name'
tl_run_hook "$HOOK" "$(ev PreToolUse Task)"
assert_eq "tool name unreadable (PreToolUse): ignored" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_eq "tool name unreadable (PostToolUse): ignored" "0|" "$TL_STATUS|$TL_OUT"
orch_unstub jq
orch_stub_failing jq 'tool_input // {}'
tl_run_hook "$HOOK" "$(ev PreToolUse Task)"
assert_eq "spawn preview unreadable: spawn still recorded" 1 "$(wc -l <"$SPAWNS" | tr -d ' ')"
assert_contains "spawn recorded with an empty preview" "$(cat "$SPAWNS")" "spawned_at"
tl_run_hook "$HOOK" "$(ev PostToolUse Task)"
assert_eq "return preview unreadable: audit still required" true "$(jq -r .pending "$PENDING")"
orch_unstub jq
reset
mark_pending
orch_stub_failing jq '.tool_input.skill'
tl_run_hook "$HOOK" "$(ev PreToolUse Skill silver-completion-audit)"
assert_eq "skill name unreadable (PreToolUse): gate stays" "0|" "$TL_STATUS|$TL_OUT"
assert_file_exists "skill name unreadable (PreToolUse): pending kept" "$PENDING"
tl_run_hook "$HOOK" "$(ev PostToolUse Skill silver-completion-audit)"
assert_file_exists "skill name unreadable (PostToolUse): pending kept" "$PENDING"
orch_unstub jq
# Without the tool-input helpers the tool name cannot be read: the hook ignores the call.
tree="$(orch_stage_tree)"
rm -f "$tree/lib/tool-input.sh"
mark_pending
tl_run_stdin "$(ev PreToolUse Edit)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "no tool-input helper (PreToolUse): ignored" "0|" "$TL_STATUS|$TL_OUT"
tl_run_stdin "$(ev PostToolUse Task)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "no tool-input helper (PostToolUse): ignored" "0|" "$TL_STATUS|$TL_OUT"
# The clearing helpers are unavailable: the hook still exits cleanly.
tree="$(orch_stage_tree)"
printf '%s\n' 'sb_site_session_subagents_spawned() { return 0; }' >"$tree/lib/site-session.sh"
mark_pending
tl_run_stdin "$(ev PreToolUse Skill silver-completion-audit)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "no clearing helpers (PreToolUse skill): clean exit" "0|" "$TL_STATUS|$TL_OUT"
tl_run_stdin "$(ev PostToolUse Skill silver-completion-audit)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "no clearing helpers (PostToolUse skill): clean exit" "0|" "$TL_STATUS|$TL_OUT"
printf 'silver-completion-audit\n' >"$STATE_REC"
tl_run_stdin "$(ev Stop)" bash "$tree/subagent-stop-enforcement.sh"
assert_eq "no clearing helpers (Stop with audit recorded): clean exit" "0|" "$TL_STATUS|$TL_OUT"

tl_results
