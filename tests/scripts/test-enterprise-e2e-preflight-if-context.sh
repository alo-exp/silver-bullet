#!/usr/bin/env bash
# Pins every failure return in the core.sh preflights for the way production calls them:
# scripts/lib/agent-delegate-common.sh runs `if ! enterprise_e2e_code_intel_preflight ...`,
# where bash ignores errexit, so each failing check must `return 1` itself. Every case calls the
# function in an if-condition and expects FAILED plus the error text, never SWALLOWED.
# E2E_CORE_UNDER_TEST points the suite at a mutated copy of core.sh (mutation check).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="${E2E_CORE_UNDER_TEST:-$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh}"
CFG="$TL_TMP/hosts.json"
echo '{"default_host": "claude", "hosts": {}}' >"$CFG"
STUBS="$TL_TMP/stubs.sh"
cat >"$STUBS" <<'S'
sb_recommended_tool_enforced() { grep -qF "\"$2\"" "$1"; }
sb_runtime_host() { echo stubhost; }
sb_graphify_cli_available() { [[ "${G_CLI:-1}" == 1 ]]; }
sb_graphify_index_exists() { [[ "${G_INDEX:-1}" == 1 ]]; }
sb_graphify_graph_rel_path() { echo "rel/graph.json"; }
sb_graphify_abs_graph_path() { echo "${G_GRAPH:-}"; }
sb_graphify_query_is_fresh() { [[ "${G_FRESH:-1}" == 1 ]]; }
sb_graphify_record_query() { echo "recorded:$1"; [[ "${G_REC:-1}" == 1 ]]; }
sb_agentmemory_cli_available() { [[ "${A_CLI:-1}" == 1 ]]; }
sb_agentmemory_server_healthy() {
  local n=0
  [[ -f "$A_COUNT" ]] && n="$(cat "$A_COUNT")"
  n=$((n + 1))
  echo "$n" >"$A_COUNT"
  [[ "$n" -gt "${A_HEALTHY_AFTER:-0}" ]]
}
sb_agentmemory_platform_artifact_present() { echo "am-artifact-host:$2"; [[ "${A_ART:-1}" == 1 ]]; }
sb_agentmemory_export_exists() { [[ "${A_EXP:-1}" == 1 ]]; }
sb_rtk_cli_path() { echo "${R_BIN:-}"; }
sb_rtk_cli_available() { [[ "${R_CLI:-1}" == 1 ]]; }
sb_rtk_version_ok() { [[ "${R_VER:-1}" == 1 ]]; }
sb_rtk_platform_hook_present() { echo "rtk-hook-host:$2" >&2; [[ "${R_HOOK:-1}" == 1 ]]; }
sb_context_mode_node_ok() { [[ "${C_NODE:-1}" == 1 ]]; }
sb_context_mode_cli_available() { [[ "${C_CLI:-1}" == 1 ]]; }
sb_context_mode_platform_artifact_present() { echo "cm-artifact-host:$2" >&2; [[ "${C_ART:-1}" == 1 ]]; }
rtcm_doctor_platform() { echo "${C_PLATFORM-claude-code}"; }
S

echo '{"enforced": ["graphify"]}' >"$TL_TMP/g.json"
echo '{"enforced": ["agentmemory"]}' >"$TL_TMP/a.json"
echo '{"enforced": ["rtk"]}' >"$TL_TMP/r.json"
echo '{"enforced": ["context_mode"]}' >"$TL_TMP/c.json"
echo '{}' >"$TL_TMP/graph.json"
PROJ="$TL_TMP/proj"
mkdir -p "$PROJ"

# ifc CALL ENV... : run CALL as an if-condition (errexit ignored inside).
ifc() {
  local call="$1"
  shift
  e2e_script "source '$CORE'; source '$STUBS'; sleep() { :; }; if $call; then echo SWALLOWED; else echo FAILED; fi" \
    "SILVER_BULLET_RUNTIME=claude" "SB_E2E_HOSTS_CONFIG=$CFG" "A_COUNT=$TL_TMP/am.count" "G_GRAPH=$TL_TMP/graph.json" "AM_STARTED=$TL_TMP/am.started" "$@"
}
expect_failed() {  # expect_failed NAME TEXT
  assert_contains "$1: reported as failed" "$TL_OUT" "FAILED"
  assert_not_contains "$1: not swallowed" "$TL_OUT" "SWALLOWED"
  assert_contains "$1: error text" "$TL_ERR" "$2"
}
tl_stub graphify 'case "$1" in update) exit "${GU_RC:-0}";; query) exit "${GQ_RC:-0}";; esac'
tl_stub agentmemory 'exit 0'
tl_stub lsof 'exit 1'
tl_stub fake-rtk 'if [[ "$1" == gain ]]; then exit "${RTK_GAIN_RC:-0}"; fi; exit 1'
tl_stub context-mode 'echo "${CM_OUT:-ok}"; exit "${CM_RC:-0}"'

# --- Graphify -----------------------------------------------------------------
G="enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0"
ifc "$G" "G_CLI=0";                        expect_failed "graphify CLI missing" "graphify CLI missing"
ifc "$G" "G_INDEX=0" "GU_RC=1";            expect_failed "graphify update failed" "graphify update failed"
ifc "$G" "G_GRAPH=$TL_TMP/absent.json";    expect_failed "graphify index still missing" "graphify index still missing"
ifc "$G" "G_FRESH=0" "GQ_RC=1";            expect_failed "graphify query failed" "graphify query failed"
ifc "$G" "G_FRESH=0" "G_REC=0";            expect_failed "graphify state not recorded" "could not record graphify query state"
ifc "$G"
assert_contains "graphify healthy path still succeeds" "$TL_OUT" "SWALLOWED"

# --- agentmemory ----------------------------------------------------------------
A="enterprise_e2e_preflight_agentmemory '$PROJ' '$TL_TMP/a.json' h 0"
rm -f "$TL_TMP/am.count"; ifc "$A" "A_CLI=0";              expect_failed "agentmemory CLI missing" "agentmemory CLI missing"
rm -f "$TL_TMP/am.count"; ifc "$A" "A_HEALTHY_AFTER=1000"; expect_failed "agentmemory server unhealthy" "agentmemory server not healthy"
rm -f "$TL_TMP/am.count"; ifc "$A" "A_ART=0";              expect_failed "agentmemory MCP not wired" "agentmemory MCP not wired"
rm -f "$TL_TMP/am.count"; ifc "$A" "A_EXP=0";              expect_failed "agentmemory export missing" ".agentmemory/ export root missing"
rm -f "$TL_TMP/am.count"; ifc "$A"
assert_contains "agentmemory healthy path still succeeds" "$TL_OUT" "SWALLOWED"

# --- RTK --------------------------------------------------------------------------
R="enterprise_e2e_preflight_rtk '$TL_TMP/r.json' h 0"
ifc "$R" "R_BIN=";                                  expect_failed "rtk binary missing" "rtk CLI missing or wrong binary"
ifc "$R" "R_BIN=$TL_BIN/fake-rtk" "R_CLI=0" "SB_ROOT=$TL_TMP"; expect_failed "rtk wrong binary" "rtk CLI missing or wrong binary"
ifc "$R" "R_BIN=$TL_BIN/fake-rtk" "RTK_GAIN_RC=1";  expect_failed "rtk gain failing" "rtk gain --help failed"
ifc "$R" "R_BIN=$TL_BIN/fake-rtk" "R_VER=0";        expect_failed "rtk version old" "rtk version too old"
ifc "$R" "R_BIN=$TL_BIN/fake-rtk" "R_HOOK=0" "SB_ROOT=$TL_TMP"; expect_failed "rtk hook missing" "RTK host hook missing"
ifc "$R" "R_BIN=$TL_BIN/fake-rtk" "SB_ROOT=$TL_TMP"
assert_contains "rtk healthy path still succeeds" "$TL_OUT" "SWALLOWED"

# --- Context Mode ---------------------------------------------------------------------
C="enterprise_e2e_preflight_context_mode '$PROJ' '$TL_TMP/c.json' h 0"
ifc "$C" "C_NODE=0";                                expect_failed "context-mode node old" "Node < 22.5"
ifc "$C" "C_CLI=0";                                 expect_failed "context-mode CLI missing" "context-mode CLI/plugin missing"
ifc "$C" "C_ART=0";                                 expect_failed "context-mode MCP not wired" "Context Mode MCP not wired"
ifc "$C" "CM_RC=1";                                 expect_failed "context-mode doctor failing" "context-mode doctor failed"
ifc "$C" "CM_OUT=FAIL: broken";                     expect_failed "context-mode doctor FAIL line" "context-mode doctor reported FAIL"
ifc "$C"
assert_contains "context-mode healthy path still succeeds" "$TL_OUT" "SWALLOWED"

# --- Claude token gateway: missing root must not fall through to an env-var pass ----------
ifc "enterprise_e2e_preflight_claude_token_gateway ''" "ANTHROPIC_API_KEY=k" -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT "SB_ROOT="
expect_failed "gateway without SB_ROOT" "SB_ROOT missing for token gateway preflight"

# --- orchestration, exactly as agent-delegate-common.sh calls it ----------------------------
SBR="$TL_TMP/orch-sb"
FXT="$TL_TMP/orch-fx"
mkdir -p "$SBR" "$FXT"
orch() {  # orch SB-CONFIG FIXTURE-CONFIG ENV...  (plain call inside the if-condition)
  rm -f "$SBR/.silver-bullet.json" "$FXT/.silver-bullet.json" "$TL_TMP/am.count"
  [[ -n "$1" ]] && cp "$TL_TMP/$1" "$SBR/.silver-bullet.json"
  [[ -n "$2" ]] && cp "$TL_TMP/$2" "$FXT/.silver-bullet.json"
  shift 2
  ifc "enterprise_e2e_code_intel_preflight '$SBR' '$FXT' 0" "$@"
}
orch "" ""
assert_contains "nothing enforced: accepted" "$TL_OUT" "SWALLOWED"
ifc "enterprise_e2e_code_intel_preflight '$TL_TMP/no-such-sb' '$FXT' 0"
expect_failed "missing SB root" "code-intel preflight: SB_ROOT missing"
ifc "enterprise_e2e_code_intel_preflight '$SBR' '$TL_TMP/no-such-fx' 0"
expect_failed "missing fixture dir" "fixture dir missing: $TL_TMP/no-such-fx"
ifc "enterprise_e2e_code_intel_preflight '$SBR' '' 0"
expect_failed "empty fixture dir" "fixture dir missing:"
orch g.json "" "G_CLI=0";  expect_failed "orchestrator: graphify (SB config)" "graphify CLI missing"
orch "" g.json "G_CLI=0";  expect_failed "orchestrator: graphify (fixture config)" "graphify CLI missing"
orch a.json "" "A_CLI=0";  expect_failed "orchestrator: agentmemory" "agentmemory CLI missing"
orch r.json "" "R_BIN=";   expect_failed "orchestrator: rtk" "rtk CLI missing or wrong binary"
orch c.json "" "C_CLI=0";  expect_failed "orchestrator: context-mode" "context-mode CLI/plugin missing"
orch g.json "" "R_BIN=";   assert_contains "orchestrator: tools that are not enforced are not checked" "$TL_OUT" "SWALLOWED"
orch g.json ""
assert_contains "orchestrator: healthy graphify accepted" "$TL_OUT" "SWALLOWED"

tl_results
