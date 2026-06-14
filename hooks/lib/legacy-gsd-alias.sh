# shellcheck shell=bash
# L-03: Legacy GSD skill alias normalization — sunset 2026-09-01.
#
# Hooks normalize legacy gsd-* / gsd:* names to canonical silver-* skills at the
# matcher boundary. New projects should invoke silver:* routes only.

# shellcheck disable=SC2034  # documented sunset date for downstream tooling
SB_GSD_ALIAS_SUNSET_DATE="2026-09-01"

sb_legacy_gsd_alias_normalize() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return 0

  local skill="$raw"
  if [[ "$skill" == silver:* ]]; then
    skill="silver-${skill#silver:}"
    skill="${skill//:/-}"
    printf '%s' "$skill"
    return 0
  fi
  skill="${skill#silver:}"
  skill="${skill//:/-}"

  case "$skill" in
    gsd-discuss-phase) printf '%s' 'silver-context' ;;
    gsd-plan-phase|gsd-plan) printf '%s' 'silver-plan' ;;
    gsd-execute-phase|gsd-autonomous) printf '%s' 'silver-execute' ;;
    gsd-verify-work) printf '%s' 'silver-verify' ;;
    gsd-ship) printf '%s' 'silver-ship' ;;
    gsd-code-review) printf '%s' 'silver-review' ;;
    gsd-secure-phase) printf '%s' 'silver-secure' ;;
    gsd-validate-phase) printf '%s' 'silver-validate' ;;
    gsd-ui-phase) printf '%s' 'silver-ui-contract' ;;
    gsd-ui-review) printf '%s' 'silver-ui-review' ;;
    gsd-complete-milestone) printf '%s' 'silver-release' ;;
    gsd-fast|gsd-quick) printf '%s' 'silver-fast' ;;
    gsd-debug) printf '%s' 'silver-debug' ;;
    gsd-new-project) printf '%s' 'silver-bootstrap-project' ;;
    gsd-new-milestone) printf '%s' 'silver-bootstrap-milestone' ;;
    gsd-scan|gsd-map-codebase) printf '%s' 'silver-orient' ;;
    *)
      printf '%s' "$skill"
      ;;
  esac
}

sb_legacy_gsd_alias_is_legacy() {
  local raw="${1:-}"
  [[ "$raw" == gsd:* || "$raw" == gsd-* ]]
}
