# shellcheck shell=bash
# L-02: core-rules.md integrity pin — detect tampered enforcement rules before injection.

sb_core_rules_pin_file() {
  local hooks_dir="${1:-}"
  [[ -n "$hooks_dir" ]] || return 1
  printf '%s/core-rules.sha256' "$hooks_dir"
}

sb_core_rules_compute_hash() {
  local core_rules_file="${1:-}"
  [[ -f "$core_rules_file" ]] || return 1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$core_rules_file" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$core_rules_file" | awk '{print $1}'
    return 0
  fi
  return 1
}

sb_core_rules_expected_hash() {
  local hooks_dir="${1:-}"
  local pin_file
  pin_file="$(sb_core_rules_pin_file "$hooks_dir" 2>/dev/null || true)"
  [[ -f "$pin_file" ]] || return 1
  head -1 "$pin_file" 2>/dev/null | tr -d '[:space:]'
}

# Returns 0 only when core-rules.md matches the pinned hash.
sb_core_rules_integrity_ok() {
  local core_rules_file="${1:-}"
  local hooks_dir="${2:-}"
  [[ -f "$core_rules_file" && -n "$hooks_dir" ]] || return 1

  local expected actual
  expected="$(sb_core_rules_expected_hash "$hooks_dir" 2>/dev/null || true)"
  [[ -n "$expected" ]] || return 1

  actual="$(sb_core_rules_compute_hash "$core_rules_file" 2>/dev/null || true)"
  [[ -n "$actual" && "$actual" == "$expected" ]]
}

# Print verified core-rules content, or empty when integrity fails.
sb_core_rules_read_verified() {
  local core_rules_file="${1:-}"
  local hooks_dir="${2:-}"
  [[ -f "$core_rules_file" ]] || return 1

  if ! sb_core_rules_integrity_ok "$core_rules_file" "$hooks_dir"; then
    return 1
  fi
  cat "$core_rules_file"
}

sb_core_rules_integrity_warning() {
  printf '%s' '⚠️ core-rules.md integrity check failed or is missing a pin — enforcement rules were not injected. Run /silver:init or reinstall the Silver Bullet plugin.'
}
