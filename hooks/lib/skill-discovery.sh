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
#   1. Installed Silver Bullet plugin skills (repo/plugin root or SB_PLUGIN_ROOT)
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

# Emit unique skill-name variants for path/frontmatter probes (hyphen⇄colon).
# Always includes the original name. One variant per line on stdout. Public
# host routes are sb:*; silver-* is retained only as the internal source/state
# spelling used by the hooks.
# Example: sb:quality-gates ↔ sb-quality-gates ↔ silver-quality-gates
sb_skill_name_variants() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 1

  local variants=()
  local variant existing
  add_variant() {
    variant="$1"
    [[ -n "$variant" ]] || return
    if [[ ${#variants[@]} -gt 0 ]]; then
      for existing in "${variants[@]}"; do
        [[ "$existing" == "$variant" ]] && return
      done
    fi
    variants+=("$variant")
  }

  add_variant "$skill"

  if [[ "$skill" == *:* ]]; then
    case "$skill" in
      sb:*)
        add_variant "${skill//:/-}"
        add_variant "silver-${skill#sb:}"
        ;;
      *)
        add_variant "${skill//:/-}"
        ;;
    esac
  fi

  # First hyphen → colon so sb-quality-gates also probes sb:quality-gates.
  if [[ "$skill" == *-* && "$skill" != *:* ]]; then
    case "$skill" in
      sb-*)
        add_variant "sb:${skill#sb-}"
        add_variant "silver-${skill#sb-}"
        ;;
      silver-*)
        add_variant "sb:${skill#silver-}"
        add_variant "sb-${skill#silver-}"
        ;;
      *)
        add_variant "${skill%%-*}:${skill#*-}"
        ;;
    esac
  fi

  for variant in "${variants[@]}"; do
    printf '%s\n' "$variant"
  done
}

sb_skill_is_installed() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 1

  # The public namespace is sb:*; do not resolve the retired silver: form.
  case "$skill" in
    silver|silver:*) return 1 ;;
  esac

  if declare -F sb_required_skill_is_virtual_marker >/dev/null 2>&1; then
    if sb_required_skill_is_virtual_marker "$skill"; then
      return 0
    fi
  else
    case "$skill" in
      silver-bootstrap-project|silver-bootstrap-milestone|silver-orient|silver-context|silver-plan|silver-execute|silver-verify|silver-ship|silver-review|silver-secure|silver-ui-contract|silver-ui-review|silver-debug|silver-review-request|silver-review-triage|silver-branch-finish|silver-completion-audit|silver-tdd)
        return 0
        ;;
    esac
  fi

  local repo_root="${SB_PLUGIN_ROOT:-$sb_skill_discovery_repo_root}"
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
      "${SB_RUNTIME_PLUGIN_CACHE_ROOT:-${SB_RUNTIME_HOME_ROOT}/plugins/cache}"
      "$HOME/.agents"
    )
  fi

  local variants=()
  local variant
  while IFS= read -r variant; do
    [[ -n "$variant" ]] || continue
    variants+=("$variant")
  done < <(sb_skill_name_variants "$skill")

  local root candidate escaped_skill
  for variant in "${variants[@]}"; do
    for root in "${search_roots[@]}"; do
      [[ -n "$root" ]] || continue
      case "$root" in
        *"/plugins/cache")
          shopt -s nullglob
          for candidate in \
            "$root"/*/skills/"$variant"/SKILL.md \
            "$root"/*/*/skills/"$variant"/SKILL.md \
            "$root"/*/*/*/skills/"$variant"/SKILL.md \
            "$root"/*/upstream/skills/"$variant"/SKILL.md \
            "$root"/*/*/upstream/skills/"$variant"/SKILL.md \
            "$root"/*/*/*/upstream/skills/"$variant"/SKILL.md; do
            if [[ -f "$candidate" ]]; then
              shopt -u nullglob
              return 0
            fi
          done
          shopt -u nullglob
          ;;
        *)
          for candidate in \
            "$root/skills/$variant/SKILL.md" \
            "$root/$variant/SKILL.md"; do
            if [[ -f "$candidate" ]]; then
              return 0
            fi
          done

          local search_dirs=()
          [[ -d "$root/skills" ]] && search_dirs+=("$root/skills")
          if [[ ${#search_dirs[@]} -gt 0 ]]; then
            escaped_skill=$(printf '%s' "$variant" | sed 's/[][(){}.^$*+?|\\]/\\&/g')
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
  done

  return 1
}

sb_skill_canonical_name() {
  local skill="${1:-}"
  [[ -n "$skill" ]] || return 1

  # Public host routes use `sb:<route>`; compliance state and the canonical
  # authoring tree retain silver-* markers internally.
  if [[ "$skill" == sb:* ]]; then
    local route="${skill#*:}"
    case "$route" in
      security) printf 'security' ;;
      tdd) printf 'tdd' ;;
      verify-tests) printf 'verify-tests' ;;
      devops-quality-gates) printf 'devops-quality-gates' ;;
      devops-skill-router) printf 'devops-skill-router' ;;
      request-review) printf 'silver-review-request' ;;
      receive-review) printf 'silver-review-triage' ;;
      *) printf 'silver-%s' "$route" ;;
    esac
    return 0
  fi

  if [[ "$skill" == "sb" ]]; then
    printf 'silver'
    return 0
  fi

  if [[ "$skill" == sb-* ]]; then
    printf 'silver-%s' "${skill#sb-}"
    return 0
  fi

  # Preserve the retired Silver Bullet namespace instead of silently treating
  # it as an unnamespaced route. Other host namespaces may still be unwrapped.
  local namespace="${skill%%:*}"
  if [[ "$skill" == *:* && "$namespace" == "silver" ]]; then
    printf '%s' "$skill"
    return 0
  fi
  while [[ "$skill" == *:* ]]; do
    skill="${skill#*:}"
  done

  printf '%s' "$skill"
}
