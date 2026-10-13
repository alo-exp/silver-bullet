# shellcheck shell=bash
# Post-release SB-only uninstall per host — preserves non-SB hooks (rtk, context-mode, etc.).

if [[ -n "${_SB_POST_RELEASE_UNINSTALL_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SB_POST_RELEASE_UNINSTALL_LOADED=1

_sb_post_release_strip_cursor_hooks() {
  local hooks_file="${1:-${HOME}/.cursor/hooks.json}"
  local strip_py="${SB_POST_RELEASE_REPO_ROOT:?}/scripts/lib/strip-cursor-sb-hooks.py"
  [[ -f "$strip_py" ]] || { printf 'ERROR: missing %s\n' "$strip_py" >&2; return 1; }
  python3 "$strip_py" "$hooks_file"
}

_sb_post_release_rm_dir() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  rm -rf "$path" 2>/dev/null || true
}

sb_post_release_uninstall_cursor() {
  local cursor_home="${CURSOR_HOME:-${HOME}/.cursor}"
  local sb_state_dir="${cursor_home}/.silver-bullet"
  _sb_post_release_rm_dir "${cursor_home}/plugins/cache/alo-labs/silver-bullet"
  _sb_post_release_rm_dir "${cursor_home}/plugins/cache/alo-labs-agent-plugins/silver-bullet"
  _sb_post_release_rm_dir "${cursor_home}/plugins/cache/alo-labs-cursor/silver-bullet"
  _sb_post_release_strip_cursor_hooks "${cursor_home}/hooks.json"
  rm -f -- \
    "${sb_state_dir}/site-session.json" \
    "${sb_state_dir}/site-visual-evidence.json" \
    "${sb_state_dir}/site-vloops.json" \
    "${sb_state_dir}/agent-delegation-active.json" \
    "${sb_state_dir}/subagent-spawns.jsonl" \
    "${sb_state_dir}/live-publish-evidence.json" \
    "${sb_state_dir}/pending-completion-audit.json" 2>/dev/null || true
  printf 'uninstall: cursor SB cache + hooks stripped\n'
}

sb_post_release_uninstall_codex() {
  local codex_home="${CODEX_HOME_ROOT:-${HOME}}"
  local lib="${SB_POST_RELEASE_REPO_ROOT}/scripts/lib/install-codex"
  export CODEX_HOME_ROOT="$codex_home"
  # shellcheck source=scripts/lib/install-codex/legacy.sh
  source "${lib}/legacy.sh"
  purge_legacy_silver_bullet_standalone_skills
  purge_legacy_silver_bullet_hooks_from_user_config
  _sb_post_release_rm_dir "${codex_home}/.codex/plugins/cache/alo-labs-codex/silver-bullet"
  _sb_post_release_rm_dir "${codex_home}/.codex/plugins/cache/silver-bullet-local/silver-bullet"
  if command -v codex >/dev/null 2>&1; then
    codex plugin remove silver-bullet@alo-labs-codex >/dev/null 2>&1 || \
      codex plugin uninstall silver-bullet@alo-labs-codex >/dev/null 2>&1 || true
  fi
  printf 'uninstall: codex SB cache, skills, hooks stripped\n'
}

sb_post_release_uninstall_claude() {
  local claude_home="${CLAUDE_HOME:-${HOME}/.claude}"
  local claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
  local plugin_id scope
  for plugin_id in "silver-bullet@alo-labs" "silver-bullet@alo-labs-claude"; do
    if [[ -n "$claude_bin" && -x "$claude_bin" ]]; then
      for scope in user project local; do
        "$claude_bin" plugin uninstall "$plugin_id" --scope "$scope" >/dev/null 2>&1 || true
      done
    fi
    _sb_post_release_rm_dir "${claude_home}/plugins/cache/${plugin_id#*@}/${plugin_id%@*}"
  done
  _sb_post_release_rm_dir "${claude_home}/plugins/cache/alo-labs/silver-bullet"
  printf 'uninstall: claude SB plugin + cache removed\n'
}

sb_post_release_uninstall_host() {
  case "$1" in
    cursor) sb_post_release_uninstall_cursor ;;
    codex) sb_post_release_uninstall_codex ;;
    claude) sb_post_release_uninstall_claude ;;
    *) printf 'ERROR: unknown host %s\n' "$1" >&2; return 2 ;;
  esac
}

