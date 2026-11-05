#!/usr/bin/env bash
# receipts.sh rt_apply_host_hooks_batch (cursor / opencode / pi hook patchers) and
# rt_apply_host_mcp_batch (MCP patcher). Patchers are logging stubs in a
# staged repo; host config files live in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"  # never run with the checkout as cwd: stubs and relative writes stay in the sandbox

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-cross-tool.sh"
rt_init_paths
export RT_HOST=cursor RT_SKIP_VENDOR_DOCTOR=1 SILVER_BULLET_SESSION_ID=sess-x
hr_bin sleep 'exit 0'
mkdir -p "$HOME/.cursor"
ALL_ENABLED=(graphify=enabled agentmemory=enabled rtk=enabled context_mode=enabled leanctx=enabled)

apply_env() { export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all; }
apply_env
j() { jq -c .; }
log() { cat "$HR_LOG"; }
# a patcher that "changes" the file it manages: appends to it from the stub
CHANGE_HOOKS='echo x >> "$HOME/.cursor/hooks.json"'
CHANGE_MCP='echo x >> "$HOME/.cursor/mcp.json"'
echo '{}' >"$HOME/.cursor/hooks.json"; echo '{}' >"$HOME/.cursor/mcp.json"

# ============================================================== hooks batch
hr_consent "${ALL_ENABLED[@]}"
: >"$HR_LOG"
out="$(HR_PY_OUT_patch_hooks="patched" HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS" rt_apply_host_hooks_batch | j)"
assert_eq "hooks (cursor): changed" '{"actions":["patch_hooks"],"failures":[],"changed":true}' "$out"
assert_contains "hooks: every consented tool patched" "$(log)" "RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_GRAPHIFY=1 RT_PATCH_LEANCTX=1 RT_PATCH_RTK=1"
assert_eq "hooks: patch env cleaned up" "" "${RT_PATCH_RTK:-}${RT_PATCH_GRAPHIFY:-}${RT_PATCH_LEANCTX:-}"
out="$(HR_PY_OUT_patch_hooks="hooks.json unchanged" HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS" rt_apply_host_hooks_batch | j)"
assert_eq "hooks: patcher reports unchanged" '{"actions":[],"failures":[],"changed":false}' "$out"
out="$(HR_PY_OUT_patch_hooks="patched" rt_apply_host_hooks_batch | j)"
assert_eq "hooks: output but identical file hash" '{"actions":[],"failures":[],"changed":false}' "$out"
out="$(HR_PY_RC_patch_hooks=1 rt_apply_host_hooks_batch | j)"
assert_eq "hooks: patcher failure" '{"actions":[],"failures":["patch_hooks_failed"],"changed":false}' "$out"
out="$(rt_apply_host_hooks_batch | j)"
assert_eq "hooks: silent patcher counts as no change" '{"actions":[],"failures":[],"changed":false}' "$out"
hr_consent rtk=enabled
: >"$HR_LOG"; rt_apply_host_hooks_batch >/dev/null
assert_contains "hooks: only consented tools are enabled" "$(log)" "RT_PATCH_AGENTMEMORY=0 RT_PATCH_CONTEXT_MODE=0 RT_PATCH_GRAPHIFY=0 RT_PATCH_LEANCTX=0 RT_PATCH_RTK=1"
hr_consent graphify=disabled
: >"$HR_LOG"
assert_eq "hooks: nothing consented -> no patch run" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
assert_eq "hooks: patcher not invoked" "" "$(log)"
hr_consent "${ALL_ENABLED[@]}"
mv "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.py" "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.off"
assert_eq "hooks: patch-hooks.py missing" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
mv "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.off" "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.py"
RT_HOST=claude; assert_eq "hooks (claude): not patched" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
RT_HOST=opencode
: >"$HR_LOG"
assert_eq "hooks (opencode): both plugins" '{"actions":["opencode_rtk_plugin","opencode_context_mode_plugin"],"failures":[],"changed":true}' "$(rt_apply_host_hooks_batch | j)"
assert_contains "hooks (opencode): rtk-only merge" "$(log)" "--host opencode --repo-root $HR_STAGE --rtk-only"
assert_contains "hooks (opencode): context-mode-only merge" "$(log)" "--context-mode-only"
assert_eq "hooks (opencode): merge failures" '{"actions":[],"failures":["opencode_rtk_plugin_failed","opencode_context_mode_plugin_failed"],"changed":false}' "$(HR_PY_RC_merge_token=1 rt_apply_host_hooks_batch | j)"
hr_consent rtk=enabled
assert_eq "hooks (opencode): only rtk consented" '{"actions":["opencode_rtk_plugin"],"failures":[],"changed":true}' "$(rt_apply_host_hooks_batch | j)"
hr_consent context_mode=enabled
assert_eq "hooks (opencode): only context-mode consented" '{"actions":["opencode_context_mode_plugin"],"failures":[],"changed":true}' "$(rt_apply_host_hooks_batch | j)"
mv "$HR_STAGE/scripts/lib/merge-token-compression-config.py" "$HR_STAGE/scripts/lib/merge.off"
assert_eq "hooks (opencode): merge helper missing" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
mv "$HR_STAGE/scripts/lib/merge.off" "$HR_STAGE/scripts/lib/merge-token-compression-config.py"
RT_HOST=pi
hr_consent "${ALL_ENABLED[@]}"
: >"$HR_LOG"
assert_eq "hooks (pi): adapter installed" '{"actions":["pi_host_adapter"],"failures":[],"changed":true}' "$(rt_apply_host_hooks_batch | j)"
assert_contains "hooks (pi): tools enabled" "$(log)" "--repo-root $HR_STAGE --enable-tool rtk --enable-tool context_mode"
assert_eq "hooks (pi): adapter failure" '{"actions":[],"failures":["pi_host_adapter_failed"],"changed":false}' "$(HR_PY_RC_install_pi=1 rt_apply_host_hooks_batch | j)"
hr_consent graphify=enabled
assert_eq "hooks (pi): neither rtk nor context-mode consented" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
hr_consent rtk=enabled
mv "$HR_STAGE/scripts/lib/global-toolstack/install-pi.py" "$HR_STAGE/scripts/lib/global-toolstack/install-pi.off"
assert_eq "hooks (pi): installer missing" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_hooks_batch | j)"
mv "$HR_STAGE/scripts/lib/global-toolstack/install-pi.off" "$HR_STAGE/scripts/lib/global-toolstack/install-pi.py"
RT_HOST=cursor


# ================================================================= mcp batch
hr_consent "${ALL_ENABLED[@]}"
: >"$HR_LOG"
assert_eq "mcp: changed" '{"actions":["patch_mcp"],"failures":[],"changed":true}' "$(HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP" rt_apply_host_mcp_batch | j)"
assert_contains "mcp: all consented servers patched" "$(log)" "RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_GRAPHIFY=1 RT_PATCH_LEANCTX=1"
assert_contains "mcp: host passed to the patcher" "$(log)" "RT_HOST=cursor"
assert_eq "mcp: unchanged output" '{"actions":[],"failures":[],"changed":false}' "$(HR_PY_OUT_patch_mcp="mcp.json unchanged" HR_PY_HOOK_patch_mcp="$CHANGE_MCP" rt_apply_host_mcp_batch | j)"
assert_eq "mcp: failure" '{"actions":[],"failures":["patch_mcp_failed"],"changed":false}' "$(HR_PY_RC_patch_mcp=2 rt_apply_host_mcp_batch | j)"
assert_eq "mcp: silent patcher" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_mcp_batch | j)"
hr_consent rtk=enabled
: >"$HR_LOG"
assert_eq "mcp: nothing mcp-related consented -> not run" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_mcp_batch | j)"
assert_eq "mcp: patcher not invoked" "" "$(log)"
hr_consent context_mode=enabled
assert_eq "mcp: context-mode alone triggers the patcher" '{"actions":["patch_mcp"],"failures":[],"changed":true}' "$(HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP" rt_apply_host_mcp_batch | j)"
RT_HOST=claude; hr_consent graphify=enabled
: >"$HR_LOG"
assert_eq "mcp (claude): hash of the claude config is watched" '{"actions":["patch_mcp"],"failures":[],"changed":true}' "$(HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp='echo x >> "$HOME/.claude.json"' rt_apply_host_mcp_batch | j)"
RT_HOST=cursor
mv "$HR_STAGE/scripts/lib/global-toolstack/patch-mcp.py" "$HR_STAGE/scripts/lib/global-toolstack/patch-mcp.off"
assert_eq "mcp: patch-mcp.py missing" '{"actions":[],"failures":[],"changed":false}' "$(rt_apply_host_mcp_batch | j)"
mv "$HR_STAGE/scripts/lib/global-toolstack/patch-mcp.off" "$HR_STAGE/scripts/lib/global-toolstack/patch-mcp.py"


tl_results
