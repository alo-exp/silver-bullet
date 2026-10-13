#!/usr/bin/env bash
# Preflight for /sb:agent-pi — CLI, MiMo model pin, auth surface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-pi/lib.sh
source "${SCRIPT_DIR}/lib.sh"
REPO_ROOT="$(agent_pi_repo_root)"
# shellcheck source=scripts/lib/pi-cli.sh
source "${REPO_ROOT}/scripts/lib/pi-cli.sh"

SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
DRY_RUN=0
PREFLIGHT_OK=1

usage() {
  cat <<'EOF'
Usage: preflight.sh [--sb-root PATH] [--dry-run]

Checks Pi CLI, MiMo V2.5 / opencode-go model pin, and auth surface.
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
  printf 'SKIP (dry-run): Pi CLI check\n'
else
  CLI="$(resolve_native_pi_cli_path "${PI_BIN:-}" || true)"
  [[ -n "$CLI" ]] || { printf 'ERROR: Pi CLI not found on PATH\n' >&2; exit 1; }
  "$CLI" --version >/dev/null 2>&1 || { printf 'ERROR: Pi CLI not working: %s\n' "$CLI" >&2; exit 1; }
  printf 'OK: Pi CLI %s\n' "$("$CLI" --version 2>/dev/null | head -1)"
fi

if [[ "$DRY_RUN" != "1" ]]; then
  agent_pi_pin_mimo_model_env || PREFLIGHT_OK=0
  printf 'OK: model pin opencode-go/mimo-v2.5\n'
else
  printf 'SKIP (dry-run): model pin\n'
fi

if [[ -f "${HOME}/.pi/agent/auth.json" ]]; then
  printf 'OK: Pi auth.json present\n'
elif [[ "$DRY_RUN" == "1" ]]; then
  printf 'SKIP (dry-run): Pi auth\n'
else
  printf 'WARN: ~/.pi/agent/auth.json missing — provider auth may fail at runtime\n' >&2
fi

_agent_pi_source_common
agent_delegate_clear_matrix_env
printf 'OK: matrix env cleared for delegation\n'

[[ "$PREFLIGHT_OK" -eq 1 ]] || exit 1
exit 0
