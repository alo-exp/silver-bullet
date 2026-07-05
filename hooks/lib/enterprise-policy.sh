# shellcheck shell=bash
# Enterprise policy profiles — config contract + runtime consumers (Phase B+D).

sb_enterprise_policy_allowed_session_modes() {
  printf '%s' 'interactive autonomous'
}

sb_enterprise_policy_read_active() {
  local config_file="$1"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local profile
  profile="$(jq -r '.enterprise_policy.active_profile // empty' "$config_file" 2>/dev/null || true)"
  [[ -n "$profile" && "$profile" != "null" ]] || return 1
  printf '%s' "$profile"
}

sb_enterprise_policy_profile_field() {
  local config_file="$1" profile_key="$2" field="$3"
  [[ -n "$config_file" && -f "$config_file" && -n "$profile_key" && -n "$field" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local value
  value="$(jq -r --arg p "$profile_key" --arg f "$field" \
    '.enterprise_policy.profiles[$p][$f] // empty' "$config_file" 2>/dev/null || true)"
  [[ -n "$value" && "$value" != "null" ]] || return 1
  printf '%s' "$value"
}

sb_enterprise_policy_session_mode_default() {
  local config_file="$1"
  local active mode
  active="$(sb_enterprise_policy_read_active "$config_file")" || { printf 'interactive'; return 0; }
  mode="$(sb_enterprise_policy_profile_field "$config_file" "$active" session_mode_default)" || mode="interactive"
  case "$mode" in
    autonomous|interactive) printf '%s' "$mode" ;;
    *) printf 'interactive' ;;
  esac
}

# Tier ≥ 2 (hook-enforced) — safe to auto-apply autonomous session defaults.
sb_enterprise_policy_host_tier_safe() {
  local config_file="$1"
  local tier lib_dir
  lib_dir="$(dirname "${BASH_SOURCE[0]}")"
  if [[ -f "${lib_dir}/enforcement-tier-gate.sh" ]]; then
    # shellcheck source=lib/enforcement-tier-gate.sh
    source "${lib_dir}/enforcement-tier-gate.sh"
  fi
  if ! declare -f sb_enforcement_tier_effective >/dev/null 2>&1; then
    return 1
  fi
  tier="$(sb_enforcement_tier_effective "$config_file" 2>/dev/null || echo 0)"
  [[ "${tier:-0}" -ge 2 ]]
}

sb_enterprise_policy_profile_auto_sets_autonomous() {
  local profile_key="$1"
  case "$profile_key" in
    autonomous_safe|internal_dogfood) return 0 ;;
    *) return 1 ;;
  esac
}

sb_enterprise_policy_should_auto_set_session_mode() {
  local config_file="$1"
  local active mode_default
  active="$(sb_enterprise_policy_read_active "$config_file")" || return 1
  sb_enterprise_policy_profile_auto_sets_autonomous "$active" || return 1
  sb_enterprise_policy_host_tier_safe "$config_file" || return 1
  mode_default="$(sb_enterprise_policy_session_mode_default "$config_file")"
  [[ "$mode_default" == "autonomous" ]]
}

# Write session mode file when enterprise policy + host tier warrant autonomous default.
# Respects an existing interactive choice unless session_source is clear.
sb_enterprise_policy_apply_session_mode_default() {
  local config_file="$1" state_dir="$2" session_source="${3:-startup}"
  local mode_default mode_file existing_mode
  [[ -n "$config_file" && -f "$config_file" && -n "$state_dir" ]] || return 0

  mode_default="$(sb_enterprise_policy_session_mode_default "$config_file")"
  mode_file="${state_dir}/mode"

  if sb_enterprise_policy_should_auto_set_session_mode "$config_file"; then
    if [[ -f "$mode_file" && ! -L "$mode_file" ]]; then
      existing_mode="$(tr -d '[:space:]' <"$mode_file" 2>/dev/null || true)"
      case "$existing_mode" in
        autonomous) return 0 ;;
        interactive)
          [[ "$session_source" == "clear" ]] || return 0
          ;;
      esac
    fi
    if declare -f sb_guard_nofollow >/dev/null 2>&1; then
      sb_guard_nofollow "$mode_file" 2>/dev/null || return 0
    fi
    printf '%s' "autonomous" >"$mode_file" 2>/dev/null || true
    return 0
  fi

  # Supervised / regulated: strongly default interactive only when mode file is absent.
  [[ "$mode_default" == "interactive" ]] || return 0
  if [[ -f "$mode_file" && ! -L "$mode_file" ]]; then
    return 0
  fi
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$mode_file" 2>/dev/null || return 0
  fi
  printf '%s' "interactive" >"$mode_file" 2>/dev/null || true
}

sb_enterprise_policy_profile_bool() {
  local config_file="$1" field="$2" default="${3:-false}"
  local active value
  active="$(sb_enterprise_policy_read_active "$config_file" 2>/dev/null || true)"
  [[ -n "$active" ]] || { [[ "$default" == true ]] && return 0; return 1; }
  value="$(sb_enterprise_policy_profile_field "$config_file" "$active" "$field" 2>/dev/null || true)"
  case "${value:-$default}" in
    1|true|yes|on|TRUE|YES) return 0 ;;
    *) return 1 ;;
  esac
}

sb_enterprise_policy_clarify_auto_enabled() {
  sb_enterprise_policy_profile_bool "$1" clarify_auto false
}

sb_enterprise_policy_evidence_schema_strict() {
  local config_file="$1" hooks_strict=""
  if sb_enterprise_policy_profile_bool "$config_file" evidence_schema_strict false; then
    return 0
  fi
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  hooks_strict="$(jq -r '.hooks.evidence_schema.strict // "true"' "$config_file" 2>/dev/null || echo true)"
  case "$hooks_strict" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

sb_enterprise_policy_production_deploy_requires_human() {
  sb_enterprise_policy_profile_bool "$1" production_deploy_requires_human true
}

sb_enterprise_policy_non_production_deploy_autonomy() {
  sb_enterprise_policy_profile_bool "$1" non_production_deploy_autonomy false
}

sb_enterprise_policy_human_deploy_marker_file() {
  printf '%s/enterprise-human-deploy-approved' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_enterprise_policy_human_deploy_approved() {
  [[ "${SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL:-0}" == "1" ]] && return 0
  local marker
  marker="$(sb_enterprise_policy_human_deploy_marker_file)"
  [[ -f "$marker" && ! -L "$marker" ]]
}

sb_enterprise_policy_delivery_command_is_non_production() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -qiE \
    'staging|preview|non[-_]?prod|dev[-_ ]?deploy|sandbox|dogfood|internal' \
    && return 0
  return 1
}

# Returns 0 when delivery command must be blocked by enterprise policy.
sb_enterprise_policy_delivery_blocked() {
  local config_file="$1" cmd="$2"
  [[ -n "$config_file" && -f "$config_file" && -n "$cmd" ]] || return 1
  printf '%s' "$cmd" | grep -qE '\bgh pr (create|merge)\b|\bgh release create\b|\bdeploy\b' || return 1
  sb_enterprise_policy_production_deploy_requires_human "$config_file" || return 1
  if sb_enterprise_policy_human_deploy_approved; then
    return 1
  fi
  if sb_enterprise_policy_non_production_deploy_autonomy "$config_file" \
    && sb_enterprise_policy_delivery_command_is_non_production "$cmd"; then
    return 1
  fi
  return 0
}

sb_enterprise_policy_delivery_block_message() {
  local config_file="$1"
  local active label
  active="$(sb_enterprise_policy_read_active "$config_file" 2>/dev/null || echo supervised)"
  label="$(sb_enterprise_policy_profile_field "$config_file" "$active" label 2>/dev/null || echo "$active")"
  cat <<EOF
🛑 ENTERPRISE POLICY BLOCK — Profile ${active} (${label}) requires human approval for production delivery (PR, release, deploy).

Record explicit approval: touch $(sb_enterprise_policy_human_deploy_marker_file) after human sign-off, or set SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1 for audited automation tests only.
EOF
}

sb_enterprise_policy_clarify_hint_block() {
  local config_file="$1"
  sb_enterprise_policy_clarify_auto_enabled "$config_file" || return 0
  cat <<'EOF'
Enterprise policy: clarify_auto enabled — prefer /silver:clarify --auto for vague intent before composer routing. decision_class:blocking outcomes still require human approval.
EOF
}

sb_enterprise_policy_evidence_strict_marker() {
  local config_file="$1"
  sb_enterprise_policy_evidence_schema_strict "$config_file" || return 0
  printf '%s' 'Enterprise policy: evidence_schema_strict active — delivery gates enforce evidence schema (not warn-only).'
}

sb_enterprise_policy_persist_active_marker() {
  local config_file="$1"
  local marker_dir="${2:-${SB_RUNTIME_STATE_DIR:-}}"
  local active
  [[ -n "$marker_dir" ]] || return 0
  active="$(sb_enterprise_policy_read_active "$config_file")" || {
    rm -f -- "${marker_dir}/enterprise-policy-active" 2>/dev/null || true
    return 0
  }
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "${marker_dir}/enterprise-policy-active" 2>/dev/null || return 0
  fi
  printf '%s' "$active" >"${marker_dir}/enterprise-policy-active" 2>/dev/null || true
}

sb_enterprise_policy_session_banner() {
  local config_file="$1"
  local state_dir="${2:-${SB_RUNTIME_STATE_DIR:-}}"
  local active label mode_default runtime_note applied_mode mode_line
  active="$(sb_enterprise_policy_read_active "$config_file")" || return 0
  label="$(sb_enterprise_policy_profile_field "$config_file" "$active" label)" || label="$active"
  mode_default="$(sb_enterprise_policy_session_mode_default "$config_file")"
  runtime_note=""
  if sb_enterprise_policy_clarify_auto_enabled "$config_file"; then
    runtime_note="${runtime_note} clarify_auto=on;"
  fi
  if sb_enterprise_policy_evidence_schema_strict "$config_file"; then
    runtime_note="${runtime_note} evidence_schema_strict=on;"
  fi
  if sb_enterprise_policy_production_deploy_requires_human "$config_file"; then
    runtime_note="${runtime_note} production_deploy_human_gate=on;"
  fi
  applied_mode=""
  if [[ -n "$state_dir" && -f "${state_dir}/mode" && ! -L "${state_dir}/mode" ]]; then
    applied_mode="$(tr -d '[:space:]' <"${state_dir}/mode" 2>/dev/null || true)"
  fi
  mode_line="Recommended session mode: ${mode_default}."
  if [[ -n "$applied_mode" && "$applied_mode" == "$mode_default" ]] \
     && sb_enterprise_policy_should_auto_set_session_mode "$config_file" 2>/dev/null; then
    mode_line="Session mode auto-set to ${applied_mode} (enterprise_policy ${active}; tier 2+ host). Do not prompt for interactive vs autonomous — mode file is already written."
  elif [[ "$mode_default" == "interactive" && "$applied_mode" == "interactive" ]]; then
    mode_line="Session mode defaulted to interactive (${active} profile)."
  fi
  cat <<EOF
Enterprise policy profile: ${active} (${label}). ${mode_line} Runtime markers:${runtime_note:- none}.
EOF
}
