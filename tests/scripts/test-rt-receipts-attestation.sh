#!/usr/bin/env bash
# scripts/lib/recommended-tools/receipts.sh: host evidence intake, attestation
# validation, receipt consumption/clearing and reconcile state. Patchers are logging
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

export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all RT_PROJECT_ROOT="$HR_PROJ"
PID="$(rt_project_id)"; WID="$(rt_worktree_id "$HR_PROJ")"
mk_receipt() { # <id> <change_set> [extra jq filter]
  local path; path="$(rt_reload_receipt_path cursor "$PID" "$WID" "$1")"
  mkdir -p "$(dirname "$path")"
  jq -n --arg id "$1" --arg cs "$2" --arg pid "$PID" --arg wid "$WID" \
    '{schema:"v1",scope:"project",receipt_id:$id,nonce:"n",change_set_id:$cs,identities:{host:"cursor",project_id:$pid,worktree_id:$wid},expected_tools:{},post_config_hashes:{},activation_status:"none",written_at:"2026-01-01T00:00:00Z",consumed_at:null,superseded_at:null}'"${3:-}" >"$path"
  printf '%s' "$path"
}
# ------------------------------------------------------ host evidence stdin
assert_eq "evidence: valid" "0|{\"a\":1}|" "$(printf '{"a": 1}\n' | { rt_host_evidence_read_stdin; echo "$?|$RT_HOST_EVIDENCE_JSON|$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: invalid json" "1||host_evidence_invalid_json" "$(printf 'not json' | { rt_host_evidence_read_stdin || true; echo "$?|$RT_HOST_EVIDENCE_JSON|$RT_HOST_EVIDENCE_ERROR"; } | sed 's/^0|/1|/')"
assert_eq "evidence: oversized" "host_evidence_oversized" "$(head -c 70000 /dev/zero | tr '\0' 'a' | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: oversized returns failure" "1" "$(head -c 70000 /dev/zero | tr '\0' 'a' | { rc=0; rt_host_evidence_read_stdin || rc=$?; echo "$rc"; })"
export RT_ATTESTATION_MAX_BYTES=20
assert_eq "evidence: limit is configurable" "host_evidence_oversized" "$(printf '{"a":"%s"}' "$(printf 'x%.0s' {1..40})" | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
export RT_ATTESTATION_MAX_BYTES=65536
assert_eq "evidence: two concatenated documents are rejected" "host_evidence_invalid_json" "$(printf '{"a":1}{"b":2}' | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: trailing junk is rejected" "host_evidence_invalid_json" "$(printf '{"a":1}\nEXTRA' | { rt_host_evidence_read_stdin || true; echo "$RT_HOST_EVIDENCE_ERROR"; })"
assert_eq "evidence: trailing junk returns failure and keeps no evidence" "1|" "$(printf '{"a":1} junk' | { rc=0; rt_host_evidence_read_stdin || rc=$?; echo "$rc|$RT_HOST_EVIDENCE_JSON"; })"
# ----------------------------------------------------- attestation validation
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
assert_eq "parse time" "1577836800" "$(rt_attestation_parse_time_epoch 2020-01-01T00:00:00Z)"
assert_eq "parse time: invalid" "1" "$(rc_of rt_attestation_parse_time_epoch garbage)"
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
