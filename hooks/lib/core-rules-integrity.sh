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

# Hard budget for SessionStart inline rules (#263). Hosts truncate ~10KB+ payloads
# to ~2KB previews; keep the injected digest within 2–3KB so non-negotiables survive.
SB_CORE_RULES_DIGEST_MAX_BYTES="${SB_CORE_RULES_DIGEST_MAX_BYTES:-3072}"

# Build a compact SessionStart digest from verified core-rules content.
# Args: <verified_content> <core_rules_file_path>
# Prints digest to stdout (never larger than SB_CORE_RULES_DIGEST_MAX_BYTES).
sb_core_rules_compact_digest() {
  local verified="${1:-}"
  local core_rules_file="${2:-}"
  local max_bytes="${SB_CORE_RULES_DIGEST_MAX_BYTES:-3072}"
  local digest path_note non_neg

  [[ -n "$verified" ]] || return 1
  path_note="${core_rules_file:-hooks/core-rules.md}"

  # Prefer the Non-Negotiable Rules section when present; fall back to a head slice.
  non_neg="$(printf '%s\n' "$verified" | awk '
    BEGIN { keep=0 }
    /^## Non-Negotiable Rules/ { keep=1 }
    keep { print }
    /^## / && !/^## Non-Negotiable Rules/ { if (keep) exit }
  ')"
  if [[ -z "$non_neg" ]]; then
    non_neg="$(printf '%s\n' "$verified" | head -n 40)"
  fi

  digest="$(cat <<EOF
# Silver Bullet — Core Enforcement Rules (SessionStart digest)

> **Motto: Process is non-negotiable. Hooks enforce. Vacuous invocation is a violation.**

${non_neg}

## Full rules (on demand)

Host SessionStart budgets truncate large payloads. This is a compact digest (~2–3KB).
Read the full enforcement model (16 layers), Active Workflow, Review Loop, and Anti-Rationalization at:
\`${path_note}\`

Do NOT skip required skills; do NOT declare complete without the planning/delivery floors.
EOF
)"

  # Hard byte cap — prefer keeping the header + non-negotiables + path footer.
  if [[ ${#digest} -gt "$max_bytes" ]]; then
    local header footer body room
    header="# Silver Bullet — Core Enforcement Rules (SessionStart digest)

> **Motto: Process is non-negotiable. Hooks enforce. Vacuous invocation is a violation.**

"
    footer="

## Full rules (on demand)

Host SessionStart budgets truncate large payloads. Read full rules at:
\`${path_note}\`
"
    room=$((max_bytes - ${#header} - ${#footer}))
    if [[ "$room" -lt 200 ]]; then
      room=200
    fi
    body="$(printf '%s\n' "$non_neg" | head -c "$room")"
    digest="${header}${body}${footer}"
    if [[ ${#digest} -gt "$max_bytes" ]]; then
      digest="$(printf '%s' "$digest" | head -c "$max_bytes")"
    fi
  fi

  printf '%s' "$digest"
}

# Verified compact digest for SessionStart injection (#263).
sb_core_rules_read_verified_digest() {
  local core_rules_file="${1:-}"
  local hooks_dir="${2:-}"
  local verified
  verified="$(sb_core_rules_read_verified "$core_rules_file" "$hooks_dir" 2>/dev/null || true)"
  [[ -n "$verified" ]] || return 1
  sb_core_rules_compact_digest "$verified" "$core_rules_file"
}

