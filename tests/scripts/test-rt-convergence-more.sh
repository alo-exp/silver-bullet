#!/usr/bin/env bash
# receipts.sh host convergence batches, part 2 (receipt options, partial changes, failures). Patchers are logging stubs in a
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
echo '{}' >"$HOME/.claude.json"

# ============================================================ convergence batch

hr_consent "${ALL_ENABLED[@]}"
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP" RT_SUPPRESS_RELOAD_RECEIPT_CREATE=1; rt_apply_host_convergence_batches true) | jq -c .)"
assert_contains "convergence: receipt creation suppressed by consume" "$out" '"actions":["patch_mcp"]'
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches false) | jq -c .)"
assert_eq "convergence: mcp only" '{"actions":["patch_mcp"],"failures":[],"restart_required":true,"changed":true,"affected_servers":["graphify","leanctx","agentmemory"]}' "$out"
hr_consent rtk=enabled
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: rtk alone on Claude runs no batch" '{"actions":[],"failures":[],"restart_required":false,"changed":false,"affected_servers":[]}' "$out"
hr_consent "${ALL_ENABLED[@]}"
out="$( (export HR_PY_RC_patch_mcp=1; rt_apply_host_convergence_batches true) | jq -c .)"
assert_eq "convergence: batch failures carried through" '{"actions":[],"failures":["patch_mcp_failed"],"restart_required":false,"changed":false,"affected_servers":[]}' "$out"
# receipt creation failure is reported
rm -rf "$SB_RUNTIME_STATE_DIR/recommended-tools"; printf 'file\n' >"$SB_RUNTIME_STATE_DIR/recommended-tools"
out="$( (export HR_PY_OUT_patch_mcp=patched HR_PY_HOOK_patch_mcp="$CHANGE_MCP"; rt_apply_host_convergence_batches true) | jq -c .)"
assert_contains "convergence: receipt failure reported" "$out" '"reload_receipt_failed"'
rm -f "$SB_RUNTIME_STATE_DIR/recommended-tools"

tl_results
