# shellcheck shell=bash
# SessionStart prerequisite probe (Wave 0.2).

sb_prereq_find_repair_script() {
  local root="${1:-$PWD}"
  local candidate
  for candidate in \
    "$root/scripts/sb-prerequisite-repair.sh" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/scripts/sb-prerequisite-repair.sh"; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

sb_prereq_check_jq() {
  command -v jq >/dev/null 2>&1
}

sb_prereq_check_plugin_cache() {
  local cache="${SB_RUNTIME_PLUGIN_CACHE_ROOT:-}"
  [[ -n "$cache" && -d "$cache" ]] || return 1
  # At least one silver-bullet plugin directory present
  shopt -s nullglob
  local dirs=("$cache"/*/silver-bullet/* "$cache"/*silver-bullet*)
  shopt -u nullglob
  [[ ${#dirs[@]} -gt 0 ]]
}

sb_prereq_run_probe() {
  local repo_root="${1:-$PWD}"
  local issues=()

  sb_prereq_check_jq || issues+=("jq missing")
  sb_prereq_check_plugin_cache || issues+=("Silver Bullet plugin cache not found")

  if [[ ! -f "$repo_root/.silver-bullet.json" || ! -f "$repo_root/silver-bullet.md" ]]; then
    issues+=("SB project files incomplete — run /silver:init")
  fi

  # L-02: core-rules integrity pin in plugin hooks directory
  local hooks_dir=""
  if _hd="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"; then
    hooks_dir="$_hd"
  fi
  if [[ -n "$hooks_dir" && -f "$hooks_dir/core-rules.md" && -f "$hooks_dir/core-rules.sha256" ]]; then
    if [[ -f "$hooks_dir/lib/core-rules-integrity.sh" ]]; then
      # shellcheck source=lib/core-rules-integrity.sh
      source "$hooks_dir/lib/core-rules-integrity.sh"
      sb_core_rules_integrity_ok "$hooks_dir/core-rules.md" "$hooks_dir" || \
        issues+=("core-rules.md integrity pin mismatch — reinstall Silver Bullet")
    fi
  fi

  if [[ ${#issues[@]} -eq 0 ]]; then
    return 0
  fi

  local repair
  repair="$(sb_prereq_find_repair_script "$repo_root" 2>/dev/null || true)"
  if [[ -n "$repair" ]]; then
    "$repair" "$repo_root" 2>/dev/null || true
    # Full re-probe after repair attempt (P4)
    issues=()
    sb_prereq_check_jq || issues+=("jq missing")
    sb_prereq_check_plugin_cache || issues+=("Silver Bullet plugin cache not found")
    if [[ ! -f "$repo_root/.silver-bullet.json" || ! -f "$repo_root/silver-bullet.md" ]]; then
      issues+=("SB project files incomplete — run /silver:init")
    fi
    if [[ ${#issues[@]} -eq 0 ]]; then
      return 0
    fi
  fi

  printf '%s' "${issues[*]}"
  return 1
}

sb_prereq_blocking_message() {
  local issues_text="$1"
  cat <<EOF
🛑 Silver Bullet prerequisites missing: ${issues_text}

Run /silver:init to repair the installation, or install jq:
  macOS: brew install jq
  Linux: sudo apt install jq
EOF
}
