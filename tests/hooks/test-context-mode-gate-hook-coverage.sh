#!/usr/bin/env bash
# Behavior tests for hooks/context-mode-gate.sh (PreToolUse). node/context-mode are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_CONTEXT_MODE_MCP_ARTIFACT SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/context-mode-gate.sh
PLUGIN="$HOME/.claude/plugins/context-mode"

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{context_mode:{enabled_by_user:true}}} | ${1:-.}" >"$GH_CFG"; }
node_ver() { tl_stub node "echo $1"; hash -r; }
node_none() { rm -f "$TL_BIN/node"; hash -r; }
fragment() { printf '<!-- BEGIN context-mode hint (do not edit) -->\nuse ctx_search\n' >"$GH_PROJ/silver-bullet.md"; }
no_fragment() { printf '# Silver Bullet\n' >"$GH_PROJ/silver-bullet.md"; }

gh_scenario_block() { base_cfg; node_none; rm -rf "$HOME/.claude"; no_fragment; }

gh_prelude_suite "$HOOK" context-mode-gate context_mode "$GH_PROJ/.cursor/mcp.json" "context-mode doctor" "$GH_PROJ/src/app.js" "CONTEXT MODE"

EDIT="$(gh_edit_input)"
gh_scenario_block
gh_run "$HOOK" "$EDIT"
assert_gate_denies "node missing is denied" "Node too old"
assert_contains "node message shows default minimum" "$(gh_reason)" "need >= 22.5"
node_ver v20.1.0
gh_run "$HOOK" "$EDIT"
assert_gate_denies "old node is denied" "Node too old"
base_cfg '.recommended_tools.context_mode.min_node_version = "20.0"'
gh_run "$HOOK" "$EDIT"
assert_gate_denies "node ok but package missing" "package not installed"
base_cfg
assert_contains "no_cli message gives install command" "$(gh_reason)" "npm install -g context-mode"
node_ver v24.0.0
gh_run "$HOOK" "$EDIT"
assert_gate_denies "node ok but cli/plugin missing is denied" "package not installed"

# CLI on PATH but MCP/plugin not wired for claude (plugin dir absent)
tl_stub context-mode 'exit 0'; hash -r
gh_run "$HOOK" "$EDIT"
assert_gate_denies "cli present but not wired" "CONTEXT MODE NOT WIRED"
assert_contains "no_platform names artifact" "$(gh_reason)" "$PLUGIN"
rm -f "$TL_BIN/context-mode"; hash -r
# plugin dir wired, instruction fragment missing
mkdir -p "$PLUGIN"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "fragment missing is denied" "INSTRUCTION FRAGMENT MISSING"
# fragment present: everything satisfied
fragment
gh_run "$HOOK" "$EDIT"
assert_gate_allows "fully wired allows"
gh_run "$HOOK" "$(gh_bash_input "git commit -m x")"
assert_gate_allows "fully wired allows commits"
# exempt: hint template + MCP configs
no_fragment
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/templates/context-mode-hint.md.base")"
assert_gate_allows "hint template edit is exempt"
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/.cursor/hooks.json")"
assert_gate_allows "cursor hooks.json edit is exempt"
gh_run "$HOOK" "$(gh_bash_input "npm install -g context-mode")"
assert_gate_allows "installing context-mode is exempt"
gh_run "$HOOK" "$(gh_bash_input "mkdir -p x && cp a b")"
assert_gate_allows "mkdir/cp helper commands are exempt"

tl_results
