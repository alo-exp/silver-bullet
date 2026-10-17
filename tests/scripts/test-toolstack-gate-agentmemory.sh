#!/usr/bin/env bash
# scripts/lib/global-toolstack/agentmemory-gate.sh (deployed layout).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

TS_STAGE="$TL_TMP/toolstack"
ts_stage_deployed "$TS_STAGE"
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
sdir="$HOME/st/$hash"
CFG='{"enforcement":"always","state_dir":"~/st","tools":{"agentmemory":{"required":true,"export_root":"mem","usage_ttl_seconds":600,"health_url":"http://am.test/health"}}}'
ts_write_config "$CFG"
edit="$(ts_payload Edit "$repo/src/app.py" "")"
shell="$(ts_payload Bash "" "git commit -m x")"

expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }
expect_deny() {
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_eq "$1: denies" deny "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$TL_OUT")"
  assert_contains "$1: reason" "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$TL_OUT")" "$2"
}

# --- silent exits ---
tl_run_stdin "$edit" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/agentmemory-gate.sh"
expect_silent "jq missing"
TS_CONFIG="$TL_TMP/none.json" ts_gate agentmemory-gate.sh "$edit" "$repo"; expect_silent "no config"
printf '{"enforcement":"off","tools":{"agentmemory":{"required":true}}}' >"$TL_TMP/off.json"
TS_CONFIG="$TL_TMP/off.json" ts_gate agentmemory-gate.sh "$edit" "$repo"; expect_silent "enforcement off"
printf '{"enforcement":"always","tools":{}}' >"$TL_TMP/nr.json"
TS_CONFIG="$TL_TMP/nr.json" ts_gate agentmemory-gate.sh "$edit" "$repo"; expect_silent "agentmemory not required"
ts_gate agentmemory-gate.sh "" "$repo"; expect_silent "empty stdin"
mkdir -p "$TL_TMP/nogit"
ts_gate agentmemory-gate.sh "$edit" "$TL_TMP/nogit"; expect_silent "outside git"
ts_gate agentmemory-gate.sh "$(ts_payload Grep "" "")" "$repo"; expect_silent "non-edit tool"
ts_gate agentmemory-gate.sh "$(ts_payload Write "$repo/mem/memory/n.md" "")" "$repo"; expect_silent "edit in export root exempt"
ts_gate agentmemory-gate.sh "$(ts_payload Bash "" "agentmemory status")" "$repo"; expect_silent "agentmemory command exempt"
ts_gate agentmemory-gate.sh "$(ts_payload Bash "" "ls -la")" "$repo"; expect_silent "non-substantive shell"
ts_gate agentmemory-gate.sh "$(ts_payload Bash "" "")" "$repo"; expect_silent "shell without command or path"

# --- denial ladder ---
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "CLI missing" "AGENTMEMORY REQUIRED"
tl_stub agentmemory 'if [[ "$1" == status ]]; then echo "$AM_STATUS"; fi'
tl_stub curl 'exit 1'
AM_STATUS="down" ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "server down" "AGENTMEMORY SERVER DOWN"
assert_contains "server-down reason names the health URL" "$TL_OUT" "http://am.test/health"
tl_stub curl 'exit 0'
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "MCP not wired" "AGENTMEMORY MCP NOT WIRED"
mkdir -p "$HOME/.cursor"
printf '{"mcpServers":{"agentmemory":{}}}' >"$HOME/.cursor/mcp.json"

# export root cannot be created: its parent is a regular file
printf 'f' >"$repo/blocker"
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"agentmemory":{"required":true,"export_root":"blocker/x","usage_ttl_seconds":600}}}'
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "export cannot be scaffolded" "AGENTMEMORY EXPORT MISSING"
assert_contains "export-missing reason names the path" "$TL_OUT" "blocker/x/memory"
ts_write_config "$CFG"

# export missing but creatable: scaffold, then allow
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_silent "first run scaffolds export and allows"
assert_file_exists "scaffold created memory dir" "$repo/mem/memory"
assert_file_exists "scaffold created snapshots dir" "$repo/mem/snapshots"

# export exists: usage required
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "no usage recorded" "AGENTMEMORY USAGE REQUIRED"
assert_contains "usage reason names the ttl" "$TL_OUT" "TTL 600s"
mkdir -p "$sdir"; echo 1 >"$sdir/agentmemory-usage"
ts_gate agentmemory-gate.sh "$shell" "$repo"
expect_deny "stale usage" "AGENTMEMORY USAGE REQUIRED"
date +%s >"$sdir/agentmemory-usage"
ts_gate agentmemory-gate.sh "$edit" "$repo"; expect_silent "fresh usage allows"
rm -f "$sdir/agentmemory-usage"

# graphify synergy: required graphify + fresh query passes the gate
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true},"agentmemory":{"required":true,"export_root":"mem","usage_ttl_seconds":600}}}'
ts_gate agentmemory-gate.sh "$edit" "$repo"
expect_deny "synergy needs a fresh graphify query" "AGENTMEMORY USAGE REQUIRED"
date +%s >"$sdir/graphify-query"
ts_gate agentmemory-gate.sh "$edit" "$repo"; expect_silent "fresh graphify query satisfies agentmemory"

# Stop event
rm -f "$sdir/graphify-query"
ts_gate agentmemory-gate.sh "$(ts_payload Edit "$repo/src/a.py" "" Stop)" "$repo"
assert_eq "stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"

tl_results
