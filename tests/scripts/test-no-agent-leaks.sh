#!/usr/bin/env bash
# Fail when canonical SB sources contain agent-specific literals that belong
# only in rendered agents/* bundles or runtime-paths branching.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

CANONICAL_ROOTS=(
  "${REPO_ROOT}/skills"
  "${REPO_ROOT}/hooks"
  "${REPO_ROOT}/templates"
  "${REPO_ROOT}/silver-bullet.md"
)

EXCLUDE_PATH_REGEX='(/skills/silver-init/scripts/|/hooks/lib/runtime-paths\.sh$)'

# pattern|human label
BANNED_PATTERNS=(
  'AskUserQuestion|AskUserQuestion'
  'Claude Skill events|Claude Skill events'
  'Claude Skill tool|Claude Skill tool'
  'Cursor Skill tool|Cursor Skill tool'
  '\${CLAUDE_PLUGIN_ROOT}|CLAUDE_PLUGIN_ROOT placeholder'
  '\${CURSOR_PLUGIN_ROOT}|CURSOR_PLUGIN_ROOT placeholder'
  '~/.codex/|~/.claude home path'
  '~/.cursor/|~/.cursor home path'
  'Read tool|Read tool'
  'Write tool|Write tool'
  'Edit tool|Edit tool'
  'Bash tool|Bash tool'
  'Glob tool|Glob tool'
  'via the Skill tool|via the Skill tool'
  'Skill tool invocations|Skill tool invocations'
)

collect_files() {
  local root="$1"
  if [[ -f "$root" ]]; then
    printf '%s\n' "$root"
    return
  fi
  find "$root" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.base' \) \
    | grep -Ev "$EXCLUDE_PATH_REGEX" || true
}

assert_no_leaks() {
  local file="$1"
  local rel="${file#"${REPO_ROOT}/"}"
  local entry pattern label

  for entry in "${BANNED_PATTERNS[@]}"; do
    pattern="${entry%%|*}"
    label="${entry#*|}"
    if grep -Eq "$pattern" "$file" 2>/dev/null; then
      echo "  FAIL: ${rel} contains banned ${label}"
      grep -En "$pattern" "$file" | head -3 | sed 's/^/         /'
      FAIL=$((FAIL + 1))
      return
    fi
  done
  PASS=$((PASS + 1))
}

echo "Scanning canonical sources for agent-specific leaks..."

while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  assert_no_leaks "$file"
done < <(
  for root in "${CANONICAL_ROOTS[@]}"; do
    collect_files "$root"
  done | sort -u
)

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
