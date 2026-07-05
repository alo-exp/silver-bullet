#!/usr/bin/env bash
# Preflight for /silver:agent-claude — CLI, expect, OAuth surface, SB-only plugins.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-claude/lib.sh
source "${SCRIPT_DIR}/lib.sh"
REPO_ROOT="$(agent_claude_repo_root)"

SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
DRY_RUN=0
PREFLIGHT_OK=1

usage() {
  cat <<'EOF'
Usage: preflight.sh [--sb-root PATH] [--dry-run]

Checks Claude CLI, expect harness, and SB install surface.
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

CLI="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
[[ -n "$CLI" ]] || { printf 'ERROR: Claude CLI not found on PATH\n' >&2; exit 1; }
"$CLI" --version >/dev/null 2>&1 || { printf 'ERROR: Claude CLI not working: %s\n' "$CLI" >&2; exit 1; }
printf 'OK: Claude CLI %s\n' "$("$CLI" --version 2>/dev/null | head -1)"

EXPECT_SCRIPT="${SB_ROOT}/scripts/claude-interactive-invoke.expect"
[[ -x "$EXPECT_SCRIPT" ]] || { printf 'ERROR: expect harness missing: %s\n' "$EXPECT_SCRIPT" >&2; PREFLIGHT_OK=0; }

if command -v expect >/dev/null 2>&1; then
  printf 'OK: expect on PATH\n'
else
  printf 'WARN: expect not on PATH — delegate falls back to claude --print\n' >&2
fi

if [[ -f "${SB_ROOT}/scripts/validate-host-install-surface.sh" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'SKIP (dry-run): validate-host-install-surface\n'
  elif bash "${SB_ROOT}/scripts/validate-host-install-surface.sh" --host claude >/dev/null 2>&1; then
    printf 'OK: SB-only Claude install surface\n'
  else
    printf 'ERROR: validate-host-install-surface claude failed — run install-claude.sh\n' >&2
    PREFLIGHT_OK=0
  fi
fi

if [[ "$DRY_RUN" != "1" ]]; then
  if agent_claude_ensure_plugin_cache "$SB_ROOT"; then
    :
  else
    PREFLIGHT_OK=0
  fi
else
  printf 'SKIP (dry-run): plugin cache ensure\n'
fi

if [[ "$DRY_RUN" != "1" && -x "${SB_ROOT}/scripts/prune-stale-claude-user-hooks.sh" ]]; then
  bash "${SB_ROOT}/scripts/prune-stale-claude-user-hooks.sh" >/dev/null 2>&1 || true
  printf 'OK: pruned stale Claude user hooks\n'
elif [[ "$DRY_RUN" == "1" ]]; then
  :
fi

if [[ "$DRY_RUN" != "1" ]]; then
  auth_status="$("$CLI" auth status 2>/dev/null || true)"
  if printf '%s' "$auth_status" | grep -qiE 'not logged|unauthenticated|login required'; then
    printf 'ERROR: Claude not authenticated — run claude auth login before delegation\n' >&2
    PREFLIGHT_OK=0
  else
    printf 'OK: Claude auth surface present\n'
  fi
else
  printf 'SKIP (dry-run): auth status\n'
fi

_agent_claude_source_common
agent_delegate_clear_matrix_env
printf 'OK: matrix env cleared for delegation\n'

[[ "$PREFLIGHT_OK" -eq 1 ]] || exit 1
exit 0
