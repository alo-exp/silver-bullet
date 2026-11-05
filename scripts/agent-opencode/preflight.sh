#!/usr/bin/env bash
# Preflight for /sb:agent-opencode — CLI, MiMo model pin, SB install surface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-opencode/lib.sh
source "${SCRIPT_DIR}/lib.sh"
REPO_ROOT="$(agent_opencode_repo_root)"
# shellcheck source=scripts/lib/opencode-cli.sh
source "${REPO_ROOT}/scripts/lib/opencode-cli.sh"

SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
DRY_RUN=0
PREFLIGHT_OK=1

usage() {
  cat <<'EOF'
Usage: preflight.sh [--sb-root PATH] [--dry-run]

Checks native OpenCode CLI (not Desktop .app), MiMo V2.5 model pin, and SB install surface.
Exit 0 when ready to delegate; non-zero on blocker.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sb-root)
      [[ $# -ge 2 ]] || { printf 'ERROR: --sb-root requires a value\n' >&2; exit 2; }
      SB_ROOT="$2"; shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$SB_ROOT" ]] || { printf 'ERROR: SB_ROOT not a directory: %s\n' "$SB_ROOT" >&2; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'SKIP (dry-run): OpenCode CLI check\n'
else
  CLI="$(resolve_native_opencode_cli_path "${OPENCODE_BIN:-}" || true)"
  [[ -n "$CLI" ]] || { printf 'ERROR: native OpenCode CLI not found — install via curl -fsSL https://opencode.ai/install | bash\n' >&2; exit 1; }
  if [[ "$CLI" == *OpenCode.app* ]]; then
    printf 'ERROR: Desktop OpenCode.app is not the automation CLI — use ~/.opencode/bin/opencode\n' >&2
    exit 1
  fi
  "$CLI" --version >/dev/null 2>&1 || { printf 'ERROR: OpenCode CLI not working: %s\n' "$CLI" >&2; exit 1; }
  printf 'OK: OpenCode CLI %s\n' "$("$CLI" --version 2>/dev/null | head -1)"
fi

if [[ "$DRY_RUN" != "1" ]]; then
  if agent_opencode_pin_mimo_model_env; then
    printf 'OK: model pin opencode-go/mimo-v2.5\n'
  else
    PREFLIGHT_OK=0
  fi
else
  printf 'SKIP (dry-run): model pin\n'
fi

# No install-surface validation: validate-host-install-surface.sh knows claude|codex|cursor only,
# so an opencode probe could never run (it exited 2 and printed a "not configured" warning).

_agent_opencode_source_common
agent_delegate_clear_matrix_env
printf 'OK: matrix env cleared for delegation\n'

[[ "$PREFLIGHT_OK" -eq 1 ]] || exit 1
exit 0
