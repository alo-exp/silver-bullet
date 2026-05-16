#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export SB_LIVE_AGENT="${SB_LIVE_AGENT:-kay}"
export SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-kay}"
export SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-codex}"
export SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-codex}"
export SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"
export SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M2.7}"

bash "${REPO_ROOT}/tests/live/run-live-tests.sh"
bash "${REPO_ROOT}/tests/e2e-live/run-e2e-live-tests.sh"
