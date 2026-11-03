#!/usr/bin/env bash
# Behavior tests for hooks/leanctx-gate.sh (PreToolUse). The lean-ctx CLI is a stub.
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
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
gh_run "$HOOK" "$(gh_bash_input "bash $TL_REPO_ROOT/scripts/install-leanctx-sb.sh --host claude")"
assert_gate_allows "the plugin's own installer command is exempt"
gh_run "$HOOK" "$(gh_bash_input "bash scripts/install-leanctx-sb.sh --host claude")"
assert_gate_denies "a project-relative installer script is not Silver Bullet's and is gated" "LEANCTX REQUIRED"
gh_run "$HOOK" "$(gh_bash_input "lean-ctx --version")"
assert_gate_allows "LeanCTX's own CLI is exempt"

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
gh_run "$HOOK" "$EDIT"
assert_contains "configured ttl in message" "$(gh_reason)" "every 200s"
assert_contains "the CLI in the message is always lean-ctx, never a config string" "$(gh_reason)" "lean-ctx status"
printf '%s\n' "$(( $(date +%s) - 900 ))" >"$USTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "usage older than ttl is denied" "LEANCTX USAGE REQUIRED"
date +%s >"$USTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "fresh usage allows edits"
gh_run "$HOOK" "$(gh_bash_input "git commit -m x")"
assert_gate_allows "fresh usage allows commits"
# R5-10: cli_command in the project file is not honoured, so it cannot make a command count as usage
base_cfg '.recommended_tools.leanctx.cli_command = "myctx"'
tl_stub myctx 'exit 0'; hash -r
rm -f "$USTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "a configured cli_command does not satisfy the gate" "LEANCTX USAGE REQUIRED"

tl_results
