#!/usr/bin/env bash
# Behavior tests for hooks/graphify-gate.sh (PreToolUse). The graphify CLI is a stub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/graphify-gate.sh
QSTATE="$SB_RUNTIME_STATE_DIR/gfy-query"

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{graphify:{enabled_by_user:true, query_state_file:\"$QSTATE\"}}} | ${1:-.}" >"$GH_CFG"; }
gfy_cli() { tl_stub graphify 'exit 0'; hash -r; }
gfy_none() { rm -f "$TL_BIN/graphify"; hash -r; }

gh_scenario_block() { base_cfg; gfy_none; rm -rf "$GH_PROJ/graphify-out"; rm -f "$QSTATE"; }

gh_prelude_suite "$HOOK" graphify-gate graphify "$GH_PROJ/graphify-out/graph.json" "graphify query foo" "$GH_PROJ/src/app.js" "GRAPHIFY REQUIRED"

EDIT="$(gh_edit_input)"
gh_scenario_block
assert_contains "no-cli message lists install" "$( gh_run "$HOOK" "$EDIT"; gh_reason)" "uv tool install"

# retrieval/index commands are exempt even when they write
gh_run "$HOOK" "$(gh_bash_input "graphify update . --no-cluster > build.log")"
assert_gate_allows "index build command is exempt"
gh_run "$HOOK" "$(gh_bash_input "git status > s.txt")"
assert_gate_allows "read-only git command is exempt"

# CLI present, index missing
gfy_cli
gh_run "$HOOK" "$EDIT"
assert_gate_denies "missing index is denied" "GRAPHIFY INDEX MISSING"
assert_contains "message names expected graph path" "$(gh_reason)" "graphify-out/graph.json"
base_cfg '.recommended_tools.graphify.graph_path = "idx/graph.json"'
gh_run "$HOOK" "$EDIT"
assert_contains "custom graph path surfaces in message" "$(gh_reason)" "idx/graph.json"
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/idx/note.md")"
assert_gate_allows "edits under the graph directory are exempt"
base_cfg

# index present, no recent query
mkdir -p "$GH_PROJ/graphify-out"; : >"$GH_PROJ/graphify-out/graph.json"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "stale query is denied" "GRAPHIFY QUERY REQUIRED"
assert_contains "default ttl in message" "$(gh_reason)" "every 1800s"
base_cfg '.recommended_tools.graphify.query_ttl_seconds = 120'
gh_run "$HOOK" "$EDIT"
assert_contains "configured ttl in message" "$(gh_reason)" "every 120s"
printf '%s\n' "$(( $(date +%s) - 500 ))" >"$QSTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "query older than ttl is denied" "GRAPHIFY QUERY REQUIRED"
date +%s >"$QSTATE"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "fresh query allows edits"
gh_run "$HOOK" "$(gh_bash_input "git commit -m x")"
assert_gate_allows "fresh query allows commits"
base_cfg
rm -f "$QSTATE"

# legacy graphify.required migration
jq -n '{config_version:"1", sb_initiated:true, graphify:{required:true}}' >"$GH_CFG"
gfy_none
gh_run "$HOOK" "$EDIT"
assert_gate_denies "legacy graphify.required=true gates" "GRAPHIFY REQUIRED"
jq -n '{config_version:"1", sb_initiated:true, graphify:{required:false}}' >"$GH_CFG"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "legacy graphify.required=false allows"

tl_results
