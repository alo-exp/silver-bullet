#!/usr/bin/env bash
# shellcheck shell=bash
# Silver Bullet — GitHub Actions run-list helper.
#
# Sources:
#   - GH_RUN_LIST_OVERRIDE_CMD (tests / deterministic fixtures that need
#     changing output across repeated polls)
#   - GH_RUN_LIST_OVERRIDE (tests / deterministic fixtures)
#   - gh run list --commit <sha> (real release gate)
#
# The helper returns a JSON array of workflow runs for a specific commit.
# Callers decide how to interpret the result.

sb_github_run_list_json() {
  local commit_sha="${1:-}"

  if [[ -n "${GH_RUN_LIST_OVERRIDE_CMD:-}" ]]; then
    bash -lc "$GH_RUN_LIST_OVERRIDE_CMD"
    return 0
  fi

  if [[ -n "${GH_RUN_LIST_OVERRIDE:-}" ]]; then
    printf '%s' "$GH_RUN_LIST_OVERRIDE"
    return 0
  fi

  command -v gh >/dev/null 2>&1 || return 1

  if [[ -n "$commit_sha" ]]; then
    gh run list --commit "$commit_sha" --json status,conclusion,workflowName,headSha,createdAt,name 2>/dev/null
  else
    gh run list --json status,conclusion,workflowName,headSha,createdAt,name 2>/dev/null
  fi
}
