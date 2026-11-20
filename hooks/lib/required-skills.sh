# shellcheck shell=bash
# Silver Bullet — canonical required-deploy skill list (reader-shim)
#
# Single source of truth: templates/silver-bullet.config.json.default
#   .skills.required_deploy          -> DEFAULT_REQUIRED
#   .skills.required_deploy_devops   -> DEVOPS_DEFAULT_REQUIRED
#   .skills.required_release         -> DEFAULT_RELEASE_REQUIRED
#   .skills.required_release_devops  -> DEVOPS_DEFAULT_RELEASE_REQUIRED
#   .skills.required_planning        -> DEFAULT_PLANNING
#   .skills.required_planning_devops -> DEVOPS_DEFAULT_PLANNING
#
# This file intentionally contains NO hardcoded skill literal. It discovers the
# default config alongside the plugin install and parses it with jq. If jq or
# the config file is missing, it falls back to a minimal safe list so hooks
# never fail-open silently — they enforce at least the quality-gate skills.
#
# Sourced by: stop-check.sh, completion-audit.sh, prompt-reminder.sh,
# compliance-status.sh, dev-cycle-check.sh

__sb_rs_find_default_config() {
  # Candidate locations, in priority order:
  #   1. Env override (used by tests).
  #   2. Adjacent to this lib: ../../templates/silver-bullet.config.json.default
  #      (repo checkout or plugin install layout).
  #   3. Walk up from $PWD looking for .silver-bullet/config.json.default.
  if [ -n "${SB_DEFAULT_CONFIG:-}" ] && [ -f "${SB_DEFAULT_CONFIG}" ]; then
    printf '%s' "${SB_DEFAULT_CONFIG}"
    return 0
  fi
  local self_dir
  # shellcheck disable=SC2128
  self_dir="$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd)"
  local candidate="${self_dir}/../../templates/silver-bullet.config.json.default"
  if [ -f "${candidate}" ]; then
    printf '%s' "${candidate}"
    return 0
  fi
  return 1
}

__sb_rs_default_version() {
  local cfg
  cfg="$(__sb_rs_find_default_config)" || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -r '.config_version // .version // ""' "${cfg}" 2>/dev/null
}

__sb_rs_version_part() {
  local version="$1"
  local index="$2"
  local part
  part=$(printf '%s' "$version" | cut -d. -f"$index" | sed 's/[^0-9].*$//')
  printf '%s' "${part:-0}"
}

__sb_rs_version_lt() {
  local left="$1"
  local right="$2"
  local i l r
  [[ -n "$left" && -n "$right" ]] || return 1
  for i in 1 2 3; do
    l=$(__sb_rs_version_part "$left" "$i")
    r=$(__sb_rs_version_part "$right" "$i")
    if (( l < r )); then
      return 0
    fi
    if (( l > r )); then
      return 1
    fi
  done
  return 1
}

sb_required_skills_config_is_legacy() {
  local config_file="$1"
  local project_version default_version
  command -v jq >/dev/null 2>&1 || return 1
  default_version="$(__sb_rs_default_version 2>/dev/null || true)"
  [[ -n "$default_version" ]] || return 1
  if declare -F sb_iv_jq >/dev/null 2>&1 && [[ -n "${SB_IV_ROOT:-}" ]]; then
    # A gate that verified its project reads the recorded config, not the live file (hooks/lib/integrity.sh).
    project_version=""
    if project_version=$(sb_iv_jq -r '.config_version // .version // ""' 2>/dev/null); then :; fi
  else
    [[ -n "$config_file" && -f "$config_file" ]] || return 1
    project_version=""
    if project_version=$(jq -r '.config_version // .version // ""' "$config_file" 2>/dev/null); then :; fi
  fi
  if [[ -z "$project_version" ]]; then
    return 0
  fi
  __sb_rs_version_lt "$project_version" "$default_version"
}

__SB_RS_RETIRED_NS_COLON=$(printf '%s%s:' gs d)
__SB_RS_RETIRED_NS_HYPHEN=$(printf '%s%s-' gs d)
__SB_RS_RETIRED_REQUIRED_SKILLS="code-review testing-strategy documentation deploy-checklist tech-debt requesting-code-review receiving-code-review finishing-a-development-branch verification-before-completion test-driven-development systematic-debugging writing-plans"

sb_required_skill_aliases() {
  local skill="$1"
  printf '%s\n' "$skill"

  case "$skill" in
    silver-plan) printf '%s\n' writing-plans ;;
    silver-review) printf '%s\n' code-review ;;
    silver-debug) printf '%s\n' systematic-debugging ;;
    silver-review-request) printf '%s\n' requesting-code-review ;;
    silver-review-triage) printf '%s\n' receiving-code-review ;;
    silver-branch-finish) printf '%s\n' finishing-a-development-branch ;;
    silver-completion-audit) printf '%s\n' verification-before-completion ;;
    silver-tdd) printf '%s\n' tdd test-driven-development ;;
  esac
}

sb_required_skill_is_virtual_marker() {
  case "$1" in
    silver-bootstrap-project|silver-bootstrap-milestone|silver-orient|silver-context|silver-plan|silver-execute|silver-verify|silver-ship|silver-review|silver-secure|silver-ui-contract|silver-ui-review|silver-debug|silver-review-request|silver-review-triage|silver-branch-finish|silver-completion-audit|silver-tdd)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sb_required_skill_is_recorded() {
  local state_contents="$1"
  local skill="$2"
  local alias

  while IFS= read -r alias; do
    [[ -n "$alias" ]] || continue
    if grep -Fqx -- "$alias" <<<"$state_contents" 2>/dev/null; then
      return 0
    fi
  done < <(sb_required_skill_aliases "$skill")

  return 1
}

sb_required_skill_line() {
  local state_contents="$1"
  local skill="$2"
  local alias line best_line=0

  while IFS= read -r alias; do
    [[ -n "$alias" ]] || continue
    line=$(printf '%s\n' "$state_contents" | grep -Fnx -- "$alias" | head -1 | cut -d: -f1)
    [[ "$line" =~ ^[0-9]+$ ]] || continue
    if (( best_line == 0 || line < best_line )); then
      best_line="$line"
    fi
  done < <(sb_required_skill_aliases "$skill")

  printf '%s' "$best_line"
}

sb_required_skills_filter_retired() {
  local skill retired skip out=""
  for skill in "$@"; do
    [[ -n "$skill" ]] || continue
    skip=false
    if [[ "$skill" == ${__SB_RS_RETIRED_NS_HYPHEN}* ]] || [[ "$skill" == ${__SB_RS_RETIRED_NS_COLON}* ]]; then
      skip=true
    fi
    for retired in $__SB_RS_RETIRED_REQUIRED_SKILLS; do
      if [[ "$skill" == "$retired" ]]; then
        skip=true
        break
      fi
    done
    if [[ "$skip" == false ]]; then
      out="${out:+$out }$skill"
    fi
  done
  printf '%s' "$out"
}

sb_required_skills_dedupe() {
  local skill existing already out=""
  for skill in "$@"; do
    [[ -n "$skill" ]] || continue
    already=false
    for existing in $out; do
      if [[ "$existing" == "$skill" ]]; then
        already=true
        break
      fi
    done
    if [[ "$already" == false ]]; then
      out="${out:+$out }$skill"
    fi
  done
  printf '%s' "$out"
}

sb_required_skills_normalize_configured_list() {
  local config_file="$1"
  local configured="$2"
  local defaults="$3"
  local filtered

  if [[ -z "$configured" ]]; then
    printf '%s' "$defaults"
    return 0
  fi

  if sb_required_skills_config_is_legacy "$config_file"; then
    # shellcheck disable=SC2086
    filtered=$(sb_required_skills_filter_retired $configured)
    # shellcheck disable=SC2086
    sb_required_skills_dedupe $defaults $filtered
    return 0
  fi

  printf '%s' "$configured"
}

# Fallback used only when default config or jq unavailable. Keep minimal —
# hooks always enforce at least the planning/quality-gate floor.
__SB_RS_FALLBACK="silver-quality-gates silver-completion-audit verify-tests"
__SB_RS_PLANNING_FALLBACK="silver-quality-gates silver-context silver-plan"
__SB_RS_DEVOPS_PLANNING_FALLBACK="silver-blast-radius devops-quality-gates silver-context silver-plan"
__SB_RS_ALL_TRACKED_FALLBACK="silver-quality-gates silver-quality-gates-design silver-quality-gates-adversarial verify-tests"

# One jq pass fills every default list (seven lists, one fork): an unreadable template or an empty list keeps the
# literal fallback.
# shellcheck disable=SC2034  # the lists are read by the hooks that source this file
__sb_rs_populate() {
  local cfg out="" line n=0 v1="" v2="" v3="" v4="" v5="" v6="" v7=""
  if cfg="$(__sb_rs_find_default_config)" && command -v jq >/dev/null 2>&1; then
    out="$(jq -r '.skills | [.required_planning, .required_planning_devops, .required_deploy, .required_deploy_devops,
      .required_release, .required_release_devops, .all_tracked][] | (if type == "array" then join(" ") else "" end)' "${cfg}" 2>/dev/null)" || out=""
  fi
  while IFS= read -r line; do
    n=$((n + 1))
    case "$n" in
      1) v1="$line" ;;
      2) v2="$line" ;;
      3) v3="$line" ;;
      4) v4="$line" ;;
      5) v5="$line" ;;
      6) v6="$line" ;;
      7) v7="$line" ;;
    esac
  done <<<"$out"
  DEFAULT_PLANNING="${v1:-${__SB_RS_PLANNING_FALLBACK}}"
  DEVOPS_DEFAULT_PLANNING="${v2:-${__SB_RS_DEVOPS_PLANNING_FALLBACK}}"
  DEFAULT_REQUIRED="${v3:-${__SB_RS_FALLBACK}}"
  DEVOPS_DEFAULT_REQUIRED="${v4:-${__SB_RS_FALLBACK}}"
  DEFAULT_RELEASE_REQUIRED="${v5:-silver-create-release}"
  DEVOPS_DEFAULT_RELEASE_REQUIRED="${v6:-silver-create-release}"
  DEFAULT_ALL_TRACKED="${v7:-${__SB_RS_ALL_TRACKED_FALLBACK}}"
}

__sb_rs_populate
