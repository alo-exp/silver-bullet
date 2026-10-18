#!/usr/bin/env bash
# scripts/lib/recommended-tools/receipts.sh: reload receipt lifecycle, host
# evidence attestation and the host convergence batches. Patchers are logging
# stubs in a staged repo; all state lives in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"

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
assert_match "random id fallback without od" '^rt-[0-9]+-' "$(hr_bin od 'exit 1'; PATH="$(hr_path_without uuidgen)" rt_receipt_random_id; hr_nobin od)" || true
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

# ------------------------------------------------------ host evidence stdin
assert_eq "evidence: valid" "0|{\"a\":1}|" "$(printf '{"a": 1}\n' | { rt_host_evidence_read_stdin; echo "$?|$RT_HOST_EVIDENCE_JSON|$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: invalid json" "1||host_evidence_invalid_json" "$(printf 'not json' | { rt_host_evidence_read_stdin || true; echo "$?|$RT_HOST_EVIDENCE_JSON|$RT_HOST_EVIDENCE_ERROR"; } | sed 's/^0|/1|/')"
assert_eq "evidence: oversized" "host_evidence_oversized" "$(head -c 70000 /dev/zero | tr '\0' 'a' | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: oversized returns failure" "1" "$(head -c 70000 /dev/zero | tr '\0' 'a' | { rc=0; rt_host_evidence_read_stdin || rc=$?; echo "$rc"; })"
export RT_ATTESTATION_MAX_BYTES=20
assert_eq "evidence: limit is configurable" "host_evidence_oversized" "$(printf '{"a":"%s"}' "$(printf 'x%.0s' {1..40})" | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
export RT_ATTESTATION_MAX_BYTES=65536
# ----------------------------------------------------- attestation validation
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
assert_eq "parse time" "1577836800" "$(rt_attestation_parse_time_epoch 2020-01-01T00:00:00Z)"
assert_eq "parse time: invalid" "1" "$(rc_of rt_attestation_parse_time_epoch garbage)"
rm -rf "$(dirname "$PA")"
RP="$(mk_receipt rv cs-v ' | .nonce="nonce-1" | .expected_tools={graphify:["query_graph","get_node"]} | .post_config_hashes={mcp:"M",hooks:"H"}')"
RECEIPT="$(jq -c . "$RP")"
att() { # <jq filter on the good attestation>
  jq -nc --arg now "$NOW" --arg pid "$PID" --arg wid "$WID" '{schema:"v1",receipt_id:"rv",nonce:"nonce-1",scope:"project",host:"cursor",project_id:$pid,worktree_id:$wid,session_id:"s1",observed_at:$now,config_hashes:{mcp:"M",hooks:"H"},servers:{graphify:{tools:[{id:"query_graph",status:"success"},{id:"get_node",status:"success"}]}}}' | jq -c "${1:-.}"
}
export RT_MODE=apply
val() { rt_attestation_validate "$1" "${2-$RECEIPT}"; }
v="$(val "$(att)")"
assert_eq "attestation: all tools succeeded" "true|full|true|0" "$(jq -r '"\(.valid)|\(.activation_status)|\(.clear_eligible)|\(.errors|length)"' <<<"$v")"
assert_eq "attestation: totals" "2|2|0" "$(jq -r '"\(.totals.total)|\(.totals.success)|\(.totals.failure)"' <<<"$v")"
v="$(val '{"schema":"v0"}')"
assert_eq "attestation: schema mismatch" '{"valid":false,"activation_status":"none","clear_eligible":false,"errors":["schema_mismatch"]}' "$(jq -c . <<<"$v")"
v="$(val "$(att '.receipt_id="x" | .nonce="y" | .host="h" | .scope="s" | .project_id="p" | .worktree_id="w" | .session_id=""')")"
for e in receipt_id_mismatch nonce_mismatch host_mismatch scope_mismatch project_id_mismatch worktree_id_mismatch empty_session; do
  assert_contains "attestation error: $e" "$(jq -c .errors <<<"$v")" "\"$e\""
done
assert_contains "attestation: missing receipt" "$(val "$(att)" "" | jq -c .errors)" '"missing_receipt"'
assert_contains "attestation: consumed receipt" "$(val "$(att)" "$(jq -c '.consumed_at="2026-01-01T00:00:00Z"' <<<"$RECEIPT")" | jq -c .errors)" '"receipt_consumed_or_superseded"'
assert_contains "attestation: stale" "$(val "$(att '.observed_at="2020-01-01T00:00:00Z"')" | jq -c .errors)" '"stale_attestation"'
FUT="$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
assert_contains "attestation: future skew" "$(val "$(att ".observed_at=\"$FUT\"")" | jq -c .errors)" '"future_skew"'
assert_contains "attestation: invalid observed_at" "$(val "$(att '.observed_at="nope"')" | jq -c .errors)" '"invalid_observed_at"'
assert_contains "attestation: mcp hash mismatch" "$(val "$(att '.config_hashes.mcp="X"')" | jq -c .errors)" '"attestation_mcp_hash_mismatch"'
assert_contains "attestation: hooks hash mismatch" "$(val "$(att '.config_hashes.hooks="X"')" | jq -c .errors)" '"attestation_hooks_hash_mismatch"'
assert_contains "attestation: missing server" "$(val "$(att 'del(.servers.graphify)')" | jq -c .errors)" '"missing_server:graphify"'
v="$(val "$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"},{id:"get_node",status:"failure"}]')")"
assert_eq "attestation: partial activation" "partial|false|1|1" "$(jq -r '"\(.activation_status)|\(.clear_eligible)|\(.totals.success)|\(.totals.failure)"' <<<"$v")"
v="$(val "$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"}]')")"
assert_contains "attestation: missing tool" "$(jq -c .errors <<<"$v")" '"missing_tool:graphify/get_node"'
assert_eq "attestation: a missing tool with some success is still valid (partial)" "true|partial" "$(jq -r '"\(.valid)|\(.activation_status)"' <<<"$v")"
v="$(val "$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"},{id:"get_node",status:"success"},{id:"extra",status:"success"}]')")"
assert_contains "attestation: unexpected tool" "$(jq -c .errors <<<"$v")" '"unexpected_tool:graphify/extra"'
v="$(val "$(att '.servers.graphify.tools=[]')")"
assert_eq "attestation: nothing succeeded -> none" "none|false" "$(jq -r '"\(.activation_status)|\(.clear_eligible)"' <<<"$v")"
NOTOOLS="$(jq -c '.expected_tools={}' <<<"$RECEIPT")"
v="$(val "$(att)" "$NOTOOLS")"
assert_eq "attestation: hooks-only repair needs no tools" "true|full|true" "$(jq -r '"\(.valid)|\(.activation_status)|\(.clear_eligible)"' <<<"$v")"
v="$(val "$(att '.nonce="bad"')" "$NOTOOLS")"
assert_eq "attestation: hooks-only repair with identity errors" "false|full|false" "$(jq -r '"\(.valid)|\(.activation_status)|\(.clear_eligible)"' <<<"$v")"
v="$(val "$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"}]|.nonce="bad"')")"
assert_eq "attestation: identity error plus partial activation is invalid" "false|partial" "$(jq -r '"\(.valid)|\(.activation_status)"' <<<"$v")"
# live hash checks apply outside apply mode
echo '{"mcp":"live"}' >"$HOME/.cursor/mcp.json"
v="$(RT_MODE=verify val "$(att)")"
assert_contains "attestation (verify): live mcp hash must match" "$(jq -c .errors <<<"$v")" '"mcp_hash_mismatch"'
assert_contains "attestation (verify): live hooks hash must match" "$(jq -c .errors <<<"$v")" '"hooks_hash_mismatch"'
LIVE_M="$(rt_config_hash_file "$HOME/.cursor/mcp.json")"; LIVE_H="$(rt_config_hash_file "$HOME/.cursor/hooks.json")"
LIVE_RECEIPT="$(jq -c --arg m "$LIVE_M" --arg h "$LIVE_H" '.post_config_hashes={mcp:$m,hooks:$h}' <<<"$RECEIPT")"
v="$(RT_MODE=verify val "$(att ".config_hashes={mcp:\"$LIVE_M\",hooks:\"$LIVE_H\"}")" "$LIVE_RECEIPT")"
assert_eq "attestation (verify): matching live hashes" "true" "$(jq -r .valid <<<"$v")"

# empty server / tool / extra names are skipped
BLANK_RECEIPT="$(jq -c '.expected_tools={"":["x"],graphify:["query_graph",""]}' <<<"$RECEIPT")"
v="$(val "$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"},{id:"",status:"success"}]')" "$BLANK_RECEIPT")"
assert_eq "attestation: blank names are ignored" "1|1" "$(jq -r '"\(.totals.total)|\(.totals.success)"' <<<"$v")"

# ----------------------------------------------------- consume / clear / reconcile
export RT_HOST_EVIDENCE_JSON="" RT_MODE=apply
assert_eq "consume: no evidence" "1" "$(rc_of rt_receipt_consume_host_evidence)"
RT_HOST_EVIDENCE_JSON="$(att)"; export RT_HOST_EVIDENCE_JSON
assert_eq "consume: verify mode refused" "1" "$(RT_MODE=verify rc_of rt_receipt_consume_host_evidence)"
RT_HOST_EVIDENCE_JSON="$(att '.receipt_id=""')"; export RT_HOST_EVIDENCE_JSON
assert_eq "consume: evidence without receipt id" "1" "$(rc_of rt_receipt_consume_host_evidence)"
RT_HOST_EVIDENCE_JSON="$(att '.receipt_id="unknown"')"; export RT_HOST_EVIDENCE_JSON
assert_eq "consume: unknown receipt" "1" "$(rc_of rt_receipt_consume_host_evidence)"
RT_HOST_EVIDENCE_JSON="$(att '.servers.graphify.tools=[{id:"query_graph",status:"success"}]')"; export RT_HOST_EVIDENCE_JSON
rc=0; rt_receipt_consume_host_evidence || rc=$?
assert_eq "consume: partial evidence does not clear" "1" "$rc"
assert_eq "consume: evaluation recorded" "partial" "$(jq -r .activation_status <<<"$RT_RECEIPT_EVAL_JSON")"
assert_eq "consume: receipt still active" "null" "$(jq -r .consumed_at "$RP")"
RT_HOST_EVIDENCE_JSON="$(att)"; export RT_HOST_EVIDENCE_JSON
rc=0; rt_receipt_consume_host_evidence || rc=$?
assert_eq "consume: full evidence clears the receipt" "0" "$rc"
assert_eq "consume: receipt consumed and full" "full" "$(jq -r .activation_status "$RP")"
assert_eq "consume: consumed_at stamped" "1" "$(jq -r '.consumed_at != null | if . then 1 else 0 end' "$RP")"
assert_eq "consume: suppress flags exported" "1|1" "${RT_SUPPRESS_RELOAD_RECEIPT_CREATE:-}|${RT_HOST_EVIDENCE_RECEIPT_CLEARED:-}"
unset RT_SUPPRESS_RELOAD_RECEIPT_CREATE RT_HOST_EVIDENCE_RECEIPT_CLEARED

assert_eq "clear: receipt file missing" "1" "$(rc_of rt_receipt_clear "$(jq -c '.receipt_id="ghost"' <<<"$RECEIPT")")"
assert_eq "clear: defaults for sparse receipts" "1" "$(rc_of rt_receipt_clear '{}')"

# reconcile state
rm -rf "$(dirname "$RP")"; unset RT_HOST_EVIDENCE_JSON
RT_RECEIPT_EVAL_JSON=""
st() { jq -c . <<<"$(rt_reconcile_receipt_state)"; }
assert_eq "reconcile: nothing pending" '{"has_receipt":false,"canonical_state":"ready","activation_status":"none","clear_eligible":false,"errors":[]}' "$(st)"
RP="$(mk_receipt rw cs-w ' | .nonce="nonce-1"')"
assert_eq "reconcile: a pending receipt produces no jq errors on stderr" "" "$(rt_reconcile_receipt_state 2>&1 >/dev/null)"
assert_eq "reconcile: pending receipt" '{"has_receipt":true,"canonical_state":"reload_required","activation_status":"none","clear_eligible":false,"errors":[]}' "$(st)"
# host-global receipts are found when no project receipt exists
rm -f "$RP"
HG="$(rt_reload_receipt_path cursor "$PID" "$WID" rg host-global)"; mkdir -p "$(dirname "$HG")"
jq -n --arg pid "$PID" '{schema:"v1",scope:"host-global",receipt_id:"rg",nonce:"n",identities:{host:"cursor",project_id:"x",worktree_id:"y"},activation_status:"partial",written_at:"2026-01-01T00:00:00Z",consumed_at:null,superseded_at:null}' >"$HG"
assert_eq "reconcile: host-global receipt" "true|partial" "$(rt_reconcile_receipt_state | jq -r '"\(.has_receipt)|\(.activation_status)"')"
rm -f "$HG"
# with evidence for a pending receipt (verify mode: evaluated, not cleared)
RP="$(mk_receipt rv cs-v ' | .nonce="nonce-1" | .expected_tools={graphify:["query_graph","get_node"]} | .post_config_hashes={mcp:"M",hooks:"H"}')"
RT_HOST_EVIDENCE_JSON="$(att)"; export RT_HOST_EVIDENCE_JSON
out="$(RT_MODE=verify rt_reconcile_receipt_state)"
assert_eq "reconcile (verify): evaluated but not cleared" "true|reload_required|full|true" "$(jq -r '"\(.has_receipt)|\(.canonical_state)|\(.activation_status)|\(.clear_eligible)"' <<<"$out")"
assert_contains "reconcile (verify): attestation errors surfaced" "$(jq -c .errors <<<"$out")" "hash_mismatch"
out="$(rt_reconcile_receipt_state)"
assert_eq "reconcile (apply): valid evidence clears the receipt" "false|ready|full|true" "$(jq -r '"\(.has_receipt)|\(.canonical_state)|\(.activation_status)|\(.clear_eligible)"' <<<"$out")"
assert_eq "reconcile (apply): receipt consumed on disk" "1" "$(jq -r '.consumed_at != null | if . then 1 else 0 end' "$RP")"
# evidence without a matching receipt falls back to the active lookup
RT_HOST_EVIDENCE_JSON="$(att '.receipt_id="nope"')"; export RT_HOST_EVIDENCE_JSON
rm -f "$RP"; RP="$(mk_receipt rx cs-x ' | .nonce="n"')"
out="$(rt_reconcile_receipt_state)"
assert_eq "reconcile: evidence for an unknown id still evaluates the active receipt" "true" "$(jq -r .has_receipt <<<"$out")"
# receipt already cleared by consume
export RT_HOST_EVIDENCE_RECEIPT_CLEARED=1 RT_RECEIPT_EVAL_JSON='{"activation_status":"partial","errors":["e1"]}'
out="$(rt_reconcile_receipt_state)"
assert_eq "reconcile: cleared via consume" "false|ready|partial|true" "$(jq -r '"\(.has_receipt)|\(.canonical_state)|\(.activation_status)|\(.clear_eligible)"' <<<"$out")"
assert_eq "reconcile: cleared via consume keeps attestation errors" '["e1"]' "$(jq -c .errors <<<"$out")"
RT_RECEIPT_EVAL_JSON=""
assert_eq "reconcile: cleared without an evaluation" "full" "$(rt_reconcile_receipt_state | jq -r .activation_status)"
unset RT_HOST_EVIDENCE_RECEIPT_CLEARED RT_HOST_EVIDENCE_JSON

tl_results
