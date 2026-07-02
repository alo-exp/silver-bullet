#!/usr/bin/env bash
# Tri-host install smoke — install SB per host in isolated HOME + verify SB invocations.
#
# Pre-release gate for hero-tri-host / help-tri-host claims. NOT validation overlay.
#
# Per host:
#   1. install-{claude,codex,cursor}.sh in isolated HOME
#   2. sb-diagnostics.sh (SB_DIAG_SMOKE=1)
#   3. claims-audit.sh + check-apo-invariants.py site-doc-freshness (repo SB scripts)
#
# Usage:
#   RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh
#   RTK_DISABLED=1 bash scripts/run-tri-host-install-smoke.sh --host cursor
#
# Claude host is skipped when claude CLI is unavailable (operator must run locally).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

HOST_FILTER="${1:-all}"
if [[ "$HOST_FILTER" == --host ]]; then
  HOST_FILTER="${2:-all}"
fi

PASS=0
FAIL=0
SKIP=0

smoke_pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
smoke_fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
smoke_skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

run_sb_invocations() {
  local label="$1"
  if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1; then
    smoke_pass "${label}: claims-audit.sh"
  else
    smoke_fail "${label}: claims-audit.sh"
  fi
  if python3 "${REPO_ROOT}/scripts/check-apo-invariants.py" site-doc-freshness >/dev/null 2>&1; then
    smoke_pass "${label}: check-apo-invariants site-doc-freshness"
  else
    smoke_fail "${label}: check-apo-invariants site-doc-freshness"
  fi
}

smoke_codex() {
  local tmp_home
  tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/sb-trihost-codex.XXXXXX")"
  export HOME="$tmp_home"
  export SILVER_BULLET_RUNTIME=codex
  trap 'rm -rf "$tmp_home"' RETURN

  smoke_pass "codex: isolated HOME ${tmp_home}"
  local attempt=0 install_ok=0
  while [[ $attempt -lt 3 ]]; do
    if bash "${REPO_ROOT}/scripts/install-codex.sh" >/dev/null 2>&1; then
      install_ok=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  if [[ $install_ok -eq 1 ]]; then
    smoke_pass "codex: install-codex.sh"
  else
    smoke_fail "codex: install-codex.sh"
    return
  fi
  if SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=codex bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1; then
    smoke_pass "codex: sb-diagnostics.sh"
  else
    smoke_fail "codex: sb-diagnostics.sh"
  fi
  run_sb_invocations "codex"
}

smoke_cursor() {
  local tmp_home
  tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/sb-trihost-cursor.XXXXXX")"
  export HOME="$tmp_home"
  export CURSOR_HOME="${tmp_home}/.cursor"
  export SILVER_BULLET_RUNTIME=cursor
  trap 'rm -rf "$tmp_home"' RETURN

  smoke_pass "cursor: isolated HOME ${tmp_home}"
  if bash "${REPO_ROOT}/scripts/install-cursor.sh" >/dev/null 2>&1; then
    smoke_pass "cursor: install-cursor.sh"
  else
    smoke_fail "cursor: install-cursor.sh"
    return
  fi
  if [[ ! -f "${CURSOR_HOME}/hooks.json" ]]; then
    smoke_fail "cursor: hooks.json missing after install"
    return
  fi
  if ! grep -q 'silver-bullet' "${CURSOR_HOME}/hooks.json"; then
    smoke_fail "cursor: hooks.json missing silver-bullet entries"
    return
  fi
  smoke_pass "cursor: hooks.json merged"
  if SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=cursor bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1; then
    smoke_pass "cursor: sb-diagnostics.sh"
  else
    smoke_fail "cursor: sb-diagnostics.sh"
  fi
  run_sb_invocations "cursor"
}

smoke_claude() {
  local claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
  if [[ -z "$claude_bin" || ! -x "$claude_bin" ]]; then
    smoke_skip "claude: CLI not available — run install-claude.sh locally before release"
    return
  fi

  local tmp_home
  tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/sb-trihost-claude.XXXXXX")"
  export HOME="$tmp_home"
  export CLAUDE_BIN="$claude_bin"
  export SILVER_BULLET_RUNTIME=claude
  trap 'rm -rf "$tmp_home"' RETURN

  smoke_pass "claude: isolated HOME ${tmp_home}"
  if HOME="$tmp_home" CLAUDE_BIN="$claude_bin" bash "${REPO_ROOT}/scripts/install-claude.sh" >/dev/null 2>&1; then
    smoke_pass "claude: install-claude.sh"
  else
    smoke_fail "claude: install-claude.sh"
    return
  fi
  if SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME=claude HOME="$tmp_home" bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1; then
    smoke_pass "claude: sb-diagnostics.sh"
  else
    smoke_fail "claude: sb-diagnostics.sh"
  fi
  run_sb_invocations "claude"
}

echo "=== Tri-host install smoke ==="
echo "REPO_ROOT=${REPO_ROOT}"
echo ""

case "$HOST_FILTER" in
  all)
    smoke_codex
    smoke_cursor
    smoke_claude
    ;;
  codex) smoke_codex ;;
  cursor) smoke_cursor ;;
  claude) smoke_claude ;;
  *)
    echo "Unknown host: $HOST_FILTER (use all|codex|cursor|claude)" >&2
    exit 2
    ;;
esac

total=$((PASS + FAIL + SKIP))
echo ""
echo "Tri-host smoke: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped (${total} checks)"

[[ "$FAIL" -eq 0 ]]
