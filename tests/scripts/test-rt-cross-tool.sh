#!/usr/bin/env bash
# probe-cross-tool.sh (route ownership, hook order, heartbeat, repair); the convergence
# batches it drives live in test-rt-convergence-cross-tool.sh. Patchers are logging stubs in a
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
# outside git there is no project id, hence no heartbeat location
NOGITP="$TL_TMP/nogit-cross"; mkdir -p "$NOGITP"; cp "$HR_PROJ/.silver-bullet.json" "$NOGITP/.silver-bullet.json"
assert_eq "cross: no project id -> heartbeat absent" "repairable|none|heartbeat_absent_or_invalid|true" "$(RT_PROJECT_ROOT="$NOGITP" pct)"

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
