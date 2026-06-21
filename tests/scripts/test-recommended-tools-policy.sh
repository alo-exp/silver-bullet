#!/usr/bin/env bash
# Policy contract tests for recommended-tools opt-in decisions
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_grep() {
  local label="$1" file="$2" pattern="$3"
  if grep -qF -- "$pattern" "$file" 2>/dev/null; then
    pass "$label"
  else
    fail "$label — expected [$pattern] in $file"
  fi
}

echo "=== recommended-tools policy contract tests ==="

assert_grep "silver-init re-prompts on update when null" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "Update mode re-prompt"

assert_grep "silver-init fresh init always pending" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "Fresh init default"

assert_grep "silver-init install failure suspends" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "enforcement_suspended"

assert_grep "silver-update retries suspended install" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "enforcement_suspended"

assert_grep "silver-update re-prompts when null" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "enabled_by_user"

template_null="$(jq -r '.recommended_tools.graphify.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$template_null" == "null" ]] && pass "template enabled_by_user is null" || fail "template enabled_by_user is null"

template_suspended="$(jq -r '.recommended_tools.graphify.enforcement_suspended' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$template_suspended" == "false" ]] && pass "template enforcement_suspended defaults false" || fail "template enforcement_suspended defaults false"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
