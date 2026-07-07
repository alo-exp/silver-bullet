# shellcheck shell=bash
# RTK install/wiring gate — CLI, version, and host PreToolUse hook helpers.
# Enforcement active only when recommended_tools.rtk.enabled_by_user is true.
# Sourced by: rtk-gate.sh, enable-rtk-context-mode.sh, sb-diagnostics.sh

_sb_rtk_default_min_version="0.42.0"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_rtk_required() {
  sb_recommended_tool_enforced "${1:-}" "rtk"
}

sb_rtk_min_version() {
  local config_file="${1:-}"
  local min="${_sb_rtk_default_min_version}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    min="$(jq -r --arg def "$_sb_rtk_default_min_version" \
      '.recommended_tools.rtk.min_version // $def' "$config_file" 2>/dev/null || echo "$_sb_rtk_default_min_version")"
  fi
  printf '%s' "$min"
}

sb_rtk_cli_path() {
  if command -v rtk >/dev/null 2>&1; then
    command -v rtk
    return 0
  fi
  if [[ -x "${HOME}/.local/bin/rtk" ]]; then
    printf '%s' "${HOME}/.local/bin/rtk"
    return 0
  fi
  return 1
}

sb_rtk_is_wrong_binary() {
  local rtk_bin="${1:-}"
  [[ -n "$rtk_bin" ]] || return 1
  if ! "$rtk_bin" gain --help >/dev/null 2>&1; then
    return 0
  fi
  if "$rtk_bin" --help 2>&1 | head -5 | grep -qiE 'rust type kit|rtk-check'; then
    return 0
  fi
  return 1
}

sb_rtk_cli_available() {
  local rtk_bin
  rtk_bin="$(sb_rtk_cli_path 2>/dev/null || true)"
  [[ -n "$rtk_bin" ]] || return 1
  ! sb_rtk_is_wrong_binary "$rtk_bin"
}

sb_rtk_version_string() {
  local rtk_bin
  rtk_bin="$(sb_rtk_cli_path 2>/dev/null || true)"
  [[ -n "$rtk_bin" ]] || return 1
  "$rtk_bin" --version 2>&1 | head -1
}

sb_rtk_version_ok() {
  local config_file="${1:-}"
  local ver_line major minor patch min_major min_minor min_patch
  ver_line="$(sb_rtk_version_string 2>/dev/null || true)"
  [[ -n "$ver_line" ]] || return 1
  if printf '%s' "$ver_line" | grep -qE '0\.4[0-9]'; then
    return 0
  fi
  local min_ver
  min_ver="$(sb_rtk_min_version "$config_file")"
  major="$(printf '%s' "$ver_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)"
  minor="$(printf '%s' "$ver_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)"
  patch="$(printf '%s' "$ver_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f3)"
  min_major="$(printf '%s' "$min_ver" | cut -d. -f1)"
  min_minor="$(printf '%s' "$min_ver" | cut -d. -f2)"
  min_patch="$(printf '%s' "$min_ver" | cut -d. -f3)"
  [[ -n "$major" && -n "$minor" && -n "$patch" ]] || return 1
  if [[ "$major" -gt "$min_major" ]]; then return 0; fi
  if [[ "$major" -lt "$min_major" ]]; then return 1; fi
  if [[ "$minor" -gt "$min_minor" ]]; then return 0; fi
  if [[ "$minor" -lt "$min_minor" ]]; then return 1; fi
  [[ "$patch" -ge "$min_patch" ]]
}

sb_rtk_platform_hook_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_RTK_HOOK_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_RTK_HOOK_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/hooks.json' "${HOME}" ;;
    codex) printf '%s/.codex/AGENTS.md' "${CODEX_HOME:-${HOME}/.codex}" ;;
    *) printf '%s/.codex/settings.json' "${HOME}" ;;
  esac
}

sb_rtk_platform_hook_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_rtk_platform_hook_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  case "$host" in
    cursor)
      grep -qE 'rtk hook cursor|"rtk"' "$artifact" 2>/dev/null
      ;;
    codex)
      grep -qiE 'rtk|rust token killer' "$artifact" 2>/dev/null
      ;;
    *)
      grep -q 'rtk' "$artifact" 2>/dev/null
      ;;
  esac
}

sb_rtk_edit_path_is_exempt() {
  local file_path="${1:-}"
  local config_file="${2:-}"
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    */.silver-bullet.json|*/SETUP_REPORT.md|*/silver-bullet.md|*/CLAUDE.md|*/AGENTS.md)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/.cursor/hooks.json" ]] || [[ "$file_path" == *"/.codex/settings.json" ]]; then
    return 0
  fi
  return 1
}

sb_rtk_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])rtk([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE 'enable-rtk-context-mode|rtk init'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(brew|curl|npm install|which|command -v|grep|cat|jq|echo|printf|true|false)(\s|$)'; then
    return 0
  fi
  return 1
}

sb_rtk_block_message_no_cli() {
  local config_file="${1:-}"
  local host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" rtk "$host" 2>/dev/null || true)"
  cat <<EOF
🚫 RTK REQUIRED — CLI not installed or wrong binary (user opted in).

Silver Bullet mandates rtk-ai/rtk for shell output compression. Install before substantive work (host: ${host}):

${install_lines}

Verify: rtk --version (v0.4x) and rtk gain --help (must succeed — wrong "Rust Type Kit" binary is rejected).

To disable enforcement, set recommended_tools.rtk.enabled_by_user to false in .silver-bullet.json.
See docs/RTK.md.
EOF
}

sb_rtk_block_message_wrong_binary() {
  cat <<EOF
🚫 RTK WRONG BINARY — reachingforthejack/rtk (Rust Type Kit) detected on PATH.

Remove the wrong binary and install rtk-ai/rtk:
  brew uninstall rtk 2>/dev/null; brew tap rtk-ai/rtk && brew install rtk

Verify: rtk gain --help must print token-savings help.
See docs/RTK.md.
EOF
}

sb_rtk_block_message_no_hook() {
  local config_file="${1:-}"
  local host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_rtk_platform_hook_artifact_path "$(dirname "$config_file")" "$host")"
  cat <<EOF
🚫 RTK HOOK NOT WIRED — host PreToolUse integration missing.

Expected RTK hook reference for host ${host} in:
  ${artifact}

Run from project root (host: ${host}):
$(sb_recommended_tool_platform_pre_index_commands "$config_file" rtk "$host" 2>/dev/null || true)

See docs/RTK.md.
EOF
}

sb_rtk_prompt_reminder_line() {
  local config_file="${1:-}"
  local project_root host
  project_root="$(dirname "$config_file")"
  host="$(sb_runtime_host)"

  case "$(sb_recommended_tool_consent "$config_file" "rtk")" in
    pending)
      printf '%s' "RTK: consent pending — ask user to opt in or out (see session-start context)."
      ;;
    disabled)
      printf '%s' "RTK: opted out — enforcements disabled."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "rtk"; then
        printf '%s' "RTK: opted in but install failed — enforcement suspended until upgrade; retry on /silver:update."
      elif ! sb_rtk_cli_available; then
        printf '%s' "RTK: CLI missing or wrong binary — install rtk-ai/rtk; hooks block substantive work until wired."
      elif ! sb_rtk_version_ok "$config_file"; then
        printf '%s' "RTK: version too old — upgrade to v0.42+; hooks block until satisfied."
      elif ! sb_rtk_platform_hook_present "$project_root" "$host"; then
        printf '%s' "RTK: host hook not wired — run rtk init for ${host}; hooks block until present."
      else
        printf '%s' "RTK: installed and wired — shell compression is automatic via upstream PreToolUse hook."
      fi
      ;;
  esac
}
