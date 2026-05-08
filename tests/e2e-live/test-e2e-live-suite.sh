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
assert_exists "install UX scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-install-ux.sh"
assert_exists "init/feature scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-init-and-feature.sh"
assert_exists "regression repair scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-regression-repair.sh"
assert_exists "release prep scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-release-prep.sh"

scenario_list=()
while IFS= read -r scenario; do
  [[ -n "$scenario" ]] || continue
  scenario_list+=("$scenario")
done < <("${SCRIPT_DIR}/run-e2e-live-tests.sh" --list)
if [[ "${scenario_list[0]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-install-ux.sh" ]]; then
  echo "PASS: install UX scenario is first in the live suite"
  PASS=$((PASS + 1))
else
  echo "FAIL: install UX scenario is first in the live suite"
  echo "  first listed scenario: ${scenario_list[0]:-<none>}"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
