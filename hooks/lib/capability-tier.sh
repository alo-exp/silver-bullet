# shellcheck shell=bash
# Silver Bullet — runtime capability tier probe (shared by session-start, diagnostics).

sb_capability_hooks_present() {
  local runtime_home="${1:-${SB_RUNTIME_HOME_ROOT:-}}"
  local runtime="${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-}}"
  [[ -n "$runtime_home" ]] || return 1
  case "$runtime" in
    cursor)
      [[ -f "${runtime_home}/hooks.json" ]] && grep -q 'silver-bullet' "${runtime_home}/hooks.json" 2>/dev/null
      ;;
    codex)
      [[ -f "${runtime_home}/config.toml" ]] && grep -q 'silver-bullet' "${runtime_home}/config.toml" 2>/dev/null
      ;;
    claude|*)
      [[ -f "${runtime_home}/settings.json" ]] && grep -q 'silver-bullet' "${runtime_home}/settings.json" 2>/dev/null
      ;;
  esac
}

sb_capability_runtime_name() {
  if [[ -n "${SB_RUNTIME_NAME:-}" ]]; then
    printf '%s' "${SB_RUNTIME_NAME}"
    return 0
  fi
  if [[ -n "${SILVER_BULLET_RUNTIME:-}" ]]; then
    printf '%s' "${SILVER_BULLET_RUNTIME}"
    return 0
  fi
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]; then
    printf 'codex'
    return 0
  fi
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]]; then
    printf 'cursor'
    return 0
  fi
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    case "$CLAUDE_PLUGIN_ROOT" in
      */.codex/*) printf 'codex'; return 0 ;;
      */.cursor/*) printf 'cursor'; return 0 ;;
    esac
  fi
  printf 'claude'
}

sb_capability_tier_number() {
  case "$(sb_capability_tier_name)" in
    hook-enforced) printf '2' ;;
    state-tracked) printf '1' ;;
    live-tested) printf '3' ;;
    *) printf '0' ;;
  esac
}

sb_capability_tier_name() {
  if [[ "${SILVER_BULLET_TEST_HOOK_ENFORCED:-}" == "1" ]]; then
    printf 'hook-enforced'
    return 0
  fi
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
