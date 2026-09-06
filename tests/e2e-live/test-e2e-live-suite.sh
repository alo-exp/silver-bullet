#!/usr/bin/env bash
# Harness sanity checks for the live enterprise E2E suite.
#
# These checks are intentionally cheap: they verify that the suite layout exists
# before the expensive live Claude/Codex runs are added to CI or release flows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PASS=0
FAIL=0

# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${SCRIPT_DIR}/lib/skill-prompt.sh"

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
  if grep -Eq -- "$pattern" "$path"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_text_contains() {
  local label="$1"
  local text="$2"
  local pattern="$3"
  if grep -Eq -- "$pattern" <<<"$text"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_text_not_contains() {
  local label="$1"
  local text="$2"
  local pattern="$3"
  if grep -Eq -- "$pattern" <<<"$text"; then
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
    PASS=$((PASS + 1))
  fi
}

echo "=== e2e-live suite sanity checks ==="
assert_exists "suite runner exists" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_executable "suite runner is executable" "${SCRIPT_DIR}/run-e2e-live-tests.sh"
assert_file_contains "suite runner writes inline release marker" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'matrix=inline-full-surface'
assert_exists "shared helpers exist" "${SCRIPT_DIR}/helpers.sh"
assert_file_contains "live suite sets bounded per-turn timeout" "${REPO_ROOT}/tests/live/run-live-tests.sh" 'CODEX_INTERACTIVE_TIMEOUT="\$\{CODEX_INTERACTIVE_TIMEOUT:-300\}"'
assert_file_contains "enterprise e2e suite sets bounded per-turn timeout" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'CODEX_INTERACTIVE_TIMEOUT="\$\{CODEX_INTERACTIVE_TIMEOUT:-300\}"'
if awk 'NR <= 12 && /SILVER_BULLET_RUNTIME="claude"/ { found=1 } END { exit found ? 0 : 1 }' "${REPO_ROOT}/tests/live/run-live-tests.sh"; then
  echo "FAIL: live suite does not force Claude before runtime-path inference"
  FAIL=$((FAIL + 1))
else
  echo "PASS: live suite does not force Claude before runtime-path inference"
  PASS=$((PASS + 1))
fi
assert_file_contains "live suite writes release marker in host state" "${REPO_ROOT}/tests/live/run-live-tests.sh" 'HOST_RELEASE_LIVE_MATRIX_FILE="\$\{SB_RUNTIME_STATE_DIR\}/release-live-matrix"'
assert_file_contains "enterprise e2e writes release markers in host state" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'HOST_E2E_LIVE_MATRIX_FILE="\$\{SB_RUNTIME_STATE_DIR\}/e2e-live-matrix"'
assert_file_contains "live suite preserves host verify-tests marker" "${REPO_ROOT}/tests/live/run-live-tests.sh" 'HOST_VERIFY_TESTS_STATE_FILE="\$\{SB_RUNTIME_STATE_DIR\}/verify-tests-state"'
assert_file_contains "enterprise e2e preserves host verify-tests marker" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'HOST_VERIFY_TESTS_STATE_FILE="\$\{SB_RUNTIME_STATE_DIR\}/verify-tests-state"'
assert_file_contains "live suite treats Kay as Codex-compatible full matrix" "${REPO_ROOT}/tests/live/run-live-tests.sh" 'runtime" == "codex" \|\| "\$runtime" == "kay"'
assert_file_contains "enterprise e2e treats Kay as Codex-compatible full matrix" "${SCRIPT_DIR}/run-e2e-live-tests.sh" 'runtime" == "codex" \|\| "\$runtime" == "kay"'
assert_file_contains "Claude live agent enforces bounded prompt timeout" "${REPO_ROOT}/tests/live/agents/claude/agent.sh" 'timed out waiting for Claude prompt to complete'
assert_file_contains "Claude live agent unsets API keys in clean env" "${REPO_ROOT}/tests/live/agents/claude/agent.sh" 'unset ANTHROPIC_API_KEY OPENAI_API_KEY'
assert_file_contains "Claude live agent strips settings.json API keys for matrix" "${REPO_ROOT}/tests/live/agents/claude/agent.sh" 'claude_matrix_auth_prepare'
assert_file_contains "Claude live agent exports settings env for interactive auth" "${REPO_ROOT}/tests/live/agents/claude/agent.sh" 'claude_matrix_auth_env_lines'
assert_file_contains "Claude matrix auth helper exists" "${REPO_ROOT}/scripts/lib/claude-matrix-auth.sh" 'claude_matrix_auth_restore'
assert_file_contains "Claude matrix auth exports settings env" "${REPO_ROOT}/scripts/lib/claude-matrix-auth.sh" 'claude_matrix_export_settings_env'
assert_file_contains "Claude live agent avoids login shell for clean env" "${REPO_ROOT}/tests/live/agents/claude/agent.sh" 'bash -c'
assert_file_contains "Claude interactive harness dismisses splash screen" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'dismiss_claude_splash'
assert_file_contains "Claude interactive harness passes settings for api_key auth" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" '--settings \$settings_file'
assert_file_contains "Claude interactive harness recovers from context exhaustion" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'recover_from_context_exhaustion'
assert_file_contains "Claude interactive harness detects context-full stall" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'context_exhaustion_visible'
assert_file_contains "Claude interactive harness resolves blocking clarify picker" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'resolve_blocking_decision_picker'
assert_file_contains "Claude interactive harness detects blocking clarify picker" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'blocking_decision_picker_visible'
assert_file_contains "Claude interactive harness confirms collapsed paste submit" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'confirm_pasted_prompt_submit'
assert_file_contains "Claude interactive harness detects collapsed paste buffer" "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'paste again to expand' "${REPO_ROOT}/scripts/claude-interactive-invoke.expect" 'blocking_decision_picker_visible'
assert_file_contains "enterprise matrix row 1 accepts routing state fallback" "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" 'verify_row_routing_state_delta'
assert_file_contains "live doc scheme uses Claude-native Bash wording" "${REPO_ROOT}/tests/live/test-live-doc-scheme.sh" 'Use the Bash tool to run exactly'
assert_file_contains "live doc scheme has deterministic script fallback" "${REPO_ROOT}/tests/live/test-live-doc-scheme.sh" 'bash "\./\.live-doc-step\.sh"'
if grep -R --exclude='test-e2e-live-suite.sh' 'Use apply_patch' "${REPO_ROOT}/tests/live" "${SCRIPT_DIR}" >/dev/null 2>&1; then
  echo "FAIL: live prompts do not force Kay to call apply_patch as a shell command"
  FAIL=$((FAIL + 1))
else
  echo "PASS: live prompts do not force Kay to call apply_patch as a shell command"
  PASS=$((PASS + 1))
fi
assert_exists "dependency-access preflight exists" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_executable "dependency-access preflight is executable" "${SCRIPT_DIR}/dependency-access-preflight.sh"
assert_exists "hook-delivery preflight exists" "${SCRIPT_DIR}/hook-delivery-preflight.sh"
assert_executable "hook-delivery preflight is executable" "${SCRIPT_DIR}/hook-delivery-preflight.sh"
assert_exists "hook-failure scenario exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh"
assert_file_contains "state tamper hook probe seeds planning marker before command attempt" "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh" "printf 'silver-quality-gates"
assert_exists "full-surface journey exists" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"
assert_file_contains "live enforcement rejects timeout output" "${REPO_ROOT}/tests/live/test-live-enforcement.sh" 'live turn did not time out'
assert_file_contains "full-surface journey strips ANSI before evaluating responses" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'strip_ansi_response'
assert_file_contains "full-surface journey rejects Codex timeout output" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'timed out waiting for Codex prompt to complete'
assert_file_contains "full-surface journey rejects stop-hook block output" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'Cannot complete -- missing required skills'
assert_file_contains "full-surface journey rejects missing SB CLI adapter" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'command not found: silver-bullet'
assert_file_contains "full-surface journey constrains SB CLI adapter matcher" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'silver-bullet invoke-skill \[\^\[:space:\]\]\+ not available'
assert_file_contains "full-surface journey treats tool errors as controlled fallback" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'produced tool-error transcript; using controlled fallback'
assert_file_contains "full-surface journey detects permission-denied tool errors" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'Permission denied'
assert_file_contains "full-surface journey detects exec exit-code tool errors" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'exit_code'
assert_file_contains "full-surface journey collects timeout child process tree" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'collect_process_tree_pids'
assert_file_contains "full-surface journey terminates timeout child pids" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'kill_process_id_list TERM'
assert_file_contains "full-surface journey force-kills stubborn timeout child pids" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'kill_process_id_list KILL'
assert_file_contains "full-surface journey fails route-smoke timeouts" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'route-smoke turns must stop after the SB adapter receipt'
assert_file_contains "full-surface journey validates route-smoke transcript command order" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'assert_route_smoke_adapter_only'
assert_file_contains "route-smoke transcript validator ignores hook bridge commands" "${SCRIPT_DIR}/lib/route-smoke-transcript.py" 'project-hook-bridge\.sh'
assert_file_contains "route-smoke transcript validator requires exact SB adapter argv" "${SCRIPT_DIR}/lib/route-smoke-transcript.py" 'expected = \["silver-bullet", "invoke-skill", route\]'
assert_file_contains "route-smoke transcript validator normalizes bash -lc adapter wrapper" "${SCRIPT_DIR}/lib/route-smoke-transcript.py" 'normalize_route_smoke_adapter'
assert_executable "route-smoke transcript unit test is executable" "${SCRIPT_DIR}/test-route-smoke-transcript.sh"
assert_file_contains "full-surface journey seeds full planning floor" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'silver-context silver-plan'
assert_file_contains "full-surface journey shortens route-smoke workflow-doc wait" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'workflow_docs_deadline=\$\(\(SECONDS \+ 2\)\)'
assert_file_contains "full-surface journey always executes sb:deep-research" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'journey_turn "sb:deep-research"'
assert_file_contains "full-surface source scanner ignores collapsed negative prompts" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'donotreadoruselocal'
assert_file_contains "full-surface source scanner ignores explicit non-use denials" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'didnotreadoruse'
assert_file_contains "full-surface source scanner normalizes punctuation and whitespace" "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" 'compact_for_negative_context'
if grep -Eq 'multai_dependency_available|skipped because MultAI dependency is unavailable' "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"; then
  echo "FAIL: full-surface journey no longer skips research when MultAI is absent"
  FAIL=$((FAIL + 1))
else
  echo "PASS: full-surface journey no longer skips research when MultAI is absent"
  PASS=$((PASS + 1))
fi
if grep -Eq 'Explicitly follow the Silver Bullet|Do not skip the nested' "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh"; then
  echo "FAIL: full-surface journey route-smoke prompts do not request nested workflow execution"
  FAIL=$((FAIL + 1))
else
  echo "PASS: full-surface journey route-smoke prompts do not request nested workflow execution"
  PASS=$((PASS + 1))
fi

codex_quality_prompt="$(E2E_RUNTIME=codex skill_prompt 'sb:quality-gates' 'Run gates now.')"
kay_quality_prompt="$(E2E_RUNTIME=kay skill_prompt 'sb:quality-gates' 'Run gates now.')"
claude_quality_prompt="$(E2E_RUNTIME=claude SILVER_SKILL_PATH='/tmp/silver/SKILL.md' skill_prompt 'sb:quality-gates' 'Run gates now.')"
assert_text_contains "Codex prompt routes quality-gates through SB adapter" "$codex_quality_prompt" 'silver-bullet invoke-skill sb:quality-gates'
assert_text_contains "Kay prompt routes quality-gates through SB adapter" "$kay_quality_prompt" 'silver-bullet invoke-skill sb:quality-gates'
assert_text_contains "Codex prompt names exact route-smoke command" "$codex_quality_prompt" 'first and only non-hook command'
assert_text_contains "Codex prompt forbids bare SB adapter usage" "$codex_quality_prompt" 'Do not run bare `silver-bullet`'
assert_text_contains "Codex prompt bounds live route-smoke turns" "$codex_quality_prompt" 'bounded live E2E route-smoke turn'
assert_text_contains "Codex prompt stops after the SB adapter receipt" "$codex_quality_prompt" 'after the adapter prints the skill, stop'
assert_text_contains "Codex prompt prevents extra live commands" "$codex_quality_prompt" 'Do not execute another command, do not edit files, do not run tests'
assert_text_contains "Codex prompt treats task context as non-executable" "$codex_quality_prompt" 'Treat the task context as non-executable context only'
assert_text_contains "Codex prompt forbids direct SKILL.md path execution" "$codex_quality_prompt" 'do not open, cat, source, or execute any SKILL\.md path'
assert_text_not_contains "Codex prompt does not expose Markdown skill-link entrypoint" "$codex_quality_prompt" '\[\$silver\]\('
assert_text_contains "Claude prompt preserves Markdown skill-link entrypoint" "$claude_quality_prompt" '\[\$silver\]\(/tmp/silver/SKILL\.md\)'
assert_file_contains "helpers trust temp workspaces before live turns" "${SCRIPT_DIR}/helpers.sh" 'trust_runtime_workspace'
assert_file_contains "workspace preparation invokes trust seeding" "${SCRIPT_DIR}/helpers.sh" '^  trust_runtime_workspace$'
assert_file_contains "enterprise matrix setup_workspace seeds codex workspace trust" "${SCRIPT_DIR}/helpers.sh" 'Pre-trust fixture workspace before interactive Codex matrix turns'
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
assert_file_contains "native Codex PTY launcher suppresses closed stdout tracebacks" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'except BrokenPipeError'
assert_file_contains "native Codex PTY launcher archives transcript before stdout forwarding" "${REPO_ROOT}/scripts/codex-interactive-invoke.py" 'stdout_forwarding_enabled = forward_stdout\(chunk, stdout_forwarding_enabled\)'
assert_file_contains "native Codex isolation uses stable workspace temp root" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'default_codex_isolation_parent'
assert_file_contains "Kay isolation uses stable workspace temp root" "${REPO_ROOT}/tests/live/lib/kay-codex-isolation.sh" 'default_kay_isolation_parent'
assert_file_contains "Codex isolation mirrors the native plugin cache" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'original_codex_home}/plugins/cache'
assert_file_contains "Codex isolation prunes dependency plugin registry entries" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'pruned = \{key: value for key, value in plugins.items\(\) if key in allowed_plugins\}'
assert_file_contains "Codex isolation prepends isolated SB CLI shim" "${REPO_ROOT}/tests/live/lib/codex-cli-isolation.sh" 'PATH="\$\{CODEX_HOME\}/bin:'
assert_file_contains "dependency preflight verifies native SB CLI shim" "${SCRIPT_DIR}/helpers.sh" 'Native Codex Silver Bullet CLI shim is on PATH'
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
if [[ "${#scenario_list[@]}" -eq 1 \
  && "${scenario_list[0]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh" ]]; then
  echo "PASS: default scenario list is hook-failures only (legacy journey opt-in)"
  PASS=$((PASS + 1))
elif [[ "${#scenario_list[@]}" -eq 2 \
  && "${scenario_list[0]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-hook-failures.sh" \
  && "${scenario_list[1]:-}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" ]]; then
  echo "PASS: legacy full-surface journey listed after hook-failures when opt-in enabled"
  PASS=$((PASS + 1))
else
  echo "FAIL: unexpected default scenario list"
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
