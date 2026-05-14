#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_ISOLATION_HELPER="${SCRIPT_DIR}/../live/lib/kay-codex-isolation.sh"
SCENARIO_DIR="${SCRIPT_DIR}/scenarios"
DEPENDENCY_PREFLIGHT_SCRIPT="${SCRIPT_DIR}/dependency-access-preflight.sh"
E2E_LIVE_MATRIX_FILE="${HOME}/.claude/.silver-bullet/e2e-live-matrix"
INLINE_E2E_MATRIX_FILE="${HOME}/.claude/.silver-bullet/inline-e2e-matrix"
SCENARIOS=(
  "${SCENARIO_DIR}/test-e2e-live-full-surface-journey.sh"
)
RUNTIMES=()
full_matrix_requested=false

if [[ -n "${SB_E2E_LIVE_RUNTIMES:-}" ]]; then
  # shellcheck disable=SC2206
  RUNTIMES=(${SB_E2E_LIVE_RUNTIMES})
else
  RUNTIMES=(claude codex)
fi

if [[ ${#RUNTIMES[@]} -eq 2 ]]; then
  has_claude=false
  has_codex=false
  for runtime in "${RUNTIMES[@]}"; do
    [[ "$runtime" == "claude" ]] && has_claude=true
    [[ "$runtime" == "codex" ]] && has_codex=true
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
echo "  Silver Bullet Live Todo-App E2E Suite"
echo "========================================"
echo ""
echo "WARNING: These tests invoke real Claude or Codex CLIs against the todo-app fixture."
echo "Estimated cost: higher than the hook matrix; keep runtimes narrow when iterating."
echo ""

rm -f "$E2E_LIVE_MATRIX_FILE"
rm -f "$INLINE_E2E_MATRIX_FILE"

TOTAL_FAIL=0
TOTAL_PASS=0

run_scenario() {
  local runtime="$1"
  local scenario="$2"
  echo ""
  echo "--- [$runtime] Running: $(basename "$scenario") ---"
  if SB_E2E_LIVE_RUNTIME="$runtime" bash "$scenario"; then
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

  marker_file="$(mktemp "${TMPDIR:-/tmp}/sb-e2e-live-dependency-preflight-${runtime}.XXXXXX")"
  export E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE="$marker_file"

  if ! SB_E2E_LIVE_RUNTIME="$runtime" bash "$DEPENDENCY_PREFLIGHT_SCRIPT"; then
    rm -f "$marker_file"
    unset E2E_LIVE_DEPENDENCY_PREFLIGHT_FILE
    return 1
  fi
}

for runtime in "${RUNTIMES[@]}"; do
  case "$runtime" in
    claude|codex)
      ;;
    *)
      echo "ERROR: unsupported runtime: $runtime"
      exit 1
      ;;
  esac

  if [[ "$runtime" == "claude" ]]; then
    if ! /Users/shafqat/.local/bin/claude --version >/dev/null 2>&1; then
      echo "ERROR: claude CLI not found or not working at /Users/shafqat/.local/bin/claude"
      exit 1
    fi
  else
    # shellcheck source=tests/live/lib/kay-codex-isolation.sh
    source "$CODEX_ISOLATION_HELPER"
    setup_kay_codex_isolation
    if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
      echo "ERROR: Kay/Codex CLI not found or not working"
      exit 1
    fi
    if ! CODEX_BIN="$CODEX_BIN" "$SCRIPT_DIR/../../scripts/install-codex.sh" --purge-legacy-skills >/dev/null 2>&1; then
      echo "ERROR: codex marketplace/bootstrap install failed"
      exit 1
    fi
  fi

  if ! run_dependency_preflight "$runtime"; then
    echo "ERROR: dependency-access preflight failed for runtime: $runtime"
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

  if [[ "$runtime" == "codex" ]]; then
    teardown_kay_codex_isolation
  fi
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
  elif [[ ${#RUNTIMES[@]} -eq 1 && "${RUNTIMES[0]}" == "codex" ]]; then
    marker="codex-only"
  fi

  if [[ -n "$marker" ]]; then
    mkdir -p "$(dirname "$E2E_LIVE_MATRIX_FILE")"
    cat > "$E2E_LIVE_MATRIX_FILE" <<EOF
matrix=${marker}
EOF
    cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
  else
    rm -f "$E2E_LIVE_MATRIX_FILE"
    rm -f "$INLINE_E2E_MATRIX_FILE"
    echo "  NOTE: E2E release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SCENARIOS PASSED"
  exit 0
fi
