#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN_JSON="${REPO_ROOT}/.claude-plugin/plugin.json"

skills_path="$(jq -r '.skills // ""' "$PLUGIN_JSON")"
if [[ "$skills_path" == "./agents/claude" ]]; then
  pass "Claude plugin manifest points skills at agents/claude"
else
  fail "Claude plugin manifest points skills at agents/claude — got [$skills_path]"
fi

if jq -e '.commands' "$PLUGIN_JSON" >/dev/null 2>&1; then
  fail "Claude plugin manifest should not declare commands (skills-only picker)"
else
  pass "Claude plugin manifest does not declare commands"
fi

if [[ -d "${REPO_ROOT}/commands" ]]; then
  fail "repo-root commands/ should not exist (Codex-only surface lives in plugins/silver-bullet/commands)"
else
  pass "repo-root commands/ is absent"
fi

if [[ -d "${REPO_ROOT}/plugins/silver-bullet/commands" ]]; then
  pass "Codex package commands directory exists"
else
  fail "Codex package commands directory exists"
fi

if jq -e '.agents' "$PLUGIN_JSON" >/dev/null 2>&1; then
  fail "Claude plugin manifest must not declare agents (skills path is sufficient; Claude schema rejects agents)"
else
  pass "Claude plugin manifest does not declare agents"
fi

cross_host_dirs="$(find "${REPO_ROOT}/agents" -mindepth 1 -maxdepth 1 -type d ! -name 'claude' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$cross_host_dirs" == "0" ]]; then
  pass "repo agents/ contains only Claude bundle (no codex/cursor siblings)"
else
  fail "repo agents/ contains only Claude bundle — found $cross_host_dirs foreign host dirs"
fi

if [[ -d "${REPO_ROOT}/host-bundles/codex" && -d "${REPO_ROOT}/host-bundles/cursor" ]]; then
  pass "Codex and Cursor bundles live under host-bundles/"
else
  fail "Codex and Cursor bundles live under host-bundles/"
fi

if grep -qE '^name: silver:feature$' "${REPO_ROOT}/agents/claude/silver:feature/SKILL.md"; then
  pass "Claude bundle exposes silver:feature skill name"
else
  fail "Claude bundle exposes silver:feature skill name"
fi

hyphen_skill_dirs="$(find "${REPO_ROOT}/agents/claude" -mindepth 1 -maxdepth 1 -type d -name 'silver-*' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$hyphen_skill_dirs" == "0" ]]; then
  pass "Claude bundle has no silver-* hyphen skill directories"
else
  fail "Claude bundle has no silver-* hyphen skill directories — found $hyphen_skill_dirs"
fi

if grep -qE '^name: silver-feature$' "${REPO_ROOT}/skills/silver-feature/SKILL.md"; then
  pass "authoring skills tree keeps silver-feature source name"
else
  fail "authoring skills tree keeps silver-feature source name"
fi

non_silver_user_invocable=0
while IFS= read -r skill_file; do
  [[ -f "$skill_file" ]] || continue
  name="$(awk '/^---$/{if(++n==2) exit} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_file")"
  invocable="$(awk '/^---$/{if(++n==2) exit} n==1 && /^user-invocable:/{sub(/^user-invocable:[[:space:]]*/, ""); print; exit}' "$skill_file")"
  [[ -n "$name" ]] || continue
  case "$name" in
    silver|silver:*) continue ;;
  esac
  if [[ "$invocable" != "false" ]]; then
    non_silver_user_invocable=1
    fail "Claude bundle skill without silver prefix is user-invocable: $name"
  fi
done < <(find "${REPO_ROOT}/agents/claude" -name SKILL.md -type f)

if [[ "$non_silver_user_invocable" -eq 0 ]]; then
  pass "Claude bundle hides non-silver helper skills from picker"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
