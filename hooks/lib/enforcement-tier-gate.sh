# shellcheck shell=bash
# Enforcement tier honesty — block delivery when hooks inactive (P1).

sb_enforcement_tier_read_config() {
  local config_file="$1"
  [[ -n "$config_file" && -f "$config_file" ]] || { printf '0'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf '0'; return 0; }
  jq -r 'if (.sb_enforcement_tier // "") != "" then (.sb_enforcement_tier | tostring) else "" end' "$config_file" 2>/dev/null || true
}

sb_enforcement_tier_probe() {
  if [[ -f "${_lib_dir:-}/capability-tier.sh" ]]; then
    # shellcheck source=lib/capability-tier.sh
    source "${_lib_dir}/capability-tier.sh"
  elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/capability-tier.sh" ]]; then
    # shellcheck source=lib/capability-tier.sh
    source "$(dirname "${BASH_SOURCE[0]}")/capability-tier.sh"
  fi

  local tier_name
  tier_name="$(sb_capability_tier_name 2>/dev/null || echo guidance-only)"
  case "$tier_name" in
    hook-enforced) printf '2' ;;
    state-tracked) printf '1' ;;
    live-tested) printf '3' ;;
    *) printf '0' ;;
  esac
}

sb_enforcement_tier_persist() {
  local config_file="$1"
  local tier="$2"
  [[ -n "$config_file" && -f "$config_file" && -n "$tier" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local updated
  updated="$(jq --argjson t "$tier" '.sb_enforcement_tier = $t' "$config_file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && printf '%s' "$updated" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
}

sb_enforcement_tier_effective() {
  local config_file="${1:-}"
  local configured probed
  configured=""
  if [[ -n "$config_file" ]]; then
    configured="$(sb_enforcement_tier_read_config "$config_file")"
  fi
  probed="$(sb_enforcement_tier_probe)"
  if [[ -n "$configured" && "$configured" =~ ^[0-3]$ ]]; then
  # Use minimum of configured and probed — never overclaim hook enforcement.
    if [[ "$configured" -lt "$probed" ]]; then
      printf '%s' "$configured"
    else
      printf '%s' "$probed"
    fi
    return 0
  fi
  printf '%s' "$probed"
}

sb_enforcement_tier_delivery_allowed() {
  local tier
  tier="$(sb_enforcement_tier_effective "${1:-}")"
  [[ "${tier:-0}" -ge 2 ]]
}

sb_enforcement_tier_block_message() {
  local tier="${1:-0}"
  cat <<EOF
🛑 Silver Bullet enforcement inactive — tier ${tier} (< 2 hook-enforced).

Mechanical gates (completion audit, stop-check, orchestrator directive) are not active in this host runtime.
Install and merge host hooks per docs/RUNTIME-COMPATIBILITY.md, then re-run /silver:init.

Do not claim SB hook-gated delivery until tier ≥ 2. Run: bash scripts/sb-diagnostics.sh
EOF
}

sb_enforcement_tier_session_banner() {
  local tier="${1:-0}"
  case "$tier" in
    0)
      printf 'SB enforcement inactive — tier 0 (guidance-only). Skills apply; hooks do not block. See docs/RUNTIME-COMPATIBILITY.md.'
      ;;
    1)
      printf 'SB enforcement tier 1 (state-tracked). Skill markers record; PreToolUse/Stop gates may not fire.'
      ;;
    2)
      printf 'SB enforcement tier 2 (hook-enforced). PreToolUse/Stop/delivery gates active.'
      ;;
    3)
      printf 'SB enforcement tier 3 (live-tested). Hook-enforced plus release live matrix receipts.'
      ;;
    *)
      printf 'SB enforcement tier unknown — run bash scripts/sb-diagnostics.sh'
      ;;
  esac
}
