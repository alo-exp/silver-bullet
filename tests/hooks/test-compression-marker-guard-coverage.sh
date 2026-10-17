#!/usr/bin/env bash
# Behavior tests for hooks/compression-marker-guard.sh (PreToolUse marker deny)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
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

expect_deny "lean-ctx marker in new_string" "$(payload Edit '{"file_path":"/p/a.md","new_string":"keep [lean-ctx: compressed 40%] here"}')"
expect_deny "marker is matched case-insensitively" "$(payload Write '{"file_path":"/p/a.md","content":"x [LEAN-CTX:abc] y"}')"
expect_deny "ellipsis marker" "$(payload Edit '{"file_path":"/p/a.md","new_string":"... [lean-ctx: truncated]"}')"
expect_deny "ctx_read plan header line" "$(payload Write '{"file_path":"/p/a.md","content":"intro\nfoo.plan.md [316L]\nbody"}')"
expect_deny "plan header with a path prefix" "$(payload Write '{"file_path":"/p/a.md","content":"docs/x.plan.md [12L]"}')"
expect_deny "MultiEdit nested edits array" "$(payload MultiEdit '{"file_path":"/p/a.md","edits":[{"old_string":"a","new_string":"b"},{"old_string":"c","new_string":"[lean-ctx: x]"}]}')"
expect_deny "apply_patch payload text" "$(payload apply_patch '{"input":"*** Begin Patch\n+[lean-ctx: cached]\n*** End Patch"}')"
expect_deny "deeply nested value" "$(payload Edit '{"a":{"b":[{"c":"[lean-ctx:"}]}}')"

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
