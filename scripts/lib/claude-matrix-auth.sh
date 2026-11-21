#!/usr/bin/env bash
# Matrix Claude auth helpers:
# - Export ~/.claude/settings.json env for interactive TUI (api_key hosts).
# - Strip settings API-key env when claude.ai OAuth conflicts (clean-env path).
# Shell unset / env -i alone is insufficient — interactive TUI needs exported env.

_claude_matrix_auth_backup=""
_claude_matrix_auth_prepared=0

claude_matrix_settings_path() {
  if [[ -n "${CLAUDE_SETTINGS_FILE:-}" && -f "${CLAUDE_SETTINGS_FILE}" ]]; then
    printf '%s\n' "${CLAUDE_SETTINGS_FILE}"
    return
  fi
  if [[ -n "${CLAUDE_CONFIG_DIR:-}" && -f "${CLAUDE_CONFIG_DIR}/settings.json" ]]; then
    printf '%s/settings.json\n' "${CLAUDE_CONFIG_DIR}"
    return
  fi
  printf '%s/.claude/settings.json\n' "${HOME}"
}

claude_matrix_auth_has_api_key_env() {
  local settings_file="$1"
  [[ -f "$settings_file" ]] || return 1
  jq -e '
    (.env.ANTHROPIC_API_KEY? // "") != ""
    or (.env.ANTHROPIC_AUTH_TOKEN? // "") != ""
    or (.env.ANTHROPIC_BASE_URL? // "") != ""
  ' "$settings_file" >/dev/null 2>&1
}

claude_matrix_auth_has_conflict() {
  local cli auth_status_json
  cli="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo claude)}"
  auth_status_json="$("$cli" auth status 2>/dev/null || true)"
  printf '%s' "$auth_status_json" | jq -e '
    (.authMethod == "claude.ai")
    and ((.apiKeySource? // "") == "ANTHROPIC_API_KEY")
  ' >/dev/null 2>&1
}

claude_matrix_settings_has_proxy_env() {
  local settings_file="$1"
  [[ -f "$settings_file" ]] || return 1
  jq -e '
    ((.env.ANTHROPIC_BASE_URL? // "") != "")
    or ((.env.ANTHROPIC_API_KEY? // "") | test("PROXY"; "i"))
  ' "$settings_file" >/dev/null 2>&1
}

claude_matrix_auth_should_strip_settings() {
  local settings_file
  settings_file="$(claude_matrix_settings_path)"
  if claude_matrix_auth_has_conflict; then
    return 0
  fi
  if [[ "${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-0}" == "1" ]] && claude_matrix_settings_has_proxy_env "$settings_file"; then
    return 0
  fi
  return 1
}

# The octal mode of a file (GNU stat first, BSD stat as the fallback), 600 when neither answers.
_claude_matrix_file_mode() {
  local mode
  mode="$(stat -c %a "$1" 2>/dev/null || true)"
  if [[ ! "$mode" =~ ^[0-7]+$ ]]; then
    mode="$(stat -f %Lp "$1" 2>/dev/null || true)"
  fi
  if [[ ! "$mode" =~ ^[0-7]+$ ]]; then
    mode=600
  fi
  printf '%s\n' "$mode"
}

# A SIGINT/SIGTERM during the stripped window restores the operator's settings, then re-raises
# the signal with its default action. SIGKILL cannot be caught: the backup stays next to the
# settings file and the next prepare puts it back first (R14-04).
_claude_matrix_auth_on_signal() {
  local sig="$1" me
  # BASHPID (the current subshell) where Bash has it; macOS Bash 3.2 does not, and `$$` would
  # name the parent shell when this runs inside a command substitution.
  me="${BASHPID:-$(sh -c 'echo $PPID')}"
  claude_matrix_auth_restore
  trap - INT TERM
  kill -s "$sig" "$me"
}

claude_matrix_auth_prepare() {
  local settings_file backup_file tmp_file mode
  settings_file="$(claude_matrix_settings_path)"
  # A backup left by a killed earlier run is the operator's real file: put it back first.
  if [[ -f "${settings_file}.sb-matrix-backup" ]]; then
    mv -f "${settings_file}.sb-matrix-backup" "$settings_file"
  fi
  if ! claude_matrix_auth_should_strip_settings; then
    return 0
  fi
  if ! claude_matrix_auth_has_api_key_env "$settings_file"; then
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'WARN: jq required to strip Claude settings API keys for matrix auth\n' >&2
    return 0
  fi

  # The backup lives beside the settings file (same mode via cp -p) so a restore is one atomic
  # rename that returns the operator's file byte for byte, mode included.
  backup_file="${settings_file}.sb-matrix-backup"
  cp -p "$settings_file" "$backup_file"
  _claude_matrix_auth_backup="$backup_file"

  # The stripped copy is written beside the original and given the original's mode before the
  # rename, so a 0600 settings file never becomes 0644.
  mode="$(_claude_matrix_file_mode "$settings_file")"
  tmp_file="$(mktemp "${settings_file}.matrix-auth.XXXXXX")"
  jq '
    if .env then
      .env |= del(
        .ANTHROPIC_API_KEY,
        .ANTHROPIC_AUTH_TOKEN,
        .ANTHROPIC_BASE_URL,
        .ANTHROPIC_DEFAULT_HAIKU_MODEL,
        .ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME,
        .ANTHROPIC_DEFAULT_SONNET_MODEL,
        .ANTHROPIC_DEFAULT_SONNET_MODEL_NAME,
        .ANTHROPIC_DEFAULT_OPUS_MODEL,
        .ANTHROPIC_DEFAULT_OPUS_MODEL_NAME
      )
    else
      .
    end
  ' "$settings_file" > "$tmp_file"
  chmod "$mode" "$tmp_file"
  mv "$tmp_file" "$settings_file"
  _claude_matrix_auth_prepared=1
  trap '_claude_matrix_auth_on_signal INT' INT
  trap '_claude_matrix_auth_on_signal TERM' TERM
}

claude_matrix_auth_restore() {
  local settings_file
  settings_file="$(claude_matrix_settings_path)"
  if [[ "$_claude_matrix_auth_prepared" == "1" && -n "$_claude_matrix_auth_backup" && -f "$_claude_matrix_auth_backup" ]]; then
    mv -f "$_claude_matrix_auth_backup" "$settings_file"
    trap - INT TERM
  fi
  _claude_matrix_auth_backup=""
  _claude_matrix_auth_prepared=0
}

# Export ~/.claude/settings.json env into the current shell so interactive Claude
# matches `claude --print` api_key auth. Project-level settings lack API keys;
# the TUI does not inject global settings env unless it is exported here.
claude_matrix_should_export_settings_env() {
  if [[ "${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-0}" == "1" || "${CLAUDE_PRINT_SKIP_SETTINGS_EXPORT:-0}" == "1" ]]; then
    return 1
  fi
  local settings_file
  settings_file="$(claude_matrix_settings_path)"
  [[ -f "$settings_file" ]] || return 1
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  if ! claude_matrix_auth_has_api_key_env "$settings_file"; then
    return 1
  fi
  if claude_matrix_auth_has_conflict; then
    return 1
  fi
  return 0
}

claude_matrix_shell_has_auth_env() {
  [[ -n "${ANTHROPIC_API_KEY:-}" || -n "${ANTHROPIC_AUTH_TOKEN:-}" || -n "${ANTHROPIC_BASE_URL:-}" ]]
}

claude_matrix_auth_env_lines() {
  local settings_file key
  settings_file="$(claude_matrix_settings_path)"
  if claude_matrix_should_export_settings_env; then
    jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "$settings_file"
    return 0
  fi
  # When settings export is skipped, still pass through caller shell gateway env
  # (terminal operators often export ANTHROPIC_* without duplicating settings.json).
  for key in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL; do
    if [[ -n "${!key:-}" ]]; then
      printf '%s=%s\n' "$key" "${!key}"
    fi
  done
}

claude_matrix_export_settings_env() {
  local line
  if ! claude_matrix_should_export_settings_env; then
    return 0
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    # shellcheck disable=SC2163
    export "$line"
  done < <(claude_matrix_auth_env_lines)
}
