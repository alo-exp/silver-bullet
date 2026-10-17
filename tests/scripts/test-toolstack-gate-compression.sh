#!/usr/bin/env bash
# scripts/lib/global-toolstack/rtk-gate.sh, token-compression-tools-gate.sh and
# stack-compression-coordinator.sh (deployed layout): allow/deny decisions.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

ts_stage_deployed
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
sdir="$HOME/st/$hash"
CFG='{"enforcement":"always","state_dir":"~/st","tools":{"rtk":{"required":true,"usage_ttl_seconds":600}}}'
ts_write_config "$CFG"
edit="$(ts_payload Edit "$repo/src/app.py" "")"
shell="$(ts_payload Bash "" "cp a b")"

expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }
expect_deny() {
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_eq "$1: denies" deny "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$TL_OUT")"
  assert_contains "$1: reason" "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$TL_OUT")" "$2"
}
no_jq() { # <script> <json>
  tl_run_stdin "$2" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$1"
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
mkdir -p "$TL_TMP/nogit"
printf '{"enforcement":"off","tools":{"rtk":{"required":true}}}' >"$TL_TMP/off.json"
printf '{"enforcement":"always","tools":{}}' >"$TL_TMP/nr.json"

# ============ rtk-gate.sh ============
r=rtk-gate.sh
no_jq $r "$edit"; expect_silent "rtk: jq missing"
ts_gate $r "$edit" "$sbp"; expect_silent "rtk: defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $r "$edit" "$repo"; expect_silent "rtk: no config"
TS_CONFIG="$TL_TMP/off.json" ts_gate $r "$edit" "$repo"; expect_silent "rtk: enforcement off"
TS_CONFIG="$TL_TMP/nr.json" ts_gate $r "$edit" "$repo"; expect_silent "rtk: not required"
ts_gate $r "" "$repo"; expect_silent "rtk: empty stdin"
ts_gate $r "$edit" "$TL_TMP/nogit"; expect_silent "rtk: outside git"
ts_gate $r '[1]' "$repo"; expect_silent "rtk: non-object JSON (event fallback)"
ts_gate $r 'not json' "$repo"; expect_silent "rtk: invalid JSON"
ts_gate $r "$(ts_payload Read "$repo/a" "")" "$repo"; expect_silent "rtk: non-edit tool"
for p in "$repo/.cursor/rules/x.mdc" "$repo/hooks/h.sh" "$repo/scripts/lib/x.sh"; do
  ts_gate $r "$(ts_payload Edit "$p" "")" "$repo"; expect_silent "rtk: exempt edit path ${p#"$repo"/}"
done
for c in 'rtk git status > f' 'context-mode stats > f' 'graphify query x > f' 'agentmemory search x > f' 'lean-ctx doctor > f' 'echo a | rtk tee b'; do
  ts_gate $r "$(ts_payload Bash "" "$c")" "$repo"; expect_silent "rtk: tool command exempt: $c"
done
ts_gate $r "$(ts_payload Bash "" "ls -la")" "$repo"; expect_silent "rtk: non-substantive shell"
ts_gate $r "$(ts_payload Bash "" "")" "$repo"; expect_silent "rtk: no path and no command"

ts_gate $r "$edit" "$repo"; expect_deny "rtk: CLI missing (edit)" "RTK REQUIRED"
ts_gate $r "$shell" "$repo"; expect_deny "rtk: CLI missing (shell)" "RTK REQUIRED"
tl_stub rtk 'exit 0'
ts_gate $r "$edit" "$repo"; expect_deny "rtk: hook missing" "RTK HOOK MISSING"
mkdir -p "$HOME/.cursor"
printf '{"hooks":{}}' >"$HOME/.cursor/hooks.json"
ts_gate $r "$shell" "$repo"; expect_deny "rtk: hooks.json without rtk" "RTK HOOK MISSING"
ts_gate $r "$(ts_payload Edit "$repo/s.py" "" Stop)" "$repo"
assert_eq "rtk: stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"
assert_contains "rtk: stop reason" "$(jq -r '.reason' <<<"$TL_OUT")" "RTK HOOK MISSING"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}' >"$HOME/.cursor/hooks.json"
ts_gate $r "$edit" "$repo"; expect_silent "rtk: wired edit allowed"
ts_gate $r "$shell" "$repo"; expect_silent "rtk: wired shell allowed"
rm -f "$TL_BIN/rtk"

# ============ token-compression-tools-gate.sh ============
t=token-compression-tools-gate.sh
commit="$(ts_payload Bash "" "git commit -m x")"
no_jq $t "$commit"; expect_silent "token: jq missing"
ts_gate $t "$commit" "$sbp"; expect_silent "token: defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $t "$commit" "$repo"; expect_silent "token: no config"
TS_CONFIG="$TL_TMP/off.json" ts_gate $t "$commit" "$repo"; expect_silent "token: enforcement off"
ts_gate $t "" "$repo"; expect_silent "token: empty stdin"
ts_gate $t '[1]' "$repo"; expect_silent "token: non-object JSON (event fallback)"
ts_gate $t "$(ts_payload Read "$repo/a" "")" "$repo"; expect_silent "token: non-edit tool"
ts_gate $t "$(ts_payload Bash "" "")" "$repo"; expect_silent "token: empty command"
ts_gate $t "$(ts_payload Bash "" "ls -la")" "$repo"; expect_silent "token: not a delivery command"
TS_CONFIG="$TL_TMP/nr.json" ts_gate $t "$commit" "$repo"; expect_silent "token: rtk not required"

ts_gate $t "$commit" "$repo"; expect_deny "token: CLI missing" "RTK USAGE REQUIRED"
tl_stub rtk 'exit 0'
ts_gate $t "$commit" "$repo"; expect_deny "token: no usage recorded" "RTK USAGE STALE"
mkdir -p "$sdir"; echo 1 >"$sdir/rtk-usage"
for c in "git commit -m x" "gh pr create --fill" "gh release create v1"; do
  ts_gate $t "$(ts_payload Bash "" "$c")" "$repo"; expect_deny "token: stale usage for '$c'" "RTK USAGE STALE"
done
ts_gate $t "$(ts_payload Edit "$repo/a.py" "git commit" Stop)" "$repo"
assert_eq "token: stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"
date +%s >"$sdir/rtk-usage"
ts_gate $t "$commit" "$repo"; expect_silent "token: fresh usage allows commit"
rm -f "$TL_BIN/rtk" "$sdir/rtk-usage"

# ============ stack-compression-coordinator.sh ============
c=stack-compression-coordinator.sh
ts_write_config '{"enforcement":"always","state_dir":"~/st"}'
lean="$(ts_payload Bash "" "lean-ctx hook rewrite")"
mcp() { jq -cn --arg t "$1" --arg s "$2" --arg n "$3" '{tool_name:$t,tool_input:{server:$s,toolName:$n}}'; }
no_jq $c "$lean"; expect_silent "coord: jq missing"
ts_gate $c "$lean" "$sbp"; expect_silent "coord: defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $c "$lean" "$repo"; expect_silent "coord: no config"
TS_CONFIG="$TL_TMP/off.json" ts_gate $c "$lean" "$repo"; expect_silent "coord: enforcement off"
ts_gate $c "" "$repo"; expect_silent "coord: empty stdin"
ts_gate $c '[1]' "$repo"; expect_silent "coord: non-object JSON (event fallback)"

# double shell compression: only when RTK is primary and installed
ts_gate $c "$lean" "$repo"; expect_silent "coord: rtk missing => no double compression"
tl_stub rtk 'exit 0'
for t in Shell Bash shell; do
  ts_gate $c "$(ts_payload "$t" "" "lean-ctx hook rewrite")" "$repo"
  expect_deny "coord: double compression ($t)" "DOUBLE SHELL COMPRESSION"
done
ts_gate $c "$(ts_payload Bash "" "ls")" "$repo"; expect_silent "coord: ordinary shell command"
ts_gate $c "$(ts_payload exec_command "" "lean-ctx hook rewrite")" "$repo"; expect_silent "coord: exec_command is not matched"
ts_write_config '{"enforcement":"always","state_dir":"~/st","shell_compression":{"primary":"leanctx"}}'
ts_gate $c "$lean" "$repo"; expect_silent "coord: leanctx primary may rewrite"
ts_write_config '{"enforcement":"always","state_dir":"~/st"}'
ts_gate $c "$(ts_payload Stop "" "")" "$repo"; expect_silent "coord: unrelated tool"
ts_gate $c "$(ts_payload Bash "" "lean-ctx hook rewrite" Stop)" "$repo"
assert_eq "coord: stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"

# wrong-owner MCP calls
ts_gate $c "$(mcp CallMcpTool context-mode ctx_execute)" "$repo"; expect_silent "coord: ctx_ on context-mode server"
ts_gate $c "$(mcp MCP leanctx lctx_shell)" "$repo"; expect_silent "coord: lctx_shell allowed while context-mode is not wired"
ts_gate $c "$(mcp MCP leanctx lctx_read)" "$repo"; expect_silent "coord: other lctx tool"
mkdir -p "$HOME/.cursor"
printf '{"mcpServers":{"context-mode":{}}}' >"$HOME/.cursor/mcp.json"
for tool in lctx_shell lctx_execute lctx_batch_execute lctx_fetch lctx_fetch_and_index; do
  ts_gate $c "$(mcp CallMcpTool leanctx "$tool")" "$repo"
  expect_deny "coord: $tool denied when context-mode wired" "WRONG OWNER — $tool disabled"
done
ts_gate $c "$(mcp MCP leanctx lctx_read)" "$repo"; expect_silent "coord: non-listed lctx tool stays allowed"
for tool in ctx_execute ctx_execute_file ctx_batch_execute ctx_search ctx_index ctx_fetch_and_index; do
  ts_gate $c "$(mcp MCP my-leanctx-server "$tool")" "$repo"
  expect_deny "coord: $tool denied on leanctx server" "use context-mode MCP server"
done
ts_gate $c "$(mcp MCP leanctx other_tool)" "$repo"; expect_silent "coord: unrelated leanctx tool"
ts_gate $c "$(mcp MCP other_server lctx_shell)" "$repo"; expect_silent "coord: non-leanctx server"

# SB plugin cache coordinator lib is sourced when present
cache="$HOME/.cursor/plugins/cache/alo-labs/silver-bullet/current"
mkdir -p "$cache/hooks/lib"
ts_gate $c "$(ts_payload Bash "" "ls")" "$repo"; expect_silent "coord: plugin cache without coordinator lib"
printf 'echo sourced >"$HOME/coord-sourced"\n' >"$cache/hooks/lib/stack-compression-coordinator.sh"
ts_gate $c "$(ts_payload Bash "" "ls")" "$repo"; expect_silent "coord: coordinator lib sourced silently"
assert_eq "coord: lib was sourced" sourced "$(cat "$HOME/coord-sourced")"
printf 'return 1\n' >"$cache/hooks/lib/stack-compression-coordinator.sh"
ts_gate $c "$(ts_payload Bash "" "ls")" "$repo"; expect_silent "coord: failing coordinator lib is ignored"

tl_results
