#!/usr/bin/env bash
# Error, polling and gh-resolution paths of scripts/verify-release-commit-ci.sh and
# scripts/verify-release-announcement-ci.sh (gh and sleep are stubbed).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

COMMIT="$TL_REPO_ROOT/scripts/verify-release-commit-ci.sh"
ANNOUNCE="$TL_REPO_ROOT/scripts/verify-release-announcement-ci.sh"
SHA=abc123
export GITHUB_REPOSITORY="o/r"
unset GH_RUN_LIST_OVERRIDE GH_RUN_LIST_OVERRIDE_CMD RELEASE_COMMIT_SHA_OVERRIDE RELEASE_TAG || true

runs() { # runs CI_STATUS CI_CONCLUSION CI_CREATED SCAN_STATUS SCAN_CONCLUSION [sha]
  jq -cn --arg sha "${6:-$SHA}" --arg a "$1" --arg b "$2" --arg c "$3" --arg d "$4" --arg e "$5" '[
    {workflowName:"CI", status:$a, conclusion:$b, headSha:$sha, createdAt:$c},
    {name:"Secret Scan", status:$d, conclusion:$e, headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}]'
}
GREEN="$(runs completed success 2026-05-07T00:00:01Z completed success)"

tl_stub sleep 'echo "$*" >>"'"$TL_TMP"'/sleep.calls"'

# ---- shared behaviours, once per script ------------------------------------
for which in commit announce; do
  if [[ $which == commit ]]; then
    script="$COMMIT"; args=("$SHA"); pfx=RELEASE_CI
  else
    script="$ANNOUNCE"; args=(v1.0.0); pfx=ANNOUNCE_CI
  fi
  export RELEASE_COMMIT_SHA_OVERRIDE="$SHA"
  export "${pfx}_TIMEOUT_SECONDS=0"

  GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: green passes" 0 "$TL_STATUS"
  assert_contains "$which: green message" "$TL_OUT" "Release commit $SHA is fully green"

  # skipped / neutral conclusions count as settled
  GH_RUN_LIST_OVERRIDE="$(runs completed skipped 2026-05-07T00:00:01Z completed neutral)" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: skipped+neutral pass" 0 "$TL_STATUS"

  # latest run per workflow wins: old failure + newer success passes, old success + newer failure waits
  both="$(jq -cn --arg sha "$SHA" '[
    {workflowName:"CI",status:"completed",conclusion:"failure",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"},
    {workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:09Z"},
    {workflowName:"Secret Scan",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:02Z"}]')"
  GH_RUN_LIST_OVERRIDE="$both" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: newer success supersedes older failure" 0 "$TL_STATUS"
  GH_RUN_LIST_OVERRIDE="$(runs completed failure 2026-05-07T00:00:09Z completed success)" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: failed latest run blocks" 1 "$TL_STATUS"
  assert_contains "$which: failure details listed" "$TL_OUT" "CI — status=completed conclusion=failure created=2026-05-07T00:00:09Z"
  assert_contains "$which: waiting timeout error" "$TL_OUT" "::error::Release"

  # a required workflow with no run for this commit -> "missing" timeout naming it
  GH_RUN_LIST_OVERRIDE="$(runs completed success 2026-05-07T00:00:01Z completed success other999)" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: runs for another commit are missing" 1 "$TL_STATUS"
  assert_contains "$which: missing workflows named" "$TL_OUT" "CI Secret Scan"
  GH_RUN_LIST_OVERRIDE='[]' tl_run bash "$script" "${args[@]}"
  assert_eq "$which: empty run list blocks" 1 "$TL_STATUS"

  # invalid payload
  GH_RUN_LIST_OVERRIDE='not json' tl_run bash "$script" "${args[@]}"
  assert_eq "$which: invalid payload exits 1" 1 "$TL_STATUS"
  assert_contains "$which: invalid payload message" "$TL_OUT" "status payload"
  assert_contains "$which: invalid payload says invalid" "$TL_OUT" "is invalid"

  # run list unavailable: no override and no gh
  PATH="$(tl_path_without gh)" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: no gh -> unable to verify" 1 "$TL_STATUS"
  assert_contains "$which: unable to verify message" "$TL_OUT" "Unable to verify GitHub Actions status"

  # real gh path: arguments and result
  tl_stub gh 'echo "$*" >>"'"$TL_TMP"'/gh.calls"; echo '"'$GREEN'"
  : >"$TL_TMP/gh.calls"
  tl_run bash "$script" "${args[@]}"
  assert_eq "$which: gh stub green passes" 0 "$TL_STATUS"
  assert_contains "$which: gh run list asked for this commit" "$(cat "$TL_TMP/gh.calls")" "run list --commit $SHA --json status,conclusion,workflowName,headSha,createdAt,name"
  tl_stub gh 'exit 1'
  tl_run bash "$script" "${args[@]}"
  assert_eq "$which: failing gh -> unable to verify" 1 "$TL_STATUS"
  rm -f "$TL_BIN/gh"

  # polling: waits with the configured interval, then succeeds
  export "${pfx}_TIMEOUT_SECONDS=100000" "${pfx}_POLL_INTERVAL_SECONDS=7"
  : >"$TL_TMP/sleep.calls"; rm -f "$TL_TMP/seq.count"
  cat >"$TL_TMP/seq.sh" <<SEQ
#!/usr/bin/env bash
n=\$(cat "$TL_TMP/seq.count" 2>/dev/null || echo 0); n=\$((n+1)); echo \$n >"$TL_TMP/seq.count"
if [ \$n -lt 3 ]; then echo '[]'; else echo '$GREEN'; fi
SEQ
  chmod +x "$TL_TMP/seq.sh"
  GH_RUN_LIST_OVERRIDE_CMD="bash $TL_TMP/seq.sh" tl_run bash "$script" "${args[@]}"
  assert_eq "$which: eventually green" 0 "$TL_STATUS"
  assert_eq "$which: slept twice with the poll interval" "7
7" "$(cat "$TL_TMP/sleep.calls")"
  assert_eq "$which: polled three times" 3 "$(cat "$TL_TMP/seq.count")"
  unset "${pfx}_POLL_INTERVAL_SECONDS"
done

# ---- verify-release-commit-ci.sh specifics ---------------------------------
unset RELEASE_COMMIT_SHA_OVERRIDE
export RELEASE_CI_TIMEOUT_SECONDS=0

# SHA defaults to the git HEAD of the script's checkout
HEAD_SHA="$(git -C "$TL_REPO_ROOT" rev-parse HEAD)"
GH_RUN_LIST_OVERRIDE="$(runs completed success 2026-05-07T00:00:01Z completed success "$HEAD_SHA")" tl_run bash "$COMMIT"
assert_eq "commit: defaults to git HEAD" 0 "$TL_STATUS"
assert_contains "commit: reports HEAD sha" "$TL_OUT" "Release commit $HEAD_SHA is fully green"

# positional argument beats the override variable
RELEASE_COMMIT_SHA_OVERRIDE=zzz GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$COMMIT" "$SHA"
assert_contains "commit: positional sha wins over override" "$TL_OUT" "Release commit $SHA is fully green"

# git absent, or the script outside any git checkout -> missing SHA
PATH="$(tl_path_without git)" GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$COMMIT"
assert_eq "commit: no git and no sha exits 2" 2 "$TL_STATUS"
assert_contains "commit: missing sha message" "$TL_OUT" "::error::Missing release commit SHA"
mkdir -p "$TL_TMP/nogit/scripts"
cp "$COMMIT" "$TL_TMP/nogit/scripts/"
GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$TL_TMP/nogit/scripts/verify-release-commit-ci.sh"
assert_eq "commit: not a git checkout exits 2" 2 "$TL_STATUS"
assert_contains "commit: not-a-checkout message" "$TL_OUT" "::error::Missing release commit SHA"

# without the run-list helper the lookup cannot work -> unable to verify (no crash)
GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$TL_TMP/nogit/scripts/verify-release-commit-ci.sh" "$SHA"
assert_eq "commit: helper library absent exits 1" 1 "$TL_STATUS"
assert_contains "commit: helper absent message" "$TL_OUT" "Unable to verify GitHub Actions status for release commit $SHA"

GITHUB_REPOSITORY="" tl_run bash "$COMMIT" "$SHA"
assert_eq "commit: repo required exits 2" 2 "$TL_STATUS"
assert_contains "commit: repo required message" "$TL_OUT" "::error::GITHUB_REPOSITORY is required"

# ---- verify-release-announcement-ci.sh specifics ---------------------------
export ANNOUNCE_CI_TIMEOUT_SECONDS=0
tl_run bash "$ANNOUNCE"
assert_eq "announce: missing tag exits 2" 2 "$TL_STATUS"
assert_contains "announce: missing tag message" "$TL_OUT" "::error::Missing release tag"
RELEASE_TAG=v2 RELEASE_COMMIT_SHA_OVERRIDE="$SHA" GH_RUN_LIST_OVERRIDE="$GREEN" tl_run bash "$ANNOUNCE"
assert_eq "announce: tag from RELEASE_TAG" 0 "$TL_STATUS"
GITHUB_REPOSITORY="" tl_run bash "$ANNOUNCE" v1
assert_eq "announce: repo required exits 2" 2 "$TL_STATUS"
assert_contains "announce: repo required message" "$TL_OUT" "::error::GITHUB_REPOSITORY is required"

# tag -> commit resolution through gh api
GHLOG="$TL_TMP/api.calls"
tl_stub gh 'echo "$*" >>"'"$GHLOG"'"
case "$*" in
  "api repos/o/r/git/ref/tags/light --jq"*) printf "commit\tsha-light\n" ;;
  "api repos/o/r/git/ref/tags/annot --jq"*) printf "tag\ttagobj1\n" ;;
  "api repos/o/r/git/tags/tagobj1 --jq"*) printf "sha-annot" ;;
  "api repos/o/r/git/ref/tags/empty --jq"*) exit 0 ;;
  "api repos/o/r/git/ref/tags/partial --jq"*) printf "commit\t\n" ;;
  "api repos/o/r/git/ref/tags/broken --jq"*) echo "HTTP 404" >&2; exit 1 ;;
  "run list --commit "*) jq -cn --arg sha "$4" '"'"'[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"x"},{workflowName:"Secret Scan",status:"completed",conclusion:"success",headSha:$sha,createdAt:"x"}]'"'"' ;;
esac'
: >"$GHLOG"
RELEASE_COMMIT_SHA_OVERRIDE="" GH_RUN_LIST_OVERRIDE="" tl_run bash "$ANNOUNCE" light
assert_eq "announce: lightweight tag resolves" 0 "$TL_STATUS"
assert_contains "announce: lightweight tag used ref sha" "$TL_OUT" "Release commit sha-light is fully green"
RELEASE_COMMIT_SHA_OVERRIDE="" GH_RUN_LIST_OVERRIDE="" tl_run bash "$ANNOUNCE" annot
assert_eq "announce: annotated tag resolves via tag object" 0 "$TL_STATUS"
assert_contains "announce: annotated tag dereferenced" "$TL_OUT" "Release commit sha-annot is fully green"
assert_contains "announce: both api calls made" "$(cat "$GHLOG")" "api repos/o/r/git/tags/tagobj1 --jq .object.sha"
for t in empty partial broken; do
  RELEASE_COMMIT_SHA_OVERRIDE="" GH_RUN_LIST_OVERRIDE="" tl_run bash "$ANNOUNCE" "$t"
  assert_eq "announce: tag '$t' cannot be resolved" 1 "$TL_STATUS"
  assert_contains "announce: '$t' resolution message" "$TL_OUT" "::error::Unable to resolve the release commit for tag $t"
done
RELEASE_COMMIT_SHA_OVERRIDE="" GH_RUN_LIST_OVERRIDE="" PATH="$(tl_path_without gh)" tl_run bash "$ANNOUNCE" light
assert_eq "announce: no gh cannot resolve tag" 1 "$TL_STATUS"
assert_contains "announce: no gh message" "$TL_OUT" "Unable to resolve the release commit for tag light"

tl_results
