#!/usr/bin/env bash
# completion-audit: change-class delivery floor (#282)
# Classify the pending change set and subset required_deploy for docs|site|config.
# Full floor remains for src|mixed|release. Interim until work-spec/Validation floors land.

# Collect changed paths relative to merge-base (or working tree when no base).
# Prints one path per line. Fail-soft → empty (caller treats as mixed/full).
ca_collect_changed_paths() {
  local root="${1:-$PWD}"
  local paths="" base=""

  [[ -d "$root/.git" || -d "$(git -C "$root" rev-parse --git-dir 2>/dev/null)" ]] || return 0

  base="$(git -C "$root" merge-base HEAD main 2>/dev/null || true)"
  if [[ -z "$base" ]]; then
    base="$(git -C "$root" merge-base HEAD master 2>/dev/null || true)"
  fi
  if [[ -n "$base" ]]; then
    paths="$(git -C "$root" diff --name-only "$base"...HEAD 2>/dev/null || true)"
  fi
  paths="$(printf '%s\n%s\n%s\n' \
    "$paths" \
    "$(git -C "$root" diff --name-only HEAD 2>/dev/null || true)" \
    "$(git -C "$root" diff --cached --name-only 2>/dev/null || true)" \
    | sed '/^$/d' | sort -u)"
  printf '%s\n' "$paths"
}

# Classify a single path → docs|site|config|src|release|other
ca_classify_path() {
  local path="$1"
  local src_pattern="${2:-/src/}"

  # Release / version / plugin packaging surfaces (host-agnostic: no host plugin literals)
  if printf '%s' "$path" | grep -qE '(^|/)(package\.json|package-lock\.json|plugins/silver-bullet/|scripts/pre-release-gate\.sh|scripts/sync-release|scripts/verify-release)'; then
    printf 'release'
    return 0
  fi
  # Marketplace plugin dirs: .*-plugin/ without host-specific literals
  if printf '%s' "$path" | grep -qE '(^|/)\.[a-z0-9-]+-plugin/'; then
    printf 'release'
    return 0
  fi
  if printf '%s' "$path" | grep -qE '(^|/)CHANGELOG\.md$|(^|/)plugins/.*/CHANGELOG\.md$'; then
    printf 'release'
    return 0
  fi

  # Site
  if printf '%s' "$path" | grep -qE '(^|/)site/'; then
    printf 'site'
    return 0
  fi

  # Config (project + hook wiring; not application src)
  if printf '%s' "$path" | grep -qE '(^|/)\.silver-bullet\.json$|(^|/)hooks\.json$|(^|/)\.[a-z0-9_-]+/hooks\.json$|(^|/)mcp\.json$|(^|/)templates/silver-bullet\.config'; then
    printf 'config'
    return 0
  fi

  # Src via configured pattern / common product roots (before generic .md docs).
  if declare -f dcc_matches_src_scope >/dev/null 2>&1; then
    if dcc_matches_src_scope "$path" "$src_pattern"; then
      printf 'src'
      return 0
    fi
  elif printf '%s' "$path" | grep -qE "$src_pattern"; then
    printf 'src'
    return 0
  fi
  if printf '%s' "$path" | grep -qE '(^|/)(hooks|skills|scripts|tests|agents|host-bundles|templates|plugins)/'; then
    printf 'src'
    return 0
  fi

  # Docs (docs tree + top-level project markdown — not skill/hook markdown)
  if printf '%s' "$path" | grep -qE '(^|/)docs/|(^|/)README\.md$|(^|/)AGENTS\.md$|(^|/)silver-bullet\.md$|(^|/)CHANGELOG\.md$'; then
    printf 'docs'
    return 0
  fi

  printf 'other'
}

# Set global ca_change_class to docs|site|config|src|mixed|release
ca_detect_change_class() {
  local root="${1:-$PWD}"
  local config_file="${2:-}"
  local src_pattern="/src/"
  local paths path kind
  local has_docs=false has_site=false has_config=false has_src=false has_release=false has_other=false

  if [[ -n "$config_file" && -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
    src_pattern="$(jq -r '.project.src_pattern // "/src/"' "$config_file" 2>/dev/null || echo "/src/")"
    if ! printf '%s' "$src_pattern" | grep -qE '^/[a-zA-Z0-9/_.|()-]*/?$'; then
      src_pattern="/src/"
    fi
  fi

  # Release delivery commands always use the full release floor.
  if printf '%s' "${cmd_first_line:-}" | grep -qE '\bgh release create\b'; then
    ca_change_class="release"
    return 0
  fi

  paths="$(ca_collect_changed_paths "$root")"
  if [[ -z "$(printf '%s' "$paths" | sed '/^$/d')" ]]; then
    ca_change_class="mixed"
    return 0
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    kind="$(ca_classify_path "$path" "$src_pattern")"
    case "$kind" in
      docs) has_docs=true ;;
      site) has_site=true ;;
      config) has_config=true ;;
      src) has_src=true ;;
      release) has_release=true ;;
      *) has_other=true ;;
    esac
  done <<< "$paths"

  if [[ "$has_release" == true ]]; then
    ca_change_class="release"
  elif [[ "$has_src" == true && ( "$has_docs" == true || "$has_site" == true || "$has_config" == true || "$has_other" == true ) ]]; then
    ca_change_class="mixed"
  elif [[ "$has_src" == true ]]; then
    ca_change_class="src"
  elif [[ "$has_other" == true ]]; then
    ca_change_class="mixed"
  elif [[ "$has_docs" == true && "$has_site" == false && "$has_config" == false ]]; then
    ca_change_class="docs"
  elif [[ "$has_site" == true && "$has_docs" == false && "$has_config" == false ]]; then
    ca_change_class="site"
  elif [[ "$has_config" == true && "$has_docs" == false && "$has_site" == false ]]; then
    ca_change_class="config"
  elif [[ "$has_docs" == true || "$has_site" == true || "$has_config" == true ]]; then
    # Pure docs/site/config mix — keep light floor; label by dominant docs.
    ca_change_class="docs"
  else
    ca_change_class="mixed"
  fi
}

# Lightweight delivery floor for docs|site|config (subset of full required_deploy).
# Keep planning + completion audit + branch finish; drop TDD/execute/secure/validate floors.
CA_LIGHT_DEPLOY_SKILLS="silver-quality-gates silver-blast-radius devops-quality-gates silver-context silver-plan silver-completion-audit silver-branch-finish finishing-a-development-branch documentation silver-ship"

# Filter space-separated skill list to the light allowlist. Prints filtered list.
ca_subset_skills_for_light_class() {
  local skills="${1:-}"
  local out="" skill allow
  for skill in $skills; do
    for allow in $CA_LIGHT_DEPLOY_SKILLS; do
      if [[ "$skill" == "$allow" ]]; then
        out="${out:+$out }$skill"
        break
      fi
    done
  done
  printf '%s' "$out"
}

# Apply change-class subsetting to required_skills (global).
# Sets ca_change_class and may rewrite required_skills.
ca_apply_change_class_floor() {
  local root="${1:-$PWD}"
  local config_file="${2:-}"
  ca_change_class="mixed"
  ca_detect_change_class "$root" "$config_file"
  case "$ca_change_class" in
    docs|site|config)
      required_skills="$(ca_subset_skills_for_light_class "$required_skills")"
      ;;
    src|mixed|release)
      ;;
    *)
      ca_change_class="mixed"
      ;;
  esac
}

