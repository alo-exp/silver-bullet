#!/usr/bin/env bash
# Behavior tests for hooks/rtk-gate.sh: gated tool surfaces and commands
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


# ----------------------------------------------------------------- tool surfaces
cfg; uninstall_rtk
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
