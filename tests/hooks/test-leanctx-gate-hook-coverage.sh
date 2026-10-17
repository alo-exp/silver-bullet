#!/usr/bin/env bash
# Behavior tests for hooks/leanctx-gate.sh (PreToolUse). The lean-ctx CLI is a stub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset SB_LEANCTX_MCP_ARTIFACT SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/leanctx-gate.sh
ART="$TL_TMP/lc-art.json"; export SB_LEANCTX_MCP_ARTIFACT="$ART"
USTATE="$SB_RUNTIME_STATE_DIR/lc-usage"

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{leanctx:{enabled_by_user:true, usage_state_file:\"$USTATE\"}}} | ${1:-.}" >"$GH_CFG"; }
lc_cli() { tl_stub lean-ctx 'exit 0'; hash -r; }
lc_none() { rm -f "$TL_BIN/lean-ctx" "$TL_BIN/myctx"; hash -r; }

gh_scenario_block() { base_cfg; lc_none; rm -f "$ART" "$USTATE"; }

gh_prelude_suite "$HOOK" leanctx-gate leanctx "$GH_PROJ/docs/LEANCTX.md" "lean-ctx status" "$GH_PROJ/src/app.js" "LEANCTX REQUIRED"

EDIT="$(gh_edit_input)"
gh_scenario_block
gh_run "$HOOK" "$EDIT"
assert_contains "no-cli message names verify command" "$(gh_reason)" "lean-ctx --version"
gh_run "$HOOK" "$(gh_bash_input "bash scripts/install-leanctx-sb.sh --host claude > install.log")"
assert_gate_allows "installer command is exempt"

# CLI present, MCP not wired
lc_cli
gh_run "$HOOK" "$EDIT"
assert_gate_denies "mcp artifact missing is denied" "LEANCTX NOT WIRED"
assert_contains "no_mcp message names artifact" "$(gh_reason)" "$ART"
# wired, no usage
printf '{"mcpServers":{"lean-ctx":{}}}' >"$ART"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "no usage stamp is denied" "LEANCTX USAGE REQUIRED"
assert_contains "stale message ttl" "$(gh_reason)" "every 1800s"
base_cfg '.recommended_tools.leanctx.usage_ttl_seconds = 200 | .recommended_tools.leanctx.cli_command = "myctx"'
tl_stub myctx 'exit 0'; hash -r
gh_run "$HOOK" "$EDIT"
assert_contains "configured ttl in message" "$(gh_reason)" "every 200s"
assert_contains "configured cli in message" "$(gh_reason)" "myctx status"
printf '%s\n' "$(( $(date +%s) - 900 ))" >"$USTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "usage older than ttl is denied" "LEANCTX USAGE REQUIRED"
date +%s >"$USTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "fresh usage allows edits"
gh_run "$HOOK" "$(gh_bash_input "git commit -m x")"
assert_gate_allows "fresh usage allows commits"
# custom CLI command must exist
base_cfg '.recommended_tools.leanctx.cli_command = "myctx"'
rm -f "$TL_BIN/myctx"; hash -r
gh_run "$HOOK" "$EDIT"
assert_gate_denies "configured cli missing is denied" "LEANCTX REQUIRED"
tl_stub myctx 'exit 0'; hash -r
gh_run "$HOOK" "$EDIT"
assert_gate_allows "configured cli present allows"

tl_results
