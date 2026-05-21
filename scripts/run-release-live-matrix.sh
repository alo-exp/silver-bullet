#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

run_in_repo() {
  local description="$1"
  shift

  printf '[release-live-matrix] %s\n' "$description"
  (cd "$REPO_ROOT" && "$@")
}

if [[ -n "${SB_RELEASE_LIVE_MATRIX_CMD:-}" ]]; then
  run_in_repo "Running configured command: ${SB_RELEASE_LIVE_MATRIX_CMD}" \
    bash -lc "${SB_RELEASE_LIVE_MATRIX_CMD}"
  exit 0
fi

if [[ -x "${REPO_ROOT}/scripts/release-live-matrix.sh" ]]; then
  run_in_repo "Running repo-local override script: ${REPO_ROOT}/scripts/release-live-matrix.sh" \
    bash "${REPO_ROOT}/scripts/release-live-matrix.sh"
  exit 0
fi

if [[ -x "${REPO_ROOT}/tests/live/run-live-tests.sh" ]]; then
  run_in_repo "Running bundled live matrix: ${REPO_ROOT}/tests/live/run-live-tests.sh" \
    bash "${REPO_ROOT}/tests/live/run-live-tests.sh"
  exit 0
fi

printf 'ERROR: No release live matrix command is configured. Set SB_RELEASE_LIVE_MATRIX_CMD, add scripts/release-live-matrix.sh, or provide tests/live/run-live-tests.sh.\n' >&2
exit 1
