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

# ---- shell commands: every spelling of the marker (R2-05) -------------------
run_tg "$(bash_in "touch $TRIVIAL")"
assert_contains "touching the marker is denied" "$(reason)" "LEGACY TRIVIAL BYPASS BLOCKED"
run_tg "$(bash_in "echo 1 > $TRIVIAL")"
assert_contains "redirecting into the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "echo 1 >> $TRIVIAL")"
assert_contains "appending to the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "cat $TRIVIAL")"
assert_eq "reading the marker is allowed" "" "$TL_OUT"
run_tg "$(bash_in 'touch ~/'"${TRIVIAL#"$HOME"/}")"
assert_contains "literal ~ spelling of the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in 'touch "$HOME/'"${TRIVIAL#"$HOME"/}"'"')"
assert_contains "literal \$HOME spelling of the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in 'touch ${HOME}/'"${TRIVIAL#"$HOME"/}")"
assert_contains "literal \${HOME} spelling of the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "cd $SD && touch trivial")"
assert_contains "cd to the state dir then touch trivial is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "cd $SD && : > trivial")"
assert_contains "cd then redirect into trivial is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "cp /dev/null $TRIVIAL")"
assert_contains "cp onto the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "mv $SD/state $TRIVIAL")"
assert_contains "mv onto the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "ln -s /dev/null $TRIVIAL")"
assert_contains "ln onto the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "printf x | tee $TRIVIAL")"
assert_contains "tee into the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "python3 -c \"open('$TRIVIAL','w').close()\"")"
assert_contains "an interpreter one-liner naming the marker is denied" "$(reason)" "BLOCKED"
run_tg "$(bash_in "python3 -c \"open(__import__('os').path.expanduser('~/.claude/.silver-bullet/'+'triv'+'ial'),'w')\"")"
assert_contains "string-built paths in one-liners are refused as code that cannot be read" "$(reason)" "cannot inspect this command"
run_tg "$(bash_in "python3 -c \"import shutil; shutil.copy('a', '/x/.claude/.silver-bullet/trivial')\"")"
assert_contains "a one-liner that names silver-bullet/trivial is blocked" "$(reason)" "BLOCKED"
run_tg "$(bash_in "touch /somewhere/else")"
assert_eq "unrelated commands are allowed" "" "$TL_OUT"
run_tg "$(bash_in "touch $SD/session-init")"
assert_eq "other state sentinels are not this guard's business" "" "$TL_OUT"
run_tg "$(bash_in "git commit -m 'drop the trivial marker docs'")"
assert_eq "prose that merely says trivial is allowed" "" "$TL_OUT"
run_tg "$(bash_in "echo trivial > notes.txt")"
assert_eq "a file named notes.txt is allowed" "" "$TL_OUT"
run_tg "$(bash_in "python3 -c 'print(1)'")"
assert_eq "an opaque writer that does not name the marker is allowed" "" "$TL_OUT"
assert_eq "the deny is one JSON document" 1 "$(run_tg "$(bash_in "touch $TRIVIAL")"; jq -s length <<<"$TL_OUT")"

# ---- configuration: a configured marker is never honoured, writing it is refused too ------
ec_cfg "$(jq -cn --arg t "$SD/custom-marker" '{sb_initiated:true,state:{trivial_file:$t}}')"
run_tg "$(write_in "$SD/custom-marker")"
assert_contains "configured marker is protected" "$(reason)" "BLOCKED"
run_tg "$(write_in "$TRIVIAL")"
assert_contains "the default marker stays protected when another is configured" "$(reason)" "BLOCKED"
ec_cfg '{"sb_initiated":true,"state":{"trivial_file":"/etc/outside-state-root"}}'
run_tg "$(write_in "$TRIVIAL")"
assert_contains "out-of-scope configured marker: the default is still protected" "$(reason)" "BLOCKED"
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

# ---- review repair: ancestor writes, unseen commands, truncated payloads ---------------------
FAKE="$TL_TMP/fake"; mkdir -p "$FAKE/.silver-bullet"; : >"$FAKE/.silver-bullet/trivial"
for c in "cp -r $FAKE/.silver-bullet $HOME/.${SB_RUNTIME_NAME}/" "cp -a $FAKE/.silver-bullet $HOME/.${SB_RUNTIME_NAME}/" "rsync -a $FAKE/ $HOME/.${SB_RUNTIME_NAME}/" "tar -xf s.tar -C $HOME" "unzip -o s.zip -d $HOME" "mv $FAKE/.silver-bullet $HOME/.${SB_RUNTIME_NAME}/"; do
  run_tg "$(bash_in "$c")"
  assert_contains "ancestor write arms the marker: $c" "$(reason)" "BLOCKED"
done
for c in "cp settings.json $HOME/.${SB_RUNTIME_NAME}/" "rsync -a build/ out/" "mkdir -p $HOME/.${SB_RUNTIME_NAME}"; do
  run_tg "$(bash_in "$c")"
  assert_eq "an honest write passes: $c" "" "$TL_OUT"
done
PADF="$TL_TMP/pad.txt"; head -c 600000 /dev/zero | tr '\0' 'a' >"$PADF"
run_tg "$(jq -cn --arg t "$TRIVIAL" --rawfile pad "$PADF" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:("touch " + $t + "; # " + $pad)}}')"
assert_contains "an over-budget command is refused" "$(reason)" "cannot inspect this command"
run_tg "$(bash_in 'eval "$X"')"
assert_contains "eval of computed text is refused" "$(reason)" "cannot inspect this command"
run_tg "$(bash_in 'npm test')"
assert_eq "an ordinary command passes" "" "$TL_OUT"
run_tg '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"touch /x/trivial'
assert_contains "a truncated payload that names the marker fails closed" "$(reason)" "cannot inspect"

# ---- python3 missing: the analysis helper is unavailable --------------------
NOPY="$(tl_path_without python3)"
PATH="$NOPY" run_tg "$(bash_in "touch $TRIVIAL")"
assert_contains "no python3: a command naming the marker is refused with the fix" "$(reason)" "python3"
PATH="$NOPY" run_tg "$(bash_in "ls -la")"
assert_eq "no python3: a command that does not name it is allowed silently" "" "$TL_OUT"
PATH="$NOPY" run_tg "$(bash_in "cat $TRIVIAL")"
assert_eq "no python3: a plainly read-only command gets no message" "" "$TL_OUT"
PATH="$NOPY" run_tg "$(write_in "$TRIVIAL")"
assert_contains "no python3: a Write to the marker is refused" "$(reason)" "python3"
run_tg "$(bash_in "echo 'unterminated trivial")"
assert_contains "an unparsable command naming the marker fails closed" "$(reason)" "cannot inspect"

tl_run_stdin "$(write_in "$TRIVIAL")" bash -c 'sb_project_active() { return 1; }; export -f sb_project_active; cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_eq "a project reported inactive: the guard stands down" "" "$TL_OUT"

tl_results
