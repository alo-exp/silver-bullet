#!/usr/bin/env bash
# hooks/trivial-file-guard.sh: marker protection, config handling and fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/trivial-file-guard.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_AGENT_CERT_RUN
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
TRIVIAL="$SD/trivial"

write_in() { jq -cn --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p}}'; }
bash_in() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
run_tg() { # payload [hook]
  tl_run_stdin "$1" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "${2:-$HOOK}"
}
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT"; }

# ---- file writes ------------------------------------------------------------
run_tg "$(write_in "$TRIVIAL")"
assert_contains "direct write to the marker is denied" "$(reason)" "LEGACY TRIVIAL BYPASS BLOCKED"
run_tg "$(write_in "$SD/../$(basename "$SD")/trivial")"
assert_contains "path normalisation catches dot-dot spellings" "$(reason)" "LEGACY TRIVIAL BYPASS BLOCKED"
run_tg "$(write_in "$SD/other-file")"
assert_eq "other state files are allowed" "" "$TL_OUT"
run_tg '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"x"}}'
assert_eq "PostToolUse ignored" "" "$TL_OUT"
SB_AGENT_CERT_RUN=1 run_tg "$(write_in "$TRIVIAL")"
assert_eq "agent cert runs bypass the guard" "" "$TL_OUT"
run_tg '{"tool_name":"Bash","tool_input":{}}'
assert_eq "no path and no command: ignored" "" "$TL_OUT"
PATH="$(tl_path_without jq)" run_tg "$(write_in "$TRIVIAL")"
assert_eq "no jq: silent allow" "" "$TL_OUT"
run_tg '{"tool_name":"Write","tool_input":{"file_path":"'"$TRIVIAL"'"}}'
assert_contains "event defaults to PreToolUse" "$(reason)" "BLOCKED"

# ---- shell commands ---------------------------------------------------------
run_tg "$(bash_in "touch $TRIVIAL")"
assert_contains "touching the marker is denied" "$(reason)" "must not arm the trivial marker file from Bash"
run_tg "$(bash_in "echo 1 > $TRIVIAL")"
assert_contains "redirecting into the marker is denied" "$(reason)" "from Bash"
run_tg "$(bash_in "echo 1 >> $TRIVIAL")"
assert_contains "appending to the marker is denied" "$(reason)" "from Bash"
run_tg "$(bash_in "cat $TRIVIAL")"
assert_eq "reading the marker is allowed" "" "$TL_OUT"
run_tg "$(bash_in "touch ${TRIVIAL/#$HOME/~}")"
assert_contains "tilde spelling of the marker is denied" "$(reason)" "from Bash"
run_tg "$(bash_in "touch /somewhere/else")"
assert_eq "unrelated commands are allowed" "" "$TL_OUT"

# ---- configuration ----------------------------------------------------------
ec_cfg "$(jq -cn --arg t "$SD/custom-marker" '{sb_initiated:true,state:{trivial_file:$t}}')"
run_tg "$(write_in "$SD/custom-marker")"
assert_contains "configured marker is protected" "$(reason)" "BLOCKED"
run_tg "$(write_in "$TRIVIAL")"
assert_eq "default marker is not special once another is configured" "" "$TL_OUT"
ec_cfg '{"sb_initiated":true,"state":{"trivial_file":"/etc/outside-state-root"}}'
run_tg "$(write_in "$TRIVIAL")"
assert_contains "out-of-scope configured marker falls back to the default" "$(reason)" "BLOCKED"
ec_cfg "$(jq -cn --arg t "$SD/linked-marker" '{sb_initiated:true,state:{trivial_file:$t}}')"
ln -s "$TL_TMP/target" "$SD/linked-marker"
run_tg "$(write_in "$TRIVIAL")"
assert_contains "symlinked configured marker falls back to the default" "$(reason)" "BLOCKED"
rm -f "${SD:?}/linked-marker"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
printf 'not json' >"$EC_CFG"
run_tg "$(write_in "$TRIVIAL")"
assert_contains "unreadable config: default marker still protected" "$(reason)" "BLOCKED"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'

# ---- project discovery ------------------------------------------------------
mkdir -p "$EC_PROJ/a/b" "$TL_TMP/plain"
EC_RUN_DIR="$EC_PROJ/a/b"
run_tg "$(write_in "$TRIVIAL")"
assert_contains "project found from a subdirectory" "$(reason)" "BLOCKED"
EC_RUN_DIR="$TL_TMP/plain"
run_tg "$(write_in "$TRIVIAL")"
assert_eq "outside an SB project: allowed" "" "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"

# ---- fallbacks --------------------------------------------------------------
PATH="$(tl_path_without python3)" run_tg "$(write_in "$TRIVIAL")"
assert_contains "no python: raw path comparison still blocks" "$(reason)" "BLOCKED"
ec_stage_hooks "$TL_TMP/nolibs" tool-input.sh cert-bypass.sh sb-project-gate.sh project-active.sh
run_tg "$(write_in "$TRIVIAL")" "$TL_TMP/nolibs/hooks/trivial-file-guard.sh"
assert_contains "no tool-input lib: jq file_path extraction" "$(reason)" "BLOCKED"
run_tg "$(bash_in "touch $TRIVIAL")" "$TL_TMP/nolibs/hooks/trivial-file-guard.sh"
assert_contains "no tool-input lib: jq command extraction" "$(reason)" "from Bash"
SB_AGENT_CERT_RUN=1 run_tg "$(write_in "$TRIVIAL")" "$TL_TMP/nolibs/hooks/trivial-file-guard.sh"
assert_contains "no cert-bypass lib: bypass is not applied" "$(reason)" "BLOCKED"
sb_project_is_initiated() { return 1; }
export -f sb_project_is_initiated
run_tg "$(write_in "$TRIVIAL")" "$TL_TMP/nolibs/hooks/trivial-file-guard.sh"
assert_eq "inherited initiated check rejecting: allowed" "" "$TL_OUT"
unset -f sb_project_is_initiated

tl_results
