#!/usr/bin/env bash
# hooks/lib/state-seal.sh and the recorder's use of it: sealed skill state, reset, tamper evidence.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/state-seal.sh
source "$TL_REPO_ROOT/hooks/lib/state-seal.sh"

S="$TL_TMP/state"
assert_eq "seal path" "$S.seal" "$(sb_state_seal_file "$S")"
assert_eq "no state, nothing trusted" "" "$(sb_state_seal_trusted "$S")"
printf 'a\nb\n' >"$S"
assert_eq "unsealed: read as written" "a
b" "$(sb_state_seal_trusted "$S")"
sb_state_seal_write "$S"
assert_eq "sealed: all of it" "a
b" "$(sb_state_seal_trusted "$S")"
printf 'forged\n' >>"$S"
assert_eq "appended outside the hooks: ignored" "a
b" "$(sb_state_seal_trusted "$S")"
sb_state_seal_enforce "$S"
assert_eq "enforce drops the unsealed line" "a
b" "$(cat "$S")"
printf 'a\nX\n' >"$S"
assert_eq "an in-place edit yields nothing" "" "$(sb_state_seal_trusted "$S")"
sb_state_seal_enforce "$S"
assert_eq "enforce empties an edited state" "" "$(cat "$S")"
printf 'a\n' >"$S"
assert_eq "fewer lines than sealed is a reset: read as is" "a" "$(sb_state_seal_trusted "$S")"
sb_state_seal_enforce "$S"
assert_eq "enforce leaves a reset state alone" "a" "$(cat "$S")"
printf 'garbage\n' >"$S.seal"
printf 'a\n' >"$S"
assert_eq "an unreadable seal yields nothing" "" "$(sb_state_seal_trusted "$S")"
rm -f "$S.seal"
sb_state_seal_enforce "$S"
assert_eq "enforce without a seal does nothing" "a" "$(cat "$S")"
ln -s "$TL_TMP/elsewhere" "$S.seal"
sb_state_seal_write "$S"
assert_file_absent "a symlinked seal is never written through" "$TL_TMP/elsewhere"
rm -f "$S.seal"
rm -f "$S"
sb_state_seal_write "$S"
assert_file_absent "nothing to seal without a state file" "$S.seal"
ln -s "$TL_TMP/real" "$S"
sb_state_seal_write "$S"
assert_file_absent "a symlinked state file is not sealed" "$S.seal"
rm -f "$S"

# ── the recorder ───────────────────────────────────────────────────────────────────────────────
P="$TL_TMP/proj"
mkdir -p "$P/.git"
printf '{"sb_initiated":true}\n' >"$P/.silver-bullet.json"
printf '# SB\n' >"$P/silver-bullet.md"
STATE="$SB_RUNTIME_STATE_DIR/state-seal-test"
export SILVER_BULLET_STATE_FILE="$STATE"
rec() { # event skill
  jq -cn --arg e "$1" --arg s "$2" '{hook_event_name:$e,tool_name:"Skill",tool_input:{skill:$s}}' >"$TL_TMP/in.json"
  (cd "$P" && bash "$TL_REPO_ROOT/hooks/record-skill.sh" <"$TL_TMP/in.json" >/dev/null 2>&1) || true
}
rm -f "$STATE" "$STATE.seal"
rec PreToolUse silver-plan
assert_file_absent "a payload that is not a PostToolUse event records nothing" "$STATE"
rec PostToolUse silver-quality-gates
assert_contains "the recorder records" "$(cat "$STATE")" "silver-quality-gates"
assert_file_exists "and seals" "$STATE.seal"
printf 'silver-plan\n' >>"$STATE"
assert_eq "an appended skill is not trusted" "silver-quality-gates" "$(sb_state_seal_trusted "$STATE" | head -1)"
rec PostToolUse silver-context
assert_not_contains "the next real record drops the forged line" "$(cat "$STATE")" "silver-plan"
assert_contains "and keeps the sealed ones" "$(cat "$STATE")" "silver-context"
assert_contains "the new state is sealed again" "$(sb_state_seal_trusted "$STATE")" "silver-context"
before="$(cat "$STATE")"
rec PostToolUse silver-context
assert_eq "re-recording a skill changes nothing" "$before" "$(cat "$STATE")"

tl_results
