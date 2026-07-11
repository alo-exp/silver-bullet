#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export SB_LIVE_AGENT="${SB_LIVE_AGENT:-claude}"
export SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-claude}"
export SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-claude}"
export SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-claude}"
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT="${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-1}"

bash "${REPO_ROOT}/tests/live/run-live-tests.sh"
bash "${REPO_ROOT}/tests/e2e-live/run-e2e-live-tests.sh"
