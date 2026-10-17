#!/usr/bin/env bash
# Behavior tests for hooks/agentmemory-gate.sh (PreToolUse). CLI/server are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_AGENTMEMORY_MCP_ARTIFACT SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/agentmemory-gate.sh
ART="$TL_TMP/am-art.json"; export SB_AGENTMEMORY_MCP_ARTIFACT="$ART"

base_cfg() { # extra jq filter applied to the base config
  jq -n "{config_version:\"1\", sb_initiated:true,
    recommended_tools:{agentmemory:{enabled_by_user:true, usage_state_file:\"$SB_RUNTIME_STATE_DIR/am-usage\", export_root:\".agentmemory\"}}} | ${1:-.}" >"$GH_CFG"
}
am_cli() { tl_stub agentmemory 'if [[ "${1:-}" == status ]]; then echo "${AM_STATUS:-}"; fi; exit 0'; hash -r; }
am_no_cli() { rm -f "$TL_BIN/agentmemory"; hash -r; }
curl_ok() { tl_stub curl 'exit "${CURL_RC:-0}"'; hash -r; }
no_curl() { rm -f "$TL_BIN/curl"; hash -r; }

# blocking baseline: opted in, CLI missing
gh_scenario_block() { base_cfg; am_no_cli; no_curl; rm -f "$ART" "$SB_RUNTIME_STATE_DIR/am-usage"; rm -rf "$GH_PROJ/.agentmemory"; }

gh_prelude_suite "$HOOK" agentmemory-gate agentmemory "$GH_PROJ/.agentmemory/memory/a.md" "agentmemory status" "$GH_PROJ/src/app.js" "AGENTMEMORY REQUIRED"

EDIT="$(gh_edit_input)"
gh_scenario_block
gh_run "$HOOK" "$EDIT"
assert_contains "no-cli message lists install" "$(gh_reason)" "npm install -g @agentmemory/agentmemory"

# exempt edit paths: the export root and runtime state dir
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/.agentmemory/memory/x.md")"
assert_gate_allows "export root edit is exempt"
gh_run "$HOOK" "$(gh_edit_input "$GH_PROJ/.silver-bullet/state")"
assert_gate_allows "state dir edit is exempt"

# retrieval commands (even write-looking ones) are exempt
gh_run "$HOOK" "$(gh_bash_input "agentmemory search foo > out.txt")"
assert_gate_allows "retrieval command is exempt"

# server down: soft-allow
am_cli; no_curl
gh_run "$HOOK" "$EDIT"
assert_gate_allows "cli present but server unreachable soft-allows"
curl_ok
gh_run "$HOOK" "$EDIT" CURL_RC=22
assert_gate_allows "curl failing and status not connected soft-allows"

# server healthy, MCP not wired: soft-allow
gh_run "$HOOK" "$EDIT" CURL_RC=0
assert_gate_allows "healthy server but MCP artifact missing soft-allows"

# wired, export missing and scaffold succeeds: first edit proceeds without restart
printf '{"mcpServers":{"agentmemory":{}}}' >"$ART"
rm -rf "$GH_PROJ/.agentmemory"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "first edit after auto-scaffold is allowed"
assert_file_exists "export memory dir scaffolded" "$GH_PROJ/.agentmemory/memory/."
assert_file_exists "export snapshots dir scaffolded" "$GH_PROJ/.agentmemory/snapshots/."

# export exists but no fresh usage: blocked with TTL in message
gh_run "$HOOK" "$EDIT"
assert_gate_denies "stale usage is denied" "AGENTMEMORY USAGE REQUIRED"
assert_contains "stale usage message carries ttl" "$(gh_reason)" "every 1800s"
base_cfg '.recommended_tools.agentmemory.usage_ttl_seconds = 300'
gh_run "$HOOK" "$EDIT"
assert_contains "configured ttl surfaces" "$(gh_reason)" "every 300s"

# fresh usage allows; just-expired usage denies
date +%s >"$SB_RUNTIME_STATE_DIR/am-usage"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "fresh usage allows"
printf '%s\n' "$(( $(date +%s) - 400 ))" >"$SB_RUNTIME_STATE_DIR/am-usage"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "usage older than ttl is denied" "AGENTMEMORY USAGE REQUIRED"
rm -f "$SB_RUNTIME_STATE_DIR/am-usage"

# graphify synergy: a fresh graphify query satisfies the retrieval requirement
base_cfg '.recommended_tools.graphify = {enabled_by_user:true, query_state_file:"'"$SB_RUNTIME_STATE_DIR"'/gfy-query"}'
gh_run "$HOOK" "$EDIT"
assert_gate_denies "graphify enabled without a fresh query does not satisfy synergy" "AGENTMEMORY USAGE REQUIRED"
date +%s >"$SB_RUNTIME_STATE_DIR/gfy-query"
gh_run "$HOOK" "$EDIT"
assert_gate_allows "graphify synergy (fresh query) allows"
rm -f "$SB_RUNTIME_STATE_DIR/gfy-query"

# export root that cannot be scaffolded
base_cfg '.recommended_tools.agentmemory.export_root = "../escape"'
gh_run "$HOOK" "$EDIT"
assert_gate_denies "unsafe export root cannot be scaffolded" "AGENTMEMORY EXPORT ROOT MISSING"
base_cfg
# export_root is a file: scaffold fails, existence check fails
rm -rf "$GH_PROJ/.agentmemory"; printf 'x' >"$GH_PROJ/.agentmemory"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "export root blocked by a file is denied" "AGENTMEMORY EXPORT ROOT MISSING"
assert_contains "no_export message names the root" "$(gh_reason)" ".agentmemory/memory"
rm -f "$GH_PROJ/.agentmemory"

# status-based health (curl absent) with a connected CLI
mkdir -p "$GH_PROJ/.agentmemory/memory"; no_curl
am_cli
gh_run "$HOOK" "$EDIT" AM_STATUS=Connected
assert_gate_denies "healthy via CLI status reaches the usage check" "AGENTMEMORY USAGE REQUIRED"

# hook runs from a subdirectory of the project
GH_CWD="$GH_PROJ/src" gh_run "$HOOK" "$EDIT" AM_STATUS=Connected
assert_gate_denies "project is discovered from a subdirectory" "AGENTMEMORY USAGE REQUIRED"

tl_results
