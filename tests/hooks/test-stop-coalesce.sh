#!/usr/bin/env bash
# Tests for Stop hook coalesce (E2E-014).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/stop-coalesce.sh
source "${REPO_ROOT}/hooks/lib/stop-coalesce.sh"

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

sb_stop_coalesce_reset
assert_false "no block before record" sb_stop_coalesce_suppress_secondary_block

sb_stop_coalesce_record "first block reason"
assert_true "suppress after first record" sb_stop_coalesce_suppress_secondary_block

sb_stop_coalesce_record "second reason should not overwrite"
assert_true "first reason preserved" grep -q 'first block reason' "$(sb_stop_coalesce_file)"

sb_stop_coalesce_reset
assert_false "reset clears suppress" sb_stop_coalesce_suppress_secondary_block

printf '\n=== stop-coalesce: %d passed, %d failed ===\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
