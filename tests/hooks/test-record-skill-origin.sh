#!/usr/bin/env bash
# hooks/record-skill.sh: only the install the host runs records (R3-01), the keyed seal it writes,
# and the contract-unlock record.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

OTHER="$TL_TMP/other"
mkdir -p "$OTHER"
cp -R "$TL_REPO_ROOT/hooks" "$OTHER/hooks"
cp -R "$TL_REPO_ROOT/templates" "$OTHER/templates"
REG="$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
mkdir -p "$(dirname "$REG")" "$TL_TMP/install-a"
EVENTS="$SB_RUNTIME_STATE_DIR/seal-events.log"
copy_rs() { local keep="$TG2_REPO"; TG2_REPO="$OTHER"; rs "$@"; TG2_REPO="$keep"; }
register() { jq -cn --arg p "$1" '{plugins:{"silver-bullet@alo-labs":[{installPath:$p}]}}' >"$REG"; }

reset; rm -f "$REG" "$EVENTS"
copy_rs "$(skill_input silver-context)"
assert_in "no registry (a bare copy): it records" "$STATE" silver-context

reset; register "$TL_TMP/install-a"
copy_rs "$(skill_input silver-context)"
assert_file_absent "a copy that is not the registered install records nothing" "$STATE"
assert_contains "and the refusal is logged" "$(cat "$EVENTS")" "recorder refused"

reset; register "$OTHER"
copy_rs "$(skill_input silver-context)"
assert_in "the registered install records" "$STATE" silver-context

reset; register "$TL_TMP/install-a"
rs "$(skill_input silver-context)"
assert_in "a source checkout (.git) is its own authority" "$STATE" silver-context

reset; rm -f "$REG"
copy_rs "$(skill_input silver-context)" CLAUDE_PLUGIN_ROOT="$TL_REPO_ROOT"
assert_file_absent "CLAUDE_PLUGIN_ROOT naming another root: refused" "$STATE"
reset
copy_rs "$(skill_input silver-context)" CLAUDE_PLUGIN_ROOT="$OTHER"
assert_in "CLAUDE_PLUGIN_ROOT naming this root: records" "$STATE" silver-context

# ── the keyed seal ──────────────────────────────────────────────────────────────────────────
reset; rm -f "$REG" "$SB_RUNTIME_STATE_DIR/seal.key" "$STATE.hwm"
rs "$(skill_input silver-context)"
assert_eq "the key is created with mode 0600" "600" "$(stat -c %a "$SB_RUNTIME_STATE_DIR/seal.key" 2>/dev/null || stat -f %Lp "$SB_RUNTIME_STATE_DIR/seal.key")"
assert_eq "the seal says it is keyed" "hmac" "$(sed -n 2p "$STATE.seal")"
assert_eq "the counter starts at 1" "1" "$(sed -n 3p "$STATE.seal")"
rs "$(skill_input silver-plan)"
assert_eq "and moves up with every record" "2" "$(sed -n 3p "$STATE.seal")"
assert_eq "the highest counter is kept beside it" "2" "$(cat "$STATE.hwm")"
key_before="$(cat "$SB_RUNTIME_STATE_DIR/seal.key")"
rs "$(skill_input silver-tdd)"
assert_eq "the key is never replaced" "$key_before" "$(cat "$SB_RUNTIME_STATE_DIR/seal.key")"

# ── the contract unlock ────────────────────────────────────────────────────────────────────
reset; rm -f "$SB_RUNTIME_STATE_DIR/contract-unlock"
rs "$(skill_input silver-plan)"
assert_file_absent "an ordinary skill unlocks nothing" "$SB_RUNTIME_STATE_DIR/contract-unlock"
rs "$(skill_input silver-add)"
assert_contains "a contract writer records its unlock" "$(cat "$SB_RUNTIME_STATE_DIR/contract-unlock")" "silver-add "
rs "$(skill_input silver-add)"
assert_contains "and again when it is invoked a second time" "$(cat "$SB_RUNTIME_STATE_DIR/contract-unlock")" "silver-add "

tl_results
