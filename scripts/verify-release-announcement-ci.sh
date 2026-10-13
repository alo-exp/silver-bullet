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

required_workflows=("CI" "Secret Scan")
poll_interval_seconds="${ANNOUNCE_CI_POLL_INTERVAL_SECONDS:-30}"
timeout_seconds="${ANNOUNCE_CI_TIMEOUT_SECONDS:-1800}"
deadline=$(( $(date +%s) + timeout_seconds ))

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

status_summary() {
  local runs_json="$1"
  local ready_lines=""
  local waiting_lines=""
  local missing_workflows=()

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
    if [[ "$status" == "completed" && " success skipped neutral " == *" $conclusion "* ]]; then
      ready_lines+="${ready_lines:+$'\n'}  • ${wf} — status=${status} conclusion=${conclusion} created=${created_at}"
    else
      waiting_lines+="${waiting_lines:+$'\n'}  • ${wf} — status=${status} conclusion=${conclusion} created=${created_at}"
    fi
  done

  if [[ ${#missing_workflows[@]} -gt 0 ]]; then
    printf 'missing\t%s\n' "${missing_workflows[*]}"
    return 0
  fi

  if [[ -n "$waiting_lines" ]]; then
    printf 'waiting\t%s\n' "$waiting_lines"
    return 0
  fi

  printf 'ready\t%s\n' "$ready_lines"
}

while true; do
  if ! runs_json=$(sb_github_run_list_json "$commit_sha"); then
    echo "::error::Unable to verify GitHub Actions status for release tag $TAG (commit $commit_sha)"
    exit 1
  fi

  if ! printf '%s' "$runs_json" | jq empty >/dev/null 2>&1; then
    echo "::error::GitHub Actions status payload for release tag $TAG is invalid"
    exit 1
  fi

  summary="$(status_summary "$runs_json")"
  state="${summary%%$'\t'*}"
  details="${summary#*$'\t'}"

  case "$state" in
    ready)
      echo "✓ Release commit $commit_sha is fully green for announcement"
      exit 0
      ;;
    missing|waiting)
      if (( $(date +%s) >= deadline )); then
        if [[ "$state" == "missing" ]]; then
          echo "::error::Release announcement timed out waiting for CI workflow runs for tag $TAG: $details"
        else
          echo "::error::Release announcement timed out waiting for release commit $commit_sha to become fully green"
          printf '%s\n' "$details"
        fi
        exit 1
      fi

      echo "Waiting for release commit $commit_sha to settle before posting announcement..."
      sleep "$poll_interval_seconds"
      ;;
    *)
      echo "::error::Unexpected release CI status state: $state"
      exit 1
      ;;
  esac
done
