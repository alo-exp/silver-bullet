# shellcheck shell=bash
# Recommended-tools opt-in consent and shared helpers for the opt-in tool gates.
# Sourced by: the opt-in gate hooks and recorders, session-start, prompt-reminder.sh,
# sb-diagnostics.sh and the recommended-tools scripts.
#
# Trust model: .silver-bullet.json is committed, repository-controlled content. It may
# recommend a tool (enabled_by_user: true), turn one off (enabled_by_user: false,
# enforcement_suspended, required_when_enabled: false) and tune validated values. It never
# grants consent and never supplies a command, URL or path that Silver Bullet runs, fetches
# or prints as an instruction. Consent is per user (hooks/lib/user-consent.sh); install and
# setup instructions come only from the built-in tables below.

_sb_rt_lib_dir="${BASH_SOURCE[0]%/*}"
# The package root (used in printed instructions); empty when it cannot be resolved.
_SB_RT_PLUGIN_ROOT="$(cd "${_sb_rt_lib_dir}/../.." 2>/dev/null && pwd)" || _SB_RT_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if ! declare -f sb_consent_decision >/dev/null 2>&1; then
  # shellcheck source=user-consent.sh
  source "${_sb_rt_lib_dir}/user-consent.sh"
fi

# ---------------------------------------------------------------------------------------
# Consent
# ---------------------------------------------------------------------------------------

# What the committed project file says about a tool: recommended | disabled | unset.
# A legacy top-level graphify.required is read when enabled_by_user is not a boolean.
sb_recommended_tool_project_preference() {
  local config_file="${1:-}" tool_id="${2:-}" out
  if [[ -z "$config_file" || ! -f "$config_file" || -z "$tool_id" ]]; then
    printf 'unset'
    return 0
  fi
  out="$(jq -r --arg id "$tool_id" '
    (.recommended_tools[$id].enabled_by_user) as $v
    | if $v == true then "recommended"
      elif $v == false then "disabled"
      elif $id == "graphify" and .graphify.required == true then "recommended"
      elif $id == "graphify" and .graphify.required == false then "disabled"
      else "unset" end' "$config_file" 2>/dev/null || true)"
  case "$out" in
    recommended|disabled) printf '%s' "$out" ;;
    *) printf 'unset' ;;
  esac
}

# Effective consent for a tool's gates in this project: pending | enabled | disabled.
#   disabled  the project file turns the tool off, or the user declined it
#   enabled   the user granted "enforce" for this project or for all projects
#   pending   no user decision (a project recommendation alone is not consent)
sb_recommended_tool_consent() {
  local config_file="${1:-}" tool_id="${2:-}"
  if [[ -z "$config_file" || ! -f "$config_file" || -z "$tool_id" ]]; then
    printf 'pending'
    return 0
  fi
  if [[ "$(sb_recommended_tool_project_preference "$config_file" "$tool_id")" == "disabled" ]]; then
    printf 'disabled'
    return 0
  fi
  case "$(sb_consent_decision "$tool_id" enforce "$(dirname "$config_file")")" in
    granted) printf 'enabled' ;;
    declined) printf 'disabled' ;;
    *) printf 'pending' ;;
  esac
}

sb_recommended_tool_enforcement_suspended() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" ]] || return 1
  jq -e --arg id "$tool_id" '.recommended_tools[$id].enforcement_suspended == true' "$config_file" >/dev/null 2>&1
}

sb_recommended_tool_install_status() {
  sb_recommended_tool_config_string "${1:-}" "${2:-}" "install_status" ""
}

# Gates run only with the user's "enforce" consent, and the project file can still switch
# them off (enabled_by_user false, enforcement_suspended, required_when_enabled false).
# The consent check comes first: without a consent store it costs no subprocess.
sb_recommended_tool_enforced() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" ]] || return 1
  sb_consent_granted "$tool_id" enforce "$(dirname "$config_file")" || return 1
  jq -e --arg id "$tool_id" '
    (.recommended_tools[$id] // {}) as $t
    | ($t.enabled_by_user != false)
      and ($t.enforcement_suspended != true)
      and ($t.required_when_enabled != false)
      and (($id != "graphify") or ($t.enabled_by_user == true) or (.graphify.required != false))' \
    "$config_file" >/dev/null 2>&1
}

# Generic accessor for scalar settings. Callers validate the value: it is repository data.
sb_recommended_tool_config_string() {
  local config_file="${1:-}" tool_id="${2:-}" key="${3:-}" default="${4:-}"
  [[ -n "$config_file" && -f "$config_file" && -n "$tool_id" && -n "$key" ]] || {
    printf '%s' "$default"
    return 0
  }
  jq -r --arg id "$tool_id" --arg k "$key" --arg def "$default" \
    '.recommended_tools[$id][$k] // $def | if type == "string" or type == "number" then tostring else $def end' \
    "$config_file" 2>/dev/null || printf '%s' "$default"
}

# ---------------------------------------------------------------------------------------
# Validation helpers shared by the gate libraries
# ---------------------------------------------------------------------------------------

# sb_rt_ttl_seconds VALUE DEFAULT: VALUE when it is a whole number of seconds in
# [60, 604800], else DEFAULT. Never evaluates VALUE arithmetically before the regex.
sb_rt_ttl_seconds() {
  local value="${1:-}" default="${2:-1800}"
  if [[ "$value" =~ ^[0-9]{1,6}$ ]] && ((10#$value >= 60 && 10#$value <= 604800)); then
    printf '%s' "$((10#$value))"
  else
    printf '%s' "$default"
  fi
}

# sb_rt_safe_rel_path VALUE DEFAULT: VALUE when it is a project-relative path of plain
# characters (letters, digits, '.', '_', '-', '/') with no empty, '.' or '..' component;
# DEFAULT otherwise. Config paths are repository data and must stay inside the project.
sb_rt_safe_rel_path() {
  local value="${1:-}" default="${2:-}" part
  local -a parts
  if [[ ! "$value" =~ ^[A-Za-z0-9._][A-Za-z0-9._/-]*$ ]]; then
    printf '%s' "$default"
    return 0
  fi
  IFS=/ read -r -a parts <<<"$value"
  for part in "${parts[@]}"; do
    case "$part" in
      . | ..) printf '%s' "$default"; return 0 ;;
    esac
  done
  case "$value" in
    */ | *//*) printf '%s' "$default"; return 0 ;;
  esac
  printf '%s' "$value"
}

# sb_rt_version_valid V: status 0 for a plain dotted version (1 to 3 numeric parts).
sb_rt_version_valid() {
  [[ "${1:-}" =~ ^[0-9]{1,9}(\.[0-9]{1,9}){0,2}$ ]]
}

# sb_rt_version_extract TEXT: print the first dotted version (X.Y or X.Y.Z) in TEXT.
sb_rt_version_extract() {
  local text="${1:-}"
  [[ "$text" =~ ([0-9]{1,9}\.[0-9]{1,9}(\.[0-9]{1,9})?) ]] || return 1
  printf '%s' "${BASH_REMATCH[1]}"
}

# sb_rt_version_ge HAVE MIN: status 0 when HAVE >= MIN, 1 when lower, 2 when either is not
# a plain dotted version. Values are validated before any arithmetic: a config string in
# [[ -gt ]] or (( )) would be evaluated, and array subscripts run commands.
sb_rt_version_ge() {
  local have="${1:-}" min="${2:-}" h1 h2 h3 m1 m2 m3
  sb_rt_version_valid "$have" && sb_rt_version_valid "$min" || return 2
  IFS=. read -r h1 h2 h3 <<<"$have"
  IFS=. read -r m1 m2 m3 <<<"$min"
  h1=$((10#$h1)) h2=$((10#${h2:-0})) h3=$((10#${h3:-0}))
  m1=$((10#$m1)) m2=$((10#${m2:-0})) m3=$((10#${m3:-0}))
  # Every comparison sits in a condition: a false (( )) must not trip errexit / ERR traps.
  if ((h1 != m1)); then
    ((h1 > m1)) && return 0
    return 1
  fi
  if ((h2 != m2)); then
    ((h2 > m2)) && return 0
    return 1
  fi
  ((h3 >= m3)) && return 0
  return 1
}

# sb_rt_state_file CONFIGURED DEFAULT_NAME: the usage/query stamp path for a tool.
# CONFIGURED comes from the project config, so it is honoured only when it names a file
# inside $SB_RUNTIME_STATE_DIR: '~/' and the ${SB_RUNTIME_HOME_ROOT} / ${SB_RUNTIME_STATE_DIR}
# placeholders are expanded; empty, relative or placeholder-bearing values, control
# characters and names that are not exactly <state dir>/<name>-usage or <name>-query all fall back to $SB_RUNTIME_STATE_DIR/DEFAULT_NAME.
sb_rt_state_file() {
  local configured="${1:-}" default_name="${2:-}" state_dir fallback candidate rel base_lc
  state_dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
  state_dir="${state_dir%/}"
  fallback="${state_dir}/${default_name}"
  candidate="$configured"
  case "$candidate" in
    \~/*) candidate="${HOME}/${candidate#\~/}" ;;
  esac
  candidate="${candidate//\$\{SB_RUNTIME_HOME_ROOT\}/${SB_RUNTIME_HOME_ROOT:-}}"
  candidate="${candidate//\$\{SB_RUNTIME_STATE_DIR\}/${state_dir}}"
  # shellcheck disable=SC2016  # '${' is matched literally
  case "$candidate" in
    "" | *'${'* | *$'\n'* | *$'\r'* | *$'\t'*) printf '%s' "$fallback"; return 0 ;;
  esac
  case "$candidate" in
    "${state_dir}"/*) rel="${candidate#"${state_dir}"/}" ;;
    *) printf '%s' "$fallback"; return 0 ;;
  esac
  # An allowlist: only a "<name>-usage" / "<name>-query" stamp (lowercase letters, digits and
  # dashes) is honoured, so a configured path can never name one of SB's own state files
  # (directive, overrides, mode, trivial, skill state...), whatever its case. Anything else,
  # including the bare state dir, falls back to the built-in stamp.
  base_lc="$(printf '%s' "${rel##*/}" | tr '[:upper:]' '[:lower:]')"
  [[ "$base_lc" =~ ^[a-z0-9-]+-(usage|query)$ ]] || { printf '%s' "$fallback"; return 0; }
  # Exactly <state dir>/<stamp>: no subdirectory (a stamp writer must never be made to create
  # a directory that shadows one of SB's own state files), so rel is one plain component.
  case "$rel" in
    */*) printf '%s' "$fallback"; return 0 ;;
  esac
  printf '%s' "$candidate"
}

# sb_rt_stamp_write PATH: write the current epoch to PATH atomically. The temp file is
# created next to PATH and renamed over it, so a symlink at PATH is replaced, not followed.
sb_rt_stamp_write() {
  local path="${1:-}" dir tmp state_dir
  [[ -n "$path" && ! -d "$path" ]] || return 1
  dir="$(dirname "$path")"
  # Only the runtime state dir itself is created with parents (a fixed path); a marker
  # subdirectory of it is created one level deep with plain mkdir, never a tree.
  state_dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
  state_dir="${state_dir%/}"
  case "$dir" in
    "$state_dir") mkdir -p "$dir" 2>/dev/null || return 1 ;;
    "$state_dir"/*/*) [[ -d "$dir" ]] || return 1 ;;
    "$state_dir"/*) mkdir -p "$state_dir" 2>/dev/null && { [[ -d "$dir" ]] || mkdir "$dir" 2>/dev/null; } || return 1 ;;
    *) [[ -d "$dir" ]] || return 1 ;;
  esac
  tmp="$(mktemp "${path}.XXXXXX" 2>/dev/null)" || return 1
  if date +%s >"$tmp" 2>/dev/null && mv -f -- "$tmp" "$path" 2>/dev/null; then
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null
  return 1
}

# sb_rt_stamp_is_fresh PATH TTL: status 0 when PATH (a regular file, not a symlink) holds
# an epoch no older than TTL seconds.
sb_rt_stamp_is_fresh() {
  local path="${1:-}" ttl="${2:-}" epoch="" now
  [[ -f "$path" && ! -L "$path" ]] || return 1
  IFS= read -r epoch <"$path" || true
  [[ "$epoch" =~ ^[0-9]{1,12}$ && "$ttl" =~ ^[0-9]{1,9}$ ]] || return 1
  now="$(date +%s)"
  ((now - 10#$epoch >= 0 && now - 10#$epoch <= 10#$ttl)) && return 0
  return 1
}

# Print an absolute path to one of Silver Bullet's own scripts, shell-quoted. Instructions
# never point at a project-relative scripts/ path: in a cloned repository that would run
# the repository's copy instead of Silver Bullet's.
sb_rt_plugin_script() {
  printf '%q' "${_SB_RT_PLUGIN_ROOT}/${1:-}"
}

# ---------------------------------------------------------------------------------------
# Built-in, pinned descriptions and install instructions
# ---------------------------------------------------------------------------------------

sb_recommended_tool_benefits() {
  local tool_id="${2:-}"
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

# CLI install commands. The CONFIG argument is accepted for compatibility and ignored:
# install_commands in .silver-bullet.json is repository content and is never shown or run.
sb_recommended_tool_install_commands() {
  local tool_id="${2:-}"
  case "$tool_id" in
    graphify)
      printf '%s\n' "uv tool install 'graphifyy[mcp]'" "pipx install 'graphifyy[mcp]'"
      ;;
    agentmemory) printf '%s\n' 'npm install -g @agentmemory/agentmemory' ;;
    alumnium) printf '%s\n' 'npm install -g alumnium' ;;
    rtk)
      printf '%s\n' 'brew tap rtk-ai/rtk && brew install rtk' \
        'curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh'
      ;;
    context_mode) printf '%s\n' 'npm install -g context-mode' ;;
    leanctx) printf '%s\n' 'curl -fsSL https://leanctx.com/install.sh | sh' ;;
    search_cli) printf '%s\n' 'brew tap paperfoot/tap && brew install paperfoot/tap/search-cli' ;;
  esac
}

# All five-tool host adapters resolve their subprocesses through this one
# user-global manifest.  A configured absolute path is authoritative; PATH is
# used only when the manifest intentionally contains a command name.
sb_global_toolstack_manifest_path() {
  if [[ -n "${SB_GLOBAL_TOOLSTACK_MANIFEST:-}" ]]; then
    printf '%s' "${SB_GLOBAL_TOOLSTACK_MANIFEST}"
  elif [[ -n "${SB_GLOBAL_TOOLSTACK_HOME:-}" ]]; then
    # Compatibility override for pre-generic SB installations and fixtures.
    printf '%s/instances.json' "${SB_GLOBAL_TOOLSTACK_HOME}"
  else
    printf '%s/manifest.json' "${FIVE_TOOL_STACK_HOME:-${XDG_STATE_HOME:-${XDG_DATA_HOME:-${HOME}/.local/state}}/five-tool-stack}"
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

# Platform setup before the first index build (built-in table; the CONFIG argument is
# ignored, see sb_recommended_tool_install_commands). Upstream order: skill registration
# (graphify install) before index; always-on after index.
sb_recommended_tool_platform_pre_index_commands() {
  # shellcheck disable=SC2016  # the instruction text keeps "$(pwd)" for the user's shell
  local tool_id="${2:-}" host="${3:-}" root='"$(pwd)"'
  host="${host:-$(sb_runtime_host)}"
  case "$tool_id:$host" in
    graphify:claude) printf '%s\n' 'graphify install --project' ;;
    graphify:codex|graphify:opencode|graphify:hermes)
      printf '%s\n' "graphify install --project --platform ${host}"
      ;;
    graphify:goose) printf '%s\n' 'graphify install --project --platform pi' ;;
    graphify:pi|rtk:pi|context_mode:pi)
      printf '%s\n' "python3 $(sb_rt_plugin_script scripts/lib/global-toolstack/install-pi.py) --repo-root ${root}"
      ;;
    agentmemory:codex)
      printf '%s\n' 'codex plugin marketplace add rohitg00/agentmemory' 'codex plugin add agentmemory@agentmemory'
      ;;
    agentmemory:pi) printf '%s\n' 'agentmemory connect pi (shared global agentmemory extension)' ;;
    alumnium:claude)
      # shellcheck disable=SC2016  # the instruction text keeps $OPENAI_API_KEY for the user's shell
      printf '%s\n' 'claude mcp add alumnium --env OPENAI_API_KEY=$OPENAI_API_KEY -- npx -y alumnium mcp'
      ;;
    alumnium:cursor) printf '%s\n' 'Merge the alumnium MCP server into ~/.cursor/mcp.json (see docs/ALUMNIUM.md)' ;;
    alumnium:codex) printf '%s\n' 'Merge [mcp_servers.alumnium] into ~/.codex/config.toml (see docs/ALUMNIUM.md)' ;;
    rtk:claude) printf '%s\n' 'rtk init -g' ;;
    rtk:cursor) printf '%s\n' 'rtk init -g --agent cursor' ;;
    rtk:codex) printf '%s\n' 'rtk init -g --codex' ;;
    rtk:opencode|context_mode:opencode|context_mode:claude|context_mode:cursor)
      [[ "$tool_id:$host" == context_mode:claude || "$tool_id:$host" == context_mode:cursor ]] \
        && printf '%s\n' 'npm install -g context-mode'
      printf '%s\n' "bash $(sb_rt_plugin_script scripts/optimize-rtk-context-mode.sh) --host ${host} --project-root ${root}"
      ;;
    context_mode:codex)
      printf '%s\n' 'Merge the context-mode blocks into ~/.codex/config.toml and hooks.json (see docs/CONTEXT-MODE.md)'
      ;;
    leanctx:cursor|leanctx:claude|leanctx:codex|leanctx:opencode|leanctx:pi)
      printf '%s\n' "bash $(sb_rt_plugin_script scripts/install-leanctx-sb.sh) --host ${host} --project-root ${root}"
      ;;
  esac
}

sb_recommended_tool_platform_post_index_commands() {
  local tool_id="${2:-}" host="${3:-}"
  host="${host:-$(sb_runtime_host)}"
  case "$tool_id:$host" in
    graphify:cursor) printf '%s\n' 'graphify cursor install' ;;
    graphify:claude) printf '%s\n' 'graphify claude install --project' ;;
    graphify:codex) printf '%s\n' 'graphify codex install --project' ;;
    agentmemory:claude) printf '%s\n' 'agentmemory connect claude-code' ;;
    agentmemory:codex) printf '%s\n' 'agentmemory connect codex --with-hooks' ;;
    agentmemory:goose|agentmemory:pi) printf '%s\n' 'agentmemory connect pi' ;;
    agentmemory:hermes) printf '%s\n' 'agentmemory connect hermes' ;;
    agentmemory:opencode)
      printf '%s\n' 'Merge the agentmemory MCP server into ~/.config/opencode/opencode.json (manual — see docs/AGENTMEMORY.md)'
      ;;
    agentmemory:cursor) printf '%s\n' 'Verify the agentmemory MCP server in ~/.cursor/mcp.json (see docs/AGENTMEMORY.md)' ;;
    rtk:cursor) printf '%s\n' "bash $(sb_rt_plugin_script scripts/optimize-rtk-context-mode.sh) --host cursor" ;;
    context_mode:claude) printf '%s\n' 'Restart Claude Code after shared MCP configuration changes' ;;
    context_mode:cursor) printf '%s\n' 'Restart Cursor after the MCP/hook merge' ;;
  esac
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
    # .claude/settings.json.
    *) printf '%s/.claude/settings.json' "${project_root%/}" ;;
  esac
}

sb_graphify_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_graphify_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -q 'graphify' "$artifact" 2>/dev/null
}

# CLI install commands followed by the platform setup commands, all built in.
sb_recommended_tool_full_install_lines() {
  local tool_id="${2:-}" host="${3:-}" cli_lines platform_lines
  host="${host:-$(sb_runtime_host)}"
  cli_lines="$(sb_recommended_tool_install_commands "" "$tool_id")"
  platform_lines="$(sb_recommended_tool_platform_install_commands "" "$tool_id" "$host")"
  if [[ -n "$cli_lines" ]]; then
    printf '%s' "$cli_lines"
  fi
  if [[ -n "$platform_lines" ]]; then
    [[ -n "$cli_lines" ]] && printf '\n'
    printf '%s' "$platform_lines"
  fi
}

# ---------------------------------------------------------------------------------------
# SessionStart consent context
# ---------------------------------------------------------------------------------------

# The commands that record the user's answer, for this project. With a third argument
# ("enforce") Yes records that capability only; without it Yes also allows installing and
# wiring the tool on this machine (install and wire are machine-wide).
_sb_rt_consent_commands() {
  local tool_id="$1" project_root="$2" only="${3:-}" cli
  cli="bash $(sb_rt_plugin_script scripts/sb-consent.sh)"
  if [[ -n "$only" ]]; then
    printf '  Yes: %s grant %s --project %q --capabilities %s\n' "$cli" "$tool_id" "$project_root" "$only"
  else
    printf '  Yes (also allows installing and wiring it on this machine): %s grant %s --project %q\n' \
      "$cli" "$tool_id" "$project_root"
  fi
  printf '  No:  %s decline %s --project %q\n' "$cli" "$tool_id" "$project_root"
}

# One-time marker for the migration notice, per tool and project (in the runtime state dir).
_sb_rt_notice_marker() {
  local tool_id="$1" project_root="$2" key sum
  key="$(sb_consent_project_key "$project_root" 2>/dev/null || printf '%s' "$project_root")"
  sum="$(printf '%s' "$key" | cksum | awk '{print $1}')"
  printf '%s/consent-notices/%s-%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}" "$tool_id" "$sum"
}

sb_recommended_tool_consent_prompt_block() {
  local config_file="${1:-}" tool_id="${2:-}"
  local benefits install_lines host project_root marker display
  [[ -n "$config_file" && -f "$config_file" ]] && sb_consent_tool_valid "$tool_id" || return 0
  project_root="$(dirname "$config_file")"
  benefits="$(sb_recommended_tool_benefits "" "$tool_id")"
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" "$tool_id" "$host")"
  display="$(sb_recommended_tool_display_name "$tool_id")"

  case "$(sb_recommended_tool_consent "$config_file" "$tool_id")" in
    pending)
      if [[ "$(sb_recommended_tool_project_preference "$config_file" "$tool_id")" == "recommended" ]]; then
        # Shown once per tool and project: the project file used to count as consent.
        marker="$(_sb_rt_notice_marker "$tool_id" "$project_root")"
        [[ -e "$marker" ]] && return 0
        sb_rt_stamp_write "$marker" || true
        cat <<EOF
RECOMMENDED TOOL CONSENT NEEDED — ${display} (${tool_id})

This project's .silver-bullet.json recommends ${display} (recommended_tools.${tool_id}.enabled_by_user: true). Silver Bullet no longer treats a setting in a repository file as your consent, so ${display} hooks, installs and host wiring stay off until the user confirms.

Ask the user once: "Enable ${display} for this project? (Yes / No)". Record the answer (this notice is shown once; Yes turns on this project's ${display} hooks only, installs and host wiring need their own grant):
$(_sb_rt_consent_commands "$tool_id" "$project_root" enforce)
EOF
        return 0
      fi
      cat <<EOF
RECOMMENDED TOOL CONSENT PENDING — ${tool_id}

Silver Bullet recommends ${tool_id} for this project.

Benefits: ${benefits}

ASK THE USER NOW (do not auto-install without explicit permission):
"Enable ${tool_id} for this project? (Yes / No)"

Record the answer in the user's own consent store (never in .silver-bullet.json):
$(_sb_rt_consent_commands "$tool_id" "$project_root")
- Yes → install (commands below), then the ${tool_id} hooks enforce.
- No → all ${tool_id} hook enforcements stay off (advisory/docs fallback only).

Install options (only after Yes):
${install_lines}

Until the user answers, ${tool_id} enforcement hooks are inactive.
EOF
      ;;
    disabled)
      printf '%s\n' "${tool_id} opted out for this project. Enforcements disabled — use direct docs reads per §2g-i advisory path."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "$tool_id"; then
        cat <<EOF
${tool_id} opted in but install failed — enforcement suspended until upgrade; retry on /sb:update.
User consent preserved. Hooks treat ${tool_id} as advisory until install succeeds.
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
        elif ! sb_graphify_index_exists "$project_root" "$config_file"; then
          printf '%s\n' "Graphify enabled — index missing. Run: graphify update . --no-cluster (expected $(sb_graphify_graph_rel_path "$config_file")). Hooks block substantive edits until built."
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
        elif ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
          printf '%s\n' "agentmemory enabled — export root missing. Run: mkdir -p $(sb_agentmemory_export_rel_path "$config_file")/memory $(sb_agentmemory_export_rel_path "$config_file")/snapshots"
        fi
      elif [[ "$tool_id" == "rtk" ]] && declare -f sb_rtk_cli_available >/dev/null 2>&1; then
        if ! sb_rtk_cli_available; then
          cat <<EOF
RTK enabled but CLI missing or wrong binary — install before substantive work (host: ${host}):

${install_lines}

Verify: rtk gain --help (rejects reachingforthejack/rtk). See docs/RTK.md.
EOF
        elif ! sb_rtk_platform_hook_present "$project_root" "$host" 2>/dev/null; then
          printf '%s\n' "RTK enabled — host hook not wired for ${host}. Run rtk init; hooks block until present."
        fi
      elif [[ "$tool_id" == "context_mode" ]] && declare -f sb_context_mode_cli_available >/dev/null 2>&1; then
        if ! sb_context_mode_node_ok "$config_file" 2>/dev/null; then
          printf '%s\n' "Context Mode enabled — Node >= $(sb_context_mode_min_node_version "$config_file") required before install."
        elif ! sb_context_mode_cli_available; then
          cat <<EOF
Context Mode enabled but not installed (host: ${host}):

${install_lines}

License: Elastic License 2.0 (ELv2) — not OSI-open. Restart the agent after plugin/MCP wiring. See docs/CONTEXT-MODE.md.
EOF
        elif ! sb_context_mode_instruction_fragment_present "$project_root" 2>/dev/null; then
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

# ---------------------------------------------------------------------------------------
# Five-tool parallel-routed stack
# ---------------------------------------------------------------------------------------

sb_stack_leanctx_active() {
  sb_recommended_tool_enforced "${1:-}" "leanctx"
}

# A route owner from the project config must name a stack tool.
sb_stack_owner_valid() {
  case "${1:-}" in
    leanctx|context_mode|rtk|graphify|agentmemory) return 0 ;;
  esac
  return 1
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
    if sb_stack_owner_valid "$owner"; then
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
