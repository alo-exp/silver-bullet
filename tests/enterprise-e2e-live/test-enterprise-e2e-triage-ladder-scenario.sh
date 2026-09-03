#!/usr/bin/env bash
# Enterprise E2E wrapper — triage ladder scenario in cursor test-app SB environment.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

export SB_ROOT="$REPO_ROOT"
export SILVER_BULLET_RUNTIME=cursor
export SB_LIVE_RUNTIME=cursor
export RTK_DISABLED=1
export SB_E2E_LIVE_RUNTIME=cursor
export SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO=1

enterprise_e2e_apply_test_app_branch_defaults

if [[ -z "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
  SB_TEST_ENTERPRISE_APP_ROOT="$(enterprise_e2e_host_config_get test_app_root cursor 2>/dev/null || true)"
fi
if [[ -z "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
  SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-$(cd "${REPO_ROOT}/../.." && pwd)/enterprise-grade-test-app-cursor}"
fi
export SB_TEST_ENTERPRISE_APP_ROOT

printf 'Enterprise E2E triage ladder scenario\n'
printf '  SB repo: %s @ %s\n' "$REPO_ROOT" "$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
printf '  Test app: %s\n' "$SB_TEST_ENTERPRISE_APP_ROOT"

if [[ ! -d "$SB_TEST_ENTERPRISE_APP_ROOT" ]]; then
  printf 'FAIL: test app root missing: %s\n' "$SB_TEST_ENTERPRISE_APP_ROOT" >&2
  exit 1
fi

if [[ "${SB_E2E_TEST_APP_BRANCH_ENFORCE:-1}" != "0" ]]; then
  enterprise_e2e_assert_test_app_branch "$SB_TEST_ENTERPRISE_APP_ROOT" || {
    printf 'NOTE: test app branch mismatch — set SB_E2E_TEST_APP_ALLOW_DIRTY=1 or use isolated worktree\n' >&2
    if [[ "${SB_E2E_TEST_APP_ALLOW_DIRTY:-0}" != "1" ]]; then
      exit 1
    fi
  }
fi

export CURSOR_AGENT="${CURSOR_AGENT:-1}"
export SB_LIVE_CURSOR_IN_SESSION="${SB_LIVE_CURSOR_IN_SESSION:-1}"
export SB_LIVE_REVIEW_FIX_LADDER_LIVE="${SB_LIVE_REVIEW_FIX_LADDER_LIVE:-1}"

if command -v gh >/dev/null 2>&1 && { [[ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]] || gh auth status >/dev/null 2>&1; }; then
  export SB_RFL_GITHUB_E2E=1
fi

exec bash "${REPO_ROOT}/tests/live/test-live-review-fix-ladder-triage-scenario.sh"
