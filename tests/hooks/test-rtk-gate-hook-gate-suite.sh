#!/usr/bin/env bash
# Shared PreToolUse gate assertions, part a (deny, audit, bridge, input shapes) for hooks/rtk-gate.sh (tg2_gate_suite)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
tg2_install_jq_stub

HOOK=hooks/rtk-gate.sh
RTK_CFG='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
ARTIFACT="$TL_TMP/rtk-wired.json"
printf '{"hooks":["rtk"]}\n' >"$ARTIFACT"
EDIT="$(tg2_edit_input)"

# rtk stub driven by env: RTK_STUB_GAIN (exit code of `gain`), RTK_STUB_VERSION
install_rtk() {
  tl_stub rtk 'case "${1:-}" in
  gain) exit "${RTK_STUB_GAIN:-0}" ;;
  --help) echo "${RTK_STUB_HELP:-rtk token killer help}" ;;
  --version) echo "${RTK_STUB_VERSION:-rtk 0.42.4}" ;;
esac
exit 0'
}
uninstall_rtk() { rm -f "$TL_BIN/rtk"; }
cfg() { tg2_cfg "$RTK_CFG"; }
run() { tg2_run "$HOOK" "$1" SB_RTK_HOOK_ARTIFACT="$ARTIFACT" "${@:2}"; }

tg2_scenario_block() { uninstall_rtk; cfg; }
tg2_scenario_off() {
  case "$1" in
    optout) jq '.recommended_tools.rtk.enabled_by_user=false' <<<"$RTK_CFG" >"$TG2_CFG" ;;
    suspended) jq '.recommended_tools.rtk.enforcement_suspended=true' <<<"$RTK_CFG" >"$TG2_CFG" ;;
  esac
}
# gate suite needs SB_RTK_HOOK_ARTIFACT only on the allow side; the baseline denies on missing CLI.
TG2_SUITE_PART=a tg2_gate_suite "$HOOK" rtk-gate "$EDIT" "RTK REQUIRED" "$TG2_PROJ/src/app.js" yes yes

tl_results
