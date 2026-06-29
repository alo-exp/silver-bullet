# shellcheck shell=bash
# Pre-release host smoke isolation — shared helpers.
#
# Policy: never read or write the operator's regular host runtime homes
# (~/.claude, ~/.codex, ~/.cursor). Each smoke host gets a dedicated temp root
# under SB_PRE_RELEASE_SMOKE_ROOT (default: mktemp under ${TMPDIR}/sb-pre-release-smoke.*).
#
# Cursor CLI auth: env-only CURSOR_API_KEY + AGENT_CLI_CREDENTIAL_STORE=memory.
# Never call cursor-agent login/status or macOS Keychain (cursor-user).

if [[ -n "${_SB_PRE_RELEASE_ISOLATION_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SB_PRE_RELEASE_ISOLATION_LOADED=1

sb_smoke_original_home="${SB_SMOKE_ORIGINAL_HOME:-${HOME}}"
sb_smoke_original_cursor_home="${SB_SMOKE_ORIGINAL_CURSOR_HOME:-${CURSOR_HOME:-${sb_smoke_original_home}/.cursor}}"
sb_smoke_original_codex_home="${SB_SMOKE_ORIGINAL_CODEX_HOME:-${CODEX_HOME_ROOT:-${sb_smoke_original_home}}}"
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

sb_smoke_begin_cursor() {
  local root
  root="$(sb_smoke_host_root cursor)"
  sb_smoke_track_root "$root"

  export HOME="$root"
  export CURSOR_HOME="${root}/.cursor"
  export SILVER_BULLET_RUNTIME=cursor
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

# Cursor CLI credential store: in-memory only — never Keychain / cursor-user.
sb_smoke_cursor_cli_auth_env() {
  export AGENT_CLI_CREDENTIAL_STORE=memory

  if [[ -n "${CURSOR_API_KEY:-}" ]]; then
    return 0
  fi

  local key_file
  key_file="$(sb_smoke_root)/.cursor-api-key"
  if [[ -f "$key_file" ]]; then
    CURSOR_API_KEY="$(<"$key_file")"
    export CURSOR_API_KEY
    return 0
  fi

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
