#!/usr/bin/env bash
# Behavior tests for hooks/record-requested-skill.sh (UserPromptSubmit route recorder)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project

HOOK=hooks/record-requested-skill.sh
NOOP='{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}'
STATE="$SB_RUNTIME_STATE_DIR/state"
REQ="$STATE.requested"
LOG_PATH_FILE="$TL_TMP/session-log-path"
reset() {
  rm -rf "$STATE" "$REQ" "$SB_RUNTIME_STATE_DIR/ups-coalesce-turn" "$SB_RUNTIME_STATE_DIR/ups-coalesce-seen" \
    "$SB_RUNTIME_STATE_DIR/project-root" "$TL_TMP/custom"
  tg2_cfg '{"sb_initiated":true}'
}
prompt_input() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit", prompt:$p}'; }
run() { tg2_run "$HOOK" "$(prompt_input "$1")" SILVER_BULLET_SESSION_LOG_PATH_FILE="$LOG_PATH_FILE" "${@:2}"; }
requested() { [[ -f "$1" ]] && cat "$1" || true; }
assert_noop() { # name
  if [[ "$TL_STATUS" == 0 && "$TL_OUT" == "$NOOP" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200})"; fi
}

# ------------------------------------------------------------------ recording
reset; run 'please run `sb:feature` now'
assert_noop "route marker prompt emits the no-op payload"
assert_eq "backtick sb:feature is recorded as silver-feature" "silver-feature" "$(requested "$REQ")"
assert_file_exists "UPS coalesce turn is started" "$SB_RUNTIME_STATE_DIR/ups-coalesce-turn"

reset; run 'run `sb:init` then `sb:bugfix` then `sb:init`'
assert_eq "multiple markers are recorded once each, in order" $'silver-init\nsilver-bugfix' "$(requested "$REQ")"
reset; run 'use `foo:bar` and `ls -la` and `sb:ui`'
assert_eq "non-sb backtick tokens are ignored" "silver-ui" "$(requested "$REQ")"
reset; run 'run `sb:feature`'
run 'run `sb:feature` again'
assert_eq "an already recorded marker is not duplicated across prompts" "silver-feature" "$(requested "$REQ")"
reset; run 'fix the login bug in the parser please'
assert_eq "bare work request is recorded as the umbrella silver route" "silver" "$(requested "$REQ")"
reset; run 'what is the weather like today'
assert_noop "informational prompt records nothing (no-op payload)"
assert_file_absent "informational prompt creates no requested file" "$REQ"
reset; run ''
assert_noop "empty prompt is a no-op"
assert_file_absent "empty prompt creates no requested file" "$REQ"

# ------------------------------------------------------------------ input shapes
reset; tg2_run "$HOOK" "" 
assert_noop "empty stdin is a no-op"
reset; TG2_STDIN_UNREADABLE=1 tg2_run "$HOOK" ""
assert_noop "unreadable stdin is a no-op"
reset; tg2_run "$HOOK" "not json"
assert_noop "unparsable stdin is a no-op"
assert_file_absent "unparsable stdin creates no requested file" "$REQ"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$HOOK" "$(prompt_input 'run `sb:feature`')"
assert_contains "missing jq prints the enforcement-inactive warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
assert_eq "missing jq exits 0" "0" "$TL_STATUS"
assert_file_absent "missing jq records nothing" "$REQ"

# ------------------------------------------------------------------ state file
reset; mkdir -p "$TL_TMP/xdg"
jq --arg p "$SB_RUNTIME_STATE_DIR/custom-state" '.state.state_file=$p' <<<'{"sb_initiated":true}' >"$TG2_CFG"
run 'run `sb:feature`'
assert_eq "config state_file is honoured" "silver-feature" "$(requested "$SB_RUNTIME_STATE_DIR/custom-state.requested")"
assert_file_absent "default state file is untouched when config sets one" "$REQ"
rm -f "$SB_RUNTIME_STATE_DIR/custom-state.requested"
reset; jq --arg p "~${SB_RUNTIME_STATE_DIR#"$HOME"}/tilde-state" '.state.state_file=$p' <<<'{"sb_initiated":true}' >"$TG2_CFG"
run 'run `sb:feature`'
assert_eq "tilde in config state_file expands to HOME" "silver-feature" "$(requested "$SB_RUNTIME_STATE_DIR/tilde-state.requested")"
rm -f "$SB_RUNTIME_STATE_DIR/tilde-state.requested"
reset; jq --arg p "$TL_TMP/outside-state-root" '.state.state_file=$p' <<<'{"sb_initiated":true}' >"$TG2_CFG"
run 'run `sb:feature`'
assert_eq "state file outside the runtime state root falls back to the default" "silver-feature" "$(requested "$REQ")"
assert_file_absent "out-of-scope state file is not written" "$TL_TMP/outside-state-root.requested"
reset; run 'run `sb:feature`' SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/env-state"
assert_eq "SILVER_BULLET_STATE_FILE overrides the config" "silver-feature" "$(requested "$SB_RUNTIME_STATE_DIR/env-state.requested")"
rm -f "$SB_RUNTIME_STATE_DIR/env-state.requested"

# ------------------------------------------------------------- project discovery
reset; rm -f "$TG2_CFG" "$TG2_PROJ/silver-bullet.md"
TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" run 'run `sb:init`'
assert_eq "bootstrap prompt is recorded even without a project scaffold" "silver-init" "$(requested "$REQ")"
printf '# Silver Bullet\n' >"$TG2_PROJ/silver-bullet.md"
reset; TG2_CWD="$TG2_PROJ/src" run 'run `sb:feature`'
assert_eq "walk-up finds the project config from a subdirectory" "silver-feature" "$(requested "$REQ")"
reset; mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
TG2_CWD="$TL_TMP/gitonly/sub" TG2_PROJECT_ROOT="" run 'run `sb:feature`'
assert_eq "walk-up stops at the .git boundary but still records" "silver-feature" "$(requested "$REQ")"

# project gate decisions (injected via the project-active library)
reset; tg2_farm inactive "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }'
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_noop "inactive project is a no-op"
assert_file_absent "inactive project records nothing" "$REQ"
reset; tg2_farm not-initiated "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_is_initiated() { return 1; }'
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_noop "uninitiated project (legacy gate) is a no-op"
assert_file_absent "uninitiated project records nothing" "$REQ"
reset; tg2_farm no-gate-fns "$HOOK" project-active.sh
tg2_farm_stub project-active.sh ':'
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_eq "no project gate function means no gating" "silver-feature" "$(requested "$REQ")"

# ------------------------------------------------------------ fault injection
reset; mkdir -p "$TL_TMP/link-target"; : >"$TL_TMP/link-target/file"
ln -s "$TL_TMP/link-target/file" "$REQ"
run 'run `sb:feature`'
assert_noop "symlinked requested file is refused with a no-op"
assert_eq "symlink target is never written" "" "$(<"$TL_TMP/link-target/file")"
rm -f "$REQ"
reset; mkdir -p "$REQ"
run 'run `sb:feature`'
assert_noop "unwritable requested path still ends with the no-op payload"
rmdir "$REQ"
reset; : >"$TL_TMP/afile"
run 'run `sb:feature`' SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/afile/.silver-bullet"
assert_noop "uncreatable state dir does not break the hook"
assert_file_absent "uncreatable state dir leaves nothing behind" "$TL_TMP/afile/.silver-bullet/state.requested"

# ledger and coalesce libraries
reset; mkdir -p "$TG2_PROJ/docs/sessions"
cat >"$TG2_PROJ/docs/sessions/log.md" <<'LOG'
# Session Log

## Active Intent Ledger

(filled during the session as active requests are intercepted)

## Agent Teams dispatched

(none)
LOG
printf '%s\n' "$TG2_PROJ/docs/sessions/log.md" >"$LOG_PATH_FILE"
run 'run `sb:feature`'
assert_contains "request is appended to the session ledger" "$(<"$TG2_PROJ/docs/sessions/log.md")" "silver-feature"
reset; tg2_farm ledger-fails "$HOOK" session-ledger.sh
tg2_farm_stub session-ledger.sh 'sb_session_ledger_append_request() { return 1; }'
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_noop "failing ledger append does not break the hook"
assert_eq "route is still recorded when the ledger append fails" "silver-feature" "$(requested "$REQ")"
reset; tg2_farm no-ledger "$HOOK" session-ledger.sh prompt-classifier.sh ups-coalesce.sh jq-gate.sh
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_noop "hook works without the optional libraries"
assert_eq "route is recorded without the optional libraries" "silver-feature" "$(requested "$REQ")"
assert_file_absent "no coalesce turn without ups-coalesce.sh" "$SB_RUNTIME_STATE_DIR/ups-coalesce-turn"
reset; TG2_REPO="$TG2_FARM" run 'fix the login bug in the parser please'
assert_noop "bare work request without the classifier is a no-op"
assert_file_absent "bare work request without the classifier records nothing" "$REQ"
reset; tg2_farm no-lib "$HOOK" -
TG2_REPO="$TG2_FARM" run 'run `sb:feature`'
assert_noop "missing lib dir still ends with the no-op payload"
rm -f "$REQ"

tl_results
