#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/verify-release-announcement-ci.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

GITHUB_REPOSITORY="alo-exp/silver-bullet"
export GITHUB_REPOSITORY

commit_sha="abc123"

pass_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  GH_RUN_LIST_OVERRIDE="$(jq -n --arg sha "$commit_sha" '[
    {workflowName:"CI", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:01Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
    {workflowName:"Deploy to GitHub Pages", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"},
    {workflowName:"Announce Release", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:04Z"}
  ]')" \
  bash "$SCRIPT" "v1.2.3" 2>&1
)

assert_contains "passes when release-critical workflows are green" "fully green for announcement" "$pass_log"

set +e
fail_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  GH_RUN_LIST_OVERRIDE="$(jq -n --arg sha "$commit_sha" '[
    {workflowName:"CI", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:05Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
    {workflowName:"Deploy to GitHub Pages", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
  ]')" \
  bash "$SCRIPT" "v1.2.3" 2>&1
)
fail_rc=$?
set -e

if [[ $fail_rc -ne 0 ]]; then
  echo "PASS: blocks when CI is still running"
  (( PASS++ )) || true
else
  echo "FAIL: blocks when CI is still running — expected non-zero exit"
  (( FAIL++ )) || true
fi
assert_contains "block message mentions announcement" "Release announcement blocked" "$fail_log"
assert_contains "block message mentions release commit" "not fully green yet" "$fail_log"

announce_workflow="$(cd "$(dirname "$0")/../.." && pwd)/.github/workflows/announce-release.yml"
assert_contains "workflow requests actions: read" "actions: read" "$(cat "$announce_workflow")"
assert_contains "workflow verifies release CI" "Verify release commit CI is settled" "$(cat "$announce_workflow")"
assert_contains "workflow invokes release CI script" "verify-release-announcement-ci.sh" "$(cat "$announce_workflow")"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
