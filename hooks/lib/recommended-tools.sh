# shellcheck shell=bash
# Recommended-tools opt-in consent — generalizable pattern for SB-suggested tooling.
# Sourced by: graphify-gate.sh, session-start, prompt-reminder.sh, sb-diagnostics.sh

# Consent values: pending | enabled | disabled
sb_recommended_tool_consent() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" ]] || {
    printf 'pending'
    return 0
  }

  if jq -e --arg id "$tool_id" '.recommended_tools[$id].enabled_by_user == true' "$config_file" >/dev/null 2>&1; then
    printf 'enabled'
    return 0
  fi
  if jq -e --arg id "$tool_id" '.recommended_tools[$id].enabled_by_user == false' "$config_file" >/dev/null 2>&1; then
    printf 'disabled'
    return 0
  fi
  if jq -e --arg id "$tool_id" '(.recommended_tools[$id].enabled_by_user | type) == "null"' "$config_file" >/dev/null 2>&1; then
    :
  elif jq -e --arg id "$tool_id" 'has("recommended_tools") and (.recommended_tools[$id] | has("enabled_by_user"))' "$config_file" >/dev/null 2>&1; then
    printf 'pending'
    return 0
  fi

  # Legacy graphify.required migration (feat/mandatory-graphify compat)
  if [[ "$tool_id" == "graphify" ]]; then
    if jq -e '.graphify.required == false' "$config_file" >/dev/null 2>&1; then
      printf 'disabled'
      return 0
    fi
    if jq -e '.graphify.required == true' "$config_file" >/dev/null 2>&1; then
      printf 'enabled'
      return 0
    fi
  fi
  printf 'pending'
}

sb_recommended_tool_enforcement_suspended() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" ]] || return 1
  jq -e --arg id "$tool_id" '.recommended_tools[$id].enforcement_suspended == true' "$config_file" >/dev/null 2>&1
}

sb_recommended_tool_install_status() {
  sb_recommended_tool_config_string "${1:-}" "${2:-}" "install_status" ""
}

sb_recommended_tool_install_failure_reason() {
  sb_recommended_tool_config_string "${1:-}" "${2:-}" "install_failure_reason" ""
}

sb_recommended_tool_enforced() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ "$(sb_recommended_tool_consent "$config_file" "$tool_id")" == "enabled" ]] || return 1
  if sb_recommended_tool_enforcement_suspended "$config_file" "$tool_id"; then
    return 1
  fi
  if jq -e --arg id "$tool_id" '.recommended_tools[$id].required_when_enabled == false' "$config_file" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

sb_recommended_tool_config_string() {
  local config_file="${1:-}" tool_id="${2:-}" key="${3:-}" default="${4:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" && -n "$key" ]] || {
    printf '%s' "$default"
    return 0
  }
  jq -r --arg id "$tool_id" --arg k "$key" --arg def "$default" \
    '.recommended_tools[$id][$k] // $def' "$config_file" 2>/dev/null || printf '%s' "$default"
}

sb_recommended_tool_benefits() {
  local config_file="${1:-}" tool_id="${2:-}"
  local benefits
  benefits="$(sb_recommended_tool_config_string "$config_file" "$tool_id" "benefits_summary" "")"
  if [[ -n "$benefits" && "$benefits" != "null" ]]; then
    printf '%s' "$benefits"
    return 0
  fi
  case "$tool_id" in
    graphify)
      printf '%s' 'Scoped retrieval saves tokens; team-shared knowledge graph indexes code and docs; portable across Claude, Codex, and Cursor agents.'
      ;;
    *)
      printf '%s' 'Improves SB workflow quality when enabled.'
      ;;
  esac
}

sb_recommended_tool_install_commands() {
  local config_file="${1:-}" tool_id="${2:-}"
  jq -r --arg id "$tool_id" '.recommended_tools[$id].install_commands[]? // empty' "$config_file" 2>/dev/null || true
}

sb_recommended_tool_consent_prompt_block() {
  local config_file="${1:-}" tool_id="${2:-}"
  local benefits install_lines
  benefits="$(sb_recommended_tool_benefits "$config_file" "$tool_id")"
  install_lines="$(sb_recommended_tool_install_commands "$config_file" "$tool_id")"
  if [[ -z "$install_lines" && "$tool_id" == "graphify" ]]; then
    install_lines=$'uv tool install graphifyy\npip install graphifyy'
  fi

  case "$(sb_recommended_tool_consent "$config_file" "$tool_id")" in
    pending)
      cat <<EOF
RECOMMENDED TOOL CONSENT PENDING — ${tool_id}

Silver Bullet recommends ${tool_id} for this project.

Benefits: ${benefits}

ASK THE USER NOW (do not auto-install without explicit permission):
"Enable ${tool_id} for this project? (Yes / No)"

- Yes → set \`recommended_tools.${tool_id}.enabled_by_user\` to \`true\` in \`.silver-bullet.json\`, attempt install, then enable mandatory enforcement.
- No → set \`enabled_by_user\` to \`false\`; all ${tool_id} hook enforcements stay off (advisory/docs fallback only).

Install options (only after Yes):
${install_lines}

Until the user answers, ${tool_id} enforcement hooks are inactive.
EOF
      ;;
    disabled)
      printf '%s\n' "${tool_id} opted out for this project (recommended_tools.${tool_id}.enabled_by_user=false). Enforcements disabled — use direct docs reads per §2g-i advisory path."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "$tool_id"; then
        local fail_reason
        fail_reason="$(sb_recommended_tool_install_failure_reason "$config_file" "$tool_id")"
        cat <<EOF
Graphify opted in but install failed — enforcement suspended until upgrade; retry on /silver:update.
User consent preserved (enabled_by_user=true). Hooks treat Graphify as advisory until install succeeds.
${fail_reason:+Failure reason: ${fail_reason}}
EOF
      elif [[ "$tool_id" == "graphify" ]] && declare -f sb_graphify_cli_available >/dev/null 2>&1; then
        if ! sb_graphify_cli_available; then
          cat <<EOF
Graphify enabled but CLI missing — install before substantive work:

${install_lines}

Then: graphify update . --no-cluster
Hooks block substantive edits until CLI, index, and a fresh query are present.
EOF
        elif declare -f sb_graphify_index_exists >/dev/null 2>&1; then
          local project_root graph_rel
          project_root="$(dirname "$config_file")"
          graph_rel="$(sb_graphify_graph_rel_path "$config_file")"
          if ! sb_graphify_index_exists "$project_root" "$config_file"; then
            printf '%s\n' "Graphify enabled — index missing. Run: graphify update . --no-cluster (expected ${graph_rel}). Hooks block substantive edits until built."
          fi
        fi
      fi
      ;;
  esac
}

# Graphify enforcement alias — used by graphify-gate.sh and record-graphify-query.sh
sb_graphify_required() {
  sb_recommended_tool_enforced "${1:-}" "graphify"
}
