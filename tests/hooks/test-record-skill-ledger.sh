#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: session ledger and orchestrator directive
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

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
