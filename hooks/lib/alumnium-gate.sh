# shellcheck shell=bash
# Alumnium MCP install/wiring gate — browser/visual testing companion.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn Alumnium off. The gate covers browser/visual
# work only: edits to browser-test files and shell commands that run browser tooling.
# Sourced by: alumnium-gate.sh, prompt-reminder.sh, sb-diagnostics.sh

_sb_alumnium_default_mcp_name="alumnium"
_sb_alumnium_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_alumnium_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_alumnium_lib_dir}/opt-in-gate.sh"

sb_alumnium_required() {
  sb_recommended_tool_enforced "${1:-}" "alumnium"
}

# MCP server name; a config value is matched as a fixed string, and only plain names count.
sb_alumnium_mcp_server_name() {
  local config_file="${1:-}" name=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    name="$(jq -r '.recommended_tools.alumnium.mcp_server_name // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || name="$_sb_alumnium_default_mcp_name"
  printf '%s' "$name"
}

# npx is what runs the Alumnium MCP server. No registry query: it made every gated call
# wait on the network and failed closed offline.
sb_alumnium_npx_available() {
  command -v npx >/dev/null 2>&1
}

sb_alumnium_platform_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_ALUMNIUM_MCP_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_ALUMNIUM_MCP_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    codex) printf '%s/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    *) printf '%s/.claude.json' "${HOME}" ;;
  esac
}

sb_alumnium_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact mcp_name
  host="${host:-$(sb_runtime_host)}"
  mcp_name="$(sb_alumnium_mcp_server_name "${project_root%/}/.silver-bullet.json")"
  artifact="$(sb_alumnium_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -qiF -e alumnium -e "$mcp_name" "$artifact" 2>/dev/null
}

sb_alumnium_edit_path_is_exempt() {
  local normalized
  [[ -n "${1:-}" ]] || return 1
  normalized="$(sb_opt_in_normalize_path "$1" "$(dirname "${2:-$PWD/x}")")"
  case "$normalized" in
    */.silver-bullet.json | */SETUP_REPORT.md | */silver-bullet.md | */CLAUDE.md | */AGENTS.md \
      | */.silver-bullet/* | */.cursor/mcp.json | */.claude.json)
      return 0
      ;;
  esac
  return 1
}

# True when the edit targets browser/visual testing artifacts (Alumnium scope). Generic unit
# tests named *.spec.ts are not browser tests; e2e/playwright/cypress locations are.
sb_alumnium_edit_path_requires_browser() {
  local file_path="${1:-}"
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    *.canvas.tsx | */e2e/* | */playwright/* | */cypress/* | */__screenshots__/* | */screenshots/* \
      | */visual-regression/* | *.e2e.[jt]s | *.e2e.[jt]sx | *.cy.[jt]s | *.cy.[jt]sx)
      return 0
      ;;
  esac
  grep -qiE '(screenshot|playwright|cypress|puppeteer|browser-test|visual-regression)' <<<"${file_path##*/}"
}

# Status 0 when a shell command does browser/visual work: it is not read-only and runs
# browser tooling, or writes a browser-test file. Commits and ordinary writes are out of scope.
sb_alumnium_command_requires_browser() {
  local cmd="${1:-}" target
  [[ -n "$cmd" ]] || return 1
  sb_opt_in_tool_command alumnium "$cmd" && return 1
  if declare -f sb_shell_command_looks_read_only >/dev/null 2>&1 \
    && sb_shell_command_looks_read_only "$cmd" >/dev/null 2>&1; then
    return 1
  fi
  if grep -qiE '(^|[^A-Za-z0-9_-])(playwright|cypress|puppeteer|wdio|webdriverio)([^A-Za-z0-9_-]|$)' <<<"$cmd"; then
    return 0
  fi
  while IFS= read -r target; do
    [[ -n "$target" ]] && sb_alumnium_edit_path_requires_browser "$target" && return 0
  done < <(sb_shell_candidate_write_paths "$cmd" "$PWD" 2>/dev/null || true)
  return 1
}

sb_alumnium_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate alumnium "${1:-}"
}

sb_alumnium_block_message_no_npx() {
  cat <<EOF
🚫 ALUMNIUM REQUIRED — npx is not on PATH (you opted in to Alumnium for browser/visual work).

The Alumnium MCP server runs through npx. Install Node.js (which provides npx), then wire the server (see docs/ALUMNIUM.md).
EOF
}

sb_alumnium_block_message_no_mcp() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" alumnium "$host")"
  cat <<EOF
🚫 ALUMNIUM REQUIRED — MCP server not wired (you opted in to Alumnium for browser/visual work).

Silver Bullet uses [Alumnium](https://alumnium.ai/) for browser/visual testing when opted in (host: ${host}):

${install_lines}

Provider API key required (e.g. OPENAI_API_KEY or ANTHROPIC_API_KEY in MCP env).

If the user asks to turn Alumnium enforcement off: bash $(sb_rt_plugin_script scripts/sb-consent.sh) decline alumnium --project $(printf '%q' "$(dirname "${config_file:-$PWD/x}")")
See docs/ALUMNIUM.md and silver-bullet.md §8.1.
EOF
}

sb_alumnium_prompt_reminder_line() {
  local config_file="${1:-}"
  case "$(sb_recommended_tool_consent "$config_file" "alumnium")" in
    pending)
      printf '%s' "Alumnium: consent pending — ask user to opt in or out (browser/visual MCP; see docs/ALUMNIUM.md)."
      ;;
    disabled)
      printf '%s' "Alumnium: opted out — use host browser MCP fallback for UI evidence (§8.1)."
      ;;
    *)
      if sb_alumnium_platform_artifact_present "$(dirname "$config_file")"; then
        printf '%s' "Alumnium: MCP wired — prefer do/check/get/wait for UI clarify, ui-review, and verify."
      else
        printf '%s' "Alumnium: opted in but MCP not wired — run platform install per docs/ALUMNIUM.md."
      fi
      ;;
  esac
}
