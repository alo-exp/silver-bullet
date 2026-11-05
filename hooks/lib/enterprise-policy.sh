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
    '.enterprise_policy.profiles[$p][$f] | if . == null then empty else . end' "$config_file" 2>/dev/null || true)"
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
      sb_guard_nofollow "$mode_file" 2>/dev/null
    fi
    printf '%s' "autonomous" 2>/dev/null >"$mode_file" || true
    return 0
  fi

  # Supervised / regulated: strongly default interactive only when mode file is absent.
  [[ "$mode_default" == "interactive" ]] || return 0
  if [[ -f "$mode_file" && ! -L "$mode_file" ]]; then
    return 0
  fi
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$mode_file" 2>/dev/null
  fi
  printf '%s' "interactive" 2>/dev/null >"$mode_file" || true
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
  hooks_strict="$(jq -r '.hooks.evidence_schema.strict | if . == null then "true" else tostring end' "$config_file" 2>/dev/null || echo true)"
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

# sb_enterprise_policy_untrusted_text TEXT: repository-controlled text (profile labels, workflow names)
# for a hook message: control characters and newlines removed, capped at 80 characters (R1-33).
sb_enterprise_policy_untrusted_text() {
  local text
  text="$(printf '%s' "${1:-}" | tr -d '[:cntrl:]' | cut -c1-"${2:-80}")"
  printf '%s' "$text"
}

# sb_enterprise_policy_unseen_note: the "cannot inspect: <reason>" paragraph for a command the analysis
# could not read (empty when the verdict has no unseen reasons). A failed helper is Silver Bullet's problem,
# not the command's, so it gets repair advice instead of "rewrite the command".
sb_enterprise_policy_unseen_note() {
  local reasons
  [[ -n "${ca_unseen_reasons:-}" ]] || return 0
  reasons="$(sb_enterprise_policy_untrusted_text "$(printf '%s' "$ca_unseen_reasons" | head -3 | tr '\n' ';')" 240)"
  if [[ "${ca_analysis_status:-}" == "helper_unavailable" ]]; then
    printf "cannot inspect: Silver Bullet's shell analysis helper failed (%s).\nThe command itself is not the problem: check that python3 is installed and on the PATH the host gives hooks, or reinstall Silver Bullet, then retry." "$reasons"
  else
    printf 'cannot inspect: %s\nThis command runs code Silver Bullet cannot read, so it is held like a delivery. Rewrite it as plain, separate commands (no eval, variable-built command names, pipes into a shell, generated scripts) so it can be inspected.' "$reasons"
  fi
}

# Marker must be created by a human operator outside the agent session.
# Do not allowlist enterprise-human-deploy-approved for agent Edit/Write/Bash touch.
# The marker is a short-lived sign-off, not a permanent waiver (R1-08, R16-06):
#   - it expires after enterprise_policy.human_approval_ttl_minutes (default 480);
#   - a marker with a `project=<repo root>` line approves only that project; an empty marker approves
#     every project of this host runtime until it expires;
#   - SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1 (an environment variable set by whoever starts the host) is
#     recorded in the hook audit log whenever it waives the gate.
# sb_enterprise_policy_approval_ttl CONFIG: minutes the approval marker stays valid (default 480).
sb_enterprise_policy_approval_ttl() {
  local ttl=480
  if [[ -n "${1:-}" && -f "${1:-}" ]] && command -v jq >/dev/null 2>&1; then
    ttl="$(jq -r '.enterprise_policy.human_approval_ttl_minutes // 480' "$1" 2>/dev/null || true)"
  fi
  [[ "$ttl" =~ ^[0-9]+$ ]] || ttl=480
  printf '%s' "$ttl"
}

sb_enterprise_policy_human_deploy_approved() {
  local config_file="${1:-}" marker ttl project=""
  if [[ "${SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL:-0}" == "1" ]]; then
    if declare -f sb_hook_audit_record >/dev/null 2>&1; then
      sb_hook_audit_record "enterprise-policy" "${hook_event:-}" "env-approval" \
        "SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1 waived the human delivery gate" ""
    fi
    return 0
  fi
  marker="$(sb_enterprise_policy_human_deploy_marker_file)"
  [[ -f "$marker" && ! -L "$marker" ]] || return 1
  ttl="$(sb_enterprise_policy_approval_ttl "$config_file")"
  [[ -n "$(find "$marker" -mmin "-${ttl}" -print 2>/dev/null)" ]] || return 1
  project="$(sed -n 's/^project=//p' "$marker" 2>/dev/null | head -1)"
  if [[ -n "$project" && -n "$config_file" ]]; then
    [[ "$project" == "$(dirname "$config_file")" ]] || return 1
  fi
  return 0
}

# Non-production autonomy applies to a deploy aimed at a named non-production target, nothing else:
# the keyword must be a whole word of the deploy command (R1-13).
sb_enterprise_policy_delivery_command_is_non_production() {
  local cmd="$1"
  grep -qiE '(^|[^[:alnum:]])(staging|preview|non[-_]?prod|dev[-_ ]?deploy|sandbox|dogfood|internal)([^[:alnum:]]|$)' <<<"$cmd"
}

# Returns 0 when delivery command must be blocked by enterprise policy.
# Inside completion-audit the classifier verdict (ca_tier / ca_actions / ca_possible_actions) decides
# what counts as delivery; the keyword match is the fallback for a caller without one, and is
# case-insensitive like the classifier.
sb_enterprise_policy_delivery_blocked() {
  local config_file="$1" cmd="$2" deploy_only=false all_actions
  [[ -n "$config_file" && -f "$config_file" && -n "$cmd" ]] || return 1
  if [[ -n "${ca_tier:-}" ]]; then
    [[ "$ca_tier" == "completion" ]] || return 1
    # only a plain deploy (no PR, merge, release, remote write or unreadable part) may be non-production
    all_actions="$(printf '%s %s\n' "${ca_actions:-}" "${ca_possible_actions:-}" | tr -s ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')"
    [[ "$all_actions" == "deploy " ]] && deploy_only=true
  else
    grep -qiE '\bgh pr (create|merge)\b|\bgh release create\b|\bdeploy\b' <<<"$cmd" || return 1
    grep -qiE '\bgh pr (create|merge)\b|\bgh release create\b' <<<"$cmd" || deploy_only=true
  fi
  sb_enterprise_policy_production_deploy_requires_human "$config_file" || return 1
  if sb_enterprise_policy_human_deploy_approved "$config_file"; then
    return 1
  fi
  if [[ "$deploy_only" == true ]] \
    && sb_enterprise_policy_non_production_deploy_autonomy "$config_file" \
    && sb_enterprise_policy_delivery_command_is_non_production "$cmd"; then
    return 1
  fi
  return 0
}

sb_enterprise_policy_delivery_block_message() {
  local config_file="$1"
  local active label marker
  active="$(sb_enterprise_policy_read_active "$config_file" 2>/dev/null || echo supervised)"
  label="$(sb_enterprise_policy_profile_field "$config_file" "$active" label 2>/dev/null || echo "$active")"
  active="$(sb_enterprise_policy_untrusted_text "$active")"
  label="$(sb_enterprise_policy_untrusted_text "$label")"
  marker="$(sb_enterprise_policy_human_deploy_marker_file)"
  if [[ -n "${ca_unseen_reasons:-}" ]]; then
    # the command could not be read: do not present it as a known production delivery
    local note ttl
    note="$(sb_enterprise_policy_unseen_note)"
    ttl="$(sb_enterprise_policy_approval_ttl "$config_file")"
    cat <<EOF
🛑 ENTERPRISE POLICY BLOCK — ${note}

Profile ${active} (${label}) requires human approval for delivery.

To proceed, have the human operator sign off from their own terminal (outside the agent session):
  touch ${marker}
Approval lasts ${ttl} minutes.
EOF
    return 0
  fi
  cat <<EOF
🛑 ENTERPRISE POLICY BLOCK — Profile ${active} (${label}) requires human approval for production delivery (PR, release, deploy).

Human operator: after you sign off, create the approval marker from your own terminal (outside the agent session):
  touch ${marker}
  (optionally  printf 'project=<this project root>\n' > ${marker}  to approve one project only)

The approval expires after enterprise_policy.human_approval_ttl_minutes (default 480) minutes; delete the marker once the approved delivery is done.
The agent must NOT create this marker (no Edit/Write/Bash touch). For audited automation tests only, set SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1.
EOF
}

sb_enterprise_policy_clarify_hint_block() {
  local config_file="$1"
  sb_enterprise_policy_clarify_auto_enabled "$config_file" || return 0
  cat <<'EOF'
Enterprise policy: clarify_auto enabled — prefer /sb:clarify --auto for vague intent before composer routing. decision_class:blocking outcomes still require human approval.
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
    sb_guard_nofollow "${marker_dir}/enterprise-policy-active" 2>/dev/null
  fi
  printf '%s' "$active" 2>/dev/null >"${marker_dir}/enterprise-policy-active" || true
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

