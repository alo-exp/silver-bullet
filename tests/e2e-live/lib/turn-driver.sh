#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SB_ROOT:-}" ]]; then
  SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

run_prompt_sequence() {
  local prompt_file="$1"
  local prompt
  while IFS= read -r prompt || [[ -n "$prompt" ]]; do
    [[ -n "$prompt" ]] || continue
    [[ "$prompt" =~ ^# ]] && continue
    run_prompt "$prompt"
  done < "$prompt_file"
}

file_enterprise_e2e_issue() {
  local title="$1"
  local body="$2"
  local item_label="${3:-bug}"
  local repo_root="${SB_ROOT}"
  local owner_repo
  local issue_create_output
  local issue_url
  local issue_num

  owner_repo="$(git -C "$repo_root" remote get-url origin 2>/dev/null | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')"

  gh label create "filed-by-silver-bullet" \
    --color "#5319E7" \
    --description "Filed by Silver Bullet auto-capture" \
    --repo "$owner_repo" \
    >/dev/null 2>&1 || true

  gh label create "enterprise-test-app" \
    --color "#0E8A16" \
    --description "Enterprise-grade-test-app live E2E filing" \
    --repo "$owner_repo" \
    >/dev/null 2>&1 || true

  issue_create_output="$(gh issue create \
    --repo "$owner_repo" \
    --title "$title" \
    --body "$body" \
    --label "filed-by-silver-bullet" \
    --label "$item_label" \
    --label "enterprise-test-app" 2>/dev/null || true)"
  issue_url="$(printf '%s' "$issue_create_output" | grep -oE 'https://github.com/[^[:space:]]+/issues/[0-9]+' | tail -n 1 || true)"
  if [[ -z "${issue_url:-}" ]]; then
    issue_url="https://github.com/${owner_repo}/issues/0"
  fi

  issue_num="$(printf '%s' "$issue_url" | grep -oE '[0-9]+$')"
  if [[ "$issue_num" != "0" ]]; then
    gh issue edit "$issue_num" \
      --repo "$owner_repo" \
      --add-label "enterprise-test-app" \
      >/dev/null 2>&1 || true
  fi

  printf '%s\n' "$issue_url"
}

# Backward-compatible alias for legacy Kay todo-app journey harness.
file_todo_app_issue() {
  file_enterprise_e2e_issue "$@"
}
