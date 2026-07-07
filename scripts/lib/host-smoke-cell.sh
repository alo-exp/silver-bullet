#!/usr/bin/env bash
# Shared host smoke cell — fresh | upgrade | structural-only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"
# shellcheck source=scripts/lib/pre-release-host-isolation.sh
source "${SCRIPT_DIR}/pre-release-host-isolation.sh"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${SCRIPT_DIR}/agent-bundle-paths.sh"

HOST="" MODE="" SCOPE="default"
WRITE_CURSOR_MARKER="${SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER:-0}"
RUN_CLAIMS=0 RUN_CURSOR_HOOK_TESTS=0 RUN_CURSOR_CLI_SMOKE=0 RUN_INVOKE_ROUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    *) exit 2 ;;
  esac
done
[[ -n "$HOST" && -n "$MODE" ]] || exit 2

case "$SCOPE" in
  ci-smoke) RUN_CURSOR_HOOK_TESTS=1; WRITE_CURSOR_MARKER=0 ;;
  tri-host|rc) RUN_CLAIMS=1 ;;
  pre-release) RUN_INVOKE_ROUTE=1; RUN_CURSOR_CLI_SMOKE=1; WRITE_CURSOR_MARKER=0 ;;
esac

SB_PRE_RELEASE_SMOKE_ROOT="$(sb_smoke_root)"
export SB_PRE_RELEASE_SMOKE_ROOT
trap sb_smoke_cleanup EXIT

host_install() { case "$1" in
  cursor) bash "${REPO_ROOT}/scripts/install-cursor.sh" ;;
  codex) bash "${REPO_ROOT}/scripts/install-codex.sh" ;;
  claude) bash "${REPO_ROOT}/scripts/install-claude.sh" ;;
esac; }

begin_host() { case "$1" in
  cursor) sb_smoke_begin_cursor ;;
  codex) sb_smoke_begin_codex ;;
  claude) sb_smoke_begin_claude ;;
esac; }

seed_upgrade() {
  local tag checkout
  tag="$(sb_smoke_resolve_previous_tag)" || tag=""
  if [[ -n "$tag" ]]; then
    checkout="$(sb_smoke_root)/prior-tag"
    rm -rf "$checkout"
    sb_smoke_checkout_at_tag "$tag" "$checkout" && SB_PRE_RELEASE_REPO_ROOT="$checkout" host_install "$1" >/dev/null 2>&1
    export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"
    return 0
  fi
  host_install "$1" >/dev/null 2>&1
}

run_install_cell() {
  local host="$1" mode="$2"
  begin_host "$host"
  [[ "$mode" == "upgrade" ]] && seed_upgrade "$host" || true
  host_install "$host" >/dev/null 2>&1 || return 1
  [[ "$host" == "cursor" ]] && grep -q silver-bullet "${HOME}/.cursor/hooks.json" || true
  [[ "$mode" == "upgrade" ]] && host_install "$host" >/dev/null 2>&1 || true
  SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME="$host" bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1 || return 1
  [[ "$RUN_CLAIMS" -eq 1 ]] && RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1
}

case "$MODE" in
  fresh|upgrade)
    if [[ "$HOST" == "claude" ]] && ! command -v claude >/dev/null 2>&1; then
      echo "SKIP: claude (CLI unavailable)"
      exit 0
    fi
    run_install_cell "$HOST" "$MODE" || exit 1
    if [[ "$HOST" == "cursor" ]]; then
      [[ "$RUN_CURSOR_HOOK_TESTS" -eq 1 ]] && for t in test-cursor-hook-bridge.sh test-cursor-runtime-bootstrap.sh test-runtime-paths.sh; do
        bash "${REPO_ROOT}/tests/hooks/$t"; done
      [[ "$RUN_CURSOR_CLI_SMOKE" -eq 1 ]] && SB_CURSOR_SMOKE_USE_CURRENT_ENV=1 \
        bash "${REPO_ROOT}/scripts/pre-release-cursor-cli-smoke.sh"
      [[ "$WRITE_CURSOR_MARKER" == "1" ]] && printf 'matrix=cursor-smoke\n' >"${SB_RUNTIME_STATE_DIR}/release-live-matrix"
    fi ;;
  structural-only)
    bash "${REPO_ROOT}/scripts/validate-host-agnostic-core.sh" --repo-root "$REPO_ROOT"
    bash "${REPO_ROOT}/scripts/validate-host-install-surface.sh" --repo-root "$REPO_ROOT"
    bash "${REPO_ROOT}/scripts/validate-host-skill-surface.sh" --repo-root "$REPO_ROOT" ;;
esac
printf 'PASS: host-smoke-cell %s %s\n' "$HOST" "$MODE"
