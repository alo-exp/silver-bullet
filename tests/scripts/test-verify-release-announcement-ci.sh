#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -F "$needle" >/dev/null <<<"$haystack"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -F "$needle" >/dev/null <<<"$haystack"; then
    echo "FAIL: $desc — unexpectedly found [$needle]"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

write_run_list_sequence_script() {
  local script_path="$1"
  cat > "$script_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

count_file="${GH_RUN_LIST_SEQUENCE_COUNT_FILE:?missing GH_RUN_LIST_SEQUENCE_COUNT_FILE}"
commit_sha="${GH_RELEASE_COMMIT_SHA:?missing GH_RELEASE_COMMIT_SHA}"
count=0
if [[ -f "$count_file" ]]; then
  count="$(cat "$count_file")"
fi
count=$((count + 1))
printf '%s' "$count" > "$count_file"

if [[ "$count" -eq 1 ]]; then
  status="in_progress"
  conclusion=""
  created_at="2026-05-07T00:00:01Z"
else
  status="completed"
  conclusion="success"
  created_at="2026-05-07T00:00:02Z"
fi

jq -n --arg sha "$commit_sha" --arg status "$status" --arg conclusion "$conclusion" --arg created_at "$created_at" '[
  {workflowName:"CI", status:$status, conclusion:$conclusion, headSha:$sha, createdAt:$created_at},
  {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"},
  {workflowName:"Deploy to GitHub Pages", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:04Z"}
]'
EOF
  chmod +x "$script_path"
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
    {workflowName:"Deploy to GitHub Pages", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"},
    {workflowName:"Announce Release", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:04Z"}
  ]')" \
  bash "$SCRIPT" "v1.2.3" 2>&1
)

assert_contains "passes when release-critical workflows are green" "fully green for announcement" "$pass_log"

set +e
fail_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  ANNOUNCE_CI_TIMEOUT_SECONDS=0 \
  ANNOUNCE_CI_POLL_INTERVAL_SECONDS=0.1 \
  GH_RUN_LIST_OVERRIDE="$(jq -n --arg sha "$commit_sha" '[
    {workflowName:"CI", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:05Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
    {workflowName:"Deploy to GitHub Pages", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
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
assert_contains "timeout message mentions announcement" "timed out waiting" "$fail_log"
assert_contains "timeout message mentions release commit" "release commit" "$fail_log"

sequence_script="$TMP/run-list-sequence.sh"
write_run_list_sequence_script "$sequence_script"
sequence_count_file="$TMP/run-list-sequence.count"

wait_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  GH_RELEASE_COMMIT_SHA="$commit_sha" \
  GH_RUN_LIST_SEQUENCE_COUNT_FILE="$sequence_count_file" \
  GH_RUN_LIST_OVERRIDE_CMD="$sequence_script" \
  ANNOUNCE_CI_TIMEOUT_SECONDS=5 \
  ANNOUNCE_CI_POLL_INTERVAL_SECONDS=0.1 \
  bash "$SCRIPT" "v1.2.3" 2>&1
)
assert_contains "waits until CI becomes green" "Waiting for release commit" "$wait_log"
assert_contains "wait succeeds once CI settles" "fully green for announcement" "$wait_log"
assert_not_contains "pages workflow does not block announcement" "Deploy to GitHub Pages" "$wait_log"

announce_workflow="$(cd "$(dirname "$0")/../.." && pwd)/.github/workflows/announce-release.yml"
assert_contains "workflow requests actions: read" "actions: read" "$(cat "$announce_workflow")"
assert_contains "workflow waits for release CI" "Wait for release commit CI to settle" "$(cat "$announce_workflow")"
assert_contains "workflow invokes release CI script" "verify-release-announcement-ci.sh" "$(cat "$announce_workflow")"

wait_line=$(grep -n "Wait for release commit CI to settle" "$announce_workflow" | head -1 | cut -d: -f1 || echo 0)
post_line=$(grep -n "Post to Google Chat" "$announce_workflow" | head -1 | cut -d: -f1 || echo 0)
assert_contains "workflow posts after CI wait step" "pass" "$([[ "$wait_line" -gt 0 && "$post_line" -gt 0 && "$wait_line" -lt "$post_line" ]] && echo pass || echo fail)"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
