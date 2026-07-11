#!/usr/bin/env bash
# Cursor runtime smoke gate for release live matrix.
#
# Runs in an isolated fake HOME + CURSOR_CONFIG_DIR (never touches operator $HOME/.codex).
# Validates install-cursor.sh, hook merge, diagnostics, and cursor hook unit tests
# without requiring a live Cursor agent session. Writes matrix=cursor-smoke when
# SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=1 (default for this script).
#
# Usage: bash scripts/release-live-matrix-cursor-smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

cursor_home_dir() {
  printf '%s\n' "${HOME}/.codex"
}

if [[ "${SB_CURSOR_SMOKE_USE_CURRENT_ENV:-}" == "1" && -n "${SB_SMOKE_CURSOR_FAKE_HOME:-}" ]]; then
  printf '[cursor-smoke] Using caller-isolated HOME=%s CURSOR_CONFIG_DIR=%s\n' \
    "$HOME" "${CURSOR_CONFIG_DIR:-}"
else
  TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-cursor-smoke.XXXXXX")"
  trap 'rm -rf "$TMP_ROOT"' EXIT

  export HOME="${TMP_ROOT}/fake-home"
  export CURSOR_CONFIG_DIR="${HOME}/.codex"
  mkdir -p "$CURSOR_CONFIG_DIR"
  printf '%s\n' '{"version":1,"hooks":{}}' >"${CURSOR_CONFIG_DIR}/hooks.json"
  printf '%s\n' '{"mcpServers":{}}' >"${CURSOR_CONFIG_DIR}/mcp.json"
  export SILVER_BULLET_RUNTIME=cursor
fi

cursor_home="$(cursor_home_dir)"

printf '[cursor-smoke] Running install-cursor.sh in isolated HOME\n'
bash "${REPO_ROOT}/scripts/install-cursor.sh"

if [[ ! -f "${cursor_home}/hooks.json" ]]; then
  printf 'ERROR: install-cursor.sh did not write %s\n' "${cursor_home}/hooks.json" >&2
  exit 1
fi
if ! grep -q 'silver-bullet' "${cursor_home}/hooks.json"; then
  printf 'ERROR: merged hooks.json missing silver-bullet entries\n' >&2
  exit 1
fi

printf '[cursor-smoke] Running sb-diagnostics (cursor path)\n'
SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=cursor HOME="$HOME" bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null

printf '[cursor-smoke] Running cursor hook unit tests\n'
for test_script in \
  "${REPO_ROOT}/tests/hooks/test-cursor-hook-bridge.sh" \
  "${REPO_ROOT}/tests/hooks/test-cursor-runtime-bootstrap.sh" \
  "${REPO_ROOT}/tests/hooks/test-runtime-paths.sh"; do
  HOME="$HOME" bash "$test_script"
done

if [[ "${SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER:-1}" == "1" ]]; then
  marker_file="$HOME/.codex/.silver-bullet/release-live-matrix"
  mkdir -p "$(dirname "$marker_file")"
  cat >"$marker_file" <<'EOF'
matrix=cursor-smoke
EOF
  printf '[cursor-smoke] Wrote %s\n' "$marker_file"
fi

printf '[cursor-smoke] PASS\n'
