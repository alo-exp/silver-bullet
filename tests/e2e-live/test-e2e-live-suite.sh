#!/usr/bin/env bash
# Harness sanity checks for the live todo-app E2E suite.
#
# These checks are intentionally cheap: they verify that the suite layout exists
# before the expensive live Claude/Codex runs are added to CI or release flows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
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

assert_file_contains() {
  local label="$1"
  local path="$2"
  local pattern="$3"
  if grep -Eq "$pattern" "$path"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== e2e-live suite sanity checks ==="
assert_exists "suite runner exists" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_executable "suite runner is executable" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_file_contains "suite runner writes inline release marker" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'matrix=inline-full-surface'
assert_exists "shared helpers exist" "${SCRIPT_DIR}/helpers.sh"
assert_file_contains "live suite sets bounded per-turn timeout" "${REPO_ROOT}/tests/live/run-live-tests.sh" 'CODEX_INTERACTIVE_TIMEOUT="\$\{CODEX_INTERACTIVE_TIMEOUT:-300\}"'
assert_exists "dependency-access preflight exists" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_executable "dependency-access preflight is executable" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_exists "hook-delivery preflight exists" "${SCRIPT_DIR}/hook-delivery-preflight.sh"
assert_executable "hook-delivery preflight is executable" "${SCRIPT_DIR}/hook-delivery-preflight.sh"
assert_exists "hook-failure scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh"
assert_exists "full-surface journey exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"
assert_file_contains "live enforcement rejects timeout output" "${REPO_ROOT}/tests/live/test-live-enforcement.sh" 'live turn did not time out'
assert_file_contains "full-surface journey strips ANSI before evaluating responses" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'strip_ansi_response'
assert_file_contains "full-surface journey rejects Codex timeout output" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'timed out waiting for Codex prompt to complete'
assert_file_contains "full-surface journey rejects stop-hook block output" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'Cannot complete -- missing required skills'
assert_file_contains "full-surface journey seeds full planning floor" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'gsd-discuss-phase gsd-plan-phase'
assert_file_contains "full-surface journey always executes silver:research" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'journey_turn "silver:research"'
if grep -Eq 'multai_dependency_available|skipped because MultAI dependency is unavailable' "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"; then
  echo "FAIL: full-surface journey no longer skips research when MultAI is absent"
  FAIL=$((FAIL + 1))
else
  echo "PASS: full-surface journey no longer skips research when MultAI is absent"
  PASS=$((PASS + 1))
fi
assert_file_contains "helpers trust temp workspaces before live turns" "${SCRIPT_DIR}/helpers.sh" 'trust_runtime_workspace'
assert_file_contains "workspace preparation invokes trust seeding" "${SCRIPT_DIR}/helpers.sh" '^  trust_runtime_workspace$'
assert_file_contains "Kay E2E helpers source the Kay isolation library in child shells" "${SCRIPT_DIR}/helpers.sh" 'source "\$\{SB_ROOT\}/tests/live/lib/kay-codex-isolation\.sh"'
assert_file_contains "interactive launcher fails fast on workspace trust prompt" "${REPO_ROOT}/scripts/codex-interactive-invoke.expect" 'workspace trust prompt surfaced'
assert_file_contains "interactive launcher fails fast on hook review prompt" "${REPO_ROOT}/scripts/codex-interactive-invoke.expect" 'interactive hook trust review surfaced'
assert_file_contains "interactive launcher supports native Codex hook trust bypass" "${REPO_ROOT}/scripts/codex-interactive-invoke.expect" 'CODEX_BYPASS_HOOK_TRUST'
assert_file_contains "interactive launcher supports isolated hook auto-trust" "${REPO_ROOT}/scripts/codex-interactive-invoke.expect" 'CODEX_AUTO_TRUST_HOOKS'
assert_file_contains "interactive launcher supports Kay config-home override" "${REPO_ROOT}/scripts/codex-interactive-invoke.expect" 'CODEX_KAY_HOME'
assert_file_contains "native Codex PTY launcher answers terminal capability probes" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'answer_terminal_queries'
assert_file_contains "native Codex PTY launcher recognizes the current Codex banner" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'openaicodex'
assert_file_contains "native Codex PTY launcher clears inherited desktop thread ids" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'CODEX_THREAD_ID'
assert_file_contains "native Codex PTY launcher clears inherited desktop originator overrides" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'CODEX_INTERNAL_ORIGINATOR_OVERRIDE'
assert_file_contains "native Codex isolation uses stable workspace temp root" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'default_codex_isolation_parent'
assert_file_contains "Kay isolation uses stable workspace temp root" "${REPO_ROOT}/tests/live/lib/kay-codex-isolation.sh" 'default_kay_isolation_parent'
assert_file_contains "Codex isolation mirrors the native plugin cache" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'original_codex_home}/plugins/cache'
assert_file_contains "hook transplant rewrites user hooks against the target home" "${REPO_ROOT}/tests/live/lib/codex-hook-transplant.sh" 'target_home_root'
assert_file_contains "native Codex agent enables hook trust bypass in isolation" "${REPO_ROOT}/tests/live/agents/codex/agent.sh" 'CODEX_BYPASS_HOOK_TRUST='
assert_file_contains "native Codex agent enables isolated hook auto-trust" "${REPO_ROOT}/tests/live/agents/codex/agent.sh" 'CODEX_AUTO_TRUST_HOOKS='
assert_file_contains "Kay agent enables isolated hook auto-trust" "${REPO_ROOT}/tests/live/agents/kay/agent.sh" 'CODEX_AUTO_TRUST_HOOKS='
assert_file_contains "Kay agent captures expect stderr for timeout assertions" "${REPO_ROOT}/tests/live/agents/kay/agent.sh" 'codex-interactive-invoke\.expect" 2>&1'

scenario_list=()
while IFS= read -r scenario; do
  [[ -n "$scenario" ]] || continue
  scenario_list+=("$scenario")
done < <("${SCRIPT_DIR}/run-e2e-live-tests.sh" --list)
if [[ "${#scenario_list[@]}" -eq 2 \
  && "${scenario_list[0]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh" \
  && "${scenario_list[1]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" ]]; then
  echo "PASS: hook-failure scenario runs before the full-surface journey"
  PASS=$((PASS + 1))
else
  echo "FAIL: hook-failure scenario runs before the full-surface journey"
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
