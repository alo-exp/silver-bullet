#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

HOST_VERIFY_TESTS_STATE_FILE="$HOME/.codex/.silver-bullet/verify-tests-state"
HOST_VERIFY_TESTS_BACKUP_FILE=""

if [[ ! -f "$HOST_VERIFY_TESTS_STATE_FILE" ]]; then
  printf 'ERROR: release live matrix requires a fresh verify-tests marker at %s. Run bash scripts/verify-tests.sh before this release gate.\n' "$HOST_VERIFY_TESTS_STATE_FILE" >&2
  exit 1
fi

HOST_VERIFY_TESTS_BACKUP_FILE="$(mktemp "${TMPDIR:-/tmp}/sb-release-live-wrapper-verify-tests-state.XXXXXX")"
cp "$HOST_VERIFY_TESTS_STATE_FILE" "$HOST_VERIFY_TESTS_BACKUP_FILE"

restore_host_verify_tests_state() {
  local rc=$?
  if [[ -n "$HOST_VERIFY_TESTS_BACKUP_FILE" && -f "$HOST_VERIFY_TESTS_BACKUP_FILE" ]]; then
    mkdir -p "$(dirname "$HOST_VERIFY_TESTS_STATE_FILE")"
    cp "$HOST_VERIFY_TESTS_BACKUP_FILE" "$HOST_VERIFY_TESTS_STATE_FILE"
    rm -f "$HOST_VERIFY_TESTS_BACKUP_FILE"
  fi
  return "$rc"
}
trap restore_host_verify_tests_state EXIT

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
