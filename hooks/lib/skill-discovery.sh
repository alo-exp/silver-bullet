# shellcheck shell=bash
# Silver Bullet — installed skill discovery helper.
#
# Sourced by enforcement hooks to distinguish between:
#   - skills that are missing from the session state but are installed and
#     therefore should still block, and
#   - skills that are not installed anywhere invocable, which should warn
#     and allow so users do not get stuck behind an impossible gate.
#
# The default search order is intentionally broad but cheap:
#   1. Installed Silver Bullet plugin skills (repo/plugin root or CLAUDE_PLUGIN_ROOT)
#   2. User skill roots under ~/.claude/ and ~/.agents/
#   3. Claude plugin caches for upstream dependency plugins
#
# Tests may override the search roots with SILVER_BULLET_SKILL_ROOTS as a
# colon-separated list of root directories to search instead of the defaults.

sb_skill_discovery_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sb_skill_discovery_repo_root="$(cd "$sb_skill_discovery_script_dir/../.." && pwd)"

sb_skill_is_installed() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 1

  local repo_root="${CLAUDE_PLUGIN_ROOT:-$sb_skill_discovery_repo_root}"
  if [[ ! -d "$repo_root/skills" ]]; then
    repo_root="$sb_skill_discovery_repo_root"
  fi

  local search_roots=()
  if [[ -n "${SILVER_BULLET_SKILL_ROOTS:-}" ]]; then
    local IFS=':'
    read -r -a search_roots <<< "${SILVER_BULLET_SKILL_ROOTS}"
  else
    search_roots=(
      "$repo_root"
      "$HOME/.claude"
      "$HOME/.agents"
      "$HOME/.claude/plugins/cache"
    )
  fi

  local root candidate
  for root in "${search_roots[@]}"; do
    [[ -n "$root" ]] || continue
    case "$root" in
      *"/plugins/cache")
        shopt -s nullglob
        for candidate in "$root"/*/skills/"$skill"/SKILL.md "$root"/*/*/skills/"$skill"/SKILL.md; do
          if [[ -f "$candidate" ]]; then
            shopt -u nullglob
            return 0
          fi
        done
        shopt -u nullglob
        ;;
      *)
        if [[ -f "$root/skills/$skill/SKILL.md" ]]; then
          return 0
        fi
        if [[ -f "$root/$skill/SKILL.md" ]]; then
          return 0
        fi
        ;;
    esac
  done

  return 1
}
