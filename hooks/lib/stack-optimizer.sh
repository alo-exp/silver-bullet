# shellcheck shell=bash
# Stack optimizer — Graphify + agentmemory synergy_max apply/verify/score.
# Sourced by: sb-optimize-stack.sh, sb-verify-synergy.sh, sb-diagnostics.sh, prompt-reminder.sh
#
# Machine-wide changes (host hook/plugin wiring, ~/.agentmemory/.env, LaunchAgents, brew
# installs) need the user's own consent (user-consent.sh): "wire" for configuration and
# "install" for packages. Only built-in command tables run; nothing from the project's
# .silver-bullet.json is evaluated, and profile knobs are validated before use.

_sb_stack_opt_lib_dir="${BASH_SOURCE[0]%/*}"
# shellcheck source=recommended-tools.sh
source "${_sb_stack_opt_lib_dir}/recommended-tools.sh"
# shellcheck source=graphify-gate.sh
source "${_sb_stack_opt_lib_dir}/graphify-gate.sh"
# shellcheck source=agentmemory-gate.sh
source "${_sb_stack_opt_lib_dir}/agentmemory-gate.sh"

_sb_stack_default_profile="synergy_max"
_sb_stack_score_threshold=70
_sb_stack_score_cache_seconds=600

sb_stack_optimizer_dry_run() {
  [[ "${SB_STACK_OPTIMIZER_DRY_RUN:-0}" == "1" ]]
}

sb_stack_skip_host_hooks() {
  [[ "${CI:-}" == "true" ]] || [[ "${CI:-}" == "1" ]] || [[ "${SB_STACK_SKIP_HOST_HOOKS:-0}" == "1" ]]
}

sb_stack_agentmemory_home() {
  printf '%s' "${SB_AGENTMEMORY_HOME:-${HOME}/.agentmemory}"
}

sb_stack_optimization_profile_name() {
  local config_file="${1:-}" profile=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    profile="$(jq -r '.recommended_tools.graphify.optimization.profile
       // .recommended_tools.agentmemory.optimization.profile // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  [[ "$profile" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || profile="${_sb_stack_default_profile}"
  printf '%s' "$profile"
}

# A profile knob from the project config, accepted only when it is one of ALLOWED
# (space-separated); anything else (a newline, an extra NAME=value) yields DEFAULT.
sb_stack_profile_knob() {
  local config_file="${1:-}" profile="${2:-}" area="${3:-}" key="${4:-}" default="${5:-}"
  local allowed="${6:-true false}" val=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # jq's // would turn an explicit false into the default; test for null instead.
    val="$(jq -r --arg p "$profile" --arg a "$area" --arg k "$key" \
      '.optimization_profiles[$p][$a][$k] | if . == null then "" else tostring end' "$config_file" 2>/dev/null || true)"
  fi
  if [[ -z "$val" ]]; then
    val="$default"
  else
    case " ${allowed} " in
      *" ${val} "*) ;;
      *) val="$default" ;;
    esac
  fi
  printf '%s' "$val"
}

sb_stack_graphify_hooks_installed() {
  local repo="${1:-$PWD}"
  grep -q 'graphify' "${repo}/.git/hooks/post-commit" 2>/dev/null && return 0
  grep -q 'graphify' "${repo}/.git/hooks/post-checkout" 2>/dev/null && return 0
  command -v graphify >/dev/null 2>&1 || return 1
  grep -qiE 'installed|active|enabled' < <(graphify hook status 2>/dev/null)
}

sb_stack_ensure_agentmemory_gitignore() {
  local repo="${1:-$PWD}" gitignore
  gitignore="${repo}/.gitignore"
  [[ -f "$gitignore" ]] || touch "$gitignore"
  if grep -q '# === agentmemory managed block ===' "$gitignore" 2>/dev/null; then
    if ! grep -q '!.agentmemory/memory/\*\*' "$gitignore" 2>/dev/null; then
      if sb_stack_optimizer_dry_run; then
        printf 'DRY-RUN: fix agentmemory gitignore /** negation in %s\n' "$gitignore"
      else
        sed -i.bak 's|!.agentmemory/memory/$|!.agentmemory/memory/**|' "$gitignore" 2>/dev/null \
          && rm -f -- "${gitignore}.bak"
      fi
    fi
    return 0
  fi
  local block='# === agentmemory managed block ===
# Most contents are gitignored, specific files committed
.agentmemory/*
!.agentmemory/memory/
!.agentmemory/memory/**
!.agentmemory/snapshots/
!.agentmemory/snapshots/**
!.agentmemory/profile.md
# === end agentmemory managed block ==='
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: append agentmemory gitignore block to %s\n' "$gitignore"
  else
    printf '\n%s\n' "$block" >>"$gitignore"
  fi
}

# Status 0 when VALUE can be written as one line of an env file or plist string.
_sb_stack_plain_value() {
  local v="${1:-}"
  [[ -n "$v" ]] || return 1
  case "$v" in
    *$'\n'* | *$'\r'* | *$'\t'* | *'<'* | *'>'* | *'&'* | *'"'*) return 1 ;;
  esac
  return 0
}

sb_stack_merge_agentmemory_env() {
  local repo="${1:-$PWD}" config_file="${2:-}" profile="${3:-synergy_max}"
  local am_home export_abs env_file inject compress obsidian bridge
  am_home="$(sb_stack_agentmemory_home)"
  export_abs="$(sb_agentmemory_abs_export_path "$repo" "$config_file" 2>/dev/null || true)"
  _sb_stack_plain_value "$export_abs" || return 1
  env_file="${am_home}/.env"
  inject="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory inject_context true)"
  compress="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory auto_compress false)"
  obsidian="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory obsidian_export true)"
  bridge="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory bridge_enabled true)"
  local template="# === SB synergy_max managed block ===
AGENTMEMORY_INJECT_CONTEXT=${inject}
AGENTMEMORY_AUTO_COMPRESS=${compress}
CONSOLIDATION_ENABLED=false
OBSIDIAN_AUTO_EXPORT=${obsidian}
CLAUDE_MEMORY_BRIDGE=${bridge}
AGENTMEMORY_EXPORT_ROOT=${export_abs}
# === end SB synergy_max managed block ==="
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: merge %s (backup .env.bak)\n' "$env_file"
    return 0
  fi
  mkdir -p "$am_home"
  local tmp
  tmp="$(mktemp "${env_file}.XXXXXX")" || return 1
  if [[ -f "$env_file" ]]; then
    cp -p "$env_file" "${env_file}.bak"
    awk '
      /^# === SB synergy_max managed block ===/ { skip=1; next }
      /^# === end SB synergy_max managed block ===/ { skip=0; next }
      skip==0 { print }
    ' "$env_file" >"$tmp"
  fi
  printf '\n%s\n' "$template" >>"$tmp"
  chmod 600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$env_file"
}

# XML-escape a value for a plist <string>.
_sb_stack_xml() {
  local v="${1:-}"
  v="${v//&/&amp;}"
  v="${v//</&lt;}"
  v="${v//>/&gt;}"
  printf '%s' "$v"
}

sb_stack_launchd_server_plist() {
  local repo="${1:-$PWD}" am_home node_path plist_dir plist_path am_bin export_abs
  am_home="$(sb_stack_agentmemory_home)"
  node_path="$(command -v node 2>/dev/null || printf '%s' /usr/local/bin/node)"
  am_bin="$(command -v agentmemory 2>/dev/null || printf '%s' "${HOME}/.npm-global/bin/agentmemory")"
  export_abs="$(sb_agentmemory_abs_export_path "$repo" "${2:-}" 2>/dev/null || true)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.server.plist"
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: write %s\n' "$plist_path"
    return 0
  fi
  mkdir -p "$plist_dir"
  cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentmemory.server</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(_sb_stack_xml "$node_path")</string>
    <string>$(_sb_stack_xml "$am_bin")</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENTMEMORY_EXPORT_ROOT</key>
    <string>$(_sb_stack_xml "$export_abs")</string>
  </dict>
  <key>WorkingDirectory</key>
  <string>$(_sb_stack_xml "$repo")</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$(_sb_stack_xml "${am_home}/server.log")</string>
  <key>StandardErrorPath</key>
  <string>$(_sb_stack_xml "${am_home}/server.log")</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/com.agentmemory.server" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null \
    || launchctl load "$plist_path" 2>/dev/null || true
}

sb_stack_launchd_bridge_plist() {
  local repo="${1:-$PWD}" python_path plist_dir plist_path bridge_script gitleaks_bin path_env
  bridge_script="$(sb_stack_agentmemory_home)/bridge.py"
  [[ -f "$bridge_script" ]] || return 0
  python_path="$(command -v python3 2>/dev/null || printf '%s' /usr/bin/python3)"
  gitleaks_bin="$(sb_stack_gitleaks_path)"
  path_env="$(sb_stack_bridge_path_env)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.bridge.plist"
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: write %s\n' "$plist_path"
    return 0
  fi
  mkdir -p "$plist_dir"
  cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentmemory.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(_sb_stack_xml "$python_path")</string>
    <string>$(_sb_stack_xml "$bridge_script")</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENTMEMORY_REPO_ROOT</key>
    <string>$(_sb_stack_xml "$repo")</string>
    <key>GITLEAKS_PATH</key>
    <string>$(_sb_stack_xml "${gitleaks_bin:-gitleaks}")</string>
    <key>PATH</key>
    <string>$(_sb_stack_xml "$path_env")</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$(_sb_stack_xml "${repo}/.agentmemory/bridge.log")</string>
  <key>StandardErrorPath</key>
  <string>$(_sb_stack_xml "${repo}/.agentmemory/bridge.log")</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/com.agentmemory.bridge" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null \
    || launchctl load "$plist_path" 2>/dev/null || true
}

sb_stack_bridge_running() {
  if command -v launchctl >/dev/null 2>&1; then
    grep -q 'com.agentmemory.bridge' < <(launchctl list 2>/dev/null) && return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user is-active agentmemory-bridge >/dev/null 2>&1 && return 0
  fi
  command -v pgrep >/dev/null 2>&1 && pgrep -f 'bridge.py' >/dev/null 2>&1
}

sb_stack_gitleaks_path() {
  command -v gitleaks 2>/dev/null || printf ''
}

sb_stack_gitleaks_required() {
  local config_file="${1:-}" profile="${2:-}" req rec
  profile="${profile:-$(sb_stack_optimization_profile_name "$config_file")}"
  req="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory gitleaks_required false)"
  rec="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory gitleaks_recommended false)"
  [[ "$req" == "true" || "$rec" == "true" ]]
}

sb_stack_bridge_path_env() {
  local gitleaks_bin path_prefix gdir
  gitleaks_bin="$(sb_stack_gitleaks_path)"
  path_prefix="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
  if [[ -n "$gitleaks_bin" ]]; then
    gdir="$(dirname "$gitleaks_bin")"
    if [[ ":${path_prefix}:" != *":${gdir}:"* ]]; then
      path_prefix="${gdir}:${path_prefix}"
    fi
  fi
  printf '%s' "$path_prefix"
}

sb_stack_ensure_gitleaks() {
  local config_file="${1:-}" profile="${2:-}"
  profile="${profile:-$(sb_stack_optimization_profile_name "$config_file")}"
  sb_stack_gitleaks_required "$config_file" "$profile" || return 0

  # sb_stack_gitleaks_path always exits 0 (empty output when absent): test the output.
  if [[ -n "$(sb_stack_gitleaks_path)" ]]; then
    return 0
  fi

  if sb_stack_optimizer_dry_run; then
    if command -v brew >/dev/null 2>&1; then
      printf 'DRY-RUN: brew install gitleaks\n'
    else
      printf 'DRY-RUN: install gitleaks — brew install gitleaks (macOS) or apt install gitleaks (Linux)\n'
    fi
    return 0
  fi

  # A package install needs the user's install consent for agentmemory (it backs the bridge).
  if ! sb_consent_granted agentmemory install; then
    printf 'WARN: gitleaks missing — install it yourself (brew install gitleaks), or grant consent: bash %s grant agentmemory --all-projects --capabilities install\n' \
      "$(sb_rt_plugin_script scripts/sb-consent.sh)"
    return 1
  fi
  if command -v brew >/dev/null 2>&1; then
    brew install gitleaks 2>/dev/null || printf 'WARN: gitleaks brew install failed — bridge regex scan only\n'
  elif command -v apt-get >/dev/null 2>&1; then
    printf 'WARN: install gitleaks — sudo apt-get install gitleaks (Debian/Ubuntu) or download from GitHub releases\n'
  else
    printf 'WARN: gitleaks not installed — brew install gitleaks (macOS) or see docs/AGENTMEMORY.md\n'
  fi

  [[ -n "$(sb_stack_gitleaks_path)" ]]
}

sb_stack_server_persistence_ok() {
  if command -v launchctl >/dev/null 2>&1; then
    grep -q 'com.agentmemory.server' < <(launchctl list 2>/dev/null) && return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user is-active agentmemory >/dev/null 2>&1 && return 0
  fi
  sb_agentmemory_server_healthy "${1:-}" 2>/dev/null
}

# Built-in platform commands as words; @PLUGIN@ and @REPO@ are replaced after splitting, so
# paths with spaces stay one argument. These run without a shell (no eval).
_sb_stack_graphify_platform_words() {
  local phase="${1:-}" host="${2:-}"
  case "$phase:$host" in
    pre:claude) printf '%s\n' 'graphify install --project' ;;
    pre:codex|pre:opencode|pre:hermes) printf '%s\n' "graphify install --project --platform ${host}" ;;
    pre:goose) printf '%s\n' 'graphify install --project --platform pi' ;;
    pre:pi) printf '%s\n' 'python3 @PLUGIN@/scripts/lib/global-toolstack/install-pi.py --repo-root @REPO@' ;;
    post:cursor) printf '%s\n' 'graphify cursor install' ;;
    post:claude) printf '%s\n' 'graphify claude install --project' ;;
    post:codex) printf '%s\n' 'graphify codex install --project' ;;
  esac
}

_sb_stack_agentmemory_connect_words() {
  case "${1:-}" in
    claude) printf '%s\n' 'agentmemory connect claude-code' ;;
    codex) printf '%s\n' 'agentmemory connect codex --with-hooks' ;;
    goose|pi) printf '%s\n' 'agentmemory connect pi' ;;
    hermes) printf '%s\n' 'agentmemory connect hermes' ;;
  esac
}

# _sb_stack_run_words REPO LINE: run one built-in command (dry run prints it).
_sb_stack_run_words() {
  local repo="$1" line="$2" i
  local -a words
  read -r -a words <<<"$line"
  for i in "${!words[@]}"; do
    words[i]="${words[i]//@PLUGIN@/${_SB_RT_PLUGIN_ROOT}}"
    words[i]="${words[i]//@REPO@/${repo}}"
  done
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: %s\n' "${words[*]}"
    return 0
  fi
  (cd "$repo" && "${words[@]}") >/dev/null 2>&1 || true
}

sb_optimize_graphify() {
  local repo="${1:-$PWD}" config_file="${2:-}" host="${3:-}" profile install_hooks prefer_no_cluster line
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  host="${host:-$(sb_runtime_host)}"
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" ]] || return 0
  sb_graphify_cli_available || return 0

  install_hooks="$(sb_stack_profile_knob "$config_file" "$profile" graphify install_git_hooks true)"
  prefer_no_cluster="$(sb_stack_profile_knob "$config_file" "$profile" graphify prefer_no_cluster true)"

  # Host wiring (git template hooks, skill/plugin registration) is machine configuration.
  if sb_consent_granted graphify wire; then
    if [[ "$install_hooks" == "true" ]] && ! sb_stack_skip_host_hooks; then
      _sb_stack_run_words "$repo" 'graphify hook install'
    fi
    while IFS= read -r line; do
      [[ -n "$line" ]] && _sb_stack_run_words "$repo" "$line"
    done < <(_sb_stack_graphify_platform_words pre "$host"; _sb_stack_graphify_platform_words post "$host")
  else
    printf 'SKIP: graphify host wiring needs your consent: bash %s grant graphify --all-projects --capabilities wire\n' \
      "$(sb_rt_plugin_script scripts/sb-consent.sh)"
  fi

  if ! sb_graphify_index_exists "$repo" "$config_file"; then
    if [[ "$prefer_no_cluster" == "true" ]]; then
      _sb_stack_run_words "$repo" 'graphify update . --no-cluster'
    else
      _sb_stack_run_words "$repo" 'graphify update .'
    fi
  fi
  return 0
}

sb_optimize_agentmemory() {
  local repo="${1:-$PWD}" config_file="${2:-}" host="${3:-}" profile persistence line
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  host="${host:-$(sb_runtime_host)}"
  [[ "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0

  # The export root is scaffolded only when it resolves inside the project (a symlink pointing
  # elsewhere is refused), so the apply never creates directories outside the repository.
  sb_agentmemory_scaffold_export_root "$repo" "$config_file" || true
  sb_stack_ensure_agentmemory_gitignore "$repo"

  if ! sb_consent_granted agentmemory wire; then
    printf 'SKIP: agentmemory machine setup (~/.agentmemory/.env, LaunchAgents, host connect) needs your consent: bash %s grant agentmemory --all-projects --capabilities wire\n' \
      "$(sb_rt_plugin_script scripts/sb-consent.sh)"
    return 0
  fi
  sb_stack_merge_agentmemory_env "$repo" "$config_file" "$profile" || true

  # A missing gitleaks only degrades the bridge to regex scanning; never abort the apply.
  sb_stack_ensure_gitleaks "$config_file" "$profile" || true

  persistence="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory server_persistence launchd 'launchd systemd none')"
  if [[ "$persistence" == "launchd" ]] && command -v launchctl >/dev/null 2>&1 && ! sb_stack_skip_host_hooks; then
    sb_stack_launchd_server_plist "$repo" "$config_file"
    sb_stack_launchd_bridge_plist "$repo"
  fi

  if sb_agentmemory_cli_available; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && _sb_stack_run_words "$repo" "$line"
    done < <(_sb_stack_agentmemory_connect_words "$host")
  fi
  return 0
}

sb_optimize_synergy() {
  local repo="${1:-$PWD}" config_file="${2:-}" profile post_export export_abs base
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" ]] || return 0
  [[ "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0

  post_export="$(sb_stack_profile_knob "$config_file" "$profile" synergy post_export_graphify_update true)"
  if sb_agentmemory_server_healthy "$config_file" 2>/dev/null; then
    export_abs="$(sb_agentmemory_abs_export_path "$repo" "$config_file" 2>/dev/null || true)"
    # The URL is validated loopback (sb_agentmemory_health_url); the body is built by jq.
    base="$(sb_agentmemory_health_url "$config_file")"
    base="${base%/agentmemory/health}"
    if sb_stack_optimizer_dry_run; then
      printf 'DRY-RUN: POST obsidian export to %s\n' "$export_abs"
    elif [[ -n "$export_abs" ]] && command -v curl >/dev/null 2>&1; then
      curl -sf --max-time 10 --proto '=http,https' --max-redirs 0 --noproxy '*' -X POST \
        -H 'Content-Type: application/json' \
        -d "$(jq -cn --arg d "${export_abs}/memory" '{vaultDir: $d}')" \
        -- "${base}/agentmemory/obsidian/export" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$post_export" == "true" ]] && sb_graphify_cli_available; then
    if [[ "$(sb_stack_profile_knob "$config_file" "$profile" graphify prefer_no_cluster true)" == "true" ]]; then
      _sb_stack_run_words "$repo" 'graphify update . --no-cluster'
    else
      _sb_stack_run_words "$repo" 'graphify update .'
    fi
  fi
  return 0
}

sb_stack_graph_has_agentmemory_refs() {
  local repo="${1:-$PWD}" config_file="${2:-}" graph_path
  graph_path="$(sb_graphify_abs_graph_path "$repo" "$config_file")"
  [[ -f "$graph_path" ]] || return 1
  grep -q '\.agentmemory' "$graph_path" 2>/dev/null
}

sb_optimization_score() {
  local repo="${1:-$PWD}" config_file="${2:-}"
  local profile score=0 fails=0 warns=0
  local report=""
  profile="$(sb_stack_optimization_profile_name "$config_file")"

  _sb_score_check() {
    local status="$1" label="$2" detail="$3" weight="${4:-10}"
    case "$status" in
      pass) score=$((score + weight)); report+="${status}|${label}|${detail}|${weight}\n" ;;
      warn) score=$((score + weight / 2)); warns=$((warns + 1)); report+="${status}|${label}|${detail}|${weight}\n" ;;
      fail) fails=$((fails + 1)); report+="${status}|${label}|${detail}|${weight}\n" ;;
      skip) report+="skip|${label}|${detail}|0\n" ;;
    esac
  }

  if [[ "$(sb_recommended_tool_consent "$config_file" graphify)" != "enabled" ]]; then
    _sb_score_check skip "graphify-opt" "graphify not opted in" 0
  else
    if sb_graphify_cli_available; then
      _sb_score_check pass "graphify-cli" "CLI on PATH" 10
    else
      _sb_score_check fail "graphify-cli" "CLI missing" 10
    fi
    if sb_graphify_index_exists "$repo" "$config_file"; then
      _sb_score_check pass "graphify-index" "index present" 15
    else
      _sb_score_check fail "graphify-index" "index missing" 15
    fi
    if sb_stack_graphify_hooks_installed "$repo"; then
      _sb_score_check pass "graphify-hooks" "git hooks installed" 10
    else
      _sb_score_check warn "graphify-hooks" "git hooks missing — run sb-optimize-stack --apply" 10
    fi
    local gf_host
    gf_host="$(sb_runtime_host)"
    if sb_graphify_platform_artifact_present "$repo" "$gf_host" 2>/dev/null; then
      _sb_score_check pass "graphify-platform" "platform artifact (${gf_host})" 10
    else
      _sb_score_check warn "graphify-platform" "platform artifact missing" 10
    fi
  fi

  if [[ "$(sb_recommended_tool_consent "$config_file" agentmemory)" != "enabled" ]]; then
    _sb_score_check skip "agentmemory-opt" "agentmemory not opted in" 0
  else
    if sb_agentmemory_cli_available; then
      _sb_score_check pass "agentmemory-cli" "CLI on PATH" 10
    else
      _sb_score_check fail "agentmemory-cli" "CLI missing" 10
    fi
    if sb_agentmemory_server_healthy "$config_file" 2>/dev/null; then
      _sb_score_check pass "agentmemory-server" "server healthy" 15
    else
      _sb_score_check fail "agentmemory-server" "server not healthy" 15
    fi
    if sb_stack_server_persistence_ok "$config_file"; then
      _sb_score_check pass "agentmemory-persistence" "launchd/systemd or healthy" 10
    else
      _sb_score_check warn "agentmemory-persistence" "no launchd/systemd persistence" 10
    fi
    local env_file
    env_file="$(sb_stack_agentmemory_home)/.env"
    if [[ -f "$env_file" ]] && grep -q 'AGENTMEMORY_INJECT_CONTEXT=true' "$env_file" 2>/dev/null; then
      _sb_score_check pass "agentmemory-env" "synergy_max .env flags" 10
    else
      _sb_score_check warn "agentmemory-env" ".env missing synergy_max flags" 10
    fi
    if sb_stack_bridge_running; then
      _sb_score_check pass "agentmemory-bridge" "bridge running" 10
    else
      _sb_score_check warn "agentmemory-bridge" "bridge not running" 10
    fi
    if sb_stack_gitleaks_required "$config_file" "$profile"; then
      if [[ -n "$(sb_stack_gitleaks_path)" ]]; then
        _sb_score_check pass "gitleaks" "installed ($(sb_stack_gitleaks_path))" 5
      else
        _sb_score_check warn "gitleaks" "required but missing — brew install gitleaks" 5
      fi
    elif [[ -n "$(sb_stack_gitleaks_path)" ]]; then
      _sb_score_check pass "gitleaks" "installed" 5
    else
      _sb_score_check skip "gitleaks" "not required for profile" 0
    fi
  fi

  if [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" \
     && "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]]; then
    if sb_stack_graph_has_agentmemory_refs "$repo" "$config_file"; then
      _sb_score_check pass "synergy-index" "graph contains .agentmemory refs" 15
    else
      _sb_score_check fail "synergy-index" "graph missing .agentmemory refs" 15
    fi
  fi

  export SB_STACK_SCORE="$score"
  export SB_STACK_SCORE_FAILS="$fails"
  export SB_STACK_SCORE_WARNS="$warns"
  export SB_STACK_SCORE_REPORT="$report"
  printf '%s' "$score"
}

# Prompt nudge when the stack score is low. Shown only when the user has consented to wire
# Graphify or agentmemory (the apply changes machine settings), never as an order to run it,
# and the score is cached per project so prompts do not re-probe the machine.
sb_stack_optimization_prompt_line() {
  local repo="${1:-$PWD}" config_file="${2:-}" score threshold cache epoch="" cached="" now
  threshold="${SB_STACK_SCORE_THRESHOLD:-$_sb_stack_score_threshold}"
  [[ "$threshold" =~ ^[0-9]{1,3}$ ]] || threshold="$_sb_stack_score_threshold"
  [[ -f "$config_file" ]] || return 0
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" \
    || "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0
  sb_consent_granted graphify wire || sb_consent_granted agentmemory wire || return 0
  cache="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/stack-optimization-score.d/$(printf '%s' "$repo" | cksum | awk '{print $1}')"
  now="$(date +%s)"
  if [[ -f "$cache" && ! -L "$cache" ]]; then
    IFS=' ' read -r epoch cached <"$cache" || true
  fi
  if [[ "$epoch" =~ ^[0-9]{1,12}$ && "$cached" =~ ^[0-9]{1,3}$ ]] \
    && ((now - 10#$epoch >= 0 && now - 10#$epoch < _sb_stack_score_cache_seconds)); then
    score="$cached"
  else
    score="$(sb_optimization_score "$repo" "$config_file")"
    local tmp
    if mkdir -p "$(dirname "$cache")" 2>/dev/null && tmp="$(mktemp "${cache}.XXXXXX" 2>/dev/null)"; then
      if printf '%s %s\n' "$now" "$score" 2>/dev/null >"$tmp"; then
        mv -f -- "$tmp" "$cache" 2>/dev/null || rm -f -- "$tmp"
      else
        rm -f -- "$tmp"
      fi
    fi
  fi
  if ((score < threshold)); then
    printf 'STACK OPTIMIZATION: score %s/100 — ask the user before running bash %s --apply (it changes machine-wide agentmemory/Graphify settings; see docs/STACK-OPTIMIZATION.md)' \
      "$score" "$(sb_rt_plugin_script scripts/sb-optimize-stack.sh)"
  fi
}

sb_stack_update_config_timestamps() {
  local config_file="${1:-}" mode="${2:-apply}" score="${3:-}" ts
  [[ -f "$config_file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  [[ "$score" =~ ^[0-9]{1,3}$ ]] || score="null"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$mode" == "apply" ]]; then
    jq --arg ts "$ts" --argjson score "$score" \
      '.recommended_tools.graphify.optimization.last_applied_at = $ts
       | .recommended_tools.agentmemory.optimization.last_applied_at = $ts
       | .recommended_tools.graphify.optimization.score = $score
       | .recommended_tools.agentmemory.optimization.score = $score' \
      "$config_file" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
  elif [[ "$mode" == "verify" ]]; then
    jq --arg ts "$ts" --argjson score "$score" \
      '.recommended_tools.graphify.optimization.last_verified_at = $ts
       | .recommended_tools.agentmemory.optimization.last_verified_at = $ts
       | .recommended_tools.graphify.optimization.score = $score
       | .recommended_tools.agentmemory.optimization.score = $score' \
      "$config_file" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
  fi
}
