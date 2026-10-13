#!/usr/bin/env bash
# Verify the current release commit is fully green before tag/release publish.
# This is the release-gate counterpart to verify-release-announcement-ci.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT/hooks/lib/github-run-list.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/hooks/lib/github-run-list.sh"
fi

COMMIT_SHA="${1:-${RELEASE_COMMIT_SHA_OVERRIDE:-}}"
if [[ -z "$COMMIT_SHA" ]]; then
  if command -v git >/dev/null 2>&1; then
    COMMIT_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
  fi
fi

if [[ -z "$COMMIT_SHA" ]]; then
  echo "::error::Missing release commit SHA"
  exit 2
fi

REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO" ]]; then
  echo "::error::GITHUB_REPOSITORY is required"
  exit 2
fi

required_workflows=("CI" "Secret Scan")
poll_interval_seconds="${RELEASE_CI_POLL_INTERVAL_SECONDS:-30}"
timeout_seconds="${RELEASE_CI_TIMEOUT_SECONDS:-1800}"
deadline=$(( $(date +%s) + timeout_seconds ))

status_summary() {
  local runs_json="$1"
  local ready_lines=""
  local waiting_lines=""
  local missing_workflows=()

  for workflow in "${required_workflows[@]}"; do
    latest_run=$(
      printf '%s' "$runs_json" | jq -r --arg commit_sha "$COMMIT_SHA" --arg workflow "$workflow" '
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
  if ! runs_json=$(sb_github_run_list_json "$COMMIT_SHA"); then
    echo "::error::Unable to verify GitHub Actions status for release commit $COMMIT_SHA"
    exit 1
  fi

  if ! printf '%s' "$runs_json" | jq empty >/dev/null 2>&1; then
    echo "::error::GitHub Actions status payload for release commit $COMMIT_SHA is invalid"
    exit 1
  fi

  summary="$(status_summary "$runs_json")"
  state="${summary%%$'\t'*}"
  details="${summary#*$'\t'}"

  case "$state" in
    ready)
      echo "✓ Release commit $COMMIT_SHA is fully green"
      exit 0
      ;;
    missing|waiting)
      if (( $(date +%s) >= deadline )); then
        if [[ "$state" == "missing" ]]; then
          echo "::error::Release CI timed out waiting for GitHub workflow runs for commit $COMMIT_SHA: $details"
        else
          echo "::error::Release CI timed out waiting for commit $COMMIT_SHA to become fully green"
          printf '%s\n' "$details"
        fi
        exit 1
      fi

      echo "Waiting for release commit $COMMIT_SHA to become fully green before tagging..."
      sleep "$poll_interval_seconds"
      ;;
    *)
      echo "::error::Unexpected release CI status state: $state"
      exit 1
      ;;
  esac
done
