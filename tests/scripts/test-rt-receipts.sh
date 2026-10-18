#!/usr/bin/env bash
# scripts/lib/recommended-tools/receipts.sh: reload receipt lifecycle, host
# evidence attestation and the host convergence batches. Patchers are logging
# stubs in a staged repo; all state lives in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"  # never run with the checkout as cwd: stubs and relative writes stay in the sandbox

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/receipts.sh"
rt_init_paths
export RT_HOST=cursor
hr_consent graphify=enabled agentmemory=enabled rtk=enabled context_mode=enabled leanctx=enabled
hr_bin sleep 'exit 0'
mkdir -p "$HOME/.cursor"

# ------------------------------------------------------------------ helpers
assert_eq "string array: empty" "[]" "$(rt_json_string_array)"
assert_eq "string array: values, blanks dropped" '["a","b c"]' "$(rt_json_string_array a "" "b c" | jq -c .)"

F="$TL_TMP/cfg.json"; printf '{"a":1}\n' >"$F"
HASH="$(sha256sum "$F" | awk '{print $1}')"
assert_eq "config hash" "$HASH" "$(rt_config_hash_file "$F")"
assert_eq "config hash without shasum" "$HASH" "$(PATH="$(hr_path_without shasum)" rt_config_hash_file "$F")"
assert_eq "config hash: missing file" "" "$(rt_config_hash_file "$TL_TMP/none")"
ln -s "$F" "$TL_TMP/cfg-link.json"
assert_eq "config hash: symlink refused" "" "$(rt_config_hash_file "$TL_TMP/cfg-link.json")"
assert_eq "current hashes (no files)" '{"mcp":"","hooks":""}' "$(rt_current_config_hashes | jq -c .)"
echo '{}' >"$HOME/.cursor/mcp.json"; echo '{"x":1}' >"$HOME/.cursor/hooks.json"
assert_eq "current hashes (files)" "$(rt_config_hash_file "$HOME/.cursor/mcp.json")|$(rt_config_hash_file "$HOME/.cursor/hooks.json")" \
  "$(rt_current_config_hashes | jq -r '"\(.mcp)|\(.hooks)"')"

assert_eq "patcher unchanged: empty output" "1" "$(rc_of rt_patcher_output_unchanged "")"
assert_eq "patcher unchanged: 'unchanged'" "0" "$(rc_of rt_patcher_output_unchanged "mcp.json unchanged")"
assert_eq "patcher unchanged: '(0 changes)'" "0" "$(rc_of rt_patcher_output_unchanged "done (0 changes)")"
assert_eq "patcher unchanged: ': 0 change(s)'" "0" "$(rc_of rt_patcher_output_unchanged "x: 0 change(s)")"
assert_eq "patcher unchanged: changed" "1" "$(rc_of rt_patcher_output_unchanged "patched 2 servers")"
assert_eq "hash changed: empty -> value" "0" "$(rc_of rt_config_hash_changed "" abc)"
assert_eq "hash changed: value -> other" "0" "$(rc_of rt_config_hash_changed abc def)"
assert_eq "hash changed: same" "1" "$(rc_of rt_config_hash_changed abc abc)"
assert_eq "hash changed: value -> empty" "1" "$(rc_of rt_config_hash_changed abc "")"
assert_eq "hash changed: both empty" "1" "$(rc_of rt_config_hash_changed "" "")"

hr_bin uuidgen 'echo "ABCD-1234"'
assert_eq "random id via uuidgen (lowercased)" "abcd-1234" "$(rt_receipt_random_id)"
NOUU="$(hr_path_without uuidgen)"
assert_match "random id fallback" '^rt-[0-9]+-[0-9a-f]{16}$' "$(PATH="$NOUU" rt_receipt_random_id)"
assert_match "random id fallback without od" '^rt-[0-9]+-' "$(hr_bin od 'exit 1'; PATH="$(hr_path_without uuidgen)" rt_receipt_random_id; hr_nobin od)"
hr_bin openssl 'echo deadbeef'
assert_eq "nonce via openssl" "deadbeef" "$(rt_receipt_random_nonce)"
assert_match "nonce fallback" '^[0-9a-f]{32}$' "$(PATH="$(hr_path_without openssl)" rt_receipt_random_nonce)"
assert_match "nonce fallback when od fails" '^nonce-[0-9]+$' "$(hr_bin od 'exit 1'; PATH="$(hr_path_without openssl)" rt_receipt_random_nonce; hr_nobin od)"
hr_nobin openssl; hr_nobin uuidgen
assert_eq "expected tools" '{"graphify":["query_graph","get_node","graph_stats"],"agentmemory":["memory_save","memory_recall"],"leanctx":["ctx_compose","ctx_read","ctx_search"],"context-mode":["ctx_execute","ctx_search"]}' \
  "$(rt_receipt_expected_tools_json '["graphify","agentmemory","leanctx","context-mode","rtk"]' | jq -c .)"
assert_eq "expected tools: default" "{}" "$(rt_receipt_expected_tools_json | jq -c .)"

# --------------------------------------------------------------- create
export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all RT_PROJECT_ROOT="$HR_PROJ"
PID="$(rt_project_id)"; WID="$(rt_worktree_id "$HR_PROJ")"
RT_MODE=verify
assert_eq "create: verify mode refused" "1" "$(rc_of rt_receipt_create project init '[]' true)"
export RT_MODE=apply RT_ENTRY_POINT=bogus
assert_eq "create: bad entry point refused" "1" "$(rc_of rt_receipt_create project init '[]' true)"
export RT_ENTRY_POINT=init
assert_eq "create: no restart needed -> no receipt" "" "$(rt_receipt_create project init '[]' false)"
assert_eq "receipts dir still empty" "" "$(rt_receipt_list_paths cursor "$PID" "$WID")"

export RT_CHANGE_SET_ID=cs-1 RT_PRE_CONFIG_HASHES='{"mcp":"old","hooks":"old"}'
R1="$(rt_receipt_create project init '["graphify"]' true)"
unset RT_CHANGE_SET_ID RT_PRE_CONFIG_HASHES
assert_eq "receipt schema" "v1|project|cs-1|cursor" "$(jq -r '"\(.schema)|\(.scope)|\(.change_set_id)|\(.identities.host)"' <<<"$R1")"
assert_eq "receipt identities" "$PID|$WID|$HR_PROJ" "$(jq -r '"\(.identities.project_id)|\(.identities.worktree_id)|\(.identities.project_root)"' <<<"$R1")"
assert_eq "receipt pre hashes taken from the caller" "old" "$(jq -r .pre_config_hashes.mcp <<<"$R1")"
assert_eq "receipt expected tools" '["query_graph","get_node","graph_stats"]' "$(jq -c .expected_tools.graphify <<<"$R1")"
assert_eq "receipt state" "none|null|null" "$(jq -r '"\(.activation_status)|\(.consumed_at)|\(.superseded_at)"' <<<"$R1")"
RID1="$(jq -r .receipt_id <<<"$R1")"
assert_file_exists "receipt persisted" "$(rt_reload_receipt_path cursor "$PID" "$WID" "$RID1")"
assert_eq "receipt read back" "$RID1" "$(rt_receipt_read "$(rt_reload_receipt_path cursor "$PID" "$WID" "$RID1")" | jq -r .receipt_id)"
assert_eq "receipt read: missing" "1" "$(rc_of rt_receipt_read "$TL_TMP/none")"
assert_eq "active receipt found" "$RID1" "$(rt_receipt_find_active cursor "$PID" "$WID" | jq -r .receipt_id)"

# persisting failure must not be reported as success (callers use the status)
BLOCK_STATE="$TL_TMP/blocked-state"; mkdir -p "$BLOCK_STATE"; printf 'file\n' >"$BLOCK_STATE/recommended-tools"
create_rc=0
if (export SB_RUNTIME_STATE_DIR="$BLOCK_STATE"; rt_receipt_create project init '[]' true >/dev/null 2>&1); then create_rc=0; else create_rc=1; fi
assert_eq "create: unwritable receipt store fails (if-context)" "1" "$create_rc"
# a newer change set supersedes the old one; the same change set does not
export RT_CHANGE_SET_ID=cs-2
R2="$(rt_receipt_create project init '[]' true)"
unset RT_CHANGE_SET_ID
RID2="$(jq -r .receipt_id <<<"$R2")"
assert_eq "older receipt superseded" "1" "$(jq -r '.superseded_at != null | if . then 1 else 0 end' "$(rt_reload_receipt_path cursor "$PID" "$WID" "$RID1")")"
assert_eq "only the newest receipt is active" "$RID2" "$(rt_receipt_find_active cursor "$PID" "$WID" | jq -r .receipt_id)"
assert_eq "create without caller hashes records live hashes" "$(rt_config_hash_file "$HOME/.cursor/hooks.json")" "$(jq -r .pre_config_hashes.hooks <<<"$R2")"
assert_eq "empty server list recorded" "[]" "$(jq -c .affected_servers <<<"$R2")"

# supersede details: same change set / predecessor are kept
S="$TL_TMP/sup"; mkdir -p "$S"
mk_receipt() { # <id> <change_set> [extra jq filter]
  local path; path="$(rt_reload_receipt_path cursor "$PID" "$WID" "$1")"
  mkdir -p "$(dirname "$path")"
  jq -n --arg id "$1" --arg cs "$2" --arg pid "$PID" --arg wid "$WID" \
    '{schema:"v1",scope:"project",receipt_id:$id,nonce:"n",change_set_id:$cs,identities:{host:"cursor",project_id:$pid,worktree_id:$wid},expected_tools:{},post_config_hashes:{},activation_status:"none",written_at:"2026-01-01T00:00:00Z",consumed_at:null,superseded_at:null}'"${3:-}" >"$path"
  printf '%s' "$path"
}
rm -rf "$(dirname "$(rt_reload_receipt_path cursor "$PID" "$WID" x)")"
PA="$(mk_receipt ra cs-a)"; PB="$(mk_receipt rb cs-b)"; PC="$(mk_receipt rc cs-c ' | .consumed_at="2026-01-02T00:00:00Z"')"
PD="$(mk_receipt rd cs-d ' | .identities.host="codex"')"
printf 'garbage' >"$(dirname "$PA")/broken.json"
rt_receipt_supersede_same_lineage cursor "$PID" "$WID" project cs-a ""
assert_eq "same change set kept" "null" "$(jq -r .superseded_at "$PA")"
assert_eq "other change set superseded" "1" "$(jq -r '.superseded_at != null | if . then 1 else 0 end' "$PB")"
assert_eq "consumed receipts untouched" "null" "$(jq -r .superseded_at "$PC")"
assert_eq "other host untouched" "null" "$(jq -r .superseded_at "$PD")"
PE="$(mk_receipt re cs-e)"
rt_receipt_supersede_same_lineage cursor "$PID" "$WID" project cs-z re
assert_eq "predecessor kept" "null" "$(jq -r .superseded_at "$PE")"
assert_eq "unrelated active receipt superseded" "1" "$(jq -r '.superseded_at != null | if . then 1 else 0 end' "$PA")"
# active-receipt selection skips consumed/foreign/broken files and prefers the newest write
rm -rf "$(dirname "$PA")"
PA="$(mk_receipt ra cs-a ' | .written_at="2026-01-01T00:00:00Z"')"
PB="$(mk_receipt rb cs-b ' | .written_at="2026-03-01T00:00:00Z"')"
PC="$(mk_receipt rc cs-c ' | .consumed_at="2026-01-02T00:00:00Z" | .written_at="2026-05-01T00:00:00Z"')"
printf 'garbage' >"$(dirname "$PA")/broken.json"
assert_eq "find active: newest unconsumed" "rb" "$(rt_receipt_find_active cursor "$PID" "$WID" | jq -r .receipt_id)"
PX="$(mk_receipt rforeign cs-f ' | .identities.host="codex" | .written_at="2026-09-01T00:00:00Z"')"
assert_eq "find active: a newer receipt of another identity in the same dir is ignored" "rb" "$(rt_receipt_find_active cursor "$PID" "$WID" | jq -r .receipt_id)"
rm -f "$PX"
assert_eq "find active: wrong identity" "1" "$(rc_of rt_receipt_find_active cursor other-pid "$WID")"
assert_eq "find active: nothing for another host" "1" "$(rc_of rt_receipt_find_active codex "$PID" "$WID")"
assert_eq "identity match: host-global scope ignores project ids" "0" "$(rc_of rt_receipt_identity_matches '{"scope":"host-global","identities":{"host":"cursor"}}' cursor x y)"
assert_eq "identity match: mismatch" "1" "$(rc_of rt_receipt_identity_matches '{"scope":"project","identities":{"host":"cursor","project_id":"a","worktree_id":"b"}}' cursor x b)"

# a failing atomic write is tolerated while superseding
PS="$(mk_receipt rs cs-s)"
hr_bin mv 'exit 1'
rt_receipt_supersede_same_lineage cursor "$PID" "$WID" project cs-none ""
/bin/rm -f "$HR_BIN/mv"; hash -r
assert_eq "supersede: failed write leaves the receipt untouched" "null" "$(jq -r .superseded_at "$PS")"
rm -f "$PS"

# find by id: direct path, then scan, then miss
assert_eq "find by id (direct)" "rb" "$(rt_receipt_find_by_id cursor rb project "$PID" "$WID" | jq -r .receipt_id)"
assert_eq "find by id: empty id" "1" "$(rc_of rt_receipt_find_by_id cursor "")"
assert_eq "find by id: unknown id" "1" "$(rc_of rt_receipt_find_by_id cursor nope project "$PID" "$WID")"
mkdir -p "$(dirname "$PB")"; mv "$PB" "$(dirname "$PB")/renamed.json"
assert_eq "find by id: scan finds receipts stored under another file name" "rb" "$(rt_receipt_find_by_id cursor rb project "$PID" "$WID" | jq -r .receipt_id)"
printf 'garbage' >"$(rt_reload_receipt_path cursor "$PID" "$WID" rz)"
assert_eq "find by id: unreadable direct file falls through to the scan" "rb" "$(rt_receipt_find_by_id cursor rb project "$PID" "$WID" | jq -r .receipt_id)"
rm -f "$(rt_reload_receipt_path cursor "$PID" "$WID" rz)"
assert_eq "list paths: unknown scope dir" "" "$(rt_receipt_list_paths cursor nope nope)"

tl_results
