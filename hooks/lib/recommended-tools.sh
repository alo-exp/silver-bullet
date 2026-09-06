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
      printf '%s' 'Scoped retrieval saves tokens; team-shared knowledge graph indexes code and docs; portable across Claude, Codex, Cursor, OpenCode, and Pi agents.'
      ;;
    agentmemory)
      printf '%s' 'Session capture with git-backed memory export; proactive context injection; pairs with Graphify for save-via-agentmemory, retrieve-via-Graphify synergy.'
      ;;
    alumnium)
      printf '%s' 'AI-native browser/visual testing via MCP (do/check/get/wait); preferred for clarify, ui-review, verify. See alumnium.ai.'
      ;;
    rtk)
      printf '%s' '60–99% shell output savings via PreToolUse rewrite — automatic once rtk-ai/rtk is wired (not reachingforthejack/rtk).'
      ;;
    context_mode)
      printf '%s' 'MCP/large-file compaction and PreCompact state recovery; highest value with MCP-heavy workflows (ELv2 license).'
      ;;
    leanctx)
      printf '%s' 'Parallel-routed compression stack: wire proxy, AST read-path, PathJail, savings ledger, and injection detection — complements RTK and Context Mode via surface routing.'
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

# All five-tool host adapters resolve their subprocesses through this one
# user-global manifest.  A configured absolute path is authoritative; PATH is
# used only when the manifest intentionally contains a command name.
sb_global_toolstack_manifest_path() {
  if [[ -n "${SB_GLOBAL_TOOLSTACK_MANIFEST:-}" ]]; then
    printf '%s' "${SB_GLOBAL_TOOLSTACK_MANIFEST}"
  else
    printf '%s/instances.json' "${SB_GLOBAL_TOOLSTACK_HOME:-${HOME}/.silver-bullet/five-tool-stack}"
  fi
}

sb_global_tool_command() {
  local tool="${1:-}" manifest
  [[ -n "$tool" ]] || return 1
  manifest="$(sb_global_toolstack_manifest_path)"
  [[ -f "$manifest" ]] || return 1
  jq -er --arg tool "$tool" '.tools[$tool].command | select(type == "string" and length > 0)' \
    "$manifest" 2>/dev/null
}

sb_global_tool_path() {
  local tool="${1:-}" command
  command="$(sb_global_tool_command "$tool" 2>/dev/null || true)"
  [[ -n "$command" ]] || return 1
  if [[ "$command" == */* ]]; then
    [[ -x "$command" ]] || return 1
    printf '%s' "$command"
    return 0
  fi
  command -v "$command"
}

# Map SB host id → graphify upstream platform name (goose runs on Pi).
sb_graphify_upstream_platform() {
  local host="${1:-}"
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    goose) printf 'pi' ;;
    *) printf '%s' "$host" ;;
  esac
}

# Host detection — mirrors hooks/lib/runtime-paths.sh.
sb_runtime_host() {
  if [[ -n "${SILVER_BULLET_RUNTIME:-}" ]]; then
    case "$SILVER_BULLET_RUNTIME" in
      claude|codex|cursor|opencode|pi|goose|hermes) printf '%s' "$SILVER_BULLET_RUNTIME"; return 0 ;;
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
  if [[ -n "${OPENCODE:-}" || -n "${OPENCODE_PID:-}" ]]; then
    printf 'opencode'
    return 0
  fi
  if [[ -n "${PI_CODING_AGENT_DIR:-}" ]]; then
    printf 'pi'
    return 0
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
      opencode) printf '%s\n' 'graphify install --project --platform opencode' ;;
      pi) printf '%s\n' 'python3 scripts/lib/global-toolstack/install-pi.py --repo-root "$(pwd)"' ;;
      goose) printf '%s\n' 'graphify install --project --platform pi' ;;
      hermes) printf '%s\n' 'graphify install --project --platform hermes' ;;
    esac
  elif [[ "$tool_id" == "agentmemory" ]]; then
    case "$host" in
      codex)
        printf '%s\n' 'codex plugin marketplace add rohitg00/agentmemory'
        printf '%s\n' 'codex plugin add agentmemory@agentmemory'
        ;;
      pi)
        printf '%s\n' 'agentmemory connect pi (shared global agentmemory extension)'
        ;;
    esac
  elif [[ "$tool_id" == "rtk" ]]; then
    case "$host" in
      claude) printf '%s\n' 'rtk init -g' ;;
      cursor) printf '%s\n' 'rtk init -g --agent cursor' ;;
      codex) printf '%s\n' 'rtk init -g --codex' ;;
      opencode) printf '%s\n' 'bash scripts/optimize-rtk-context-mode.sh --host opencode --project-root "$(pwd)"' ;;
      pi) printf '%s\n' 'bash scripts/optimize-rtk-context-mode.sh --host pi --project-root "$(pwd)"' ;;
    esac
  elif [[ "$tool_id" == "context_mode" ]]; then
    case "$host" in
      claude)
        printf '%s\n' 'npm install -g context-mode'
        printf '%s\n' 'bash scripts/optimize-rtk-context-mode.sh --host claude --project-root "$(pwd)"'
        ;;
      cursor)
        printf '%s\n' 'Copy context-mode.mdc to .cursor/rules/; merge MCP + hooks per docs/CONTEXT-MODE.md'
        ;;
      codex)
        printf '%s\n' 'Merge context-mode blocks into Codex config.toml and hooks.json per docs/CONTEXT-MODE.md'
        ;;
      opencode)
        printf '%s\n' 'Register the global Context Mode plugin and RTK plugin in ~/.config/opencode/opencode.json; remove legacy Context Mode MCP duplicates'
        ;;
      pi)
        printf '%s\n' 'python3 scripts/lib/global-toolstack/install-pi.py --repo-root "$(pwd)"'
        ;;
    esac
  elif [[ "$tool_id" == "leanctx" ]]; then
    case "$host" in
      cursor|claude|codex|opencode|pi)
        printf '%s\n' "bash scripts/install-leanctx-sb.sh --host ${host} --project-root \"\$(pwd)\""
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
  if legacy="$(jq -r --arg id "$tool_id" --arg host "$host" \
    '.recommended_tools[$id].platform_install_commands[$host] | if type == "array" then .[] else empty end' \
    "$config_file" 2>/dev/null || true)" && [[ -n "$legacy" ]]; then
    case "$host" in
      cursor) printf '%s' "$legacy"; return 0 ;;
      claude|codex|opencode|goose|hermes)
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
      opencode|pi|goose|hermes) ;;
    esac
  elif [[ "$tool_id" == "agentmemory" ]]; then
    case "$host" in
      claude) printf '%s\n' 'agentmemory connect claude-code' ;;
      codex) printf '%s\n' 'agentmemory connect codex --with-hooks' ;;
      goose) printf '%s\n' 'agentmemory connect pi' ;;
      pi) printf '%s\n' 'agentmemory connect pi' ;;
      hermes) printf '%s\n' 'agentmemory connect hermes' ;;
      opencode)
        printf '%s\n' 'Merge agentmemory MCP into ~/.config/opencode/opencode.json (manual — see docs/AGENTMEMORY.md)'
        ;;
    esac
  elif [[ "$tool_id" == "context_mode" ]]; then
    case "$host" in
      claude) printf '%s\n' 'Restart Claude Code after plugin install (hooks load on restart)' ;;
    esac
  fi
}

sb_graphify_platform_artifact_path() {
  local project_root="${1:-$PWD}" host="${2:-}"
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/rules/graphify.mdc' "${project_root%/}" ;;
    codex) printf '%s/.codex/hooks.json' "${project_root%/}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    pi) printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
      "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
    goose) printf '%s/.pi/agent/skills/graphify/SKILL.md' "${project_root%/}" ;;
    hermes) printf '%s/AGENTS.md' "${project_root%/}" ;;
    # `graphify claude install --project` writes project-scoped hooks into
    # .claude/settings.json. Without this arm claude fell through to the codex
    # path, so graphify-platform reported a permanently unclearable WARN even
    # when Claude hooks were installed correctly.
    claude) printf '%s/.claude/settings.json' "${project_root%/}" ;;
    *) printf '%s/.codex/settings.json' "${project_root%/}" ;;
  esac
}

sb_graphify_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_graphify_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  case "$host" in
    cursor|codex|claude|opencode|pi|goose|hermes) grep -q 'graphify' "$artifact" 2>/dev/null ;;
    *) grep -q 'graphify' "$artifact" 2>/dev/null ;;
  esac
}

sb_recommended_tool_full_install_lines() {
  local config_file="${1:-}" tool_id="${2:-}" host="${3:-}"
  local cli_lines platform_lines
  host="${host:-$(sb_runtime_host)}"
  cli_lines="$(sb_recommended_tool_install_commands "$config_file" "$tool_id")"
  if [[ -z "$cli_lines" && "$tool_id" == "graphify" ]]; then
    cli_lines=$'uv tool install '\''graphifyy[mcp]'\''\npipx install '\''graphifyy[mcp]'\'''
  fi
  if [[ -z "$cli_lines" && "$tool_id" == "agentmemory" ]]; then
    cli_lines='npm install -g @agentmemory/agentmemory'
  fi
  if [[ -z "$cli_lines" && "$tool_id" == "rtk" ]]; then
    cli_lines=$'brew tap rtk-ai/rtk && brew install rtk\ncurl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh'
  fi
  if [[ -z "$cli_lines" && "$tool_id" == "context_mode" ]]; then
    cli_lines='npm install -g context-mode'
  fi
  if [[ -z "$cli_lines" && "$tool_id" == "leanctx" ]]; then
    cli_lines='curl -fsSL https://leanctx.com/install.sh | sh'
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
${tool_id} opted in but install failed — enforcement suspended until upgrade; retry on /sb:update.
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
      elif [[ "$tool_id" == "rtk" ]] && declare -f sb_rtk_cli_available >/dev/null 2>&1; then
        if ! sb_rtk_cli_available; then
          cat <<EOF
RTK enabled but CLI missing or wrong binary — install before substantive work (host: ${host}):

${install_lines}

Verify: rtk gain --help (rejects reachingforthejack/rtk). See docs/RTK.md.
EOF
        elif ! sb_rtk_platform_hook_present "$(dirname "$config_file")" "$host" 2>/dev/null; then
          printf '%s\n' "RTK enabled — host hook not wired for ${host}. Run rtk init; hooks block until present."
        fi
      elif [[ "$tool_id" == "context_mode" ]] && declare -f sb_context_mode_cli_available >/dev/null 2>&1; then
        if ! sb_context_mode_node_ok "$config_file" 2>/dev/null; then
          printf '%s\n' "Context Mode enabled — Node >= 22.5 required before install."
        elif ! sb_context_mode_cli_available; then
          cat <<EOF
Context Mode enabled but not installed (host: ${host}):

${install_lines}

ELv2 license — see recommended_tools.context_mode.license_note. Restart agent after plugin wiring. See docs/CONTEXT-MODE.md.
EOF
        elif ! sb_context_mode_instruction_fragment_present "$(dirname "$config_file")" 2>/dev/null; then
          printf '%s\n' "Context Mode enabled — instruction fragment missing from silver-bullet.md/CLAUDE.md. Run init/update scaffold."
        fi
      fi
      ;;
  esac
}

# Graphify enforcement alias — used by graphify-gate.sh and record-graphify-query.sh
sb_graphify_required() {
  sb_recommended_tool_enforced "${1:-}" "graphify"
}

# Five-tool parallel-routed stack helpers (Phase 1 config contract; coordinator enforces in Phase 2).
sb_stack_leanctx_active() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  [[ "$(sb_recommended_tool_consent "$config_file" "leanctx")" == "enabled" ]] || return 1
  if sb_recommended_tool_enforcement_suspended "$config_file" "leanctx"; then
    return 1
  fi
  return 0
}

# Map host tool surface or sb_* route → owning tool id from optimization_profiles.five_tool_routed.
# Surfaces: Read, Grep, Bash, WebFetch (or sb_* route names directly).
sb_stack_surface_owner() {
  local config_file="${1:-}" surface="${2:-}"
  local route owner profile

  [[ -n "$config_file" && -f "$config_file" && -n "$surface" ]] || return 1

  case "$surface" in
    Read) route="sb_read" ;;
    Grep) route="sb_grep" ;;
    Bash) route="sb_shell" ;;
    WebFetch) route="sb_webfetch" ;;
    sb_wire|sb_read|sb_grep|sb_shell|sb_slice|sb_webfetch|sb_graph|sb_remember|sb_pathjail|sb_injection)
      route="$surface"
      ;;
    *)
      return 1
      ;;
  esac

  if sb_stack_leanctx_active "$config_file"; then
    profile="$(jq -r '.recommended_tools.leanctx.optimization_profile // "five_tool_routed"' \
      "$config_file" 2>/dev/null || echo "five_tool_routed")"
    owner="$(jq -r --arg p "$profile" --arg r "$route" \
      '.optimization_profiles[$p].routes[$r] // empty' "$config_file" 2>/dev/null || true)"
    if [[ -n "$owner" && "$owner" != "null" ]]; then
      printf '%s' "$owner"
      return 0
    fi
  fi

  # Legacy two-tool compression fallback when LeanCTX inactive.
  case "$route" in
    sb_read|sb_grep|sb_slice|sb_webfetch) printf 'context_mode'; return 0 ;;
    sb_shell) printf 'rtk'; return 0 ;;
    sb_graph) printf 'graphify'; return 0 ;;
    sb_remember) printf 'agentmemory'; return 0 ;;
    *) return 1 ;;
  esac
}
