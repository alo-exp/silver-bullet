#!/usr/bin/env bash
# Behavior tests for hooks/lib/agentmemory-gate.sh (all external tools stubbed)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_AGENTMEMORY_MCP_ARTIFACT SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME

# shellcheck source=../../hooks/lib/agentmemory-gate.sh
source "$TL_REPO_ROOT/hooks/lib/agentmemory-gate.sh"
# shellcheck source=../../hooks/lib/nofollow-guard.sh
source "$TL_REPO_ROOT/hooks/lib/nofollow-guard.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
LIBF="$TL_REPO_ROOT/hooks/lib/agentmemory-gate.sh"
PR="$TL_TMP/proj"; mkdir -p "$PR"

# ---------- required / config strings ----------
w '{"recommended_tools":{"agentmemory":{"enabled_by_user":true,"health_url":"http://h/x","export_root":"mem","usage_ttl_seconds":120}}}'
yes_t "required" sb_agentmemory_required "$CFG"
assert_eq "health url: non-loopback host in the project file is ignored" "http://localhost:3111/agentmemory/health" "$(sb_agentmemory_health_url "$CFG")"
w '{"recommended_tools":{"agentmemory":{"health_url":"http://127.0.0.1:4000/agentmemory/health"}}}'
assert_eq "health url: loopback url accepted" "http://127.0.0.1:4000/agentmemory/health" "$(sb_agentmemory_health_url "$CFG")"
for bad in "-K/tmp/x" "file:///etc/passwd" "http://evil.example/health" "http://localhost:3111/a b" "http://localhost:99999999/x" "ftp://localhost/x"; do
  w "$(jq -n --arg u "$bad" '{recommended_tools:{agentmemory:{health_url:$u}}}')"
  assert_eq "health url rejected: $bad" "http://localhost:3111/agentmemory/health" "$(sb_agentmemory_health_url "$CFG")"
done
w '{"recommended_tools":{"agentmemory":{"enabled_by_user":true,"export_root":"mem","usage_ttl_seconds":120}}}'
assert_eq "health url default" "http://localhost:3111/agentmemory/health" "$(sb_agentmemory_health_url)"
assert_eq "export rel configured" "mem" "$(sb_agentmemory_export_rel_path "$CFG")"
assert_eq "export rel default" ".agentmemory" "$(sb_agentmemory_export_rel_path)"
w 'garbage'
assert_eq "health url invalid json" "http://localhost:3111/agentmemory/health" "$(sb_agentmemory_health_url "$CFG")"
assert_eq "export rel invalid json" ".agentmemory" "$(sb_agentmemory_export_rel_path "$CFG")"
assert_eq "ttl invalid json" "1800" "$(sb_agentmemory_usage_ttl_seconds "$CFG")"

# ---------- export path safety ----------
no_t "rel safe empty" sb_agentmemory_export_rel_is_safe ""
no_t "rel safe dotdot" sb_agentmemory_export_rel_is_safe "../x"
no_t "rel safe embedded dotdot component" sb_agentmemory_export_rel_is_safe "a/../b"
yes_t "rel safe dots inside a name" sb_agentmemory_export_rel_is_safe "a..b"
yes_t "rel safe plain" sb_agentmemory_export_rel_is_safe ".agentmemory"

no_t "scoped needs args" sb_agentmemory_export_path_is_project_scoped "" ""
no_t "scoped needs export" sb_agentmemory_export_path_is_project_scoped "$PR" ""
yes_t "scoped child" sb_agentmemory_export_path_is_project_scoped "$PR" "$PR/.agentmemory"
yes_t "scoped root itself" sb_agentmemory_export_path_is_project_scoped "$PR" "$PR"
no_t "scoped sibling" sb_agentmemory_export_path_is_project_scoped "$PR" "$TL_TMP/other"
no_t "scoped prefix lookalike" sb_agentmemory_export_path_is_project_scoped "$PR" "${PR}-evil/x"
mkdir -p "$TL_TMP/outside"; ln -s "$TL_TMP/outside" "$PR/escape"
no_t "scoped symlink escape (canonical)" sb_agentmemory_export_path_is_project_scoped "$PR" "$PR/escape"
yes_t "scoped nonexistent project root" sb_agentmemory_export_path_is_project_scoped "$TL_TMP/nonexistent-root" "$TL_TMP/nonexistent-root/x"
no_t "scoped dotdot lands outside" sb_agentmemory_export_path_is_project_scoped "$PR" "$PR/sub/../../other"
yes_t "scoped dotdot stays inside" sb_agentmemory_export_path_is_project_scoped "$PR" "$PR/sub/../ok"

w '{"recommended_tools":{"agentmemory":{"export_root":"mem"}}}'
assert_eq "abs export relative" "$PR/mem" "$(sb_agentmemory_abs_export_path "$PR/" "$CFG")"
assert_eq "abs export default root" "$PR/.agentmemory" "$(sb_agentmemory_abs_export_path "$PR")"
assert_eq "abs export default project root is PWD" "$PR/mem" "$(cd "$PR" && sb_agentmemory_abs_export_path "" "$CFG")"
w "{\"recommended_tools\":{\"agentmemory\":{\"export_root\":\"$PR/absmem\"}}}"
assert_eq "abs export: an absolute root from the project file falls back to the default" "$PR/.agentmemory" "$(sb_agentmemory_abs_export_path "$PR" "$CFG")"
w '{"recommended_tools":{"agentmemory":{"export_root":"/etc/outside"}}}'
assert_eq "abs export: absolute outside project falls back to the default" "$PR/.agentmemory" "$(sb_agentmemory_abs_export_path "$PR" "$CFG")"
w '{"recommended_tools":{"agentmemory":{"export_root":"../up"}}}'
assert_eq "abs export: traversal falls back to the default" "$PR/.agentmemory" "$(sb_agentmemory_abs_export_path "$PR" "$CFG")"
w '{"recommended_tools":{"agentmemory":{"export_root":"escape"}}}'
no_t "abs export through symlink escape" sb_agentmemory_abs_export_path "$PR" "$CFG"

# ---------- export exists / scaffold ----------
w '{"recommended_tools":{"agentmemory":{"export_root":"mem"}}}'
no_t "export missing" sb_agentmemory_export_exists "$PR" "$CFG"
yes_t "scaffold creates" sb_agentmemory_scaffold_export_root "$PR" "$CFG"
assert_file_exists "scaffold memory dir" "$PR/mem/memory/."
assert_file_exists "scaffold snapshots dir" "$PR/mem/snapshots/."
yes_t "export exists" sb_agentmemory_export_exists "$PR" "$CFG"
yes_t "export exists default project root" bash -c 'cd "$1" && source "$2" && sb_agentmemory_export_exists "" "$3"' _ "$PR" "$LIBF" "$CFG"
yes_t "scaffold default project root" bash -c 'cd "$1" && source "$2" && sb_agentmemory_scaffold_export_root "" "$3"' _ "$PR" "$LIBF" "$CFG"
rm -rf "$PR/mem"; ln -s "$TL_TMP/outside" "$PR/mem"
no_t "export symlink rejected" sb_agentmemory_export_exists "$PR" "$CFG"
no_t "scaffold refuses symlink-escaping export" sb_agentmemory_scaffold_export_root "$PR" "$CFG"
rm -f "$PR/mem"
w '{"recommended_tools":{"agentmemory":{"export_root":"../up"}}}'
yes_t "scaffold unsafe root scaffolds the default root instead" sb_agentmemory_scaffold_export_root "$PR" "$CFG"
[[ -d "$PR/.agentmemory/memory" && ! -e "$TL_TMP/up" ]] && tl_pass "nothing scaffolded outside the project" || tl_fail "nothing scaffolded outside the project"
printf 'file' >"$PR/blocker"
w '{"recommended_tools":{"agentmemory":{"export_root":"blocker/sub"}}}'
no_t "scaffold fails when mkdir fails" sb_agentmemory_scaffold_export_root "$PR" "$CFG"

# ---------- cli path / server ----------
PATH_NO_AM="$(tl_path_without agentmemory curl)"
no_t "cli_path none" env PATH="$PATH_NO_AM" bash -c 'source "$1"; sb_agentmemory_cli_path' _ "$LIBF"
no_t "cli_available none" env PATH="$PATH_NO_AM" bash -c 'source "$1"; sb_agentmemory_cli_available' _ "$LIBF"
tl_stub agentmemory 'if [[ "${1:-}" == status ]]; then printf "%s\n" "${AM_STATUS:-}"; fi; exit 0'
hash -r
assert_eq "cli_path from PATH" "$TL_BIN/agentmemory" "$(sb_agentmemory_cli_path)"
yes_t "cli_available" sb_agentmemory_cli_available
OTHER="$TL_TMP/manifest-am"; printf '#!/bin/sh\n' >"$OTHER"; chmod +x "$OTHER"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
jq -n --arg c "$OTHER" '{tools:{agentmemory:{command:$c}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path from manifest" "$OTHER" "$(sb_agentmemory_cli_path)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

hc() { rm -f "$SB_RUNTIME_STATE_DIR/agentmemory-health"; }
# server health: curl success, curl failure + CLI status, neither
tl_stub curl 'echo "$@" >>"'"$TL_TMP"'/curl.log"; exit "${CURL_RC:-0}"'
hash -r
export CURL_RC=0
hc
yes_t "healthy via curl" sb_agentmemory_server_healthy "$CFG"
assert_contains "curl hits the validated url" "$(cat "$TL_TMP/curl.log")" "http://localhost:3111/agentmemory/health"
assert_contains "curl gets the url after --" "$(cat "$TL_TMP/curl.log")" "-- http://localhost:3111/agentmemory/health"
assert_contains "curl does not follow redirects" "$(cat "$TL_TMP/curl.log")" "--max-redirs 0"
CURL_RC=22
yes_t "a fresh health cache answers without probing" sb_agentmemory_server_healthy "$CFG"
hc; CURL_RC=0; sb_agentmemory_server_healthy "$CFG"; printf 'up junk\n' >"$SB_RUNTIME_STATE_DIR/agentmemory-health"
CURL_RC=22
no_t "an unparsable health cache is ignored" sb_agentmemory_server_healthy "$CFG"
printf '%s up http://localhost:9/other\n' "$(date +%s)" >"$SB_RUNTIME_STATE_DIR/agentmemory-health"
no_t "a cache for another url is ignored" sb_agentmemory_server_healthy "$CFG"
printf '%s down http://localhost:3111/agentmemory/health\n' "$(date +%s)" >"$SB_RUNTIME_STATE_DIR/agentmemory-health"
CURL_RC=0
no_t "a fresh cached down answer is used" sb_agentmemory_server_healthy "$CFG"
printf '%s down http://localhost:3111/agentmemory/health\n' "$(( $(date +%s) - 120 ))" >"$SB_RUNTIME_STATE_DIR/agentmemory-health"
yes_t "an expired cache is re-probed" sb_agentmemory_server_healthy "$CFG"
export CURL_RC=22
hc
no_t "unhealthy: curl fails, status empty" sb_agentmemory_server_healthy "$CFG"
export AM_STATUS="Connected to engine"
hc
yes_t "healthy via status Connected" sb_agentmemory_server_healthy "$CFG"
export AM_STATUS="Health:   healthy"
hc
yes_t "healthy via status Health: healthy" sb_agentmemory_server_healthy "$CFG"
export AM_STATUS="Health: degraded"
hc
no_t "unhealthy status text" sb_agentmemory_server_healthy "$CFG"
AM_STATUS=""
hc
no_t "unhealthy: no curl, no cli" env PATH="$PATH_NO_AM" bash -c 'source "$1"; sb_agentmemory_server_healthy' _ "$LIBF"
tl_stub agentmemory 'exit 1'; hash -r
hc
no_t "unhealthy when status command fails" sb_agentmemory_server_healthy "$CFG"
tl_stub agentmemory 'if [[ "${1:-}" == status ]]; then printf "%s\n" "${AM_STATUS:-}"; fi; exit 0'
rm -f "$TL_BIN/curl"; hash -r
export AM_STATUS="Connected"
hc
yes_t "healthy via cli when curl missing" env PATH="$(tl_path_without curl)" AM_STATUS=Connected bash -c 'source "$1"; sb_agentmemory_server_healthy' _ "$LIBF"

# ---------- platform artifact ----------
export SB_AGENTMEMORY_MCP_ARTIFACT=/ovr
assert_eq "artifact override" "/ovr" "$(sb_agentmemory_platform_artifact_path "$PR" claude)"
unset SB_AGENTMEMORY_MCP_ARTIFACT
assert_eq "artifact cursor" "$HOME/.cursor/mcp.json" "$(sb_agentmemory_platform_artifact_path "$PR" cursor)"
assert_eq "artifact codex" "$HOME/.codex/config.toml" "$(sb_agentmemory_platform_artifact_path "$PR" codex)"
assert_eq "artifact opencode" "$HOME/.config/opencode/opencode.json" "$(sb_agentmemory_platform_artifact_path "$PR" opencode)"
assert_eq "artifact goose" "$HOME/.config/goose/config.yaml" "$(sb_agentmemory_platform_artifact_path "$PR" goose)"
assert_eq "artifact hermes" "$HOME/.hermes/config.yaml" "$(sb_agentmemory_platform_artifact_path "$PR" hermes)"
assert_eq "artifact pi env" "/pd/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pd sb_agentmemory_platform_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_agentmemory_platform_artifact_path /x pi' _ "$LIBF")"
assert_eq "artifact claude" "$HOME/.claude.json" "$(sb_agentmemory_platform_artifact_path "$PR" claude)"
assert_eq "artifact unknown" "$HOME/.claude.json" "$(sb_agentmemory_platform_artifact_path "$PR" weird)"
assert_eq "artifact default host" "$HOME/.claude.json" "$(SILVER_BULLET_RUNTIME=claude sb_agentmemory_platform_artifact_path "$PR")"
AF="$TL_TMP/art"; export SB_AGENTMEMORY_MCP_ARTIFACT="$AF"
no_t "artifact present: missing" sb_agentmemory_platform_artifact_present "$PR" claude
printf '{}' >"$AF"
no_t "artifact present: no marker" sb_agentmemory_platform_artifact_present "$PR" claude
printf '{"mcp":"agentmemory"}' >"$AF"
yes_t "artifact present" sb_agentmemory_platform_artifact_present "$PR" claude
yes_t "artifact present default host" sb_agentmemory_platform_artifact_present "$PR"
rm -f "$AF"; ln -s "$TL_TMP/tgt" "$AF"; printf 'agentmemory' >"$TL_TMP/tgt"
no_t "artifact present: symlink refused" sb_agentmemory_platform_artifact_present "$PR" claude
rm -f "$AF"; unset SB_AGENTMEMORY_MCP_ARTIFACT

# ---------- usage ttl / state path / epoch ----------
w '{"recommended_tools":{"agentmemory":{"usage_ttl_seconds":120}}}'
assert_eq "ttl configured" "120" "$(sb_agentmemory_usage_ttl_seconds "$CFG")"
assert_eq "ttl default" "1800" "$(sb_agentmemory_usage_ttl_seconds)"
w '{"recommended_tools":{"agentmemory":{"usage_ttl_seconds":10}}}'
assert_eq "ttl too low" "1800" "$(sb_agentmemory_usage_ttl_seconds "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_ttl_seconds":"x"}}}'
assert_eq "ttl non numeric" "1800" "$(sb_agentmemory_usage_ttl_seconds "$CFG")"

DEFSTATE="$SB_RUNTIME_STATE_DIR/agentmemory-usage"
assert_eq "state path default no config" "$DEFSTATE" "$(sb_agentmemory_usage_state_path)"
w '{}'
assert_eq "state path default empty config" "$DEFSTATE" "$(sb_agentmemory_usage_state_path "$CFG")"
w "{\"recommended_tools\":{\"agentmemory\":{\"usage_state_file\":\"$SB_RUNTIME_STATE_DIR/custom\"}}}"
assert_eq "state path configured inside state dir" "$SB_RUNTIME_STATE_DIR/custom" "$(sb_agentmemory_usage_state_path "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"${SB_RUNTIME_STATE_DIR}/placeholder"}}}'
assert_eq "state path placeholder STATE_DIR expanded" "$SB_RUNTIME_STATE_DIR/placeholder" "$(sb_agentmemory_usage_state_path "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"${SB_RUNTIME_HOME_ROOT}/.silver-bullet/home-placeholder"}}}'
assert_eq "state path placeholder HOME_ROOT expanded" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/home-placeholder" "$(sb_agentmemory_usage_state_path "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"${UNKNOWN_VAR}/x"}}}'
assert_eq "state path unresolved placeholder rejected" "$DEFSTATE" "$(sb_agentmemory_usage_state_path "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"/tmp/elsewhere/state"}}}'
assert_eq "state path outside state scope rejected" "$DEFSTATE" "$(sb_agentmemory_usage_state_path "$CFG")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"~/outside-state"}}}'
assert_eq "state path ~ outside state scope rejected" "$DEFSTATE" "$(sb_agentmemory_usage_state_path "$CFG")"
assert_eq "state path default without runtime dirs" "$HOME/.silver-bullet/agentmemory-usage" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; unset -f sb_runtime_path_is_state_scoped; sb_agentmemory_usage_state_path' _ "$LIBF")"
assert_eq "state path expands placeholders with fallbacks" "$HOME/.silver-bullet/p" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; unset -f sb_runtime_path_is_state_scoped; sb_agentmemory_usage_state_path "$2"' _ "$LIBF" "$(w '{"recommended_tools":{"agentmemory":{"usage_state_file":"${SB_RUNTIME_STATE_DIR}/p"}}}'; echo "$CFG")")"
w '{"recommended_tools":{"agentmemory":{"usage_state_file":"${SB_RUNTIME_HOME_ROOT}/h"}}}'
assert_eq "home root placeholder without a runtime home is rejected" "$HOME/.silver-bullet/agentmemory-usage" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; unset -f sb_runtime_path_is_state_scoped; sb_agentmemory_usage_state_path "$2"' _ "$LIBF" "$CFG")"

w 'garbage'
assert_eq "state path with unparsable config uses default" "$DEFSTATE" "$(sb_agentmemory_usage_state_path "$CFG")"
U="$DEFSTATE"

# ---------- usage fresh / record / clear ----------
w '{}'
no_t "not fresh without file" sb_agentmemory_usage_is_fresh "$CFG"
tl_stub date 'echo 5000'; hash -r
printf '4000\n' >"$U"; yes_t "fresh within default ttl" sb_agentmemory_usage_is_fresh "$CFG"
printf '3200\n' >"$U"; yes_t "fresh at ttl boundary" sb_agentmemory_usage_is_fresh "$CFG"
printf '3199\n' >"$U"; no_t "stale beyond ttl" sb_agentmemory_usage_is_fresh "$CFG"
printf '6000\n' >"$U"; no_t "future epoch not fresh" sb_agentmemory_usage_is_fresh "$CFG"
rm -f "$U"
sb_agentmemory_record_usage "$CFG"
assert_eq "record usage writes epoch" "5000" "$(cat "$U")"
sb_agentmemory_clear_usage_state "$CFG"
assert_file_absent "clear removes state" "$U"
sb_agentmemory_clear_usage_state "$CFG"
tl_pass "clear is idempotent"
mkdir -p "$U/child"
sb_agentmemory_clear_usage_state "$CFG"
assert_eq "clear tolerates rm failure on non-empty directory" "yes" "$([[ -d "$U/child" ]] && echo yes || echo no)"
rm -rf "$U"
mkdir -p "$U"
no_t "record usage fails when path is a directory" sb_agentmemory_record_usage "$CFG"
rmdir "$U"
printf 'precious\n' >"$TL_TMP/tgt"
ln -s "$TL_TMP/tgt" "$U"
sb_agentmemory_record_usage "$CFG"
assert_eq "record usage never writes through a symlink" "precious" "$(cat "$TL_TMP/tgt")"
if [[ -f "$U" && ! -L "$U" ]]; then tl_pass "record usage replaces the symlink with a regular file"; else tl_fail "record usage replaces the symlink with a regular file"; fi
assert_eq "record usage wrote the epoch" "5000" "$(cat "$U")"
printf '4999\n' >"$TL_TMP/tgt"; rm -f "$U"; ln -s "$TL_TMP/tgt" "$U"
no_t "a symlinked usage stamp is never fresh" sb_agentmemory_usage_is_fresh "$CFG"
rm -f "$U"
rm -f "$U" "$TL_BIN/date"; hash -r
BADF="$TL_TMP/badfile"; printf 'x' >"$BADF"
(
  sb_agentmemory_usage_state_path() { printf '%s/sub/state' "$BADF"; }
  sb_agentmemory_record_usage "$CFG" && exit 1
  exit 0
) && tl_pass "record usage fails when parent cannot be created" || tl_fail "record usage fails when parent cannot be created"

# ---------- graphify synergy ----------
no_t "synergy needs config" sb_agentmemory_graphify_synergy_active ""
no_t "synergy missing config" sb_agentmemory_graphify_synergy_active "$TL_TMP/none.json"
w '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}'
mkdir -p "$PR/graphify-out"; : >"$PR/graphify-out/graph.json"
no_t "synergy: graphify enabled but no fresh query" bash -c 'source "$1"; sb_agentmemory_graphify_synergy_active "$2"' _ "$LIBF" "$CFG"
w '{"recommended_tools":{"graphify":{"enabled_by_user":false}}}'
no_t "synergy: graphify disabled" bash -c 'source "$1"; sb_agentmemory_graphify_synergy_active "$2"' _ "$LIBF" "$CFG"
(
  # graphify freshness helper present but the required-check helper missing: synergy is inactive
  w '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}'
  sb_graphify_query_is_fresh() { return 0; }
  unset -f sb_graphify_required
  sb_agentmemory_graphify_synergy_active "$CFG" && exit 1
  exit 0
) && tl_pass "synergy inactive when required-helper is unavailable" || tl_fail "synergy inactive when required-helper is unavailable (exit $?)"
(
  sb_graphify_required() { return 0; }
  sb_graphify_query_is_fresh() { return 0; }
  w '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}'
  sb_agentmemory_graphify_synergy_active "$CFG" || exit 1
  sb_graphify_query_is_fresh() { return 1; }
  sb_agentmemory_graphify_synergy_active "$CFG" && exit 2
  exit 0
) && tl_pass "synergy follows graphify required + fresh query" || tl_fail "synergy follows graphify required + fresh query (exit $?)"

# ---------- command classification ----------
yes_t "retrieval: empty is not retrieval" bash -c '! { source "$1"; sb_agentmemory_command_is_retrieval ""; }' _ "$LIBF"
yes_t "retrieval http" sb_agentmemory_command_is_retrieval "curl http://localhost:3111/agentmemory/smart-search"
yes_t "retrieval cli search" sb_agentmemory_command_is_retrieval "agentmemory search foo"
yes_t "retrieval cli query" sb_agentmemory_command_is_retrieval "/usr/bin/agentmemory query bar"
no_t "retrieval cli status is not retrieval" sb_agentmemory_command_is_retrieval "agentmemory status"
no_t "retrieval: mcp package launch is not retrieval" sb_agentmemory_command_is_retrieval "npx @agentmemory/mcp"
no_t "retrieval: scheme-less curl url is not accepted" sb_agentmemory_command_is_retrieval "curl localhost:3111/agentmemory/smart-search"
no_t "retrieval: curl with an output option is not retrieval" sb_agentmemory_command_is_retrieval "curl -o /tmp/x http://localhost:3111/agentmemory/smart-search"
no_t "retrieval: curl config option is not retrieval" sb_agentmemory_command_is_retrieval "curl -K /tmp/x http://localhost:3111/agentmemory/smart-search"
no_t "retrieval: other host is not retrieval" sb_agentmemory_command_is_retrieval "curl http://evil.example/agentmemory/smart-search http://localhost:3111/agentmemory/smart-search"
no_t "retrieval: health endpoint is not retrieval" sb_agentmemory_command_is_retrieval "curl http://localhost:3111/agentmemory/health"
no_t "retrieval: a pipeline is not a simple command" sb_agentmemory_command_is_retrieval "agentmemory search foo | tee out"
no_t "retrieval: echo of a retrieval is not retrieval" sb_agentmemory_command_is_retrieval "echo agentmemory search foo"
no_t "retrieval: a positional argument before the subcommand" sb_agentmemory_command_is_retrieval "agentmemory export search"
yes_t "retrieval: leading flag before the subcommand" sb_agentmemory_command_is_retrieval "agentmemory --json search foo"
yes_t "retrieval: rtk prefix is unwrapped" sb_agentmemory_command_is_retrieval "rtk agentmemory search foo"
no_t "retrieval: bare agentmemory" sb_agentmemory_command_is_retrieval "agentmemory"
no_t "retrieval unrelated" sb_agentmemory_command_is_retrieval "ls -la"
yes_t "exempt empty" sb_agentmemory_command_is_exempt ""
yes_t "exempt retrieval" sb_agentmemory_command_is_exempt "agentmemory recall x"
yes_t "exempt agentmemory cli" sb_agentmemory_command_is_exempt "agentmemory status"
yes_t "exempt loopback read-only curl" sb_agentmemory_command_is_exempt "curl -s http://localhost:3111/agentmemory/health"
no_t "not exempt: wget" sb_agentmemory_command_is_exempt "wget localhost:3111/agentmemory/health > out.txt"
no_t "not exempt: curl to another host" sb_agentmemory_command_is_exempt "curl http://x > out.txt"
no_t "not exempt: arbitrary background command" sb_agentmemory_command_is_exempt "nohup server > out.log &"
yes_t "exempt: the documented server start" sb_agentmemory_command_is_exempt "nohup agentmemory > ~/.agentmemory/server.log 2>&1 &"
no_t "not exempt: a lookalike of the server start" sb_agentmemory_command_is_exempt "nohup agentmemory > ~/.bashrc 2>&1 &"
yes_t "exempt: read-only listing" sb_agentmemory_command_is_exempt "ls -la"
no_t "not exempt commit" sb_agentmemory_command_is_exempt "git commit -m x"

# ---------- edit path exemption ----------
w '{"recommended_tools":{"agentmemory":{"export_root":"mem"}}}'
no_t "edit exempt empty" sb_agentmemory_edit_path_is_exempt ""
yes_t "edit exempt in export root (absolute)" sb_agentmemory_edit_path_is_exempt "$TL_TMP/mem/memory/a.md" "$CFG"
no_t "edit not exempt: dotdot out of the export root" sb_agentmemory_edit_path_is_exempt "$TL_TMP/mem/../src/a.py" "$CFG"
no_t "edit not exempt: export root lookalike" sb_agentmemory_edit_path_is_exempt "$TL_TMP/mem-evil/a.py" "$CFG"
yes_t "edit exempt in export root (relative)" sb_agentmemory_edit_path_is_exempt "mem/memory/a.md" "$CFG"
yes_t "edit exempt default export root" sb_agentmemory_edit_path_is_exempt "$TL_TMP/.agentmemory/x" "$TL_TMP/none.json"
yes_t "edit exempt state dir" sb_agentmemory_edit_path_is_exempt "/p/.silver-bullet/state" "$CFG"
no_t "edit not exempt" sb_agentmemory_edit_path_is_exempt "/p/src/a.py" "$CFG"

# ---------- messages ----------
m="$(SILVER_BULLET_RUNTIME=claude sb_agentmemory_block_message_no_cli "$CFG")"
assert_contains "no_cli header" "$m" "AGENTMEMORY REQUIRED"
assert_contains "no_cli install" "$m" "npm install -g @agentmemory/agentmemory"
w '{"recommended_tools":{"agentmemory":{"health_url":"http://localhost:1/health"}}}'
m="$(sb_agentmemory_block_message_no_server "$CFG")"
assert_contains "no_server header" "$m" "AGENTMEMORY SERVER DOWN"
assert_contains "no_server url" "$m" "Health check failed: http://localhost:1/health"
m="$(SILVER_BULLET_RUNTIME=claude sb_agentmemory_block_message_no_mcp "$CFG")"
assert_contains "no_mcp header" "$m" "AGENTMEMORY MCP NOT WIRED"
assert_contains "no_mcp artifact" "$m" "$HOME/.claude.json"
assert_contains "no_mcp commands" "$m" "agentmemory connect claude-code"
(
  sb_recommended_tool_platform_install_commands() { return 1; }
  [[ "$(sb_agentmemory_block_message_no_mcp "$CFG")" == *"MCP NOT WIRED"* ]]
) && tl_pass "no_mcp survives command failure" || tl_fail "no_mcp survives command failure"
m="$(sb_agentmemory_block_message_no_export "/p/.agentmemory")"
assert_contains "no_export mkdir" "$m" "mkdir -p /p/.agentmemory/memory /p/.agentmemory/snapshots"
assert_contains "no_export env root" "$m" "AGENTMEMORY_EXPORT_ROOT=./.agentmemory"
assert_contains "no_export default" "$(sb_agentmemory_block_message_no_export)" "mkdir -p .agentmemory/memory"
assert_contains "stale usage ttl" "$(sb_agentmemory_block_message_stale_usage 77)" "every 77s"
assert_contains "stale usage default ttl" "$(sb_agentmemory_block_message_stale_usage)" "every 1800s"

# ---------- prompt reminder ----------
RC="$PR/.silver-bullet.json"
reminder() { SILVER_BULLET_RUNTIME=claude sb_agentmemory_prompt_reminder_line "$RC"; }
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}' >"$RC"
assert_contains "reminder pending (a project recommendation is not consent)" "$(XDG_CONFIG_HOME="$TL_TMP/none" reminder)" "consent pending"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":false}}}' >"$RC"; assert_contains "reminder disabled" "$(reminder)" "opted out"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true,"enforcement_suspended":true}}}' >"$RC"; assert_contains "reminder suspended" "$(reminder)" "enforcement suspended"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true,"export_root":"mem"}}}' >"$RC"
rm -f "$TL_BIN/agentmemory"; hash -r
assert_contains "reminder cli missing" "$(PATH="$PATH_NO_AM" reminder)" "CLI missing"
mkdir -p "$PR/mem/memory"; hc
tl_stub agentmemory 'exit 0'; tl_stub curl 'exit 22'; hash -r
assert_contains "reminder server down" "$(reminder)" "the server is down"
tl_stub curl 'exit 0'; hash -r; hc
export SB_AGENTMEMORY_MCP_ARTIFACT="$AF"
assert_contains "reminder healthy server asks for usage" "$(reminder)" "recall via MCP or smart-search"
printf 'agentmemory' >"$AF"
rm -rf "$PR/mem"
assert_contains "reminder export missing" "$(reminder)" "export root missing — mkdir -p mem/memory"
mkdir -p "$PR/mem/memory"
tl_stub date 'echo 5000'; hash -r
assert_contains "reminder usage required" "$(reminder)" "USAGE REQUIRED"
assert_contains "reminder usage required ttl" "$(reminder)" "TTL 1800s"
printf '4000\n' >"$U"
assert_contains "reminder fresh" "$(reminder)" "fresh usage recorded"
(
  sb_agentmemory_graphify_synergy_active() { return 0; }
  [[ "$(reminder)" == *"synergy active"* ]]
) && tl_pass "reminder synergy" || tl_fail "reminder synergy"
rm -f "$U" "$TL_BIN/date"; hash -r
unset SB_AGENTMEMORY_MCP_ARTIFACT

tl_results
