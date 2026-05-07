#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="${SCRIPT_DIR}/scenarios"
E2E_LIVE_MATRIX_FILE="${HOME}/.claude/.silver-bullet/e2e-live-matrix"
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
  find "$SCENARIO_DIR" -maxdepth 1 -type f -name 'test-*.sh' | sort
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
    if ! command -v codex >/dev/null 2>&1; then
      echo "ERROR: codex CLI not found in PATH"
      exit 1
    fi
    if ! "$SCRIPT_DIR/../../scripts/install-codex.sh" --purge-legacy-skills >/dev/null 2>&1; then
      echo "ERROR: codex marketplace/bootstrap install failed"
      exit 1
    fi
  fi

  for scenario in "$SCENARIO_DIR"/test-*.sh; do
    [[ -f "$scenario" ]] || continue
    run_scenario "$runtime" "$scenario"
  done
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
  else
    rm -f "$E2E_LIVE_MATRIX_FILE"
    echo "  NOTE: E2E release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SCENARIOS PASSED"
  exit 0
fi
