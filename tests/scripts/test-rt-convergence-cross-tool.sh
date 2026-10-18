#!/usr/bin/env bash
# receipts.sh host convergence batches (hooks + MCP patchers) and probe-cross-tool.sh
# (route ownership, hook order, heartbeat, repair). Patchers are logging stubs in a
# staged repo; host config files live in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"

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
assert_eq "convergence: only context-mode" '"patch_hooks"' "$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS"; rt_apply_host_convergence_batches false) | jq -c '.actions[0]')"
hr_consent leanctx=enabled
assert_eq "convergence: only leanctx" '"patch_hooks"' "$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS"; rt_apply_host_convergence_batches false) | jq -c '.actions[0]')"
hr_consent "${ALL_ENABLED[@]}"
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS" HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: hooks + mcp changed, receipt created" '{"actions":["patch_hooks","patch_mcp","reload_receipt_created"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["context-mode","graphify","leanctx","agentmemory"]}' "$out"
PID="$(rt_project_id)"; WID="$(rt_worktree_id "$HR_PROJ")"
RECEIPT_FILE="$(rt_receipt_list_paths cursor "$PID" "$WID" | head -1)"
assert_file_exists "convergence: receipt written" "$RECEIPT_FILE"
assert_eq "convergence: receipt lists the affected servers" '["context-mode","graphify","leanctx","agentmemory"]' "$(jq -c .affected_servers "$RECEIPT_FILE")"
assert_eq "convergence: batch env cleaned up" "" "${RT_PRE_CONFIG_HASHES:-}${RT_CHANGE_SET_ID:-}"
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS"; rt_apply_host_convergence_batches false) | jq -c .)"
assert_eq "convergence: receipt creation disabled" '{"actions":["patch_hooks"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["context-mode"]}' "$out"
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS" RT_SUPPRESS_RELOAD_RECEIPT_CREATE=1; rt_apply_host_convergence_batches true) | jq -c .)"
assert_contains "convergence: receipt creation suppressed by consume" "$out" '"actions":["patch_hooks"]'
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches false) | jq -c .)"
assert_eq "convergence: mcp only" '{"actions":["patch_mcp"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["graphify","leanctx","agentmemory"]}' "$out"
hr_consent rtk=enabled
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: hooks change without context-mode -> no affected server, receipt still created" '{"actions":["patch_hooks","reload_receipt_created"],"failures":[],"restart_required":true,"changed":true,"affected_servers":[]}' "$out"
hr_consent "${ALL_ENABLED[@]}"
out="$( (export HR_PY_RC_patch_hooks=1 HR_PY_RC_patch_mcp=1; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: batch failures carried through" '{"actions":[],"failures":["patch_hooks_failed","patch_mcp_failed"],"restart_required":false,"changed":false,"affected_servers":[]}' "$out"
# receipt creation failure is reported
rm -rf "$SB_RUNTIME_STATE_DIR/recommended-tools"; printf 'file\n' >"$SB_RUNTIME_STATE_DIR/recommended-tools"
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_contains "convergence: receipt failure reported" "$out" '"reload_receipt_failed"'
rm -f "$SB_RUNTIME_STATE_DIR/recommended-tools"

# ============================================================ cross-tool probe
routes_json() { jq -n --arg drop "${1:-}" '{optimization_profiles:{five_tool_routed:{routes:{sb_wire:"leanctx",sb_read:"leanctx",sb_grep:"context_mode",sb_shell:"rtk",sb_slice:"context_mode",sb_webfetch:"context_mode",sb_graph:"graphify",sb_remember:"agentmemory",sb_pathjail:"leanctx",sb_injection:"leanctx"}}}} | if $drop != "" and $drop != "null" then del(.optimization_profiles.five_tool_routed.routes[$drop]) else . end'; }
cfg_with() { # <routes-drop> consent specs...
  local drop="$1"; shift
  hr_consent "$@"
  jq -c --argjson r "$(routes_json "$drop")" '. + $r' "$HR_PROJ/.silver-bullet.json" >"$HR_PROJ/.sb.tmp"; mv "$HR_PROJ/.sb.tmp" "$HR_PROJ/.silver-bullet.json"
}
pct() { hr_state "$(rt_probe_cross_tool)"; }
assert_eq "routes: no config" "1" "$(RT_CONFIG_FILE="$TL_TMP/none.json" rc_of rt_probe_five_tool_routes)"
cfg_with null "${ALL_ENABLED[@]}"
assert_eq "routes: complete" "0" "$(rc_of rt_probe_five_tool_routes)"
cfg_with sb_graph "${ALL_ENABLED[@]}"
assert_eq "routes: a missing route is drift" "1" "$(rc_of rt_probe_five_tool_routes)"
cfg_with null "${ALL_ENABLED[@]}"
jq '.optimization_profiles.five_tool_routed.routes.sb_shell="leanctx"' "$HR_PROJ/.silver-bullet.json" >"$HR_PROJ/.sb.tmp"; mv "$HR_PROJ/.sb.tmp" "$HR_PROJ/.silver-bullet.json"
assert_eq "routes: a wrong owner is drift" "1" "$(rc_of rt_probe_five_tool_routes)"
assert_eq "any consented: none" "1" "$(hr_consent graphify=disabled; rc_of rt_any_five_tool_consented)"
assert_eq "any consented: one" "0" "$(hr_consent leanctx=enabled; rc_of rt_any_five_tool_consented)"

RT_HOST=goose; assert_eq "cross: unsupported host" "unsupported|none||false" "$(pct)"; RT_HOST=cursor
hr_consent graphify=disabled
assert_eq "cross: nothing consented" "ready|none|no_five_tool_consent|false" "$(pct)"
cfg_with sb_graph "${ALL_ENABLED[@]}"
assert_eq "cross: route drift" "repairable|none|route_ownership_drift|true" "$(pct)"
cfg_with null "${ALL_ENABLED[@]}"
rm -f "$HOME/.cursor/hooks.json"
assert_eq "cross: shell owner is not rtk" "repairable|none|shell_owner_not_rtk|true" "$(pct)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"},{"command":"lean-ctx hook rewrite"}]}}' >"$HOME/.cursor/hooks.json"
assert_eq "cross: lean-ctx rewrite hook" "repairable|none|leanctx_shell_rewrite|true" "$(pct)"
echo '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse"},{"command":"rtk hook cursor"}]}}' >"$HOME/.cursor/hooks.json"
assert_eq "cross: rtk after context-mode" "repairable|none|hook_order_rtk_after_cm|true" "$(pct)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"},{"command":"context-mode hook cursor pretooluse"}]}}' >"$HOME/.cursor/hooks.json"
assert_eq "cross: heartbeat absent" "repairable|none|heartbeat_absent_or_invalid|true" "$(pct)"
RT_MODE=verify rt_heartbeat_write "$HR_PROJ" cursor
assert_eq "cross: ready with a valid heartbeat" "ready|full||false" "$(pct)"

# ============================================================ cross-tool repair
RT_MODE=verify
assert_eq "cross repair: verify mode" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_cross_tool | jq -c .)"
export RT_MODE=apply RT_ENTRY_POINT=bogus
assert_eq "cross repair: bad entry point" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_cross_tool | jq -c .)"
export RT_ENTRY_POINT=init
rm -rf "$SB_RUNTIME_STATE_DIR/recommended-tools"
out="$( (export HR_PY_OUT_patch_hooks=patched HR_PY_HOOK_patch_hooks="$CHANGE_HOOKS" HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_repair_cross_tool) | jq -c .)"
assert_eq "cross repair: convergence and heartbeat" '{"actions":["patch_hooks","patch_mcp","reload_receipt_created","heartbeat_written"],"failures":[],"restart_required":true}' "$out"
out="$(rt_repair_cross_tool | jq -c .)"
assert_eq "cross repair: converged host only refreshes the heartbeat" '{"actions":["heartbeat_written"],"failures":[],"restart_required":false}' "$out"
out="$( (export HR_PY_RC_patch_hooks=1; rt_heartbeat_write() { return 1; }; rt_repair_cross_tool) | jq -c .)"
assert_eq "cross repair: failures reported" '{"actions":[],"failures":["patch_hooks_failed","heartbeat_write_failed"],"restart_required":false}' "$out"

tl_results
