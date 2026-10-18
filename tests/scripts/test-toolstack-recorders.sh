#!/usr/bin/env bash
# scripts/lib/global-toolstack/record-graphify-query.sh and
# record-agentmemory-usage.sh (deployed layout): what makes a PostToolUse payload
# count as a retrieval/usage and what is written to the project state dir.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

ts_stage_deployed
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
sdir="$HOME/st/$hash"
CFG='{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true},"agentmemory":{"required":true}}}'
ts_write_config "$CFG"

resp() { # <tool> <command> <tool_response json>
  jq -cn --arg t "$1" --arg c "$2" --argjson r "$3" '{tool_name:$t,tool_input:{command:$c},tool_response:$r}'
}
mcp() { # <tool_name> <server> <tool>
  jq -cn --arg t "$1" --arg s "$2" --arg n "$3" '{tool_name:$t,tool_input:{server:$s,toolName:$n}}'
}
expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }
expect_recorded() { # <name> <state file> <message fragment>
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_contains "$1: message" "$(jq -r '.hookSpecificOutput.message // empty' <<<"$TL_OUT")" "$3"
  assert_match "$1: state holds an epoch" '^[0-9]+$' "$(cat "$2")"
}

sbp="$TL_TMP/sbp"; tl_git_repo "$sbp"
ts_sb_project "$sbp"
mkdir -p "$sbp/scripts/lib/recommended-tools"
cat >"$sbp/scripts/lib/recommended-tools/heartbeat.sh" <<'HB'
rt_project_id() { echo p; }
rt_worktree_id() { echo w; }
rt_current_session_id() { echo s; }
rt_heartbeat_path() { echo /hb; }
rt_heartbeat_is_valid() { return 0; }
HB
mkdir -p "$TL_TMP/nogit" "$TL_TMP/catfail"
printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/catfail/cat"; chmod +x "$TL_TMP/catfail/cat"
printf '{"enforcement":"always","tools":{}}' >"$TL_TMP/nr.json"

# ============ record-graphify-query.sh ============
g=record-graphify-query.sh
gq="$(resp Bash 'graphify query "hooks" --graph graphify-out/graph.json' '{"exit_code":0}')"

tl_run_stdin "$gq" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$g"
expect_silent "graphify: jq missing"
ts_gate $g "$gq" "$sbp"; expect_silent "graphify: defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $g "$gq" "$repo"; expect_silent "graphify: no config"
TS_CONFIG="$TL_TMP/nr.json" ts_gate $g "$gq" "$repo"; expect_silent "graphify: not required"
ts_gate $g "" "$repo"; expect_silent "graphify: empty stdin"
tl_run_stdin "$gq" env PATH="$TL_TMP/catfail:$PATH" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$g"
expect_silent "graphify: unreadable stdin"
ts_gate $g 'not json' "$repo"; expect_silent "graphify: invalid JSON"
ts_gate $g "$(ts_payload Edit "$repo/a.py" "")" "$repo"; expect_silent "graphify: non-shell tool"
ts_gate $g "$gq" "$TL_TMP/nogit"; expect_silent "graphify: outside git"
ts_gate $g "$(ts_payload Bash "" "")" "$repo"; expect_silent "graphify: empty command"
ts_gate $g "$(resp Bash 'graphify update .' '{"exit_code":0}')" "$repo"; expect_silent "graphify: index build is not retrieval"
ts_gate $g "$(resp Bash 'ls' '{"exit_code":0}')" "$repo"; expect_silent "graphify: unrelated command"
ts_gate $g "$(resp Bash 'graphify query x' '{"exit_code":2}')" "$repo"; expect_silent "graphify: failed query (exit_code)"
ts_gate $g "$(resp Bash 'graphify query x' '{"exitCode":1}')" "$repo"; expect_silent "graphify: failed query (exitCode)"
assert_file_absent "graphify: nothing recorded so far" "$sdir/graphify-query"

ts_gate $g "$gq" "$repo"
expect_recorded "graphify: recorded" "$sdir/graphify-query" "Graphify query recorded"
for t in Shell shell exec_command; do
  rm -f "$sdir/graphify-query"
  ts_gate $g "$(resp "$t" 'graphify explain hooks' '{"exitCode":0}')" "$repo"
  expect_recorded "graphify: $t tool name" "$sdir/graphify-query" "Graphify query recorded"
done
rm -f "$sdir/graphify-query"
ts_gate $g "$(resp Bash 'graphify path A B' '"plain string response"')" "$repo"
expect_recorded "graphify: non-object response counts as success" "$sdir/graphify-query" "Graphify query recorded"

# unwritable state dir: no message, still exit 0
rm -rf "$HOME/st"; printf x >"$HOME/st"
ts_gate $g "$gq" "$repo"; expect_silent "graphify: state dir cannot be created"
rm -f "$HOME/st"

# ============ record-agentmemory-usage.sh ============
a=record-agentmemory-usage.sh
aq="$(resp Bash 'agentmemory search "hooks"' '{"exit_code":0}')"

tl_run_stdin "$aq" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$a"
expect_silent "agentmemory: jq missing"
ts_gate $a "$aq" "$sbp"; expect_silent "agentmemory: defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $a "$aq" "$repo"; expect_silent "agentmemory: no config"
TS_CONFIG="$TL_TMP/nr.json" ts_gate $a "$aq" "$repo"; expect_silent "agentmemory: not required"
ts_gate $a "" "$repo"; expect_silent "agentmemory: empty stdin"
tl_run_stdin "$aq" env PATH="$TL_TMP/catfail:$PATH" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$a"
expect_silent "agentmemory: unreadable stdin"
ts_gate $a "$aq" "$TL_TMP/nogit"; expect_silent "agentmemory: outside git"
ts_gate $a "$(ts_payload Read "$repo/a.py" "")" "$repo"; expect_silent "agentmemory: unrelated tool"
ts_gate $a "$(mcp CallMcpTool agentmemory memory_recall)" "$repo"; expect_silent "agentmemory: MCP non-save tool"
ts_gate $a "$(mcp MCP other memory_save)" "$repo"; expect_silent "agentmemory: MCP save on another server"
ts_gate $a "$(ts_payload Bash "" "")" "$repo"; expect_silent "agentmemory: empty command"
ts_gate $a "$(resp Bash 'agentmemory start' '{"exit_code":0}')" "$repo"; expect_silent "agentmemory: non-retrieval command"
ts_gate $a "$(resp Bash 'agentmemory search x' '{"exit_code":3}')" "$repo"; expect_silent "agentmemory: failed retrieval (exit_code)"
ts_gate $a "$(resp Bash 'agentmemory search x' '{"exitCode":1}')" "$repo"; expect_silent "agentmemory: failed retrieval (exitCode)"
assert_file_absent "agentmemory: nothing recorded so far" "$sdir/agentmemory-usage"

ts_gate $a "$aq" "$repo"
expect_recorded "agentmemory: shell retrieval" "$sdir/agentmemory-usage" "agentmemory usage recorded"
rm -f "$sdir/agentmemory-usage"
ts_gate $a "$(resp exec_command 'curl localhost:3111/agentmemory/recall' '"ok"')" "$repo"
expect_recorded "agentmemory: curl recall with string response" "$sdir/agentmemory-usage" "agentmemory usage recorded"
for t in CallMcpTool MCP; do
  rm -f "$sdir/agentmemory-usage"
  ts_gate $a "$(mcp "$t" agentmemory memory_save)" "$repo"
  expect_recorded "agentmemory: $t save" "$sdir/agentmemory-usage" "agentmemory usage recorded"
done

rm -rf "$HOME/st"; printf x >"$HOME/st"
ts_gate $a "$aq" "$repo"; expect_silent "agentmemory: state dir cannot be created"
rm -f "$HOME/st"

tl_results
