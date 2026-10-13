# shellcheck shell=bash
# Stack optimizer — Graphify + agentmemory synergy_max apply/verify/score.
# Sourced by: sb-optimize-stack.sh, sb-verify-synergy.sh, sb-diagnostics.sh

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/graphify-gate.sh" ]]; then
  # shellcheck source=graphify-gate.sh
  source "$(dirname "${BASH_SOURCE[0]}")/graphify-gate.sh"
fi
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/agentmemory-gate.sh" ]]; then
  # shellcheck source=agentmemory-gate.sh
  source "$(dirname "${BASH_SOURCE[0]}")/agentmemory-gate.sh"
fi

_sb_stack_default_profile="synergy_max"
_sb_stack_score_threshold=70

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
  local config_file="${1:-}"
  local profile="${_sb_stack_default_profile}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    profile="$(jq -r --arg def "$_sb_stack_default_profile" \
      '.recommended_tools.graphify.optimization.profile
       // .recommended_tools.agentmemory.optimization.profile
       // $def' "$config_file" 2>/dev/null || echo "$_sb_stack_default_profile")"
  fi
  [[ -n "$profile" && "$profile" != "null" ]] || profile="${_sb_stack_default_profile}"
  printf '%s' "$profile"
}

sb_stack_profile_knob() {
  local config_file="${1:-}" profile="${2:-}" area="${3:-}" key="${4:-}" default="${5:-}"
  local val
  val="$(jq -r --arg p "$profile" --arg a "$area" --arg k "$key" --arg def "$default" \
    '.optimization_profiles[$p][$a][$k] // $def' "$config_file" 2>/dev/null || echo "$default")"
  [[ "$val" == "null" ]] && val="$default"
  printf '%s' "$val"
}

sb_stack_graphify_hooks_installed() {
  local repo="${1:-$PWD}"
  if [[ -d "${repo}/.git/hooks" ]]; then
    grep -q 'graphify' "${repo}/.git/hooks/post-commit" 2>/dev/null && return 0
    grep -q 'graphify' "${repo}/.git/hooks/post-checkout" 2>/dev/null && return 0
  fi
  command -v graphify >/dev/null 2>&1 || return 1
  if graphify hook status >/dev/null 2>&1; then
    graphify hook status 2>/dev/null | grep -qiE 'installed|active|enabled'
    return $?
  fi
  return 1
}

sb_stack_ensure_agentmemory_gitignore() {
  local repo="${1:-$PWD}"
  local gitignore="${repo}/.gitignore"
  [[ -f "$gitignore" ]] || touch "$gitignore"
  if grep -q '# === agentmemory managed block ===' "$gitignore" 2>/dev/null; then
  if ! grep -q '!.agentmemory/memory/\*\*' "$gitignore" 2>/dev/null; then
    if sb_stack_optimizer_dry_run; then
      printf 'DRY-RUN: fix agentmemory gitignore /** negation in %s\n' "$gitignore"
    else
      sed -i.bak 's|!.agentmemory/memory/$|!.agentmemory/memory/**|' "$gitignore" 2>/dev/null \
        || sed -i '' 's|!.agentmemory/memory/$|!.agentmemory/memory/**|' "$gitignore" 2>/dev/null \
        || true
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

sb_stack_merge_agentmemory_env() {
  local repo="${1:-$PWD}" config_file="${2:-}" profile="${3:-synergy_max}"
  local am_home export_abs env_file
  am_home="$(sb_stack_agentmemory_home)"
  export_abs="$(sb_agentmemory_abs_export_path "$repo" "$config_file")"
  env_file="${am_home}/.env"
  mkdir -p "$am_home"
  local inject compress obsidian bridge
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
  [[ -f "$env_file" ]] && cp "$env_file" "${env_file}.bak"
  if [[ -f "$env_file" ]] && grep -q '# === SB synergy_max managed block ===' "$env_file"; then
    local tmp
    tmp="$(mktemp)"
    awk '
      /^# === SB synergy_max managed block ===/ { skip=1; next }
      /^# === end SB synergy_max managed block ===/ { skip=0; next }
      skip==0 { print }
    ' "$env_file" >"$tmp"
    mv "$tmp" "$env_file"
  fi
  printf '\n%s\n' "$template" >>"$env_file"
  chmod 600 "$env_file" 2>/dev/null || true
}

sb_stack_launchd_server_plist() {
  local repo="${1:-$PWD}" am_home
  am_home="$(sb_stack_agentmemory_home)"
  local node_path plist_dir plist_path
  node_path="$(command -v node 2>/dev/null || printf '%s' /usr/local/bin/node)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.server.plist"
  mkdir -p "$plist_dir"
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: write %s\n' "$plist_path"
    return 0
  fi
  cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentmemory.server</string>
  <key>ProgramArguments</key>
  <array>
    <string>${node_path}</string>
    <string>${HOME}/.npm-global/bin/agentmemory</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENTMEMORY_EXPORT_ROOT</key>
    <string>$(sb_agentmemory_abs_export_path "$repo" "${2:-}")</string>
  </dict>
  <key>WorkingDirectory</key>
  <string>${repo}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${am_home}/server.log</string>
  <key>StandardErrorPath</key>
  <string>${am_home}/server.log</string>
</dict>
</plist>
EOF
  if command -v agentmemory >/dev/null 2>&1; then
    local am_bin
    am_bin="$(command -v agentmemory)"
    /usr/bin/sed -i.bak "s|${HOME}/.npm-global/bin/agentmemory|${am_bin}|g" "$plist_path" 2>/dev/null \
      || sed -i '' "s|${HOME}/.npm-global/bin/agentmemory|${am_bin}|g" "$plist_path" 2>/dev/null || true
    rm -f -- "${plist_path}.bak"
  fi
  launchctl bootout "gui/$(id -u)/com.agentmemory.server" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null \
    || launchctl load "$plist_path" 2>/dev/null || true
}

sb_stack_launchd_bridge_plist() {
  local repo="${1:-$PWD}"
  local python_path plist_dir plist_path bridge_script gitleaks_bin path_env
  bridge_script="$(sb_stack_agentmemory_home)/bridge.py"
  [[ -f "$bridge_script" ]] || return 0
  python_path="$(command -v python3 2>/dev/null || printf '%s' /usr/bin/python3)"
  gitleaks_bin="$(sb_stack_gitleaks_path)"
  path_env="$(sb_stack_bridge_path_env)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.bridge.plist"
  mkdir -p "$plist_dir"
  if sb_stack_optimizer_dry_run; then
    printf 'DRY-RUN: write %s\n' "$plist_path"
    return 0
  fi
  cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentmemory.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>${python_path}</string>
    <string>${bridge_script}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENTMEMORY_REPO_ROOT</key>
    <string>${repo}</string>
    <key>GITLEAKS_PATH</key>
    <string>${gitleaks_bin:-gitleaks}</string>
    <key>PATH</key>
    <string>${path_env}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${repo}/.agentmemory/bridge.log</string>
  <key>StandardErrorPath</key>
  <string>${repo}/.agentmemory/bridge.log</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/com.agentmemory.bridge" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null \
    || launchctl load "$plist_path" 2>/dev/null || true
}

sb_stack_bridge_running() {
  if command -v launchctl >/dev/null 2>&1; then
    launchctl list 2>/dev/null | grep -q 'com.agentmemory.bridge' && return 0
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
  local config_file="${1:-}" profile="${2:-}"
  profile="${profile:-$(sb_stack_optimization_profile_name "$config_file")}"
  local req rec
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

  if sb_stack_gitleaks_path >/dev/null; then
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

  if command -v brew >/dev/null 2>&1; then
    brew install gitleaks 2>/dev/null || printf 'WARN: gitleaks brew install failed — bridge regex scan only\n'
  elif command -v apt-get >/dev/null 2>&1; then
    printf 'WARN: install gitleaks — sudo apt-get install gitleaks (Debian/Ubuntu) or download from GitHub releases\n'
  else
    printf 'WARN: gitleaks not installed — brew install gitleaks (macOS) or see docs/AGENTMEMORY.md\n'
  fi

  sb_stack_gitleaks_path >/dev/null
}

sb_stack_server_persistence_ok() {
  if command -v launchctl >/dev/null 2>&1; then
    launchctl list 2>/dev/null | grep -q 'com.agentmemory.server' && return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user is-active agentmemory >/dev/null 2>&1 && return 0
  fi
  sb_agentmemory_server_healthy "${1:-}" 2>/dev/null
}

sb_optimize_graphify() {
  local repo="${1:-$PWD}" config_file="${2:-}" host="${3:-}"
  local profile actions=0
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  host="${host:-$(sb_runtime_host)}"
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" ]] || return 0

  local install_hooks prefer_no_cluster
  install_hooks="$(sb_stack_profile_knob "$config_file" "$profile" graphify install_git_hooks true)"
  prefer_no_cluster="$(sb_stack_profile_knob "$config_file" "$profile" graphify prefer_no_cluster true)"

  if [[ "$install_hooks" == "true" ]] && ! sb_stack_skip_host_hooks; then
    if sb_graphify_cli_available; then
      if sb_stack_optimizer_dry_run; then
        printf 'DRY-RUN: graphify hook install\n'
      else
        graphify hook install 2>/dev/null || true
      fi
      actions=$((actions + 1))
    fi
  fi

  if sb_graphify_cli_available; then
    local cmd
    while IFS= read -r cmd; do
      [[ -n "$cmd" ]] || continue
      if sb_stack_optimizer_dry_run; then
        printf 'DRY-RUN: %s\n' "$cmd"
      else
        (cd "$repo" && eval "$cmd") 2>/dev/null || true
      fi
      actions=$((actions + 1))
    done < <(sb_recommended_tool_platform_pre_index_commands "$config_file" graphify "$host")
    while IFS= read -r cmd; do
      [[ -n "$cmd" ]] || continue
      if sb_stack_optimizer_dry_run; then
        printf 'DRY-RUN: %s\n' "$cmd"
      else
        (cd "$repo" && eval "$cmd") 2>/dev/null || true
      fi
      actions=$((actions + 1))
    done < <(sb_recommended_tool_platform_post_index_commands "$config_file" graphify "$host")

    if ! sb_graphify_index_exists "$repo" "$config_file"; then
      local cluster_flag=""
      [[ "$prefer_no_cluster" == "true" ]] && cluster_flag="--no-cluster"
      if sb_stack_optimizer_dry_run; then
        printf 'DRY-RUN: graphify update . %s\n' "$cluster_flag"
      else
        (cd "$repo" && graphify update . $cluster_flag) 2>/dev/null || true
      fi
      actions=$((actions + 1))
    fi
  fi
  return 0
}

sb_optimize_agentmemory() {
  local repo="${1:-$PWD}" config_file="${2:-}" host="${3:-}"
  local profile persistence
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  host="${host:-$(sb_runtime_host)}"
  [[ "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0

  mkdir -p "${repo}/.agentmemory/memory" "${repo}/.agentmemory/snapshots"
  sb_stack_ensure_agentmemory_gitignore "$repo"
  sb_stack_merge_agentmemory_env "$repo" "$config_file" "$profile"

  sb_stack_ensure_gitleaks "$config_file" "$profile"

  persistence="$(sb_stack_profile_knob "$config_file" "$profile" agentmemory server_persistence launchd)"
  if [[ "$persistence" == "launchd" ]] && command -v launchctl >/dev/null 2>&1 && ! sb_stack_skip_host_hooks; then
    sb_stack_launchd_server_plist "$repo" "$config_file"
    sb_stack_launchd_bridge_plist "$repo"
  fi

  local cmd
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    [[ "$cmd" == Verify* ]] && continue
    if sb_stack_optimizer_dry_run; then
      printf 'DRY-RUN: %s\n' "$cmd"
    else
      eval "$cmd" 2>/dev/null || true
    fi
  done < <(sb_recommended_tool_platform_post_index_commands "$config_file" agentmemory "$host")
  return 0
}

sb_optimize_synergy() {
  local repo="${1:-$PWD}" config_file="${2:-}"
  local profile post_export
  profile="$(sb_stack_optimization_profile_name "$config_file")"
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" ]] || return 0
  [[ "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0

  post_export="$(sb_stack_profile_knob "$config_file" "$profile" synergy post_export_graphify_update true)"
  if sb_agentmemory_server_healthy "$config_file" 2>/dev/null; then
    local export_abs url
    export_abs="$(sb_agentmemory_abs_export_path "$repo" "$config_file")"
    url="$(sb_agentmemory_health_url "$config_file")"
  url="${url%/agentmemory/health}"
    if sb_stack_optimizer_dry_run; then
      printf 'DRY-RUN: POST obsidian export to %s\n' "$export_abs"
    elif command -v curl >/dev/null 2>&1; then
      curl -sf -X POST "${url}/agentmemory/obsidian/export" \
        -H 'Content-Type: application/json' \
        -d "{\"vaultDir\":\"${export_abs}/memory\"}" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$post_export" == "true" ]] && sb_graphify_cli_available; then
    local prefer_no_cluster cluster_flag=""
    prefer_no_cluster="$(sb_stack_profile_knob "$config_file" "$profile" graphify prefer_no_cluster true)"
    [[ "$prefer_no_cluster" == "true" ]] && cluster_flag="--no-cluster"
    if sb_stack_optimizer_dry_run; then
      printf 'DRY-RUN: graphify update . %s (post-export)\n' "$cluster_flag"
    else
      (cd "$repo" && graphify update . $cluster_flag) 2>/dev/null || true
    fi
  fi
  return 0
}

sb_stack_graph_has_agentmemory_refs() {
  local repo="${1:-$PWD}" config_file="${2:-}" graph_path count
  graph_path="$(sb_graphify_abs_graph_path "$repo" "$config_file")"
  [[ -f "$graph_path" ]] || return 1
  count="$(grep -c '\.agentmemory' "$graph_path" 2>/dev/null || echo 0)"
  [[ "$count" -gt 0 ]]
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
      if sb_stack_gitleaks_path >/dev/null; then
        _sb_score_check pass "gitleaks" "installed ($(sb_stack_gitleaks_path))" 5
      else
        _sb_score_check warn "gitleaks" "required but missing — brew install gitleaks" 5
      fi
    elif sb_stack_gitleaks_path >/dev/null; then
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

sb_stack_optimization_prompt_line() {
  local repo="${1:-$PWD}" config_file="${2:-}" score threshold
  threshold="${SB_STACK_SCORE_THRESHOLD:-$_sb_stack_score_threshold}"
  [[ -f "$config_file" ]] || return 0
  [[ "$(sb_recommended_tool_consent "$config_file" graphify)" == "enabled" \
    || "$(sb_recommended_tool_consent "$config_file" agentmemory)" == "enabled" ]] || return 0
  score="$(sb_optimization_score "$repo" "$config_file")"
  if [[ "$score" -lt "$threshold" ]]; then
    printf 'STACK OPTIMIZATION: score %s/%s — run bash scripts/sb-optimize-stack.sh --apply (see docs/STACK-OPTIMIZATION.md)' "$score" "100"
  fi
}

sb_stack_update_config_timestamps() {
  local config_file="${1:-}" mode="${2:-apply}" score="${3:-}"
  [[ -f "$config_file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$mode" == "apply" ]]; then
    jq --arg ts "$ts" --argjson score "${score:-null}" \
      '.recommended_tools.graphify.optimization.last_applied_at = $ts
       | .recommended_tools.agentmemory.optimization.last_applied_at = $ts
       | .recommended_tools.graphify.optimization.score = $score
       | .recommended_tools.agentmemory.optimization.score = $score' \
      "$config_file" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
  elif [[ "$mode" == "verify" ]]; then
    jq --arg ts "$ts" --argjson score "${score:-null}" \
      '.recommended_tools.graphify.optimization.last_verified_at = $ts
       | .recommended_tools.agentmemory.optimization.last_verified_at = $ts
       | .recommended_tools.graphify.optimization.score = $score
       | .recommended_tools.agentmemory.optimization.score = $score' \
      "$config_file" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
  fi
}
