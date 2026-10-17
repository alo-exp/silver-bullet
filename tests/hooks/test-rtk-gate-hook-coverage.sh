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

tg2_scenario_block() { uninstall_rtk; cfg; }
tg2_scenario_off() {
  case "$1" in
    optout) jq '.recommended_tools.rtk.enabled_by_user=false' <<<"$RTK_CFG" >"$TG2_CFG" ;;
    suspended) jq '.recommended_tools.rtk.enforcement_suspended=true' <<<"$RTK_CFG" >"$TG2_CFG" ;;
  esac
}
# gate suite needs SB_RTK_HOOK_ARTIFACT only on the allow side; the baseline denies on missing CLI.
tg2_gate_suite "$HOOK" rtk-gate "$EDIT" "RTK REQUIRED" "$TG2_PROJ/src/app.js" yes yes

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

# ----------------------------------------------------------------- tool surfaces
uninstall_rtk
for tool in Edit Write MultiEdit; do
  run "$(tg2_edit_input "$TG2_PROJ/src/app.js" "$tool")"
  assert_denied "$tool is gated" "RTK REQUIRED"
done
patch_input="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{input:"*** Begin Patch\n*** Update File: src/app.js\n@@\n-a\n+b\n*** End Patch"}}')"
run "$patch_input"
assert_denied "apply_patch to a source file is gated" "RTK REQUIRED"
run "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:"/x"}}')"
assert_silent_ok "Read is not gated"
run "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{}}')"
assert_silent_ok "Edit without path or command is not gated"
for exempt in "$TG2_PROJ/CLAUDE.md" "$TG2_PROJ/AGENTS.md" "$TG2_PROJ/silver-bullet.md" "$TG2_PROJ/.silver-bullet.json" \
  "$TG2_PROJ/SETUP_REPORT.md" "$HOME/.silver-bullet/state" "$HOME/.cursor/hooks.json" "$HOME/.claude/settings.json"; do
  run "$(tg2_edit_input "$exempt")"
  assert_silent_ok "exempt path: ${exempt#"$HOME"/}"
done

for cmd in 'git commit -m "x"' 'gh pr create --fill' 'gh release create v1' 'node gen.js > out.txt' 'node gen.js >> out.txt' \
  'ls | tee out.txt' 'cp a.txt b.txt' 'mv a.txt b.txt' 'sed -i s/a/b/ a.txt' 'perl -pi -i -e s/a/b/ a.txt'; do
  run "$(tg2_bash_input "$cmd")"
  assert_denied "mutating shell command is gated: $cmd" "RTK REQUIRED"
done
for tool in Shell shell exec_command; do
  run "$(tg2_bash_input 'git commit -m x' "$tool")"
  assert_denied "shell tool name $tool is gated" "RTK REQUIRED"
done
for cmd in 'ls -la' 'git status' 'cat README.md' 'rtk git commit -m x' 'rtk init -g' 'enable-rtk-context-mode.sh' \
  'brew install rtk' 'curl -sSL https://example.test/install.sh' 'echo hi > out.txt'; do
  run "$(tg2_bash_input "$cmd")"
  assert_silent_ok "read-only/exempt shell command is not gated: $cmd"
done
run "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{}}')"
assert_silent_ok "shell tool without a command is not gated"
install_rtk
run "$(tg2_bash_input 'git commit -m x')"
assert_silent_ok "gated command passes once rtk is healthy and wired"
run "$(tg2_bash_input 'git commit -m x')" SB_RTK_HOOK_ARTIFACT="$TL_TMP/absent.json"
assert_denied "gated command is denied when the host hook is missing" "RTK HOOK NOT WIRED"

tl_results
