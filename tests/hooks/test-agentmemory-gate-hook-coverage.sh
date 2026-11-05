#!/usr/bin/env bash
# Behavior tests for hooks/agentmemory-gate.sh (PreToolUse). CLI/server are stubs.
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
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
# The server-health result is cached for a few seconds; scenarios change the probe, so drop it.
curl_ok() { tl_stub curl 'exit "${CURL_RC:-0}"'; hash -r; rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"; }
no_curl() { rm -f "$TL_BIN/curl"; hash -r; rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"; }

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
gh_run "$HOOK" "$(gh_bash_input "agentmemory search foo")"
assert_gate_allows "retrieval command is exempt"
gh_run "$HOOK" "$(gh_bash_input "agentmemory search foo > out.txt")"
assert_gate_denies "a retrieval that writes a file is not a bare retrieval" "AGENTMEMORY"

# retrieval is a single simple agentmemory command: a word in a pipeline does not exempt it
gh_run "$HOOK" "$(gh_bash_input "echo agentmemory search foo > out.txt")"
assert_gate_denies "echo of a retrieval command is not retrieval" "AGENTMEMORY"

# server down: the usage requirement stays and the message says how to start the server
am_cli; no_curl
rm -rf "$GH_PROJ/.agentmemory"; mkdir -p "$GH_PROJ/.agentmemory/memory"
gh_run "$HOOK" "$EDIT"
assert_gate_denies "cli present but server unreachable still requires usage" "AGENTMEMORY SERVER DOWN"
curl_ok
rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"
gh_run "$HOOK" "$EDIT" CURL_RC=22
assert_gate_denies "curl failing and status not connected reports the server down" "AGENTMEMORY SERVER DOWN"

# server healthy, MCP not wired: usage still required, wiring explained
rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"
gh_run "$HOOK" "$EDIT" CURL_RC=0
assert_gate_denies "healthy server but MCP artifact missing reports the wiring" "AGENTMEMORY MCP NOT WIRED"

# wired, export missing and scaffold succeeds: first edit proceeds without restart
printf '{"mcpServers":{"agentmemory":{}}}' >"$ART"
rm -rf "$GH_PROJ/.agentmemory"
rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"
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

# an export root that escapes the project is repository data: the default root is used instead
rm -rf "$GH_PROJ/.agentmemory"
base_cfg '.recommended_tools.agentmemory.export_root = "../escape"'
gh_run "$HOOK" "$EDIT"
assert_gate_allows "unsafe export root falls back to the default and scaffolds there"
if [[ -e "$GH_PROJ/../escape" ]]; then tl_fail "nothing created outside the project"; else tl_pass "nothing created outside the project"; fi
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
