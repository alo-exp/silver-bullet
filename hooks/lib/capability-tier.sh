# shellcheck shell=bash
# Silver Bullet — runtime capability tier probe (shared by session-start, diagnostics).

sb_capability_hooks_present() {
  local runtime_home="${1:-${SB_RUNTIME_HOME_ROOT:-}}"
  [[ -n "$runtime_home" ]] || return 1
  if [[ -f "${runtime_home}/config.toml" ]] && grep -q 'silver-bullet' "${runtime_home}/config.toml" 2>/dev/null; then
    return 0
  fi
  if [[ -f "${HOME}/.cursor/hooks.json" ]] && grep -q 'silver-bullet' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
    return 0
  fi
  if [[ -f "${HOME}/.claude/settings.json" ]] && grep -q 'silver-bullet' "${HOME}/.claude/settings.json" 2>/dev/null; then
    return 0
  fi
  return 1
}

sb_capability_tier_name() {
  local hooks_present="no"
  local state_dir="${SB_RUNTIME_STATE_DIR:-}"
  if sb_capability_hooks_present "${SB_RUNTIME_HOME_ROOT:-}"; then
    hooks_present="yes"
  fi
  if [[ "$hooks_present" == "yes" && -n "$state_dir" && -d "$state_dir" ]]; then
    printf 'hook-enforced'
    return 0
  fi
  if [[ -n "$state_dir" && -d "$state_dir" ]]; then
    printf 'state-tracked'
    return 0
  fi
  printf 'guidance-only'
}

sb_capability_tier_banner() {
  local tier
  tier="$(sb_capability_tier_name)"
  case "$tier" in
    hook-enforced)
      printf 'Silver Bullet capability: tier 2 (hook-enforced). PreToolUse/Stop/delivery gates are active.'
      ;;
    state-tracked)
      printf 'Silver Bullet capability: tier 1 (state-tracked). Skill markers record, but hooks may not fire — run bash scripts/sb-diagnostics.sh. Do not claim hook enforcement on ship/release.'
      ;;
    *)
      printf 'Silver Bullet capability: tier 0 (guidance-only). Skills and docs apply; mechanical enforcement is INACTIVE. Install host hooks per docs/RUNTIME-COMPATIBILITY.md before claiming SB gated this work.'
      ;;
  esac
}
