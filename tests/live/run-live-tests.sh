#!/usr/bin/env bash
set -euo pipefail
LIVE_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_ISOLATION_HELPER="${LIVE_TEST_ROOT}/lib/codex-cli-isolation.sh"
KAY_ISOLATION_HELPER="${LIVE_TEST_ROOT}/lib/kay-codex-isolation.sh"
CODEX_HOOK_TRANSPLANT_HELPER="${LIVE_TEST_ROOT}/lib/codex-hook-transplant.sh"
EVIDENCE_GUARD_HELPER="${LIVE_TEST_ROOT}/lib/evidence-guard.sh"
# shellcheck source=tests/live/lib/evidence-guard.sh
source "$EVIDENCE_GUARD_HELPER"

if [[ -f "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh"
fi
if [[ -f "$CODEX_HOOK_TRANSPLANT_HELPER" ]]; then
  # shellcheck source=tests/live/lib/codex-hook-transplant.sh
  source "$CODEX_HOOK_TRANSPLANT_HELPER"
fi

RUNTIMES=()
HOST_RELEASE_LIVE_MATRIX_FILE="${SB_RUNTIME_STATE_DIR}/release-live-matrix"
PENDING_RELEASE_MARKER=""
full_matrix_requested=false
if [[ -n "${SB_LIVE_RUNTIMES:-}" ]]; then
  # shellcheck disable=SC2206
  RUNTIMES=(${SB_LIVE_RUNTIMES})
else
  RUNTIMES=(claude)
fi

export CODEX_INTERACTIVE_TIMEOUT="${CODEX_INTERACTIVE_TIMEOUT:-300}"

runtime_model_provider() {
  local runtime="$1"
  if [[ -n "${SB_LIVE_CODEX_MODEL_PROVIDER:-}" ]]; then
    printf '%s\n' "$SB_LIVE_CODEX_MODEL_PROVIDER"
  elif [[ "$runtime" == "kay" ]]; then
    printf 'minimax\n'
  fi
}

runtime_model() {
  local runtime="$1"
  if [[ -n "${SB_LIVE_CODEX_MODEL:-}" ]]; then
    printf '%s\n' "$SB_LIVE_CODEX_MODEL"
  elif [[ "$runtime" == "kay" ]]; then
    printf 'MiniMax-M3\n'
  fi
}

runtime_reasoning_effort() {
  if [[ -n "${SB_LIVE_CODEX_REASONING_EFFORT:-}" ]]; then
    printf '%s\n' "$SB_LIVE_CODEX_REASONING_EFFORT"
  else
    printf 'low\n'
  fi
}

if [[ ${#RUNTIMES[@]} -eq 2 ]]; then
  has_claude=false
  has_codex=false
  for runtime in "${RUNTIMES[@]}"; do
    [[ "$runtime" == "claude" ]] && has_claude=true
    [[ "$runtime" == "codex" || "$runtime" == "kay" ]] && has_codex=true
  done
  if [[ "$has_claude" == true && "$has_codex" == true ]]; then
    full_matrix_requested=true
  fi
fi

echo "========================================"
echo "  Silver Bullet Live AI E2E Test Suite"
echo "========================================"
echo ""
echo "WARNING: These tests default to Claude CLI (direct OAuth when proxy settings are skipped)."
echo "Default provider/model: runtime-aware (Claude: native config; Codex/Kay: isolated Codex-compatible)."
echo "Per-turn timeout: ${CODEX_INTERACTIVE_TIMEOUT}s."
echo ""

# Snapshot every release-evidence file; the EXIT trap restores the ones this runner does not own
# (e2e-live-matrix, inline-e2e-matrix, quality-gate-state, verify-tests-state), tears down any
# isolated Codex/Kay home and writes release-live-matrix only after a complete pass
# (R14-03, R14-15).
sb_evidence_snapshot "$SB_RUNTIME_STATE_DIR"
sb_evidence_restore release-live-matrix

runner_exit() {
  local rc=$?
  trap - EXIT INT TERM
  if declare -F teardown_codex_cli_isolation >/dev/null 2>&1; then
    teardown_codex_cli_isolation || true
  fi
  if declare -F teardown_kay_codex_isolation >/dev/null 2>&1; then
    teardown_kay_codex_isolation || true
  fi
  sb_evidence_restore release-live-matrix
  if [[ "$rc" -eq 0 && -n "$PENDING_RELEASE_MARKER" ]]; then
    sb_evidence_write_marker "$HOST_RELEASE_LIVE_MATRIX_FILE" "$PENDING_RELEASE_MARKER" "$(cd "${LIVE_TEST_ROOT}/../.." && pwd)"
  fi
  sb_evidence_discard
  exit "$rc"
}
trap runner_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

TOTAL_FAIL=0

run_suite() {
  local runtime="$1"
  local name="$2"
  local script="$3"
  local provider
  local model
  local reasoning
  provider="$(runtime_model_provider "$runtime")"
  model="$(runtime_model "$runtime")"
  reasoning="$(runtime_reasoning_effort)"
  echo ""
  echo "--- [$runtime] Running: $name ---"
  if SB_LIVE_RUNTIME="$runtime" \
    SB_LIVE_CODEX_MODEL_PROVIDER="$provider" \
    SB_LIVE_CODEX_MODEL="$model" \
    SB_LIVE_CODEX_REASONING_EFFORT="$reasoning" \
    bash "$script"; then
    echo "SUITE PASSED: [$runtime] $name"
  else
    echo "SUITE FAILED: [$runtime] $name"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

for runtime in "${RUNTIMES[@]}"; do
  case "$runtime" in
    claude)
      SILVER_BULLET_RUNTIME="claude"
      if [[ -f "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh" ]]; then
        # shellcheck source=hooks/lib/runtime-paths.sh
        source "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh"
      fi
      if ! "${CLAUDE_BIN:-claude}" --version >/dev/null 2>&1; then
        echo "ERROR: claude CLI not found or not working at ${CLAUDE_BIN:-claude} (set CLAUDE_BIN or put claude on PATH)"
        exit 1
      fi
      ;;
    codex)
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/codex-cli-isolation.sh
      source "$CODEX_ISOLATION_HELPER"
      setup_codex_cli_isolation
      if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
        echo "ERROR: native Codex CLI not found or not working"
        exit 1
      fi
      if ! sync_install_generated_codex_user_hooks "$HOME" "codex"; then
        echo "ERROR: native Codex hook-surface refresh failed"
        exit 1
      fi
      ;;
    kay)
      # shellcheck disable=SC2034  # read by the sourced runtime-paths/isolation helpers
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/kay-codex-isolation.sh
      source "$KAY_ISOLATION_HELPER"
      setup_kay_codex_isolation
      if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
        echo "ERROR: Kay CLI not found or not working"
        exit 1
      fi
      if ! sync_install_generated_codex_user_hooks "$KAY_HOME" "kay"; then
        echo "ERROR: Kay-backed hook-surface refresh failed"
        exit 1
      fi
      ;;
    *)
    echo "ERROR: unsupported agent: $runtime"
      exit 1
      ;;
  esac

  run_suite "$runtime" "Doc Scheme" "$LIVE_TEST_ROOT/test-live-doc-scheme.sh"
  run_suite "$runtime" "Enforcement" "$LIVE_TEST_ROOT/test-live-enforcement.sh"
  run_suite "$runtime" "Skill Recording" "$LIVE_TEST_ROOT/test-live-skill-recording.sh"
  run_suite "$runtime" "Full Scenario" "$LIVE_TEST_ROOT/test-live-full-scenario.sh"

  if [[ "$runtime" == "codex" ]]; then
    teardown_codex_cli_isolation
  elif [[ "$runtime" == "kay" ]]; then
    teardown_kay_codex_isolation
  fi
done

echo ""
echo "========================================"
if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo "  OVERALL: $TOTAL_FAIL suite(s) FAILED"
  exit 1
else
  marker=""
  if [[ "$full_matrix_requested" == true ]]; then
    marker="full-claude-codex"
  elif [[ ${#RUNTIMES[@]} -eq 1 && "${RUNTIMES[0]}" == "claude" ]]; then
    marker="claude-only"
  elif [[ ${#RUNTIMES[@]} -eq 1 && ( "${RUNTIMES[0]}" == "codex" || "${RUNTIMES[0]}" == "kay" ) ]]; then
    marker="codex-only"
  fi

  if [[ -n "$marker" ]]; then
    PENDING_RELEASE_MARKER="$marker"
  else
    echo "  NOTE: Release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SUITES PASSED"
  exit 0
fi
