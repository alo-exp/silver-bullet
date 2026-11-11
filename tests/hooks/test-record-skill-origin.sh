#!/usr/bin/env bash
# hooks/record-skill.sh: only the install the host runs records (R3-01), the keyed seal it writes,
# and the contract-unlock record.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../../hooks/lib/state-seal.sh
source "$TL_REPO_ROOT/hooks/lib/state-seal.sh"
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

OTHER="$TL_TMP/other"
mkdir -p "$OTHER"
cp -R "$TL_REPO_ROOT/hooks" "$OTHER/hooks"
cp -R "$TL_REPO_ROOT/templates" "$OTHER/templates"
REG="$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
mkdir -p "$(dirname "$REG")" "$TL_TMP/install-a"
EVENTS="$SB_RUNTIME_STATE_DIR/seal-events.log"
copy_rs() { local keep="$TG2_REPO"; TG2_REPO="$OTHER"; rs "$1" SILVER_BULLET_DEV_PLUGIN_ROOT= "${@:2}"; TG2_REPO="$keep"; }
register() { jq -cn --arg p "$1" '{plugins:{"silver-bullet@alo-labs":[{installPath:$p}]}}' >"$REG"; }

no_dev="SILVER_BULLET_DEV_PLUGIN_ROOT="

reset; rm -f "$REG" "$EVENTS"
copy_rs "$(skill_input silver-context)"
assert_file_absent "no registry: a bare copy is refused (a missing registry is not a reason to accept)" "$STATE"
assert_contains "and the refusal is logged" "$(cat "$EVENTS")" "recorder refused"

reset; register "$TL_TMP/install-a"
copy_rs "$(skill_input silver-context)"
assert_file_absent "a copy that is not the registered install records nothing" "$STATE"

reset; register "$OTHER"
copy_rs "$(skill_input silver-context)"
assert_in "the registered install records" "$STATE" silver-context

reset; register "$TL_TMP/install-a"
mkdir -p "$OTHER/.git"
copy_rs "$(skill_input silver-context)"
assert_file_absent "a copy with a .git directory is not a source checkout to trust" "$STATE"
rmdir "$OTHER/.git"
: >"$OTHER/.git"
copy_rs "$(skill_input silver-context)"
assert_file_absent "nor one with a .git file" "$STATE"
rm -f "$OTHER/.git"

reset; register "$TL_TMP/install-a"
rs "$(skill_input silver-context)"
assert_in "the developer's own checkout, named for the host, records" "$STATE" silver-context
reset; register "$TL_TMP/install-a"
rs "$(skill_input silver-context)" "$no_dev"
assert_file_absent "the same checkout without that naming is refused" "$STATE"
reset; register "$TL_TMP/install-a"
copy_rs "$(skill_input silver-context)" SILVER_BULLET_DEV_PLUGIN_ROOT="$TL_TMP/install-a"
assert_file_absent "a development root that is another directory admits nothing" "$STATE"
reset; rm -f "$REG"
copy_rs "$(skill_input silver-context)" SILVER_BULLET_DEV_PLUGIN_ROOT="$OTHER"
assert_in "a copy named as the development root records" "$STATE" silver-context

reset; rm -f "$REG"
mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins/host-managed"
cp -R "$TL_REPO_ROOT/hooks" "$SB_RUNTIME_HOME_ROOT/plugins/host-managed/hooks"
cp -R "$TL_REPO_ROOT/templates" "$SB_RUNTIME_HOME_ROOT/plugins/host-managed/templates"
keep="$TG2_REPO"; TG2_REPO="$SB_RUNTIME_HOME_ROOT/plugins/host-managed"
rs "$(skill_input silver-context)" "$no_dev"
TG2_REPO="$keep"
assert_in "without a registry a root below the host's plugins directory records" "$STATE" silver-context
reset; rm -f "$REG"
keep="$TG2_REPO"
mv "$SB_RUNTIME_HOME_ROOT/plugins/host-managed" "$TL_TMP/host-managed-moved"
TG2_REPO="$TL_TMP/host-managed-moved"
rs "$(skill_input silver-context)" "$no_dev"
TG2_REPO="$keep"
assert_file_absent "and one outside it does not" "$STATE"

reset; rm -f "$REG"
copy_rs "$(skill_input silver-context)" "$no_dev" CLAUDE_PLUGIN_ROOT="$TL_REPO_ROOT"
assert_file_absent "CLAUDE_PLUGIN_ROOT naming another root: refused" "$STATE"
reset; register "$OTHER"
copy_rs "$(skill_input silver-context)" CLAUDE_PLUGIN_ROOT="$OTHER"
assert_in "CLAUDE_PLUGIN_ROOT naming this registered root: records" "$STATE" silver-context

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

# a registry that is not JSON names no install
reset; printf 'not json' >"$REG"
copy_rs "$(skill_input silver-context)"
assert_file_absent "an unreadable registry names nothing: the copy is refused" "$STATE"

# ── parallel recorders lose nothing ───────────────────────────────────────────────────────────
rm -f "$REG"
for trial in 1 2 3; do
  reset
  rm -rf "$STATE.lock"
  pids=()
  for sk in silver-context silver-plan silver-quality-gates tdd modularity verify-tests; do
    ( cd "$TG2_PROJ" && printf '%s' "$(skill_input "$sk")" | env SILVER_BULLET_PROJECT_ROOT="$TG2_PROJ" SILVER_BULLET_SESSION_LOG_PATH_FILE="$LOG_PATH_FILE" SILVER_BULLET_RUNTIME=claude bash "$TL_REPO_ROOT/hooks/record-skill.sh" >/dev/null 2>&1 ) &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done
  trusted="$(sb_state_seal_trusted "$STATE" | grep -cE '^(silver-context|silver-plan|silver-quality-gates|tdd|modularity|verify-tests)$' || true)"
  assert_eq "six parallel recorders, trial $trial: every skill is kept" "6" "$trusted"
  assert_file_absent "and the lock is released" "$STATE.lock"
done

tl_results
