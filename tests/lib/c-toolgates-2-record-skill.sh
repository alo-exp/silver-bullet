# shellcheck shell=bash disable=SC2034
# Shared fixtures for the record-skill.sh tests. Source after tl_init, c-toolgates-2-helpers.sh
# and tg2_init_project.
HOOK=hooks/record-skill.sh
STATE="$SB_RUNTIME_STATE_DIR/state"
LOADED="$STATE.loaded"
DIRECTIVE="$SB_RUNTIME_STATE_DIR/orchestrator-directive.json"
RECEIPTS="$SB_RUNTIME_STATE_DIR/skill-invocations"
LOG_PATH_FILE="$TL_TMP/session-log-path"
SESSION_LOG="$TG2_PROJ/docs/sessions/log.md"
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


# Fault-injection stubs; they are only on PATH for runs that pass PY_NO_C= / JQ_FAIL= / CAT_FAIL=.
REAL_PY="$(command -v python3)"
REAL_CAT="$(command -v cat)"
tg2_install_jq_stub
# python3 fails only for `python3 -c ...` (the hook's cwd resolution), not for the heredoc script
tg2_fault_stub python3 "if [[ -n \"\${PY_NO_C:-}\" && \"\${1:-}\" == -c ]]; then exit 1; fi
exec $REAL_PY \"\$@\""
tg2_fault_stub cat "if [[ -n \"\${CAT_FAIL:-}\" && \"\${1:-}\" == \"\$CAT_FAIL\" ]]; then exit 1; fi
exec $REAL_CAT \"\$@\""
