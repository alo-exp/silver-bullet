#!/usr/bin/env bash
# Preflight for /silver:agent-codex — CLI, hook trust, SB-only plugin surface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-codex/lib.sh
source "${SCRIPT_DIR}/lib.sh"
REPO_ROOT="$(agent_codex_repo_root)"
# shellcheck source=scripts/lib/codex-cli.sh
source "${REPO_ROOT}/scripts/lib/codex-cli.sh"

SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
SKIP_HOOK_TRUST="${AGENT_CODEX_SKIP_HOOK_TRUST:-0}"
DRY_RUN=0
PREFLIGHT_OK=1

usage() {
  cat <<'EOF'
Usage: preflight.sh [--sb-root PATH] [--dry-run]

Checks native Codex CLI, hook-trust seed, and SB install surface.
Exit 0 when ready to delegate; non-zero on blocker.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sb-root) SB_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$SB_ROOT" ]] || { printf 'ERROR: SB_ROOT not a directory: %s\n' "$SB_ROOT" >&2; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'SKIP (dry-run): Codex CLI check\n'
else
  CLI="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
  [[ -n "$CLI" ]] || { printf 'ERROR: native Codex CLI not found\n' >&2; exit 1; }
  "$CLI" --version >/dev/null 2>&1 || { printf 'ERROR: Codex CLI not working: %s\n' "$CLI" >&2; exit 1; }
  printf 'OK: Codex CLI %s\n' "$("$CLI" --version 2>/dev/null | head -1)"
fi

if [[ -f "${SB_ROOT}/scripts/install-codex.sh" && "$SKIP_HOOK_TRUST" != "1" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'SKIP (dry-run): hook-trust seed\n'
  elif (cd "$SB_ROOT" && bash scripts/install-codex.sh --hook-trust-seed-only) >/dev/null 2>&1; then
    printf 'OK: hook-trust seeded\n'
  else
    printf 'ERROR: hook-trust seed failed — run install-codex.sh manually\n' >&2
    PREFLIGHT_OK=0
  fi
fi

if [[ -f "${SB_ROOT}/scripts/validate-host-install-surface.sh" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'SKIP (dry-run): validate-host-install-surface\n'
  elif bash "${SB_ROOT}/scripts/validate-host-install-surface.sh" --host codex >/dev/null 2>&1; then
    printf 'OK: SB-only Codex install surface\n'
  else
    printf 'ERROR: validate-host-install-surface codex failed — run install-codex.sh\n' >&2
    PREFLIGHT_OK=0
  fi
fi

_agent_codex_source_common
agent_delegate_clear_matrix_env
printf 'OK: matrix env cleared for delegation\n'

[[ "$PREFLIGHT_OK" -eq 1 ]] || exit 1
exit 0
