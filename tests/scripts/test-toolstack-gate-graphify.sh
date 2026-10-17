#!/usr/bin/env bash
# scripts/lib/global-toolstack/graphify-gate.sh (deployed layout): when the
# gate allows silently and when it denies, for PreToolUse and Stop events.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

TS_STAGE="$TL_TMP/toolstack"
ts_stage_deployed "$TS_STAGE"
repo="$TL_TMP/repo"; tl_git_repo "$repo"
mkdir -p "$repo/graphify-out"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
state="$HOME/st/$hash/graphify-query"
CFG='{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true,"query_ttl_seconds":600}}}'
ts_write_config "$CFG"
edit="$(ts_payload Edit "$repo/src/app.py" "")"
shell="$(ts_payload Bash "" "make deploy > out.log")"

expect_silent() { # <name>
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_eq "$1: no output" "" "$TL_OUT"
}
expect_deny() { # <name> <reason fragment>
  assert_eq "$1: exit 0" 0 "$TL_STATUS"
  assert_eq "$1: denies" deny "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$TL_OUT")"
  assert_contains "$1: reason" "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$TL_OUT")" "$2"
}

# --- silent exits ---
tl_run_stdin "$edit" env PATH="$(tl_path_without jq)" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/graphify-gate.sh"
expect_silent "jq missing"

TS_CONFIG="$TL_TMP/none.json" ts_gate graphify-gate.sh "$edit" "$repo"; expect_silent "no config"
printf '{"enforcement":"off","tools":{"graphify":{"required":true}}}' >"$TL_TMP/off.json"
TS_CONFIG="$TL_TMP/off.json" ts_gate graphify-gate.sh "$edit" "$repo"; expect_silent "enforcement off"
printf '{"enforcement":"always","tools":{"graphify":{"required":false}}}' >"$TL_TMP/nr.json"
TS_CONFIG="$TL_TMP/nr.json" ts_gate graphify-gate.sh "$edit" "$repo"; expect_silent "graphify not required"
ts_gate graphify-gate.sh "" "$repo"; expect_silent "empty stdin"
mkdir -p "$TL_TMP/nogit"
ts_gate graphify-gate.sh "$edit" "$TL_TMP/nogit"; expect_silent "outside git"
ts_gate graphify-gate.sh "$(ts_payload Read "$repo/a" "")" "$repo"; expect_silent "non-edit tool"
ts_gate graphify-gate.sh "$(ts_payload Edit "$repo/graphify-out/notes.md" "")" "$repo"; expect_silent "edit under graphify-out exempt"
ts_gate graphify-gate.sh "$(ts_payload Bash "" "graphify query foo")" "$repo"; expect_silent "graphify command exempt"
ts_gate graphify-gate.sh "$(ts_payload Bash "" "ls -la")" "$repo"; expect_silent "non-substantive shell"
ts_gate graphify-gate.sh "$(ts_payload Bash "" "")" "$repo"; expect_silent "shell without command or path"
ts_gate graphify-gate.sh 'not json' "$repo"; expect_silent "invalid JSON payload"

# --- SB bridge deferral ---
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
ts_gate graphify-gate.sh "$edit" "$sbp"; expect_silent "defers to a live SB bridge"

# --- denies ---
ts_gate graphify-gate.sh "$edit" "$repo"
expect_deny "CLI missing" "GRAPHIFY REQUIRED"
tl_stub graphify 'exit 0'
ts_gate graphify-gate.sh "$edit" "$repo"
expect_deny "index missing" "GRAPHIFY INDEX MISSING"
assert_contains "index-missing reason names the expected graph" "$TL_OUT" "graphify-out/graph.json"
printf '{}' >"$repo/graphify-out/graph.json"
ts_gate graphify-gate.sh "$edit" "$repo"
expect_deny "no query yet" "GRAPHIFY QUERY REQUIRED"
assert_contains "stale reason names the ttl" "$TL_OUT" "600s"
mkdir -p "$(dirname "$state")"
echo 1 >"$state"
ts_gate graphify-gate.sh "$shell" "$repo"
expect_deny "stale query on substantive shell" "GRAPHIFY QUERY REQUIRED"

# --- Stop-style event uses block JSON ---
ts_gate graphify-gate.sh "$(ts_payload Edit "$repo/src/app.py" "" Stop)" "$repo"
assert_eq "stop event blocks" block "$(jq -r '.decision' <<<"$TL_OUT")"
assert_contains "stop event reason" "$(jq -r '.reason' <<<"$TL_OUT")" "GRAPHIFY QUERY REQUIRED"

# --- fresh query allows ---
date +%s >"$state"
ts_gate graphify-gate.sh "$edit" "$repo"; expect_silent "fresh query allows edit"
ts_gate graphify-gate.sh "$shell" "$repo"; expect_silent "fresh query allows shell"

tl_results
