#!/usr/bin/env bash
# stamp-interface-state.sh — create .planning/interface/STATE.md from template
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="${1:-$PWD}"
FORCE="${SILVER_BULLET_FORCE_INTERFACE_STATE:-0}"

template_path() {
  local root="$1"
  local candidate=""
  for candidate in \
    "$root/templates/interface/STATE.md.base" \
    "$REPO_ROOT/templates/interface/STATE.md.base"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

detect_ui_project() {
  local root="$1"
  local stack="" workflow=""

  if [[ -f "$root/.silver-bullet.json" ]]; then
    stack="$(jq -r '.project.tech_stack // ""' "$root/.silver-bullet.json" 2>/dev/null || true)"
    workflow="$(jq -r '.project.active_workflow // ""' "$root/.silver-bullet.json" 2>/dev/null || true)"
    if [[ "$workflow" == *ui* ]]; then
      return 0
    fi
  fi

  if echo "$stack" | grep -qiE 'react|vue|angular|svelte|next\.js|nuxt|flutter|swiftui|frontend|ui/'; then
    return 0
  fi

  if [[ -f "$root/package.json" ]] && grep -qiE '"react"|"vue"|"@angular/|svelte|next"|nuxt"' "$root/package.json" 2>/dev/null; then
    return 0
  fi

  return 1
}

main() {
  local template="" dest="$TARGET_ROOT/.planning/interface/STATE.md"

  if ! detect_ui_project "$TARGET_ROOT"; then
    echo "skip:not-ui-project"
    return 0
  fi

  if [[ -f "$dest" && "$FORCE" != "1" ]]; then
    echo "skip:exists"
    return 0
  fi

  if ! template="$(template_path "$TARGET_ROOT")"; then
    echo "error:template-missing" >&2
    return 1
  fi

  mkdir -p "$TARGET_ROOT/.planning/interface"
  cp "$template" "$dest"
  echo "stamped:$dest"
}

main "$@"
