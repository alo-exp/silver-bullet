# shellcheck shell=bash
# Reload receipt lifecycle and host-evidence attestation (schema-v1).
# Only the reconciler creates, supersedes, verifies, persists, clears, or deletes receipts.

RT_RECEIPT_SCHEMA="v1"
RT_ATTESTATION_SCHEMA="v1"
RT_ATTESTATION_MAX_BYTES=65536
RT_ATTESTATION_MAX_AGE_SECONDS=120
RT_ATTESTATION_MAX_FUTURE_SKEW_SECONDS=15

# shellcheck source=paths.sh
source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

RT_HOST_EVIDENCE_JSON=""
RT_HOST_EVIDENCE_ERROR=""
RT_RECEIPT_EVAL_JSON=""

rt_json_string_array() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
  else
    printf '%s\n' "$@" | jq -R -s 'split("\n")|map(select(length>0))'
  fi
}

rt_config_hash_file() {
  local path="${1:-}"
  [[ -f "$path" && ! -L "$path" ]] || { printf ''; return 0; }
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    sha256sum "$path" | awk '{print $1}'
  fi
}

rt_current_config_hashes() {
  local mcp hooks
  mcp="$(rt_config_hash_file "${HOME}/.cursor/mcp.json")"
  hooks="$(rt_config_hash_file "${HOME}/.cursor/hooks.json")"
  jq -n --arg mcp "$mcp" --arg hooks "$hooks" '{mcp:$mcp,hooks:$hooks}'
}

rt_patcher_output_unchanged() {
  local output="${1:-}"
  [[ -n "$output" ]] || return 1
  grep -qE 'unchanged|\(0 changes?\)|: 0 change\(s\)' <<<"$output"
}

rt_config_hash_changed() {
  local pre="${1:-}" post="${2:-}"
  [[ -z "$pre" && -n "$post" ]] && return 0
  [[ -n "$pre" && -n "$post" && "$pre" != "$post" ]]
}

rt_receipt_random_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    printf 'rt-%s-%s' "$(date +%s)" "$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo rand)"
  fi
}

rt_receipt_random_nonce() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || printf 'nonce-%s' "$(date +%s)"
  fi
}

# Attest real session MCP tool IDs. SB five_tool_routed rules document lctx_* namespace,
# but lean-ctx 3.9.9 may still expose ctx_* when LEANCTX_MCP_TOOL_PREFIX=lctx_ until upstream rename.
# Hooks-only servers (e.g. rtk) are omitted — attestation requires MCP tool liveness only.
rt_receipt_expected_tools_json() {
  local servers_json="${1:-[]}"
  jq -n --argjson servers "$servers_json" '
    reduce $servers[] as $s ({};
      if $s == "graphify" then . + {($s): ["query_graph","get_node","graph_stats"]}
      elif $s == "agentmemory" then . + {($s): ["memory_save","memory_recall"]}
      elif $s == "leanctx" then . + {($s): ["ctx_compose","ctx_read","ctx_search"]}
      elif $s == "context-mode" then . + {($s): ["ctx_execute","ctx_search"]}
      else .
      end
    )
  '
}

rt_receipt_list_paths() {
  local host="${1:-cursor}" project_id="${2:-}" worktree_id="${3:-}" scope="${4:-project}"
  local dir
  dir="$(rt_reload_receipt_scope_dir "$host" "$project_id" "$worktree_id" "$scope" 2>/dev/null || true)"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -name '*.json' -type f ! -name '.*' 2>/dev/null | sort
}

rt_receipt_read() {
  local path="${1:-}"
  [[ -f "$path" && ! -L "$path" ]] || return 1
  jq -c '.' "$path" 2>/dev/null
}

rt_receipt_identity_matches() {
  local receipt_json="${1:-}" host="${2:-}" project_id="${3:-}" worktree_id="${4:-}"
  jq -e --arg host "$host" --arg pid "$project_id" --arg wid "$worktree_id" '
    .identities.host == $host
    and (.identities.project_id == $pid or .scope == "host-global")
    and (.identities.worktree_id == $wid or .scope == "host-global")
  ' <<<"$receipt_json" >/dev/null 2>&1
}

rt_receipt_find_active() {
  local host="${1:-cursor}" project_id="${2:-}" worktree_id="${3:-}" scope="${4:-project}"
  local path receipt newest="" newest_ts=""
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    receipt="$(rt_receipt_read "$path" 2>/dev/null || true)"
    [[ -n "$receipt" ]] || continue
    jq -e '.consumed_at == null and (.superseded_at == null or .superseded_at == "")' <<<"$receipt" >/dev/null 2>&1 || continue
    rt_receipt_identity_matches "$receipt" "$host" "$project_id" "$worktree_id" || continue
    local ts
    ts="$(jq -r '.written_at // ""' <<<"$receipt")"
    if [[ -z "$newest" || "$ts" > "$newest_ts" ]]; then
      newest="$receipt"
      newest_ts="$ts"
    fi
  done < <(rt_receipt_list_paths "$host" "$project_id" "$worktree_id" "$scope")
  [[ -n "$newest" ]] && printf '%s' "$newest"
}

rt_receipt_supersede_same_lineage() {
  local host="${1:-}" project_id="${2:-}" worktree_id="${3:-}" scope="${4:-project}"
  local change_set_id="${5:-}" predecessor="${6:-}"
  local path receipt
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    receipt="$(rt_receipt_read "$path" 2>/dev/null || true)"
    [[ -n "$receipt" ]] || continue
    jq -e '.consumed_at == null and (.superseded_at == null or .superseded_at == "")' <<<"$receipt" >/dev/null 2>&1 || continue
    rt_receipt_identity_matches "$receipt" "$host" "$project_id" "$worktree_id" || continue
    if [[ -n "$change_set_id" ]] && jq -e --arg cs "$change_set_id" '.change_set_id == $cs' <<<"$receipt" >/dev/null 2>&1; then
      continue
    fi
    if [[ -n "$predecessor" ]] && jq -e --arg pred "$predecessor" '.receipt_id == $pred' <<<"$receipt" >/dev/null 2>&1; then
      continue
    fi
    local updated
    updated="$(jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.superseded_at = $now' <<<"$receipt")"
    rt_atomic_write_json "$path" "$updated" 2>/dev/null || true
  done < <(rt_receipt_list_paths "$host" "$project_id" "$worktree_id" "$scope")
}

rt_receipt_create() {
  local scope="${1:-project}" entry_point="${2:-}" affected_servers_json="${3:-[]}" restart="${4:-false}"
  [[ "${RT_MODE:-verify}" == "apply" ]] || return 1
  rt_validate_authorization || return 1
  [[ "$restart" == "true" || "$restart" == "1" ]] || return 0

  local host project_id worktree_id receipt_id nonce change_set_id pre post expected action path lock_dir payload
  host="${RT_HOST:-cursor}"
  project_id="$(rt_project_id)"
  worktree_id="$(rt_worktree_id "${RT_PROJECT_ROOT:-}")"
  receipt_id="$(rt_receipt_random_id)"
  nonce="$(rt_receipt_random_nonce)"
  change_set_id="${RT_CHANGE_SET_ID:-$(rt_receipt_random_id)}"
  if [[ -n "${RT_PRE_CONFIG_HASHES:-}" ]]; then
    pre="$RT_PRE_CONFIG_HASHES"
  else
    pre="$(rt_current_config_hashes)"
  fi
  post="$(rt_current_config_hashes)"
  expected="$(rt_receipt_expected_tools_json "$affected_servers_json")"
  action="Tools & MCP → toggle affected servers off/on, then start a new chat; fallback Developer: Reload Window"

  path="$(rt_reload_receipt_path "$host" "$project_id" "$worktree_id" "$receipt_id" "$scope")"
  lock_dir="$(rt_reload_receipt_lock_dir "$host" "$project_id" "$worktree_id" "$scope")"
  rt_receipt_supersede_same_lineage "$host" "$project_id" "$worktree_id" "$scope" "$change_set_id" "" || true

  payload="$(jq -n \
    --arg schema "$RT_RECEIPT_SCHEMA" \
    --arg scope "$scope" \
    --arg receipt_id "$receipt_id" \
    --arg nonce "$nonce" \
    --arg change_set_id "$change_set_id" \
    --arg host "$host" \
    --arg project_id "${project_id:-unknown}" \
    --arg worktree_id "${worktree_id:-unknown}" \
    --arg project_root "${RT_PROJECT_ROOT:-}" \
    --arg worktree_root "${RT_PROJECT_ROOT:-}" \
    --arg entry_point "$entry_point" \
    --argjson pre "$pre" \
    --argjson post "$post" \
    --argjson affected "$affected_servers_json" \
    --argjson expected "$expected" \
    --arg action "$action" \
  '{
    schema: $schema,
    scope: $scope,
    receipt_id: $receipt_id,
    nonce: $nonce,
    change_set_id: $change_set_id,
    identities: {
      host: $host,
      project_id: $project_id,
      worktree_id: $worktree_id,
      project_root: $project_root,
      worktree_root: $worktree_root
    },
    entry_point: $entry_point,
    pre_config_hashes: $pre,
    post_config_hashes: $post,
    affected_servers: $affected,
    expected_tools: $expected,
    activation_status: "none",
    predecessor_receipt_id: null,
    required_user_action: $action,
    written_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    consumed_at: null,
    superseded_at: null
  }')"

  rt_with_lock "$lock_dir" 15 rt_atomic_write_json "$path" "$payload"
  printf '%s' "$payload"
}

rt_host_evidence_read_stdin() {
  local max="${RT_ATTESTATION_MAX_BYTES}"
  local raw size
  RT_HOST_EVIDENCE_ERROR=""
  RT_HOST_EVIDENCE_JSON=""
  raw="$(head -c "$((max + 1))")"
  size="${#raw}"
  if (( size > max )); then
    RT_HOST_EVIDENCE_ERROR="host_evidence_oversized"
    return 1
  fi
  if ! printf '%s' "$raw" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    RT_HOST_EVIDENCE_ERROR="host_evidence_invalid_json"
    return 1
  fi
  local trailing
  trailing="$(cat 2>/dev/null || true)"
  if [[ -n "$trailing" && "$trailing" != $'\n' ]]; then
    RT_HOST_EVIDENCE_ERROR="host_evidence_trailing_data"
    return 1
  fi
  RT_HOST_EVIDENCE_JSON="$(printf '%s' "$raw" | jq -c '.')"
  return 0
}

rt_attestation_parse_time_epoch() {
  local ts="${1:-}"
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
    || date -u -d "$ts" +%s 2>/dev/null \
    || return 1
}

rt_attestation_validate() {
  local attestation_json="${1:-}" receipt_json="${2:-}"
  local errors=() activation="none" clear_eligible=false valid=false
  local now observed age skew session_id

  if ! jq -e --arg schema "$RT_ATTESTATION_SCHEMA" '.schema == $schema' <<<"$attestation_json" >/dev/null 2>&1; then
    errors+=("schema_mismatch")
    jq -n --argjson errors "$(printf '%s\n' "${errors[@]}" | jq -R -s 'split("\n")|map(select(length>0))')" \
      --arg activation "$activation" --argjson clear_eligible false --argjson valid false \
      '{valid:$valid,activation_status:$activation,clear_eligible:$clear_eligible,errors:$errors}'
    return 0
  fi

  local rid nonce scope host pid wid
  rid="$(jq -r '.receipt_id // ""' <<<"$attestation_json")"
  nonce="$(jq -r '.nonce // ""' <<<"$attestation_json")"
  scope="$(jq -r '.scope // ""' <<<"$attestation_json")"
  host="$(jq -r '.host // ""' <<<"$attestation_json")"
  pid="$(jq -r '.project_id // ""' <<<"$attestation_json")"
  wid="$(jq -r '.worktree_id // ""' <<<"$attestation_json")"
  session_id="$(jq -r '.session_id // ""' <<<"$attestation_json")"
  observed="$(jq -r '.observed_at // ""' <<<"$attestation_json")"

  [[ -n "$receipt_json" ]] || errors+=("missing_receipt")
  [[ -n "$rid" && "$(jq -r '.receipt_id // ""' <<<"$receipt_json")" == "$rid" ]] || errors+=("receipt_id_mismatch")
  [[ -n "$nonce" && "$(jq -r '.nonce // ""' <<<"$receipt_json")" == "$nonce" ]] || errors+=("nonce_mismatch")
  [[ -n "$host" && "$(jq -r '.identities.host // ""' <<<"$receipt_json")" == "$host" ]] || errors+=("host_mismatch")
  [[ -n "$scope" && "$(jq -r '.scope // ""' <<<"$receipt_json")" == "$scope" ]] || errors+=("scope_mismatch")
  [[ -n "$pid" && "$(jq -r '.identities.project_id // ""' <<<"$receipt_json")" == "$pid" ]] || errors+=("project_id_mismatch")
  [[ -n "$wid" && "$(jq -r '.identities.worktree_id // ""' <<<"$receipt_json")" == "$wid" ]] || errors+=("worktree_id_mismatch")
  [[ -n "$session_id" ]] || errors+=("empty_session")
  jq -e '.consumed_at == null and (.superseded_at == null or .superseded_at == "")' <<<"$receipt_json" >/dev/null 2>&1 || errors+=("receipt_consumed_or_superseded")

  now="$(date +%s)"
  if observed_epoch="$(rt_attestation_parse_time_epoch "$observed" 2>/dev/null)"; then
    age=$((now - observed_epoch))
    skew=$((observed_epoch - now))
    (( age <= RT_ATTESTATION_MAX_AGE_SECONDS )) || errors+=("stale_attestation")
    (( skew <= RT_ATTESTATION_MAX_FUTURE_SKEW_SECONDS )) || errors+=("future_skew")
  else
    errors+=("invalid_observed_at")
  fi

  local current expected
  # Authorized apply may converge host config before attestation is evaluated — do not
  # require live hashes to match receipt post_config_hashes (repairs run first).
  if [[ "${RT_MODE:-verify}" != "apply" ]]; then
    current="$(rt_current_config_hashes)"
    expected="$(jq -r '.post_config_hashes // {}' <<<"$receipt_json")"
    if [[ "$(jq -r '.mcp // ""' <<<"$current")" != "$(jq -r '.mcp // ""' <<<"$expected")" ]]; then
      errors+=("mcp_hash_mismatch")
    fi
    if [[ "$(jq -r '.hooks // ""' <<<"$current")" != "$(jq -r '.hooks // ""' <<<"$expected")" ]]; then
      errors+=("hooks_hash_mismatch")
    fi
  fi

  expected="$(jq -r '.post_config_hashes // {}' <<<"$receipt_json")"
  local attestation_hashes
  attestation_hashes="$(jq -c '.config_hashes // {}' <<<"$attestation_json")"
  if [[ "$(jq -r '.mcp // ""' <<<"$attestation_hashes")" != "$(jq -r '.mcp // ""' <<<"$expected")" ]]; then
    errors+=("attestation_mcp_hash_mismatch")
  fi
  if [[ "$(jq -r '.hooks // ""' <<<"$attestation_hashes")" != "$(jq -r '.hooks // ""' <<<"$expected")" ]]; then
    errors+=("attestation_hooks_hash_mismatch")
  fi

  local server tool total=0 success=0 failure=0 missing=0 unexpected=0
  while IFS= read -r server; do
    [[ -n "$server" ]] || continue
    if ! jq -e --arg s "$server" '.servers[$s]' <<<"$attestation_json" >/dev/null 2>&1; then
      errors+=("missing_server:${server}")
      missing=$((missing + 1))
      continue
    fi
    while IFS= read -r tool; do
      [[ -n "$tool" ]] || continue
      total=$((total + 1))
      local status
      status="$(jq -r --arg s "$server" --arg t "$tool" \
        '.servers[$s].tools[]? | select(.id == $t) | .status // ""' <<<"$attestation_json" 2>/dev/null | head -1)"
      case "$status" in
        success) success=$((success + 1)) ;;
        failure) failure=$((failure + 1)) ;;
        *) errors+=("missing_tool:${server}/${tool}"); missing=$((missing + 1)) ;;
      esac
    done < <(jq -r --arg s "$server" '.expected_tools[$s][]?' <<<"$receipt_json")
    while IFS= read -r extra; do
      [[ -n "$extra" ]] || continue
      if ! jq -e --arg s "$server" --arg t "$extra" '.expected_tools[$s][]? | select(. == $t)' <<<"$receipt_json" >/dev/null 2>&1; then
        errors+=("unexpected_tool:${server}/${extra}")
        unexpected=$((unexpected + 1))
      fi
    done < <(jq -r --arg s "$server" '.servers[$s].tools[]?.id // empty' <<<"$attestation_json")
  done < <(jq -r '.expected_tools | keys[]?' <<<"$receipt_json" 2>/dev/null)

  if (( total > 0 && success == total )); then
    activation="full"
    clear_eligible=true
  elif (( success > 0 || failure > 0 )); then
    activation="partial"
    clear_eligible=false
  elif (( total == 0 )); then
    # hooks-only repairs: no MCP tools to attest; identity/hash checks suffice
    activation="full"
    if [[ ${#errors[@]} -eq 0 ]]; then
      clear_eligible=true
    else
      clear_eligible=false
    fi
  else
    activation="none"
    clear_eligible=false
  fi

  valid=false
  if [[ ${#errors[@]} -eq 0 ]]; then
    valid=true
  elif [[ "$activation" == "partial" || "$activation" == "none" ]] \
     && printf '%s\n' "${errors[@]}" | grep -qvE '^(missing_tool:|missing_server:)'; then
    valid=false
  elif [[ "$activation" == "partial" ]]; then
    valid=true
  fi

  jq -n \
    --argjson valid "$([[ "$valid" == true ]] && echo true || echo false)" \
    --arg activation "$activation" \
    --argjson clear_eligible "$([[ "$clear_eligible" == true ]] && echo true || echo false)" \
    --argjson errors "$(printf '%s\n' "${errors[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson totals "$(jq -n --argjson total "$total" --argjson success "$success" --argjson failure "$failure" \
      '{total:$total,success:$success,failure:$failure}')" \
    '{valid:$valid,activation_status:$activation,clear_eligible:$clear_eligible,errors:$errors,totals:$totals}'
}

rt_receipt_find_by_id() {
  local host="${1:-cursor}" receipt_id="${2:-}" scope="${3:-project}"
  local project_id="${4:-}" worktree_id="${5:-}"
  [[ -n "$receipt_id" ]] || return 1
  local path receipt
  path="$(rt_reload_receipt_path "$host" "$project_id" "$worktree_id" "$receipt_id" "$scope" 2>/dev/null || true)"
  if [[ -n "$path" ]]; then
    receipt="$(rt_receipt_read "$path" 2>/dev/null || true)"
    if [[ -n "$receipt" ]]; then
      printf '%s' "$receipt"
      return 0
    fi
  fi
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    receipt="$(rt_receipt_read "$path" 2>/dev/null || true)"
    [[ -n "$receipt" ]] || continue
    jq -e --arg rid "$receipt_id" '.receipt_id == $rid' <<<"$receipt" >/dev/null 2>&1 || continue
    printf '%s' "$receipt"
    return 0
  done < <(rt_receipt_list_paths "$host" "$project_id" "$worktree_id" "$scope")
  return 1
}

rt_receipt_consume_host_evidence() {
  local attestation="${RT_HOST_EVIDENCE_JSON:-}"
  [[ -n "$attestation" ]] || return 1
  [[ "${RT_MODE:-verify}" == "apply" ]] || return 1

  local rid scope host pid wid receipt attestation_eval
  rid="$(jq -r '.receipt_id // ""' <<<"$attestation")"
  scope="$(jq -r '.scope // "project"' <<<"$attestation")"
  host="$(jq -r '.host // "cursor"' <<<"$attestation")"
  pid="$(jq -r '.project_id // ""' <<<"$attestation")"
  wid="$(jq -r '.worktree_id // ""' <<<"$attestation")"
  [[ -n "$rid" ]] || return 1

  receipt="$(rt_receipt_find_by_id "$host" "$rid" "$scope" "$pid" "$wid" 2>/dev/null || true)"
  [[ -n "$receipt" ]] || return 1

  attestation_eval="$(rt_attestation_validate "$attestation" "$receipt")"
  RT_RECEIPT_EVAL_JSON="$attestation_eval"

  if jq -e '.valid == true and .clear_eligible == true' <<<"$attestation_eval" >/dev/null 2>&1; then
    rt_receipt_clear "$receipt" && export RT_SUPPRESS_RELOAD_RECEIPT_CREATE=1 RT_HOST_EVIDENCE_RECEIPT_CLEARED=1
    return 0
  fi
  return 1
}

rt_receipt_clear() {
  local receipt_json="${1:-}"
  local host project_id worktree_id scope receipt_id path lock_dir
  host="$(jq -r '.identities.host // "cursor"' <<<"$receipt_json")"
  project_id="$(jq -r '.identities.project_id // ""' <<<"$receipt_json")"
  worktree_id="$(jq -r '.identities.worktree_id // ""' <<<"$receipt_json")"
  scope="$(jq -r '.scope // "project"' <<<"$receipt_json")"
  receipt_id="$(jq -r '.receipt_id // ""' <<<"$receipt_json")"
  path="$(rt_reload_receipt_path "$host" "$project_id" "$worktree_id" "$receipt_id" "$scope")"
  lock_dir="$(rt_reload_receipt_lock_dir "$host" "$project_id" "$worktree_id" "$scope")"
  [[ -f "$path" ]] || return 1
  local updated
  updated="$(jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.consumed_at = $now | .activation_status = "full"' <<<"$receipt_json")"
  rt_with_lock "$lock_dir" 15 rt_atomic_write_json "$path" "$updated"
}

rt_reconcile_receipt_state() {
  local host project_id worktree_id receipt attestation_eval activation clear_eligible
  host="${RT_HOST:-cursor}"
  project_id="$(rt_project_id)"
  worktree_id="$(rt_worktree_id "${RT_PROJECT_ROOT:-}")"

  if [[ "${RT_HOST_EVIDENCE_RECEIPT_CLEARED:-0}" == "1" ]]; then
    local result attestation_payload activation_from_eval
    attestation_payload="${RT_RECEIPT_EVAL_JSON:-}"
    [[ -n "$attestation_payload" ]] || attestation_payload='{}'
    activation_from_eval="$(jq -r '.activation_status // "full"' <<<"$attestation_payload")"
    result="$(jq -n \
      --argjson has_receipt false \
      --arg canonical "ready" \
      --arg activation "$activation_from_eval" \
      --argjson clear_eligible true \
      --argjson attestation "$attestation_payload" \
      '{has_receipt:$has_receipt,canonical_state:$canonical,activation_status:$activation,clear_eligible:$clear_eligible,attestation:$attestation,errors:($attestation.errors // [])}')"
    RT_RECEIPT_EVAL_JSON="$result"
    printf '%s' "$result"
    return 0
  fi

  receipt=""
  if [[ -n "${RT_HOST_EVIDENCE_JSON:-}" ]]; then
    local rid scope att_pid att_wid att_host
    rid="$(jq -r '.receipt_id // ""' <<<"$RT_HOST_EVIDENCE_JSON")"
    scope="$(jq -r '.scope // "project"' <<<"$RT_HOST_EVIDENCE_JSON")"
    att_host="$(jq -r '.host // "cursor"' <<<"$RT_HOST_EVIDENCE_JSON")"
    att_pid="$(jq -r '.project_id // ""' <<<"$RT_HOST_EVIDENCE_JSON")"
    att_wid="$(jq -r '.worktree_id // ""' <<<"$RT_HOST_EVIDENCE_JSON")"
    if [[ -n "$rid" ]]; then
      receipt="$(rt_receipt_find_by_id "$att_host" "$rid" "$scope" "$att_pid" "$att_wid" 2>/dev/null || true)"
    fi
  fi
  if [[ -z "$receipt" ]]; then
    receipt="$(rt_receipt_find_active "$host" "$project_id" "$worktree_id" "project" 2>/dev/null || true)"
  fi
  if [[ -z "$receipt" ]]; then
    receipt="$(rt_receipt_find_active "$host" "$project_id" "$worktree_id" "host-global" 2>/dev/null || true)"
  fi

  local result
  result="$(jq -n \
    --argjson has_receipt "$([[ -n "$receipt" ]] && echo true || echo false)" \
    --arg canonical "$( [[ -n "$receipt" ]] && echo reload_required || echo ready)" \
    --arg activation "$(jq -r '.activation_status // "none"' <<<"${receipt:-{}}")" \
    --argjson clear_eligible false \
    '{has_receipt:$has_receipt,canonical_state:$canonical,activation_status:$activation,clear_eligible:$clear_eligible,errors:[]}')"

  if [[ -n "${RT_HOST_EVIDENCE_JSON:-}" && -n "$receipt" ]]; then
    attestation_eval="$(rt_attestation_validate "$RT_HOST_EVIDENCE_JSON" "$receipt")"
    activation="$(jq -r '.activation_status // "none"' <<<"$attestation_eval")"
    clear_eligible="$(jq -r '.clear_eligible // false' <<<"$attestation_eval")"
    if [[ "${RT_MODE:-verify}" == "apply" ]] && [[ "$clear_eligible" == "true" ]] \
       && jq -e '.valid == true' <<<"$attestation_eval" >/dev/null 2>&1; then
      rt_receipt_clear "$receipt" && receipt="" \
        && activation="full" && clear_eligible=true
    fi
    result="$(jq -n \
      --argjson has_receipt "$([[ -n "$receipt" ]] && echo true || echo false)" \
      --arg canonical "$( [[ -n "$receipt" ]] && echo reload_required || echo ready)" \
      --arg activation "$activation" \
      --argjson clear_eligible "$clear_eligible" \
      --argjson attestation "$attestation_eval" \
      '{has_receipt:$has_receipt,canonical_state:$canonical,activation_status:$activation,clear_eligible:$clear_eligible,attestation:$attestation,errors:($attestation.errors // [])}')"
  elif [[ -n "$receipt" ]]; then
    result="$(jq -n \
      --argjson has_receipt true \
      --arg canonical "reload_required" \
      --arg activation "$(jq -r '.activation_status // "none"' <<<"$receipt")" \
      --argjson clear_eligible false \
      '{has_receipt:true,canonical_state:$canonical,activation_status:$activation,clear_eligible:$clear_eligible,errors:[]}')"
  fi

  RT_RECEIPT_EVAL_JSON="$result"
  printf '%s' "$result"
}

# Shared host hooks + MCP convergence used by cross_tool repair and forced apply pass.
rt_apply_host_convergence_batches() {
  local create_receipt="${1:-true}"
  local actions=() failures=() restart=0 affected=() batch_json
  local pre_hashes change_set_id

  if ! rt_any_five_tool_mutation_allowed; then
    jq -n \
      --argjson actions '[]' --argjson failures '[]' --argjson restart false \
      --argjson changed false --argjson affected '[]' \
      '{actions:$actions,failures:$failures,restart_required:$restart,changed:$changed,affected_servers:$affected}'
    return 0
  fi

  pre_hashes="$(rt_current_config_hashes)"
  export RT_PRE_CONFIG_HASHES="$pre_hashes"
  change_set_id="$(rt_receipt_random_id)"
  export RT_CHANGE_SET_ID="$change_set_id"

  if rt_mutation_allowed graphify || rt_mutation_allowed agentmemory || rt_mutation_allowed rtk \
    || rt_mutation_allowed context_mode || rt_mutation_allowed leanctx; then
    batch_json="$(rt_apply_host_hooks_batch)"
    while IFS= read -r a; do
      [[ -n "$a" ]] && actions+=("$a")
    done < <(printf '%s' "$batch_json" | jq -r '.actions[]? // empty')
    while IFS= read -r f; do
      [[ -n "$f" ]] && failures+=("$f")
    done < <(printf '%s' "$batch_json" | jq -r '.failures[]? // empty')
    if printf '%s' "$batch_json" | jq -e '.changed == true' >/dev/null 2>&1; then
      restart=1
      rt_mutation_allowed context_mode && affected+=("context-mode")
    fi
  fi

  if rt_mutation_allowed graphify || rt_mutation_allowed leanctx || rt_mutation_allowed agentmemory; then
    batch_json="$(rt_apply_host_mcp_batch)"
    while IFS= read -r a; do
      [[ -n "$a" ]] && actions+=("$a")
    done < <(printf '%s' "$batch_json" | jq -r '.actions[]? // empty')
    while IFS= read -r f; do
      [[ -n "$f" ]] && failures+=("$f")
    done < <(printf '%s' "$batch_json" | jq -r '.failures[]? // empty')
    if printf '%s' "$batch_json" | jq -e '.changed == true' >/dev/null 2>&1; then
      restart=1
      rt_mutation_allowed graphify && affected+=("graphify")
      rt_mutation_allowed leanctx && affected+=("leanctx")
      rt_mutation_allowed agentmemory && affected+=("agentmemory")
    fi
  fi

  if [[ $restart -eq 1 && "$create_receipt" == "true" && "${RT_SUPPRESS_RELOAD_RECEIPT_CREATE:-0}" != "1" ]]; then
    local servers_json
    if [[ ${#affected[@]} -gt 0 ]]; then
      servers_json="$(printf '%s\n' "${affected[@]}" | jq -R -s 'split("\n")|map(select(length>0))')"
    else
      servers_json='[]'
    fi
    RT_PRE_CONFIG_HASHES="$pre_hashes"
    rt_receipt_create "project" "${RT_ENTRY_POINT:-doctor-fix}" "$servers_json" true >/dev/null 2>&1 \
      && actions+=("reload_receipt_created") || failures+=("reload_receipt_failed")
  fi

  unset RT_PRE_CONFIG_HASHES RT_CHANGE_SET_ID
  jq -n \
    --argjson actions "$(rt_json_string_array ${actions[@]+"${actions[@]}"})" \
    --argjson failures "$(rt_json_string_array ${failures[@]+"${failures[@]}"})" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    --argjson changed "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    --argjson affected "$(rt_json_string_array ${affected[@]+"${affected[@]}"})" \
    '{actions:$actions,failures:$failures,restart_required:$restart,changed:$changed,affected_servers:$affected}'
}

rt_apply_host_hooks_batch() {
  local repo="${RT_REPO_ROOT:-}" actions=() failures=() changed=0 patch_any=0
  local hooks_pre hooks_post patch_out fix_out
  # Claude and Codex own their hook formats and lifecycle; their installers
  # wire RTK/Context Mode directly. Never invoke the Cursor JSON patcher for a
  # different host, because that silently creates a foreign-host config.
  if [[ "${RT_HOST:-cursor}" != "cursor" ]]; then
    jq -n \
      --argjson actions '[]' --argjson failures '[]' --argjson changed false \
      '{actions:$actions,failures:$failures,changed:$changed}'
    return 0
  fi
  [[ -f "${repo}/scripts/lib/global-toolstack/patch-hooks.py" ]] || {
    jq -n \
      --argjson actions '[]' --argjson failures '[]' --argjson changed false \
      '{actions:$actions,failures:$failures,changed:$changed}'
    return 0
  }
  export TOOLSTACK_REPO_ROOT="$repo"
  if rt_mutation_allowed graphify; then
    export RT_PATCH_GRAPHIFY=1
    patch_any=1
  else
    export RT_PATCH_GRAPHIFY=0
  fi
  if rt_mutation_allowed agentmemory; then
    export RT_PATCH_AGENTMEMORY=1
    patch_any=1
  else
    export RT_PATCH_AGENTMEMORY=0
  fi
  if rt_mutation_allowed context_mode; then
    export RT_PATCH_CONTEXT_MODE=1
    patch_any=1
  else
    export RT_PATCH_CONTEXT_MODE=0
  fi
  if rt_mutation_allowed rtk; then
    export RT_PATCH_RTK=1
    patch_any=1
  else
    export RT_PATCH_RTK=0
  fi
  if rt_mutation_allowed leanctx; then
    export RT_PATCH_LEANCTX=1
    patch_any=1
  else
    export RT_PATCH_LEANCTX=0
  fi
  if [[ $patch_any -eq 1 ]]; then
    hooks_pre="$(rt_config_hash_file "${HOME}/.cursor/hooks.json")"
    patch_out="$(python3 "${repo}/scripts/lib/global-toolstack/patch-hooks.py" 2>&1)" || {
      failures+=("patch_hooks_failed")
      patch_out=""
    }
    if [[ -n "$patch_out" ]]; then
      hooks_post="$(rt_config_hash_file "${HOME}/.cursor/hooks.json")"
      if ! rt_patcher_output_unchanged "$patch_out" \
         && rt_config_hash_changed "$hooks_pre" "$hooks_post"; then
        actions+=("patch_hooks")
        changed=1
      fi
    fi
  fi
  unset RT_PATCH_GRAPHIFY RT_PATCH_AGENTMEMORY RT_PATCH_RTK RT_PATCH_CONTEXT_MODE RT_PATCH_LEANCTX
  jq -n \
    --argjson actions "$(rt_json_string_array ${actions[@]+"${actions[@]}"})" \
    --argjson failures "$(rt_json_string_array ${failures[@]+"${failures[@]}"})" \
    --argjson changed "$([[ $changed -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,changed:$changed}'
}

rt_apply_host_mcp_batch() {
  local repo="${RT_REPO_ROOT:-}" actions=() failures=() changed=0
  local mcp_pre mcp_post patch_out
  [[ -f "${repo}/scripts/lib/global-toolstack/patch-mcp.py" ]] || {
    jq -n \
      --argjson actions '[]' --argjson failures '[]' --argjson changed false \
      '{actions:$actions,failures:$failures,changed:$changed}'
    return 0
  }
  export TOOLSTACK_REPO_ROOT="$repo"
  if rt_mutation_allowed graphify; then
    export RT_PATCH_GRAPHIFY=1
  else
    export RT_PATCH_GRAPHIFY=0
  fi
  if rt_mutation_allowed leanctx; then
    export RT_PATCH_LEANCTX=1
  else
    export RT_PATCH_LEANCTX=0
  fi
  if rt_mutation_allowed agentmemory; then
    export RT_PATCH_AGENTMEMORY=1
  else
    export RT_PATCH_AGENTMEMORY=0
  fi
  if rt_mutation_allowed context_mode; then
    export RT_PATCH_CONTEXT_MODE=1
  else
    export RT_PATCH_CONTEXT_MODE=0
  fi
  if [[ "${RT_PATCH_GRAPHIFY:-0}" == "1" || "${RT_PATCH_LEANCTX:-0}" == "1" || "${RT_PATCH_AGENTMEMORY:-0}" == "1" || "${RT_PATCH_CONTEXT_MODE:-0}" == "1" ]]; then
    local mcp_path
    mcp_path="$(rt_host_mcp_config_path "${RT_HOST:-cursor}")"
    mcp_pre="$(rt_config_hash_file "$mcp_path")"
    patch_out="$(RT_HOST="${RT_HOST:-cursor}" python3 "${repo}/scripts/lib/global-toolstack/patch-mcp.py" 2>&1)" || {
      failures+=("patch_mcp_failed")
      patch_out=""
    }
    if [[ -n "$patch_out" ]]; then
      mcp_post="$(rt_config_hash_file "$mcp_path")"
      if ! rt_patcher_output_unchanged "$patch_out" \
         && rt_config_hash_changed "$mcp_pre" "$mcp_post"; then
        actions+=("patch_mcp")
        changed=1
      fi
    fi
  fi
  unset RT_PATCH_GRAPHIFY RT_PATCH_LEANCTX RT_PATCH_AGENTMEMORY RT_PATCH_CONTEXT_MODE
  jq -n \
    --argjson actions "$(rt_json_string_array ${actions[@]+"${actions[@]}"})" \
    --argjson failures "$(rt_json_string_array ${failures[@]+"${failures[@]}"})" \
    --argjson changed "$([[ $changed -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,changed:$changed}'
}
