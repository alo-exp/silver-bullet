#!/usr/bin/env bash
# Behaviour tests for the code-intel preflight (Graphify, agentmemory, RTK, Context Mode) in
# scripts/enterprise-e2e/lib/core.sh. The tool libraries and CLIs are replaced by stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
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
ALL_TOOLS='{"enforced": ["graphify", "agentmemory", "rtk", "context_mode"]}'
NO_TOOLS='{"enforced": []}'
echo "$ALL_TOOLS" >"$TL_TMP/all.json"
echo "$NO_TOOLS" >"$TL_TMP/none.json"
echo '{"enforced": ["graphify"]}' >"$TL_TMP/g.json"
echo '{"enforced": ["agentmemory"]}' >"$TL_TMP/a.json"
echo '{"enforced": ["rtk"]}' >"$TL_TMP/r.json"
echo '{"enforced": ["context_mode"]}' >"$TL_TMP/c.json"

# ci BODY ENV... : source core + stubs, then run BODY (errexit on).
ci() {
  local body="$1"
  shift
  e2e_script "source '$CORE'; source '$STUBS'; $body" "SILVER_BULLET_RUNTIME=claude" "SB_E2E_HOSTS_CONFIG=$CFG" "A_COUNT=$TL_TMP/am.count" "$@"
}
reset_counts() { rm -f "$TL_TMP/am.count"; }
PROJ="$TL_TMP/proj"
mkdir -p "$PROJ"

# --- enforcement lookup ------------------------------------------------------
ci "enterprise_e2e_tool_enforced_in_config '' graphify"; assert_eq "enforced: empty config path" 1 "$TL_STATUS"
ci "enterprise_e2e_tool_enforced_in_config '$TL_TMP/absent.json' graphify"; assert_eq "enforced: missing config" 1 "$TL_STATUS"
ci "enterprise_e2e_tool_enforced_in_config '$TL_TMP/g.json' graphify"; assert_eq "enforced: tool listed" 0 "$TL_STATUS"
ci "enterprise_e2e_tool_enforced_in_config '$TL_TMP/g.json' rtk"; assert_eq "enforced: tool not listed" 1 "$TL_STATUS"
e2e_script "source '$CORE'; enterprise_e2e_tool_enforced_in_config '$TL_TMP/g.json' graphify" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "enforced: helper library not loaded" 1 "$TL_STATUS"
mkdir -p "$TL_TMP/anysb" "$TL_TMP/anyfx"
cp "$TL_TMP/g.json" "$TL_TMP/anysb/.silver-bullet.json"
cp "$TL_TMP/r.json" "$TL_TMP/anyfx/.silver-bullet.json"
ci "enterprise_e2e_any_tool_enforced '$TL_TMP/anysb' '$TL_TMP/anyfx' graphify"; assert_eq "any enforced: SB repo config" 0 "$TL_STATUS"
ci "enterprise_e2e_any_tool_enforced '$TL_TMP/anysb' '$TL_TMP/anyfx' rtk"; assert_eq "any enforced: fixture config" 0 "$TL_STATUS"
ci "enterprise_e2e_any_tool_enforced '$TL_TMP/anysb' '$TL_TMP/anyfx' context_mode"; assert_eq "any enforced: neither" 1 "$TL_STATUS"

# --- library sourcing -------------------------------------------------------
LIBSB="$TL_TMP/libsb"
mkdir -p "$LIBSB/hooks/lib"
echo 'LIB_RTK_GATE=loaded' >"$LIBSB/hooks/lib/rtk-gate.sh"
echo 'LIB_RECOMMENDED=loaded' >"$LIBSB/hooks/lib/recommended-tools.sh"
e2e_script "source '$CORE'; enterprise_e2e_source_code_intel_libs '$LIBSB'; echo \"\${LIB_RECOMMENDED:-no} \${LIB_RTK_GATE:-no} \${LIB_GRAPHIFY:-no}\"" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "source libs: only the files that exist are sourced" "loaded loaded no" "$TL_OUT"
e2e_script "source '$CORE'; enterprise_e2e_source_code_intel_libs; echo ok" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "source libs: no root argument is harmless" "ok" "$TL_OUT"

# --- preflight_fail ----------------------------------------------------------
ci "enterprise_e2e_preflight_fail part one" ; assert_eq "preflight_fail returns 1" 1 "$TL_STATUS"
assert_eq "preflight_fail message" "ERROR: enterprise E2E code-intel preflight: part one" "$TL_ERR"

# --- Graphify ----------------------------------------------------------------
tl_stub graphify 'echo "graphify $*" >>"$GRAPHIFY_LOG"; case "$1" in update) exit "${GU_RC:-0}";; query) exit "${GQ_RC:-0}";; esac'
GL="$TL_TMP/graphify.log"
echo '{}' >"$TL_TMP/graph.json"
gfy() { rm -f "$GL"; ci "enterprise_e2e_preflight_graphify '$PROJ' '${CONFIG:-$TL_TMP/g.json}' ${DRY:-0}" "GRAPHIFY_LOG=$GL" "G_GRAPH=$TL_TMP/graph.json" "$@"; }
CONFIG="$TL_TMP/none.json" gfy
assert_eq "graphify: not enforced is silent success" "" "$TL_OUT"
DRY=1 gfy
assert_contains "graphify: dry run announces" "$TL_OUT" "graphify: $PROJ (opted in)"
assert_contains "graphify: dry run plans, runs nothing" "$TL_OUT" "DRY-RUN: would verify index + fresh graphify query"
assert_file_absent "graphify: dry run invokes nothing" "$GL"
gfy
assert_eq "graphify: fresh index and query ok" 0 "$TL_STATUS"
assert_contains "graphify: fresh message" "$TL_OUT" "graphify query fresh"
gfy "G_CLI=0"
assert_eq "graphify: CLI missing fails" 1 "$TL_STATUS"
assert_contains "graphify: CLI missing message" "$TL_ERR" "graphify CLI missing — install: uv tool install graphifyy ($PROJ)"
ci "unset -f sb_graphify_cli_available; enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0"
assert_eq "graphify: CLI probe not defined fails" 1 "$TL_STATUS"
gfy "G_INDEX=0"
assert_eq "graphify: missing index is rebuilt" 0 "$TL_STATUS"
assert_contains "graphify: rebuild announced" "$TL_OUT" "graphify index missing — running graphify update . --no-cluster"
assert_contains "graphify: update command run" "$(cat "$GL")" "graphify update . --no-cluster"
gfy "G_INDEX=0" "GU_RC=1"
assert_eq "graphify: failing update fails" 1 "$TL_STATUS"
assert_contains "graphify: update failure message" "$TL_ERR" "graphify update failed in $PROJ"
ci "enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0" "G_GRAPH=$TL_TMP/absent-graph.json" "GRAPHIFY_LOG=$GL"
assert_eq "graphify: index still missing after the check fails" 1 "$TL_STATUS"
assert_contains "graphify: index missing message" "$TL_ERR" "graphify index still missing at $TL_TMP/absent-graph.json"
ln -sf "$TL_TMP/graph.json" "$TL_TMP/graph-link.json"
ci "enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0" "G_GRAPH=$TL_TMP/graph-link.json" "GRAPHIFY_LOG=$GL"
assert_eq "graphify: a symlinked graph is refused" 1 "$TL_STATUS"
gfy "G_FRESH=0"
assert_eq "graphify: stale query is refreshed" 0 "$TL_STATUS"
assert_contains "graphify: refresh announced" "$TL_OUT" "graphify query stale/missing — recording fresh query"
assert_contains "graphify: query run with graph and budget" "$(cat "$GL")" "graphify query enterprise e2e live test matrix routes hooks skills orchestrator --graph rel/graph.json --budget 2000"
assert_contains "graphify: query state recorded" "$TL_OUT" "recorded:$TL_TMP/g.json"
ci "enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0 'custom task'" "G_GRAPH=$TL_TMP/graph.json" "GRAPHIFY_LOG=$GL" "G_FRESH=0"
assert_contains "graphify: custom task context honoured" "$(cat "$GL")" "graphify query custom task --graph"
gfy "G_FRESH=0" "GQ_RC=1"
assert_eq "graphify: failing query fails" 1 "$TL_STATUS"
assert_contains "graphify: query failure message" "$TL_ERR" "graphify query failed in $PROJ"
gfy "G_FRESH=0" "G_REC=0"
assert_eq "graphify: unrecordable query state fails" 1 "$TL_STATUS"
assert_contains "graphify: record failure message" "$TL_ERR" "could not record graphify query state"
ci "unset -f sb_graphify_record_query; enterprise_e2e_preflight_graphify '$PROJ' '$TL_TMP/g.json' 0" "G_GRAPH=$TL_TMP/graph.json" "GRAPHIFY_LOG=$GL" "G_FRESH=0"
assert_eq "graphify: no recorder defined is tolerated" 0 "$TL_STATUS"

# --- agentmemory --------------------------------------------------------------
tl_stub agentmemory 'echo started >>"$AM_STARTED"; exit 0'
tl_stub lsof 'echo 2147483646'
AM_ENV=("AM_STARTED=$TL_TMP/am.started")
am() {  # am DRY HOST ENV...
  local dry="$1" host="$2"
  shift 2
  reset_counts
  rm -f "$TL_TMP/am.started"
  ci "sleep() { :; }; enterprise_e2e_preflight_agentmemory '$PROJ' '${CONFIG:-$TL_TMP/a.json}' '$host' $dry" "${AM_ENV[@]}" "$@"
}
CONFIG="$TL_TMP/none.json" am 0 h
assert_eq "agentmemory: not enforced is silent" "" "$TL_OUT"
am 1 h
assert_contains "agentmemory: dry run plan" "$TL_OUT" "DRY-RUN: would verify server health, MCP wiring, .agentmemory/"
am 0 myhost
assert_eq "agentmemory: healthy server, wired, exported" 0 "$TL_STATUS"
assert_contains "agentmemory: platform check uses the given host" "$TL_OUT" "am-artifact-host:myhost"
am 0 "" 
assert_contains "agentmemory: host defaults to the runtime host" "$TL_OUT" "am-artifact-host:stubhost"
am 0 h "A_CLI=0"
assert_eq "agentmemory: CLI missing fails" 1 "$TL_STATUS"
assert_contains "agentmemory: CLI missing message" "$TL_ERR" "agentmemory CLI missing"
reset_counts
ci "unset -f sb_agentmemory_cli_available; enterprise_e2e_preflight_agentmemory '$PROJ' '$TL_TMP/a.json' h 0" "${AM_ENV[@]}"
assert_eq "agentmemory: CLI probe not defined fails" 1 "$TL_STATUS"
am 0 h "A_HEALTHY_AFTER=1"
assert_eq "agentmemory: unhealthy server is started and waited for" 0 "$TL_STATUS"
assert_contains "agentmemory: lsof found a stale listener" "$TL_OUT" "port 3111 in use but health failed — recycling stale listener"
assert_contains "agentmemory: start announced" "$TL_OUT" "agentmemory server not healthy — starting background server"
for _ in $(seq 1 50); do [[ -f "$TL_TMP/am.started" ]] && break; sleep 0.1; done
assert_file_exists "agentmemory: the server binary was launched" "$TL_TMP/am.started"
assert_file_exists "agentmemory: server log location prepared" "$HOME/.agentmemory/server.log"
tl_stub lsof 'exit 1'
am 0 h "A_HEALTHY_AFTER=1"
assert_not_contains "agentmemory: no listener, nothing to recycle" "$TL_OUT" "recycling stale listener"
assert_eq "agentmemory: still starts and recovers" 0 "$TL_STATUS"
rm -f "$TL_BIN/lsof"
am 0 h "A_HEALTHY_AFTER=1"
assert_not_contains "agentmemory: lsof absent skips the listener check" "$TL_OUT" "recycling stale listener"
am 0 h "A_HEALTHY_AFTER=1000"
assert_eq "agentmemory: server that never becomes healthy fails" 1 "$TL_STATUS"
assert_contains "agentmemory: unhealthy message" "$TL_ERR" "agentmemory server not healthy"
am 0 h "A_ART=0"
assert_eq "agentmemory: MCP not wired fails" 1 "$TL_STATUS"
assert_contains "agentmemory: wiring message" "$TL_ERR" "agentmemory MCP not wired for host=h"
reset_counts
ci "unset -f sb_agentmemory_platform_artifact_present sb_agentmemory_export_exists; enterprise_e2e_preflight_agentmemory '$PROJ' '$TL_TMP/a.json' h 0" "${AM_ENV[@]}"
assert_eq "agentmemory: optional checks undefined are skipped" 0 "$TL_STATUS"
am 0 h "A_EXP=0"
assert_eq "agentmemory: missing export root fails" 1 "$TL_STATUS"
assert_contains "agentmemory: export message" "$TL_ERR" ".agentmemory/ export root missing in $PROJ"

# --- RTK ------------------------------------------------------------------------
tl_stub fake-rtk 'if [[ "$1" == gain && "$2" == --help ]]; then exit "${RTK_GAIN_RC:-0}"; fi; exit 1'
RTK_BIN="$TL_BIN/fake-rtk"
rtk() { ci "enterprise_e2e_preflight_rtk '${CONFIG:-$TL_TMP/r.json}' '${HOST_ARG-h}' ${DRY:-0}" "R_BIN=$RTK_BIN" "$@"; }
CONFIG="$TL_TMP/none.json" rtk
assert_eq "rtk: not enforced is silent" "" "$TL_OUT"
DRY=1 rtk
assert_contains "rtk: dry run plan" "$TL_OUT" "DRY-RUN: would verify rtk gain --help and host PreToolUse hook"
rtk "SB_ROOT=$TL_TMP"
assert_eq "rtk: healthy install ok" 0 "$TL_STATUS"
assert_contains "rtk: wiring announced" "$TL_OUT" "rtk: global wiring (opted in via $TL_TMP/r.json)"
assert_contains "rtk: hook checked for the host" "$TL_ERR" "rtk-hook-host:h"
HOST_ARG="" rtk "SB_ROOT=$TL_TMP"
assert_contains "rtk: host defaults to the runtime host" "$TL_ERR" "rtk-hook-host:stubhost"
rtk "R_BIN="
assert_eq "rtk: no binary fails" 1 "$TL_STATUS"
assert_contains "rtk: no binary message" "$TL_ERR" "rtk CLI missing or wrong binary"
rtk "R_CLI=0"
assert_eq "rtk: wrong binary fails" 1 "$TL_STATUS"
rtk "RTK_GAIN_RC=1"
assert_eq "rtk: failing gain fails" 1 "$TL_STATUS"
assert_contains "rtk: gain message" "$TL_ERR" "rtk gain --help failed"
rtk "R_VER=0"
assert_eq "rtk: old version fails" 1 "$TL_STATUS"
assert_contains "rtk: version message" "$TL_ERR" "rtk version too old"
ci "unset -f sb_rtk_version_ok sb_rtk_platform_hook_present; enterprise_e2e_preflight_rtk '$TL_TMP/r.json' h 0" "R_BIN=$RTK_BIN"
assert_eq "rtk: optional checks undefined are skipped" 0 "$TL_STATUS"
rtk "R_HOOK=0" "SB_ROOT=$TL_TMP"
assert_eq "rtk: missing host hook fails" 1 "$TL_STATUS"
assert_contains "rtk: hook message" "$TL_ERR" "RTK host hook missing for h"
rtk "R_HOOK=0" -u SB_ROOT
assert_eq "rtk: hook probe falls back to PWD without SB_ROOT" 1 "$TL_STATUS"

# --- Context Mode ---------------------------------------------------------------
tl_stub context-mode 'echo "doctor platform=$CONTEXT_MODE_PLATFORM"; echo "${CM_DOCTOR_EXTRA:-all good}"; exit "${CM_DOCTOR_RC:-0}"'
cm() { ci "enterprise_e2e_preflight_context_mode '$PROJ' '${CONFIG:-$TL_TMP/c.json}' '${HOST_ARG-h}' ${DRY:-0}" "$@"; }
CONFIG="$TL_TMP/none.json" cm
assert_eq "context-mode: not enforced is silent" "" "$TL_OUT"
DRY=1 cm
assert_contains "context-mode: dry run plan" "$TL_OUT" "DRY-RUN: would verify Node >= 22.5, MCP wiring, context-mode doctor"
cm
assert_eq "context-mode: healthy install ok" 0 "$TL_STATUS"
assert_contains "context-mode: doctor ran for the mapped platform" "$TL_OUT" "context-mode doctor OK (platform=claude-code)"
HOST_ARG="" cm
assert_contains "context-mode: host defaults to the runtime host" "$TL_ERR" "cm-artifact-host:stubhost"
cm "C_NODE=0"
assert_eq "context-mode: old node fails" 1 "$TL_STATUS"
assert_contains "context-mode: node message" "$TL_ERR" "Node < 22.5"
cm "C_CLI=0"
assert_eq "context-mode: CLI missing fails" 1 "$TL_STATUS"
assert_contains "context-mode: CLI message" "$TL_ERR" "context-mode CLI/plugin missing"
ci "unset -f sb_context_mode_cli_available; enterprise_e2e_preflight_context_mode '$PROJ' '$TL_TMP/c.json' h 0"
assert_eq "context-mode: CLI probe not defined fails" 1 "$TL_STATUS"
cm "C_ART=0"
assert_eq "context-mode: MCP not wired fails" 1 "$TL_STATUS"
assert_contains "context-mode: wiring message" "$TL_ERR" "Context Mode MCP not wired for host=h"
cm "CM_DOCTOR_RC=1"
assert_eq "context-mode: failing doctor fails" 1 "$TL_STATUS"
assert_contains "context-mode: doctor failure message names the first line" "$TL_ERR" "context-mode doctor failed (platform=claude-code): doctor platform=claude-code"
cm "CM_DOCTOR_EXTRA=FAIL: hooks not installed"
assert_eq "context-mode: FAIL line in doctor output fails" 1 "$TL_STATUS"
assert_contains "context-mode: FAIL message" "$TL_ERR" "context-mode doctor reported FAIL (platform=claude-code)"
cm "C_PLATFORM="
assert_eq "context-mode: unmapped host warns and passes" 0 "$TL_STATUS"
assert_contains "context-mode: unmapped host message" "$TL_OUT" "WARN: no context-mode doctor platform for host=h — skipped"
ci "unset -f rtcm_doctor_platform; enterprise_e2e_preflight_context_mode '$PROJ' '$TL_TMP/c.json' h 0"
assert_eq "context-mode: no platform mapper skips the doctor" 0 "$TL_STATUS"
assert_not_contains "context-mode: doctor not run" "$TL_OUT" "doctor OK"
ci "unset -f sb_context_mode_node_ok sb_context_mode_platform_artifact_present; enterprise_e2e_preflight_context_mode '$PROJ' '$TL_TMP/c.json' h 0"
assert_eq "context-mode: optional probes undefined are skipped" 0 "$TL_STATUS"
rm -f "$TL_BIN/context-mode"
cm
assert_eq "context-mode: no context-mode binary skips the doctor" 0 "$TL_STATUS"

# --- orchestration ---------------------------------------------------------------
SBR="$TL_TMP/orch-sb"
FXT="$TL_TMP/orch-fx"
mkdir -p "$SBR" "$FXT"
orch() {  # orch DRY ENV...  (sub-preflights replaced by recorders honouring *_RC)
  local dry="$1"
  shift
  ci 'enterprise_e2e_preflight_graphify() { echo "G:$1:$3"; return "${G_RC:-0}"; }
enterprise_e2e_preflight_agentmemory() { echo "A:$1:$3:$4"; return "${A_RC:-0}"; }
enterprise_e2e_preflight_rtk() { echo "R:$1:$2:$3"; return "${R_RC:-0}"; }
enterprise_e2e_preflight_context_mode() { echo "C:$1:$3:$4"; return "${C_RC:-0}"; }
enterprise_e2e_code_intel_preflight '"'$SBR' '$FXT' $dry" "$@"
}
orch 0 "SILVER_BULLET_RUNTIME=codex"
assert_eq "orchestration: no configs, nothing to check" 0 "$TL_STATUS"
assert_contains "orchestration: banner" "$TL_OUT" "--- Code-intel preflight (Graphify / agentmemory / RTK / Context Mode) ---"
assert_contains "orchestration: live completion message" "$TL_OUT" "Code-intel preflight OK."
orch 1 "SILVER_BULLET_RUNTIME=codex"
assert_contains "orchestration: dry-run completion message" "$TL_OUT" "Code-intel preflight dry-run complete."
cp "$TL_TMP/all.json" "$SBR/.silver-bullet.json"
cp "$TL_TMP/all.json" "$FXT/.silver-bullet.json"
orch 0 "SILVER_BULLET_RUNTIME=codex"
assert_eq "orchestration: both configs checked" 0 "$TL_STATUS"
assert_contains "orchestration: graphify for the SB repo" "$TL_OUT" "G:$SBR:0"
assert_contains "orchestration: graphify for the fixture" "$TL_OUT" "G:$FXT:0"
assert_contains "orchestration: agentmemory gets the runtime host" "$TL_OUT" "A:$SBR:codex:0"
assert_eq "orchestration: RTK checked once" "1" "$(grep -c '^R:' <<<"$TL_OUT")"
assert_contains "orchestration: RTK uses the first config" "$TL_OUT" "R:$SBR/.silver-bullet.json:codex:0"
assert_eq "orchestration: Context Mode checked once" "1" "$(grep -c '^C:' <<<"$TL_OUT")"
assert_contains "orchestration: Context Mode project root" "$TL_OUT" "C:$SBR:codex:0"
orch 1 "SILVER_BULLET_RUNTIME=codex"
assert_contains "orchestration: dry-run flag forwarded" "$TL_OUT" "A:$FXT:codex:1"
cp "$TL_TMP/none.json" "$SBR/.silver-bullet.json"
orch 0 "SILVER_BULLET_RUNTIME=codex"
assert_contains "orchestration: RTK found via the fixture config" "$TL_OUT" "R:$FXT/.silver-bullet.json:codex:0"
assert_contains "orchestration: Context Mode project root is the fixture" "$TL_OUT" "C:$FXT:codex:0"
orch 0 "SILVER_BULLET_RUNTIME=codex" "G_RC=1"
assert_eq "orchestration: a graphify failure stops the run" 1 "$TL_STATUS"
assert_not_contains "orchestration: nothing after the failing step" "$TL_OUT" "A:"
orch 0 "SILVER_BULLET_RUNTIME=codex" "A_RC=1"
assert_eq "orchestration: an agentmemory failure stops the run" 1 "$TL_STATUS"
orch 0 "SILVER_BULLET_RUNTIME=codex" "R_RC=1"
assert_eq "orchestration: an rtk failure stops the run" 1 "$TL_STATUS"
orch 0 "SILVER_BULLET_RUNTIME=codex" "C_RC=1"
assert_eq "orchestration: a context-mode failure stops the run" 1 "$TL_STATUS"
assert_not_contains "orchestration: no success banner after a failure" "$TL_OUT" "Code-intel preflight OK."
orch 0 -u SILVER_BULLET_RUNTIME
assert_contains "orchestration: host defaults to claude" "$TL_OUT" "A:$FXT:claude:0"
ci "enterprise_e2e_code_intel_preflight '$TL_TMP/no-such-sb' '$FXT' 0"
assert_eq "orchestration: missing SB root fails" 1 "$TL_STATUS"
assert_contains "orchestration: missing SB root message" "$TL_ERR" "code-intel preflight: SB_ROOT missing"
ci "enterprise_e2e_code_intel_preflight '$SBR' '$TL_TMP/no-such-fx' 0"
assert_eq "orchestration: missing fixture fails" 1 "$TL_STATUS"
assert_contains "orchestration: missing fixture message" "$TL_ERR" "fixture dir missing: $TL_TMP/no-such-fx"
ci "enterprise_e2e_code_intel_preflight '$SBR' '' 0"
assert_eq "orchestration: empty fixture fails" 1 "$TL_STATUS"
# Failure propagation through the real sub-checks, reached via `if !` as agent-delegate does.
cp "$TL_TMP/g.json" "$FXT/.silver-bullet.json"
rm -f "$SBR/.silver-bullet.json"
ci "if ! enterprise_e2e_code_intel_preflight '$SBR' '$FXT' 0; then echo REFUSED; else echo ACCEPTED; fi" "G_CLI=0"
assert_contains "if-context: a missing graphify CLI is refused" "$TL_OUT" "REFUSED"
assert_not_contains "if-context: never accepted" "$TL_OUT" "ACCEPTED"

tl_results
