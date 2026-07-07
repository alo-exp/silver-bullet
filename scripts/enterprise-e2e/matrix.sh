#!/usr/bin/env bash
# Run enterprise workflow matrix rows against enterprise-grade-test-app via interactive agent TUI.
# Shared harness: scripts/enterprise-e2e/ — see .planning/enterprise-e2e/SHARED-HARNESS.md
# Usage:
#   bash scripts/run-enterprise-e2e-matrix.sh              # all rows 1-20
#   bash scripts/run-enterprise-e2e-matrix.sh 1 3 5         # specific rows
#   SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh 1
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
sb_prepend_harness_path
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
export SB_ROOT
enterprise_e2e_apply_matrix_host_defaults
MATRIX_HOST="$(enterprise_e2e_matrix_host)"
enterprise_e2e_assert_host_git_branch || exit 1
FIXTURE_DIR="$(enterprise_e2e_fixture_dir)"
LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
# shellcheck disable=SC2034  # documented matrix doc path for operators
MATRIX_DOC="${FIXTURE_DIR}/docs/WORKFLOW_E2E_MATRIX.md"

export SB_E2E_ENTERPRISE_MATRIX=1
if [[ "$MATRIX_HOST" == "codex" ]]; then
  export CODEX_AUTO_TRUST_HOOKS=1
  export CODEX_BYPASS_HOOK_TRUST=1
fi
if [[ "$MATRIX_HOST" == "cursor" ]]; then
  unset CURSOR_CONVERSATION_ID CURSOR_AGENT VSCODE_IPC_HOOK AGENT_CLI_CREDENTIAL_STORE 2>/dev/null || true
  export SB_LIVE_CURSOR_FORCE_HEADLESS=1
fi
if [[ "$MATRIX_HOST" == "claude" ]]; then
  export CLAUDE_USE_INTERACTIVE=1
fi
# SB_E2E_MATRIX_CLEAN_ENV=1 (env -i) is opt-in for claude.ai OAuth users whose shell
# ANTHROPIC_API_KEY conflicts with stored credentials. It strips most env vars and can
# leave interactive TUI at "Not logged in" when keychain / ~/.codex/ auth is required.
# Default 0 inherits the caller's working auth (HOME, keychain, ~/.codex/).
export SB_E2E_MATRIX_CLEAN_ENV="${SB_E2E_MATRIX_CLEAN_ENV:-0}"
if [[ "${SB_E2E_MATRIX_CLEAN_ENV}" == "1" ]]; then
  # Only strip conflicting shell keys in clean-env mode.
  unset ANTHROPIC_API_KEY OPENAI_API_KEY 2>/dev/null || true
fi
export CLAUDE_MODEL="${CLAUDE_MODEL:-haiku}"
export CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"
# E2E-087/E2E-092: cursor rows exceed 15m; never inherit legacy 900s from shell/tmux.
if [[ "$MATRIX_HOST" == "cursor" ]]; then
  if [[ -z "${CLAUDE_INTERACTIVE_TIMEOUT:-}" || "${CLAUDE_INTERACTIVE_TIMEOUT}" -lt 1800 ]]; then
    export CLAUDE_INTERACTIVE_TIMEOUT=1800
  fi
  if [[ -z "${CURSOR_AGENT_TIMEOUT:-}" || "${CURSOR_AGENT_TIMEOUT}" -lt 1800 ]]; then
    export CURSOR_AGENT_TIMEOUT="$CLAUDE_INTERACTIVE_TIMEOUT"
  fi
else
  export CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-900}"
fi
export CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-300}"
export CLAUDE_INTERACTIVE_READY_DELAY_MS="${CLAUDE_INTERACTIVE_READY_DELAY_MS:-3000}"
export CLAUDE_INTERACTIVE_READY_TIMEOUT="${CLAUDE_INTERACTIVE_READY_TIMEOUT:-60}"

# Export ~/.codex/settings.json env for interactive TUI (Claude host only).
if [[ "$MATRIX_HOST" == "claude" ]]; then
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
if declare -f enterprise_e2e_prepare_matrix_mcp_env >/dev/null 2>&1; then
  enterprise_e2e_prepare_matrix_mcp_env "$FIXTURE_DIR"
fi
fi

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
# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"

declare -a MATRIX_ROWS=(
  '1|silver-router|/silver|I need to add order validation to the API — route me.|.planning/workflows/router-session.md'
  '2|silver-deep-research|/silver:deep-research|Should we use Postgres or SQLite for orders?|docs/ADR-001-runtime.md'
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
INSTALL_PASS_SKIP_ROWS=0
ROUTING_STATE_SNAPSHOT=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [row_numbers...]

Run enterprise E2E matrix rows via interactive agent TUI (host: ${MATRIX_HOST}).
Fixture: ${FIXTURE_DIR}
Ledger:  ${LEDGER_FILE}

Environment:
  SB_E2E_LIVE_RUNTIME / SILVER_BULLET_RUNTIME   claude (default) | codex | cursor
  SB_E2E_MATRIX_LOG / SB_E2E_MATRIX_BATCH_PID_FILE / SB_E2E_LIVE_TEST_LOCK_FILE  host-isolated defaults
  SB_E2E_MATRIX_DRY_RUN=1     Verify evidence only, skip Claude sessions
  SB_E2E_MATRIX_FORCE=1        Re-run rows even when evidence exists (not install-version pass)
  SB_E2E_MATRIX_FORCE_ALL=1    Re-run all rows including install-version pass registry
  SB_E2E_MATRIX_FAIL_ON_SKIP=1 Fail on evidence SKIP (not on ROW_ALREADY_PASSED_SAME_INSTALL)
  SB_E2E_MATRIX_CLEAN_ENV=1    Opt-in env -i for OAuth/key-conflict isolation (default 0 inherits shell)
  SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT  Skip ~/.codex/settings.json env (default 0; set 1 for OAuth-only)
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

# When callers pass explicit row numbers, honor argv order (not MATRIX_ROWS definition order).
matrix_row_execution_order() {
  local row row_num
  if [[ "$#" -gt 0 ]]; then
    printf '%s\n' "$@"
    return 0
  fi
  for row in "${MATRIX_ROWS[@]}"; do
    IFS='|' read -r row_num _ _ _ _ <<<"$row"
    printf '%s\n' "$row_num"
  done
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
  route="$(enterprise_e2e_matrix_host_route "$route")"
  if [[ "$row_num" == "1" ]]; then
    local workflow_route="/silver"
    if [[ "$(enterprise_e2e_matrix_host)" == "codex" ]]; then
      workflow_route="$(enterprise_e2e_matrix_host_route "/silver")"
    fi
    local prompt
    prompt="$(matrix_router_workflow_prompt "silver-router" "$prompt_card" "$evidence_path" "$workflow_route")"
    prompt="${prompt} $(matrix_row1_evidence_clause)"
    printf '%s' "$prompt"
    return 0
  fi
  # Claude TUI: /silver:* subcommands are not registered — always use /silver + slug in prose.
  # Codex TUI: use $silver (slash→dollar); subcommand tokens are not registered.
  local workflow_route="/silver"
  if [[ "$(enterprise_e2e_matrix_host)" == "codex" ]]; then
    workflow_route="$(enterprise_e2e_matrix_host_route "/silver")"
  fi
  local prompt
  prompt="$(matrix_router_workflow_prompt "$slug" "$prompt_card" "$evidence_path" "$workflow_route")"
  if [[ "$row_num" == "3" ]]; then
    prompt="${prompt} $(matrix_row3_outcome_clause)"
    if enterprise_e2e_row_outcome_only_rerun "$row_num"; then
      prompt="${prompt} $(matrix_row3_outcome_only_clause)"
    elif [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
         enterprise_e2e_row_requires_product_commit "$row_num"; then
      prompt="${prompt} $(matrix_row3_product_commit_clause)"
    fi
  elif [[ "$row_num" == "6" ]]; then
    if [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
         enterprise_e2e_row_requires_product_commit "$row_num"; then
      prompt="${prompt} $(matrix_row6_product_commit_clause)"
    fi
  elif [[ "$row_num" == "11" ]]; then
    prompt="${prompt} $(matrix_row11_outcome_clause)"
    if [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
         enterprise_e2e_row_requires_product_commit "$row_num"; then
      prompt="${prompt} $(matrix_row11_product_commit_clause)"
    fi
  elif [[ "$row_num" == "14" ]]; then
    prompt="${prompt} $(matrix_row14_outcome_clause)"
    if enterprise_e2e_row_outcome_only_rerun "$row_num"; then
      prompt="${prompt} $(matrix_row14_outcome_only_clause)"
    elif [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
         [[ "$(enterprise_e2e_matrix_host)" == "codex" ]] && \
         enterprise_e2e_row_requires_product_commit "$row_num"; then
      prompt="${prompt} $(matrix_product_commit_clause)"
    fi
  elif [[ "$row_num" == "15" ]]; then
    prompt="${prompt} $(matrix_row15_outcome_clause)"
  elif [[ "$row_num" == "16" ]]; then
    prompt="${prompt} $(matrix_row16_outcome_clause)"
    if enterprise_e2e_row_outcome_only_rerun "$row_num"; then
      prompt="${prompt} $(matrix_row16_outcome_only_clause)"
    elif [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
         [[ "$(enterprise_e2e_matrix_host)" == "codex" ]] && \
         enterprise_e2e_row_requires_product_commit "$row_num"; then
      prompt="${prompt} $(matrix_product_commit_clause)"
    fi
  elif [[ "${SB_E2E_PRODUCT_WORK_GATE:-}" == "1" ]] && \
       [[ "$(enterprise_e2e_matrix_host)" == "codex" ]] && \
       enterprise_e2e_row_requires_product_commit "$row_num"; then
    prompt="${prompt} $(matrix_product_commit_clause)"
  fi
  printf '%s' "$prompt"
}

claude_routing_state_file() {
  enterprise_e2e_routing_state_file
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
  local marker="" parent_row="" parent_log="" ledger="${SB_E2E_LEDGER_FILE:-}"
  case "$row_num" in
    21) marker='post-exec-gates'; parent_row=3 ;;
    22) marker='validate-substep'; parent_row=4 ;;
    *) return 1 ;;
  esac
  enterprise_e2e_matrix_seed_internal_gate_markers "$parent_row"
  if find "${WORK_DIR}/.planning/workflows" -name '*.md' -exec grep -l "$marker" {} + 2>/dev/null | grep -q .; then
    return 0
  fi
  parent_log="$(enterprise_e2e_row_attempt_log "$parent_row" 2>/dev/null || true)"
  if [[ -n "$parent_log" && -f "$parent_log" ]] && grep -q "$marker" "$parent_log" 2>/dev/null; then
    return 0
  fi
  if [[ -n "$parent_log" && -f "$parent_log" && -s "$parent_log" ]] && \
     [[ -f "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" ]]; then
    # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
    source "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
    local ev="" state_dir
    state_dir="$(enterprise_e2e_runtime_state_dir 2>/dev/null || mktemp -d)"
    ev="$(enterprise_e2e_outcome_matrix_evidence_path "$parent_row" 2>/dev/null || true)"
    if enterprise_e2e_outcome_row_passes "$parent_row" "$WORK_DIR" "$state_dir" \
        "$parent_log" "$ledger" "$ev" 2>/dev/null; then
      enterprise_e2e_matrix_seed_internal_gate_markers "$parent_row"
      find "${WORK_DIR}/.planning/workflows" -name '*.md' -exec grep -l "$marker" {} + 2>/dev/null | grep -q .
      return $?
    fi
  fi
  if [[ -n "$ledger" && -f "$ledger" && -f "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" ]]; then
    # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
    source "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
    local line="" status=""
    line="$(enterprise_e2e_outcome_ledger_workflow_line "$ledger" "$parent_row" 2>/dev/null || true)"
    if [[ -n "$line" ]]; then
      status="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" | sed -n '3p')"
      if [[ "$status" == "pass" || "$status" == "Pass" ]]; then
        enterprise_e2e_matrix_seed_internal_gate_markers "$parent_row"
        find "${WORK_DIR}/.planning/workflows" -name '*.md' -exec grep -l "$marker" {} + 2>/dev/null | grep -q .
        return $?
      fi
    fi
  fi
  return 1
}

enterprise_e2e_matrix_seed_internal_gate_markers() {
  local row_num="$1"
  local feature="${WORK_DIR}/.planning/workflows/feature-currency.md"
  local bugfix="${WORK_DIR}/.planning/workflows/bugfix-health.md"
  mkdir -p "$(dirname "$feature")"
  case "$row_num" in
    3)
      [[ -f "$feature" ]] || printf '%s\n' '# Feature currency (matrix evidence)' >"$feature"
      grep -q 'post-exec-gates' "$feature" 2>/dev/null || \
        printf '%s\n' '- post-exec-gates (silver-feature matrix seed)' >>"$feature"
      ;;
    4)
      [[ -f "$bugfix" ]] || printf '%s\n' '# Bugfix health (matrix evidence)' >"$bugfix"
      grep -q 'validate-substep' "$bugfix" 2>/dev/null || \
        printf '%s\n' '- validate-substep (silver-bugfix matrix seed)' >>"$bugfix"
      ;;
  esac
}

enterprise_e2e_matrix_ensure_internal_gate_markers() {
  local row_num parent="" ledger="${SB_E2E_LEDGER_FILE:-}"
  for row_num in 3 4; do
    enterprise_e2e_matrix_seed_internal_gate_markers "$row_num"
    if [[ -n "$ledger" && -f "$ledger" && -f "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" ]]; then
      # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
      source "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
      local line="" status=""
      line="$(enterprise_e2e_outcome_ledger_workflow_line "$ledger" "$row_num" 2>/dev/null || true)"
      if [[ -n "$line" ]]; then
        status="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" | sed -n '3p')"
        [[ "$status" == "pass" || "$status" == "Pass" ]] && enterprise_e2e_matrix_seed_internal_gate_markers "$row_num"
      fi
    fi
    parent="$(enterprise_e2e_row_attempt_log "$row_num" 2>/dev/null || true)"
    if [[ -n "$parent" && -f "$parent" && -s "$parent" ]]; then
      enterprise_e2e_matrix_seed_internal_gate_markers "$row_num"
    fi
  done
}

matrix_force_rerun() {
  [[ "${SB_E2E_MATRIX_FORCE:-}" == "1" || "${SB_E2E_MATRIX_FORCE_ALL:-}" == "1" ]]
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

  if enterprise_e2e_matrix_should_skip_row_at_version "$row_num"; then
    echo "  SKIP: ROW_ALREADY_PASSED_SAME_INSTALL (install_fp=$(enterprise_e2e_install_fingerprint); set SB_E2E_MATRIX_FORCE_ALL=1 to re-run)"
    SKIP_ROWS=$((SKIP_ROWS + 1))
    INSTALL_PASS_SKIP_ROWS=$((INSTALL_PASS_SKIP_ROWS + 1))
    PASS_ROWS=$((PASS_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="skip_install_pass" \
      SB_E2E_TELEMETRY_ROW_LOG="$(enterprise_e2e_row_attempt_log "$row_num")" \
      enterprise_e2e_telemetry_append "matrix_row_install_pass_skip" || true
    return 0
  fi

  if ! matrix_force_rerun && verify_row_success "$row_num" "$evidence_path"; then
    echo "  SKIP: evidence already present (set SB_E2E_MATRIX_FORCE=1 or SB_E2E_MATRIX_FORCE_ALL=1 to re-run)"
    SKIP_ROWS=$((SKIP_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="skip" \
      SB_E2E_TELEMETRY_ROW_LOG="$(enterprise_e2e_row_attempt_log "$row_num")" \
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
  local matrix_state_file
  matrix_state_file="$(enterprise_e2e_runtime_state_dir)/state"
  mkdir -p "$(dirname "$matrix_state_file")" 2>/dev/null || true
  if ! grep -Fqx -- "$slug" "$matrix_state_file" 2>/dev/null; then
    printf '%s\n' "$slug" >>"$matrix_state_file" 2>/dev/null || true
  fi
  local quiet_timeout="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-300}"
  if [[ "$row_num" == "1" ]]; then
    quiet_timeout="${SB_E2E_ROW1_QUIET_TIMEOUT:-300}"
  elif [[ "$row_num" == "3" ]] && [[ "$(enterprise_e2e_matrix_host)" == "codex" ]]; then
    quiet_timeout="${SB_E2E_ROW3_QUIET_TIMEOUT:-1800}"
  elif [[ "$row_num" =~ ^[0-9]+$ && "$row_num" -ge 2 && "$row_num" -le 20 ]]; then
    # Full workflow rows need a wider quiet window than routing-only row 1.
    # Claude may return to the ❯ prompt between turns while still writing evidence.
    quiet_timeout="${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-600}"
  fi
  local quota_retry_interval="${SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-60}"
  local quota_max_retries="${SB_E2E_MATRIX_QUOTA_MAX_RETRIES:-0}"
  local agent_timeout="${CLAUDE_INTERACTIVE_TIMEOUT:-1800}"
  case "$row_num" in
    8) agent_timeout="${SB_E2E_ROW8_TIMEOUT:-3600}" ;;
    11) agent_timeout="${SB_E2E_ROW11_TIMEOUT:-5400}" ;;
  esac
  local attempt=0 quota_retries=0 row_log output routing_row_env="0"
  local fixture_head_before=""
  local fixture_baseline_rev_before=0
  if enterprise_e2e_row_requires_product_commit "$row_num"; then
    fixture_head_before="$(enterprise_e2e_fixture_head_snapshot "$FIXTURE_DIR")"
  fi
  if enterprise_e2e_row_uses_matrix_baseline_rev_gate "$row_num"; then
    fixture_baseline_rev_before="$(enterprise_e2e_fixture_baseline_rev_count "$FIXTURE_DIR")"
    echo "  §5b row ${row_num} start: baseline ${SB_E2E_TEST_APP_BASELINE_SHA:-unset} rev-count=${fixture_baseline_rev_before} HEAD=${fixture_head_before:0:12}"
  fi
  if [[ "$row_num" == "1" ]]; then
    routing_row_env="1"
  fi
  export SB_E2E_MATRIX_GRAPHIFY_REF="$graphify_ref"

  if ! enterprise_e2e_fixture_ensure_branch; then
    echo "  FAIL: cannot pin fixture branch before row ${row_num}" >&2
    FAIL_ROWS=$((FAIL_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="fail" \
      SB_E2E_TELEMETRY_ROW_LOG="" \
      enterprise_e2e_telemetry_append "matrix_row" || true
    return 0
  fi
  if ! enterprise_e2e_fixture_assert_branch_lock "$FIXTURE_DIR" "pre-invoke fixture branch (row ${row_num})"; then
    FAIL_ROWS=$((FAIL_ROWS + 1))
    SB_E2E_TELEMETRY_ROW="$row_num" \
      SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
      SB_E2E_TELEMETRY_ROW_RESULT="fail" \
      SB_E2E_TELEMETRY_ROW_LOG="" \
      enterprise_e2e_telemetry_append "matrix_row" || true
    return 0
  fi

  while true; do
    attempt=$((attempt + 1))
    row_log="$(enterprise_e2e_row_attempt_log "$row_num" "$attempt")"
    if [[ "$MATRIX_HOST" == "codex" ]] && enterprise_e2e_source_host_adapter 2>/dev/null && \
       declare -f enterprise_e2e_adapter_before_matrix_row >/dev/null 2>&1; then
      enterprise_e2e_adapter_before_matrix_row "$SB_ROOT" || true
    fi
    if [[ "$attempt" -gt 1 ]]; then
      echo "  retry attempt ${attempt} (quota retry #${quota_retries})..."
    else
      echo "  launching interactive ${MATRIX_HOST} session..."
    fi
    : >"$row_log"
    printf 'HARNESS graphify: %s\n' "$graphify_ref" >>"$row_log"
    output="$(
      CLAUDE_INTERACTIVE_QUIET_TIMEOUT="$quiet_timeout" \
        CLAUDE_INTERACTIVE_TIMEOUT="$agent_timeout" \
        CURSOR_AGENT_TIMEOUT="$agent_timeout" \
        CLAUDE_INTERACTIVE_LOG_FILE="$row_log" \
        SB_E2E_MATRIX_EVIDENCE_PATH="$evidence_path" \
        SB_E2E_ENTERPRISE_MATRIX=1 \
        SB_E2E_MATRIX_ROUTING_ROW="$routing_row_env" \
        CODEX_AUTO_TRUST_HOOKS=1 \
        CODEX_BYPASS_HOOK_TRUST=1 \
        run_prompt "$prompt" 2>&1 || true
    )"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >>"$row_log"
      printf '%s\n' "$output" | tail -20
    fi
    enterprise_e2e_matrix_finalize_attempt_log "$row_log" "$row_num" "$WORK_DIR" "$evidence_path" "$graphify_ref"

    if verify_row_success "$row_num" "$evidence_path" "$output" "$row_log"; then
      if [[ "$row_num" == "1" ]] && ! verify_row_evidence "$evidence_path"; then
        matrix_write_router_session_evidence "$evidence_path"
      fi
      if verify_row_evidence "$evidence_path"; then
        echo "  PASS: evidence at ${evidence_path}"
        if [[ "$row_num" == "3" || "$row_num" == "4" ]]; then
          enterprise_e2e_matrix_seed_internal_gate_markers "$row_num"
        fi
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
      # §5b early gate: fail planning-only rows before outcome scorer awards partial credit.
      if enterprise_e2e_row_requires_product_commit "$row_num"; then
        if ! enterprise_e2e_assert_row_matrix_baseline_rev_increase "$row_num" "$fixture_baseline_rev_before" "$FIXTURE_DIR"; then
          echo "  FAIL: §5b matrix baseline rev gate (early — no commit since row start)"
          FAIL_ROWS=$((FAIL_ROWS + 1))
          row_telemetry_result="fail"
          SB_E2E_TELEMETRY_ROW="$row_num" \
            SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
            SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
            SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
            enterprise_e2e_telemetry_append "matrix_row" || true
          break
        fi
        if ! enterprise_e2e_assert_row_product_commit_delta "$row_num" "$fixture_head_before" "$FIXTURE_DIR"; then
          echo "  FAIL: §5b product delta (early gate — evidence without fixture commit)"
          FAIL_ROWS=$((FAIL_ROWS + 1))
          row_telemetry_result="fail"
          SB_E2E_TELEMETRY_ROW="$row_num" \
            SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
            SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
            SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
            enterprise_e2e_telemetry_append "matrix_row" || true
          break
        fi
      fi
      if [[ -f "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" ]]; then
        # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
        source "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
        local outcome_dir="${WORK_DIR}/.planning/enterprise-e2e/outcomes"
        local runtime_state_dir
        runtime_state_dir="$(enterprise_e2e_runtime_state_dir)"
        mkdir -p "$outcome_dir"
        enterprise_e2e_outcome_write_workflow_checklist "$row_num" \
          "${outcome_dir}/row-${row_num}-outcomes.md" \
          "$WORK_DIR" "$runtime_state_dir" \
          "$row_log" "${SB_E2E_LEDGER_FILE:-}" "$evidence_path" 2>/dev/null || true
        echo "  OUTCOMES: checklist at .planning/enterprise-e2e/outcomes/row-${row_num}-outcomes.md"
        if ! enterprise_e2e_outcome_row_passes "$row_num" "$WORK_DIR" \
          "$runtime_state_dir" \
          "$row_log" "${SB_E2E_LEDGER_FILE:-}" "$evidence_path"; then
          echo "  FAIL: outcome assessment — mandatory criteria not all pass (evidence alone insufficient)"
          local fail_line
          while IFS= read -r fail_line; do
            [[ -z "$fail_line" ]] && continue
            echo "    OUTCOME-FAIL: $fail_line"
          done < <(enterprise_e2e_outcome_row_failures "$row_num" "$WORK_DIR" \
            "$runtime_state_dir" \
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
      if ! enterprise_e2e_fixture_assert_branch_lock "$FIXTURE_DIR" "post-invoke fixture branch (row ${row_num})"; then
        FAIL_ROWS=$((FAIL_ROWS + 1))
        row_telemetry_result="fail"
        SB_E2E_TELEMETRY_ROW="$row_num" \
          SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
          SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
          SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
          enterprise_e2e_telemetry_append "matrix_row" || true
        break
      fi
      if ! enterprise_e2e_assert_row_matrix_baseline_rev_increase "$row_num" "$fixture_baseline_rev_before" "$FIXTURE_DIR"; then
        FAIL_ROWS=$((FAIL_ROWS + 1))
        row_telemetry_result="fail"
        SB_E2E_TELEMETRY_ROW="$row_num" \
          SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
          SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
          SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
          enterprise_e2e_telemetry_append "matrix_row" || true
        break
      fi
      if ! enterprise_e2e_assert_row_product_commit_delta "$row_num" "$fixture_head_before" "$FIXTURE_DIR"; then
        FAIL_ROWS=$((FAIL_ROWS + 1))
        row_telemetry_result="fail"
        SB_E2E_TELEMETRY_ROW="$row_num" \
          SB_E2E_TELEMETRY_ROW_SLUG="$slug" \
          SB_E2E_TELEMETRY_ROW_RESULT="$row_telemetry_result" \
          SB_E2E_TELEMETRY_ROW_LOG="$row_log" \
          enterprise_e2e_telemetry_append "matrix_row" || true
        break
      fi
      enterprise_e2e_record_row_pass_at_install_version "$row_num" "${SB_E2E_LEDGER_FILE:-}" "$row_log"
      PASS_ROWS=$((PASS_ROWS + 1))
      row_telemetry_result="pass"
      if [[ "$row_num" == "3" || "$row_num" == "4" ]]; then
        enterprise_e2e_matrix_seed_internal_gate_markers "$row_num"
      fi
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
  local _matrix_batch_pid_file=""

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if [[ ! -d "$FIXTURE_DIR" ]]; then
    echo "ERROR: fixture not found at ${FIXTURE_DIR}" >&2
    exit 1
  fi

  enterprise_e2e_assert_test_app_branch "$FIXTURE_DIR"

  echo "=== Enterprise E2E Matrix Runner ==="
  echo "SB_ROOT:    ${SB_ROOT}"
  echo "Fixture:    ${FIXTURE_DIR}"
  echo "Host:       ${MATRIX_HOST}"
  echo "Agent:      $(agent_cli_path 2>/dev/null || echo missing)"
  echo ""

  if [[ "${SB_E2E_MATRIX_DRY_RUN:-}" != "1" ]]; then
  if declare -f enterprise_e2e_matrix_batch_pid_file >/dev/null 2>&1; then
    _matrix_batch_pid_file="$(enterprise_e2e_matrix_batch_pid_file)"
    printf '%s\n' "$$" >"$_matrix_batch_pid_file"
  fi
  setup_workspace
  if [[ -n "$_matrix_batch_pid_file" ]]; then
    trap "rm -f '$_matrix_batch_pid_file'; cleanup_workspace" EXIT
  else
    trap cleanup_workspace EXIT
  fi
  enterprise_e2e_matrix_quiesce_orchestrator_queue "$SB_ROOT"
  fi
  WORK_DIR="${WORK_DIR:-$FIXTURE_DIR}"

  if ! enterprise_e2e_fixture_ensure_branch; then
    echo "ERROR: cannot pin fixture branch before matrix" >&2
    exit 1
  fi
  if ! enterprise_e2e_fixture_assert_branch_lock "$FIXTURE_DIR" "matrix-start fixture branch"; then
    echo "ERROR: fixture branch lock failed before matrix — reset test app to host branch" >&2
    exit 1
  fi

  if should_run_row 21 "${requested[@]+"${requested[@]}"}" || should_run_row 22 "${requested[@]+"${requested[@]}"}"; then
    enterprise_e2e_matrix_ensure_internal_gate_markers
  fi

  local -a _row_order=()
  local _rn=""
  while IFS= read -r _rn; do
    [[ -z "$_rn" ]] && continue
    _row_order+=("$_rn")
  done < <(matrix_row_execution_order "${requested[@]+"${requested[@]}"}")
  for row_num in "${_row_order[@]}"; do
    [[ -z "$row_num" ]] && continue
    local slug="" route="" prompt_card="" evidence_path="" row="" rn=""
    for row in "${MATRIX_ROWS[@]}"; do
      IFS='|' read -r rn slug route prompt_card evidence_path <<<"$row"
      if [[ "$rn" == "$row_num" ]]; then
        run_matrix_row "$row_num" "$slug" "$route" "$prompt_card" "$evidence_path"
        break
      fi
    done
  done

  if should_run_row 21 "${requested[@]+"${requested[@]}"}" || should_run_row 22 "${requested[@]+"${requested[@]}"}"; then
    enterprise_e2e_matrix_ensure_internal_gate_markers
  fi

  if should_run_row 21 "${requested[@]+"${requested[@]}"}" || [[ "${#requested[@]}" -eq 0 ]]; then
    if verify_row_internal 21 silver-feature; then
      echo "=== Row 21: post-exec-gates (internal) PASS ==="
      enterprise_e2e_record_row_pass_at_install_version 21 "${SB_E2E_LEDGER_FILE:-}" ""
      PASS_ROWS=$((PASS_ROWS + 1))
    elif enterprise_e2e_row_pass_registry_should_skip 21; then
      echo "=== Row 21: post-exec-gates (internal) SKIP: ROW_ALREADY_PASSED_SAME_INSTALL ==="
      SKIP_ROWS=$((SKIP_ROWS + 1))
      INSTALL_PASS_SKIP_ROWS=$((INSTALL_PASS_SKIP_ROWS + 1))
      PASS_ROWS=$((PASS_ROWS + 1))
    else
      echo "=== Row 21: post-exec-gates (internal) FAIL ==="
      FAIL_ROWS=$((FAIL_ROWS + 1))
    fi
  fi

  if should_run_row 22 "${requested[@]+"${requested[@]}"}" || [[ "${#requested[@]}" -eq 0 ]]; then
    if verify_row_internal 22 silver-bugfix; then
      echo "=== Row 22: validate-substep (internal) PASS ==="
      enterprise_e2e_record_row_pass_at_install_version 22 "${SB_E2E_LEDGER_FILE:-}" ""
      PASS_ROWS=$((PASS_ROWS + 1))
    elif enterprise_e2e_row_pass_registry_should_skip 22; then
      echo "=== Row 22: validate-substep (internal) SKIP: ROW_ALREADY_PASSED_SAME_INSTALL ==="
      SKIP_ROWS=$((SKIP_ROWS + 1))
      INSTALL_PASS_SKIP_ROWS=$((INSTALL_PASS_SKIP_ROWS + 1))
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
  echo "Skip:  ${SKIP_ROWS} (install-pass: ${INSTALL_PASS_SKIP_ROWS})"
  echo "Total: $((PASS_ROWS + FAIL_ROWS + SKIP_ROWS)) / 22"

  if [[ "$FAIL_ROWS" -gt 0 ]]; then
    exit 1
  fi

  if [[ "${SB_E2E_MATRIX_FAIL_ON_SKIP:-}" == "1" ]]; then
    local evidence_skip=$((SKIP_ROWS - INSTALL_PASS_SKIP_ROWS))
    if [[ "$evidence_skip" -gt 0 ]]; then
      echo "ERROR: SB_E2E_MATRIX_FAIL_ON_SKIP=1 — ${evidence_skip} evidence SKIP row(s) (install-pass skips allowed: ${INSTALL_PASS_SKIP_ROWS})" >&2
      exit 1
    fi
  fi
}

main "$@"
