#!/usr/bin/env bash
# Shared PreToolUse gate assertions, part a (deny, audit, bridge, input shapes) for hooks/token-compression-tools-gate.sh (tg2_gate_suite)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
tg2_install_jq_stub

HOOK=hooks/token-compression-tools-gate.sh
RTK_STATE="$SB_RUNTIME_STATE_DIR/rtk-usage"
MUTEX="$SB_RUNTIME_STATE_DIR/stack-compression-mutex"
CFG_JSON='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed"}}}'
EDIT="$(tg2_edit_input)"

install_rtk() { tl_stub rtk 'exit 0'; }
uninstall_rtk() { rm -f "$TL_BIN/rtk"; }
fresh() { date +%s >"$RTK_STATE"; }
reset() { rm -f "$RTK_STATE" "$MUTEX" "$SB_RUNTIME_STATE_DIR/project-root"; uninstall_rtk; tg2_cfg "$CFG_JSON"; }
dirty_mutex() { printf '{"violations":[{"route":"sb_shell","attempted":"leanctx","incumbent":"rtk","reason":"x","epoch":1}]}' >"$MUTEX"; }

tg2_scenario_block() { reset; }
tg2_scenario_off() {
  case "$1" in
    optout) jq '.recommended_tools.rtk.enabled_by_user=false' <<<"$CFG_JSON" >"$TG2_CFG" ;;
    suspended) jq '.recommended_tools.rtk.enforcement_suspended=true' <<<"$CFG_JSON" >"$TG2_CFG" ;;
  esac
}
TG2_SUITE_PART=a tg2_gate_suite "$HOOK" token-compression-tools-gate "$EDIT" "USAGE REQUIRED" "$TG2_PROJ/src/app.js" yes no

tl_results
