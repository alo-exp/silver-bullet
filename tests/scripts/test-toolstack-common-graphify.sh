#!/usr/bin/env bash
# scripts/lib/global-toolstack/common.sh: graphify helpers and the "effective"
# readers that prefer a Silver Bullet project config over the global one.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

in_dir() { # <dir> <fn> [args]: call a common.sh function with cwd=<dir>
  local d="$1"; shift
  tl_run bash -c 'cd "$1" && source "$2/common.sh" && shift 2 && "$@"' _ "$d" "$TS_SRC" "$@"
}

ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true,"graph_path":"idx/g.json","query_ttl_seconds":900,"query_budget":1234}}}'
plain="$TL_TMP/plain"
mkdir -p "$plain"
sbp="$TL_TMP/sbproj"
ts_sb_project "$sbp" '{"recommended_tools":{"graphify":{"graph_path":"sb/graph.json","query_ttl_seconds":300,"query_budget":77}}}'
mkdir -p "$sbp/src"

# --- graphify config readers ---
ts_call ts_graphify_graph_rel_path
assert_eq "graph path from config" idx/g.json "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_graphify_graph_rel_path
assert_eq "graph path default" graphify-out/graph.json "$TL_OUT"
ts_call ts_graphify_query_budget
assert_eq "budget from config" 1234 "$TL_OUT"
ts_call ts_graphify_query_ttl_seconds
assert_eq "ttl from config" 900 "$TL_OUT"
for bad in 0 abc -5; do
  printf '{"tools":{"graphify":{"query_budget":"%s","query_ttl_seconds":"%s"}}}' "$bad" "$bad" >"$TL_TMP/bad.json"
  TS_CONFIG="$TL_TMP/bad.json" ts_call ts_graphify_query_budget
  assert_eq "invalid budget '$bad' falls back" 2000 "$TL_OUT"
  TS_CONFIG="$TL_TMP/bad.json" ts_call ts_graphify_query_ttl_seconds
  assert_eq "invalid ttl '$bad' falls back" 1800 "$TL_OUT"
done
printf '{"tools":{"graphify":{"query_ttl_seconds":59}}}' >"$TL_TMP/bad.json"
TS_CONFIG="$TL_TMP/bad.json" ts_call ts_graphify_query_ttl_seconds
assert_eq "ttl below 60 falls back" 1800 "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_graphify_query_budget
assert_eq "budget without config falls back" 2000 "$TL_OUT"
TS_CONFIG="$TL_TMP/none.json" ts_call ts_graphify_query_ttl_seconds
assert_eq "ttl without config falls back" 1800 "$TL_OUT"

# --- effective readers: global config outside SB projects ---
in_dir "$plain" ts_effective_graph_path
assert_eq "effective graph path (global)" idx/g.json "$TL_OUT"
in_dir "$plain" ts_effective_query_ttl
assert_eq "effective ttl (global)" 900 "$TL_OUT"
in_dir "$plain" ts_effective_query_budget
assert_eq "effective budget (global)" 1234 "$TL_OUT"

# --- effective readers: SB project config wins ---
in_dir "$sbp/src" ts_effective_graph_path
assert_eq "effective graph path (SB)" sb/graph.json "$TL_OUT"
in_dir "$sbp/src" ts_effective_query_ttl
assert_eq "effective ttl (SB)" 300 "$TL_OUT"
in_dir "$sbp/src" ts_effective_query_budget
assert_eq "effective budget (SB)" 77 "$TL_OUT"

# --- SB config present but values missing/invalid => global values ---
sb2="$TL_TMP/sb2"
ts_sb_project "$sb2" '{"recommended_tools":{"graphify":{"query_ttl_seconds":30,"query_budget":0}}}'
in_dir "$sb2" ts_effective_graph_path
assert_eq "SB without graph_path falls back" idx/g.json "$TL_OUT"
in_dir "$sb2" ts_effective_query_ttl
assert_eq "SB ttl <60 falls back" 900 "$TL_OUT"
in_dir "$sb2" ts_effective_query_budget
assert_eq "SB budget 0 falls back" 1234 "$TL_OUT"
sb3="$TL_TMP/sb3"
ts_sb_project "$sb3" '{"recommended_tools":{"graphify":{"query_ttl_seconds":"x","query_budget":"y"}}}'
in_dir "$sb3" ts_effective_query_ttl
assert_eq "SB non-numeric ttl falls back" 900 "$TL_OUT"
in_dir "$sb3" ts_effective_query_budget
assert_eq "SB non-numeric budget falls back" 1234 "$TL_OUT"
sb4="$TL_TMP/sb4"
ts_sb_project "$sb4" 'not json'
in_dir "$sb4" ts_effective_query_ttl
assert_eq "SB unparsable config: ttl falls back" 900 "$TL_OUT"
in_dir "$sb4" ts_effective_query_budget
assert_eq "SB unparsable config: budget falls back" 1234 "$TL_OUT"

# --- ts_graphify_cli_available ---
ts_call ts_graphify_cli_available
assert_eq "no graphify anywhere" 1 "$TL_STATUS"
tl_stub graphify 'exit 0'
ts_call ts_graphify_cli_available
assert_eq "graphify on PATH" 0 "$TL_STATUS"
rm -f "$TL_BIN/graphify"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\n' >"$HOME/.local/bin/graphify"
chmod +x "$HOME/.local/bin/graphify"
ts_call ts_graphify_cli_available
assert_eq "graphify in ~/.local/bin" 0 "$TL_STATUS"
rm -f "$HOME/.local/bin/graphify"

# --- abs graph path / index exists ---
in_dir "$plain" ts_graphify_abs_graph_path
assert_eq "abs graph path defaults to PWD" "$plain/idx/g.json" "$TL_OUT"
ts_call ts_graphify_abs_graph_path "$plain/"
assert_eq "trailing slash trimmed" "$plain/idx/g.json" "$TL_OUT"
printf '{"tools":{"graphify":{"graph_path":"/abs/graph.json"}}}' >"$TL_TMP/abs.json"
TS_CONFIG="$TL_TMP/abs.json" in_dir "$plain" ts_graphify_abs_graph_path
assert_eq "absolute graph path kept" /abs/graph.json "$TL_OUT"
ts_call ts_graphify_index_exists "$plain"
assert_eq "index missing" 1 "$TL_STATUS"
mkdir -p "$plain/idx"
printf '{}' >"$plain/idx/g.json"
ts_call ts_graphify_index_exists "$plain"
assert_eq "index present" 0 "$TL_STATUS"
in_dir "$plain" ts_graphify_index_exists
assert_eq "index present (PWD default)" 0 "$TL_STATUS"
rm "$plain/idx/g.json"
printf '{}' >"$TL_TMP/real.json"
ln -s "$TL_TMP/real.json" "$plain/idx/g.json"
ts_call ts_graphify_index_exists "$plain"
assert_eq "symlinked index rejected" 1 "$TL_STATUS"

# --- query state path, epoch, freshness, record ---
repo="$TL_TMP/repo"
tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
in_dir "$repo" ts_graphify_query_state_path
assert_eq "state path under project state dir" "$HOME/st/$hash/graphify-query" "$TL_OUT"
in_dir "$sbp" ts_graphify_query_state_path
assert_eq "SB projects share the SB state file" "$HOME/.silver-bullet/graphify-query" "$TL_OUT"

sf="$TL_TMP/epoch"
ts_call ts_graphify_query_epoch "$sf"
assert_eq "epoch: missing file" 1 "$TL_STATUS"
printf '1700000000\nextra\n' >"$sf"
ts_call ts_graphify_query_epoch "$sf"
assert_eq "epoch: first line" 1700000000 "$TL_OUT"
printf 'abc\n' >"$sf"
ts_call ts_graphify_query_epoch "$sf"
assert_eq "epoch: non-numeric" 1 "$TL_STATUS"
rm -f "$sf"; ln -s "$TL_TMP/real.json" "$sf"
ts_call ts_graphify_query_epoch "$sf"
assert_eq "epoch: symlink rejected" 1 "$TL_STATUS"
ts_call ts_graphify_query_epoch
assert_eq "epoch: no argument" 1 "$TL_STATUS"

# freshness uses date; pin it
tl_stub date 'echo 10000'
statef="$HOME/st/$hash/graphify-query"
in_dir "$repo" ts_graphify_query_is_fresh
assert_eq "no state => stale" 1 "$TL_STATUS"
mkdir -p "$(dirname "$statef")"
echo 9500 >"$statef"
in_dir "$repo" ts_graphify_query_is_fresh
assert_eq "age 500 <= ttl 900 => fresh" 0 "$TL_STATUS"
echo 9100 >"$statef"
in_dir "$repo" ts_graphify_query_is_fresh
assert_eq "age 900 == ttl => fresh" 0 "$TL_STATUS"
echo 9099 >"$statef"
in_dir "$repo" ts_graphify_query_is_fresh
assert_eq "age 901 > ttl => stale" 1 "$TL_STATUS"
echo 10001 >"$statef"
in_dir "$repo" ts_graphify_query_is_fresh
assert_eq "future epoch => stale" 1 "$TL_STATUS"
rm -f "$statef"
in_dir "$repo" ts_graphify_record_query
assert_eq "record query ok" 0 "$TL_STATUS"
assert_eq "record writes current epoch" 10000 "$(cat "$statef")"
# unwritable state path: make the state dir a file
rm -rf "$HOME/st"
printf 'x' >"$HOME/st"
in_dir "$repo" ts_graphify_record_query
assert_eq "record fails when state dir cannot be created" 1 "$TL_STATUS"
rm -f "$HOME/st"
rm -f "$TL_BIN/date"

# --- command classification ---
for c in 'graphify query "x"' '/usr/bin/graphify explain foo' 'graphifyy path a b' 'graphify dfs a' 'graphify affected f' 'graphify diagnose'; do
  ts_call ts_graphify_command_is_retrieval "$c"
  assert_eq "retrieval: $c" 0 "$TL_STATUS"
done
for c in '' 'graphify update .' 'echo query' 'xgraphify query'; do
  ts_call ts_graphify_command_is_retrieval "$c"
  assert_eq "not retrieval: '$c'" 1 "$TL_STATUS"
done
for c in 'graphify update .' 'graphify extract x' 'graphify watch'; do
  ts_call ts_graphify_command_is_index_build "$c"
  assert_eq "index build: $c" 0 "$TL_STATUS"
done
for c in '' 'graphify query x' 'echo update'; do
  ts_call ts_graphify_command_is_index_build "$c"
  assert_eq "not index build: '$c'" 1 "$TL_STATUS"
done
for c in '' 'graphify query x' 'graphify update .' 'graphify hook install' 'cat file' 'git status' 'git diff HEAD' 'echo hi' 'ls' 'command -v graphify'; do
  ts_call ts_graphify_command_is_exempt "$c"
  assert_eq "exempt: '$c'" 0 "$TL_STATUS"
done
for c in 'make build' 'rm -rf x' 'npm test'; do
  ts_call ts_graphify_command_is_exempt "$c"
  assert_eq "not exempt: $c" 1 "$TL_STATUS"
done

# --- edit path exemptions ---
for p in graphify-out/graph.json /r/graphify-out/x idx/y /r/idx/y /r/.silver-bullet/state .silver-bullet/state; do
  ts_call ts_graphify_edit_path_is_exempt "$p"
  assert_eq "edit exempt: $p" 0 "$TL_STATUS"
done
for p in "" /r/src/a.py other/z; do
  ts_call ts_graphify_edit_path_is_exempt "$p"
  assert_eq "edit not exempt: '$p'" 1 "$TL_STATUS"
done

# --- bootstrap flag ---
ts_call ts_graphify_bootstrap_enabled
assert_eq "bootstrap off by default" 1 "$TL_STATUS"
printf '{"worktree":{"bootstrap_graphify":true}}' >"$TL_TMP/bs.json"
TS_CONFIG="$TL_TMP/bs.json" ts_call ts_graphify_bootstrap_enabled
assert_eq "bootstrap on" 0 "$TL_STATUS"

# --- stale-query message ---
in_dir "$sbp" ts_graphify_block_message_stale_query
assert_contains "message names SB graph path" "$TL_OUT" '--graph sb/graph.json --budget 77'
assert_contains "message names ttl" "$TL_OUT" 'A fresh query is required every 300s.'
assert_contains "message headline" "$TL_OUT" 'GRAPHIFY QUERY REQUIRED'

tl_results
