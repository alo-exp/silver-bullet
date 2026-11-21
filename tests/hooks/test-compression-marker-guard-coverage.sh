#!/usr/bin/env bash
# Behavior tests for hooks/compression-marker-guard.sh (PreToolUse marker deny)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_KAY_HOOK_BRIDGE_INVOKED

HOOK="hooks/compression-marker-guard.sh"
payload() { # tool field-json [event]
  jq -cn --arg t "$1" --argjson ti "$2" --arg e "${3:-PreToolUse}" '{hook_event_name:$e, tool_name:$t, tool_input:$ti}'
}
run() { tl_run_hook "$HOOK" "$1"; }
denied() { [[ "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null)" == deny ]]; }
expect_deny() {
  run "$2"
  if denied && [[ "$TL_STATUS" == 0 ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:160})"; fi
}
expect_allow() {
  run "$2"
  if [[ "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:160})"; fi
}

expect_deny "lean-ctx marker line in new_string" "$(payload Edit '{"file_path":"/p/a.md","new_string":"keep\n[lean-ctx: compressed 40%]\nhere"}')"
expect_deny "marker is matched case-insensitively" "$(payload Write '{"file_path":"/p/a.md","content":"x\n  [LEAN-CTX:abc] y"}')"
expect_deny "ellipsis marker" "$(payload Edit '{"file_path":"/p/a.md","new_string":"... [lean-ctx: truncated]"}')"
expect_deny "ctx_read plan header line" "$(payload Write '{"file_path":"/p/a.md","content":"intro\nfoo.plan.md [316L]\nbody"}')"
expect_deny "plan header with a path prefix" "$(payload Write '{"file_path":"/p/a.md","content":"docs/x.plan.md [12L]"}')"
expect_deny "MultiEdit nested edits array" "$(payload MultiEdit '{"file_path":"/p/a.md","edits":[{"old_string":"a","new_string":"b"},{"old_string":"c","new_string":"[lean-ctx: x]"}]}')"
expect_deny "apply_patch added line" "$(payload apply_patch '{"input":"*** Begin Patch\n+[lean-ctx: cached]\n*** End Patch"}')"
expect_deny "deeply nested content value" "$(payload Edit '{"a":{"b":[{"new_string":"[lean-ctx:"}]}}')"

# R2-27: documentation that merely mentions the marker, and removing a marker, stay possible
expect_allow "marker mentioned inside a sentence" "$(payload Write '{"file_path":"/p/a.md","content":"LeanCTX prefixes compressed reads with [lean-ctx: ...] markers."}')"
expect_allow "inline marker in new_string" "$(payload Edit '{"file_path":"/p/a.md","new_string":"keep [lean-ctx: compressed 40%] here"}')"
expect_allow "marker only in old_string (removing it)" "$(payload Edit '{"file_path":"/p/a.md","old_string":"... [lean-ctx: omitted 3 lines]","new_string":"restored line"}')"
expect_allow "patch removes a marker line" "$(payload apply_patch '{"input":"*** Begin Patch\n*** Update File: a.md\n-[lean-ctx: cached]\n+clean\n*** End Patch"}')"
expect_allow "a marker line under docs/ is documentation" "$(payload Write '{"file_path":"/p/docs/leanctx.md","content":"Example:\n[lean-ctx: omitted 3 lines]\n"}')"
expect_allow "Windows-style docs path" "$(payload Write '{"file_path":"C:\\p\\docs\\leanctx.md","content":"[lean-ctx: x]"}')"
mkdir -p "$TL_TMP/p"
printf 'already documents\n[lean-ctx: omitted]\n' >"$TL_TMP/p/known.md"
expect_allow "a file that already contains the marker may be edited" "$(payload Edit "$(jq -cn --arg f "$TL_TMP/p/known.md" '{file_path:$f,new_string:"[lean-ctx: more]"}')")"
printf 'clean\n' >"$TL_TMP/p/clean.md"
expect_deny "a clean existing file still refuses a pasted block" "$(payload Edit "$(jq -cn --arg f "$TL_TMP/p/clean.md" '{file_path:$f,new_string:"... [lean-ctx: omitted 3 lines]"}')")"
expect_deny "a pasted ctx_read block outside docs" "$(payload Write '{"file_path":"/p/src/a.md","content":"line 1\n... [lean-ctx: omitted 40 lines]\nline 50"}')"
expect_allow "clean edit" "$(payload Edit '{"file_path":"/p/a.md","old_string":"a","new_string":"b"}')"
expect_allow "similar-looking text is not a marker" "$(payload Write '{"file_path":"/p/a.md","content":"lean-ctx is a tool; see [docs] and plan.md [x]"}')"
expect_allow "plan header must be a whole line" "$(payload Write '{"file_path":"/p/a.md","content":"see .plan.md [316L] for details"}')"
expect_allow "non-string tool_input values ignored" "$(payload Edit '{"count":3,"flag":true,"none":null}')"
expect_allow "no tool_input at all" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Edit"}')"
expect_allow "Bash tool is not inspected" "$(payload Bash '{"command":"echo [lean-ctx: x]"}')"
expect_allow "Read tool is not inspected" "$(payload Read '{"file_path":"[lean-ctx: x]"}')"
expect_allow "PostToolUse event is ignored" "$(payload Edit '{"new_string":"[lean-ctx: x]"}' PostToolUse)"
expect_allow "missing event defaults to PreToolUse but clean payload allows" "$(jq -cn '{tool_name:"Edit", tool_input:{new_string:"ok"}}')"
expect_deny "missing event defaults to PreToolUse" "$(jq -cn '{tool_name:"Edit", tool_input:{new_string:"[lean-ctx: x]"}}')"
expect_allow "empty stdin" ""
expect_allow "unparsable stdin" "not json {"
expect_allow "unparsable payload that reaches the scanner (jq fails open)" "{\"tool_name\":\"Edit\""

# deny message content
run "$(payload Edit '{"new_string":"[lean-ctx: x]"}')"
reason="$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
assert_contains "reason explains the problem" "$reason" "Compression marker guard"
assert_contains "reason tells how to recover" "$reason" "ctx_read(raw=true)"
assert_eq "hook event name is PreToolUse" "PreToolUse" "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.hookEventName')"

# bridge invocation: deny JSON plus stderr reason and exit 2
tl_run_stdin "$(payload Edit '{"new_string":"[lean-ctx: x]"}')" env SB_KAY_HOOK_BRIDGE_INVOKED=1 bash "$TL_REPO_ROOT/$HOOK"
assert_eq "bridge deny exits 2" "2" "$TL_STATUS"
assert_contains "bridge deny prints reason on stderr" "$TL_ERR" "Compression marker guard"
assert_contains "bridge deny still prints JSON" "$TL_OUT" '"permissionDecision":"deny"'
tl_run_stdin "$(payload Edit '{"new_string":"clean"}')" env SB_KAY_HOOK_BRIDGE_INVOKED=1 bash "$TL_REPO_ROOT/$HOOK"
assert_eq "bridge env with clean payload exits 0" "0" "$TL_STATUS"

# environment failures are fail-open
tl_run_stdin "$(payload Edit '{"new_string":"[lean-ctx: x]"}')" env PATH="$(tl_path_without jq)" bash "$TL_REPO_ROOT/$HOOK"
assert_eq "missing jq allows" "0" "$TL_STATUS"
assert_eq "missing jq prints nothing" "" "$TL_OUT"
tl_run_stdin "$(payload Edit '{"new_string":"[lean-ctx: x]"}')" env PATH="$(tl_path_without python3)" bash "$TL_REPO_ROOT/$HOOK"
assert_eq "missing python3 allows (cannot inspect)" "0" "$TL_STATUS"
assert_eq "missing python3 prints nothing" "" "$TL_OUT"

tl_results
