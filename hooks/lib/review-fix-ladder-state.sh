# shellcheck shell=bash
# Session-scoped review-fix-ladder state machine (AF-REVIEW-TRIAGE).

sb_rfl_guard_disabled() {
  [[ "${SB_REVIEW_FIX_LADDER_GUARD:-1}" == "0" ]]
}

sb_rfl_state_file() {
  printf '%s/review-fix-ladder-state.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_rfl_is_active() {
  sb_rfl_guard_disabled && return 1
  local file
  file="$(sb_rfl_state_file)"
  [[ -f "$file" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    [[ "$(jq -r '.active // false' "$file" 2>/dev/null)" == "true" ]]
    return $?
  fi
  grep -q '"active"[[:space:]]*:[[:space:]]*true' "$file" 2>/dev/null
}

sb_rfl_read_field() {
  local field="${1:-}" default="${2:-}"
  local file
  file="$(sb_rfl_state_file)"
  [[ -n "$field" ]] || { printf '%s' "$default"; return 0; }
  [[ -f "$file" ]] || { printf '%s' "$default"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$field" --arg d "$default" '.[$f] // $d' "$file" 2>/dev/null || printf '%s' "$default"
    return 0
  fi
  printf '%s' "$default"
}

sb_rfl_write_state() {
  local json="$1"
  local file
  file="$(sb_rfl_state_file)"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$json" >"$file"
}

sb_rfl_project_root() {
  if [[ -n "${SB_RFL_PROJECT_ROOT:-}" ]]; then
    printf '%s' "$SB_RFL_PROJECT_ROOT"
    return 0
  fi
  if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
    local cfg
    cfg="$(sb_find_project_config_walk_only 2>/dev/null || true)"
    if [[ -n "$cfg" ]]; then
      dirname "$cfg"
      return 0
    fi
  fi
  printf '%s' "${PWD:-.}"
}

sb_rfl_resolver_json() {
  local project_root="${1:-}"
  [[ -n "$project_root" ]] || project_root="$(sb_rfl_project_root)"
  local resolver="${project_root%/}/scripts/review-fix-ladder.py"
  if [[ ! -f "$resolver" ]]; then
    printf '{}'
    return 1
  fi
  SB_CURSOR_SB_AGENTS_SKIP_PROBE=1 python3 "$resolver" --host cursor --json --project-root "$project_root" 2>/dev/null || printf '{}'
}

sb_rfl_total_rungs_from_resolver() {
  local resolver_json="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '(.total_rungs // (.rungs | length) // 6)' <<<"$resolver_json"
  else
    printf '6'
  fi
}

sb_rfl_rung_from_resolver() {
  local resolver_json="$1" rung_index="${2:-1}"
  if command -v jq >/dev/null 2>&1; then
    jq -c --argjson idx "$rung_index" '.rungs[$idx - 1] // {}' <<<"$resolver_json"
  else
    printf '{}'
  fi
}

sb_rfl_sync_rung_metadata() {
  local rung="${1:-1}"
  local project_root resolver_json rung_json subagent_name model_param
  project_root="$(sb_rfl_project_root)"
  resolver_json="$(sb_rfl_resolver_json "$project_root")"
  rung_json="$(sb_rfl_rung_from_resolver "$resolver_json" "$rung")"
  command -v jq >/dev/null 2>&1 || return 0
  subagent_name="$(jq -r '.subagent_name // empty' <<<"$rung_json")"
  model_param="$(jq -r '.model_param // empty' <<<"$rung_json")"
  [[ -n "$subagent_name" ]] && sb_rfl_set_field subagent_name "$subagent_name"
  [[ -n "$model_param" ]] && sb_rfl_set_field model_param "$model_param"
  [[ -n "$model_param" ]] && sb_rfl_set_field rung_model "$model_param"
}

sb_rfl_activate() {
  local rung="${1:-1}" rung_model="${2:-}" host_model="${3:-composer-2.5}"
  local project_root resolver_json total_rungs rung_json subagent_name model_param state_json
  project_root="$(sb_rfl_project_root)"
  resolver_json="$(sb_rfl_resolver_json "$project_root")"
  total_rungs="$(sb_rfl_total_rungs_from_resolver "$resolver_json")"
  rung_json="$(sb_rfl_rung_from_resolver "$resolver_json" "$rung")"
  if command -v jq >/dev/null 2>&1; then
    subagent_name="$(jq -r '.subagent_name // empty' <<<"$rung_json")"
    model_param="$(jq -r '.model_param // empty' <<<"$rung_json")"
    [[ -z "$rung_model" && -n "$model_param" ]] && rung_model="$model_param"
    [[ -z "$rung_model" ]] && rung_model="composer-2.5"
    state_json="$(jq -n \
      --argjson rung "$rung" \
      --argjson total "$total_rungs" \
      --arg rung_model "$rung_model" \
      --arg host_model "$host_model" \
      --arg subagent_name "$subagent_name" \
      --arg model_param "$model_param" \
      '{
        active: true,
        rung: $rung,
        total_rungs: $total,
        phase: "review",
        rung_model: $rung_model,
        host_model: $host_model,
        subagent_name: (if $subagent_name == "" then null else $subagent_name end),
        model_param: (if $model_param == "" then null else $model_param end),
        subscription_quota_fallback: false,
        pm_filed: false,
        verify_pass: 0,
        grep_after_verify: 0,
        compliance_stop: false
      }')"
    sb_rfl_write_state "$state_json"
  else
    [[ -z "$rung_model" ]] && rung_model="composer-2.5"
    sb_rfl_write_state "{\"active\":true,\"rung\":${rung},\"total_rungs\":${total_rungs},\"phase\":\"review\",\"rung_model\":\"${rung_model}\",\"host_model\":\"${host_model}\",\"pm_filed\":false,\"verify_pass\":0}"
  fi
}

sb_rfl_deactivate() {
  rm -f -- "$(sb_rfl_state_file)" 2>/dev/null || true
}

sb_rfl_reset() {
  local rung="${1:-1}" rung_model="${2:-composer-2.5}" host_model="${3:-composer-2.5}"
  sb_rfl_deactivate
  sb_rfl_activate "$rung" "$rung_model" "$host_model"
}

sb_rfl_set_field() {
  local field="$1" value="$2"
  local file
  file="$(sb_rfl_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

sb_rfl_set_bool() {
  local field="$1" value="$2"
  local file
  file="$(sb_rfl_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq --arg f "$field" --argjson v "$value" '.[$f] = $v' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

sb_rfl_mark_pm_filed() {
  sb_rfl_set_bool pm_filed true
  local phase
  phase="$(sb_rfl_read_field phase "")"
  [[ "$phase" == "file_valid_issues" ]] && sb_rfl_set_field phase fix_parallel
}

sb_rfl_mark_orchestrator_grep() {
  local pass
  pass="$(sb_rfl_read_field grep_after_verify 0)"
  if [[ "$pass" == "0" ]]; then
    sb_rfl_set_field grep_after_verify 1
    sb_rfl_set_field phase verify_2
  elif [[ "$pass" == "1" ]]; then
    sb_rfl_set_field grep_after_verify 2
    sb_rfl_advance_rung
  fi
}

sb_rfl_advance_rung() {
  local file rung total
  file="$(sb_rfl_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  rung="$(sb_rfl_read_field rung 1)"
  total="$(sb_rfl_read_field total_rungs 6)"
  if (( rung >= total )); then
    sb_rfl_deactivate
    return 0
  fi
  jq --argjson next "$((rung + 1))" \
    '.rung = $next | .phase = "review" | .pm_filed = false | .verify_pass = 0 | .grep_after_verify = 0 | .subscription_quota_fallback = false | .subscription_quota_host = "" | .subscription_quota_signal = ""' \
    "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
  sb_rfl_sync_rung_metadata "$((rung + 1))"
}

sb_rfl_compliance_stop() {
  local reason="$1"
  sb_rfl_set_bool compliance_stop true
  sb_rfl_set_field stop_reason "$reason"
}

sb_rfl_prompt_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

sb_rfl_prompt_phase_hint() {
  local prompt="$1"
  local lower
  lower="$(sb_rfl_prompt_lower "$prompt")"
  if printf '%s' "$lower" | grep -qiE 'rung_[0-9]+_review|review-only|raw findings only|review_raw'; then
    printf 'review'
  elif printf '%s' "$lower" | grep -qiE '/sb:triage|sb:triage|rung_[0-9]+_triage|triage_pass|classify'; then
    printf 'triage'
  elif printf '%s' "$lower" | grep -qiE 'rung_[0-9]+_fix|fix subagent|fix_pass|apply accept'; then
    printf 'fix'
  elif printf '%s' "$lower" | grep -qiE 'verify_2|second verify|verify pass 2'; then
    printf 'verify_2'
  elif printf '%s' "$lower" | grep -qiE 'verify-only|verify_1|readonly:\s*true|ladder_pass'; then
    printf 'verify_1'
  else
    printf 'unknown'
  fi
}

sb_rfl_prompt_has_combined_verify() {
  local prompt="$1"
  local lower
  lower="$(sb_rfl_prompt_lower "$prompt")"
  printf '%s' "$lower" | grep -qiE 'verify_1.*verify_2|two consecutive verify|2 verify pass|both verify pass|do 2 passes|two passes in one'
}

sb_rfl_prompt_has_review_triage_mix() {
  local prompt="$1"
  local lower
  lower="$(sb_rfl_prompt_lower "$prompt")"
  local has_review=0 has_triage=0
  printf '%s' "$lower" | grep -qiE 'review-only|raw findings' && has_review=1
  printf '%s' "$lower" | grep -qiE 'sb:triage|/sb:triage|valid-blocker|valid-nonblocker|triage_pass' && has_triage=1
  [[ "$has_review" -eq 1 && "$has_triage" -eq 1 ]]
}

sb_rfl_subagent_requires_subscription_first() {
  local name="$1"
  [[ "$name" == sb-gpt-* || "$name" == sb-opus-* || "$name" == sb-claude-* ]]
}

sb_rfl_mark_subscription_quota_fallback() {
  local host="${1:-}" signal="${2:-}"
  sb_rfl_set_bool subscription_quota_fallback true || return 1
  [[ -n "$host" ]] && sb_rfl_set_field subscription_quota_host "$host"
  [[ -n "$signal" ]] && sb_rfl_set_field subscription_quota_signal "$signal"
  return 0
}

sb_rfl_clear_subscription_quota_fallback() {
  sb_rfl_set_bool subscription_quota_fallback false || return 0
  sb_rfl_set_field subscription_quota_host "" || true
  sb_rfl_set_field subscription_quota_signal "" || true
}

sb_rfl_subscription_cursor_task_denied() {
  local name="$1"
  sb_rfl_subagent_requires_subscription_first "$name" || return 1
  [[ "$(sb_rfl_read_field subscription_quota_fallback false)" == "true" ]] && return 1
  return 0
}

sb_rfl_deny_unqualified_subscription_task() {
  local name="$1"
  [[ -n "$name" ]] || return 0
  sb_rfl_subscription_cursor_task_denied "$name" || return 0
  printf '%s' "Review-fix-ladder: ${name} requires subscription-first (/sb:agent-codex for GPT, /sb:agent-claude for Claude/Opus). Cursor Task is allowed only after quota exhaustion. Record with: python3 scripts/review-fix-ladder.py --mark-quota-fallback --quota-host <codex|claude> --quota-signal '<matched signal>'."
  return 1
}

sb_rfl_validate_task_spawn() {
  local prompt="$1" model="${2:-}" readonly_flag="${3:-}" subagent_type="${4:-}"
  local phase rung_model host_model pm_filed hint rung prompt_rung expected_subagent custom_subagent

  sb_rfl_is_active || return 0
  [[ "$(sb_rfl_read_field compliance_stop false)" == "true" ]] && return 0

  phase="$(sb_rfl_read_field phase review)"
  rung_model="$(sb_rfl_read_field rung_model "")"
  host_model="$(sb_rfl_read_field host_model "")"
  pm_filed="$(sb_rfl_read_field pm_filed false)"
  hint="$(sb_rfl_prompt_phase_hint "$prompt")"

  if sb_rfl_prompt_has_combined_verify "$prompt"; then
    printf '%s' "Review-fix-ladder: FORBIDDEN combined verify passes in one Task — use separate verify_1 and verify_2 subagent calls."
    return 1
  fi

  case "$phase" in
    review)
      if [[ "$hint" == "triage" || "$hint" == "fix" ]]; then
        printf '%s' "Review-fix-ladder: rung review phase — Task must be review-only (no triage or fix in the same subagent)."
        return 1
      fi
      if sb_rfl_prompt_has_review_triage_mix "$prompt"; then
        printf '%s' "Review-fix-ladder: review subagent must not triage — separate review and triage Task calls."
        return 1
      fi
      expected_subagent="$(sb_rfl_read_field subagent_name "")"
      if [[ -n "$expected_subagent" ]]; then
        if [[ -z "$subagent_type" ]]; then
          printf '%s' "Review-fix-ladder: review phase requires subagent_type ${expected_subagent}."
          return 1
        fi
        if [[ "$subagent_type" != "$expected_subagent" ]]; then
          printf '%s' "Review-fix-ladder: review phase requires subagent_type ${expected_subagent} (got ${subagent_type})."
          return 1
        fi
      fi
      sb_rfl_deny_unqualified_subscription_task "${subagent_type:-$expected_subagent}" || return 1
      custom_subagent=0
      [[ -n "$expected_subagent" && "$subagent_type" == "$expected_subagent" ]] && custom_subagent=1
      if [[ "$custom_subagent" -eq 0 && -n "$model" && -n "$rung_model" && "$model" != "$rung_model" ]]; then
        printf '%s' "Review-fix-ladder: review phase requires rung model ${rung_model} (got ${model})."
        return 1
      fi
      ;;
    triage)
      if [[ "$hint" == "review" ]]; then
        printf '%s' "Review-fix-ladder: triage phase — do not spawn a review-only Task; invoke /sb:triage at host model."
        return 1
      fi
      if [[ -n "$model" && -n "$host_model" && -n "$rung_model" && "$model" == "$rung_model" && "$host_model" != "$rung_model" ]]; then
        printf '%s' "Review-fix-ladder: triage must use host model ${host_model}, not rung model ${rung_model}."
        return 1
      fi
      ;;
    file_valid_issues)
      printf '%s' "Review-fix-ladder: file_valid_issues phase — orchestrator files PM items before fix Tasks (no Task spawn)."
      return 1
      ;;
    fix_parallel)
      if [[ "$pm_filed" != "true" ]]; then
        printf '%s' "Review-fix-ladder: fix_parallel blocked — file valid issues via /sb:add before fix subagents."
        return 1
      fi
      if [[ "$hint" == "review" || "$hint" == "triage" ]]; then
        printf '%s' "Review-fix-ladder: fix_parallel phase — spawn fix subagent only."
        return 1
      fi
      ;;
    verify_1)
      expected_subagent="$(sb_rfl_read_field subagent_name "")"
      if [[ -n "$expected_subagent" ]]; then
        if [[ -z "$subagent_type" ]]; then
          printf '%s' "Review-fix-ladder: verify_1 requires subagent_type ${expected_subagent}."
          return 1
        fi
        if [[ "$subagent_type" != "$expected_subagent" ]]; then
          printf '%s' "Review-fix-ladder: verify_1 requires subagent_type ${expected_subagent} (got ${subagent_type})."
          return 1
        fi
      fi
      sb_rfl_deny_unqualified_subscription_task "${subagent_type:-$expected_subagent}" || return 1
      if [[ "$hint" == "fix" || "$hint" == "triage" ]]; then
        printf '%s' "Review-fix-ladder: verify_1 — verify-only subagent (readonly), no fix or triage."
        return 1
      fi
      if [[ "$hint" == "verify_2" ]]; then
        printf '%s' "Review-fix-ladder: verify_1 must complete before verify_2 — separate Task calls."
        return 1
      fi
      if [[ "$readonly_flag" != "true" && "$readonly_flag" != "True" ]]; then
        printf '%s' "Review-fix-ladder: verify pass requires readonly: true on Task (or verify-only directive)."
        return 1
      fi
      ;;
    verify_2)
      expected_subagent="$(sb_rfl_read_field subagent_name "")"
      if [[ -n "$expected_subagent" ]]; then
        if [[ -z "$subagent_type" ]]; then
          printf '%s' "Review-fix-ladder: verify_2 requires subagent_type ${expected_subagent}."
          return 1
        fi
        if [[ "$subagent_type" != "$expected_subagent" ]]; then
          printf '%s' "Review-fix-ladder: verify_2 requires subagent_type ${expected_subagent} (got ${subagent_type})."
          return 1
        fi
      fi
      sb_rfl_deny_unqualified_subscription_task "${subagent_type:-$expected_subagent}" || return 1
      if [[ "$hint" == "fix" || "$hint" == "triage" || "$hint" == "verify_1" ]]; then
        printf '%s' "Review-fix-ladder: verify_2 — second verify-only pass only."
        return 1
      fi
      if [[ "$readonly_flag" != "true" && "$readonly_flag" != "True" ]]; then
        printf '%s' "Review-fix-ladder: verify pass requires readonly: true on Task (or verify-only directive)."
        return 1
      fi
      ;;
    orchestrator_grep_1|orchestrator_grep_2)
      printf '%s' "Review-fix-ladder: orchestrator grep between verify passes — run charter signals before the next verify Task."
      return 1
      ;;
  esac

  prompt_rung="$(printf '%s' "$prompt" | grep -oiE 'rung_[0-9]+' | head -1 | sed 's/rung_//')"
  rung="$(sb_rfl_read_field rung 1)"
  if [[ -n "$prompt_rung" && "$prompt_rung" != "$rung" ]]; then
    printf '%s' "Review-fix-ladder: parallel rung launch blocked — active rung ${rung}, prompt references rung ${prompt_rung}."
    return 1
  fi

  return 0
}

sb_rfl_advance_after_task() {
  local prompt="$1"
  local phase hint
  sb_rfl_is_active || return 0
  [[ "$(sb_rfl_read_field compliance_stop false)" == "true" ]] && return 0

  phase="$(sb_rfl_read_field phase review)"
  hint="$(sb_rfl_prompt_phase_hint "$prompt")"

  case "$phase" in
    review)
      [[ "$hint" == "review" || "$hint" == "unknown" ]] && sb_rfl_set_field phase triage
      sb_rfl_clear_subscription_quota_fallback
      ;;
    triage)
      [[ "$hint" == "triage" || "$hint" == "unknown" ]] && sb_rfl_set_field phase file_valid_issues
      ;;
    fix_parallel)
      [[ "$hint" == "fix" || "$hint" == "unknown" ]] && sb_rfl_set_field phase verify_1
      ;;
    verify_1)
      [[ "$hint" == "verify_1" || "$hint" == "unknown" ]] && sb_rfl_set_field phase orchestrator_grep_1
      sb_rfl_clear_subscription_quota_fallback
      ;;
    verify_2)
      [[ "$hint" == "verify_2" || "$hint" == "unknown" ]] && sb_rfl_set_field phase orchestrator_grep_2
      sb_rfl_clear_subscription_quota_fallback
      ;;
  esac
}

sb_rfl_detect_pm_filing_command() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -qiE 'silver-add\.sh|adapter-create|gh issue create|/sb:add|sb:add'
}

sb_rfl_on_skill_invoke() {
  local skill="$1"
  case "$skill" in
    silver-review-fix-ladder|sb:review-fix-ladder|review-fix-ladder)
      sb_rfl_activate 1 "" composer-2.5
      ;;
  esac
}
