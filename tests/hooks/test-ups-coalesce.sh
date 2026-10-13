#!/usr/bin/env bash
# Tests for UserPromptSubmit additionalContext coalesce (#262).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/ups-coalesce.sh
source "${REPO_ROOT}/hooks/lib/ups-coalesce.sh"

TMP_STATE="$(mktemp -d)"
export SB_RUNTIME_STATE_DIR="$TMP_STATE"
trap 'rm -rf "$TMP_STATE"' EXIT

pass=0
fail=0

assert_true() {
  local label="$1"
  shift
  if "$@"; then
    pass=$((pass + 1))
    printf 'PASS: %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$label" >&2
  fi
}

assert_false() {
  local label="$1"
  shift
  if ! "$@"; then
    pass=$((pass + 1))
    printf 'PASS: %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$label" >&2
  fi
}

assert_contains() {
  local label="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    pass=$((pass + 1))
    printf 'PASS: %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s — missing %s in %s\n' "$label" "$needle" "$hay" >&2
  fi
}

assert_not_contains() {
  local label="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    fail=$((fail + 1))
    printf 'FAIL: %s — unexpected %s\n' "$label" "$needle" >&2
  else
    pass=$((pass + 1))
    printf 'PASS: %s\n' "$label"
  fi
}

BANNER=$'Outstanding per-prompt outcomes:\n  - Ship the fix'

sb_ups_coalesce_reset
assert_true "first claim succeeds" sb_ups_coalesce_claim "$BANNER"
assert_false "duplicate claim rejected" sb_ups_coalesce_claim "$BANNER"
assert_true "different banner allowed" sb_ups_coalesce_claim $'Instruction ledger — unresolved items:\n- [a] item'

# Hard reset starts a new turn
sb_ups_coalesce_reset
assert_true "same banner ok after reset" sb_ups_coalesce_claim "$BANNER"

sb_ups_coalesce_reset
out1="$(sb_ups_emit_additional_context "$BANNER" "UserPromptSubmit")"
assert_contains "first emit has additionalContext" "$out1" "additionalContext"
assert_contains "first emit has banner text" "$out1" "Outstanding per-prompt outcomes"

out2="$(sb_ups_emit_additional_context "$BANNER" "UserPromptSubmit")"
assert_not_contains "duplicate emit omits additionalContext" "$out2" "additionalContext"
assert_contains "duplicate emit still valid UPS payload" "$out2" "UserPromptSubmit"

# Stale turn (TTL) allows re-emit of same banner
printf '%s' "$(($(date +%s) - 30))" >"$(sb_ups_coalesce_turn_file)"
out3="$(sb_ups_emit_additional_context "$BANNER" "UserPromptSubmit")"
assert_contains "stale turn re-emits additionalContext" "$out3" "additionalContext"

printf '\n=== ups-coalesce: %d passed, %d failed ===\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
