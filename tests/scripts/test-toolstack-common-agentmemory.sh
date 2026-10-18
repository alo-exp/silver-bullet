#!/usr/bin/env bash
# scripts/lib/global-toolstack/common.sh: agentmemory, shell-compression and
# token-usage helpers, plus MCP/hook wiring probes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

# The common.sh functions are sourced once into this shell and every call runs in a
# forked subshell (no bash -c re-exec per call), with the defaults of a fresh
# `bash -c` (no errexit/nounset/pipefail, empty command hash, cwd as requested).
# shellcheck source=/dev/null
source "$TS_SRC/common.sh"
_ts_sub() { # <dir> <fn> [args]
  local d="$1"; shift
  ( set +e +u +o pipefail; hash -r; cd "$d" && "$@" )
}
in_dir() { tl_run _ts_sub "$@"; }
ts_call() { tl_run _ts_sub "$HOME" "$@"; }

ts_write_config '{"enforcement":"always","state_dir":"~/st","shell_compression":{"primary":"leanctx","fallback":"rtk"},"tools":{"graphify":{"required":true,"query_ttl_seconds":900},"agentmemory":{"required":true,"health_url":"http://h.test/health","export_root":"mem","usage_ttl_seconds":600},"rtk":{"usage_ttl_seconds":100}}}'
plain="$TL_TMP/plain"; mkdir -p "$plain"
sbp="$TL_TMP/sbproj"
ts_sb_project "$sbp" '{"recommended_tools":{"agentmemory":{"export_root":"sbmem","health_url":"http://sb.test/h","usage_ttl_seconds":240}}}'

# --- config readers ---
ts_call ts_agentmemory_health_url
assert_eq "health url from config" http://h.test/health "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_agentmemory_health_url
assert_eq "health url default" http://localhost:3111/agentmemory/health "$TL_OUT"
ts_call ts_agentmemory_export_rel_path
assert_eq "export root from config" mem "$TL_OUT"
printf '{"tools":{"agentmemory":{"export_dir":"edir"}}}' >"$TL_TMP/ed.json"
TS_CONFIG="$TL_TMP/ed.json" ts_call ts_agentmemory_export_rel_path
assert_eq "export_dir alias" edir "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_agentmemory_export_rel_path
assert_eq "export root default" .agentmemory "$TL_OUT"
ts_call ts_agentmemory_usage_ttl_seconds
assert_eq "usage ttl from config" 600 "$TL_OUT"
for bad in 0 x 59; do
  printf '{"tools":{"agentmemory":{"usage_ttl_seconds":"%s"}}}' "$bad" >"$TL_TMP/b.json"
  TS_CONFIG="$TL_TMP/b.json" ts_call ts_agentmemory_usage_ttl_seconds
  assert_eq "usage ttl '$bad' falls back" 1800 "$TL_OUT"
done
TS_CONFIG="$TL_TMP/none.json" ts_call ts_agentmemory_usage_ttl_seconds
assert_eq "usage ttl without config" 1800 "$TL_OUT"

# --- effective readers ---
in_dir "$plain" ts_effective_export_root
assert_eq "effective export root (global)" mem "$TL_OUT"
in_dir "$sbp" ts_effective_export_root
assert_eq "effective export root (SB)" sbmem "$TL_OUT"
in_dir "$plain" ts_effective_health_url
assert_eq "effective health url (global)" http://h.test/health "$TL_OUT"
in_dir "$sbp" ts_effective_health_url
assert_eq "effective health url (SB)" http://sb.test/h "$TL_OUT"
in_dir "$plain" ts_effective_usage_ttl
assert_eq "effective usage ttl (global)" 600 "$TL_OUT"
in_dir "$sbp" ts_effective_usage_ttl
assert_eq "effective usage ttl (SB)" 240 "$TL_OUT"
sb2="$TL_TMP/sb2"
ts_sb_project "$sb2" '{"recommended_tools":{"agentmemory":{"usage_ttl_seconds":10}}}'
in_dir "$sb2" ts_effective_usage_ttl
assert_eq "SB ttl <60 falls back to global" 600 "$TL_OUT"
in_dir "$sb2" ts_effective_export_root
assert_eq "SB without export root falls back" mem "$TL_OUT"
in_dir "$sb2" ts_effective_health_url
assert_eq "SB without health url falls back" http://h.test/health "$TL_OUT"
sb3="$TL_TMP/sb3"
ts_sb_project "$sb3" 'garbage'
in_dir "$sb3" ts_effective_usage_ttl
assert_eq "SB unparsable: usage ttl falls back" 600 "$TL_OUT"

# --- export path ---
in_dir "$plain" ts_agentmemory_abs_export_path
assert_eq "abs export path defaults to PWD" "$plain/mem" "$TL_OUT"
ts_call ts_agentmemory_abs_export_path "$plain/"
assert_eq "abs export path trims slash" "$plain/mem" "$TL_OUT"
printf '{"tools":{"agentmemory":{"export_root":"/abs/mem"}}}' >"$TL_TMP/abs.json"
TS_CONFIG="$TL_TMP/abs.json" ts_call ts_agentmemory_abs_export_path "$plain"
assert_eq "absolute export root kept" /abs/mem "$TL_OUT"
printf '{"tools":{"agentmemory":{"export_root":"../escape"}}}' >"$TL_TMP/dd.json"
TS_CONFIG="$TL_TMP/dd.json" ts_call ts_agentmemory_abs_export_path "$plain"
assert_eq "parent traversal rejected" 1 "$TL_STATUS"
ts_call ts_agentmemory_export_exists "$plain"
assert_eq "export dir missing" 1 "$TL_STATUS"
mkdir -p "$plain/mem"
ts_call ts_agentmemory_export_exists "$plain"
assert_eq "export dir exists" 0 "$TL_STATUS"
in_dir "$plain" ts_agentmemory_export_exists
assert_eq "export dir exists (PWD default)" 0 "$TL_STATUS"
rmdir "$plain/mem"; mkdir "$TL_TMP/target"; ln -s "$TL_TMP/target" "$plain/mem"
ts_call ts_agentmemory_export_exists "$plain"
assert_eq "symlinked export dir rejected" 1 "$TL_STATUS"
TS_CONFIG="$TL_TMP/dd.json" ts_call ts_agentmemory_export_exists "$plain"
assert_eq "traversal export path => not exists" 1 "$TL_STATUS"
rm "$plain/mem"
ts_call ts_agentmemory_scaffold_export "$plain"
assert_eq "scaffold ok" 0 "$TL_STATUS"
assert_file_exists "scaffold creates memory/" "$plain/mem/memory"
assert_file_exists "scaffold creates snapshots/" "$plain/mem/snapshots"
in_dir "$plain" ts_agentmemory_scaffold_export
assert_eq "scaffold idempotent (PWD default)" 0 "$TL_STATUS"
TS_CONFIG="$TL_TMP/dd.json" ts_call ts_agentmemory_scaffold_export "$plain"
assert_eq "scaffold refuses traversal" 1 "$TL_STATUS"
printf 'file' >"$TL_TMP/blocker"
printf '{"tools":{"agentmemory":{"export_root":"%s/blocker/x"}}}' "$TL_TMP" >"$TL_TMP/blk.json"
TS_CONFIG="$TL_TMP/blk.json" ts_call ts_agentmemory_scaffold_export "$plain"
assert_eq "scaffold fails when mkdir fails" 1 "$TL_STATUS"

# --- cli / server health ---
ts_call ts_agentmemory_cli_available
assert_eq "no agentmemory CLI" 1 "$TL_STATUS"
tl_stub agentmemory 'if [[ "$1" == status ]]; then echo "$AM_STATUS"; fi'
ts_call ts_agentmemory_cli_available
assert_eq "agentmemory CLI present" 0 "$TL_STATUS"
tl_stub curl 'echo "$*" >"$HOME/curl-args"; exit "${CURL_RC:-0}"'
CURL_RC=0 ts_call ts_agentmemory_server_healthy
assert_eq "healthy via curl" 0 "$TL_STATUS"
assert_contains "curl hits configured URL with timeout" "$(cat "$HOME/curl-args")" "--max-time 3 http://h.test/health"
for s in "Connected" "Health:   healthy"; do
  CURL_RC=1 AM_STATUS="$s" ts_call ts_agentmemory_server_healthy
  assert_eq "healthy via status: $s" 0 "$TL_STATUS"
done
CURL_RC=1 AM_STATUS="Health: down" ts_call ts_agentmemory_server_healthy
assert_eq "unhealthy status" 1 "$TL_STATUS"
rm -f "$TL_BIN/curl"
# tl_path_without symlinks every executable on PATH (about 5 s per call here), so
# build a minimal PATH with only what the health probe needs and without curl.
mini="$TL_TMP/mini-path"; mkdir -p "$mini"
for c in bash jq dirname grep sed cat date sha256sum awk mkdir env; do ln -s "$(command -v "$c")" "$mini/$c"; done
PATH="$TL_BIN:$mini" AM_STATUS="Connected" ts_call ts_agentmemory_server_healthy
assert_eq "no curl: falls back to agentmemory status" 0 "$TL_STATUS"
rm -f "$TL_BIN/agentmemory"
PATH="$mini" ts_call ts_agentmemory_server_healthy
assert_eq "neither curl nor agentmemory => unhealthy" 1 "$TL_STATUS"

# --- MCP wiring probes ---
mcp="$HOME/.cursor/mcp.json"
mkdir -p "$HOME/.cursor"
for fn in ts_agentmemory_mcp_wired ts_context_mode_mcp_wired ts_leanctx_mcp_wired; do
  ts_call "$fn"
  assert_eq "$fn: no mcp.json" 1 "$TL_STATUS"
done
printf '{"mcpServers":{"agentmemory":{},"context-mode":{},"leanctx":{}}}' >"$mcp"
for fn in ts_agentmemory_mcp_wired ts_context_mode_mcp_wired ts_leanctx_mcp_wired; do
  ts_call "$fn"
  assert_eq "$fn: wired" 0 "$TL_STATUS"
done
printf '{"mcpServers":{}}' >"$mcp"
for fn in ts_agentmemory_mcp_wired ts_context_mode_mcp_wired ts_leanctx_mcp_wired; do
  ts_call "$fn"
  assert_eq "$fn: not listed" 1 "$TL_STATUS"
done
rm "$mcp"; printf '{"agentmemory":1,"context-mode":1,"leanctx":1}' >"$TL_TMP/real-mcp.json"; ln -s "$TL_TMP/real-mcp.json" "$mcp"
for fn in ts_agentmemory_mcp_wired ts_context_mode_mcp_wired ts_leanctx_mcp_wired; do
  ts_call "$fn"
  assert_eq "$fn: symlinked mcp.json rejected" 1 "$TL_STATUS"
done
rm "$mcp"

# --- usage state ---
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
statef="$HOME/st/$hash/agentmemory-usage"
in_dir "$repo" ts_agentmemory_usage_state_path
assert_eq "usage path under project state dir" "$statef" "$TL_OUT"
in_dir "$sbp" ts_agentmemory_usage_state_path
assert_eq "SB projects share SB usage file" "$HOME/.silver-bullet/agentmemory-usage" "$TL_OUT"
sf="$TL_TMP/u"
ts_call ts_agentmemory_usage_epoch "$sf"
assert_eq "usage epoch: missing" 1 "$TL_STATUS"
echo 123 >"$sf"
ts_call ts_agentmemory_usage_epoch "$sf"
assert_eq "usage epoch" 123 "$TL_OUT"
echo nope >"$sf"
ts_call ts_agentmemory_usage_epoch "$sf"
assert_eq "usage epoch: non-numeric" 1 "$TL_STATUS"
rm "$sf"; ln -s "$TL_TMP/real-mcp.json" "$sf"
ts_call ts_agentmemory_usage_epoch "$sf"
assert_eq "usage epoch: symlink rejected" 1 "$TL_STATUS"

tl_stub date 'echo 5000'
in_dir "$repo" ts_agentmemory_usage_is_fresh
assert_eq "no usage state => stale" 1 "$TL_STATUS"
mkdir -p "$(dirname "$statef")"
echo 4400 >"$statef"
in_dir "$repo" ts_agentmemory_usage_is_fresh
assert_eq "age 600 == ttl => fresh" 0 "$TL_STATUS"
echo 4399 >"$statef"
in_dir "$repo" ts_agentmemory_usage_is_fresh
assert_eq "age 601 => stale" 1 "$TL_STATUS"
echo 5001 >"$statef"
in_dir "$repo" ts_agentmemory_usage_is_fresh
assert_eq "future epoch => stale" 1 "$TL_STATUS"
rm -f "$statef"
in_dir "$repo" ts_agentmemory_record_usage
assert_eq "record usage ok" 0 "$TL_STATUS"
assert_eq "record usage writes epoch" 5000 "$(cat "$statef")"
rm -rf "$HOME/st"; printf x >"$HOME/st"
in_dir "$repo" ts_agentmemory_record_usage
assert_eq "record usage fails when dir cannot be created" 1 "$TL_STATUS"
rm -f "$HOME/st"
rm -f "$TL_BIN/date"

# --- synergy ---
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":false}}}'
in_dir "$repo" ts_agentmemory_graphify_synergy_active
assert_eq "synergy off when graphify not required" 1 "$TL_STATUS"
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true,"query_ttl_seconds":900}}}'
in_dir "$repo" ts_agentmemory_graphify_synergy_active
assert_eq "synergy off without fresh graphify query" 1 "$TL_STATUS"
mkdir -p "$HOME/st/$hash"; date +%s >"$HOME/st/$hash/graphify-query"
in_dir "$repo" ts_agentmemory_graphify_synergy_active
assert_eq "synergy on with fresh graphify query" 0 "$TL_STATUS"

# --- command classification ---
for c in 'curl localhost:3111/agentmemory/smart-search' 'curl localhost:3111/agentmemory/recall' 'agentmemory search foo' '/x/agentmemory recall x' 'npx @agentmemory/mcp'; do
  ts_call ts_agentmemory_command_is_retrieval "$c"
  assert_eq "am retrieval: $c" 0 "$TL_STATUS"
done
for c in '' 'agentmemory start' 'curl localhost:3111/agentmemory/health' 'echo search'; do
  ts_call ts_agentmemory_command_is_retrieval "$c"
  assert_eq "am not retrieval: '$c'" 1 "$TL_STATUS"
done
for c in '' 'agentmemory search x' 'agentmemory start' 'curl localhost:3111/agentmemory/health' 'mkdir -p x' 'cat f' 'graphify update .' 'launchctl list'; do
  ts_call ts_agentmemory_command_is_exempt "$c"
  assert_eq "am exempt: '$c'" 0 "$TL_STATUS"
done
for c in 'make build' 'rm -rf x'; do
  ts_call ts_agentmemory_command_is_exempt "$c"
  assert_eq "am not exempt: $c" 1 "$TL_STATUS"
done

# --- edit path exemptions ---
for p in .agentmemory/x /r/.agentmemory/x mem/y /r/mem/y; do
  ts_write_config '{"tools":{"agentmemory":{"export_root":"mem"}}}'
  ts_call ts_agentmemory_edit_path_is_exempt "$p"
  assert_eq "am edit exempt: $p" 0 "$TL_STATUS"
done
for p in "" /r/src/a.py other/z; do
  ts_call ts_agentmemory_edit_path_is_exempt "$p"
  assert_eq "am edit not exempt: '$p'" 1 "$TL_STATUS"
done

# --- MCP save detection ---
mk() { jq -cn --arg s "$1" --arg t "$2" '{tool_input:{server:$s,toolName:$t}}'; }
for t in memory_save save_memory agentmemory_save; do
  ts_call ts_agentmemory_mcp_is_save "$(mk agentmemory-server "$t")"
  assert_eq "mcp save: $t" 0 "$TL_STATUS"
done
ts_call ts_agentmemory_mcp_is_save "$(mk agentmemory memory_recall)"
assert_eq "mcp non-save tool" 1 "$TL_STATUS"
ts_call ts_agentmemory_mcp_is_save "$(mk other memory_save)"
assert_eq "mcp save on other server" 1 "$TL_STATUS"
ts_call ts_agentmemory_mcp_is_save ""
assert_eq "mcp save with empty payload" 1 "$TL_STATUS"

# --- shell compression / token usage ---
ts_write_config '{"shell_compression":{"primary":"leanctx","fallback":"rtk"}}'
ts_call ts_shell_compression_primary
assert_eq "compression primary" leanctx "$TL_OUT"
ts_call ts_shell_compression_fallback
assert_eq "compression fallback" rtk "$TL_OUT"
printf '{"tools":{"shell_compression":{"primary":"tp","fallback":"tf"}}}' >"$TL_TMP/tsc.json"
TS_CONFIG="$TL_TMP/tsc.json" ts_call ts_shell_compression_primary
assert_eq "primary under tools" tp "$TL_OUT"
TS_CONFIG="$TL_TMP/tsc.json" ts_call ts_shell_compression_fallback
assert_eq "fallback under tools" tf "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_shell_compression_primary
assert_eq "primary default without config" rtk "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_shell_compression_fallback
assert_eq "fallback default without config" leanctx "$TL_OUT"

ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"rtk":{"usage_ttl_seconds":100}}}'
in_dir "$repo" ts_token_usage_state_path
assert_eq "token usage path defaults to rtk" "$HOME/st/$hash/rtk-usage" "$TL_OUT"
in_dir "$repo" ts_token_usage_state_path leanctx
assert_eq "token usage path per tool" "$HOME/st/$hash/leanctx-usage" "$TL_OUT"
tl_stub date 'echo 1000'
tf="$HOME/st/$hash/rtk-usage"
rm -f "$tf"
in_dir "$repo" ts_token_usage_is_fresh
assert_eq "token usage: missing state => stale" 1 "$TL_STATUS"
echo 900 >"$tf"
in_dir "$repo" ts_token_usage_is_fresh
assert_eq "token usage: age 100 == ttl => fresh" 0 "$TL_STATUS"
echo 899 >"$tf"
in_dir "$repo" ts_token_usage_is_fresh rtk
assert_eq "token usage: age 101 => stale" 1 "$TL_STATUS"
echo 1001 >"$tf"
in_dir "$repo" ts_token_usage_is_fresh
assert_eq "token usage: future epoch => stale" 1 "$TL_STATUS"
echo bad >"$tf"
in_dir "$repo" ts_token_usage_is_fresh
assert_eq "token usage: non-numeric => stale" 1 "$TL_STATUS"
rm "$tf"; ln -s "$TL_TMP/real-mcp.json" "$tf"
in_dir "$repo" ts_token_usage_is_fresh
assert_eq "token usage: symlink => stale" 1 "$TL_STATUS"
rm "$tf"
echo 1000 >"$HOME/st/$hash/leanctx-usage"
in_dir "$repo" ts_token_usage_is_fresh leanctx
assert_eq "token usage: tool without ttl uses 1800" 0 "$TL_STATUS"
rm -f "$TL_BIN/date"

# --- rtk / context-mode probes ---
ts_call ts_rtk_cli_available
assert_eq "no rtk" 1 "$TL_STATUS"
ts_call ts_context_mode_cli_available
assert_eq "no context-mode" 1 "$TL_STATUS"
tl_stub rtk 'exit 0'; tl_stub context-mode 'exit 0'
ts_call ts_rtk_cli_available
assert_eq "rtk present" 0 "$TL_STATUS"
ts_call ts_context_mode_cli_available
assert_eq "context-mode present" 0 "$TL_STATUS"
ts_call ts_rtk_hook_present
assert_eq "no hooks.json" 1 "$TL_STATUS"
printf '{"hooks":{}}' >"$HOME/.cursor/hooks.json"
ts_call ts_rtk_hook_present
assert_eq "hooks.json without rtk" 1 "$TL_STATUS"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}' >"$HOME/.cursor/hooks.json"
ts_call ts_rtk_hook_present
assert_eq "hooks.json with rtk hook" 0 "$TL_STATUS"

# --- SB plugin cache ---
ts_call ts_sb_plugin_cache
assert_eq "no plugin cache" 1 "$TL_STATUS"
cache="$HOME/.cursor/plugins/cache/alo-labs/silver-bullet/current"
mkdir -p "$cache/hooks/lib"
ts_call ts_sb_plugin_cache
assert_eq "plugin cache path" "$cache" "$TL_OUT"

tl_results
