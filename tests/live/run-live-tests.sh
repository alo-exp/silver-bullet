#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_ISOLATION_HELPER="${SCRIPT_DIR}/lib/kay-codex-isolation.sh"
RUNTIMES=()
RELEASE_LIVE_MATRIX_FILE=""
full_matrix_requested=false
if [[ -n "${SB_LIVE_RUNTIMES:-}" ]]; then
  # shellcheck disable=SC2206
  RUNTIMES=(${SB_LIVE_RUNTIMES})
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

echo "========================================"
echo "  Silver Bullet Live AI E2E Test Suite"
echo "========================================"
echo ""
echo "WARNING: These tests invoke the real Claude CLI or the Kay-backed agent."
echo "Estimated cost: \$0.10-\$0.60 per full run."
echo ""

if [[ -n "$RELEASE_LIVE_MATRIX_FILE" ]]; then
  rm -f "$RELEASE_LIVE_MATRIX_FILE"
fi

TOTAL_FAIL=0

run_suite() {
  local runtime="$1"
  local name="$2"
  local script="$3"
  echo ""
  echo "--- [$runtime] Running: $name ---"
  if SB_LIVE_RUNTIME="$runtime" bash "$script"; then
    echo "SUITE PASSED: [$runtime] $name"
  else
    echo "SUITE FAILED: [$runtime] $name"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

for runtime in "${RUNTIMES[@]}"; do
  case "$runtime" in
    claude)
      RELEASE_LIVE_MATRIX_FILE="${HOME}/.claude/.silver-bullet/release-live-matrix"
      if ! /Users/shafqat/.local/bin/claude --version >/dev/null 2>&1; then
        echo "ERROR: claude CLI not found or not working at /Users/shafqat/.local/bin/claude"
        exit 1
      fi
      ;;
    codex)
      # shellcheck source=tests/live/lib/kay-codex-isolation.sh
      source "$CODEX_ISOLATION_HELPER"
      setup_kay_codex_isolation
      RELEASE_LIVE_MATRIX_FILE="${KAY_HOME}/.kay/.silver-bullet/release-live-matrix"
      if [[ -z "${CODEX_BIN:-}" ]] || ! "$CODEX_BIN" --version >/dev/null 2>&1; then
        echo "ERROR: Kay CLI not found or not working"
        exit 1
      fi
      if ! CODEX_BIN="$CODEX_BIN" "$SCRIPT_DIR/../../scripts/install-codex.sh" --purge-legacy-skills >/dev/null 2>&1; then
        echo "ERROR: Kay-backed marketplace/bootstrap install failed"
        exit 1
      fi
      ;;
    *)
    echo "ERROR: unsupported agent: $runtime"
      exit 1
      ;;
  esac

  run_suite "$runtime" "Enforcement" "$SCRIPT_DIR/test-live-enforcement.sh"
  run_suite "$runtime" "Skill Recording" "$SCRIPT_DIR/test-live-skill-recording.sh"
  run_suite "$runtime" "Full Scenario" "$SCRIPT_DIR/test-live-full-scenario.sh"
  run_suite "$runtime" "Doc Scheme" "$SCRIPT_DIR/test-live-doc-scheme.sh"

  if [[ "$runtime" == "codex" ]]; then
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
  elif [[ ${#RUNTIMES[@]} -eq 1 && "${RUNTIMES[0]}" == "codex" ]]; then
    marker="codex-only"
  fi

  if [[ -n "$marker" ]]; then
    mkdir -p "$(dirname "$RELEASE_LIVE_MATRIX_FILE")"
    cat > "$RELEASE_LIVE_MATRIX_FILE" <<EOF
matrix=${marker}
EOF
  else
    rm -f "$RELEASE_LIVE_MATRIX_FILE"
    echo "  NOTE: Release marker not written because the full Claude/Codex matrix was not run."
  fi
  echo "  OVERALL: ALL SUITES PASSED"
  exit 0
fi
