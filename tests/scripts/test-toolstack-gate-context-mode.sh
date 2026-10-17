#!/usr/bin/env bash
# scripts/lib/global-toolstack/context-mode-gate.sh (deployed layout).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

TS_STAGE="$TL_TMP/toolstack"
ts_stage_deployed "$TS_STAGE"
repo="$TL_TMP/repo"; tl_git_repo "$repo"
ts_write_config '{"enforcement":"always","tools":{"context_mode":{"required":true}}}'
edit="$(ts_payload Edit "$repo/src/app.py" "")"
shell="$(ts_payload Bash "" "cp a b")"

expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }
expect_deny() {
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_eq "$1: denies" deny "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$TL_OUT")"
  assert_contains "$1: reason" "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$TL_OUT")" "$2"
}

tl_run_stdin "$edit" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/context-mode-gate.sh"
expect_silent "jq missing"
TS_CONFIG="$TL_TMP/none.json" ts_gate context-mode-gate.sh "$edit" "$repo"; expect_silent "no config"
printf '{"enforcement":"off","tools":{"context_mode":{"required":true}}}' >"$TL_TMP/off.json"
TS_CONFIG="$TL_TMP/off.json" ts_gate context-mode-gate.sh "$edit" "$repo"; expect_silent "enforcement off"
printf '{"enforcement":"always","tools":{}}' >"$TL_TMP/nr.json"
TS_CONFIG="$TL_TMP/nr.json" ts_gate context-mode-gate.sh "$edit" "$repo"; expect_silent "context_mode not required"
ts_gate context-mode-gate.sh "" "$repo"; expect_silent "empty stdin"
mkdir -p "$TL_TMP/nogit"
ts_gate context-mode-gate.sh "$edit" "$TL_TMP/nogit"; expect_silent "outside git"
ts_gate context-mode-gate.sh "$(ts_payload Read "$repo/a" "")" "$repo"; expect_silent "non-edit tool"
ts_gate context-mode-gate.sh "$(ts_payload Edit "$repo/.cursor/rules/x.mdc" "")" "$repo"; expect_silent "edit under .cursor exempt"
ts_gate context-mode-gate.sh "$(ts_payload Write "$repo/hooks/h.sh" "")" "$repo"; expect_silent "edit under hooks exempt"
ts_gate context-mode-gate.sh "$(ts_payload Bash "" "context-mode stats > f")" "$repo"; expect_silent "context-mode command exempt"
ts_gate context-mode-gate.sh "$(ts_payload Bash "" "ctx_ search")" "$repo"; expect_silent "ctx_ command exempt"
ts_gate context-mode-gate.sh "$(ts_payload Bash "" "ls")" "$repo"; expect_silent "non-substantive shell"
ts_gate context-mode-gate.sh "$(ts_payload Bash "" "")" "$repo"; expect_silent "shell without command or path"

ts_gate context-mode-gate.sh "$edit" "$repo"
expect_deny "CLI missing" "CONTEXT MODE REQUIRED"
tl_stub context-mode 'exit 0'
ts_gate context-mode-gate.sh "$shell" "$repo"
expect_deny "MCP not wired" "CONTEXT MODE MCP NOT WIRED"
mkdir -p "$HOME/.cursor"
printf '{"mcpServers":{"context-mode":{}}}' >"$HOME/.cursor/mcp.json"
ts_gate context-mode-gate.sh "$edit" "$repo"; expect_silent "wired CLI allows edit"
ts_gate context-mode-gate.sh "$shell" "$repo"; expect_silent "wired CLI allows shell"

printf '{"mcpServers":{}}' >"$HOME/.cursor/mcp.json"
ts_gate context-mode-gate.sh "$(ts_payload Edit "$repo/s.py" "" Stop)" "$repo"
assert_eq "stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"

tl_results
