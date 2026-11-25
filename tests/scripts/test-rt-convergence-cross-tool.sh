#!/usr/bin/env bash
# receipts.sh host convergence batches (hooks + MCP patchers). Patchers are logging stubs in a
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
export RT_HOST=claude RT_SKIP_VENDOR_DOCTOR=1 SILVER_BULLET_SESSION_ID=sess-x
hr_bin sleep 'exit 0'
mkdir -p "$HOME/.claude"
ALL_ENABLED=(graphify=enabled agentmemory=enabled rtk=enabled context_mode=enabled leanctx=enabled)

apply_env() { export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all; }
apply_env
j() { jq -c .; }
log() { cat "$HR_LOG"; }
# a patcher that "changes" the file it manages: appends to it from the stub
CHANGE_MCP='echo x >> "$HOME/.claude.json"'
echo '{}' >"$HOME/.claude/settings.json"; echo '{}' >"$HOME/.claude.json"

# ============================================================ convergence batch
RT_MODE=verify
hr_consent "${ALL_ENABLED[@]}"
assert_eq "convergence: verify mode mutates nothing" '{"actions":[],"failures":[],"restart_required":false,"changed":false,"affected_servers":[]}' "$(rt_apply_host_convergence_batches | j)"
apply_env
hr_consent graphify=disabled
assert_eq "convergence: nobody consented" '{"actions":[],"failures":[],"restart_required":false,"changed":false,"affected_servers":[]}' "$(rt_apply_host_convergence_batches | j)"
hr_consent "${ALL_ENABLED[@]}"
# a single consented tool is enough to trigger the batches
hr_consent context_mode=enabled
assert_eq "convergence: only context-mode (no MCP batch for it)" 'null' "$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches false) | jq -c '.actions[0]')"
hr_consent leanctx=enabled
assert_eq "convergence: only leanctx" '"patch_mcp"' "$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches false) | jq -c '.actions[0]')"
hr_consent "${ALL_ENABLED[@]}"
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: hooks + mcp changed, receipt created" '{"actions":["patch_mcp","reload_receipt_created"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["graphify","leanctx","agentmemory"]}' "$out"
PID="$(rt_project_id)"; WID="$(rt_worktree_id "$HR_PROJ")"
RECEIPT_FILE="$(rt_receipt_list_paths claude "$PID" "$WID" | head -1)"
assert_file_exists "convergence: receipt written" "$RECEIPT_FILE"
assert_eq "convergence: receipt lists the affected servers" '["graphify","leanctx","agentmemory"]' "$(jq -c .affected_servers "$RECEIPT_FILE")"
assert_eq "convergence: batch env cleaned up" "" "${RT_PRE_CONFIG_HASHES:-}${RT_CHANGE_SET_ID:-}"

# hosts whose hook patchers report back: their actions and failures reach the combined result, a changed hook
# batch needs a restart, and only context-mode is named as affected by it (the MCP batch has nothing to patch here)
RT_HOST=opencode; hr_consent "${ALL_ENABLED[@]}"
assert_eq "convergence (opencode): plugins installed, context-mode affected" '{"actions":["opencode_rtk_plugin","opencode_context_mode_plugin"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["context-mode"]}' "$(rt_apply_host_convergence_batches false | j)"
assert_eq "convergence (opencode): patcher failures are reported, nothing restarts" '{"actions":[],"failures":["opencode_rtk_plugin_failed","opencode_context_mode_plugin_failed"],"restart_required":false,"changed":false,"affected_servers":[]}' "$(HR_PY_RC_merge_token=1 rt_apply_host_convergence_batches false | j)"
# a hook batch that changed a host which consented only to rtk: restart needed, no server affected, and the reload
# receipt is created with an empty server list
RT_HOST=pi; hr_consent rtk=enabled
rm -rf "$SB_RUNTIME_STATE_DIR/recommended-tools"
assert_eq "convergence (pi, rtk only): restart with no affected server, receipt created" '{"actions":["pi_host_adapter","reload_receipt_created"],"failures":[],"restart_required":true,"changed":true,"affected_servers":[]}' "$(rt_apply_host_convergence_batches true | j)"
PID="$(rt_project_id)"; WID="$(rt_worktree_id "$HR_PROJ")"
RECEIPT_FILE="$(rt_receipt_list_paths pi "$PID" "$WID" | head -1)"
assert_file_exists "convergence (pi, rtk only): receipt written" "$RECEIPT_FILE"
assert_eq "convergence (pi, rtk only): receipt lists no affected server" '[]' "$(jq -c .affected_servers "$RECEIPT_FILE")"
RT_HOST=claude

tl_results
