#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_ISOLATION_HELPER="${SCRIPT_DIR}/../live/lib/codex-cli-isolation.sh"
KAY_ISOLATION_HELPER="${SCRIPT_DIR}/../live/lib/kay-codex-isolation.sh"
CODEX_HOOK_TRANSPLANT_HELPER="${SCRIPT_DIR}/../live/lib/codex-hook-transplant.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi
if [[ -f "$CODEX_HOOK_TRANSPLANT_HELPER" ]]; then
  # shellcheck source=tests/live/lib/codex-hook-transplant.sh
  source "$CODEX_HOOK_TRANSPLANT_HELPER"
fi
SCENARIO_DIR="${SCRIPT_DIR}/scenarios"
DEPENDENCY_PREFLIGHT_SCRIPT="${SCRIPT_DIR}/dependency-access-preflight.sh"
HOOK_PREFLIGHT_SCRIPT="${SCRIPT_DIR}/hook-delivery-preflight.sh"
RECOMMENDED_TOOLS_PREFLIGHT_SCRIPT="${SCRIPT_DIR}/recommended-tools-preflight.sh"
E2E_LIVE_MATRIX_FILE=""
INLINE_E2E_MATRIX_FILE=""
HOST_E2E_LIVE_MATRIX_FILE="${SB_RUNTIME_STATE_DIR}/e2e-live-matrix"
HOST_INLINE_E2E_MATRIX_FILE="${SB_RUNTIME_STATE_DIR}/inline-e2e-matrix"
HOST_VERIFY_TESTS_STATE_FILE="${SB_RUNTIME_STATE_DIR}/verify-tests-state"
HOST_VERIFY_TESTS_BACKUP_FILE=""
HOST_VERIFY_TESTS_HAD_FILE=false
SCENARIOS=(
  "${SCENARIO_DIR}/test-e2e-live-hook-failures.sh"
)
# Kay inline full-surface journey (todo-app) retired — primary live gate is Claude
# supervised matrix per enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md.
# Legacy journey retained at scenarios/test-e2e-live-full-surface-journey.sh for reference.
LEGACY_SCENARIOS=(
  "${SCENARIO_DIR}/test-e2e-live-full-surface-journey.sh"
)
if [[ "${SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY:-0}" == "1" ]]; then
  SCENARIOS+=("${LEGACY_SCENARIOS[@]}")
fi
RUNTIMES=()
full_matrix_requested=false
export CODEX_INTERACTIVE_TIMEOUT="${CODEX_INTERACTIVE_TIMEOUT:-300}"

if [[ -n "${SB_E2E_LIVE_RUNTIMES:-}" ]]; then
  # shellcheck disable=SC2206
  RUNTIMES=(${SB_E2E_LIVE_RUNTIMES})
else
  RUNTIMES=(claude)
fi

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

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${SCENARIOS[@]}"
  exit 0
fi

echo "========================================"
echo "  Silver Bullet Enterprise Live E2E Suite"
echo "========================================"
echo ""
echo "WARNING: These tests default to Claude CLI against the enterprise-grade-test-app fixture."
echo "Default provider/model: runtime-aware (Claude: native config; Codex/Kay: isolated Codex-compatible)."
echo ""

rm -f "$HOST_E2E_LIVE_MATRIX_FILE"
rm -f "$HOST_INLINE_E2E_MATRIX_FILE"

if [[ -f "$HOST_VERIFY_TESTS_STATE_FILE" ]]; then
  HOST_VERIFY_TESTS_HAD_FILE=true
  HOST_VERIFY_TESTS_BACKUP_FILE="$(mktemp "${TMPDIR:-/tmp}/sb-e2e-live-verify-tests-state.XXXXXX")"
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
TOTAL_PASS=0

run_scenario() {
  local runtime="$1"
  local scenario="$2"
  local provider
  local model
  local reasoning
  provider="$(runtime_model_provider "$runtime")"
  model="$(runtime_model "$runtime")"
  reasoning="$(runtime_reasoning_effort)"
  echo ""
  echo "--- [$runtime] Running: $(basename "$scenario") ---"
  if SB_E2E_LIVE_RUNTIME="$runtime" \
    SB_ORCHESTRATOR_PARENT=0 \
    SB_LIVE_CODEX_MODEL_PROVIDER="$provider" \
    SB_LIVE_CODEX_MODEL="$model" \
    SB_LIVE_CODEX_REASONING_EFFORT="$reasoning" \
    bash "$scenario"; then
    echo "SCENARIO PASSED: [$runtime] $(basename "$scenario")"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "SCENARIO FAILED: [$runtime] $(basename "$scenario")"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

run_dependency_preflight() {
  local runtime="$1"
  local marker_file
  local provider
  local model
  local reasoning
  provider="$(runtime_model_provider "$runtime")"
  model="$(runtime_model "$runtime")"
  reasoning="$(runtime_reasoning_effort)"

  marker_file="$(mktemp "${TMPDIR:-/tmp}/sb-e2e-live-dependency-preflight-${runtime}.XXXXXX")"
  export E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE="$marker_file"

  if ! SB_E2E_LIVE_RUNTIME="$runtime" \
    SB_LIVE_CODEX_MODEL_PROVIDER="$provider" \
    SB_LIVE_CODEX_MODEL="$model" \
    SB_LIVE_CODEX_REASONING_EFFORT="$reasoning" \
    bash "$DEPENDENCY_PREFLIGHT_SCRIPT"; then
    rm -f "$marker_file"
    unset E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE
    return 1
  fi
}

run_hook_preflight() {
  local runtime="$1"
  local marker_file
  local provider
  local model
  local reasoning
  provider="$(runtime_model_provider "$runtime")"
  model="$(runtime_model "$runtime")"
  reasoning="$(runtime_reasoning_effort)"

  marker_file="$(mktemp "${TMPDIR:-/tmp}/sb-e2e-live-hook-preflight-${runtime}.XXXXXX")"
  export E2E_LIVE_HOOK_PREFLIGHT_FILE="$marker_file"

  if ! SB_E2E_LIVE_RUNTIME="$runtime" \
    SB_LIVE_CODEX_MODEL_PROVIDER="$provider" \
    SB_LIVE_CODEX_MODEL="$model" \
    SB_LIVE_CODEX_REASONING_EFFORT="$reasoning" \
    bash "$HOOK_PREFLIGHT_SCRIPT"; then
    rm -f "$marker_file"
    unset E2E_LIVE_HOOK_PREFLIGHT_FILE
    return 1
  fi
}

run_recommended_tools_preflight() {
  local runtime="$1"
  local provider
  local model
  local reasoning
  provider="$(runtime_model_provider "$runtime")"
  model="$(runtime_model "$runtime")"
  reasoning="$(runtime_reasoning_effort)"

  if ! SB_E2E_LIVE_RUNTIME="$runtime" \
    SB_LIVE_CODEX_MODEL_PROVIDER="$provider" \
    SB_LIVE_CODEX_MODEL="$model" \
    SB_LIVE_CODEX_REASONING_EFFORT="$reasoning" \
    bash "$RECOMMENDED_TOOLS_PREFLIGHT_SCRIPT"; then
    return 1
  fi
}

for runtime in "${RUNTIMES[@]}"; do
  case "$runtime" in
    claude|codex|kay)
      ;;
    *)
      echo "ERROR: unsupported agent: $runtime"
      exit 1
      ;;
  esac

  if [[ "$runtime" == "claude" ]]; then
    E2E_LIVE_MATRIX_FILE="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/e2e-live-matrix"
    INLINE_E2E_MATRIX_FILE="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/inline-e2e-matrix"
    if ! /Users/shafqat/.local/bin/claude --version >/dev/null 2>&1; then
      echo "ERROR: claude CLI not found or not working at /Users/shafqat/.local/bin/claude"
      exit 1
    fi
  elif [[ "$runtime" == "codex" ]]; then
    # shellcheck source=tests/live/lib/codex-cli-isolation.sh
    source "$CODEX_ISOLATION_HELPER"
    setup_codex_cli_isolation
    E2E_LIVE_MATRIX_FILE="${CODEX_HOME}/.silver-bullet/e2e-live-matrix"
    INLINE_E2E_MATRIX_FILE="${CODEX_HOME}/.silver-bullet/inline-e2e-matrix"
    if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
      echo "ERROR: native Codex CLI not found or not working"
      exit 1
    fi
    if ! sync_install_generated_codex_user_hooks "$HOME" "codex"; then
      echo "ERROR: codex hook-surface refresh failed"
      exit 1
    fi
  else
    # shellcheck source=tests/live/lib/kay-codex-isolation.sh
    source "$KAY_ISOLATION_HELPER"
    setup_kay_codex_isolation
    E2E_LIVE_MATRIX_FILE="${KAY_HOME}/.codex/.silver-bullet/e2e-live-matrix"
    INLINE_E2E_MATRIX_FILE="${KAY_HOME}/.codex/.silver-bullet/inline-e2e-matrix"
    if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
      echo "ERROR: Kay CLI not found or not working"
      exit 1
    fi
    if ! sync_install_generated_codex_user_hooks "$KAY_HOME" "kay"; then
      echo "ERROR: kay hook-surface refresh failed"
      exit 1
    fi
  fi

  if ! run_dependency_preflight "$runtime"; then
    if [[ "$runtime" != "claude" ]]; then
      if ! run_dependency_preflight "$runtime"; then
        echo "ERROR: dependency-access preflight failed for runtime: $runtime after hook-surface refresh"
        exit 1
      fi
    else
      echo "ERROR: dependency-access preflight failed for runtime: $runtime"
      exit 1
    fi
  fi

  if ! run_hook_preflight "$runtime"; then
    echo "ERROR: hook-delivery preflight failed for runtime: $runtime"
    echo "ERROR: live E2E cannot establish Silver Bullet hook enforcement for this runtime."
    exit 1
  fi

  if ! run_recommended_tools_preflight "$runtime"; then
    echo "ERROR: recommended-tools preflight failed for runtime: $runtime"
    echo "ERROR: live E2E requires all recommended tools opted in and host CLIs/MCP wired."
    exit 1
  fi

  for scenario in "${SCENARIOS[@]}"; do
    [[ -f "$scenario" ]] || continue
    run_scenario "$runtime" "$scenario"
  done

  if [[ -n "${E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE:-}" ]]; then
    rm -f "$E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE"
    unset E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE
  fi
  if [[ -n "${E2E_LIVE_HOOK_PREFLIGHT_FILE:-}" ]]; then
    rm -f "$E2E_LIVE_HOOK_PREFLIGHT_FILE"
    unset E2E_LIVE_HOOK_PREFLIGHT_FILE
  fi

  if [[ "$runtime" == "codex" ]]; then
    teardown_codex_cli_isolation
  elif [[ "$runtime" == "kay" ]]; then
    teardown_kay_codex_isolation
  fi
  E2E_LIVE_MATRIX_FILE="$HOST_E2E_LIVE_MATRIX_FILE"
  INLINE_E2E_MATRIX_FILE="$HOST_INLINE_E2E_MATRIX_FILE"
done

echo ""
echo "========================================"
if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo "  OVERALL: ${TOTAL_FAIL} scenario(s) FAILED"
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
    mkdir -p "$(dirname "$HOST_E2E_LIVE_MATRIX_FILE")"
    cat > "$HOST_E2E_LIVE_MATRIX_FILE" <<EOF
matrix=${marker}
EOF
    cat > "$HOST_INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
  else
    rm -f "$HOST_E2E_LIVE_MATRIX_FILE"
    rm -f "$HOST_INLINE_E2E_MATRIX_FILE"
    echo "  NOTE: E2E release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SCENARIOS PASSED"
  exit 0
fi
