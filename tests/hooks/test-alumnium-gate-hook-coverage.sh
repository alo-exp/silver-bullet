#!/usr/bin/env bash
# Behavior tests for hooks/alumnium-gate.sh (PreToolUse). npx/npm are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_ALUMNIUM_MCP_ARTIFACT SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/alumnium-gate.sh
ART="$TL_TMP/alum-art.json"; export SB_ALUMNIUM_MCP_ARTIFACT="$ART"
BROWSER_EDIT="$GH_PROJ/e2e/login.spec.ts"

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{alumnium:{enabled_by_user:true}}} | ${1:-.}" >"$GH_CFG"; }
npx_ok() { tl_stub npx 'exit 0'; tl_stub npm 'exit "${NPM_RC:-0}"'; hash -r; }
npx_none() { rm -f "$TL_BIN/npx" "$TL_BIN/npm"; hash -r; }

gh_scenario_block() { base_cfg; npx_none; rm -f "$ART"; }

gh_prelude_suite "$HOOK" alumnium-gate alumnium "$GH_PROJ/.silver-bullet/state" "npm test" "$BROWSER_EDIT" "ALUMNIUM REQUIRED"

gh_scenario_block
# edits that are not browser/visual-testing artifacts are never gated
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/src/app.js")"
assert_gate_allows "non-browser edit allows"
# browser/visual artifacts are gated
for p in "$GH_PROJ/e2e/a.ts" "$GH_PROJ/playwright/a.js" "$GH_PROJ/src/Panel.canvas.tsx" "$GH_PROJ/tests/login.spec.js" "$GH_PROJ/docs/screenshots/a.png"; do
  gh_run "$HOOK" "$(gh_edit_input "$p")"
  assert_gate_denies "browser artifact is gated: ${p#"$GH_PROJ"/}" "ALUMNIUM REQUIRED"
done
# exempt paths are allowed even when they look like browser artifacts
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/e2e/silver-bullet.md")"
assert_gate_allows "silver-bullet.md under e2e is exempt"
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/e2e/.silver-bullet/x.spec.ts")"
assert_gate_allows "state dir under e2e is exempt"

# npx reachable but the npm registry lookup fails -> still not wired
npx_ok
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")" NPM_RC=1
assert_gate_denies "npm view failure counts as unavailable" "ALUMNIUM REQUIRED"
# npx available, MCP artifact missing
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")"
assert_gate_denies "mcp artifact missing is denied" "ALUMNIUM REQUIRED"
assert_contains "message names provider key" "$(gh_reason)" "OPENAI_API_KEY"
# wired
printf '{"mcpServers":{"alumnium":{}}}' >"$ART"
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")"
assert_gate_allows "wired alumnium allows browser edits"
gh_run "$HOOK" "$(gh_bash_input "git commit -m x")"
assert_gate_allows "wired alumnium allows commits"
# artifact referencing a custom mcp server name
printf '{"mcpServers":{"my-browser":{}}}' >"$ART"
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")"
assert_gate_denies "custom server name not in artifact is denied" "ALUMNIUM REQUIRED"
base_cfg '.recommended_tools.alumnium.mcp_server_name = "my-browser"'
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")"
assert_gate_allows "custom mcp_server_name found in artifact allows"
# cursor host reads the cursor MCP config
rm -f "$ART"
mkdir -p "$HOME/.cursor"; printf '{"mcpServers":{"alumnium":{}}}' >"$HOME/.cursor/mcp.json"
unset SB_ALUMNIUM_MCP_ARTIFACT
base_cfg
gh_run "$HOOK" "$(gh_edit_input "$BROWSER_EDIT")" SILVER_BULLET_RUNTIME=cursor
assert_gate_allows "cursor host artifact path is honored"
rm -rf "$HOME/.cursor"

tl_results
