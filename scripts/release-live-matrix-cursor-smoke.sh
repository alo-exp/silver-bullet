#!/usr/bin/env bash
# Cursor runtime smoke gate for release live matrix.
#
# Runs in an isolated fake HOME + CURSOR_CONFIG_DIR (never touches operator ~/.cursor).
# Validates install-cursor.sh, hook merge, diagnostics, and cursor hook unit tests
# without requiring a live Cursor agent session.
#
# Nothing here touches the operator's runtime state unless asked: every hook and
# helper run under the fake HOME uses a state dir inside it. The release-gate
# marker (matrix=cursor-smoke) is written only when
# SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=1 is set explicitly, and then to the
# state dir the caller had before isolation (or SB_RELEASE_LIVE_MATRIX_MARKER_DIR
# when given); a caller-isolated run writes it into its own isolated state dir.
#
# Usage: bash scripts/release-live-matrix-cursor-smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

# Where an explicitly requested marker goes: captured before HOME is replaced.
MARKER_STATE_DIR="${SB_RELEASE_LIVE_MATRIX_MARKER_DIR:-${SB_RUNTIME_STATE_DIR:-}}"

cursor_home_dir() {
  printf '%s\n' "${HOME}/.cursor"
}

if [[ "${SB_CURSOR_SMOKE_USE_CURRENT_ENV:-}" == "1" && -n "${SB_SMOKE_CURSOR_FAKE_HOME:-}" ]]; then
  printf '[cursor-smoke] Using caller-isolated HOME=%s CURSOR_CONFIG_DIR=%s\n' \
    "$HOME" "${CURSOR_CONFIG_DIR:-}"
else
  TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-cursor-smoke.XXXXXX")"
  trap 'rm -rf "$TMP_ROOT"' EXIT

  export HOME="${TMP_ROOT}/fake-home"
  export CURSOR_CONFIG_DIR="${HOME}/.cursor"
  mkdir -p "$CURSOR_CONFIG_DIR"
  printf '%s\n' '{"version":1,"hooks":{}}' >"${CURSOR_CONFIG_DIR}/hooks.json"
  printf '%s\n' '{"mcpServers":{}}' >"${CURSOR_CONFIG_DIR}/mcp.json"
  export SILVER_BULLET_RUNTIME=cursor
  # Isolation is more than HOME: drop every variable that points the hooks, the
  # installer or the host at real config or state, and pin the state dir inside
  # the fake HOME.
  unset KAY_HOME CLAUDE_CONFIG_DIR CODEX_HOME SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE \
    SB_RUNTIME_HOME_ROOT SB_RUNTIME_PLUGIN_CACHE_ROOT XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${TMP_ROOT}/.silver-bullet"
  if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
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

if [[ "${SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER:-0}" == "1" ]]; then
  marker_file="${MARKER_STATE_DIR:-${SB_RUNTIME_STATE_DIR}}/release-live-matrix"
  mkdir -p "$(dirname "$marker_file")"
  cat >"$marker_file" <<'EOF'
matrix=cursor-smoke
EOF
  printf '[cursor-smoke] Wrote %s\n' "$marker_file"
fi

printf '[cursor-smoke] PASS\n'
