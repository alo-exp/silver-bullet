# shellcheck shell=bash
# Cross-tool route ownership, hook order, heartbeat, convergence.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=heartbeat.sh
source "$(dirname "${BASH_SOURCE[0]}")/heartbeat.sh"
# shellcheck source=receipts.sh
source "$(dirname "${BASH_SOURCE[0]}")/receipts.sh"
# shellcheck source=probe-rtk.sh
source "$(dirname "${BASH_SOURCE[0]}")/probe-rtk.sh"

rt_probe_five_tool_routes() {
  local cfg="${RT_CONFIG_FILE:-$(rt_project_config)}"
  [[ -f "$cfg" ]] || return 1
  local entry route expected owner
  for entry in "${RT_FIVE_TOOL_ROUTES[@]}"; do
    route="${entry%%:*}"
    expected="${entry#*:}"
    owner="$(jq -r --arg p "five_tool_routed" --arg r "$route" \
      '.optimization_profiles[$p].routes[$r] // empty' "$cfg" 2>/dev/null)"
    [[ "$owner" == "$expected" ]] || return 1
  done
  return 0
}

rt_any_five_tool_consented() {
  local tool consent
  for tool in graphify agentmemory rtk context_mode leanctx; do
    consent="$(rt_consent_for "$tool")"
    [[ "$consent" == "enabled" ]] && return 0
  done
  return 1
}

rt_probe_cross_tool() {
  local tool_id="cross_tool" consent="n/a" activation="none" canonical repairable=0
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0

  if ! rt_host_supported "${RT_HOST:-cursor}"; then fu=1
  elif ! rt_any_five_tool_consented; then
    fr=1
    activation="none"
    evidence+=("no_five_tool_consent")
  else
    if ! rt_probe_five_tool_routes; then frp=1; repairable=1; evidence+=("route_ownership_drift")
    elif ! rt_probe_rtk_shell_owner; then frp=1; repairable=1; evidence+=("shell_owner_not_rtk")
    elif ! rt_probe_rtk_leanctx_rewrite_absent; then frp=1; repairable=1; evidence+=("leanctx_shell_rewrite")
    elif ! rt_probe_rtk_before_cm; then frp=1; repairable=1; evidence+=("hook_order_rtk_after_cm")
    else
      local hb_path project_id worktree_id session_id
      project_id="$(rt_project_id)"
      worktree_id="$(rt_worktree_id "${RT_PROJECT_ROOT:-}")"
      session_id="$(rt_current_session_id)"
      hb_path="$(rt_heartbeat_path "$project_id" "$worktree_id" "$session_id" 2>/dev/null || true)"
      if [[ -n "$hb_path" ]] && rt_heartbeat_is_valid "$hb_path" "${RT_HOST:-cursor}" "${RT_PROJECT_ROOT:-}" "${RT_PROJECT_ROOT:-}"; then
        activation="full"
        fr=1
      else
        evidence+=("heartbeat_absent_or_invalid")
        frp=1
        repairable=1
      fi
    fi
  fi

  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_cross_tool() {
  local actions=() failures=() restart=0 conv_json
  if [[ "${RT_MODE:-verify}" != "apply" ]] || ! rt_validate_authorization; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi

  conv_json="$(rt_apply_host_convergence_batches true)"
  while IFS= read -r a; do
    [[ -n "$a" ]] && actions+=("$a")
  done < <(printf '%s' "$conv_json" | jq -r '.actions[]? // empty')
  while IFS= read -r f; do
    [[ -n "$f" ]] && failures+=("$f")
  done < <(printf '%s' "$conv_json" | jq -r '.failures[]? // empty')
  [[ "$(printf '%s' "$conv_json" | jq -r '.restart_required // false')" == "true" ]] && restart=1

  rt_heartbeat_write "${RT_PROJECT_ROOT:-}" "${RT_HOST:-cursor}" && actions+=("heartbeat_written") \
    || failures+=("heartbeat_write_failed")

  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
