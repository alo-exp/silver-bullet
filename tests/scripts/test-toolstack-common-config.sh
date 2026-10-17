#!/usr/bin/env bash
# scripts/lib/global-toolstack/common.sh: config access, project discovery,
# bridge deferral, state paths, deny JSON and hook-payload extractors.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init
unset TS_CONFIG

# --- ts_expand_path ---
ts_call ts_expand_path '~/x/y'
assert_eq "expand ~ prefix" "$HOME/x/y" "$TL_OUT"
ts_call ts_expand_path '/abs/~/y'
assert_eq "expand keeps non-leading ~" '/abs/~/y' "$TL_OUT"
ts_call ts_expand_path
assert_eq "expand empty" "" "$TL_OUT"

# --- ts_config_path / ts_config ---
ts_call ts_config_path
assert_eq "default config path under HOME" "$HOME/.cursor/toolstack.json" "$TL_OUT"
TS_CONFIG="$TL_TMP/custom.json" ts_call ts_config_path
assert_eq "TS_CONFIG overrides path" "$TL_TMP/custom.json" "$TL_OUT"
ts_call ts_config
assert_eq "ts_config fails without file" 1 "$TL_STATUS"
ts_write_config '{"enforcement":"always","profile":"p1","state_dir":"~/st","tools":{"graphify":{"required":true},"rtk":{"required":false}},"routes":{"sb_read":"leanctx"},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_grep":"context_mode"}}}}'
ts_call ts_config
assert_eq "ts_config prints existing path" "$TS_CONFIG" "$TL_OUT"

# --- ts_jq ---
ts_call ts_jq '.profile'
assert_eq "ts_jq reads field" "p1" "$TL_OUT"
ts_call ts_jq '.missing // $def' '"fallback"'
assert_eq "ts_jq passes --argjson def" "fallback" "$TL_OUT"
printf 'not json' >"$TS_CONFIG"
ts_call ts_jq '.profile'
assert_eq "ts_jq with invalid JSON fails" 5 "$TL_STATUS"
rm -f "$TS_CONFIG"
ts_call ts_jq '.profile'
assert_eq "ts_jq without config fails" 1 "$TL_STATUS"
ts_write_config '{"enforcement":"always","profile":"p1","state_dir":"~/st","tools":{"graphify":{"required":true},"rtk":{"required":false}},"routes":{"sb_read":"leanctx"},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_grep":"context_mode"}}}}'

# --- ts_sb_jq ---
sbcfg="$TL_TMP/sb.json"
printf '{"a":{"b":7}}' >"$sbcfg"
ts_call ts_sb_jq "$sbcfg" '.a.b'
assert_eq "ts_sb_jq reads" 7 "$TL_OUT"
ts_call ts_sb_jq "$sbcfg" '.zz // $def' '"d"'
assert_eq "ts_sb_jq --argjson def" "d" "$TL_OUT"
ts_call ts_sb_jq "$TL_TMP/nope.json" '.a'
assert_eq "ts_sb_jq missing file fails" 1 "$TL_STATUS"
ts_call ts_sb_jq "" '.a'
assert_eq "ts_sb_jq empty path fails" 1 "$TL_STATUS"

# --- ts_find_sb_config ---
ts_sb_project "$TL_TMP/proj/sub/deep"
mkdir -p "$TL_TMP/proj/sub/deeper"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_find_sb_config' _ "$TL_TMP/proj/sub/deeper" "$TS_SRC"
assert_eq "no SB config found without markers" 1 "$TL_STATUS"
ts_sb_project "$TL_TMP/proj"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_find_sb_config' _ "$TL_TMP/proj/sub/deeper" "$TS_SRC"
assert_eq "finds SB config walking up" "$TL_TMP/proj/.silver-bullet.json" "$TL_OUT"
ts_call ts_find_sb_config "$TL_TMP/proj/sub"
assert_eq "explicit start dir" "$TL_TMP/proj/.silver-bullet.json" "$TL_OUT"
ts_call ts_find_sb_config "$TL_TMP/does/not/exist"
assert_eq "nonexistent start dir fails" 1 "$TL_STATUS"
# a git root stops the walk (marker above the repo is ignored)
tl_git_repo "$TL_TMP/proj/inner"
ts_call ts_find_sb_config "$TL_TMP/proj/inner"
assert_eq "git root stops SB config search" 1 "$TL_STATUS"
# .silver-bullet.json without silver-bullet.md is not a project
mkdir -p "$TL_TMP/half"
printf '{}' >"$TL_TMP/half/.silver-bullet.json"
ts_call ts_find_sb_config "$TL_TMP/half"
assert_eq "half-initialised project ignored" 1 "$TL_STATUS"

# --- ts_sb_defer_to_bridge ---
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/half" "$TS_SRC"
assert_eq "no defer without SB project" 1 "$TL_STATUS"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/proj" "$TS_SRC"
assert_eq "no defer without heartbeat lib" 1 "$TL_STATUS"
hbdir="$TL_TMP/proj/scripts/lib/recommended-tools"
mkdir -p "$hbdir"
# heartbeat lib that does not define rt_heartbeat_path
printf '%s\n' ':' >"$hbdir/heartbeat.sh"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/proj" "$TS_SRC"
assert_eq "no defer when heartbeat lib defines nothing" 1 "$TL_STATUS"
# valid heartbeat
cat >"$hbdir/heartbeat.sh" <<'HB'
rt_project_id() { echo pid; }
rt_worktree_id() { echo "wt-$1"; }
rt_current_session_id() { echo sess; }
rt_heartbeat_path() { echo "$HB_PATH_OUT"; }
rt_heartbeat_is_valid() { echo "$@" >"$HB_ARGS_FILE"; [[ "$HB_VALID" == "1" ]]; }
HB
export HB_ARGS_FILE="$TL_TMP/hb-args"
HB_PATH_OUT="/hb/path" HB_VALID=1 ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/proj" "$TS_SRC"
assert_eq "defers on valid heartbeat" 0 "$TL_STATUS"
assert_eq "heartbeat validated for cursor and project root" "/hb/path cursor $TL_TMP/proj $TL_TMP/proj" "$(cat "$HB_ARGS_FILE")"
HB_PATH_OUT="/hb/path" HB_VALID=0 ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/proj" "$TS_SRC"
assert_eq "no defer on invalid heartbeat" 1 "$TL_STATUS"
HB_PATH_OUT="" HB_VALID=1 ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_sb_defer_to_bridge' _ "$TL_TMP/proj" "$TS_SRC"
assert_eq "no defer when heartbeat path is empty" 1 "$TL_STATUS"

# --- ts_enforcement_active / ts_tool_required ---
ts_call ts_enforcement_active
assert_eq "enforcement always => active" 0 "$TL_STATUS"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_enforcement_active
assert_eq "no config => inactive" 1 "$TL_STATUS"
printf '{"enforcement":"off"}' >"$TL_TMP/off.json"
TS_CONFIG="$TL_TMP/off.json" ts_call ts_enforcement_active
assert_eq "enforcement off => inactive" 1 "$TL_STATUS"
printf '{}' >"$TL_TMP/empty.json"
TS_CONFIG="$TL_TMP/empty.json" ts_call ts_enforcement_active
assert_eq "enforcement missing defaults to off" 1 "$TL_STATUS"
ts_call ts_tool_required graphify
assert_eq "required tool" 0 "$TL_STATUS"
ts_call ts_tool_required rtk
assert_eq "tool with required=false" 1 "$TL_STATUS"
ts_call ts_tool_required unknown
assert_eq "unknown tool not required" 1 "$TL_STATUS"
ts_call ts_tool_required ""
assert_eq "empty tool name" 1 "$TL_STATUS"
TS_CONFIG="$TL_TMP/off.json" ts_call ts_tool_required graphify
assert_eq "required tool ignored when enforcement off" 1 "$TL_STATUS"

# --- ts_profile_name / ts_route_owner ---
ts_call ts_profile_name
assert_eq "profile from config" p1 "$TL_OUT"
printf '{"tools":{"leanctx":{"profile":"lp"}}}' >"$TL_TMP/lp.json"
TS_CONFIG="$TL_TMP/lp.json" ts_call ts_profile_name
assert_eq "profile falls back to leanctx profile" lp "$TL_OUT"
TS_CONFIG="$TL_TMP/empty.json" ts_call ts_profile_name
assert_eq "profile default" five_tool_routed "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_profile_name
assert_eq "profile default without config" five_tool_routed "$TL_OUT"
ts_call ts_route_owner sb_read
assert_eq "route owner from routes" leanctx "$TL_OUT"
ts_call ts_route_owner sb_grep
assert_eq "route owner from optimization profile" context_mode "$TL_OUT"
ts_call ts_route_owner sb_unknown
assert_eq "unknown route fails" 1 "$TL_STATUS"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_route_owner sb_read
assert_eq "route owner without config fails" 1 "$TL_STATUS"

# --- ts_state_root ---
ts_call ts_state_root
assert_eq "state_dir expanded" "$HOME/st" "$TL_OUT"
TS_CONFIG="$TL_TMP/empty.json" ts_call ts_state_root
assert_eq "state root default" "$HOME/.cursor/state/toolstack" "$TL_OUT"

# --- ts_git_root ---
tl_git_repo "$TL_TMP/repo"
mkdir -p "$TL_TMP/repo/a/b" "$TL_TMP/nogit"
ts_call ts_git_root "$TL_TMP/repo/a/b"
assert_eq "git root found from subdir" "$TL_TMP/repo" "$TL_OUT"
ts_call ts_git_root "$TL_TMP/nogit"
assert_eq "no git root" 1 "$TL_STATUS"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_git_root' _ "$TL_TMP/repo/a" "$TS_SRC"
assert_eq "git root defaults to PWD" "$TL_TMP/repo" "$TL_OUT"

# --- ts_project_hash ---
ts_call ts_project_hash /some/root
expected="$(printf '%s' /some/root | sha256sum | awk '{print substr($1,1,16)}')"
assert_eq "hash is first 16 hex of sha256" "$expected" "$TL_OUT"
ts_call ts_project_hash ""
assert_eq "empty root rejected" 1 "$TL_STATUS"
# shasum preferred when present
tl_stub shasum 'cat >/dev/null; echo "abcdef0123456789ffff -"'
ts_call ts_project_hash /some/root
assert_eq "shasum used when available" abcdef0123456789 "$TL_OUT"
rm -f "$TL_BIN/shasum"

# --- ts_project_state_dir ---
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_project_state_dir' _ "$TL_TMP/repo/a" "$TS_SRC"
assert_eq "state dir keyed by project hash" "$HOME/st/$(printf '%s' "$TL_TMP/repo" | sha256sum | awk '{print substr($1,1,16)}')" "$TL_OUT"
ts_call bash -c 'cd "$1" && source "$2/common.sh" && ts_project_state_dir' _ "$TL_TMP/nogit" "$TS_SRC"
assert_eq "outside git: plain state root" "$HOME/st" "$TL_OUT"

# --- ts_emit_deny ---
ts_call ts_emit_deny 'no "way"'
assert_eq "deny PreToolUse decision" deny "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$TL_OUT")"
assert_eq "deny PreToolUse reason JSON-escaped" 'no "way"' "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$TL_OUT")"
assert_eq "deny PreToolUse event name" PreToolUse "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$TL_OUT")"
ts_call ts_emit_deny
assert_eq "deny default reason" blocked "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$TL_OUT")"
ts_call ts_emit_deny 'stop it' Stop
assert_eq "stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"
assert_eq "stop event reason" 'stop it' "$(jq -r '.reason' <<<"$TL_OUT")"
assert_eq "stop event message" 'stop it' "$(jq -r '.hookSpecificOutput.message' <<<"$TL_OUT")"

# --- payload extractors ---
payload='{"tool_name":"Edit","tool_input":{"file_path":"/a/b.txt","command":"ls -l","toolName":"memory_save","server":"agentmemory"}}'
ts_call ts_tool_name "$payload"
assert_eq "tool_name" Edit "$TL_OUT"
ts_call ts_tool_file_path "$payload"
assert_eq "file_path" /a/b.txt "$TL_OUT"
ts_call ts_tool_file_path '{"tool_input":{"path":"/p/q"}}'
assert_eq "file path falls back to .path" /p/q "$TL_OUT"
ts_call ts_tool_command_string "$payload"
assert_eq "command string" "ls -l" "$TL_OUT"
ts_call ts_mcp_tool_name "$payload"
assert_eq "mcp toolName" memory_save "$TL_OUT"
ts_call ts_mcp_tool_name '{"tool_input":{"name":"nm"}}'
assert_eq "mcp tool falls back to name" nm "$TL_OUT"
ts_call ts_mcp_server_name "$payload"
assert_eq "mcp server" agentmemory "$TL_OUT"
ts_call ts_mcp_server_name '{"tool_input":{"serverName":"sn"}}'
assert_eq "mcp server falls back to serverName" sn "$TL_OUT"
ts_call ts_tool_name 'not json'
assert_eq "non-JSON payload yields empty tool name" "" "$TL_OUT"
ts_call ts_tool_name
assert_eq "empty payload yields empty tool name" "" "$TL_OUT"
ts_call ts_tool_file_path '{}'
assert_eq "missing file path is empty" "" "$TL_OUT"

# --- ts_is_substantive_shell ---
for c in 'git commit -m x' 'gh pr create --fill' 'gh release create v1' 'echo hi >> f' 'echo hi > f' 'cat a | tee b' 'cp a b' 'mv a b' 'sed -i s/a/b/ f' 'perl -i.bak -pe s/a/b/ f'; do
  ts_call ts_is_substantive_shell "$c"
  assert_eq "substantive: $c" 0 "$TL_STATUS"
done
for c in '' 'ls -la' 'git status' 'echo a >&2' 'cat a'; do
  ts_call ts_is_substantive_shell "$c"
  assert_eq "not substantive: '$c'" 1 "$TL_STATUS"
done

tl_results
