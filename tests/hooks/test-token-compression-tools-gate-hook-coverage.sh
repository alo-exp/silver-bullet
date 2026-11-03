#!/usr/bin/env bash
# Behavior tests for hooks/token-compression-tools-gate.sh (PreToolUse RTK usage freshness)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
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
CFG_TWO='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed"},"context_mode":{"enabled_by_user":true}}}'
# Consent for RTK alone (consent is per tool: the all-tools store would enable the whole stack).
ALL_CONSENT="$XDG_CONFIG_HOME"
sb_test_consent_sandbox; sb_test_consent_grant rtk install,wire,enforce
RTK_ONLY="$XDG_CONFIG_HOME"; export XDG_CONFIG_HOME="$ALL_CONSENT"
# R5-16: the gate guards delivery commands only; edits are never gated.
EDIT="$(tg2_bash_input 'git commit -m x')"

install_rtk() { tl_stub rtk 'exit 0'; }
uninstall_rtk() { rm -f "$TL_BIN/rtk"; }
fresh() { date +%s >"$RTK_STATE"; }
reset() { rm -rf "$RTK_STATE" "$MUTEX" "$SB_RUNTIME_STATE_DIR/stack-compression-mutex.d" "$SB_RUNTIME_STATE_DIR/project-root"; uninstall_rtk; tg2_cfg "$CFG_JSON"; }
# The coordinator's violation state is scoped to one project and one host session (R5-13).
mutex_path() { ( source "$TL_REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"; SB_STACK_SESSION="${1:-}"; export SB_STACK_SESSION; sb_stack_mutex_state_path "$TG2_CFG" ); }
dirty_mutex() { local p; p="$(mutex_path "${1:-}")"; mkdir -p "$(dirname "$p")"; printf '{"violations":[{"route":"sb_shell","attempted":"leanctx","incumbent":"rtk","reason":"x","epoch":1}]}' >"$p"; }


# ------------------------------------------------------ rtk CLI / usage freshness
reset
tg2_run "$HOOK" "$EDIT"
assert_denied "rtk CLI missing: denied" "RTK USAGE REQUIRED"
assert_contains "denial names the CLI" "$(tg2_reason)" "run rtk"
assert_contains "denial names the TTL" "$(tg2_reason)" "1800s"

install_rtk
tg2_run "$HOOK" "$EDIT"
assert_denied "rtk installed but never used: denied" "RTK USAGE REQUIRED"
fresh
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "fresh rtk usage allows the edit"
echo "$(( $(date +%s) - 4000 ))" >"$RTK_STATE"
tg2_run "$HOOK" "$EDIT"
assert_denied "stale rtk usage is denied" "RTK USAGE REQUIRED"
echo "garbage" >"$RTK_STATE"
tg2_run "$HOOK" "$EDIT"
assert_denied "unparsable usage state is denied" "RTK USAGE REQUIRED"
fresh; jq '.recommended_tools.rtk.install_status="failed"' <<<"$CFG_JSON" >"$TG2_CFG"
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "rtk not installed (install_status) is not enforced"
echo "$(( $(date +%s) - 4000 ))" >"$RTK_STATE"
jq '.recommended_tools.rtk.usage_ttl_seconds=9999' <<<"$CFG_JSON" >"$TG2_CFG"
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "configured usage TTL is honoured"
tg2_cfg "$CFG_JSON"
jq --arg p "~${SB_RUNTIME_STATE_DIR#"$HOME"}/custom-rtk-usage" '.recommended_tools.rtk.usage_state_file=$p' <<<"$CFG_JSON" >"$TG2_CFG"
date +%s >"$SB_RUNTIME_STATE_DIR/custom-rtk-usage"
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "configured usage_state_file (with ~) is read"
rm -f "$SB_RUNTIME_STATE_DIR/custom-rtk-usage"

# ------------------------------------------------------------------ tool surfaces
reset
# R5-16: edits are never gated by RTK usage (the gate guards commits, PRs and releases)
for tool in Edit Write MultiEdit; do
  tg2_run "$HOOK" "$(tg2_edit_input "$TG2_PROJ/src/app.js" "$tool")"
  assert_silent_ok "$tool is not gated by stale RTK usage"
done
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{input:"*** Begin Patch\n*** Update File: src/app.js\n@@\n-a\n+b\n*** End Patch"}}')"
assert_silent_ok "apply_patch is not gated by stale RTK usage"
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:"/x"}}')"
assert_silent_ok "Read is not gated"
for cmd in 'git commit -m x' 'gh pr create --fill' 'gh release create v1'; do
  tg2_run "$HOOK" "$(tg2_bash_input "$cmd")"
  assert_denied "delivery command is gated: $cmd" "RTK USAGE REQUIRED"
done
for tool in Shell shell exec_command; do
  tg2_run "$HOOK" "$(tg2_bash_input 'git commit -m x' "$tool")"
  assert_denied "shell tool name $tool is gated" "RTK USAGE REQUIRED"
done
for cmd in 'ls -la' 'git status' 'npm test'; do
  tg2_run "$HOOK" "$(tg2_bash_input "$cmd")"
  assert_silent_ok "non-delivery shell command is not gated: $cmd"
done
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{}}')"
assert_silent_ok "a shell call without a command is not a delivery step"
for cmd in 'echo "git commit"' "git log --grep 'gh pr create'"; do
  tg2_run "$HOOK" "$(tg2_bash_input "$cmd")"
  assert_silent_ok "a mention of a delivery command is not a delivery step: $cmd"
done
install_rtk; fresh
tg2_run "$HOOK" "$(tg2_bash_input 'git commit -m x')"
assert_silent_ok "delivery command passes with fresh rtk usage"

# ---------------------------------------------------- mutual-exclusion state
reset; tg2_cfg "$CFG_TWO"; install_rtk; fresh; dirty_mutex
tg2_run "$HOOK" "$EDIT"
assert_denied "dirty stack mutex blocks even with fresh rtk usage" "STACK COMPRESSION CONFLICT"
tg2_run "$HOOK" "$(tg2_bash_input 'git commit -m x')"
assert_denied "dirty stack mutex blocks delivery commands" "STACK COMPRESSION CONFLICT"
tg2_run "$HOOK" "$(tg2_bash_input 'ls -la')"
assert_silent_ok "non-delivery commands skip the mutex check"
# a violation recorded by another session never blocks this one
reset; tg2_cfg "$CFG_TWO"; install_rtk; fresh; dirty_mutex "other-session"
tg2_run "$HOOK" "$(jq -c '.session_id = "mine"' <<<"$EDIT")"
assert_silent_ok "another session's violation does not block this session"
tg2_run "$HOOK" "$(jq -c '.session_id = "other-session"' <<<"$EDIT")"
assert_denied "the same session's violation blocks" "STACK COMPRESSION CONFLICT"
reset; tg2_cfg "$CFG_TWO"; install_rtk; fresh; dirty_mutex
rm -rf "$SB_RUNTIME_STATE_DIR/stack-compression-mutex.d"
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "clean mutex state allows"
mkdir -p "$(dirname "$(mutex_path)")"; printf '{"violations":[]}' >"$(mutex_path)"
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "mutex file with zero violations is clean"
reset; tg2_cfg "$CFG_JSON"; install_rtk; fresh; dirty_mutex
tg2_run "$HOOK" "$EDIT" XDG_CONFIG_HOME="$RTK_ONLY"
assert_silent_ok "mutex is only enforced when two or more compression tools are enabled"
reset; tg2_cfg "$CFG_TWO"; install_rtk; fresh; dirty_mutex
tg2_farm no-stack "$HOOK" stack-compression-coordinator.sh
TG2_REPO="$TG2_FARM" tg2_run "$HOOK" "$EDIT"
assert_silent_ok "without the coordinator library the mutex check is skipped"

tl_results
