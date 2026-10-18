#!/usr/bin/env bash
# Fault injection for session-log-init, timeout-check, compliance-status and prompt-reminder.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT PROJECT_ROOT_OVERRIDE SESSION_LOG_TEST_DIR SENTINEL_SLEEP_OVERRIDE SB_WORKFLOW_ID SILVER_BULLET_DEBUG_HOOK_EVENTS
R="$TL_REPO_ROOT/hooks"
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
CUR_VER="$(jq -r .config_version "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"
hook() { # script cwd payload [copy]
  tl_run_stdin "$3" bash -c 'cd "$1" && exec bash "$2"' _ "$2" "${4:-$R/$1}"
}
mkdir -p "$TL_TMP/plain"
SLEEPERS=()
cleanup_procs() {
  local p
  for p in "${SLEEPERS[@]}"; do kill "$p" 2>/dev/null || true; done
  if [[ -f "$SD/sentinel-pid" ]]; then kill "$(cut -d: -f1 "$SD/sentinel-pid")" 2>/dev/null || true; fi
  tl_cleanup
}
trap cleanup_procs EXIT
# A PID that has just exited and been reaped. A hard-coded PID such as 999999 can name a live
# process of the same user (on a CI runner, the runner itself), which the legacy sentinel
# format and the EXIT cleanup above would kill.
dead_pid() { local p; ( exit 0 ) & p=$!; wait "$p" 2>/dev/null || true; echo "$p"; }

# ======== session-log-init =====================================================
TODAY="2026-01-15"
ec_freeze_date "$TODAY"
SESS="$EC_PROJ/docs/sessions"
SL_IN="$(jq -cn --arg c "echo autonomous > $SB_RUNTIME_HOME_ROOT/.silver-bullet/mode" '{tool_name:"Bash",tool_input:{command:$c}}')"
sl_reset() {
  local f
  rm -rf "${SESS:?}"
  for f in mode sentinel-pid timeout session-start-time timeout-warn-count session-log-path; do rm -f "${SD:?}/${f:?}"; done
  for f in "$SD"/sentinel-lock-*; do [[ -e "$f" ]] && rm -f "$f"; done
  ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
}
ec_stage_hooks "$TL_TMP/noti" tool-input.sh
sl_reset
ec_fail jq '*".tool_name"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN" "$TL_TMP/noti/hooks/session-log-init.sh"
ec_unfail jq
assert_contains "log: unreadable tool name (plain extraction) is tolerated" "$TL_OUT" "Session log created"
ec_fail jq '*".tool_input.command"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN" "$TL_TMP/noti/hooks/session-log-init.sh"
ec_unfail jq
assert_eq "log: unreadable command: nothing created" "" "$TL_OUT"

# an unreadable sentinel pid file is treated as no sentinel
sl_reset
printf '%s\n' "$(dead_pid)" >"$SD/sentinel-pid"
ec_fail cat '*"sentinel-pid"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail cat
assert_contains "log: unreadable sentinel pid: log still created" "$TL_OUT" "Session log created"
# kill failing on an owned sentinel, legacy and tokenised
for variant in legacy token; do
  sl_reset
  sleep 300 &
  old=$!
  SLEEPERS+=("$old")
  if [[ "$variant" == legacy ]]; then printf '%s\n' "$old" >"$SD/sentinel-pid"; else printf '%s:tk\n' "$old" >"$SD/sentinel-pid"; : >"$SD/sentinel-lock-tk"; fi
  kill() { if [[ "${1:-}" == "-0" ]]; then builtin kill "$@"; else return 1; fi; }
  export -f kill
  hook session-log-init.sh "$EC_PROJ" "$SL_IN"
  unset -f kill
  assert_contains "log: kill failing ($variant sentinel): log still created" "$TL_OUT" "Session log created"
  kill "$old" 2>/dev/null || true
done
# rm failing during sentinel cleanup
sl_reset
printf '%s\n' "$(dead_pid)" >"$SD/sentinel-pid"
ec_fail rm '*"sentinel-lock-"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail rm
assert_contains "log: failing sentinel cleanup: log still created" "$TL_OUT" "Session log created"
# find failing means no existing log is seen
sl_reset
ec_fail find '*"-maxdepth 1"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail find
assert_contains "log: find failing: a new log is created" "$TL_OUT" "Session log created"
# autonomous: the sentinel actually fires, uuid sources both unavailable, lock failure
sl_reset
printf 'autonomous' >"$SD/mode"
SENTINEL_SLEEP_OVERRIDE=0 hook session-log-init.sh "$EC_PROJ" "$SL_IN"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [[ -f "$SD/timeout" ]] && break; sleep 0.1; done
assert_eq "log: the sentinel wrote its timeout flag" "TIMEOUT" "$(cat "$SD/timeout")"
rm -f "${SD:?}/timeout"
# existing autonomous log: restart path
tl_stub uuidgen 'exit 1'
REAL_CAT="$(command -v cat)"
tl_stub cat "for a in \"\$@\"; do case \"\$a\" in /proc/*) exit 1;; esac; done; exec $REAL_CAT \"\$@\""
rm -f "${SD:?}/sentinel-pid"
SENTINEL_SLEEP_OVERRIDE=0 hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail uuidgen; ec_unfail cat
assert_match "log: restart token falls back to pid-time" '^[0-9]+:[0-9]+-[0-9]+$' "$(cat "$SD/sentinel-pid")"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [[ -f "$SD/timeout" ]] && break; sleep 0.1; done
assert_eq "log: the restarted sentinel fired" "TIMEOUT" "$(cat "$SD/timeout")"
rm -f "${SD:?}/timeout" "${SD:?}/sentinel-pid"
tl_stub touch 'exit 1'
kill() { if [[ "${1:-}" == "-0" ]]; then builtin kill "$@"; else return 1; fi; }
export -f kill
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail touch
assert_file_absent "log: lock creation failing on restart: no pid file" "$SD/sentinel-pid"
# same failure on first creation of an autonomous log
sl_reset
printf 'autonomous' >"$SD/mode"
tl_stub touch 'exit 1'
SENTINEL_SLEEP_OVERRIDE=0 hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail touch
unset -f kill
assert_file_absent "log: lock creation failing on creation: no pid file" "$SD/sentinel-pid"
ec_fail awk '*"Timeout sentinel restarted"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail awk
assert_contains "log: restart note awk failing: still reports the existing log" "$TL_OUT" "already exists"
rm -f "${SD:?}/sentinel-pid"
# mode file unreadable
sl_reset
printf 'autonomous' >"$SD/mode"
ec_fail cat '*"/mode"*'
hook session-log-init.sh "$EC_PROJ" "$SL_IN"
ec_unfail cat
assert_contains "log: unreadable mode file: interactive default" "$(cat "$(find "$SESS" -name "${TODAY}*.md" | head -1)")" "**Mode:** interactive"
# pre-existing symlink where the new log would be written (sb_safe_write via the fallback guard)
sl_reset
mkdir -p "$SESS"
ec_stage_hooks "$TL_TMP/noguard" nofollow-guard.sh
REAL_DATE="$(PATH="${PATH#"$TL_BIN":}" command -v date)"
tl_stub date "if [[ \"\$1\" == \"+%H-%M-%S\" ]]; then echo 01-02-03; elif [[ \"\$1\" == \"+%Y-%m-%d\" ]]; then echo $TODAY; else exec $REAL_DATE \"\$@\"; fi"
tl_stub find 'exit 0'
printf 'precious' >"$TL_TMP/log-target"
ln -s "$TL_TMP/log-target" "$SESS/${TODAY}-01-02-03.md"
hook session-log-init.sh "$EC_PROJ" "$SL_IN" "$TL_TMP/noguard/hooks/session-log-init.sh"
ec_freeze_date "$TODAY"; ec_unfail find
assert_eq "log: symlinked target untouched" "precious" "$(cat "$TL_TMP/log-target")"
if [[ -L "$SESS/${TODAY}-01-02-03.md" ]]; then tl_fail "log: the symlink was replaced by a regular file"; else tl_pass "log: the symlink was replaced by a regular file"; fi

# ======== timeout-check ========================================================
tc_reset() {
  local f
  for f in mode session-start-time timeout call-count last-progress-call last-state-mtime state stall-block timeout-warn-count; do rm -f "${SD:?}/${f:?}"; done
  printf 'autonomous' >"$SD/mode"
  printf '1000' >"$SD/session-start-time"
}
ec_stage_hooks "$TL_TMP/nolib" -
tc_reset
hook timeout-check.sh "$EC_PROJ" '{}' "$TL_TMP/nolib/hooks/timeout-check.sh"
assert_eq "timeout: no lib directory fails open and silently" "0:" "$TL_STATUS:$TL_OUT"
tc_reset
ec_fail cat '*"/mode"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable mode file means not autonomous" "" "$TL_OUT"
assert_file_absent "timeout: unreadable mode file: no counters" "$SD/call-count"
tc_reset
printf '5' >"$SD/call-count"; printf '3' >"$SD/last-progress-call"; printf '1' >"$SD/last-state-mtime"; printf 'TIMEOUT' >"$SD/timeout"; printf '4' >"$SD/timeout-warn-count"
for f in call-count last-progress-call last-state-mtime timeout-warn-count; do touch -d @5000 "$SD/$f"; done
ec_fail cat '*"call-count"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable counter restarts from zero" "1" "$(cat "$SD/call-count")"
# a state file newer than the recorded baseline: the progress baseline must be rewritten after an unreadable counter
printf 'silver-plan\n' >"$SD/state"
STATE_MTIME="$(stat -c %Y "$SD/state" 2>/dev/null || stat -f %m "$SD/state")"
ec_fail cat '*"last-progress-call"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable progress counter: baseline mtime recorded" "$STATE_MTIME" "$(cat "$SD/last-state-mtime")"
assert_eq "timeout: unreadable progress counter restarts from zero" "$(cat "$SD/call-count")" "$(cat "$SD/last-progress-call")"
printf '1' >"$SD/last-state-mtime"; touch -d @5000 "$SD/last-state-mtime"
printf '3' >"$SD/last-progress-call"; touch -d @5000 "$SD/last-progress-call"
ec_fail cat '*"last-state-mtime"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable state baseline: baseline mtime recorded" "$STATE_MTIME" "$(cat "$SD/last-state-mtime")"
assert_eq "timeout: unreadable state baseline: progress rewritten to the call count" "$(cat "$SD/call-count")" "$(cat "$SD/last-progress-call")"
ec_fail cat '*"timeout-warn-count"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable warn counter restarts" "1" "$(cat "$SD/timeout-warn-count")"
ec_fail stat '*"--format"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail stat
assert_eq "timeout: stat failing: exit 0" "0" "$TL_STATUS"
assert_eq "timeout: stat failing: the call counter is still maintained" "1" "$(cat "$SD/call-count" 2>/dev/null)"
tc_reset
ec_fail cat '*"session-start-time"*'
hook timeout-check.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_eq "timeout: unreadable session start: silent" "" "$TL_OUT"

# ======== compliance-status ====================================================
cs_reset() {
  local f
  rm -f "${SD:?}/state" "${SD:?}/mode"
  for f in "$SD"/config-cache-*; do [[ -e "$f" ]] && rm -f "$f"; done
  ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,skills:{required_planning:["silver-context"]}}')"
}
cs_reset
printf 'silver-context\n' >"$SD/state"
export SILVER_BULLET_DEBUG_HOOK_EVENTS=1
ec_fail mkdir '*"-p"*'
hook compliance-status.sh "$EC_PROJ" '{"hook_event_name":"PostToolUse","tool_name":"Bash"}'
ec_unfail mkdir
assert_contains "compliance: debug mkdir failing: summary still printed" "$TL_OUT" "Silver Bullet:"
ec_fail jq '*"hook_event_name"*'
hook compliance-status.sh "$EC_PROJ" '{"hook_event_name":"PostToolUse","tool_name":"Bash"}'
ec_unfail jq
assert_contains "compliance: debug event name unreadable: summary still printed" "$TL_OUT" "Silver Bullet:"
ec_fail jq '*".tool_name"*'
hook compliance-status.sh "$EC_PROJ" '{"hook_event_name":"PostToolUse","tool_name":"Bash"}'
ec_unfail jq
assert_contains "compliance: debug jq failing: summary still printed" "$TL_OUT" "Silver Bullet:"
rm -f "$SD/hook-events.debug.log"
mkdir -p "$SD/hook-events.debug.log"
hook compliance-status.sh "$EC_PROJ" '{"hook_event_name":"PostToolUse"}'
rmdir "$SD/hook-events.debug.log"
assert_contains "compliance: unwritable debug sink: summary still printed" "$TL_OUT" "Silver Bullet:"
assert_eq "compliance: unwritable debug sink: no diagnostics" "" "$TL_ERR"
tl_run bash -c 'cd "$1" && exec bash "$2" <"$3"' _ "$EC_PROJ" "$R/compliance-status.sh" "$TL_TMP"
unset SILVER_BULLET_DEBUG_HOOK_EVENTS
assert_eq "compliance: unreadable stdin with debug on: exit 0" "0" "$TL_STATUS"
assert_contains "compliance: unreadable stdin with debug on: summary still printed" "$TL_OUT" "Silver Bullet:"
cs_reset
printf 'silver-context\n' >"$SD/state"
tl_stub md5 'cat >/dev/null; echo fixedhash'
hook compliance-status.sh "$EC_PROJ" '{}'
ec_fail stat '*"-c"*'
hook compliance-status.sh "$EC_PROJ" '{}'
ec_unfail stat
assert_contains "compliance: cached config mtime unreadable: summary still printed" "$TL_OUT" "Silver Bullet:"
rm -f "${SD:?}/config-cache-fixedhash"
ec_fail stat '*"-c"*'
hook compliance-status.sh "$EC_PROJ" '{}'
ec_unfail stat
assert_contains "compliance: config mtime unreadable on first run: summary still printed" "$TL_OUT" "Silver Bullet:"
ec_unfail md5
cs_reset
printf '' >"$SD/state"
hook compliance-status.sh "$EC_PROJ" '{}'
assert_contains "compliance: empty state file: zero steps" "$TL_OUT" "0 steps"
printf 'autonomous' >"$SD/mode"
ec_fail cat '*"/mode"*'
hook compliance-status.sh "$EC_PROJ" '{}'
ec_unfail cat
assert_contains "compliance: unreadable mode file: interactive" "$TL_OUT" "Mode: interactive"
ec_flaky_fn sb_project_active 1
hook compliance-status.sh "$EC_PROJ" '{}'
unset -f sb_project_active
assert_eq "compliance: a failing project check is silent" "" "$TL_OUT"

cs_reset
hook compliance-status.sh "$EC_PROJ" '{}' "$TL_TMP/nolib/hooks/compliance-status.sh"
assert_eq "compliance: no lib directory: exit 0" "0" "$TL_STATUS"

# ======== prompt-reminder ======================================================
pr_cfg() { ec_cfg "$(jq -cn --arg v "$CUR_VER" --argjson x "${1:-{\}}" '{config_version:$v,sb_initiated:true} * $x')"; }
pr_reset() {
  local f
  for f in state trivial session-rules-injected orchestrator.json orchestrator-directive.json outcomes-session.json ups-coalesce-turn ups-coalesce-seen; do rm -f "${SD:?}/${f:?}"; done
  rm -rf "${EC_PROJ:?}/.planning"
  pr_cfg '{"skills":{"required_planning":["silver-quality-gates"]}}'
}
prompt() { jq -cn --arg p "$1" '{prompt:$p}'; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
pr_reset
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'carry on')" "$TL_TMP/nolib/hooks/prompt-reminder.sh"
assert_eq "reminder: no lib directory: no-op payload" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$(jq -c . <<<"$TL_OUT")"
# adapter path when the package root cannot be resolved
pr_reset
cd() {
  case "${1:-}" in */lib/../..) return 1 ;; esac
  builtin cd "$@"
}
export -f cd
SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_RUNTIME=codex hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'please fix the failing login test')"
unset -f cd
assert_contains "reminder: package root unresolved: falls back to the bare command" "$(ctx)" '"silver-bullet" invoke-skill sb'
pr_reset
tl_run bash -c 'cd "$1" && exec bash "$2" <"$3"' _ "$EC_PROJ" "$R/prompt-reminder.sh" "$TL_TMP"
assert_contains "reminder: unreadable stdin: still answers" "$TL_OUT" "UserPromptSubmit"
pr_reset
ec_fail jq '*".prompt"*'
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'ship it')"
ec_unfail jq
assert_contains "reminder: unreadable prompt: planning floor shown" "$(ctx)" "planning floor"
pr_reset
ec_flaky_fn sb_project_active 1
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'x')"
unset -f sb_project_active
assert_eq "reminder: failing project check: no-op payload" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$(jq -c . <<<"$TL_OUT")"
# delivery tier without the required-skills lib and without configured deploy skills
ec_stage_hooks "$TL_TMP/norsl" required-skills.sh
pr_reset
pr_cfg '{}'
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'ship it')" "$TL_TMP/norsl/hooks/prompt-reminder.sh"
assert_contains "reminder: delivery tier with no lists at all still answers" "$(ctx)" "Silver Bullet"
# a directory named like a workflow file is ignored
pr_reset
mkdir -p "$EC_PROJ/.planning/workflows/dir.md" "$EC_PROJ/.planning/workflows"
printf x >"$EC_PROJ/.planning/workflows/real.md"
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'continue')"
assert_contains "reminder: only regular workflow files are listed" "$(ctx)" "Active composed workflows: real"
assert_not_contains "reminder: directories are skipped" "$(ctx)" "dir.md"
# helper libraries that return nothing
ec_stage_hooks "$TL_TMP/helpers" orchestrator-state.sh orchestrator-directive.sh graphify-gate.sh agentmemory-gate.sh token-compression-tools-gate.sh stack-optimizer.sh
HL="$TL_TMP/helpers/hooks/lib"
printf '%s\n' 'sb_orchestrator_sync_directive_from_state() { return 1; }' >"$HL/orchestrator-state.sh"
printf '%s\n' 'sb_orchestrator_directive_context_block() { return 1; }' 'sb_orchestrator_directive_from_pending_outcome() { return 1; }' >"$HL/orchestrator-directive.sh"
printf '%s\n' 'sb_graphify_required() { return 0; }' 'sb_graphify_prompt_reminder_line() { return 1; }' >"$HL/graphify-gate.sh"
printf '%s\n' 'sb_agentmemory_required() { return 0; }' 'sb_agentmemory_prompt_reminder_line() { return 1; }' >"$HL/agentmemory-gate.sh"
printf '%s\n' 'sb_token_tool_enforced() { return 0; }' 'sb_token_tool_usage_is_fresh() { return 1; }' 'sb_token_tool_prompt_reminder_line() { return 1; }' >"$HL/token-compression-tools-gate.sh"
printf '%s\n' 'sb_stack_optimization_prompt_line() { return 1; }' >"$HL/stack-optimizer.sh"
pr_reset
printf '{}' >"$SD/outcomes-session.json"
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'carry on with the parser')" "$TL_TMP/helpers/hooks/prompt-reminder.sh"
assert_contains "reminder: helper libraries returning nothing: planning floor still shown" "$(ctx)" "planning floor"
# core rules whose directory resolves elsewhere on the second look
pr_reset
rm -f "$TL_TMP/cd-count"
cd() {
  case "${1:-}" in */hooks) echo $(( $(cat "$TL_TMP/cd-count" 2>/dev/null || echo 0) + 1 )) >"$TL_TMP/cd-count" ;; esac
  builtin cd "$@"
}
pwd() {
  if [[ "$(cat "$TL_TMP/cd-count" 2>/dev/null || echo 0)" -ge 2 ]]; then printf '/elsewhere'; else builtin pwd "$@"; fi
}
export -f cd pwd
export TL_TMP
hook prompt-reminder.sh "$EC_PROJ" "$(prompt 'continue')"
unset -f cd pwd
assert_not_contains "reminder: rules resolving outside the plugin dir are not injected" "$(ctx)" "Non-Negotiable Rules"

tl_results
