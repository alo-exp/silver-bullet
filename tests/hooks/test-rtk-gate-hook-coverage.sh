#!/usr/bin/env bash
# Behavior tests for hooks/rtk-gate.sh (PreToolUse RTK install/wiring gate)
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


# ----------------------------------------------------- CLI / version / wiring states
cfg; uninstall_rtk
run "$EDIT"
assert_denied "no rtk on PATH: install message" "RTK REQUIRED"
assert_contains "no-CLI message names verification commands" "$(tg2_reason)" "rtk gain --help"

install_rtk
run "$EDIT"
assert_silent_ok "healthy rtk + wired host hook allows"

run "$EDIT" RTK_STUB_GAIN=1
assert_denied "rtk without a working gain command is the wrong binary" "RTK WRONG BINARY"
run "$EDIT" RTK_STUB_HELP="Rust Type Kit - checks"
assert_denied "Rust Type Kit help text is the wrong binary" "RTK WRONG BINARY"
run "$EDIT" RTK_STUB_VERSION="rtk 0.1.0"
assert_denied "outdated rtk version is rejected" "RTK REQUIRED"
run "$EDIT" RTK_STUB_VERSION="rtk 9.0.0"
assert_silent_ok "newer major version passes"
run "$EDIT" RTK_STUB_VERSION="not a version"
assert_denied "unparsable version is rejected" "RTK REQUIRED"
jq '.recommended_tools.rtk.min_version="0.1.0"' <<<"$RTK_CFG" >"$TG2_CFG"
run "$EDIT" RTK_STUB_VERSION="rtk 1.0.0"
assert_silent_ok "configured min_version is honoured"
cfg

run "$EDIT" SB_RTK_HOOK_ARTIFACT="$TL_TMP/absent.json"
assert_denied "unwired host hook is denied" "RTK HOOK NOT WIRED"
assert_contains "unwired message names the expected artifact" "$(tg2_reason)" "$TL_TMP/absent.json"
printf 'nothing relevant\n' >"$TL_TMP/other.json"
run "$EDIT" SB_RTK_HOOK_ARTIFACT="$TL_TMP/other.json"
assert_denied "artifact without an rtk reference is denied" "RTK HOOK NOT WIRED"
# default artifact for the claude host
mkdir -p "$HOME/.claude"
printf '{"hooks":[{"command":"rtk hook claude"}]}\n' >"$HOME/.claude/settings.json"
tg2_run "$HOOK" "$EDIT" SILVER_BULLET_RUNTIME=claude SB_RTK_HOOK_ARTIFACT=
assert_silent_ok "claude host default artifact (~/.claude/settings.json) counts as wired"
rm -f "$HOME/.claude/settings.json"
tg2_run "$HOOK" "$EDIT" SILVER_BULLET_RUNTIME=claude SB_RTK_HOOK_ARTIFACT=
assert_denied "claude host without settings.json is unwired" "RTK HOOK NOT WIRED"

tl_results
