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

file_todo_app_issue() {
  local title="$1"
  local body="$2"
  local item_label="${3:-bug}"
  local repo_root="${SB_ROOT}"
  local owner_repo
  local issue_url
  local issue_num

  owner_repo="$(git -C "$repo_root" remote get-url origin 2>/dev/null | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')"

  gh label create "filed-by-silver-bullet" \
    --color "#5319E7" \
    --description "Filed by Silver Bullet auto-capture" \
    --repo "$owner_repo" \
    >/dev/null 2>&1 || true

  gh label create "todo-app" \
    --color "#0E8A16" \
    --description "Todo-app live E2E filing" \
    --repo "$owner_repo" \
    >/dev/null 2>&1 || true

  issue_url="$(gh issue create \
    --repo "$owner_repo" \
    --title "$title" \
    --body "$body" \
    --label "filed-by-silver-bullet" \
    --label "$item_label" \
    --label "todo-app" \
    --json url -q '.url')"

  issue_num="$(printf '%s' "$issue_url" | grep -oE '[0-9]+$')"
  gh issue edit "$issue_num" \
    --repo "$owner_repo" \
    --add-label "todo-app" \
    >/dev/null

  printf '%s\n' "$issue_url"
}
