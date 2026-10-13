#!/usr/bin/env bash
set -euo pipefail
LIVE_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_ISOLATION_HELPER="${LIVE_TEST_ROOT}/lib/codex-cli-isolation.sh"
KAY_ISOLATION_HELPER="${LIVE_TEST_ROOT}/lib/kay-codex-isolation.sh"
CODEX_HOOK_TRANSPLANT_HELPER="${LIVE_TEST_ROOT}/lib/codex-hook-transplant.sh"

if [[ -f "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${LIVE_TEST_ROOT}/../../hooks/lib/runtime-paths.sh"
fi
if [[ -f "$CODEX_HOOK_TRANSPLANT_HELPER" ]]; then
  # shellcheck source=tests/live/lib/codex-hook-transplant.sh
  source "$CODEX_HOOK_TRANSPLANT_HELPER"
fi

RUNTIMES=()
RELEASE_LIVE_MATRIX_FILE=""
HOST_RELEASE_LIVE_MATRIX_FILE="${SB_RUNTIME_STATE_DIR}/release-live-matrix"
HOST_VERIFY_TESTS_STATE_FILE="${SB_RUNTIME_STATE_DIR}/verify-tests-state"
HOST_VERIFY_TESTS_BACKUP_FILE=""
HOST_VERIFY_TESTS_HAD_FILE=false
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

rm -f "$HOST_RELEASE_LIVE_MATRIX_FILE"

if [[ -f "$HOST_VERIFY_TESTS_STATE_FILE" ]]; then
  HOST_VERIFY_TESTS_HAD_FILE=true
  HOST_VERIFY_TESTS_BACKUP_FILE="$(mktemp "${TMPDIR:-/tmp}/sb-release-live-verify-tests-state.XXXXXX")"
  cp "$HOST_VERIFY_TESTS_STATE_FILE" "$HOST_VERIFY_TESTS_BACKUP_FILE"
fi

restore_host_verify_tests_state() {
  local rc=$?
  if [[ "$HOST_VERIFY_TESTS_HAD_FILE" == true && -n "$HOST_VERIFY_TESTS_BACKUP_FILE" && -f "$HOST_VERIFY_TESTS_BACKUP_FILE" ]]; then
    mkdir -p "$(dirname "$HOST_VERIFY_TESTS_STATE_FILE")"
    cp "$HOST_VERIFY_TESTS_BACKUP_FILE" "$HOST_VERIFY_TESTS_STATE_FILE"
    rm -f "$HOST_VERIFY_TESTS_BACKUP_FILE"
  elif [[ "$HOST_VERIFY_TESTS_HAD_FILE" == false ]]; then
    rm -f "$HOST_VERIFY_TESTS_STATE_FILE"
  fi
  return "$rc"
}
trap restore_host_verify_tests_state EXIT

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
      RELEASE_LIVE_MATRIX_FILE="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/release-live-matrix"
      if ! /Users/shafqat/.local/bin/claude --version >/dev/null 2>&1; then
        echo "ERROR: claude CLI not found or not working at /Users/shafqat/.local/bin/claude"
        exit 1
      fi
      ;;
    codex)
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/codex-cli-isolation.sh
      source "$CODEX_ISOLATION_HELPER"
      setup_codex_cli_isolation
      RELEASE_LIVE_MATRIX_FILE="${CODEX_HOME}/.silver-bullet/release-live-matrix"
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
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/kay-codex-isolation.sh
      source "$KAY_ISOLATION_HELPER"
      setup_kay_codex_isolation
      RELEASE_LIVE_MATRIX_FILE="${KAY_HOME}/.codex/.silver-bullet/release-live-matrix"
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
  RELEASE_LIVE_MATRIX_FILE="$HOST_RELEASE_LIVE_MATRIX_FILE"
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
    mkdir -p "$(dirname "$HOST_RELEASE_LIVE_MATRIX_FILE")"
    cat > "$HOST_RELEASE_LIVE_MATRIX_FILE" <<EOF
matrix=${marker}
EOF
  else
    rm -f "$HOST_RELEASE_LIVE_MATRIX_FILE"
    echo "  NOTE: Release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SUITES PASSED"
  exit 0
fi
