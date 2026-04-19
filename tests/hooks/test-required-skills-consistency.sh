#!/usr/bin/env bash
# test-required-skills-consistency.sh — CONS-02 regression guard
#
# Single source of truth for the required-deploy skill list must be
# templates/silver-bullet.config.json.default. hooks/lib/required-skills.sh
# must derive DEFAULT_REQUIRED and DEVOPS_DEFAULT_REQUIRED from it.
#
# This test sources the lib, reads the config, and asserts the two lists
# match as sorted sets. Divergence = FAIL.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/templates/silver-bullet.config.json.default"
LIB="$REPO_ROOT/hooks/lib/required-skills.sh"

PASS=0
FAIL=0
check() {
  local name="$1"; shift
  if "$@"; then
    PASS=$((PASS + 1))
    echo "  ok: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name"
  fi
}

[[ -f "$CONFIG" ]] || { echo "missing $CONFIG"; exit 1; }
[[ -f "$LIB"    ]] || { echo "missing $LIB"; exit 1; }

# Load lib vars.
# shellcheck disable=SC1090
source "$LIB"

sort_space() { tr ' ' '\n' | sed '/^$/d' | sort -u; }

CFG_REQUIRED_DEPLOY=$(jq -r '.skills.required_deploy | .[]' "$CONFIG" | sort -u)
CFG_REQUIRED_DEVOPS=$(jq -r '.skills.required_deploy_devops | .[]' "$CONFIG" 2>/dev/null | sort -u)

LIB_REQUIRED_DEPLOY=$(printf '%s' "${DEFAULT_REQUIRED:-}" | sort_space)
LIB_REQUIRED_DEVOPS=$(printf '%s' "${DEVOPS_DEFAULT_REQUIRED:-}" | sort_space)

echo "[required-skills-consistency]"

check "required_deploy set matches DEFAULT_REQUIRED" \
  test "$CFG_REQUIRED_DEPLOY" = "$LIB_REQUIRED_DEPLOY"
if [[ "$CFG_REQUIRED_DEPLOY" != "$LIB_REQUIRED_DEPLOY" ]]; then
  echo "    --- config required_deploy ---"
  echo "$CFG_REQUIRED_DEPLOY" | sed 's/^/    /'
  echo "    --- lib DEFAULT_REQUIRED ---"
  echo "$LIB_REQUIRED_DEPLOY" | sed 's/^/    /'
fi

check "required_deploy_devops set matches DEVOPS_DEFAULT_REQUIRED" \
  test "$CFG_REQUIRED_DEVOPS" = "$LIB_REQUIRED_DEVOPS"
if [[ "$CFG_REQUIRED_DEVOPS" != "$LIB_REQUIRED_DEVOPS" ]]; then
  echo "    --- config required_deploy_devops ---"
  echo "$CFG_REQUIRED_DEVOPS" | sed 's/^/    /'
  echo "    --- lib DEVOPS_DEFAULT_REQUIRED ---"
  echo "$LIB_REQUIRED_DEVOPS" | sed 's/^/    /'
fi

# Enforce that the lib is a reader (not a hardcoded literal) —
# presence of a hardcoded multi-skill DEFAULT_REQUIRED= assignment is the drift vector.
check "lib sources config (no hardcoded literal DEFAULT_REQUIRED)" \
  bash -c '! grep -qE "^DEFAULT_REQUIRED=\"silver-quality-gates" "'"$LIB"'"'

# Cross-list validation: every skill in required_deploy must appear in all_tracked.
# Without this, a skill can be required for deployment but never recordable (deadlock).
CFG_ALL_TRACKED=$(jq -r '.skills.all_tracked | .[]' "$CONFIG" | sort -u)
missing_from_tracked=()
while IFS= read -r skill; do
  if ! printf '%s\n' "$CFG_ALL_TRACKED" | grep -qx "$skill"; then
    missing_from_tracked+=("$skill")
  fi
done < <(jq -r '.skills.required_deploy | .[]' "$CONFIG")

check "all required_deploy skills are in all_tracked" \
  test "${#missing_from_tracked[@]}" -eq 0
if [[ ${#missing_from_tracked[@]} -gt 0 ]]; then
  echo "    Skills in required_deploy but missing from all_tracked:"
  for s in "${missing_from_tracked[@]}"; do echo "      - $s"; done
fi

# Same check for required_deploy_devops
missing_from_tracked_devops=()
while IFS= read -r skill; do
  if ! printf '%s\n' "$CFG_ALL_TRACKED" | grep -qx "$skill"; then
    missing_from_tracked_devops+=("$skill")
  fi
done < <(jq -r '.skills.required_deploy_devops | .[]' "$CONFIG" 2>/dev/null)

check "all required_deploy_devops skills are in all_tracked" \
  test "${#missing_from_tracked_devops[@]}" -eq 0
if [[ ${#missing_from_tracked_devops[@]} -gt 0 ]]; then
  echo "    Skills in required_deploy_devops but missing from all_tracked:"
  for s in "${missing_from_tracked_devops[@]}"; do echo "      - $s"; done
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
