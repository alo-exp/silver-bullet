#!/usr/bin/env bash
# Behavior tests for hooks/lib/graphify-gate.sh (graphify CLI is stubbed)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME

LIBF="$TL_REPO_ROOT/hooks/lib/graphify-gate.sh"
# shellcheck source=../../hooks/lib/graphify-gate.sh
source "$LIBF"
# shellcheck source=../../hooks/lib/nofollow-guard.sh
source "$TL_REPO_ROOT/hooks/lib/nofollow-guard.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
PR="$TL_TMP/proj"; mkdir -p "$PR"

# ---------- graph path / ttl ----------
assert_eq "graph path default" "graphify-out/graph.json" "$(sb_graphify_graph_rel_path)"
w '{"recommended_tools":{"graphify":{"graph_path":"g/graph.json","query_ttl_seconds":120}}}'
assert_eq "graph path from recommended_tools" "g/graph.json" "$(sb_graphify_graph_rel_path "$CFG")"
assert_eq "ttl from recommended_tools" "120" "$(sb_graphify_query_ttl_seconds "$CFG")"
w '{"graphify":{"graph_path":"legacy/graph.json","query_ttl_seconds":300}}'
assert_eq "graph path legacy key" "legacy/graph.json" "$(sb_graphify_graph_rel_path "$CFG")"
assert_eq "ttl legacy key" "300" "$(sb_graphify_query_ttl_seconds "$CFG")"
w '{}'
assert_eq "graph path default for empty config" "graphify-out/graph.json" "$(sb_graphify_graph_rel_path "$CFG")"
assert_eq "ttl default" "1800" "$(sb_graphify_query_ttl_seconds "$CFG")"
assert_eq "ttl default without config" "1800" "$(sb_graphify_query_ttl_seconds)"
w 'garbage'
assert_eq "graph path default on invalid json" "graphify-out/graph.json" "$(sb_graphify_graph_rel_path "$CFG")"
assert_eq "ttl default on invalid json" "1800" "$(sb_graphify_query_ttl_seconds "$CFG")"
w '{"graphify":{"query_ttl_seconds":30}}'
assert_eq "ttl below floor" "1800" "$(sb_graphify_query_ttl_seconds "$CFG")"
w '{"graphify":{"query_ttl_seconds":"abc"}}'
assert_eq "ttl non numeric" "1800" "$(sb_graphify_query_ttl_seconds "$CFG")"

# ---------- cli path ----------
PATH_NO_G="$(tl_path_without graphify)"
no_t "cli_path none" env PATH="$PATH_NO_G" bash -c 'source "$1"; sb_graphify_cli_path' _ "$LIBF"
no_t "cli_available none" env PATH="$PATH_NO_G" bash -c 'source "$1"; sb_graphify_cli_available' _ "$LIBF"
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' >"$HOME/.local/bin/graphify"; chmod +x "$HOME/.local/bin/graphify"
assert_eq "cli_path from ~/.local/bin" "$HOME/.local/bin/graphify" "$(PATH="$PATH_NO_G" sb_graphify_cli_path)"
rm -f "$HOME/.local/bin/graphify"
tl_stub graphify 'exit 0'; hash -r
assert_eq "cli_path from PATH" "$TL_BIN/graphify" "$(sb_graphify_cli_path)"
yes_t "cli_available" sb_graphify_cli_available
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
GBIN="$TL_TMP/global/graphify"; mkdir -p "$TL_TMP/global"; printf '#!/bin/sh\n' >"$GBIN"; chmod +x "$GBIN"
jq -n --arg c "$GBIN" '{tools:{graphify:{command:$c}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path from manifest absolute" "$GBIN" "$(sb_graphify_cli_path)"
jq -n '{tools:{graphify:{command:"/nonexistent/dir/graphify"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
no_t "cli_path manifest absolute missing fails closed" sb_graphify_cli_path
jq -n '{tools:{graphify:{command:"graphify"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path manifest bare name via PATH" "$TL_BIN/graphify" "$(sb_graphify_cli_path)"
jq -n '{tools:{graphify:{command:"nonexistent-graphify-bin-zz"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path manifest other basename falls through to PATH" "$TL_BIN/graphify" "$(sb_graphify_cli_path)"
jq -n '{tools:{graphify:{command:"/opt/other-tool"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path ignores manifest command with other basename" "$TL_BIN/graphify" "$(sb_graphify_cli_path)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST
# manifest bare name that is not on PATH: command -v fails and its status is returned
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest2.json"
jq -n '{tools:{graphify:{command:"graphify"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
no_t "cli_path manifest bare name missing from PATH" env PATH="$PATH_NO_G" bash -c 'source "$1"; sb_graphify_cli_path' _ "$LIBF"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

# ---------- index paths ----------
w '{}'
assert_eq "abs graph path default" "$PR/graphify-out/graph.json" "$(sb_graphify_abs_graph_path "$PR/" "$CFG")"
assert_eq "abs graph path default project is PWD" "$PR/graphify-out/graph.json" "$(cd "$PR" && sb_graphify_abs_graph_path)"
w '{"recommended_tools":{"graphify":{"graph_path":"/abs/graph.json"}}}'
assert_eq "abs graph path absolute rel" "/abs/graph.json" "$(sb_graphify_abs_graph_path "$PR" "$CFG")"
w '{}'
no_t "index missing" sb_graphify_index_exists "$PR" "$CFG"
mkdir -p "$PR/graphify-out"; : >"$PR/graphify-out/graph.json"
yes_t "index exists" sb_graphify_index_exists "$PR" "$CFG"
yes_t "index exists default project" bash -c 'cd "$1" && source "$2" && sb_graphify_index_exists' _ "$PR" "$LIBF"
rm "$PR/graphify-out/graph.json"; ln -s "$TL_TMP/tgt" "$PR/graphify-out/graph.json"; : >"$TL_TMP/tgt"
no_t "index symlink rejected" sb_graphify_index_exists "$PR" "$CFG"
rm "$PR/graphify-out/graph.json"

# ---------- query state ----------
DEF="$SB_RUNTIME_STATE_DIR/graphify-query"
assert_eq "state path default no config" "$DEF" "$(sb_graphify_query_state_path)"
w '{}'
assert_eq "state path default empty config" "$DEF" "$(sb_graphify_query_state_path "$CFG")"
w "{\"recommended_tools\":{\"graphify\":{\"query_state_file\":\"$SB_RUNTIME_STATE_DIR/q-custom\"}}}"
assert_eq "state path configured" "$SB_RUNTIME_STATE_DIR/q-custom" "$(sb_graphify_query_state_path "$CFG")"
w "{\"graphify\":{\"query_state_file\":\"$SB_RUNTIME_STATE_DIR/q-legacy\"}}"
assert_eq "state path legacy key" "$SB_RUNTIME_STATE_DIR/q-legacy" "$(sb_graphify_query_state_path "$CFG")"
w '{"graphify":{"query_state_file":"/tmp/escape/q"}}'
assert_eq "state path outside state scope rejected" "$DEF" "$(sb_graphify_query_state_path "$CFG")"
w '{"graphify":{"query_state_file":"~/escape"}}'
assert_eq "state path ~ outside scope rejected" "$DEF" "$(sb_graphify_query_state_path "$CFG")"
w 'garbage'
assert_eq "state path invalid json default" "$DEF" "$(sb_graphify_query_state_path "$CFG")"
assert_eq "state path without scope helper accepts any" "/tmp/anywhere/q" "$(w '{"graphify":{"query_state_file":"/tmp/anywhere/q"}}'; env bash -c 'source "$1"; unset -f sb_runtime_path_is_state_scoped; sb_graphify_query_state_path "$2"' _ "$LIBF" "$CFG")"
assert_eq "state path default without runtime dir" "$HOME/.silver-bullet/graphify-query" "$(env -u SB_RUNTIME_STATE_DIR bash -c 'source "$1"; unset -f sb_runtime_path_is_state_scoped; sb_graphify_query_state_path' _ "$LIBF")"

Q="$DEF"
w '{}'
no_t "epoch missing" sb_graphify_query_epoch "$Q"
printf 'x\n' >"$Q"; no_t "epoch non-numeric" sb_graphify_query_epoch "$Q"
printf '42\nextra\n' >"$Q"; assert_eq "epoch first line" "42" "$(sb_graphify_query_epoch "$Q")"
tl_stub sed 'exit 1'; hash -r
no_t "epoch unreadable" sb_graphify_query_epoch "$Q"
rm -f "$TL_BIN/sed"; hash -r
rm -f "$Q"; ln -s "$TL_TMP/tgt" "$Q"; printf '9\n' >"$TL_TMP/tgt"
no_t "epoch symlink refused" sb_graphify_query_epoch "$Q"
rm -f "$Q"

no_t "not fresh without state" sb_graphify_query_is_fresh "$CFG"
tl_stub date 'echo 10000'; hash -r
printf '9000\n' >"$Q"; yes_t "fresh" sb_graphify_query_is_fresh "$CFG"
printf '8200\n' >"$Q"; yes_t "fresh at boundary" sb_graphify_query_is_fresh "$CFG"
printf '8199\n' >"$Q"; no_t "stale" sb_graphify_query_is_fresh "$CFG"
printf '11000\n' >"$Q"; no_t "future not fresh" sb_graphify_query_is_fresh "$CFG"
rm -f "$Q"
sb_graphify_record_query "$CFG"
assert_eq "record writes epoch" "10000" "$(cat "$Q")"
sb_graphify_clear_query_state "$CFG"
assert_file_absent "clear removes" "$Q"
sb_graphify_clear_query_state "$CFG"; tl_pass "clear idempotent"
mkdir -p "$Q/child"; sb_graphify_clear_query_state "$CFG"
assert_eq "clear tolerates rm failure" "yes" "$([[ -d "$Q/child" ]] && echo yes || echo no)"; rm -rf "$Q"
mkdir -p "$Q"; no_t "record fails when path is a directory" sb_graphify_record_query "$CFG"; rmdir "$Q"
( ln -s "$TL_TMP/tgt" "$Q"; sb_graphify_record_query "$CFG" ) 2>"$TL_TMP/err" && tl_fail "record refuses symlink" || tl_pass "record refuses symlink"
assert_contains "symlink refusal message" "$(cat "$TL_TMP/err")" "refusing to write through symlink"
rm -f "$Q"
( unset -f sb_guard_nofollow; sb_graphify_record_query "$CFG" ) && tl_pass "record without nofollow helper" || tl_fail "record without nofollow helper"
assert_eq "record without helper wrote epoch" "10000" "$(cat "$Q")"
rm -f "$Q" "$TL_BIN/date"; hash -r
BADF="$TL_TMP/badfile"; printf x >"$BADF"
(
  sb_graphify_query_state_path() { printf '%s/sub/q' "$BADF"; }
  sb_graphify_record_query "$CFG" && exit 1
  exit 0
) && tl_pass "record fails when parent cannot be created" || tl_fail "record fails when parent cannot be created"

# ---------- command classification ----------
no_t "retrieval empty" sb_graphify_command_is_retrieval ""
for c in "graphify query foo" "graphify explain x" "uvx graphifyy path A B" "/usr/bin/graphify affected f" "graphify diagnose" "graphify dfs a"; do
  yes_t "retrieval: $c" sb_graphify_command_is_retrieval "$c"
done
no_t "retrieval: update is not retrieval" sb_graphify_command_is_retrieval "graphify update ."
no_t "retrieval: other tool" sb_graphify_command_is_retrieval "grep query"
no_t "index_build empty" sb_graphify_command_is_index_build ""
for c in "graphify update ." "graphify extract f" "graphify watch"; do yes_t "index build: $c" sb_graphify_command_is_index_build "$c"; done
no_t "index build: query" sb_graphify_command_is_index_build "graphify query x"
no_t "index build: other tool" sb_graphify_command_is_index_build "make update"
yes_t "exempt empty" sb_graphify_command_is_exempt ""
yes_t "exempt retrieval" sb_graphify_command_is_exempt "graphify query a"
yes_t "exempt index build" sb_graphify_command_is_exempt "graphify update ."
yes_t "exempt bare graphify" sb_graphify_command_is_exempt "graphify --help"
for c in "cat f" "ls -la" "git status" "git diff HEAD" "echo hi" "jq . f" "pwd"; do yes_t "exempt read-only: $c" sb_graphify_command_is_exempt "$c"; done
no_t "not exempt commit" sb_graphify_command_is_exempt "git commit -m x"
no_t "not exempt writer" sb_graphify_command_is_exempt "cp a b"

# ---------- edit exemptions ----------
w '{}'
no_t "edit exempt empty" sb_graphify_edit_path_is_exempt ""
yes_t "edit exempt graphify-out abs" sb_graphify_edit_path_is_exempt "/p/graphify-out/graph.json" "$CFG"
yes_t "edit exempt graphify-out rel" sb_graphify_edit_path_is_exempt "graphify-out/x" "$CFG"
w '{"recommended_tools":{"graphify":{"graph_path":"idx/graph.json"}}}'
yes_t "edit exempt custom graph dir abs" sb_graphify_edit_path_is_exempt "/p/idx/graph.json" "$CFG"
yes_t "edit exempt custom graph dir rel" sb_graphify_edit_path_is_exempt "idx/a" "$CFG"
yes_t "edit exempt state dir" sb_graphify_edit_path_is_exempt "/p/.silver-bullet/state" "$CFG"
no_t "edit not exempt" sb_graphify_edit_path_is_exempt "/p/src/a.py" "$CFG"

# ---------- messages ----------
m="$(SILVER_BULLET_RUNTIME=claude sb_graphify_block_message_no_cli "$CFG")"
assert_contains "no_cli header" "$m" "GRAPHIFY REQUIRED"
assert_contains "no_cli install lines" "$m" "uv tool install 'graphifyy[mcp]'"
(
  # install-line helper yields nothing: message builds its own default list
  sb_recommended_tool_full_install_lines() { return 0; }
  m="$(SILVER_BULLET_RUNTIME=claude sb_graphify_block_message_no_cli "$CFG")"
  [[ "$m" == *"uv tool install graphifyy"* && "$m" == *"graphify install --project"* && "$m" == *"graphify update . --no-cluster"* && "$m" == *"graphify claude install --project"* ]] || { echo "$m"; exit 1; }
  # host with no pre/post commands (opencode)
  m="$(SILVER_BULLET_RUNTIME=opencode sb_graphify_block_message_no_cli "$CFG")"
  [[ "$m" == *"pipx install graphifyy"* && "$m" == *"graphify update . --no-cluster"* ]] || exit 2
  exit 0
) && tl_pass "no_cli builds fallback install list" || tl_fail "no_cli builds fallback install list (exit $?)"
(
  sb_recommended_tool_full_install_lines() { return 1; }
  sb_recommended_tool_platform_pre_index_commands() { return 1; }
  sb_recommended_tool_platform_post_index_commands() { return 1; }
  m="$(SILVER_BULLET_RUNTIME=claude sb_graphify_block_message_no_cli "$CFG")"
  [[ "$m" == *"pipx install graphifyy"* && "$m" == *"graphify update . --no-cluster"* ]]
) && tl_pass "no_cli survives helper failures" || tl_fail "no_cli survives helper failures"
m="$(sb_graphify_block_message_no_index "idx/graph.json")"
assert_contains "no_index header" "$m" "GRAPHIFY INDEX MISSING"
assert_contains "no_index path" "$m" "Expected index: idx/graph.json"
assert_contains "no_index default path" "$(sb_graphify_block_message_no_index)" "Expected index: graphify-out/graph.json"
m="$(sb_graphify_block_message_stale_query "idx/graph.json" 77)"
assert_contains "stale header" "$m" "GRAPHIFY QUERY REQUIRED"
assert_contains "stale graph arg" "$m" "--graph idx/graph.json"
assert_contains "stale ttl" "$m" "every 77s"
assert_contains "stale defaults" "$(sb_graphify_block_message_stale_query)" "--graph graphify-out/graph.json"

# ---------- prompt reminder ----------
RC="$PR/.silver-bullet.json"
rem() { sb_graphify_prompt_reminder_line "$RC"; }
printf '{}' >"$RC"; assert_contains "reminder pending" "$(rem)" "consent pending"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":false}}}' >"$RC"; assert_contains "reminder disabled" "$(rem)" "opted out"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true,"enforcement_suspended":true}}}' >"$RC"; assert_contains "reminder suspended" "$(rem)" "enforcement suspended"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$RC"
rm -f "$TL_BIN/graphify"; hash -r
assert_contains "reminder cli missing" "$(PATH="$PATH_NO_G" rem)" "CLI missing"
tl_stub graphify 'exit 0'; hash -r
assert_contains "reminder index missing" "$(rem)" "index missing"
assert_contains "reminder index path" "$(rem)" "graphify-out/graph.json"
: >"$PR/graphify-out/graph.json"
tl_stub date 'echo 10000'; hash -r
assert_contains "reminder query required" "$(rem)" "QUERY REQUIRED"
assert_contains "reminder query ttl" "$(rem)" "TTL 1800s"
printf '9500\n' >"$Q"
assert_contains "reminder fresh" "$(rem)" "fresh query recorded"
rm -f "$Q" "$TL_BIN/date"; hash -r

tl_results
