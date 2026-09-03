#!/usr/bin/env bash
# Checkout tri-criteria fixture branch, stashing dirty worktree when needed.
# Greenfield mode: reset to main baseline and create feature/tri-<host>-<track>-<run_id>.
set -euo pipefail

tri_criteria_branch_for_track() {
  case "${1:-}" in
    TC-01) printf '%s\n' "feature/tc01-waitlist-saas" ;;
    TC-02) printf '%s\n' "feature/tc02-observability-runbook" ;;
    TC-03) printf '%s\n' "feature/tc03-posture-audit" ;;
    *) return 1 ;;
  esac
}

tri_criteria_greenfield_branch_name() {
  local host="$1" track="$2" run_id="$3"
  local track_slug host_slug run_slug
  track_slug="$(printf '%s' "$track" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  host_slug="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
  run_slug="$(printf '%s' "$run_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-24)"
  printf 'feature/tri-%s-%s-%s\n' "$host_slug" "$track_slug" "$run_slug"
}

tri_criteria_baseline_ref() {
  local work_dir="$1"
  local baseline="${SB_TRI_CRITERIA_BASELINE_REF:-main}"
  if git -C "$work_dir" rev-parse --verify "$baseline" >/dev/null 2>&1; then
    printf '%s\n' "$baseline"
    return 0
  fi
  if git -C "$work_dir" rev-parse --verify master >/dev/null 2>&1; then
    printf '%s\n' "master"
    return 0
  fi
  git -C "$work_dir" rev-parse --verify HEAD
}

tri_criteria_stash_if_dirty() {
  local work_dir="$1"
  if [[ -n "$(git -C "$work_dir" status --porcelain 2>/dev/null)" ]]; then
    git -C "$work_dir" stash push -u -m "tri-criteria-auto-stash-$(date -u +%Y%m%dT%H%M%SZ)" >/dev/null 2>&1 || true
  fi
}

tri_criteria_checkout_fixture() {
  local work_dir="$1" track="$2"
  local branch
  branch="$(tri_criteria_branch_for_track "$track")" || return 1

  if ! git -C "$work_dir" rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "WARN: fixture branch not found: $branch" >&2
    return 0
  fi

  tri_criteria_stash_if_dirty "$work_dir"

  if ! git -C "$work_dir" checkout "$branch" >/dev/null 2>&1; then
    echo "FAIL: could not checkout $branch in $work_dir (dirty worktree?)" >&2
    return 1
  fi
  echo "[fixture] checked out $branch ($(git -C "$work_dir" rev-parse --short=12 HEAD 2>/dev/null || echo unknown))" >&2
}

tri_criteria_greenfield_checkout_fixture() {
  local work_dir="$1" track="$2" host="$3" run_id="$4"
  local baseline branch

  baseline="$(tri_criteria_baseline_ref "$work_dir")"
  branch="$(tri_criteria_greenfield_branch_name "$host" "$track" "$run_id")"

  tri_criteria_stash_if_dirty "$work_dir"

  if ! git -C "$work_dir" checkout "$baseline" >/dev/null 2>&1; then
    echo "FAIL: could not checkout baseline $baseline in $work_dir" >&2
    return 1
  fi
  echo "[fixture] greenfield baseline: $baseline ($(git -C "$work_dir" rev-parse --short=12 HEAD 2>/dev/null || echo unknown))" >&2

  if git -C "$work_dir" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$work_dir" checkout "$branch" >/dev/null 2>&1 || {
      echo "FAIL: could not checkout existing greenfield branch $branch" >&2
      return 1
    }
    echo "[fixture] reused greenfield branch $branch" >&2
  else
    git -C "$work_dir" checkout -b "$branch" >/dev/null 2>&1 || {
      echo "FAIL: could not create greenfield branch $branch" >&2
      return 1
    }
    echo "[fixture] created greenfield branch $branch from $baseline" >&2
  fi

  printf '%s\n' "$branch"
}
