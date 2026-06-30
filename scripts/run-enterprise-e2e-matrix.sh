#!/usr/bin/env bash
# Run enterprise workflow matrix rows against enterprise-grade-test-app via interactive Claude TUI.
# Usage:
#   bash scripts/run-enterprise-e2e-matrix.sh              # all rows 1-20
#   bash scripts/run-enterprise-e2e-matrix.sh 1 3 5         # specific rows
#   SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh 1
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
sb_prepend_harness_path
FIXTURE_DIR="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
# shellcheck disable=SC2034  # documented matrix doc path for operators
MATRIX_DOC="${FIXTURE_DIR}/docs/WORKFLOW_E2E_MATRIX.md"

export SB_E2E_ENTERPRISE_MATRIX=1
export CLAUDE_USE_INTERACTIVE=1
# SB_E2E_MATRIX_CLEAN_ENV=1 (env -i) is opt-in for claude.ai OAuth users whose shell
# ANTHROPIC_API_KEY conflicts with stored credentials. It strips most env vars and can
# leave interactive TUI at "Not logged in" when keychain / ~/.claude/ auth is required.
# Default 0 inherits the caller's working auth (HOME, keychain, ~/.claude/).
export SB_E2E_MATRIX_CLEAN_ENV="${SB_E2E_MATRIX_CLEAN_ENV:-0}"
if [[ "${SB_E2E_MATRIX_CLEAN_ENV}" == "1" ]]; then
  # Only strip conflicting shell keys in clean-env mode.
  unset ANTHROPIC_API_KEY OPENAI_API_KEY 2>/dev/null || true
fi
export CLAUDE_MODEL="${CLAUDE_MODEL:-haiku}"
export CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"
export CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-900}"
export CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-300}"
export CLAUDE_INTERACTIVE_READY_DELAY_MS="${CLAUDE_INTERACTIVE_READY_DELAY_MS:-3000}"
export CLAUDE_INTERACTIVE_READY_TIMEOUT="${CLAUDE_INTERACTIVE_READY_TIMEOUT:-60}"
export SB_E2E_LIVE_RUNTIME=claude
export SILVER_BULLET_RUNTIME=claude

# Export ~/.claude/settings.json env for interactive TUI (api_key / proxy / token gateway).
# Enterprise matrix always exports — do not inherit SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
# from run-all-tests.sh / run-sb-live-tests-claude.sh (leaves TUI at login wall).
# OAuth-only: SB_E2E_MATRIX_OAUTH_ONLY=1 bash scripts/run-enterprise-e2e-matrix.sh
# shellcheck source=scripts/lib/claude-matrix-auth.sh
source "${SB_ROOT}/scripts/lib/claude-matrix-auth.sh"
if [[ "${SB_E2E_MATRIX_OAUTH_ONLY:-}" == "1" ]]; then
  export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
  export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-recommended}"
  unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
else
  export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
  # Arrow moves off default "No (recommended)" to "Yes" on custom API key disclaimer.
  export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-arrow}"
fi
claude_matrix_export_settings_env

# shellcheck source=scripts/lib/matrix-quota.sh
source "${SB_ROOT}/scripts/lib/matrix-quota.sh"
# shellcheck source=scripts/lib/enterprise-e2e-token-telemetry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-token-telemetry.sh"

# shellcheck source=tests/e2e-live/helpers.sh
source "${SB_ROOT}/tests/e2e-live/helpers.sh"
# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${SB_ROOT}/tests/e2e-live/lib/skill-prompt.sh"
# shellcheck source=scripts/lib/enterprise-e2e-matrix-quiesce.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-matrix-quiesce.sh"
# shellcheck source=hooks/lib/e2e-matrix-routing.sh
source "${SB_ROOT}/hooks/lib/e2e-matrix-routing.sh"

declare -a MATRIX_ROWS=(
  '1|silver-router|/silver|I need to add order validation to the API — route me.|.planning/workflows/router-session.md'
  '2|silver-research|/silver:research|Should we use Postgres or SQLite for orders?|docs/ADR-001-runtime.md'
  '3|silver-feature|/silver:feature|Add currency field to orders API + tests.|.planning/workflows/feature-currency.md'
  '4|silver-bugfix|/silver:bugfix|Health endpoint returns 500 when version is missing.|.planning/workflows/bugfix-health.md'
  '5|silver-ui|/silver:ui|Show API version in the admin UI badge.|ui/src/App.jsx'
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
ROUTING_STATE_SNAPSHOT=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [row_numbers...]

Run enterprise E2E matrix rows via interactive Claude TUI.
Fixture: ${FIXTURE_DIR}
Ledger:  ${LEDGER_FILE}

Environment:
  SB_E2E_MATRIX_DRY_RUN=1     Verify evidence only, skip Claude sessions
  SB_E2E_MATRIX_FORCE=1        Re-run rows even when evidence exists
  SB_E2E_MATRIX_CLEAN_ENV=1    Opt-in env -i for OAuth/key-conflict isolation (default 0 inherits shell)
  SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT  Skip ~/.claude/settings.json env (default 0; set 1 for OAuth-only)
  CLAUDE_INTERACTIVE_READY_TIMEOUT  Seconds to wait for prompt readiness (default 60)
  CLAUDE_MODEL                 Claude model (default haiku for matrix runs)
  CLAUDE_INTERACTIVE_QUIET_TIMEOUT  Seconds of quiet before row completes (default 300)
  SB_E2E_WORKFLOW_QUIET_TIMEOUT    Quiet window for rows 2-20 (default 60)
  CLAUDE_INTERACTIVE_READY_TIMEOUT  Seconds to wait for TUI ready before submit (default 60)
  SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL  Seconds between 429/Token Plan retries (default 60)
  SB_E2E_MATRIX_QUOTA_MAX_RETRIES     Max quota retries per row (0 = unlimited, default 0)
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
  local evidence_path="$3"
  local row_num="${4:-}"
  local slug="${5:-}"
  if [[ "$row_num" == "1" ]]; then
    # Row 1 validates interactive routing only — same scope as the direct /silver probe.
    printf '%s %s Enterprise E2E routing validation only. Route this request through the Silver Bullet orchestrator and invoke the composed workflow skill. Stop when routing completes.' \
      "$route" "$prompt_card"
    return 0
  fi
  # Native /silver:* subcommands are not registered in Claude TUI — route via /silver + workflow card.
  matrix_router_workflow_prompt "$slug" "$prompt_card" "$evidence_path"
}

claude_routing_state_file() {
  printf '%s\n' "${HOME}/.claude/.silver-bullet/state"
}

snapshot_routing_state() {
  local state_file
  state_file="$(claude_routing_state_file)"
  if [[ -f "$state_file" ]]; then
    ROUTING_STATE_SNAPSHOT="$(cat "$state_file")"
  else
    ROUTING_STATE_SNAPSHOT=""
  fi
}

verify_row_routing_state_delta() {
  local state_file new_skills
  state_file="$(claude_routing_state_file)"
  [[ -f "$state_file" ]] || return 1
  new_skills="$(comm -13 \
    <(printf '%s\n' "$ROUTING_STATE_SNAPSHOT" | sed '/^$/d' | sort -u) \
    <(sed '/^$/d' "$state_file" | sort -u) 2>/dev/null || true)"
  [[ -n "$new_skills" ]] || return 1
  printf '%s\n' "$new_skills" | grep -qE '^(silver-feature|silver-fast|silver-clarify|silver-context|silver-quality-gates)$'
}

verify_row_routing_state_present() {
  local state_file
  state_file="$(claude_routing_state_file)"
  [[ -f "$state_file" ]] || return 1
  grep -qE '^(silver-feature|silver-fast|silver-clarify|silver-context|silver-quality-gates)$' "$state_file"
}

verify_row_routing_output() {
  local output="$1"
  printf '%s\n' "$output" | grep -qE 'SILVER BULLET.*ROUTING|Skill\(silver-bullet:silver-(feature|fast|clarify|context|quality-gates)'
}

verify_row_success() {
  local row_num="$1"
  local evidence_path="$2"
  local output="${3:-}"
  local row_log="${4:-}"
  if verify_row_evidence "$evidence_path"; then
    return 0
  fi
  if [[ "$row_num" == "1" ]]; then
    if verify_row_routing_state_delta; then
      return 0
    fi
    if verify_row_routing_state_present; then
      return 0
    fi
    if [[ -n "$output" ]] && verify_row_routing_output "$output"; then
      return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && verify_row_routing_output "$(tail -c 2500000 "$row_log" 2>/dev/null || true)"; then
      return 0
    fi
  fi
  return 1
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

  local row_telemetry_result="fail"

  graphify_ref="$(graphify_query_ref "$slug")"
  echo "=== Row ${row_num}: ${slug} (${route}) ==="
  echo "  graphify: ${graphify_ref}"
  echo "  evidence: ${evidence_path}"

  if [[ "${SB_E2E_MATRIX_DRY_RUN:-}" == "1" ]]; then
    if verify_row_evidence "$evidence_path"; then
      echo "  DRY RUN PASS: evidence present"
      PASS_ROWS=$((PASS_ROWS + 1))
      row_telemetry_result="pass"
    else
      echo "  DRY RUN FAIL: missing evidence"
      FAIL_ROWS=$((FAIL_ROWS + 1))
    fi
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
      SB_E2E_TELEMETRY_ROW_LOG="" \
      enterprise_e2e_telemetry_append "matrix_row_dry_run" || true
    return 0
  fi

  if [[ "${SB_E2E_MATRIX_FORCE:-}" != "1" ]] && verify_row_success "$row_num" "$evidence_path"; then
    echo "  SKIP: evidence already present (set SB_E2E_MATRIX_FORCE=1 to re-run)"
    SKIP_ROWS=$((SKIP_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="skip" \
      SB_E2E_TELEMETRY_ROW_LOG="${SB_ROOT}/.e2e-row${row_num}-attempt.log" \
      enterprise_e2e_telemetry_append "matrix_row_skip" || true
    return 0
  fi

  if [[ "$row_num" == "1" ]]; then
    snapshot_routing_state
    enterprise_e2e_matrix_quiesce_orchestrator_queue "$SB_ROOT"
    sb_e2e_matrix_set_routing_row_marker
  fi

  matrix_quiesce_active_workflows

  if command -v graphify >/dev/null 2>&1; then
    (cd "$SB_ROOT" && graphify query "${slug} routes hooks skills orchestrator" >/dev/null 2>&1) || true
  fi

  prompt="$(build_matrix_prompt "$route" "$prompt_card" "$evidence_path" "$row_num" "$slug")"
  local quiet_timeout="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-300}"
  if [[ "$row_num" == "1" ]]; then
    quiet_timeout="${SB_E2E_ROW1_QUIET_TIMEOUT:-300}"
  elif [[ "$row_num" =~ ^[0-9]+$ && "$row_num" -ge 2 && "$row_num" -le 20 ]]; then
    # Full workflow rows need a wider quiet window than routing-only row 1.
    # Claude may return to the ❯ prompt between turns while still writing evidence.
    quiet_timeout="${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-600}"
  fi
  local quota_retry_interval="${SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-60}"
  local quota_max_retries="${SB_E2E_MATRIX_QUOTA_MAX_RETRIES:-0}"
  local attempt=0 quota_retries=0 row_log output routing_row_env="0"
  if [[ "$row_num" == "1" ]]; then
    routing_row_env="1"
  fi

  while true; do
    attempt=$((attempt + 1))
    row_log="${SB_ROOT}/.e2e-row${row_num}-attempt${attempt}.log"
    if [[ "$attempt" -eq 1 ]]; then
      # Back-compat symlink path for operators tailing .e2e-rowN-attempt.log
      row_log="${SB_ROOT}/.e2e-row${row_num}-attempt.log"
    fi
    if [[ "$attempt" -gt 1 ]]; then
      echo "  retry attempt ${attempt} (quota retry #${quota_retries})..."
    else
      echo "  launching interactive Claude session..."
    fi
    : >"$row_log"
    output="$(
      CLAUDE_INTERACTIVE_QUIET_TIMEOUT="$quiet_timeout" \
        CLAUDE_INTERACTIVE_LOG_FILE="$row_log" \
        SB_E2E_MATRIX_EVIDENCE_PATH="$evidence_path" \
        SB_E2E_ENTERPRISE_MATRIX=1 \
        SB_E2E_MATRIX_ROUTING_ROW="$routing_row_env" \
        run_prompt "$prompt" 2>&1 || true
    )"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" | tail -20
    fi

    if verify_row_success "$row_num" "$evidence_path" "$output" "$row_log"; then
      if [[ "$row_num" == "1" ]] && ! verify_row_evidence "$evidence_path"; then
        matrix_write_router_session_evidence "$evidence_path"
      fi
      if verify_row_evidence "$evidence_path"; then
        echo "  PASS: evidence at ${evidence_path}"
      elif [[ "$row_num" == "1" ]] && verify_row_routing_state_delta; then
        echo "  PASS: routing skill recorded in $(claude_routing_state_file) (row 1 routing-only criterion)"
      elif [[ "$row_num" == "1" ]] && verify_row_routing_output "$output"; then
        echo "  PASS: routing markers in session output (row 1 routing-only criterion)"
      fi
      if [[ "$row_num" == "1" ]]; then
        sb_e2e_matrix_clear_routing_row_marker
        enterprise_e2e_matrix_quiesce_orchestrator_queue "$SB_ROOT"
      fi
      if [[ "$quota_retries" -gt 0 ]]; then
        echo "  PASS: succeeded after ${quota_retries} quota retry(ies)"
      fi
      if [[ -f "${SB_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh" ]]; then
        # shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
        source "${SB_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"
        local outcome_dir="${WORK_DIR}/.planning/enterprise-e2e/outcomes"
        mkdir -p "$outcome_dir"
        enterprise_e2e_outcome_write_workflow_checklist "$row_num" \
          "${outcome_dir}/row-${row_num}-outcomes.md" \
          "$WORK_DIR" "${SB_RUNTIME_STATE_DIR:-${HOME}/.claude/.silver-bullet}" \
          "$row_log" "${SB_E2E_LEDGER_FILE:-}" "$evidence_path" 2>/dev/null || true
        echo "  OUTCOMES: checklist at .planning/enterprise-e2e/outcomes/row-${row_num}-outcomes.md"
        if ! enterprise_e2e_outcome_row_passes "$row_num" "$WORK_DIR" \
          "${SB_RUNTIME_STATE_DIR:-${HOME}/.claude/.silver-bullet}" \
          "$row_log" "${SB_E2E_LEDGER_FILE:-}" "$evidence_path"; then
          echo "  FAIL: outcome assessment — mandatory criteria not all pass (evidence alone insufficient)"
          local fail_line
          while IFS= read -r fail_line; do
            [[ -z "$fail_line" ]] && continue
            echo "    OUTCOME-FAIL: $fail_line"
          done < <(enterprise_e2e_outcome_row_failures "$row_num" "$WORK_DIR" \
            "${SB_RUNTIME_STATE_DIR:-${HOME}/.claude/.silver-bullet}" \
            "$row_log" "${SB_E2E_LEDGER_FILE:-}" "$evidence_path")
          FAIL_ROWS=$((FAIL_ROWS + 1))
          row_telemetry_result="fail"
          SB_E2E_TELEMETRY_ROW="$row_num" \
            SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
            SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
            SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
            enterprise_e2e_telemetry_append "matrix_row" || true
          break
        fi
        echo "  OUTCOMES: all applicable criteria pass (OUT-WORLD-01 composite)"
      fi
      PASS_ROWS=$((PASS_ROWS + 1))
      row_telemetry_result="pass"
      SB_E2E_TELEMETRY_ROW="$row_num" \
        SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
        SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
        SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
        enterprise_e2e_telemetry_append "matrix_row" || true
      break
    fi

    if is_quota_failure "$output" "$row_log"; then
      quota_retries=$((quota_retries + 1))
      if [[ "$quota_max_retries" -gt 0 && "$quota_retries" -gt "$quota_max_retries" ]]; then
        echo "  FAIL: quota retries exhausted (${quota_max_retries}) — missing evidence at ${evidence_path}"
        FAIL_ROWS=$((FAIL_ROWS + 1))
        SB_E2E_TELEMETRY_ROW="$row_num" \
          SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
          SB_E2E_TELEMETRY_ROW_RESULT="fail" \
          SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
          enterprise_e2e_telemetry_append "matrix_row" || true
        break
      fi
      echo "  QUOTA: API 429 / Token Plan limit — waiting ${quota_retry_interval}s before retry ${quota_retries}..."
      sleep "$quota_retry_interval"
      continue
    fi

    echo "  FAIL: missing evidence at ${evidence_path}"
    if [[ "$row_num" == "1" ]]; then
      echo "  FAIL: no routing markers in session output or $(claude_routing_state_file)"
      sb_e2e_matrix_clear_routing_row_marker
      enterprise_e2e_matrix_quiesce_orchestrator_queue "$SB_ROOT"
    fi
    FAIL_ROWS=$((FAIL_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="fail" \
      SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
      enterprise_e2e_telemetry_append "matrix_row" || true
    break
  done
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
  enterprise_e2e_matrix_quiesce_orchestrator_queue "$SB_ROOT"
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
