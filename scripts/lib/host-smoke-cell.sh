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
RUN_CLAIMS=0

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
  tri-host|rc) RUN_CLAIMS=1 ;;
esac

SB_PRE_RELEASE_SMOKE_ROOT="$(sb_smoke_root)"
export SB_PRE_RELEASE_SMOKE_ROOT
trap sb_smoke_cleanup EXIT

host_install() { case "$1" in
  codex) bash "${REPO_ROOT}/scripts/install-codex.sh" ;;
  claude) bash "${REPO_ROOT}/scripts/install-claude.sh" ;;
esac; }

begin_host() { case "$1" in
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
  if [[ "$mode" == "upgrade" ]]; then
    seed_upgrade "$host" || true
  fi
  host_install "$host" >/dev/null 2>&1 || return 1
  if [[ "$mode" == "upgrade" ]]; then
    host_install "$host" >/dev/null 2>&1 || true
  fi
  SB_DIAG_SMOKE=1 SILVER_BULLET_RUNTIME="$host" bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" >/dev/null 2>&1 || return 1
  if [[ "$RUN_CLAIMS" -eq 1 ]]; then
    RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1
  fi
}

case "$MODE" in
  fresh|upgrade)
    if [[ "$HOST" == "claude" ]] && ! command -v claude >/dev/null 2>&1; then
      echo "SKIP: claude (CLI unavailable)"
      exit 0
    fi
    run_install_cell "$HOST" "$MODE" || exit 1 ;;
  structural-only)
    bash "${REPO_ROOT}/scripts/validate-host-agnostic-core.sh" --repo-root "$REPO_ROOT"
    bash "${REPO_ROOT}/scripts/validate-host-install-surface.sh" --repo-root "$REPO_ROOT"
    bash "${REPO_ROOT}/scripts/validate-host-skill-surface.sh" --repo-root "$REPO_ROOT" ;;
esac
printf 'PASS: host-smoke-cell %s %s\n' "$HOST" "$MODE"
