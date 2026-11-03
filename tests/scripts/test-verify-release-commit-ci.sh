#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -qF "$needle" <<<"$haystack"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
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
  {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
]'
EOF
  chmod +x "$script_path"
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/verify-release-commit-ci.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

commit_sha="abc123"

pass_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  GH_RUN_LIST_OVERRIDE="$(jq -n --arg sha "$commit_sha" '[
    {workflowName:"CI", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:01Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"}
  ]')" \
  GITHUB_REPOSITORY="alo-exp/silver-bullet" \
  bash "$SCRIPT" 2>&1
)
assert_contains "passes when release-critical workflows are green" "fully green" "$pass_log"

set +e
fail_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  RELEASE_CI_TIMEOUT_SECONDS=0 \
  GH_RUN_LIST_OVERRIDE="$(jq -n --arg sha "$commit_sha" '[
    {workflowName:"CI", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:05Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"}
  ]')" \
  GITHUB_REPOSITORY="alo-exp/silver-bullet" \
  bash "$SCRIPT" 2>&1
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
assert_contains "timeout message mentions release commit" "timed out waiting" "$fail_log"

sequence_script="$TMP/run-list-sequence.sh"
write_run_list_sequence_script "$sequence_script"
sequence_count_file="$TMP/run-list-sequence.count"

wait_log=$(
  RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" \
  GH_RELEASE_COMMIT_SHA="$commit_sha" \
  GH_RUN_LIST_SEQUENCE_COUNT_FILE="$sequence_count_file" \
  GH_RUN_LIST_OVERRIDE_CMD="$sequence_script" \
  RELEASE_CI_TIMEOUT_SECONDS=5 \
  RELEASE_CI_POLL_INTERVAL_SECONDS=0.1 \
  GITHUB_REPOSITORY="alo-exp/silver-bullet" \
  bash "$SCRIPT" 2>&1
)
assert_contains "waits until release commit becomes green" "Waiting for release commit" "$wait_log"
assert_contains "wait succeeds once release CI settles" "fully green" "$wait_log"

# GITHUB_REPOSITORY is derived from origin when unset (the skill and docs rely on it).
derive_root="$(mktemp -d)"
trap 'rm -rf "$derive_root"' EXIT
mkdir -p "$derive_root/scripts"
cp "$SCRIPT" "$derive_root/scripts/verify-release-commit-ci.sh"
git init -q "$derive_root"
derive_run() {
  env -u GITHUB_REPOSITORY RELEASE_COMMIT_SHA_OVERRIDE="$commit_sha" RELEASE_CI_TIMEOUT_SECONDS=1 \
    RELEASE_CI_POLL_INTERVAL_SECONDS=0.1 GH_RUN_LIST_OVERRIDE_CMD="$derive_probe" \
    bash "$derive_root/scripts/verify-release-commit-ci.sh" 2>&1 || true
}
derive_probe="$derive_root/probe.sh"
printf '#!/usr/bin/env bash\necho "[]"\n' >"$derive_probe"
chmod +x "$derive_probe"
git -C "$derive_root" remote add origin "git@github.com:acme/widget.git"
assert_lacks() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -qF "$needle" <<<"$haystack"; then echo "FAIL: $desc — found [$needle]"; (( FAIL++ )) || true; else echo "PASS: $desc"; (( PASS++ )) || true; fi
}
assert_lacks "ssh origin supplies the repository" "GITHUB_REPOSITORY is required" "$(derive_run)"
git -C "$derive_root" remote set-url origin "https://github.com/acme/widget2"
assert_lacks "https origin supplies the repository" "GITHUB_REPOSITORY is required" "$(derive_run)"
git -C "$derive_root" remote set-url origin "https://example.com/acme/widget"
assert_contains "non-GitHub origin still requires GITHUB_REPOSITORY" "GITHUB_REPOSITORY is required" "$(derive_run)"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
