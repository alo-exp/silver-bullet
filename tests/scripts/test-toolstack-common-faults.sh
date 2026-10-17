#!/usr/bin/env bash
# scripts/lib/global-toolstack/common.sh: failure-injection paths (tools that
# fail, unparsable SB config, missing hashing tools, failing heartbeat helpers).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

in_dir() { # <dir> <fn> [args]
  local d="$1"; shift
  tl_run bash -c 'cd "$1" && source "$2/common.sh" && shift 2 && "$@"' _ "$d" "$TS_SRC" "$@"
}

ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true,"graph_path":"g/x.json"},"agentmemory":{"export_root":"gmem","health_url":"http://g/h"},"rtk":{}}}'

# --- unparsable SB config: every effective reader falls back to the global value ---
bad="$TL_TMP/badsb"
ts_sb_project "$bad" 'not json at all'
in_dir "$bad" ts_effective_graph_path
assert_eq "bad SB config: graph path falls back" g/x.json "$TL_OUT"
in_dir "$bad" ts_effective_export_root
assert_eq "bad SB config: export root falls back" gmem "$TL_OUT"
in_dir "$bad" ts_effective_health_url
assert_eq "bad SB config: health url falls back" http://g/h "$TL_OUT"

# --- git root of a directory that does not exist falls back to the raw value ---
ts_call ts_git_root "$TL_TMP/missing/dir"
assert_eq "git root of missing dir: not found" 1 "$TL_STATUS"

# --- no shasum: sha256sum is used ---
want="$(printf '%s' /r | sha256sum | awk '{print substr($1,1,16)}')"
PATH="$(tl_path_without shasum)" ts_call ts_project_hash /r
assert_eq "sha256sum fallback when shasum missing" "$want" "$TL_OUT"

# --- both absolute and relative export roots in one process ---
printf '{"tools":{"agentmemory":{"export_root":"/abs/e"}}}' >"$TL_TMP/abs.json"
printf '{"tools":{"agentmemory":{"export_root":"rel/e"}}}' >"$TL_TMP/rel.json"
tl_run bash -c 'cd "$HOME"; source "$3/common.sh"; TS_CONFIG="$1" ts_agentmemory_abs_export_path /w; echo; TS_CONFIG="$2" ts_agentmemory_abs_export_path /w/' _ "$TL_TMP/abs.json" "$TL_TMP/rel.json" "$TS_SRC"
assert_eq "abs then rel export path" $'/abs/e\n/w/rel/e' "$TL_OUT"

# --- sed failing: epoch readers treat the state as unreadable ---
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
mkdir -p "$HOME/st/$hash"
echo 100 >"$HOME/st/$hash/graphify-query"
echo 100 >"$HOME/st/$hash/agentmemory-usage"
echo 100 >"$HOME/st/$hash/rtk-usage"
tl_stub sed 'exit 1'
ts_call ts_graphify_query_epoch "$HOME/st/$hash/graphify-query"
assert_eq "graphify epoch: sed failure" 1 "$TL_STATUS"
ts_call ts_agentmemory_usage_epoch "$HOME/st/$hash/agentmemory-usage"
assert_eq "usage epoch: sed failure" 1 "$TL_STATUS"
in_dir "$repo" ts_token_usage_is_fresh rtk
assert_eq "token usage: sed failure => stale" 1 "$TL_STATUS"
rm -f "$TL_BIN/sed"

# --- token usage without a config: default ttl 1800 applies ---
tl_stub date 'echo 2000'
mkdir -p "$HOME/.cursor/state/toolstack/$hash"
echo 1000 >"$HOME/.cursor/state/toolstack/$hash/rtk-usage"
TS_CONFIG="$TL_TMP/none.json" in_dir "$repo" ts_token_usage_is_fresh rtk
assert_eq "no config: default ttl 1800 keeps 1000s-old usage fresh" 0 "$TL_STATUS"
echo 100 >"$HOME/.cursor/state/toolstack/$hash/rtk-usage"
TS_CONFIG="$TL_TMP/none.json" in_dir "$repo" ts_token_usage_is_fresh rtk
assert_eq "no config: default ttl 1800 expires 1900s-old usage" 1 "$TL_STATUS"
rm -f "$TL_BIN/date"

# --- heartbeat helpers that fail ---
proj="$TL_TMP/hbproj"
ts_sb_project "$proj"
hbdir="$proj/scripts/lib/recommended-tools"
mkdir -p "$hbdir"
cat >"$hbdir/heartbeat.sh" <<'HB'
rt_project_id() { return 1; }
rt_worktree_id() { return 1; }
rt_current_session_id() { return 1; }
rt_heartbeat_path() { echo "args:[$1][$2][$3]"; }
rt_heartbeat_is_valid() { echo "$1" >"$HB_OUT"; return 1; }
HB
export HB_OUT="$TL_TMP/hb-out"
in_dir "$proj" ts_sb_defer_to_bridge
assert_eq "failing id helpers => no defer" 1 "$TL_STATUS"
assert_eq "empty ids still reach path helper" "args:[][][]" "$(cat "$HB_OUT")"
# heartbeat path helper that fails
cat >"$hbdir/heartbeat.sh" <<'HB'
rt_project_id() { echo p; }
rt_worktree_id() { echo w; }
rt_current_session_id() { echo s; }
rt_heartbeat_path() { return 1; }
rt_heartbeat_is_valid() { echo called >"$HB_OUT"; return 0; }
HB
rm -f "$HB_OUT"
in_dir "$proj" ts_sb_defer_to_bridge
assert_eq "failing heartbeat path helper => no defer" 1 "$TL_STATUS"
assert_file_absent "validity check skipped without a heartbeat path" "$HB_OUT"
# heartbeat lib that fails to load entirely
printf 'return 1\n' >"$hbdir/heartbeat.sh"
in_dir "$proj" ts_sb_defer_to_bridge
assert_eq "heartbeat lib that fails to load => no defer" 1 "$TL_STATUS"

tl_results
