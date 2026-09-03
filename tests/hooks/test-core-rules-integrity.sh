#!/usr/bin/env bash
# Tests for hooks/lib/core-rules-integrity.sh (L-02).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/core-rules-integrity.sh"
HOOKS_DIR="${REPO_ROOT}/hooks"
CORE_RULES="${HOOKS_DIR}/core-rules.md"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_fail() {
  local name="$1"
  shift
  if "$@"; then
    echo "FAIL: $name (expected failure)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $name"
    PASS=$((PASS + 1))
  fi
}

expected="$(sb_core_rules_expected_hash "$HOOKS_DIR")"
actual="$(sb_core_rules_compute_hash "$CORE_RULES")"
assert_eq "pin matches core-rules.md" "$expected" "$actual"
assert_ok "integrity ok for canonical file" sb_core_rules_integrity_ok "$CORE_RULES" "$HOOKS_DIR"

TMP=$(mktemp)
cp "$CORE_RULES" "$TMP"
echo "# tamper" >> "$TMP"
assert_fail "tampered file fails integrity" sb_core_rules_integrity_ok "$TMP" "$HOOKS_DIR"
rm -f "$TMP"

TMP_HOOKS_DIR=$(mktemp -d)
cp "$CORE_RULES" "$TMP_HOOKS_DIR/core-rules.md"
assert_fail "missing pin fails integrity" sb_core_rules_integrity_ok "$TMP_HOOKS_DIR/core-rules.md" "$TMP_HOOKS_DIR"
missing_pin_content="$(sb_core_rules_read_verified "$TMP_HOOKS_DIR/core-rules.md" "$TMP_HOOKS_DIR" 2>/dev/null || true)"
assert_eq "missing pin does not read core rules" "" "$missing_pin_content"
rm -rf "$TMP_HOOKS_DIR"

content="$(sb_core_rules_read_verified "$CORE_RULES" "$HOOKS_DIR" | head -1)"
assert_eq "read verified returns content" "# Silver Bullet — Core Enforcement Rules" "$content"


verified="$(sb_core_rules_read_verified "$CORE_RULES" "$HOOKS_DIR")"
digest="$(sb_core_rules_compact_digest "$verified" "$CORE_RULES")"
digest_bytes=$(printf '%s' "$digest" | wc -c | tr -d ' ')
if [[ "$digest_bytes" -le 3072 ]]; then
  echo "PASS: compact digest size ${digest_bytes}B <= 3072B"
  PASS=$((PASS + 1))
else
  echo "FAIL: compact digest size ${digest_bytes}B > 3072B"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$digest" | grep -q "Non-Negotiable\|Process is non-negotiable"; then
  echo "PASS: digest keeps non-negotiable markers"
  PASS=$((PASS + 1))
else
  echo "FAIL: digest missing non-negotiable markers"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$digest" | grep -q "Full rules (on demand)\|core-rules.md"; then
  echo "PASS: digest points to full core-rules path"
  PASS=$((PASS + 1))
else
  echo "FAIL: digest missing full-rules pointer"
  FAIL=$((FAIL + 1))
fi
vdigest="$(sb_core_rules_read_verified_digest "$CORE_RULES" "$HOOKS_DIR" || true)"
if [[ -n "$vdigest" ]]; then
  echo "PASS: read_verified_digest returns content"
  PASS=$((PASS + 1))
else
  echo "FAIL: read_verified_digest empty"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
