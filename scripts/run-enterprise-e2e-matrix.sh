#!/usr/bin/env bash
# Run enterprise workflow matrix rows against enterprise-grade-test-app via interactive Claude TUI.
# Usage:
#   bash scripts/run-enterprise-e2e-matrix.sh              # all rows 1-20
#   bash scripts/run-enterprise-e2e-matrix.sh 1 3 5         # specific rows
#   SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh 1
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
MATRIX_DOC="${FIXTURE_DIR}/docs/WORKFLOW_E2E_MATRIX.md"

export SB_E2E_ENTERPRISE_MATRIX=1
export CLAUDE_USE_INTERACTIVE=1
export CLAUDE_MODEL="${CLAUDE_MODEL:-sonnet}"
export CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"
export CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-900}"
export CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-180}"
export SB_E2E_LIVE_RUNTIME=claude
export SILVER_BULLET_RUNTIME=claude

# shellcheck source=tests/e2e-live/helpers.sh
source "${SB_ROOT}/tests/e2e-live/helpers.sh"
# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${SB_ROOT}/tests/e2e-live/lib/skill-prompt.sh"

declare -a MATRIX_ROWS=(
  '1|silver-router|/silver|I need to add order validation to the API — route me.|.planning/workflows/router-session.md'
  '2|silver-research|/silver:research|Should we use Postgres or SQLite for orders?|docs/ADR-001-runtime.md'
  '3|silver-feature|/silver:feature|Add currency field to orders API + tests.|.planning/workflows/feature-currency.md'
  '4|silver-bugfix|/silver:bugfix|Health endpoint returns 500 when version is missing.|.planning/workflows/bugfix-health.md'
  '5|silver-ui|/silver:ui|Show API version in the admin UI badge.|.planning/workflows/ui-version-badge.md'
  '6|silver-fast|/silver:fast|Fix README install instructions only.|.planning/workflows/fast-readme.md'
  '7|silver-test|/silver:test|Add integration test for order creation.|.planning/workflows/test-orders-integration.md'
  '8|silver-refactor|/silver:refactor|Extract order validation into domain/orders/.|.planning/workflows/refactor-order-validation.md'
  '9|silver-benchmark|/silver:benchmark|Benchmark health endpoint p95 latency.|docs/benchmarks/health.md'
  '10|silver-content|/silver:content|Write public API consumer docs.|docs/API.md'
  '11|silver-devops|/silver:devops|Add environment variable validation in Terraform.|.planning/workflows/devops-terraform-validation.md'
  '12|silver-deploy|/silver:deploy|Document staging deploy procedure.|docs/DEPLOY.md'
  '13|silver-canary|/silver:canary|Add canary rollout notes for API.|docs/CANARY.md'
  '14|silver-release|/silver:release|Ship v0.2.0 with changelog.|CHANGELOG.md'
  '15|review-triad|/silver:review-triad|Review the currency field change before merge.|.planning/reviews/triad-currency.md'
  '16|ship-readiness|/silver:ship-readiness|Is this branch ready to merge?|.planning/ship-readiness/checklist.md'
  '17|silver-incident|/silver:incident|CI failed on main — run incident workflow.|docs/incidents/INC-001.md'
  '18|silver-retro|/silver:retro|Retro after v0.2.0 ship.|docs/retro/RETRO-001.md'
  '19|silver-forensics|/silver:forensics|Investigate why verify-tests failed last session.|docs/forensics/CI-001.md'
  '20|process-maintenance|/silver:process-maintenance|Update workflow map after SB catalog bump.|docs/WORKFLOW_E2E_MATRIX.md'
)

PASS_ROWS=0
FAIL_ROWS=0
SKIP_ROWS=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [row_numbers...]

Run enterprise E2E matrix rows via interactive Claude TUI.
Fixture: ${FIXTURE_DIR}
Ledger:  ${LEDGER_FILE}

Environment:
  SB_E2E_MATRIX_DRY_RUN=1     Verify evidence only, skip Claude sessions
  SB_E2E_MATRIX_FORCE=1        Re-run rows even when evidence exists
  CLAUDE_INTERACTIVE_QUIET_TIMEOUT  Seconds of quiet before row completes (default 180)
EOF
}

should_run_row() {
  local row_num="$1"
  shift || true
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "$row_num" ]]; then
      return 0
    fi
  done
  return 1
}

graphify_query_ref() {
  local slug="$1"
  printf 'graphify query "%s routes hooks skills orchestrator"' "$slug"
}

build_matrix_prompt() {
  local route="$1"
  local prompt_card="$2"
  skill_prompt "$route" "Enterprise E2E matrix validation. ${prompt_card} Use the Silver Bullet orchestrator; parent must not implement product code inline. Create workflow evidence at the matrix evidence path. Stop when the workflow is complete."
}

verify_row_evidence() {
  local evidence_path="$1"
  if [[ -f "${WORK_DIR}/${evidence_path}" ]]; then
    return 0
  fi
  if [[ -d "${WORK_DIR}/${evidence_path}" ]]; then
    return 0
  fi
  return 1
}

verify_row_internal() {
  local row_num="$1"
  local slug="$2"
  case "$row_num" in
    21)
      grep -q 'post-exec-gates' "${WORK_DIR}/.planning/workflows/feature-currency.md" 2>/dev/null
      ;;
    22)
      grep -q 'validate-substep' "${WORK_DIR}/.planning/workflows/bugfix-health.md" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

run_matrix_row() {
  local row_num="$1"
  local slug="$2"
  local route="$3"
  local prompt_card="$4"
  local evidence_path="$5"
  local graphify_ref prompt output

  graphify_ref="$(graphify_query_ref "$slug")"
  echo "=== Row ${row_num}: ${slug} (${route}) ==="
  echo "  graphify: ${graphify_ref}"
  echo "  evidence: ${evidence_path}"

  if [[ "${SB_E2E_MATRIX_DRY_RUN:-}" == "1" ]]; then
    if verify_row_evidence "$evidence_path"; then
      echo "  DRY RUN PASS: evidence present"
      PASS_ROWS=$((PASS_ROWS + 1))
    else
      echo "  DRY RUN FAIL: missing evidence"
      FAIL_ROWS=$((FAIL_ROWS + 1))
    fi
    return 0
  fi

  if [[ "${SB_E2E_MATRIX_FORCE:-}" != "1" ]] && verify_row_evidence "$evidence_path"; then
    echo "  SKIP: evidence already present (set SB_E2E_MATRIX_FORCE=1 to re-run)"
    SKIP_ROWS=$((SKIP_ROWS + 1))
    return 0
  fi

  if command -v graphify >/dev/null 2>&1; then
    (cd "$SB_ROOT" && graphify query "${slug} routes hooks skills orchestrator" >/dev/null 2>&1) || true
  fi

  prompt="$(build_matrix_prompt "$route" "$prompt_card")"
  echo "  launching interactive Claude session..."
  output="$(run_prompt "$prompt" 2>&1 || true)"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" | tail -20
  fi

  if verify_row_evidence "$evidence_path"; then
    echo "  PASS: evidence at ${evidence_path}"
    PASS_ROWS=$((PASS_ROWS + 1))
  else
    echo "  FAIL: missing evidence at ${evidence_path}"
    FAIL_ROWS=$((FAIL_ROWS + 1))
  fi
}

main() {
  local requested=("$@")
  local row slug route prompt_card evidence_path row_num

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if [[ ! -d "$FIXTURE_DIR" ]]; then
    echo "ERROR: fixture not found at ${FIXTURE_DIR}" >&2
    exit 1
  fi

  echo "=== Enterprise E2E Matrix Runner ==="
  echo "SB_ROOT:    ${SB_ROOT}"
  echo "Fixture:    ${FIXTURE_DIR}"
  echo "Claude:     $(agent_cli_path 2>/dev/null || echo missing)"
  echo ""

  if [[ "${SB_E2E_MATRIX_DRY_RUN:-}" != "1" ]]; then
  bootstrap_claude_dependencies || true
  setup_workspace
  trap cleanup_workspace EXIT
  fi
  WORK_DIR="${WORK_DIR:-$FIXTURE_DIR}"

  for row in "${MATRIX_ROWS[@]}"; do
    IFS='|' read -r row_num slug route prompt_card evidence_path <<<"$row"
    if ! should_run_row "$row_num" "${requested[@]+"${requested[@]}"}"; then
      continue
    fi
    run_matrix_row "$row_num" "$slug" "$route" "$prompt_card" "$evidence_path"
  done

  if should_run_row 21 "${requested[@]+"${requested[@]}"}" || [[ "${#requested[@]}" -eq 0 ]]; then
    if verify_row_internal 21 silver-feature; then
      echo "=== Row 21: post-exec-gates (internal) PASS ==="
      PASS_ROWS=$((PASS_ROWS + 1))
    else
      echo "=== Row 21: post-exec-gates (internal) FAIL ==="
      FAIL_ROWS=$((FAIL_ROWS + 1))
    fi
  fi

  if should_run_row 22 "${requested[@]+"${requested[@]}"}" || [[ "${#requested[@]}" -eq 0 ]]; then
    if verify_row_internal 22 silver-bugfix; then
      echo "=== Row 22: validate-substep (internal) PASS ==="
      PASS_ROWS=$((PASS_ROWS + 1))
    else
      echo "=== Row 22: validate-substep (internal) FAIL ==="
      FAIL_ROWS=$((FAIL_ROWS + 1))
    fi
  fi

  echo ""
  echo "=== Matrix summary ==="
  echo "Pass:  ${PASS_ROWS}"
  echo "Fail:  ${FAIL_ROWS}"
  echo "Skip:  ${SKIP_ROWS}"
  echo "Total: $((PASS_ROWS + FAIL_ROWS + SKIP_ROWS)) / 22"

  if [[ "$FAIL_ROWS" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
