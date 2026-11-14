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

_sb_gh_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -f sb_run_hooked_command >/dev/null 2>&1 && [[ -f "$_sb_gh_lib_dir/hook-subproc-timeout.sh" ]]; then
  # shellcheck source=hook-subproc-timeout.sh
  source "$_sb_gh_lib_dir/hook-subproc-timeout.sh"
fi
if ! declare -f sb_runtime_in_test_sandbox >/dev/null 2>&1 && [[ -f "$_sb_gh_lib_dir/cert-bypass.sh" ]]; then
  # shellcheck source=cert-bypass.sh
  source "$_sb_gh_lib_dir/cert-bypass.sh"
fi

# The GH_*_OVERRIDE switches replace CI status for the test suites. They are honoured only in a
# throw-away sandbox (R1-36); the _CMD form runs a shell command and is never taken from a real home.
sb_github_overrides_allowed() {
  declare -f sb_runtime_in_test_sandbox >/dev/null 2>&1 && sb_runtime_in_test_sandbox
}

# sb_github_run_list_json COMMIT: JSON array of the workflow runs for COMMIT. The gh call is bounded
# (SB_GH_TIMEOUT_SECONDS, default 8, well under the hook budget); a timeout or any gh failure returns
# 1 so the caller treats the status as "cannot verify".
sb_github_run_list_json() {
  local commit_sha="${1:-}" tmp out_file timeout_s rc=0

  if sb_github_overrides_allowed; then
    if [[ -n "${GH_RUN_LIST_OVERRIDE_CMD:-}" ]]; then
      bash -lc "$GH_RUN_LIST_OVERRIDE_CMD"
      return 0
    fi

    if [[ -n "${GH_RUN_LIST_OVERRIDE:-}" ]]; then
      printf '%s' "$GH_RUN_LIST_OVERRIDE"
      return 0
    fi
  fi

  command -v gh >/dev/null 2>&1 || return 1
  timeout_s="${SB_GH_TIMEOUT_SECONDS:-8}"
  [[ "$timeout_s" =~ ^[0-9]+$ ]] || timeout_s=8

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-gh-runs.XXXXXX")" || return 1
  out_file="$tmp/out"
  if [[ -n "$commit_sha" ]]; then
    sb_run_hooked_command "$timeout_s" /dev/null "$out_file" "$tmp/err" \
      gh run list --commit "$commit_sha" --json status,conclusion,workflowName,headSha,createdAt,name || rc=$?
  else
    sb_run_hooked_command "$timeout_s" /dev/null "$out_file" "$tmp/err" \
      gh run list --json status,conclusion,workflowName,headSha,createdAt,name || rc=$?
  fi
  if [[ "$rc" -eq 0 ]]; then
    cat "$out_file"
  fi
  rm -rf -- "$tmp"
  return "$rc"
}
