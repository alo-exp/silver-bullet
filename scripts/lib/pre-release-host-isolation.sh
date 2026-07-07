# shellcheck shell=bash
# Pre-release host smoke isolation — shared helpers.
#
# Policy: never read or write the operator's regular host runtime homes
# (~/.claude, ~/.codex, ~/.cursor). Each smoke host gets a dedicated temp root
# under SB_PRE_RELEASE_SMOKE_ROOT (default: mktemp under ${TMPDIR}/sb-pre-release-smoke.*).
#
# Cursor CLI isolation (official mechanisms only):
#   - Fake HOME blocks global hooks/MCP/rules merge from operator profile
#   - CURSOR_CONFIG_DIR → isolated cli-config.json (permissions, approval mode)
#   - --plugin-dir loads plugin from repo disk (no install to ~/.cursor/plugins/)
#   - --workspace targets a throwaway checkout under the smoke root
# Do NOT use CURSOR_DATA_DIR, --config, or undocumented full ~/.cursor redirects.
#
# Cursor CLI auth: env-only CURSOR_API_KEY + AGENT_CLI_CREDENTIAL_STORE=memory.
# Never call cursor-agent login/status or macOS Keychain (cursor-user).

if [[ -n "${_SB_PRE_RELEASE_ISOLATION_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SB_PRE_RELEASE_ISOLATION_LOADED=1

sb_smoke_roots=()

sb_smoke_root() {
  if [[ -z "${SB_PRE_RELEASE_SMOKE_ROOT:-}" ]]; then
    SB_PRE_RELEASE_SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-pre-release-smoke.XXXXXX")"
    export SB_PRE_RELEASE_SMOKE_ROOT
  fi
  printf '%s\n' "$SB_PRE_RELEASE_SMOKE_ROOT"
}

sb_smoke_host_root() {
  local host="$1"
  local root
  root="$(sb_smoke_root)/${host}"
  mkdir -p "$root"
  printf '%s\n' "$root"
}

sb_smoke_track_root() {
  local root="$1"
  local existing
  if ((${#sb_smoke_roots[@]} > 0)); then
    for existing in "${sb_smoke_roots[@]}"; do
      [[ "$existing" == "$root" ]] && return 0
    done
  fi
  sb_smoke_roots+=("$root")
}

sb_smoke_begin_codex() {
  local root
  root="$(sb_smoke_host_root codex)"
  sb_smoke_track_root "$root"

  export HOME="$root"
  export CODEX_HOME_ROOT="$root"
  export SILVER_BULLET_RUNTIME=codex
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

sb_smoke_begin_claude() {
  local root
  root="$(sb_smoke_host_root claude)"
  sb_smoke_track_root "$root"

  export HOME="$root"
  export SILVER_BULLET_RUNTIME=claude
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

sb_smoke_cursor_plugin_dir() {
  local repo="${SB_PRE_RELEASE_REPO_ROOT:-}"
  if [[ -z "$repo" || ! -d "${repo}/plugins/silver-bullet" ]]; then
    return 1
  fi
  printf '%s\n' "${repo}/plugins/silver-bullet"
}

sb_smoke_cursor_workspace() {
  local root
  root="$(sb_smoke_host_root cursor)"
  printf '%s\n' "${root}/workspace"
}

sb_smoke_cursor_config_dir() {
  local root
  root="$(sb_smoke_host_root cursor)"
  printf '%s\n' "${root}/fake-home/.cursor"
}

sb_smoke_cursor_write_cli_config() {
  local config_dir="$1"
  mkdir -p "$config_dir"
  cat >"${config_dir}/cli-config.json" <<'EOF'
{
  "version": 1,
  "permissions": {
    "allow": [
      "Shell(bash *)",
      "Shell(echo *)",
      "Shell(pwd)",
      "Shell(test *)"
    ]
  }
}
EOF
}

# Cursor pre-release isolation: fake HOME + CURSOR_CONFIG_DIR (official).
# install-cursor.sh still resolves ~/.cursor as ${HOME}/.cursor inside fake HOME.
sb_smoke_begin_cursor() {
  local root fake_home workspace config_dir plugin_dir
  root="$(sb_smoke_host_root cursor)"
  sb_smoke_track_root "$root"

  fake_home="${root}/fake-home"
  workspace="${root}/workspace"
  config_dir="${fake_home}/.cursor"
  mkdir -p "$fake_home/.cursor" "$workspace"

  printf '%s\n' '{"version":1,"hooks":{}}' >"${config_dir}/hooks.json"
  printf '%s\n' '{"mcpServers":{}}' >"${config_dir}/mcp.json"
  sb_smoke_cursor_write_cli_config "$config_dir"

  export HOME="$fake_home"
  export CURSOR_CONFIG_DIR="$config_dir"
  unset CURSOR_HOME 2>/dev/null || true
  export SILVER_BULLET_RUNTIME=cursor
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  plugin_dir="$(sb_smoke_cursor_plugin_dir)" || plugin_dir=""
  export SB_SMOKE_CURSOR_WORKSPACE="$workspace"
  export SB_SMOKE_CURSOR_PLUGIN_DIR="$plugin_dir"
  export SB_SMOKE_CURSOR_FAKE_HOME="$fake_home"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

# Cursor CLI credential store: in-memory only — never Keychain / cursor-user.
# Auth resolution order: CURSOR_API_KEY → HOST_API_KEY (doc alias) → smoke-root
# file → operator file ~/.silver-bullet/cursor-api-key (gitignored, local only).
sb_smoke_cursor_cli_auth_env() {
  export AGENT_CLI_CREDENTIAL_STORE=memory

  if [[ -n "${CURSOR_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ -n "${HOST_API_KEY:-}" ]]; then
    CURSOR_API_KEY="$HOST_API_KEY"
    export CURSOR_API_KEY
    return 0
  fi

  local key_file
  for key_file in \
    "$(sb_smoke_root)/.cursor-api-key" \
    "${HOME}/.silver-bullet/cursor-api-key"; do
    if [[ -f "$key_file" ]]; then
      CURSOR_API_KEY="$(<"$key_file")"
      export CURSOR_API_KEY
      return 0
    fi
  done

  return 1
}

sb_smoke_cleanup() {
  local root
  if ((${#sb_smoke_roots[@]} > 0)); then
    for root in "${sb_smoke_roots[@]}"; do
      rm -rf "$root" 2>/dev/null || true
    done
  fi
  if [[ -n "${SB_PRE_RELEASE_SMOKE_ROOT:-}" && -d "$SB_PRE_RELEASE_SMOKE_ROOT" ]]; then
    rm -rf "$SB_PRE_RELEASE_SMOKE_ROOT" 2>/dev/null || true
  fi
  unset SB_PRE_RELEASE_SMOKE_ROOT
}

sb_smoke_resolve_previous_tag() {
  [[ -n "${SB_RC_PREVIOUS_TAG:-}" ]] && { printf '%s\n' "$SB_RC_PREVIOUS_TAG"; return 0; }
  local repo="${SB_PRE_RELEASE_REPO_ROOT:-}" tag
  [[ -d "${repo}/.git" ]] || return 1
  tag="$(git -C "$repo" tag --sort=-v:refname 2>/dev/null | sed -n '2p')"
  [[ -n "$tag" ]] && printf '%s\n' "$tag"
}

sb_smoke_checkout_at_tag() {
  local tag="$1" dest="$2" repo="${SB_PRE_RELEASE_REPO_ROOT:-}"
  [[ -d "${repo}/.git" ]] || return 1
  mkdir -p "$dest" && git -C "$repo" archive "$tag" | tar -x -C "$dest"
}

sb_smoke_rc_marker_dir() { printf '%s/rc-validation\n' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"; }

sb_smoke_write_rc_marker() {
  local host="$1" mode="$2" status="${3:-pass}" artifact="${4:-}" dir file
  dir="$(sb_smoke_rc_marker_dir)"; mkdir -p "$dir"; file="${dir}/${host}-${mode}"
  { printf 'host=%s\nmode=%s\nstatus=%s\n' "$host" "$mode" "$status"
    printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [[ -n "$artifact" ]] && printf 'artifact=%s\n' "$artifact"; } >"$file"
  printf '%s\n' "$file"
}

sb_smoke_rc_markers_complete() {
  local host mode dir file; dir="$(sb_smoke_rc_marker_dir)"
  for host in cursor codex claude; do for mode in fresh upgrade; do
    file="${dir}/${host}-${mode}"
    [[ -f "$file" ]] && grep -qE '^status=(pass|skip)$' "$file" || return 1
  done; done
}
