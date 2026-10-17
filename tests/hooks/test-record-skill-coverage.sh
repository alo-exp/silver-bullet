#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh (PostToolUse Skill/Bash skill-state recorder)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project

HOOK=hooks/record-skill.sh
STATE="$SB_RUNTIME_STATE_DIR/state"
LOADED="$STATE.loaded"
DIRECTIVE="$SB_RUNTIME_STATE_DIR/orchestrator-directive.json"
RECEIPTS="$SB_RUNTIME_STATE_DIR/skill-invocations"
LOG_PATH_FILE="$TL_TMP/session-log-path"
SESSION_LOG="$TG2_PROJ/docs/sessions/log.md"
REAL_PY="$(command -v python3)"
REAL_JQ="$(command -v jq)"
REAL_GREP="$(command -v grep)"
REAL_CAT="$(command -v cat)"
BASE_CFG='{"sb_initiated":true}'

reset() {
  rm -rf "$STATE" "$LOADED" "$DIRECTIVE" "$RECEIPTS" "$SB_RUNTIME_STATE_DIR/project-root" \
    "$SB_RUNTIME_STATE_DIR/record-skill.debug.log" "$TG2_PROJ/.planning"
  tg2_cfg "$BASE_CFG"
}
skill_input() { jq -cn --arg s "$1" '{hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$s}}'; }
bash_input() { # command [tool] [exit_code]
  jq -cn --arg c "$1" --arg t "${2:-Bash}" --argjson x "${3:-0}" \
    '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:{command:$c}, tool_response:{exit_code:$x}}'
}
rs() { tg2_run "$HOOK" "$1" SILVER_BULLET_SESSION_LOG_PATH_FILE="$LOG_PATH_FILE" "${@:2}"; }
msg() { printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message // ""' 2>/dev/null || true; }
lines() { [[ -f "$1" ]] && cat "$1" || true; }
in_state() { grep -Fqx -- "$2" "$1" 2>/dev/null; }
assert_in() { # name file line
  if in_state "$2" "$3"; then tl_pass "$1"; else tl_fail "$1 ('$3' not in $2: $(lines "$2" | tr '\n' ' '))"; fi
}
assert_not_in() {
  if in_state "$2" "$3"; then tl_fail "$1 ('$3' unexpectedly in $2)"; else tl_pass "$1"; fi
}
RECORDED="✅ Skill recorded"
NOTHING="ℹ️ No completed tracked skill invocation found"

# python3 wrapper failing only for `python3 -c ...` (cwd resolution), grep/jq/cat fault stubs
tl_stub python3 "if [[ -n \"\${PY_NO_C:-}\" && \"\${1:-}\" == -c ]]; then exit 1; fi
exec $REAL_PY \"\$@\""
tl_stub jq "if [[ -n \"\${JQ_FAIL:-}\" && \"\$*\" == *\"\$JQ_FAIL\"* ]]; then exit 1; fi
exec $REAL_JQ \"\$@\""
tl_stub grep "if [[ -n \"\${GREP_EXTRA:-}\" && \"\${1:-}\" == -oE ]]; then printf '%b' \"\$GREP_EXTRA\"; fi
exec $REAL_GREP \"\$@\""
tl_stub cat "if [[ -n \"\${CAT_FAIL:-}\" && \"\${1:-}\" == \"\$CAT_FAIL\" ]]; then exit 1; fi
exec $REAL_CAT \"\$@\""

# ===================================================== recording completed skills
reset; rs "$(skill_input silver-context)"
assert_eq "tracked skill: status" "0" "$TL_STATUS"
assert_eq "tracked skill: message" "$RECORDED" "$(msg)"
assert_in "tracked skill is appended to the state file" "$STATE" silver-context
reset; rs "$(skill_input silver-context)"; rs "$(skill_input silver-context)"
assert_eq "re-recording a skill is reported as nothing new" "$NOTHING" "$(msg)"
assert_eq "re-recording does not duplicate the state line" "1" "$(grep -Fxc silver-context "$STATE")"
reset; rs "$(skill_input some-untracked-skill)"
assert_eq "untracked skill is reported as nothing recorded" "$NOTHING" "$(msg)"
assert_file_absent "untracked skill creates no state file" "$STATE"
reset; rs "$(skill_input plugin:ns:silver-plan)"
assert_in "namespace prefixes are stripped" "$STATE" silver-plan
reset; rs "$(skill_input sb:feature)"
assert_in "sb:feature is canonicalised to silver-feature" "$STATE" silver-feature
reset; rs "$(skill_input silver-tdd)"
assert_in "silver-tdd is recorded as the canonical tdd marker" "$STATE" tdd
reset; rs "$(skill_input test-driven-development)"
assert_in "test-driven-development is recorded as the canonical tdd marker" "$STATE" tdd
reset; jq '.skills.all_tracked=["my-custom-skill"]' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input my-custom-skill)"
assert_in "custom tracked skills from the project config are recorded" "$STATE" my-custom-skill
rs "$(skill_input silver-plan)"
assert_in "custom tracked skills are additive to the packaged defaults" "$STATE" silver-plan

# --------------------------------------------------- quality-gates mode markers
reset; rs "$(skill_input silver-quality-gates)"
assert_in "silver-quality-gates is recorded" "$STATE" silver-quality-gates
assert_in "pre-plan quality gates add the design marker" "$STATE" silver-quality-gates-design
reset; mkdir -p "$TG2_PROJ/.planning"
printf '# Plan\n\nreal body\n' >"$TG2_PROJ/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TG2_PROJ/.planning/VERIFICATION.md"
rs "$(skill_input silver-quality-gates)"
assert_in "verified plan switches quality gates to adversarial mode" "$STATE" silver-quality-gates-adversarial
reset; rs "$(skill_input devops-quality-gates)"
assert_in "devops quality gates add the devops design marker" "$STATE" devops-quality-gates-design
reset; mkdir -p "$TG2_PROJ/.planning"
printf '# Plan\n\nreal body\n' >"$TG2_PROJ/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TG2_PROJ/.planning/VERIFICATION.md"
rs "$(skill_input devops-quality-gates)"
assert_in "devops quality gates add the adversarial marker when verified" "$STATE" devops-quality-gates-adversarial
reset; rm -f "$TG2_CFG" "$TG2_PROJ/silver-bullet.md"; mkdir -p "$TL_TMP/outside/.planning"
printf '# Plan\n\nreal body\n' >"$TL_TMP/outside/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TL_TMP/outside/.planning/VERIFICATION.md"
TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" rs "$(skill_input silver-quality-gates)"
assert_in "without a project config quality-gates mode is read from the cwd" "$STATE" silver-quality-gates-adversarial
rm -f "$STATE"
TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" rs "$(skill_input devops-quality-gates)"
assert_in "without a project config devops mode is read from the cwd" "$STATE" devops-quality-gates-adversarial
printf '# Silver Bullet\n' >"$TG2_PROJ/silver-bullet.md"
reset; tg2_farm no-qg "$HOOK" quality-gates-mode.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)"
assert_in "without the mode library the plain marker is still recorded" "$STATE" silver-quality-gates
assert_not_in "without the mode library no mode marker is added" "$STATE" silver-quality-gates-design
TG2_REPO="$TG2_FARM" rs "$(skill_input devops-quality-gates)"
assert_not_in "without the mode library no devops mode marker is added" "$STATE" devops-quality-gates-design

# ------------------------------------------------------------- SKILL.md reads
reset; rs "$(bash_input 'cat /plugins/silver-bullet/skills/silver-plan/SKILL.md')"
assert_eq "reading SKILL.md is not a completed skill" "$NOTHING" "$(msg)"
assert_in "reading SKILL.md records loaded-only metadata" "$LOADED" silver-plan
assert_file_absent "reading SKILL.md leaves the completed state untouched" "$STATE"
rs "$(bash_input 'cat /p/skills/silver-plan/SKILL.md')"
assert_eq "loaded marker is not duplicated" "1" "$(grep -Fxc silver-plan "$LOADED")"
reset; rs "$(bash_input 'head -5 "/x/skills/silver-context/SKILL.md"; tail (/y/skills/silver-plan/SKILL.md)' exec_command)"
assert_in "double-quoted/parenthesised SKILL.md tokens are normalised" "$LOADED" silver-context
assert_in "parenthesised token is normalised" "$LOADED" silver-plan
reset; rs "$(bash_input "cat '/x/skills/silver-feature/SKILL.md'")"
assert_in "single-quoted SKILL.md token is normalised" "$LOADED" silver-feature
reset; rs "$(bash_input 'cat /x/skills/not-tracked-thing/SKILL.md')"
assert_file_absent "untracked skill reads are not recorded as loaded" "$LOADED"
reset; rs "$(bash_input 'cat ./SKILL.md')"
assert_file_absent "SKILL.md outside a skills/<name>/ dir is ignored" "$LOADED"
reset; rs "$(bash_input 'echo SKILL.md')"
assert_eq "a bare SKILL.md mention (no message)" "" "$TL_OUT"
reset; rs "$(bash_input 'ls -la')"
assert_eq "an ordinary shell command (no message)" "" "$TL_OUT"
reset; rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md' Read)"
assert_eq "non-shell tools without a skill name record nothing (no message)" "" "$TL_OUT"
reset; rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')" GREP_EXTRA='\n/other/path\n'
assert_in "blank and non-SKILL.md tokens from grep are skipped" "$LOADED" silver-plan

# ----------------------------------------------------------- invoke-skill adapter
write_receipt() { # canonical-skill [age-seconds] [cwd] [file]
  local skill="$1" age="${2:-0}" cwd="${3:-$TG2_PROJ}" file="${4:-r1.json}"
  mkdir -p "$RECEIPTS"
  jq -cn --arg s "$skill" --arg cwd "$cwd" --argjson ts "$(( $(date +%s) - age ))" \
    '{channel:"silver-bullet.invoke-skill", status:"loaded", canonical_skill:$s, cwd:$cwd,
      timestamp_epoch:$ts, skill_file:"/x/SKILL.md", script:"/x/silver-bullet"}' >"$RECEIPTS/$file"
}
ADAPTER='bash /x/scripts/silver-bullet invoke-skill sb:plan'
reset; rs "$(bash_input "$ADAPTER")"
assert_not_in "adapter command without a receipt is not trusted" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")"
assert_in "adapter command with a fresh receipt records the skill" "$STATE" silver-plan
assert_eq "adapter record reports success" "$RECORDED" "$(msg)"
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER" exec_command)"
assert_in "exec_command adapter payloads are recognised" "$STATE" silver-plan
reset; write_receipt silver-plan 9999; rs "$(bash_input "$ADAPTER")"
assert_not_in "stale receipt is rejected" "$STATE" silver-plan
reset; write_receipt silver-plan 400; rs "$(bash_input "$ADAPTER")" SILVER_BULLET_INVOKE_SKILL_RECEIPT_MAX_AGE_SECONDS=1000
assert_in "receipt max age is configurable" "$STATE" silver-plan
reset; write_receipt silver-plan 0 /somewhere/else; rs "$(bash_input "$ADAPTER")"
assert_not_in "receipt for another cwd is rejected" "$STATE" silver-plan
reset; write_receipt silver-context; rs "$(bash_input "$ADAPTER")"
assert_not_in "receipt for another skill is rejected" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER" Bash 1)"
assert_not_in "failed adapter command is not recorded" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" JQ_FAIL='.tool_response.exit_code'
assert_in "unreadable exit code defaults to success" "$STATE" silver-plan
reset; write_receipt silver-plan; ln -s "$RECEIPTS/r1.json" "$RECEIPTS/aaa-link.json"
mkdir -p "$RECEIPTS/dir.json"
rs "$(bash_input "$ADAPTER")"
assert_in "symlinked and non-file receipts are skipped, the real one is used" "$STATE" silver-plan
reset; mkdir -p "$TL_TMP/real-receipts"; : >"$TL_TMP/real-receipts/r.json"; ln -s "$TL_TMP/real-receipts" "$RECEIPTS"
rs "$(bash_input "$ADAPTER")"
assert_not_in "symlinked receipt directory is skipped" "$STATE" silver-plan
rm -f "$RECEIPTS"
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" PY_NO_C=1
assert_in "cwd falls back to \$PWD when python cannot resolve it" "$STATE" silver-plan
for cmd in \
  'silver-bullet invoke-skill sb:plan' \
  'env FOO=1 BAR=2 silver-bullet invoke-skill sb:plan' \
  'FOO=1 silver-bullet invoke-skill sb:plan' \
  "bash -c 'silver-bullet invoke-skill sb:plan'" \
  'sh -x /opt/silver-bullet invoke-skill sb:plan'; do
  reset; write_receipt silver-plan; rs "$(bash_input "$cmd")"
  assert_in "adapter form recognised: $cmd" "$STATE" silver-plan
done
for cmd in \
  'silver-bullet other-subcommand sb:plan' \
  'silver-bullet invoke-skill' \
  'bash /opt/not-silver-bullet invoke-skill sb:plan' \
  'bash' \
  'env' \
  "echo 'unbalanced" \
  'ls invoke-skill sb:plan'; do
  reset; write_receipt silver-plan; rs "$(bash_input "$cmd")"
  assert_not_in "non-adapter form ignored: $cmd" "$STATE" silver-plan
done
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" PATH="$(tl_path_without python3)"
assert_not_in "without python3 the adapter command cannot be verified" "$STATE" silver-plan
reset; tg2_farm no-rt "$HOOK" runtime-paths.sh
mkdir -p "$RECEIPTS"; write_receipt silver-plan
TG2_REPO="$TG2_FARM" rs "$(bash_input "$ADAPTER")"
assert_in "without runtime-paths.sh the default receipt directory is used" "$STATE" silver-plan

# --------------------------------------------------------- project / state wiring
reset; tg2_farm inactive "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_absent "inactive project records nothing" "$STATE"
reset; tg2_farm uninit "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_is_initiated() { return 1; }'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_absent "uninitiated project (legacy gate) records nothing" "$STATE"
reset; tg2_farm nogatefn "$HOOK" project-active.sh
tg2_farm_stub project-active.sh ':'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "no gate function means no gating" "$STATE" silver-plan
reset; TG2_CWD="$TG2_PROJ/src" TG2_PROJECT_ROOT="" rs "$(skill_input silver-plan)"
assert_in "walk-up finds the config from a subdirectory" "$STATE" silver-plan
reset; rm -f "$TG2_CFG"; mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
TG2_CWD="$TL_TMP/gitonly/sub" TG2_PROJECT_ROOT="" rs "$(skill_input silver-plan)"
assert_in "no project config: skills still record to the default state" "$STATE" silver-plan
reset; jq --arg p "$SB_RUNTIME_STATE_DIR/cfg-state" '.state.state_file=$p' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "config state_file is honoured" "$SB_RUNTIME_STATE_DIR/cfg-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/cfg-state"
reset; jq --arg p "~${SB_RUNTIME_STATE_DIR#"$HOME"}/tilde-state" '.state.state_file=$p' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "tilde in config state_file expands to HOME" "$SB_RUNTIME_STATE_DIR/tilde-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/tilde-state"
reset; jq '.state.state_file="/tmp/outside-state-root"' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "state file outside the runtime root falls back to the default" "$STATE" silver-plan
assert_file_absent "out-of-scope state path is never written" /tmp/outside-state-root
reset; rs "$(skill_input silver-plan)" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/env-state"
assert_in "SILVER_BULLET_STATE_FILE overrides the config" "$SB_RUNTIME_STATE_DIR/env-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/env-state"
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$STATE"
rs "$(skill_input silver-plan)"
assert_eq "symlinked state file is refused (exit 0 via ERR trap/guard)" "1" "$([[ "$TL_STATUS" == 1 || "$TL_STATUS" == 0 ]] && echo 1 || echo 0)"
assert_eq "symlink target is never written" "" "$(<"$TL_TMP/target")"
assert_contains "symlink refusal is reported on stderr" "$TL_ERR" "refusing to write through symlink"
rm -f "$STATE"
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$LOADED"
rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')"
assert_eq "symlinked loaded file is never written through" "" "$(<"$TL_TMP/target")"
rm -f "$LOADED"
reset; : >"$SB_RUNTIME_STATE_DIR/afile"
rs "$(skill_input silver-plan)" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/afile/state"
assert_eq "uncreatable state dir fails open (completed path)" "0" "$TL_STATUS"
assert_eq "uncreatable state dir emits no message" "" "$TL_OUT"
rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/afile/state"
assert_eq "uncreatable state dir fails open (loaded path)" "0" "$TL_STATUS"
rm -f "$SB_RUNTIME_STATE_DIR/afile"
reset; : >"$TL_TMP/afile"
rs "$(skill_input silver-plan)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/afile/.silver-bullet"
assert_eq "uncreatable runtime state dir fails open" "0" "$TL_STATUS"

# ------------------------------------------------- lib farms and injected faults
reset; tg2_farm farm-noguard "$HOOK" nofollow-guard.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "without nofollow-guard.sh the inline guard still lets records through" "$STATE" silver-plan
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$STATE"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_contains "inline fallback guard refuses a symlinked state file" "$TL_ERR" "refusing to write through symlink"
assert_eq "inline fallback guard exits non-zero" "1" "$TL_STATUS"
assert_eq "inline fallback guard never writes through the link" "" "$(<"$TL_TMP/target")"
rm -f "$STATE"
reset; tg2_farm farm-nolib "$HOOK" -
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_eq "missing lib dir: hook exits 0" "0" "$TL_STATUS"
reset; tg2_farm farm-notoolinput "$HOOK" tool-input.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "jq fallbacks work without tool-input.sh (Skill)" "$STATE" silver-plan
reset; TG2_REPO="$TG2_FARM" rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')"
assert_eq "without tool-input.sh a Bash payload is not shell-like (nothing recorded)" "$NOTHING" "$(msg)"
reset; tg2_farm farm-nodisc "$HOOK" skill-discovery.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input legacy:plugin:silver-plan)"
assert_in "without skill-discovery.sh namespaces are stripped by sed" "$STATE" silver-plan
reset; tg2_farm farm-norequired "$HOOK" required-skills.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "without required-skills.sh the tracked list is read from the template" "$STATE" silver-plan
reset; tg2_farm farm-notemplate "$HOOK" required-skills.sh
rm -f "$TG2_FARM/templates"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)"
assert_in "without library and template the built-in fallback list is used" "$STATE" silver-quality-gates
rm -f "$STATE"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_not_in "built-in fallback list is minimal" "$STATE" silver-plan
reset; tg2_farm farm-badtemplate "$HOOK" required-skills.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)" JQ_FAIL='silver-bullet.config.json.default'
assert_in "unreadable template falls back to the built-in tracked list" "$STATE" silver-quality-gates
reset; tg2_farm farm-nohookout "$HOOK" hook-output.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_eq "missing hook-output.sh: skill still recorded" "0" "$([[ -f "$STATE" ]] && echo 0 || echo 1)"

# bash functions can be exported: make the hook's own `cd <dir>/..` probe fail
cd_fail='cd() { if [[ "${1:-}" == */.. && "${BASH_SOURCE[1]:-}" == *record-skill.sh ]]; then return 1; fi; builtin cd "$@"; }'
reset; tg2_farm farm-cdfail "$HOOK" required-skills.sh
( eval "$cd_fail"; export -f cd; TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)" )
assert_in "unresolvable repo dir falls back to the built-in tracked list" "$STATE" silver-quality-gates
rm -f "$STATE"
( eval "$cd_fail"; export -f cd; TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)" )
assert_not_in "the built-in fallback list does not include other skills" "$STATE" silver-plan

# debug log
reset; rs "$(skill_input silver-plan)" SILVER_BULLET_DEBUG_RECORD_SKILL=1
DBG="$SB_RUNTIME_STATE_DIR/record-skill.debug.log"
assert_file_exists "debug mode writes the debug log" "$DBG"
assert_in "debug mode still records the skill" "$STATE" silver-plan
assert_contains "debug log carries the skill" "$(lines "$DBG")" "raw_skill=silver-plan"
assert_contains "debug log has the canonical_skill line" "$(lines "$DBG")" "canonical_skill="
assert_contains "debug log carries the config file" "$(lines "$DBG")" "config_file=$TG2_CFG"
reset; rs "$(skill_input silver-plan)"
assert_file_absent "no debug log unless enabled" "$DBG"
reset; : >"$TL_TMP/afile2"
rs "$(skill_input silver-plan)" SILVER_BULLET_DEBUG_RECORD_SKILL=1 SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/afile2/.silver-bullet"
assert_eq "an unwritable debug log never breaks the hook" "0" "$TL_STATUS"
assert_file_absent "unwritable debug log is not created" "$TL_TMP/afile2/.silver-bullet/record-skill.debug.log"

# ------------------------------------------------- session ledger and directive
mkdir -p "$(dirname "$SESSION_LOG")"
write_log() {
  cat >"$SESSION_LOG" <<'LOG'
# Session Log

## Active Intent Ledger

- Request [2026-01-01 00:00:00Z]
  > do the thing
  - [ ] silver-plan

## Agent Teams dispatched

(none)
LOG
  printf '%s\n' "$SESSION_LOG" >"$LOG_PATH_FILE"
}
reset; write_log; rs "$(skill_input silver-plan)"
assert_contains "completed skill is checked off in the session ledger" "$(<"$SESSION_LOG")" "  - [x] silver-plan"
reset; write_log; tg2_farm ledger-fails "$HOOK" session-ledger.sh
tg2_farm_stub session-ledger.sh 'sb_session_ledger_mark_completed() { return 1; }'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "failing ledger update does not stop recording" "$STATE" silver-plan
assert_eq "failing ledger update still reports success" "$RECORDED" "$(msg)"
rm -f "$LOG_PATH_FILE"

write_directive() { printf '{"next_skill":"%s","blocking":true}\n' "$1" >"$DIRECTIVE"; }
reset; write_directive silver-plan; rs "$(skill_input silver-plan)"
assert_file_absent "recording the expected skill clears the directive" "$DIRECTIVE"
reset; write_directive silver-context; rs "$(skill_input silver-plan)"
assert_file_exists "recording an unrelated skill keeps the directive" "$DIRECTIVE"
reset; write_directive silver-plan; printf 'silver-plan\n' >"$STATE"; rs "$(skill_input silver-context)"
assert_file_absent "directive clears when the expected skill is already recorded" "$DIRECTIVE"
reset; write_directive silver-plan; rs "$(skill_input silver-plan)" CAT_FAIL="$STATE"
assert_file_absent "unreadable state still clears when the recorded skill is the expected one" "$DIRECTIVE"
reset; write_directive silver-context; rs "$(skill_input silver-plan)" CAT_FAIL="$STATE"
assert_file_exists "unreadable state keeps an unrelated directive" "$DIRECTIVE"
reset; printf '{"blocking":true}\n' >"$DIRECTIVE"; rs "$(skill_input silver-plan)"
assert_file_exists "directive without next_skill is left alone" "$DIRECTIVE"
reset; write_directive silver-plan; tg2_farm nodirective "$HOOK" orchestrator-directive.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_exists "without orchestrator-directive.sh the directive is untouched" "$DIRECTIVE"

tl_results
