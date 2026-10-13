#!/usr/bin/env bash
# CI-safe enterprise test-app fixture root for script unit tests.
set -euo pipefail

# Writable temp fixture when mktemp is used (empty when env/sibling path wins).
enterprise_e2e_test_fixture_temp=""

# Resolve FIXTURE for enterprise E2E script tests:
# 1. SB_TEST_ENTERPRISE_APP_ROOT when set (operator override)
# 2. Sibling enterprise-grade-test-app next to repo parent (local dev)
# 3. mktemp dir (GitHub Actions / CI without fixture clone)
enterprise_e2e_test_fixture_init() {
  local repo_root="$1"
  local default_sibling
  default_sibling="$(cd "${repo_root}/../.." && pwd)/enterprise-grade-test-app"

  if [[ -n "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
    FIXTURE="$SB_TEST_ENTERPRISE_APP_ROOT"
  elif [[ -d "$default_sibling" ]]; then
    FIXTURE="$default_sibling"
  else
    local tmp="${TMPDIR:-/tmp}"
    FIXTURE="$(mktemp -d "${tmp}/sb-enterprise-fixture.XXXXXX")"
    enterprise_e2e_test_fixture_temp="$FIXTURE"
  fi
  export FIXTURE SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
}
