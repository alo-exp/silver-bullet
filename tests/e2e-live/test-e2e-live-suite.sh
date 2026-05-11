#!/usr/bin/env bash
# Harness sanity checks for the live todo-app E2E suite.
#
# These checks are intentionally cheap: they verify that the suite layout exists
# before the expensive live Claude/Codex runs are added to CI or release flows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

assert_exists() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (missing: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_executable() {
  local label="$1"
  local path="$2"
  if [[ -x "$path" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (not executable: $path)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== e2e-live suite sanity checks ==="
assert_exists "suite runner exists" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_executable "suite runner is executable" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_exists "shared helpers exist" "${SCRIPT_DIR}/helpers.sh"
assert_exists "dependency-access preflight exists" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_executable "dependency-access preflight is executable" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_exists "full-surface journey exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"

scenario_list=()
while IFS= read -r scenario; do
  [[ -n "$scenario" ]] || continue
  scenario_list+=("$scenario")
done < <("${SCRIPT_DIR}/run-e2e-live-tests.sh" --list)
if [[ "${#scenario_list[@]}" -eq 1 && "${scenario_list[0]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" ]]; then
  echo "PASS: full-surface journey is the only live suite scenario"
  PASS=$((PASS + 1))
else
  echo "FAIL: full-surface journey is the only live suite scenario"
  printf '  listed scenarios:'
  for scenario in "${scenario_list[@]}"; do
    printf ' %s' "$(basename "$scenario")"
  done
  printf '\n'
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
