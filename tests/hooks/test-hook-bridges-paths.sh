#!/usr/bin/env bash
# cursor-hook-bridge.sh, codex-hook-adapter.sh, industry-tooling-hint.sh and debug-dump.sh edge paths.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
CURSOR="$TL_REPO_ROOT/hooks/cursor-hook-bridge.sh"
CODEX="$TL_REPO_ROOT/hooks/codex-hook-adapter.sh"
HINT="$TL_REPO_ROOT/hooks/industry-tooling-hint.sh"
DUMP="$TL_REPO_ROOT/hooks/debug-dump.sh"
SD="${SB_RUNTIME_STATE_DIR:?}"

# ---- bridge argument validation ---------------------------------------------
tl_run_stdin '{}' bash "$CURSOR"
assert_eq "cursor bridge without arguments: exit 2" "2" "$TL_STATUS"
tl_run_stdin '{}' bash "$CURSOR" preToolUse
assert_eq "cursor bridge without a command: exit 2" "2" "$TL_STATUS"
tl_run_stdin '{}' bash "$CODEX"
assert_eq "codex adapter without arguments: exit 2" "2" "$TL_STATUS"
tl_run_stdin '{}' bash "$CODEX" PreToolUse
assert_eq "codex adapter without a command: exit 2" "2" "$TL_STATUS"

ec_stage_hooks "$TL_TMP/nolib" -
tl_run_stdin '{}' bash "$TL_TMP/nolib/hooks/cursor-hook-bridge.sh" preToolUse true
assert_eq "cursor bridge without its helper libraries: the missing runner is reported (127)" "127" "$TL_STATUS"
tl_run_stdin '{}' bash "$TL_TMP/nolib/hooks/codex-hook-adapter.sh" PreToolUse true
assert_eq "codex adapter without its helper libraries: the missing runner is reported (127)" "127" "$TL_STATUS"

# ---- subprocess timeouts ----------------------------------------------------
SB_CURSOR_HOOK_SUBPROC_TIMEOUT=0.3 tl_run_stdin '{"tool_name":"Shell","tool_input":{"command":"x"}}' bash "$CURSOR" preToolUse sleep 5
assert_eq "cursor bridge: a timed-out hook is not a failure" "0" "$TL_STATUS"
assert_contains "cursor bridge: timeout message" "$TL_OUT" "Silver Bullet hook subprocess timed out."
SB_CODEX_HOOK_SUBPROC_TIMEOUT=0.3 tl_run_stdin '{}' bash "$CODEX" PreToolUse sleep 5
assert_eq "codex adapter: a timed-out hook is not a failure" "0" "$TL_STATUS"
assert_contains "codex adapter: timeout message" "$TL_OUT" "Silver Bullet hook subprocess timed out."

# ---- industry tooling hint --------------------------------------------------
ec_project
ec_cfg '{"sb_initiated":true,"hooks":{"industry_tooling":{"enabled":true}}}'
mkdir -p "$EC_PROJ/infra/deep"
: >"$EC_PROJ/infra/main.tf"
bash_in() { jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
run_hint() { # cwd payload
  tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$1" "$HINT"
}
run_hint "$EC_PROJ/infra" "$(bash_in 'terraform apply')"
assert_contains "terraform hint found from a subdirectory (config walk-up)" "$TL_OUT" "terraform validate"
run_hint "$EC_PROJ/infra" "$(bash_in 'terraform validate && terraform apply')"
assert_eq "validated apply gets no hint" "" "$TL_OUT"
run_hint "$EC_PROJ/infra" ""
assert_eq "empty input: silent" "" "$TL_OUT"
run_hint "$EC_PROJ/infra" '{"tool_name":"Read","tool_input":{}}'
assert_eq "non-shell tool: silent" "" "$TL_OUT"
run_hint "$EC_PROJ/infra" '{"tool_name":"Bash","tool_input":{}}'
assert_eq "empty command: silent" "" "$TL_OUT"
ec_cfg '{"sb_initiated":true}'
run_hint "$EC_PROJ/infra" "$(bash_in 'terraform apply')"
assert_eq "hint disabled by default" "" "$TL_OUT"
ec_cfg '{"sb_initiated":true,"hooks":{"industry_tooling":{"enabled":true}}}'
printf '{}' >"$EC_PROJ/package.json"
run_hint "$EC_PROJ" "$(bash_in 'npm install')"
assert_contains "npm hint" "$TL_OUT" "npm audit"
run_hint "$EC_PROJ" "$(bash_in 'npm install && npm audit')"
assert_eq "audited install gets no hint" "" "$TL_OUT"
mkdir -p "$TL_TMP/plain"
rm -f "${SD:?}/project-root"
run_hint "$TL_TMP/plain" "$(bash_in 'npm install')"
assert_eq "outside an SB project: silent" "" "$TL_OUT"
PATH="$(tl_path_without jq)" run_hint "$EC_PROJ" "$(bash_in 'npm install')"
assert_eq "no jq: silent" "" "$TL_OUT"

# ---- long-output producers must not defeat grep -q under pipefail -------------
rm -rf "${EC_PROJ:?}/infra"
mkdir -p "$EC_PROJ/infra"
tl_stub find 'echo "$PWD/infra/main.tf"; head -c 300000 /dev/zero | tr "\\0" "x"; echo'
run_hint "$EC_PROJ/infra" "$(bash_in 'terraform apply')"
assert_contains "terraform hint survives a producer that keeps writing" "$TL_OUT" "terraform validate"
rm -f "${TL_BIN:?}/find"; hash -r

# ---- debug dump -------------------------------------------------------------
rm -f "${SD:?}/debug-dump" "${SD:?}/hook-dump.jsonl"
tl_run_stdin '{"a":1}' bash "$DUMP"
assert_file_absent "no flag: nothing dumped" "$SD/hook-dump.jsonl"
: >"$SD/debug-dump"
tl_run_stdin '{"a":1}' bash "$DUMP"
assert_eq "flag present: payload appended" '{"a":1}' "$(cat "$SD/hook-dump.jsonl")"
tl_run_stdin '{"b":2}' bash "$DUMP"
assert_eq "second payload appended" '{"b":2}' "$(tail -1 "$SD/hook-dump.jsonl")"
tl_run_stdin '' bash "$DUMP"
assert_eq "empty payload ignored" "2" "$(wc -l <"$SD/hook-dump.jsonl" | tr -d ' ')"
rm -f "${SD:?}/debug-dump" "${SD:?}/hook-dump.jsonl"
ln -s "$TL_TMP/target" "$SD/debug-dump"
tl_run_stdin '{"c":3}' bash "$DUMP"
assert_file_absent "symlinked flag is ignored" "$SD/hook-dump.jsonl"
rm -f "${SD:?}/debug-dump"

tl_results
