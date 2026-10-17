#!/usr/bin/env bash
# Behavior tests for hooks/stack-compression-lifecycle.sh (SessionStart compact LeanCTX marker)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
tg2_install_jq_stub

HOOK=hooks/stack-compression-lifecycle.sh
MARK="$SB_RUNTIME_STATE_DIR/stack-compression-lifecycle.leanctx_compact"
LEAN_CFG='{"sb_initiated":true,"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
TWO_CFG='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}}}'
ONE_CFG='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
LEAN_SUSPENDED='{"sb_initiated":true,"recommended_tools":{"leanctx":{"enabled_by_user":true,"enforcement_suspended":true},"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}}}'
COMPACT='{"hook_event_name":"SessionStart","session_source":"compact"}'
reset() { rm -rf "$MARK" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "${1:-$LEAN_CFG}"; }
assert_marked() {
  if [[ -f "$MARK" && "$(<"$MARK")" =~ ^[0-9]+$ && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=$TL_OUT mark=$([[ -e "$MARK" ]] && cat "$MARK" || echo absent))"; fi
}
assert_unmarked() {
  if [[ ! -e "$MARK" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=$TL_OUT mark=$([[ -e "$MARK" ]] && echo present || echo absent))"; fi
}

reset; tg2_run "$HOOK" "$COMPACT"
assert_marked "compact session with leanctx records the leanctx_compact phase"
reset; tg2_run "$HOOK" '{"hook_event_name":"SessionStart","source":"compact"}'
assert_marked "the legacy 'source' field is accepted"
reset; tg2_run "$HOOK" '{"hook_event_name":"SessionStart","session_source":"startup"}'
assert_unmarked "non-compact sessions are ignored"
reset; tg2_run "$HOOK" '{"hook_event_name":"SessionStart"}'
assert_unmarked "payload without a source is ignored"
reset; tg2_run "$HOOK" ""
assert_unmarked "empty stdin is ignored"
reset; TG2_STDIN_DIR=1 tg2_run "$HOOK" ""
assert_unmarked "unreadable stdin is ignored"
reset; tg2_run "$HOOK" "not json"
assert_unmarked "unparsable stdin is ignored"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$HOOK" "$COMPACT"
assert_unmarked "missing jq is a no-op"
reset; tg2_run "$HOOK" "$COMPACT" JQ_FAIL=session_source
assert_unmarked "failed source extraction is treated as not-compact"
reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$HOOK" "$COMPACT"
assert_unmarked "outside an SB project is a no-op"
reset; rm -f "$TG2_CFG"; tg2_run "$HOOK" "$COMPACT"
assert_unmarked "missing project config is a no-op"
reset "$ONE_CFG"; tg2_run "$HOOK" "$COMPACT"
assert_unmarked "a single compression tool does not need the coordinator"
reset "$TWO_CFG"; tg2_run "$HOOK" "$COMPACT"
assert_unmarked "two tools without leanctx: no leanctx phase is recorded"
reset "$LEAN_SUSPENDED"; tg2_run "$HOOK" "$COMPACT"
assert_unmarked "suspended leanctx does not record its phase"
reset; mkdir -p "$MARK"
tg2_run "$HOOK" "$COMPACT"
if [[ "$TL_STATUS" == 0 && -z "$TL_OUT" && -d "$MARK" ]]; then tl_pass "unwritable marker path is tolerated"; else tl_fail "unwritable marker path (status=$TL_STATUS out=$TL_OUT)"; fi
rmdir "$MARK"

reset; tg2_farm nogate "$HOOK" sb-project-gate.sh project-active.sh
TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" tg2_run "$HOOK" "$COMPACT"
assert_unmarked "without the project-gate library no config is found"
reset; tg2_farm nolib "$HOOK" -
TG2_REPO="$TG2_FARM" tg2_run "$HOOK" "$COMPACT"
assert_unmarked "missing lib dir fails open"

tl_results
