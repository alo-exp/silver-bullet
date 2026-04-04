#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Bash)
# After git commit or push, checks last completed CI run status.
# BLOCKING on failure — outputs decision:block and instructs immediate /gsd:debug.
# Non-blocking for in_progress (informational only).
# Scoped to current branch when possible to avoid cross-branch false positives.

# jq required — session-start already warns visibly if missing
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') || true
[[ -z "$cmd" ]] && exit 0

# Only fire on commit or push
printf '%s' "$cmd" | grep -qE '\bgit (commit|push)\b' || exit 0

# gh CLI required for real runs; test override bypasses it
if [[ -n "${GH_STATUS_OVERRIDE:-}" ]]; then
  run_json="$GH_STATUS_OVERRIDE"
else
  command -v gh >/dev/null 2>&1 || exit 0
  current_branch=$(git branch --show-current 2>/dev/null || echo "")
  branch_args=()
  [[ -n "$current_branch" ]] && branch_args=(--branch "$current_branch")
  run_json=$(gh run list --limit 1 "${branch_args[@]}" --json status,conclusion,name,headBranch 2>/dev/null \
    | jq -r '.[0] // empty' 2>/dev/null) || true
fi

[[ -z "${run_json:-}" ]] && exit 0

conclusion=$(printf '%s' "$run_json" | jq -r '.conclusion // ""' 2>/dev/null) || true
status=$(printf '%s' "$run_json"    | jq -r '.status // ""'     2>/dev/null) || true

# Validate extracted values against known-good sets (defense-in-depth)
case "$conclusion" in
  success|failure|cancelled|skipped|"") ;;
  *) conclusion="unknown" ;;
esac
case "$status" in
  completed|in_progress|queued|waiting|"") ;;
  *) status="unknown" ;;
esac

if [[ "$conclusion" == "failure" ]] || [[ "$conclusion" == "cancelled" ]]; then
  msg="🛑 CI FAILURE DETECTED — conclusion=${conclusion}.

STOP all other work immediately. Do NOT proceed to any other step.
Invoke /gsd:debug now to investigate the failing CI run before continuing.
Run: gh run list --limit 3 --json status,conclusion,name,headBranch
Then: gh run view <run-id> --log-failed"

  json_msg=$(printf '%s' "$msg" | jq -Rs '.')
  printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_msg" "$json_msg"

elif [[ "$status" == "in_progress" ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ CI in progress. Step 17 will poll for result before deploy."}}'
fi
# success or unknown: silent exit
