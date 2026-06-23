#!/usr/bin/env bash
# Tests for enforcement tier gate (P1).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/enforcement-tier-gate.sh"
TIER_LIB="$REPO_ROOT/hooks/lib/capability-tier.sh"
PASS=0
FAIL=0

# shellcheck source=../../hooks/lib/capability-tier.sh
source "$TIER_LIB"
# shellcheck source=../../hooks/lib/enforcement-tier-gate.sh
source "$LIB"

assert_true() {
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

assert_false() {
  local name="$1"
  shift
  if ! "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
echo '{"sb_enforcement_tier":0}' >"$WORK/.silver-bullet.json"

assert_false "tier 0 blocks delivery" sb_enforcement_tier_delivery_allowed "$WORK/.silver-bullet.json"

jq '.sb_enforcement_tier = 2' "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"
# Effective tier is min(config, probed) — in CI without hooks probed may be 0
eff="$(sb_enforcement_tier_effective "$WORK/.silver-bullet.json")"
assert_true "effective tier is numeric" test "$eff" -ge 0

banner="$(sb_enforcement_tier_session_banner 0)"
assert_true "tier 0 banner mentions inactive" grep -q 'inactive' <<<"$banner"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
