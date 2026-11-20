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
ts_sb_bridge "$TL_TMP/sbroot"
hbdir="$TL_TMP/sbroot/scripts/lib/recommended-tools"
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

# --- ts_token_usage_record: atomic stamp, every failure reported (R6-08) ---
rec="$TL_TMP/recrepo"; tl_git_repo "$rec"
rechash="$(printf '%s' "$rec" | sha256sum | awk '{print substr($1,1,16)}')"
rm -rf "$HOME/st"
in_dir "$rec" ts_token_usage_record rtk
assert_eq "usage record: ok" 0 "$TL_STATUS"
assert_match "usage record holds an epoch" '^[0-9]+$' "$(cat "$HOME/st/$rechash/rtk-usage")"
in_dir "$rec" ts_token_usage_is_fresh rtk
assert_eq "a recorded usage is fresh" 0 "$TL_STATUS"
# a symlink planted at the stamp is replaced, never written through
echo precious >"$TL_TMP/victim"
rm -f "$HOME/st/$rechash/rtk-usage"; ln -s "$TL_TMP/victim" "$HOME/st/$rechash/rtk-usage"
in_dir "$rec" ts_token_usage_record rtk
assert_eq "usage record over a symlink: ok" 0 "$TL_STATUS"
assert_eq "the symlink target is untouched" precious "$(cat "$TL_TMP/victim")"
assert_eq "the stamp is a regular file again" "no" "$([[ -L "$HOME/st/$rechash/rtk-usage" ]] && echo yes || echo no)"
# failures
rm -rf "$HOME/st"; mkdir -p "$HOME"; printf 'file\n' >"$HOME/st"
in_dir "$rec" ts_token_usage_record rtk
assert_eq "state dir that cannot be created: fails" 1 "$TL_STATUS"
rm -f "$HOME/st"; mkdir -p "$HOME/st/$rechash"
tl_stub mktemp 'exit 1'
in_dir "$rec" ts_token_usage_record rtk
assert_eq "mktemp failing: fails" 1 "$TL_STATUS"
rm -f "$TL_BIN/mktemp"
tl_stub mv 'exit 1'
in_dir "$rec" ts_token_usage_record rtk
assert_eq "rename failing: fails" 1 "$TL_STATUS"
assert_eq "no temp file is left behind" "" "$(ls -A "$HOME/st/$rechash")"
rm -f "$TL_BIN/mv"
tl_stub date 'exit 1'
in_dir "$rec" ts_token_usage_record rtk
assert_eq "clock failing: fails" 1 "$TL_STATUS"
rm -f "$TL_BIN/date"

tl_results
