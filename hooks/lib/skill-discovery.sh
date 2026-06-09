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
#   2. User skill roots under the active host runtime and ~/.agents/
#   3. Plugin caches for upstream dependency plugins
#
# Tests may override the search roots with SILVER_BULLET_SKILL_ROOTS as a
# colon-separated list of root directories to search instead of the defaults.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi

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
      # Host-specific runtime root.
      "${SB_RUNTIME_HOME_ROOT}"
      "$HOME/.agents"
    )
  fi

  local root candidate
  for root in "${search_roots[@]}"; do
    [[ -n "$root" ]] || continue
    case "$root" in
      *"/plugins/cache")
        shopt -s nullglob
        for candidate in \
          "$root"/*/skills/"$skill"/SKILL.md \
          "$root"/*/*/skills/"$skill"/SKILL.md; do
          if [[ -f "$candidate" ]]; then
            shopt -u nullglob
            return 0
          fi
        done
        shopt -u nullglob
        ;;
      *)
        for candidate in \
          "$root/skills/$skill/SKILL.md" \
          "$root/$skill/SKILL.md"; do
          if [[ -f "$candidate" ]]; then
            return 0
          fi
        done

        local search_dirs=()
        [[ -d "$root/skills" ]] && search_dirs+=("$root/skills")
        if [[ ${#search_dirs[@]} -gt 0 ]]; then
          local escaped_skill
          escaped_skill=$(printf '%s' "$skill" | sed 's/[][(){}.^$*+?|\\]/\\&/g')
          if command -v rg >/dev/null 2>&1; then
            if rg -l -m1 -g 'SKILL.md' "^name:[[:space:]]*${escaped_skill}[[:space:]]*$" "${search_dirs[@]}" >/dev/null 2>&1; then
              return 0
            fi
          else
            if grep -Rls -E "^name:[[:space:]]*${escaped_skill}[[:space:]]*$" "${search_dirs[@]}" >/dev/null 2>&1; then
              return 0
            fi
          fi
        fi
        ;;
    esac
  done

  return 1
}

sb_skill_canonical_name() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 1

  if [[ "$skill" == gsd:* ]]; then
    printf 'gsd-%s' "${skill#gsd:}"
    return 0
  fi

  # Silver Bullet uses `silver:<route>` as a single skill family, and the
  # compliance state uses hyphenated markers (`silver-init`, `silver-feature`,
  # etc.). Do not strip the `silver:` prefix.
  if [[ "$skill" == silver:* ]]; then
    case "${skill#silver:}" in
      security) printf 'security' ;;
      tdd) printf 'tdd' ;;
      verify-tests) printf 'verify-tests' ;;
      devops-quality-gates) printf 'devops-quality-gates' ;;
      devops-skill-router) printf 'devops-skill-router' ;;
      request-review) printf 'requesting-code-review' ;;
      receive-review) printf 'receiving-code-review' ;;
      *) printf 'silver-%s' "${skill#silver:}" ;;
    esac
    return 0
  fi

  while [[ "$skill" == *:* ]]; do
    skill="${skill#*:}"
  done

  printf '%s' "$skill"
}
