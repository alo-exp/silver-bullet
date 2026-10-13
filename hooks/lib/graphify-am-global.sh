# shellcheck shell=bash
# Graphify + agentmemory global setup — SB-independent synergy_max apply/verify.
# Sourced by: scripts/graphify-am-global-setup.sh

GA_SUPPORTED_HOSTS="claude codex opencode goose hermes"
GA_DEFAULT_PROFILE="synergy_max"
GA_DEFAULT_EXPORT_FALLBACK="${HOME}/.agentmemory/default-export"

ga_skip_host_hooks() {
  [[ "${CI:-}" == "true" ]] || [[ "${CI:-}" == "1" ]] \
    || [[ "${GA_SKIP_HOST_HOOKS:-0}" == "1" ]]
}

ga_dry_run() {
  [[ "${GA_GLOBAL_DRY_RUN:-0}" == "1" ]]
}

ga_agentmemory_home() {
  printf '%s' "${GA_AGENTMEMORY_HOME:-${HOME}/.agentmemory}"
}

ga_validate_host() {
  local host="${1:-}"
  case " ${GA_SUPPORTED_HOSTS} " in
    *" ${host} "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Goose runs on Pi upstream platform.
ga_graphify_upstream_platform() {
  local host="${1:-}"
  case "$host" in
    goose) printf 'pi' ;;
    *) printf '%s' "$host" ;;
  esac
}

ga_abs_export_path() {
  local repo="${1:-}"
  if [[ -n "$repo" ]]; then
    printf '%s/.agentmemory' "${repo%/}"
  else
    printf '%s' "${GA_DEFAULT_EXPORT_FALLBACK}"
  fi
}

ga_host_config_present() {
  local host="${1:-}"
  case "$host" in
    claude) [[ -f "${HOME}/.claude.json" ]] ;;
    codex) [[ -f "${HOME}/.codex/config.toml" ]] ;;
    opencode) [[ -f "${HOME}/.config/opencode/opencode.json" ]] ;;
    goose) [[ -f "${HOME}/.config/goose/config.yaml" ]] || [[ -d "${HOME}/.pi/agent" ]] ;;
    hermes) [[ -f "${HOME}/.hermes/config.yaml" ]] || [[ -d "${HOME}/.hermes" ]] ;;
    *) return 1 ;;
  esac
}

ga_graphify_pre_commands() {
  local host="${1:-}"
  local platform
  platform="$(ga_graphify_upstream_platform "$host")"
  case "$host" in
    claude) printf '%s\n' 'graphify install' ;;
    codex|opencode|hermes|goose)
      printf '%s\n' "graphify install --platform ${platform}"
      ;;
  esac
}

ga_graphify_post_commands() {
  local host="${1:-}"
  local platform
  platform="$(ga_graphify_upstream_platform "$host")"
  case "$host" in
    claude) printf '%s\n' 'graphify claude install' ;;
    codex) printf '%s\n' 'graphify codex install' ;;
    opencode) printf '%s\n' 'graphify opencode install' ;;
    hermes) printf '%s\n' 'graphify hermes install' ;;
    goose) printf '%s\n' 'graphify pi install' ;;
  esac
}

ga_agentmemory_commands() {
  local host="${1:-}"
  case "$host" in
    claude) printf '%s\n' 'agentmemory connect claude-code' ;;
    codex)
      printf '%s\n' \
        'codex plugin marketplace add rohitg00/agentmemory' \
        'codex plugin add agentmemory@agentmemory' \
        'agentmemory connect codex --with-hooks'
      ;;
    goose) printf '%s\n' 'agentmemory connect pi' ;;
    hermes) printf '%s\n' 'agentmemory connect hermes' ;;
    opencode) ;;
  esac
}

ga_graphify_global_artifact_path() {
  local host="${1:-}"
  case "$host" in
    claude) printf '%s/.codex/skills/graphify/SKILL.md' "${HOME}" ;;
    codex) printf '%s/.codex/skills/graphify/SKILL.md' "${HOME}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    goose) printf '%s/.pi/agent/skills/graphify/SKILL.md' "${HOME}" ;;
    hermes) printf '%s/.hermes/skills/graphify/SKILL.md' "${HOME}" ;;
    *) return 1 ;;
  esac
}

ga_agentmemory_global_artifact_path() {
  local host="${1:-}"
  case "$host" in
    claude) printf '%s/.claude.json' "${HOME}" ;;
    codex) printf '%s/.codex/config.toml' "${HOME}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    goose) printf '%s/.config/goose/config.yaml' "${HOME}" ;;
    hermes) printf '%s/.hermes/config.yaml' "${HOME}" ;;
    *) return 1 ;;
  esac
}

ga_graphify_artifact_present() {
  local host="${1:-}" artifact
  artifact="$(ga_graphify_global_artifact_path "$host" 2>/dev/null || true)"
  [[ -n "$artifact" && -f "$artifact" ]] || return 1
  grep -q 'graphify' "$artifact" 2>/dev/null
}

ga_agentmemory_artifact_present() {
  local host="${1:-}" artifact
  artifact="$(ga_agentmemory_global_artifact_path "$host" 2>/dev/null || true)"
  [[ -n "$artifact" && -f "$artifact" ]] || return 1
  grep -q 'agentmemory' "$artifact" 2>/dev/null
}

ga_merge_agentmemory_env() {
  local arg="${1:-}"
  local export_abs
  if [[ "$arg" == */.agentmemory ]]; then
    export_abs="$arg"
  elif [[ -n "$arg" ]]; then
    export_abs="$(ga_abs_export_path "$arg")"
  else
    export_abs="$(ga_abs_export_path "")"
  fi
  local am_home env_file
  am_home="$(ga_agentmemory_home)"
  env_file="${am_home}/.env"
  mkdir -p "$am_home"
  local template="# === graphify-am synergy_max managed block ===
AGENTMEMORY_INJECT_CONTEXT=true
AGENTMEMORY_AUTO_COMPRESS=false
CONSOLIDATION_ENABLED=false
OBSIDIAN_AUTO_EXPORT=true
CLAUDE_MEMORY_BRIDGE=true
AGENTMEMORY_EXPORT_ROOT=${export_abs}
# === end graphify-am synergy_max managed block ==="
  if ga_dry_run; then
    printf 'DRY-RUN: merge %s (backup .env.bak)\n' "$env_file"
    return 0
  fi
  [[ -f "$env_file" ]] && cp "$env_file" "${env_file}.bak"
  if [[ -f "$env_file" ]] && grep -q '# === graphify-am synergy_max managed block ===' "$env_file"; then
    local tmp
    tmp="$(mktemp)"
    awk '
      /^# === graphify-am synergy_max managed block ===/ { skip=1; next }
      /^# === end graphify-am synergy_max managed block ===/ { skip=0; next }
      skip==0 { print }
    ' "$env_file" >"$tmp"
    mv "$tmp" "$env_file"
  fi
  printf '\n%s\n' "$template" >>"$env_file"
  chmod 600 "$env_file" 2>/dev/null || true
}

ga_opencode_merge_agentmemory_mcp() {
  local cfg="${HOME}/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$cfg")"
  if ga_dry_run; then
    printf 'DRY-RUN: merge agentmemory MCP into %s\n' "$cfg"
    return 0
  fi
  if [[ ! -f "$cfg" ]]; then
    cat >"$cfg" <<'JSON'
{"$schema":"https://opencode.ai/config.json","mcp":{"agentmemory":{"type":"stdio","command":"npx","args":["-y","@agentmemory/mcp"],"env":{"AGENTMEMORY_URL":"http://localhost:3111"}}}}
JSON
    return 0
  fi
  command -v jq >/dev/null 2>&1 || return 1
  local tmp
  tmp="$(mktemp)"
  jq '.mcp.agentmemory = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@agentmemory/mcp"],
    "env": { "AGENTMEMORY_URL": "http://localhost:3111" }
  }' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
}

ga_launchd_server_plist() {
  local export_abs="${1:-$(ga_abs_export_path "")}"
  local am_home node_path plist_dir plist_path
  am_home="$(ga_agentmemory_home)"
  node_path="$(command -v node 2>/dev/null || printf '%s' /usr/local/bin/node)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.server.plist"
  mkdir -p "$plist_dir"
  if ga_dry_run; then
    printf 'DRY-RUN: write %s\n' "$plist_path"
    return 0
  fi
  local am_bin
  am_bin="$(command -v agentmemory 2>/dev/null || printf '%s' "${HOME}/.npm-global/bin/agentmemory")"
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
    <string>${am_bin}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENTMEMORY_EXPORT_ROOT</key>
    <string>${export_abs}</string>
  </dict>
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
  launchctl bootout "gui/$(id -u)/com.agentmemory.server" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null \
    || launchctl load "$plist_path" 2>/dev/null || true
}

ga_launchd_bridge_plist() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || return 0
  local bridge_script python_path plist_dir plist_path gitleaks_bin path_env
  bridge_script="$(ga_agentmemory_home)/bridge.py"
  [[ -f "$bridge_script" ]] || return 0
  python_path="$(command -v python3 2>/dev/null || printf '%s' /usr/bin/python3)"
  gitleaks_bin="$(ga_gitleaks_path)"
  path_env="$(ga_bridge_path_env)"
  plist_dir="${HOME}/Library/LaunchAgents"
  plist_path="${plist_dir}/com.agentmemory.bridge.plist"
  mkdir -p "$plist_dir" "${repo}/.agentmemory"
  if ga_dry_run; then
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

ga_graphify_cli_available() {
  command -v graphify >/dev/null 2>&1
}

ga_agentmemory_cli_available() {
  command -v agentmemory >/dev/null 2>&1
}

ga_agentmemory_server_healthy() {
  command -v curl >/dev/null 2>&1 \
    && curl -sf "http://localhost:3111/agentmemory/health" >/dev/null 2>&1
}

ga_gitleaks_path() {
  command -v gitleaks 2>/dev/null || printf ''
}

ga_bridge_path_env() {
  local gitleaks_bin path_prefix gdir
  gitleaks_bin="$(ga_gitleaks_path)"
  path_prefix="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
  if [[ -n "$gitleaks_bin" ]]; then
    gdir="$(dirname "$gitleaks_bin")"
    if [[ ":${path_prefix}:" != *":${gdir}:"* ]]; then
      path_prefix="${gdir}:${path_prefix}"
    fi
  fi
  printf '%s' "$path_prefix"
}

ga_ensure_gitleaks() {
  if ga_gitleaks_path >/dev/null; then
    return 0
  fi
  if ga_dry_run; then
    if command -v brew >/dev/null 2>&1; then
      printf 'DRY-RUN: brew install gitleaks\n'
    else
      printf 'DRY-RUN: install gitleaks — brew install gitleaks (macOS) or apt install gitleaks (Linux)\n'
    fi
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    brew install gitleaks 2>/dev/null || {
      printf 'WARN: gitleaks brew install failed — bridge regex scan only\n'
      return 1
    }
  elif command -v apt-get >/dev/null 2>&1; then
    printf 'WARN: install gitleaks — sudo apt-get install gitleaks (Debian/Ubuntu) or GitHub releases\n'
    return 1
  else
    printf 'WARN: gitleaks not installed — brew install gitleaks (macOS) or see docs/AGENTMEMORY.md\n'
    return 1
  fi
  ga_gitleaks_path >/dev/null
}

ga_graphify_hooks_installed() {
  command -v graphify >/dev/null 2>&1 || return 1
  graphify hook status 2>/dev/null | grep -qiE 'installed|active|enabled'
}

ga_run_cmd() {
  local cmd="$1"
  if ga_dry_run; then
    printf 'DRY-RUN: %s\n' "$cmd"
    return 0
  fi
  eval "$cmd" 2>/dev/null || true
}

ga_apply_shared_agentmemory() {
  local repo="${1:-}"
  local export_abs
  export_abs="$(ga_abs_export_path "$repo")"
  mkdir -p "$export_abs/memory" "$export_abs/snapshots"
  if command -v agentmemory >/dev/null 2>&1; then
    ga_run_cmd 'agentmemory init'
  fi
  ga_merge_agentmemory_env "$export_abs"
  ga_ensure_gitleaks
  if ! ga_skip_host_hooks && command -v launchctl >/dev/null 2>&1; then
    ga_launchd_server_plist "$export_abs"
    ga_launchd_bridge_plist "$repo"
  fi
}

ga_apply_graphify_host() {
  local host="${1:-}"
  ga_graphify_cli_available || return 0
  local cmd
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    ga_run_cmd "$cmd"
  done < <(ga_graphify_pre_commands "$host")
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    ga_run_cmd "$cmd"
  done < <(ga_graphify_post_commands "$host")
  if ! ga_skip_host_hooks; then
    ga_run_cmd 'graphify hook install'
  fi
}

ga_apply_agentmemory_host() {
  local host="${1:-}"
  ga_agentmemory_cli_available || return 0
  local cmd
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    ga_run_cmd "$cmd"
  done < <(ga_agentmemory_commands "$host")
  if [[ "$host" == "opencode" ]]; then
    ga_opencode_merge_agentmemory_mcp
  fi
}

ga_apply_host() {
  local host="${1:-}" repo="${2:-}"
  printf '== graphify-am global apply (host=%s, profile=%s) ==\n' "$host" "$GA_DEFAULT_PROFILE"
  ga_apply_shared_agentmemory "$repo"
  ga_apply_graphify_host "$host"
  ga_apply_agentmemory_host "$host"
  if [[ -n "$repo" ]] && ga_graphify_cli_available; then
  if ga_dry_run; then
    printf 'DRY-RUN: graphify update %s --no-cluster\n' "$repo"
  else
    (cd "$repo" && graphify update . --no-cluster) 2>/dev/null || true
  fi
  fi
}

ga_verify_host() {
  local host="${1:-}" repo="${2:-}"
  local fails=0 warns=0 pass=0
  local report=""

  _ga_check() {
    local status="$1" label="$2" detail="$3"
    case "$status" in
      pass) pass=$((pass + 1)); report+="  [x] ${label}: ${detail}\n" ;;
      warn) warns=$((warns + 1)); report+="  [!] ${label}: ${detail}\n" ;;
      fail) fails=$((fails + 1)); report+="  [ ] ${label}: ${detail}\n" ;;
    esac
  }

  if ga_graphify_cli_available; then
    _ga_check pass graphify-cli "$(command -v graphify)"
  else
    _ga_check fail graphify-cli "not on PATH — uv tool install graphifyy"
  fi

  if ga_agentmemory_cli_available; then
    _ga_check pass agentmemory-cli "$(command -v agentmemory)"
  else
    _ga_check fail agentmemory-cli "not on PATH — npm install -g @agentmemory/agentmemory"
  fi

  if ga_agentmemory_server_healthy; then
    _ga_check pass agentmemory-server "http://localhost:3111/agentmemory/health"
  else
    _ga_check fail agentmemory-server "not healthy — launch agentmemory or check launchd"
  fi

  local env_file
  env_file="$(ga_agentmemory_home)/.env"
  if [[ -f "$env_file" ]] && grep -q 'AGENTMEMORY_INJECT_CONTEXT=true' "$env_file" 2>/dev/null; then
    _ga_check pass agentmemory-env "synergy_max flags in ${env_file}"
  else
    _ga_check warn agentmemory-env "missing synergy_max block — run --apply"
  fi

  if ga_graphify_artifact_present "$host"; then
    _ga_check pass graphify-platform "${host} artifact wired"
  else
    _ga_check warn graphify-platform "missing $(ga_graphify_global_artifact_path "$host" 2>/dev/null || echo artifact)"
  fi

  if [[ "$host" == "opencode" ]]; then
    if ga_agentmemory_artifact_present "$host"; then
      _ga_check pass agentmemory-platform "opencode MCP in opencode.json"
    else
      _ga_check warn agentmemory-platform "merge agentmemory MCP — run --apply"
    fi
  elif ga_agentmemory_artifact_present "$host"; then
    _ga_check pass agentmemory-platform "${host} config references agentmemory"
  else
    _ga_check warn agentmemory-platform "missing $(ga_agentmemory_global_artifact_path "$host" 2>/dev/null || echo config)"
  fi

  if ga_graphify_hooks_installed; then
    _ga_check pass graphify-hooks "git template hooks installed"
  else
    _ga_check warn graphify-hooks "run graphify hook install"
  fi

  if ga_gitleaks_path >/dev/null; then
    _ga_check pass gitleaks "installed ($(ga_gitleaks_path))"
  else
    _ga_check warn gitleaks "required for bridge second-line scan — brew install gitleaks"
  fi

  if [[ -n "$repo" && -f "${repo}/graphify-out/graph.json" ]]; then
    _ga_check pass graphify-index "index at ${repo}/graphify-out/graph.json"
  elif [[ -n "$repo" ]]; then
    _ga_check warn graphify-index "no index — cd ${repo} && graphify update . --no-cluster"
  fi

  export GA_VERIFY_PASS="$pass"
  export GA_VERIFY_FAILS="$fails"
  export GA_VERIFY_WARNS="$warns"
  export GA_VERIFY_REPORT="$report"
  printf '== graphify-am verify (host=%s) ==\n' "$host"
  printf '%b' "$report"
  printf 'Summary: %s passed, %s failed, %s warnings\n' "$pass" "$fails" "$warns"
  [[ "$fails" -eq 0 ]]
}

ga_detect_configured_hosts() {
  local host
  for host in $GA_SUPPORTED_HOSTS; do
    if ga_host_config_present "$host"; then
      printf '%s\n' "$host"
    fi
  done
}
