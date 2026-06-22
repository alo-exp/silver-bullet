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
    agentmemory)
      printf '%s' 'Session capture with git-backed memory export; proactive context injection; pairs with Graphify for save-via-agentmemory, retrieve-via-Graphify synergy.'
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

# Host detection — mirrors hooks/lib/runtime-paths.sh (claude | codex | cursor).
sb_runtime_host() {
  if [[ -n "${SILVER_BULLET_RUNTIME:-}" ]]; then
    case "$SILVER_BULLET_RUNTIME" in
      claude|codex|cursor) printf '%s' "$SILVER_BULLET_RUNTIME"; return 0 ;;
    esac
  fi
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]; then
    printf 'codex'
    return 0
  fi
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]]; then
    printf 'cursor'
    return 0
  fi
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    case "$CLAUDE_PLUGIN_ROOT" in
      */.codex/*) printf 'codex'; return 0 ;;
      */.cursor/*) printf 'cursor'; return 0 ;;
    esac
  fi
  printf 'claude'
}

sb_recommended_tool_platform_install_commands() {
  local config_file="${1:-}" tool_id="${2:-}" host="${3:-}"
  local pre post
  host="${host:-$(sb_runtime_host)}"
  pre="$(sb_recommended_tool_platform_pre_index_commands "$config_file" "$tool_id" "$host")"
  post="$(sb_recommended_tool_platform_post_index_commands "$config_file" "$tool_id" "$host")"
  if [[ -n "$pre" ]]; then
    printf '%s' "$pre"
  fi
  if [[ -n "$post" ]]; then
    [[ -n "$pre" ]] && printf '\n'
    printf '%s' "$post"
  fi
}

# Upstream order: skill registration (graphify install) before index; always-on after index.
sb_recommended_tool_platform_pre_index_commands() {
  local config_file="${1:-}" tool_id="${2:-}" host="${3:-}"
  local cmds
  host="${host:-$(sb_runtime_host)}"
  cmds="$(jq -r --arg id "$tool_id" --arg host "$host" \
    '.recommended_tools[$id].platform_install_commands[$host].pre_index[]? // empty' \
    "$config_file" 2>/dev/null || true)"
  if [[ -n "$cmds" ]]; then
    printf '%s' "$cmds"
    return 0
  fi
  if [[ "$tool_id" == "graphify" ]]; then
    case "$host" in
      claude) printf '%s\n' 'graphify install --project' ;;
      codex) printf '%s\n' 'graphify install --project --platform codex' ;;
    esac
  elif [[ "$tool_id" == "agentmemory" ]]; then
    case "$host" in
      codex)
        printf '%s\n' 'codex plugin marketplace add rohitg00/agentmemory'
        printf '%s\n' 'codex plugin add agentmemory@agentmemory'
        ;;
    esac
  fi
}

sb_recommended_tool_platform_post_index_commands() {
  local config_file="${1:-}" tool_id="${2:-}" host="${3:-}"
  local cmds legacy
  host="${host:-$(sb_runtime_host)}"
  cmds="$(jq -r --arg id "$tool_id" --arg host "$host" \
    '.recommended_tools[$id].platform_install_commands[$host].post_index[]? // empty' \
    "$config_file" 2>/dev/null || true)"
  if [[ -n "$cmds" ]]; then
    printf '%s' "$cmds"
    return 0
  fi
  # Legacy flat-array config: cursor = post-only; claude/codex = second command post-index.
  legacy="$(jq -r --arg id "$tool_id" --arg host "$host" \
    '.recommended_tools[$id].platform_install_commands[$host][]? // empty' \
    "$config_file" 2>/dev/null || true)"
  if [[ -n "$legacy" ]]; then
    case "$host" in
      cursor) printf '%s' "$legacy"; return 0 ;;
      claude|codex)
        printf '%s' "$legacy" | tail -n 1
        return 0
        ;;
    esac
  fi
  if [[ "$tool_id" == "graphify" ]]; then
    case "$host" in
      cursor) printf '%s\n' 'graphify cursor install' ;;
      claude) printf '%s\n' 'graphify claude install --project' ;;
      codex) printf '%s\n' 'graphify codex install --project' ;;
    esac
  elif [[ "$tool_id" == "agentmemory" ]]; then
    case "$host" in
      claude) printf '%s\n' 'agentmemory connect claude-code' ;;
      codex) printf '%s\n' 'agentmemory connect codex --with-hooks' ;;
    esac
  fi
}

sb_graphify_platform_artifact_path() {
  local project_root="${1:-$PWD}" host="${2:-}"
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/rules/graphify.mdc' "${project_root%/}" ;;
    codex) printf '%s/.codex/hooks.json' "${project_root%/}" ;;
    *) printf '%s/.claude/settings.json' "${project_root%/}" ;;
  esac
}

sb_graphify_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_graphify_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  case "$host" in
    cursor) grep -q 'graphify' "$artifact" 2>/dev/null ;;
    codex) grep -q 'graphify' "$artifact" 2>/dev/null ;;
    *) grep -q 'graphify' "$artifact" 2>/dev/null ;;
  esac
}

sb_recommended_tool_full_install_lines() {
  local config_file="${1:-}" tool_id="${2:-}" host="${3:-}"
  local cli_lines platform_lines
  host="${host:-$(sb_runtime_host)}"
  cli_lines="$(sb_recommended_tool_install_commands "$config_file" "$tool_id")"
  if [[ -z "$cli_lines" && "$tool_id" == "graphify" ]]; then
    cli_lines=$'uv tool install graphifyy\npipx install graphifyy'
  fi
  if [[ -z "$cli_lines" && "$tool_id" == "agentmemory" ]]; then
    cli_lines='npm install -g @agentmemory/agentmemory'
  fi
  platform_lines="$(sb_recommended_tool_platform_install_commands "$config_file" "$tool_id" "$host")"
  if [[ -n "$cli_lines" ]]; then
    printf '%s' "$cli_lines"
  fi
  if [[ -n "$platform_lines" ]]; then
    [[ -n "$cli_lines" ]] && printf '\n'
    printf '%s' "$platform_lines"
  fi
}

sb_recommended_tool_consent_prompt_block() {
  local config_file="${1:-}" tool_id="${2:-}"
  local benefits install_lines host
  benefits="$(sb_recommended_tool_benefits "$config_file" "$tool_id")"
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" "$tool_id" "$host")"

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
${tool_id} opted in but install failed — enforcement suspended until upgrade; retry on /silver:update.
User consent preserved (enabled_by_user=true). Hooks treat ${tool_id} as advisory until install succeeds.
${fail_reason:+Failure reason: ${fail_reason}}
EOF
      elif [[ "$tool_id" == "graphify" ]] && declare -f sb_graphify_cli_available >/dev/null 2>&1; then
        if ! sb_graphify_cli_available; then
          cat <<EOF
Graphify enabled but CLI missing — install before substantive work (host: ${host}):

${install_lines}

Then: graphify update . --no-cluster
Run the platform commands above from the project root after the CLI is on PATH.
Hooks block substantive edits until CLI, index, platform registration, and a fresh query are present.
EOF
        elif declare -f sb_graphify_index_exists >/dev/null 2>&1; then
          local project_root graph_rel
          project_root="$(dirname "$config_file")"
          graph_rel="$(sb_graphify_graph_rel_path "$config_file")"
          if ! sb_graphify_index_exists "$project_root" "$config_file"; then
            printf '%s\n' "Graphify enabled — index missing. Run: graphify update . --no-cluster (expected ${graph_rel}). Hooks block substantive edits until built."
          fi
        fi
      elif [[ "$tool_id" == "agentmemory" ]] && declare -f sb_agentmemory_cli_available >/dev/null 2>&1; then
        if ! sb_agentmemory_cli_available; then
          cat <<EOF
agentmemory enabled but CLI missing — install before substantive work (host: ${host}):

${install_lines}

Then start server: nohup agentmemory > ~/.agentmemory/server.log 2>&1 &
Run platform connect commands above. Hooks block substantive edits until CLI, server, MCP, and export root are ready.
EOF
        elif ! sb_agentmemory_server_healthy "$config_file" 2>/dev/null; then
          printf '%s\n' "agentmemory enabled — server not healthy. Start: nohup agentmemory > ~/.agentmemory/server.log 2>&1 &"
        elif declare -f sb_agentmemory_export_exists >/dev/null 2>&1; then
          local project_root export_rel
          project_root="$(dirname "$config_file")"
          export_rel="$(sb_agentmemory_export_rel_path "$config_file")"
          if ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
            printf '%s\n' "agentmemory enabled — export root missing. Run: mkdir -p ${export_rel}/memory ${export_rel}/snapshots"
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
