# shellcheck shell=bash
# RTK install/wiring gate — CLI, version, and host PreToolUse hook helpers.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn RTK off.
# Sourced by: rtk-gate.sh, enable-rtk-context-mode.sh, sb-diagnostics.sh

_sb_rtk_default_min_version="0.42.0"
_sb_rtk_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_rtk_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_rtk_lib_dir}/opt-in-gate.sh"

sb_rtk_required() {
  sb_recommended_tool_enforced "${1:-}" "rtk"
}

# Minimum rtk version. The config value is repository data: anything but a plain dotted
# version (e.g. HOME[$(cmd)], which [[ -gt ]] would execute) falls back to the default.
sb_rtk_min_version() {
  local config_file="${1:-}" min=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    min="$(jq -r '.recommended_tools.rtk.min_version // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_version_valid "$min" || min="$_sb_rtk_default_min_version"
  printf '%s' "$min"
}

sb_rtk_cli_path() {
  sb_global_tool_path rtk 2>/dev/null && return 0
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
  if grep -qiE 'rust type kit|rtk-check' < <("$rtk_bin" --help 2>&1 | head -5); then
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

# Status 0 when the installed rtk is at least the minimum version (default 0.42.0).
sb_rtk_version_ok() {
  local config_file="${1:-}" have
  have="$(sb_rt_version_extract "$(sb_rtk_version_string 2>/dev/null || true)" || true)"
  [[ -n "$have" ]] || return 1
  sb_rt_version_ge "$have" "$(sb_rtk_min_version "$config_file")"
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
    codex) printf '%s/AGENTS.md' "${CODEX_HOME:-${HOME}/.codex}" ;;
    opencode) printf '%s/.config/opencode/plugins/rtk.ts' "${HOME}" ;;
    pi) printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
      "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
    # rtk init -g wires Claude hooks into ${HOME}/.claude/settings.json.
    *) printf '%s/.claude/settings.json' "${HOME}" ;;
  esac
}

sb_rtk_platform_hook_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_rtk_platform_hook_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  case "$host" in
    cursor) grep -qE 'rtk hook cursor|"rtk"' "$artifact" 2>/dev/null ;;
    codex) grep -qiE 'rtk|rust token killer' "$artifact" 2>/dev/null ;;
    *) grep -q 'rtk' "$artifact" 2>/dev/null ;;
  esac
}

# Status 0 when an edit target is SB configuration or RTK's own host wiring (normalized
# first, so a '..' never smuggles a source file in under an exempt name).
sb_rtk_edit_path_is_exempt() {
  local normalized
  [[ -n "${1:-}" ]] || return 1
  normalized="$(sb_opt_in_normalize_path "$1" "$(dirname "${2:-$PWD/x}")")"
  case "$normalized" in
    */.silver-bullet.json | */SETUP_REPORT.md | */silver-bullet.md | */CLAUDE.md | */AGENTS.md \
      | */.silver-bullet/* | */.cursor/hooks.json | */.claude/settings.json)
      return 0
      ;;
  esac
  return 1
}

sb_rtk_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate rtk "${1:-}"
}

sb_rtk_block_message_no_cli() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" rtk "$host")"
  cat <<EOF
🚫 RTK REQUIRED — CLI not installed (you opted in to RTK enforcement).

Silver Bullet mandates rtk-ai/rtk for shell output compression. Install before substantive work (host: ${host}):

${install_lines}

Verify: rtk --version (>= $(sb_rtk_min_version "$config_file")) and rtk gain --help (must succeed — wrong "Rust Type Kit" binary is rejected).

If the user asks to turn RTK enforcement off: bash $(sb_rt_plugin_script scripts/sb-consent.sh) decline rtk --project $(printf '%q' "$(dirname "${config_file:-$PWD/x}")")
See docs/RTK.md.
EOF
}

sb_rtk_block_message_old_version() {
  local config_file="${1:-}" have
  have="$(sb_rt_version_extract "$(sb_rtk_version_string 2>/dev/null || true)" || true)"
  cat <<EOF
🚫 RTK TOO OLD — installed ${have:-unknown}, need >= $(sb_rtk_min_version "$config_file").

Upgrade rtk-ai/rtk (brew upgrade rtk, or re-run the installer), then retry. See docs/RTK.md.
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
  local config_file="${1:-}" host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_rtk_platform_hook_artifact_path "$(dirname "${config_file:-$PWD/x}")" "$host")"
  cat <<EOF
🚫 RTK HOOK NOT WIRED — host PreToolUse integration missing.

Expected RTK hook reference for host ${host} in:
  ${artifact}

Run from project root (host: ${host}):
$(sb_recommended_tool_platform_pre_index_commands "" rtk "$host")

See docs/RTK.md.
EOF
}

sb_rtk_prompt_reminder_line() {
  local config_file="${1:-}" project_root host
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
        printf '%s' "RTK: opted in but install failed — enforcement suspended until upgrade; retry on /sb:update."
      elif ! sb_rtk_cli_available; then
        printf '%s' "RTK: CLI missing or wrong binary — install rtk-ai/rtk; hooks block substantive work until wired."
      elif ! sb_rtk_version_ok "$config_file"; then
        printf '%s' "RTK: version too old — upgrade to >= $(sb_rtk_min_version "$config_file"); hooks block until satisfied."
      elif ! sb_rtk_platform_hook_present "$project_root" "$host"; then
        printf '%s' "RTK: host hook not wired — run rtk init for ${host}; hooks block until present."
      else
        printf '%s' "RTK: installed and wired — shell compression is automatic via upstream PreToolUse hook."
      fi
      ;;
  esac
}
