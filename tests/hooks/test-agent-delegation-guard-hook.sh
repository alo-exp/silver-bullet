#!/usr/bin/env bash
# End-to-end tests for hooks/agent-delegation-guard.sh, the progress surface it embeds
# (hooks/agent-delegation-progress-surface.sh) and hooks/lib/agent-delegation-state.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/agent-delegation-guard.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_GUARD SB_AGENT_CERT_RUN SILVER_BULLET_PROJECT_ROOT
# shellcheck source=../../hooks/lib/agent-delegation-state.sh
source "$TL_REPO_ROOT/hooks/lib/agent-delegation-state.sh"

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/src" "$PROJ/docs" "$PROJ/hooks" "$PROJ/.planning/agent-codex/T1"
: >"$PROJ/src/owned.txt"
: >"$PROJ/docs/free.md"
LOG="$PROJ/.planning/agent-codex/T1/delegate.log"
STATE_FILE="$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
AUDIT_LOG="$SB_RUNTIME_STATE_DIR/hook-audit.jsonl"

edit_json() { # edit_json TOOL PATH [event]
  jq -cn --arg t "$1" --arg p "$2" --arg e "${3:-PreToolUse}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{file_path:$p}}'
}

activate() {
  sb_agent_delegation_activate codex T1 "$PROJ" "[\"$PROJ/src\",\"\",\"$PROJ/missing/../x\"]" "$LOG"
}

cd "$PROJ"

echo "=== guard: early exits ==="
# Partially installed plugin (no hooks/lib): the guard fails open silently.
staged="$(orch_stage_hook agent-delegation-guard.sh)"
activate
tl_run_stdin "$(edit_json Edit "$PROJ/src/owned.txt")" bash "$staged"
assert_eq "staged guard without lib exits 0" 0 "$TL_STATUS"
assert_eq "staged guard without lib prints nothing" "" "$TL_OUT"

# Outside an SB workspace nothing is enforced.
mkdir -p "$TL_TMP/plain/.git"
( cd "$TL_TMP/plain" && tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "non-SB workspace: allow silently" "0|" "$(cat "$TL_TMP/plain.out")"

SB_AGENT_DELEGATE_V2=0 tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "V2 rollback (SB_AGENT_DELEGATE_V2=0) disables guard" "0|" "$TL_STATUS|$TL_OUT"

sb_agent_delegation_deactivate
tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "no active delegation: allow" "0|" "$TL_STATUS|$TL_OUT"
activate

tl_run_hook "$HOOK" ""
assert_eq "empty stdin: allow" "0|" "$TL_STATUS|$TL_OUT"

SB_AGENT_CERT_RUN=1 tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "cert run bypass: allow" "0|" "$TL_STATUS|$TL_OUT"

tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt" PostToolUse)"
assert_eq "PostToolUse event ignored" "0|" "$TL_STATUS|$TL_OUT"

tl_run_hook "$HOOK" "$(edit_json Read "$PROJ/src/owned.txt")"
assert_eq "read-only tool ignored" "0|" "$TL_STATUS|$TL_OUT"

tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{}}'
assert_eq "Write without a path ignored" "0|" "$TL_STATUS|$TL_OUT"

tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/docs/free.md")"
assert_eq "path outside ownership scope allowed" "0|" "$TL_STATUS|$TL_OUT"

tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/.planning/agent-codex/T1/brief.md")"
assert_eq "own evidence dir always allowed" "0|" "$TL_STATUS|$TL_OUT"

echo "=== guard: block tier (claude/codex parents) ==="
: >"$SB_RUNTIME_STATE_DIR/hook-audit-enabled"
tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "scoped edit: exit 0 with JSON decision" 0 "$TL_STATUS"
assert_eq "scoped edit denied" "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"
assert_contains "deny reason cites AF-AGENT-DELEGATE" "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$TL_OUT")" "AF-AGENT-DELEGATE"
assert_contains "deny decision audited" "$(cat "$AUDIT_LOG")" '"decision":"deny"'

tl_run_hook "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{path:"src/owned.txt"}}')"
assert_eq "apply_patch with relative tool_input.path denied" "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"

tl_run_hook "$HOOK" "$(edit_json MultiEdit "$PROJ/src/new-file.txt")"
assert_eq "new file inside scope denied" "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"

tl_run_hook "$HOOK" "$(edit_json Write "$PROJ/hooks/repair.sh")"
assert_eq "harness repair path under hooks/ allowed" "0|" "$TL_STATUS|$TL_OUT"

echo "=== guard: advise tier (cursor parent) ==="
printf 'line-%s\n' 1 2 3 4 5 6 7 8 9 >"$LOG"
printf 'token=supersecret123\n' >>"$LOG"
rm -f "$AUDIT_LOG"
SILVER_BULLET_RUNTIME=cursor tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$TL_OUT")"
assert_eq "cursor parent: no deny decision" "null" "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"
assert_contains "cursor advise names delegation" "$ctx" "Active external-agent delegation"
assert_contains "cursor advise includes progress header" "$ctx" "[SB delegation active] host=codex task_id=T1"
assert_contains "progress shows recent log lines" "$ctx" "line-3"
assert_not_contains "progress keeps only the last 8 log lines" "$ctx" "line-2"
assert_contains "progress redacts secrets" "$ctx" "token=[REDACTED]"
assert_not_contains "secret value never surfaced" "$ctx" "supersecret123"
assert_contains "advise decision audited" "$(cat "$AUDIT_LOG")" '"decision":"advise"'

echo "=== guard: jq unavailable ==="
nojq="$(tl_path_without jq)"
PATH="$nojq" tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "without jq the guard cannot resolve paths and fails open" "0|" "$TL_STATUS|$TL_OUT"

echo "=== guard: malformed and degenerate input ==="
activate
tl_run_hook "$HOOK" 'this is not json'
assert_eq "invalid JSON input: allow" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":"just-a-string"}'
assert_eq "tool_input that is not an object: allow" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/no/such/dir/f.txt")"
assert_eq "target under a missing directory is not scoped: allow" "0|" "$TL_STATUS|$TL_OUT"
# stdin is a directory: cat fails, the guard sees no input and allows.
status=0
out="$(bash "$TL_REPO_ROOT/$HOOK" <"$TL_TMP")" || status=$?
assert_eq "unreadable stdin: allow" "0|" "$status|$out"

echo "=== guard: progress surface missing ==="
staged_lib="$(orch_stage_hook agent-delegation-guard.sh with-lib)"
tl_run_stdin "$(edit_json Edit "$PROJ/src/owned.txt")" bash "$staged_lib"
assert_eq "no progress surface file: still denies" "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"

echo "=== guard: jq-less hosts ==="
# Without jq from the start the guard cannot read a target path and allows.
for ev in '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"x"}}' \
          '{"hook_event_name":"PostToolUse","tool_name":"Edit"}' \
          '{"hook_event_name":"PreToolUse","tool_name":"Read"}' \
          '{"tool_name":"Edit"}'; do
  PATH="$nojq" tl_run_hook "$HOOK" "$ev"
  assert_eq "no jq, event $(printf '%s' "$ev" | cut -c1-40): allow" "0|" "$TL_STATUS|$TL_OUT"
done

# jq present for the path lookup and then gone: the block tier falls back to a stderr
# message and exit 2. The stub jq removes itself after extracting the target path.
real_jq="$(command -v jq)"
stubdir="$TL_TMP/selfdel"
mkdir -p "$stubdir"
cat >"$stubdir/jq" <<STUB
#!/usr/bin/env bash
if [[ "\$*" == *tool_input.file_path* ]]; then
  "$real_jq" "\$@"; rc=\$?
  rm -f "\$0"
  exit \$rc
fi
exec "$real_jq" "\$@"
STUB
chmod +x "$stubdir/jq"
activate
PATH="$stubdir:$nojq" tl_run_hook "$HOOK" "$(edit_json Edit "$PROJ/src/owned.txt")"
assert_eq "block tier without jq exits 2" 2 "$TL_STATUS"
assert_contains "block tier without jq explains on stderr" "$TL_ERR" "AF-AGENT-DELEGATE"
assert_eq "block tier without jq prints no JSON" "" "$TL_OUT"

echo "=== guard: jq-less field extraction (sb_adg_hook_field) ==="
# The hook runs its main flow on source, so load just the function definition.
eval "$(sed -n '/^sb_adg_hook_field()/,/^}/p' "$TL_REPO_ROOT/$HOOK")"
_sb_adg_have_jq=false
pre='{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"x"}}'
assert_eq "no-jq event name: PreToolUse recognised" "PreToolUse" "$(sb_adg_hook_field "$pre" hook_event_name dflt)"
assert_eq "no-jq event name: other event falls back to default" "dflt" "$(sb_adg_hook_field '{"hook_event_name":"PostToolUse"}' hook_event_name dflt)"
assert_eq "no-jq tool_name is extracted" "Edit" "$(sb_adg_hook_field "$pre" tool_name dflt)"
assert_eq "no-jq tool_name missing falls back to default" "dflt" "$(sb_adg_hook_field '{"x":1}' tool_name dflt)"
assert_eq "no-jq unknown field returns default" "dflt" "$(sb_adg_hook_field "$pre" other dflt)"

tl_results
