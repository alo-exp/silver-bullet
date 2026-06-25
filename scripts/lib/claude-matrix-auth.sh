#!/usr/bin/env bash
# Matrix-only Claude auth helpers: strip ~/.claude/settings.json API-key env
# entries that conflict with claude.ai OAuth during interactive E2E runs.
# Shell unset / env -i alone is insufficient — Claude reads keys from settings.

_claude_matrix_auth_backup=""
_claude_matrix_auth_prepared=0

claude_matrix_settings_path() {
  printf '%s/.claude/settings.json\n' "${HOME}"
}

claude_matrix_auth_has_api_key_env() {
  local settings_file="$1"
  [[ -f "$settings_file" ]] || return 1
  jq -e '
    (.env.ANTHROPIC_API_KEY? // "") != ""
    or (.env.ANTHROPIC_BASE_URL? // "") != ""
  ' "$settings_file" >/dev/null 2>&1
}

claude_matrix_auth_has_conflict() {
  local cli status
  cli="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo claude)}"
  status="$("$cli" auth status 2>/dev/null || true)"
  printf '%s' "$status" | jq -e '
    (.authMethod == "claude.ai")
    and ((.apiKeySource? // "") == "ANTHROPIC_API_KEY")
  ' >/dev/null 2>&1
}

claude_matrix_auth_prepare() {
  local settings_file backup_file
  settings_file="$(claude_matrix_settings_path)"
  if ! claude_matrix_auth_has_conflict; then
    return 0
  fi
  if ! claude_matrix_auth_has_api_key_env "$settings_file"; then
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'WARN: jq required to strip Claude settings API keys for matrix auth\n' >&2
    return 0
  fi

  backup_file="$(mktemp "${TMPDIR:-/tmp}/claude-matrix-settings.XXXXXX")"
  cp "$settings_file" "$backup_file"
  _claude_matrix_auth_backup="$backup_file"

  jq '
    if .env then
      .env |= del(
        .ANTHROPIC_API_KEY,
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
  ' "$settings_file" > "${settings_file}.matrix-auth.tmp"
  mv "${settings_file}.matrix-auth.tmp" "$settings_file"
  _claude_matrix_auth_prepared=1
}

claude_matrix_auth_restore() {
  local settings_file
  settings_file="$(claude_matrix_settings_path)"
  if [[ "$_claude_matrix_auth_prepared" == "1" && -n "$_claude_matrix_auth_backup" && -f "$_claude_matrix_auth_backup" ]]; then
    cp "$_claude_matrix_auth_backup" "$settings_file"
    rm -f "$_claude_matrix_auth_backup"
  fi
  _claude_matrix_auth_backup=""
  _claude_matrix_auth_prepared=0
}
