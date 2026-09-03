#!/usr/bin/env bash
# Resolve SB_ROOT for enterprise E2E live runs — avoids stale /private/tmp worktrees.
#
# Usage:
#   source scripts/lib/enterprise-e2e-sb-root-resolve.sh
#   SB_ROOT="$(enterprise_e2e_resolve_sb_root)"
#
# Environment (first match wins):
#   SB_ROOT              — use when directory contains run-enterprise-e2e-live-test.sh
#   SB_E2E_MAIN_REPO     — canonical artifact repo (ledger, registry)
#   SB_E2E_SB_ROOT_CANDIDATES — space-separated extra paths to try
set -euo pipefail

enterprise_e2e_sb_root_is_valid() {
  local dir="$1"
  [[ -n "$dir" && -d "$dir" ]] || return 1
  [[ -f "${dir}/scripts/run-enterprise-e2e-live-test.sh" ]] || return 1
  [[ -d "${dir}/.git" ]] || return 1
  return 0
}

# Emit absolute path to harness repo root (SB_ROOT).
enterprise_e2e_resolve_sb_root() {
  local candidate repo_root script_root
  if [[ -n "${SB_ROOT:-}" ]] && enterprise_e2e_sb_root_is_valid "$SB_ROOT"; then
    printf '%s\n' "$(cd "$SB_ROOT" && pwd)"
    return 0
  fi
  if [[ -n "${SB_E2E_MAIN_REPO:-}" ]] && enterprise_e2e_sb_root_is_valid "$SB_E2E_MAIN_REPO"; then
    printf '%s\n' "$(cd "$SB_E2E_MAIN_REPO" && pwd)"
    return 0
  fi
  if [[ -n "${SB_E2E_SB_ROOT_CANDIDATES:-}" ]]; then
    for candidate in $SB_E2E_SB_ROOT_CANDIDATES; do
      if enterprise_e2e_sb_root_is_valid "$candidate"; then
        printf '%s\n' "$(cd "$candidate" && pwd)"
        return 0
      fi
    done
  fi
  # Legacy worktree — only when still present (do not default blindly).
  if enterprise_e2e_sb_root_is_valid "/private/tmp/sb-main-row11-fp"; then
    printf '%s\n' "/private/tmp/sb-main-row11-fp"
    return 0
  fi
  script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  if enterprise_e2e_sb_root_is_valid "$script_root"; then
    printf '%s\n' "$script_root"
    return 0
  fi
  echo "ERROR: cannot resolve SB_ROOT — set SB_ROOT or SB_E2E_MAIN_REPO to silver-bullet repo" >&2
  return 1
}

# MAIN repo for ledger/registry artifacts (may equal SB_ROOT).
enterprise_e2e_resolve_main_repo() {
  local main
  if [[ -n "${SB_E2E_MAIN_REPO:-}" ]] && [[ -d "${SB_E2E_MAIN_REPO}/.planning/enterprise-e2e" ]]; then
    printf '%s\n' "$(cd "$SB_E2E_MAIN_REPO" && pwd)"
    return 0
  fi
  main="$(enterprise_e2e_resolve_sb_root)"
  printf '%s\n' "$main"
}
