#!/usr/bin/env bash
# Verify the CI workflows for a release commit are fully settled before announcing it.
# This is intentionally narrower than the release gate: it checks the release-critical
# CI workflows only, so the announcement workflow never self-blocks on its own run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT/hooks/lib/github-run-list.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/hooks/lib/github-run-list.sh"
fi

TAG="${1:-${RELEASE_TAG:-}}"
if [[ -z "$TAG" ]]; then
  echo "::error::Missing release tag"
  exit 2
fi

REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO" ]]; then
  echo "::error::GITHUB_REPOSITORY is required"
  exit 2
fi

required_workflows=("CI" "Secret Scan" "Deploy to GitHub Pages")

resolve_release_commit_sha() {
  if [[ -n "${RELEASE_COMMIT_SHA_OVERRIDE:-}" ]]; then
    printf '%s' "$RELEASE_COMMIT_SHA_OVERRIDE"
    return 0
  fi

  command -v gh >/dev/null 2>&1 || return 1

  local ref_type ref_sha tag_sha
  read -r ref_type ref_sha < <(
    gh api "repos/$REPO/git/ref/tags/$TAG" --jq '.object | [.type, .sha] | @tsv'
  )

  [[ -n "${ref_type:-}" && -n "${ref_sha:-}" ]] || return 1

  if [[ "$ref_type" == "tag" ]]; then
    tag_sha="$ref_sha"
    gh api "repos/$REPO/git/tags/$tag_sha" --jq '.object.sha'
  else
    printf '%s' "$ref_sha"
  fi
}

commit_sha="$(resolve_release_commit_sha)" || {
  echo "::error::Unable to resolve the release commit for tag $TAG"
  exit 1
}

if ! runs_json=$(sb_github_run_list_json "$commit_sha"); then
  echo "::error::Unable to verify GitHub Actions status for release tag $TAG (commit $commit_sha)"
  exit 1
fi

if ! printf '%s' "$runs_json" | jq empty >/dev/null 2>&1; then
  echo "::error::GitHub Actions status payload for release tag $TAG is invalid"
  exit 1
fi

blocked_lines=""
missing_workflows=()

for workflow in "${required_workflows[@]}"; do
  latest_run=$(
    printf '%s' "$runs_json" | jq -r --arg commit_sha "$commit_sha" --arg workflow "$workflow" '
      [ .[]
        | select((.headSha // "") == $commit_sha and ((.workflowName // .name // "unknown") == $workflow))
      ]
      | if length == 0 then empty else
          sort_by(.createdAt // "")
          | last
          | [.workflowName // .name // "unknown", (.status // ""), (.conclusion // ""), (.createdAt // "")]
          | @tsv
        end
    '
  )

  if [[ -z "$latest_run" ]]; then
    missing_workflows+=("$workflow")
    continue
  fi

  IFS=$'\t' read -r wf status conclusion created_at <<< "$latest_run"
  if [[ "$status" != "completed" ]] || [[ ! " success skipped neutral " == *" $conclusion "* ]]; then
    line=$(printf '  • %s — status=%s conclusion=%s created=%s' "$wf" "$status" "$conclusion" "$created_at")
    if [[ -n "$blocked_lines" ]]; then
      blocked_lines+=$'\n'"$line"
    else
      blocked_lines="$line"
    fi
  fi
done

if [[ ${#missing_workflows[@]} -gt 0 ]]; then
  echo "::error::Release announcement blocked — missing CI workflow runs for tag $TAG: ${missing_workflows[*]}"
  exit 1
fi

if [[ -n "$blocked_lines" ]]; then
  echo "::error::Release announcement blocked — release commit $commit_sha is not fully green yet"
  printf '%s\n' "$blocked_lines"
  exit 1
fi

echo "✓ Release commit $commit_sha is fully green for announcement"
