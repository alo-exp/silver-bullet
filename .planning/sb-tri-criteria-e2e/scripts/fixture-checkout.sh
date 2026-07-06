#!/usr/bin/env bash
# Checkout tri-criteria fixture branch, stashing dirty worktree when needed.
set -euo pipefail

tri_criteria_branch_for_track() {
  case "${1:-}" in
    TC-01) printf '%s\n' "feature/tc01-waitlist-saas" ;;
    TC-02) printf '%s\n' "feature/tc02-observability-runbook" ;;
    TC-03) printf '%s\n' "feature/tc03-posture-audit" ;;
    *) return 1 ;;
  esac
}

tri_criteria_checkout_fixture() {
  local work_dir="$1" track="$2"
  local branch
  branch="$(tri_criteria_branch_for_track "$track")" || return 1

  if ! git -C "$work_dir" rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "WARN: fixture branch not found: $branch" >&2
    return 0
  fi

  if [[ -n "$(git -C "$work_dir" status --porcelain 2>/dev/null)" ]]; then
    git -C "$work_dir" stash push -u -m "tri-criteria-auto-stash-$(date -u +%Y%m%dT%H%M%SZ)" >/dev/null 2>&1 || true
  fi

  if ! git -C "$work_dir" checkout "$branch" >/dev/null 2>&1; then
    echo "FAIL: could not checkout $branch in $work_dir (dirty worktree?)" >&2
    return 1
  fi
  echo "[fixture] checked out $branch ($(git -C "$work_dir" rev-parse --short=12 HEAD 2>/dev/null || echo unknown))"
}
