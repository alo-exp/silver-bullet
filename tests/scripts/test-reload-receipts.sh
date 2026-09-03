#!/usr/bin/env bash
# Tests reload receipt lifecycle and host-evidence attestation (Phase C §8-9)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RECONCILE="$REPO_ROOT/scripts/reconcile-recommended-tools.sh"
RT_LIB="$REPO_ROOT/scripts/lib/recommended-tools"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0
TMP=""
TEST_HOME=""
WT_LINKED=""

cleanup() {
  # EXIT trap must not fail the script after a green assertion run.
  # lean-ctx may still be writing $HOME/.local/share/lean-ctx when HOME=$TEST_HOME.
  set +e
  if [[ -n "${TMP:-}" && -n "${WT_LINKED:-}" && -d "${WT_LINKED}" ]]; then
    git -C "$TMP" worktree remove "$WT_LINKED" --force 2>/dev/null || rm -rf "$WT_LINKED"
  fi
  chmod -R u+w "$TMP" "$TEST_HOME" 2>/dev/null
  rm -rf "$TMP" "$TEST_HOME" 2>/dev/null || {
    sleep 0.2
    rm -rf "$TMP" "$TEST_HOME" 2>/dev/null || true
  }
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
export SB_RUNTIME_STATE_DIR="${TEST_HOME}/.silver-bullet"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SILVER_BULLET_RUNTIME=cursor
export SILVER_BULLET_SESSION_ID="test-session-$$"
mkdir -p "${TEST_HOME}/.cursor" "$SB_RUNTIME_STATE_DIR"
printf '{"mcpServers":{}}\n' >"${TEST_HOME}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' >"${TEST_HOME}/.cursor/hooks.json"

jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP/silver-bullet.md"
git -C "$TMP" init -q
git -C "$TMP" add .silver-bullet.json silver-bullet.md 2>/dev/null || git -C "$TMP" add .silver-bullet.json
git -C "$TMP" -c user.email=test@example.com -c user.name="Test User" commit -q -m "init" 2>/dev/null || true

echo "=== reload receipts + host evidence tests ==="

for lib in paths.sh receipts.sh; do
  bash -n "$RT_LIB/$lib" 2>/dev/null && pass "bash -n $lib" || fail "bash -n $lib"
done

export RT_PROJECT_ROOT="$TMP" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=init
# shellcheck source=../../scripts/lib/recommended-tools/common.sh
source "$RT_LIB/common.sh"
rt_init_paths
# shellcheck source=../../scripts/lib/recommended-tools/receipts.sh
source "$RT_LIB/receipts.sh"

hashes="$(rt_current_config_hashes)"
receipt="$(rt_receipt_create project init '["graphify","agentmemory"]' true 2>/dev/null || true)"
echo "$receipt" | jq -e '.schema == "v1" and .receipt_id != "" and .nonce != ""' >/dev/null 2>&1 \
  && pass "receipt create schema-v1" || fail "receipt create schema-v1"

rid="$(echo "$receipt" | jq -r '.receipt_id')"
nonce="$(echo "$receipt" | jq -r '.nonce')"
pid="$(echo "$receipt" | jq -r '.identities.project_id')"
wid="$(echo "$receipt" | jq -r '.identities.worktree_id')"
post_hashes="$(echo "$receipt" | jq -c '.post_config_hashes')"

build_attestation() {
  local status="${1:-success}"
  jq -n \
    --arg schema "v1" \
    --arg receipt_id "$rid" \
    --arg nonce "$nonce" \
    --arg scope "project" \
    --arg host "cursor" \
    --arg project_id "$pid" \
    --arg worktree_id "$wid" \
    --arg session_id "$SILVER_BULLET_SESSION_ID" \
    --argjson config_hashes "$post_hashes" \
    --arg status "$status" \
    --arg observed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      schema: $schema,
      receipt_id: $receipt_id,
      nonce: $nonce,
      scope: $scope,
      host: $host,
      project_id: $project_id,
      worktree_id: $worktree_id,
      session_id: $session_id,
      config_hashes: $config_hashes,
      observed_at: $observed,
      servers: {
        graphify: { tools: [
          {id:"query_graph",status:$status},
          {id:"get_node",status:$status},
          {id:"graph_stats",status:$status}
        ]},
        agentmemory: { tools: [
          {id:"memory_save",status:$status},
          {id:"memory_recall",status:$status}
        ]}
      }
    }'
}

attestation="$(build_attestation success)"
eval="$(rt_attestation_validate "$attestation" "$receipt")"
echo "$eval" | jq -e '.valid == true and .clear_eligible == true' >/dev/null 2>&1 \
  && pass "valid all-success attestation clear-eligible" || fail "valid all-success attestation clear-eligible"

# leanctx expected tools use ctx_* IDs (live lean-ctx 3.9.9 session names; SB rules document lctx_)
leanctx_tools="$(rt_receipt_expected_tools_json '["leanctx"]')"
echo "$leanctx_tools" | jq -e '.leanctx == ["ctx_compose","ctx_read","ctx_search"]' >/dev/null 2>&1 \
  && pass "leanctx expected tools use ctx_ session IDs" || fail "leanctx expected tools use ctx_ session IDs"

# hooks-only servers (rtk) omitted from expected_tools attestation map
rtk_tools="$(rt_receipt_expected_tools_json '["rtk","graphify"]')"
echo "$rtk_tools" | jq -e 'has("rtk") == false and (.graphify | length) > 0' >/dev/null 2>&1 \
  && pass "hooks-only rtk omitted from expected_tools" || fail "hooks-only rtk omitted from expected_tools"

# verify/plan consume in memory only — no clear
verify_out="$(printf '%s' "$attestation" | bash "$RECONCILE" --project-root "$TMP" --host cursor \
  --mode verify --format json --host-evidence-stdin 2>/dev/null || true)"
echo "$verify_out" | jq -e '.receipt.clear_eligible == true and .receipt.has_receipt == true' >/dev/null 2>&1 \
  && pass "verify consumes evidence without clearing" || fail "verify consumes evidence without clearing"
active="$(rt_receipt_find_active cursor "$pid" "$wid" project 2>/dev/null || true)"
echo "$active" | jq -e '.consumed_at == null' >/dev/null 2>&1 \
  && pass "receipt still active after verify" || fail "receipt still active after verify"

# partial failure attestation
partial="$(build_attestation failure)"
peval="$(rt_attestation_validate "$partial" "$receipt")"
echo "$peval" | jq -e '.activation_status == "partial" and .clear_eligible == false' >/dev/null 2>&1 \
  && pass "partial tool failures retain reload_required" || fail "partial tool failures retain reload_required"

# oversized stdin
big="$(printf '%70000s' 'x')"
big_rc=0
printf '%s' "$big" | bash "$RECONCILE" --project-root "$TMP" --host cursor --mode verify \
  --host-evidence-stdin --format json 2>/dev/null || big_rc=$?
[[ "$big_rc" -ne 0 ]] && pass "rejects oversized host evidence" || fail "rejects oversized host evidence"

# trailing document
trail_rc=0
printf '{"schema":"v1"}{}\n' | bash "$RECONCILE" --project-root "$TMP" --host cursor --mode verify \
  --host-evidence-stdin --format json >/dev/null 2>&1 || trail_rc=$?
[[ "$trail_rc" -ne 0 ]] && pass "rejects trailing host evidence" || fail "rejects trailing host evidence"

# wrong nonce
bad="$(echo "$attestation" | jq '.nonce = "wrong"')"
beval="$(rt_attestation_validate "$bad" "$receipt")"
echo "$beval" | jq -e '(.errors | index("nonce_mismatch")) != null' >/dev/null 2>&1 \
  && pass "rejects wrong nonce" || fail "rejects wrong nonce"

# cross-worktree: linked worktree shares project_id, differs worktree_id
WT_LINKED=""
if git -C "$TMP" worktree list >/dev/null 2>&1; then
  WT_LINKED="$(mktemp -d)"
  if git -C "$TMP" worktree add -q "$WT_LINKED" 2>/dev/null; then
    export RT_PROJECT_ROOT="$TMP"
    pid_main="$(bash -c 'source "'"$RT_LIB"'/common.sh"; rt_init_paths; rt_project_id' 2>/dev/null || true)"
    wid_main="$(bash -c 'source "'"$RT_LIB"'/common.sh"; rt_init_paths; rt_worktree_id "'"$TMP"'"' 2>/dev/null || true)"
    export RT_PROJECT_ROOT="$WT_LINKED"
    pid_linked="$(bash -c 'source "'"$RT_LIB"'/common.sh"; rt_init_paths; rt_project_id' 2>/dev/null || true)"
    wid_linked="$(bash -c 'source "'"$RT_LIB"'/common.sh"; rt_init_paths; rt_worktree_id "'"$WT_LINKED"'"' 2>/dev/null || true)"
    [[ -n "$pid_main" && -n "$pid_linked" && "$pid_main" == "$pid_linked" ]] \
      && pass "project_id equal across linked worktrees" || fail "project_id equal across linked worktrees"
    [[ -n "$wid_main" && -n "$wid_linked" && "$wid_main" != "$wid_linked" ]] \
      && pass "worktree_id differs across linked worktrees" || fail "worktree_id differs across linked worktrees"

    export RT_PROJECT_ROOT="$WT_LINKED"
    receipt2="$(rt_receipt_create project init '["graphify"]' true 2>/dev/null || true)"
    rid2="$(echo "$receipt2" | jq -r '.receipt_id')"
    wid2="$(echo "$receipt2" | jq -r '.identities.worktree_id')"
    pid2="$(echo "$receipt2" | jq -r '.identities.project_id')"
    [[ "$pid" == "$pid2" ]] && pass "linked worktree receipt shares project_id" || fail "linked worktree receipt shares project_id"
    [[ "$wid" != "$wid2" ]] && pass "worktree ids differ across linked worktrees" || fail "worktree ids differ across linked worktrees"
    found="$(rt_receipt_find_active cursor "$pid" "$wid" project 2>/dev/null || true)"
    found2="$(rt_receipt_find_active cursor "$pid2" "$wid2" project 2>/dev/null || true)"
    [[ "$(echo "$found" | jq -r '.receipt_id')" == "$rid" ]] && pass "main worktree receipt isolated" || fail "main worktree receipt isolated"
    [[ "$(echo "$found2" | jq -r '.receipt_id')" == "$rid2" ]] && pass "linked worktree receipt isolated" || fail "linked worktree receipt isolated"

    git -C "$TMP" worktree remove "$WT_LINKED" --force 2>/dev/null || rm -rf "$WT_LINKED"
    WT_LINKED=""
  else
    rm -rf "$WT_LINKED"
    WT_LINKED=""
    fail "linked worktree fixture could not be created"
  fi
else
  fail "git worktree unavailable for linked worktree fixture"
fi
export RT_PROJECT_ROOT="$TMP"

# Valid heartbeat so cross_tool is ready (not repairable) during authorized apply
# shellcheck source=../../scripts/lib/recommended-tools/heartbeat.sh
source "$RT_LIB/heartbeat.sh"
rt_heartbeat_write "$TMP" cursor >/dev/null 2>&1 || true

# authorized apply clears on all-success
apply_out="$(printf '%s' "$attestation" | bash "$RECONCILE" --project-root "$TMP" --host cursor \
  --mode apply --entry-point init --scope host --format json --host-evidence-stdin 2>/dev/null || true)"
echo "$apply_out" | jq -e '.receipt.has_receipt == false or .receipt.canonical_state == "ready"' >/dev/null 2>&1 \
  && pass "authorized apply clears receipt on all-success" || fail "authorized apply clears receipt on all-success"

# hooks-only receipt (rtk): empty expected_tools clears on valid attestation
hooks_receipt="$(rt_receipt_create project init '["rtk"]' true 2>/dev/null || true)"
echo "$hooks_receipt" | jq -e '.expected_tools == {}' >/dev/null 2>&1 \
  && pass "hooks-only receipt has empty expected_tools" || fail "hooks-only receipt has empty expected_tools"
hooks_rid="$(echo "$hooks_receipt" | jq -r '.receipt_id')"
hooks_nonce="$(echo "$hooks_receipt" | jq -r '.nonce')"
hooks_post="$(echo "$hooks_receipt" | jq -c '.post_config_hashes')"
hooks_attestation="$(jq -n \
  --arg schema "v1" \
  --arg receipt_id "$hooks_rid" \
  --arg nonce "$hooks_nonce" \
  --arg scope "project" \
  --arg host "cursor" \
  --arg project_id "$pid" \
  --arg worktree_id "$wid" \
  --arg session_id "$SILVER_BULLET_SESSION_ID" \
  --argjson config_hashes "$hooks_post" \
  --arg observed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: $schema,
    receipt_id: $receipt_id,
    nonce: $nonce,
    scope: $scope,
    host: $host,
    project_id: $project_id,
    worktree_id: $worktree_id,
    session_id: $session_id,
    config_hashes: $config_hashes,
    observed_at: $observed,
    servers: {}
  }')"
hooks_eval="$(rt_attestation_validate "$hooks_attestation" "$hooks_receipt")"
echo "$hooks_eval" | jq -e '.valid == true and .clear_eligible == true and .totals.total == 0' >/dev/null 2>&1 \
  && pass "hooks-only attestation clear-eligible when total==0" || fail "hooks-only attestation clear-eligible when total==0"

hooks_apply_out="$(printf '%s' "$hooks_attestation" | bash "$RECONCILE" --project-root "$TMP" --host cursor \
  --mode apply --entry-point init --scope host --format json --host-evidence-stdin 2>/dev/null || true)"
echo "$hooks_apply_out" | jq -e '.receipt.has_receipt == false or .receipt.canonical_state == "ready"' >/dev/null 2>&1 \
  && pass "authorized apply clears hooks-only receipt" || fail "authorized apply clears hooks-only receipt"

# wrong hooks hash in attestation must not clear hooks-only receipt
hooks_receipt_bad="$(rt_receipt_create project init '["rtk"]' true 2>/dev/null || true)"
hooks_rid_bad="$(echo "$hooks_receipt_bad" | jq -r '.receipt_id')"
hooks_nonce_bad="$(echo "$hooks_receipt_bad" | jq -r '.nonce')"
hooks_post_bad="$(echo "$hooks_receipt_bad" | jq -c '.post_config_hashes')"
hooks_bad_hashes="$(echo "$hooks_post_bad" | jq -c '.hooks = "deadbeef0000000000000000000000000000000000000000000000000000000000"')"
hooks_bad_attestation="$(jq -n \
  --arg schema "v1" \
  --arg receipt_id "$hooks_rid_bad" \
  --arg nonce "$hooks_nonce_bad" \
  --arg scope "project" \
  --arg host "cursor" \
  --arg project_id "$pid" \
  --arg worktree_id "$wid" \
  --arg session_id "$SILVER_BULLET_SESSION_ID" \
  --argjson config_hashes "$hooks_bad_hashes" \
  --arg observed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: $schema,
    receipt_id: $receipt_id,
    nonce: $nonce,
    scope: $scope,
    host: $host,
    project_id: $project_id,
    worktree_id: $worktree_id,
    session_id: $session_id,
    config_hashes: $config_hashes,
    observed_at: $observed,
    servers: {}
  }')"
hooks_bad_eval="$(rt_attestation_validate "$hooks_bad_attestation" "$hooks_receipt_bad")"
echo "$hooks_bad_eval" | jq -e '(.errors | index("attestation_hooks_hash_mismatch")) != null and .clear_eligible == false' >/dev/null 2>&1 \
  && pass "wrong hooks hash rejects hooks-only attestation" || fail "wrong hooks hash rejects hooks-only attestation"
hooks_bad_apply="$(printf '%s' "$hooks_bad_attestation" | bash "$RECONCILE" --project-root "$TMP" --host cursor \
  --mode apply --entry-point init --scope host --format json --host-evidence-stdin 2>/dev/null || true)"
echo "$hooks_bad_apply" | jq -e '.receipt.has_receipt == true' >/dev/null 2>&1 \
  && pass "wrong hooks hash does not clear hooks-only receipt" || fail "wrong hooks hash does not clear hooks-only receipt"

# leanctx receipt attestation with ctx_* tool IDs (live session names)
leanctx_receipt="$(rt_receipt_create project init '["leanctx"]' true 2>/dev/null || true)"
leanctx_rid="$(echo "$leanctx_receipt" | jq -r '.receipt_id')"
leanctx_nonce="$(echo "$leanctx_receipt" | jq -r '.nonce')"
leanctx_post="$(echo "$leanctx_receipt" | jq -c '.post_config_hashes')"
leanctx_attestation="$(jq -n \
  --arg schema "v1" \
  --arg receipt_id "$leanctx_rid" \
  --arg nonce "$leanctx_nonce" \
  --arg scope "project" \
  --arg host "cursor" \
  --arg project_id "$pid" \
  --arg worktree_id "$wid" \
  --arg session_id "$SILVER_BULLET_SESSION_ID" \
  --argjson config_hashes "$leanctx_post" \
  --arg observed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: $schema,
    receipt_id: $receipt_id,
    nonce: $nonce,
    scope: $scope,
    host: $host,
    project_id: $project_id,
    worktree_id: $worktree_id,
    session_id: $session_id,
    config_hashes: $config_hashes,
    observed_at: $observed,
    servers: {
      leanctx: { tools: [
        {id:"ctx_compose",status:"success"},
        {id:"ctx_read",status:"success"},
        {id:"ctx_search",status:"success"}
      ]}
    }
  }')"
leanctx_eval="$(rt_attestation_validate "$leanctx_attestation" "$leanctx_receipt")"
echo "$leanctx_eval" | jq -e '.valid == true and .clear_eligible == true' >/dev/null 2>&1 \
  && pass "leanctx ctx_* attestation clear-eligible" || fail "leanctx ctx_* attestation clear-eligible"

# pre_config_hashes captured before mutations when RT_PRE_CONFIG_HASHES set
pre_snapshot="$(rt_current_config_hashes)"
printf '{"mcpServers":{"test":{"command":"noop"}}}\n' >"${TEST_HOME}/.cursor/mcp.json"
RT_PRE_CONFIG_HASHES="$pre_snapshot"
receipt_pre="$(rt_receipt_create project init '["graphify"]' true 2>/dev/null || true)"
unset RT_PRE_CONFIG_HASHES
echo "$receipt_pre" | jq -e --argjson pre "$pre_snapshot" '.pre_config_hashes.mcp == $pre.mcp' >/dev/null 2>&1 \
  && pass "receipt pre_config_hashes captured before post mutation" || fail "receipt pre_config_hashes captured before post mutation"
printf '{"mcpServers":{}}\n' >"${TEST_HOME}/.cursor/mcp.json"

# supersede: new receipt supersedes prior active for same scope/identity
receipt_old="$(rt_receipt_create project init '["graphify"]' true 2>/dev/null || true)"
rid_old="$(echo "$receipt_old" | jq -r '.receipt_id')"
receipt_new="$(rt_receipt_create project init '["graphify","rtk"]' true 2>/dev/null || true)"
rid_new="$(echo "$receipt_new" | jq -r '.receipt_id')"
active_after="$(rt_receipt_find_active cursor "$pid" "$wid" project 2>/dev/null || true)"
[[ "$(echo "$active_after" | jq -r '.receipt_id')" == "$rid_new" ]] \
  && pass "supersede leaves only newest active receipt" || fail "supersede leaves only newest active receipt"
old_path="$(rt_reload_receipt_path cursor "$pid" "$wid" "$rid_old" project)"
old_on_disk="$(rt_receipt_read "$old_path" 2>/dev/null || true)"
echo "$old_on_disk" | jq -e '.superseded_at != null' >/dev/null 2>&1 \
  && pass "superseded receipt has superseded_at set" || fail "superseded receipt has superseded_at set"

# malicious receipt_id cannot escape store on clear
# shellcheck source=../../scripts/lib/recommended-tools/paths.sh
source "$RT_LIB/paths.sh"
decoy_outside="${TEST_HOME}/decoy-outside-store.json"
printf '{"marker":"outside-store","consumed_at":null}\n' >"$decoy_outside"
store_root="$(rt_reload_receipt_root)"
malicious_rid='../../../decoy-outside-store'
safe_path="$(rt_reload_receipt_path cursor "$pid" "$wid" "$malicious_rid" project)"
case "$safe_path" in
  "${store_root}"/*) pass "malicious receipt_id path stays under store root" ;;
  *) fail "malicious receipt_id path stays under store root" ;;
esac
malicious_receipt="$(jq -n \
  --arg schema "v1" \
  --arg receipt_id "$malicious_rid" \
  --arg nonce "malicious-nonce" \
  --arg scope "project" \
  --arg host "cursor" \
  --arg project_id "$pid" \
  --arg worktree_id "$wid" \
  --arg observed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: $schema,
    scope: $scope,
    receipt_id: $receipt_id,
    nonce: $nonce,
    identities: {host: $host, project_id: $project_id, worktree_id: $worktree_id},
    activation_status: "none",
    consumed_at: null,
    superseded_at: null,
    written_at: $observed
  }')"
mkdir -p "$(dirname "$safe_path")"
rt_atomic_write_json "$safe_path" "$malicious_receipt"
rt_receipt_clear "$malicious_receipt" 2>/dev/null || true
jq -e '.marker == "outside-store" and .consumed_at == null' "$decoy_outside" >/dev/null 2>&1 \
  && pass "malicious receipt_id clear cannot escape store" || fail "malicious receipt_id clear cannot escape store"
rm -f "$decoy_outside" "$safe_path"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
