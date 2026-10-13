#!/usr/bin/env bash
# Deterministic checks for Claude install surface isolation and token budget.
# Would have caught: Codex/Cursor agents in Claude Agents Library + 17.8k token warning.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SURFACE="${REPO_ROOT}/scripts/validate-host-install-surface.sh"
TOKEN_BUDGET="${REPO_ROOT}/scripts/validate-claude-agent-token-budget.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "--- Claude agent surface isolation (live repo) ---"

if [[ -x "$INSTALL_SURFACE" ]] && bash "$INSTALL_SURFACE" --repo-root "$REPO_ROOT" --host claude >/dev/null 2>&1; then
  pass "validate-host-install-surface --host claude"
else
  fail "validate-host-install-surface --host claude"
fi

foreign_dirs=0
if [[ -d "${REPO_ROOT}/agents" ]]; then
  while IFS= read -r name; do
    [[ "$name" == "claude" ]] && continue
    foreign_dirs=$((foreign_dirs + 1))
    fail "agents/${name} must not exist (Claude discovers silver-bullet:${name}: namespaces)"
  done < <(find "${REPO_ROOT}/agents" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -u)
fi
[[ "$foreign_dirs" -eq 0 ]] && pass "agents/ contains only claude bundle"

if grep -rE 'silver-bullet:(codex|cursor):' "${REPO_ROOT}/agents/claude" --include='SKILL.md' -q 2>/dev/null; then
  fail "agents/claude SKILL.md files contain silver-bullet:codex: or silver-bullet:cursor: refs"
else
  pass "no silver-bullet:codex:/cursor: refs in Claude bundle manifests"
fi

if [[ -x "$TOKEN_BUDGET" ]] && bash "$TOKEN_BUDGET" --repo-root "$REPO_ROOT" --max-tokens 14000 >/dev/null 2>&1; then
  pass "Claude agent description token budget <= 14k"
else
  fail "Claude agent description token budget <= 14k"
fi

manifest="${REPO_ROOT}/.claude-plugin/plugin.json"
if [[ -f "$manifest" ]] && command -v jq >/dev/null 2>&1; then
  skills="$(jq -r '.skills // ""' "$manifest")"
  agents="$(jq -r '.agents // empty' "$manifest" 2>/dev/null || true)"
  if [[ "$skills" == "./agents/claude" && ( -z "$agents" || "$agents" == "null" ) ]]; then
    pass "Claude plugin manifest scopes skills to ./agents/claude (no agents field — Claude schema rejects agents)"
  else
    fail "Claude plugin manifest must scope skills to ./agents/claude without agents field (got skills=${skills} agents=${agents:-<unset>})"
  fi
else
  pass "Claude plugin manifest jq check skipped"
fi

echo ""
echo "--- Claude agent surface isolation (bleed fixture) ---"

bleed_root="$(mktemp -d)"
trap 'rm -rf "$bleed_root"' EXIT
mkdir -p "${bleed_root}/.claude-plugin" \
  "${bleed_root}/agents/claude/sb" \
  "${bleed_root}/agents/codex/silver" \
  "${bleed_root}/host-bundles/codex/sb" \
  "${bleed_root}/host-bundles/cursor/sb" \
  "${bleed_root}/plugins/silver-bullet/.codex-plugin" \
  "${bleed_root}/plugins/silver-bullet/skill-source/sb" \
  "${bleed_root}/plugins/silver-bullet/commands" \
  "${bleed_root}/.cursor-plugin"
printf '{"name":"silver-bullet","skills":"./agents/claude","agents":"./agents/claude"}\n' >"${bleed_root}/.claude-plugin/plugin.json"
printf '{"name":"silver-bullet","commands":"./commands/","hooks":"./hooks/hooks.json"}\n' >"${bleed_root}/plugins/silver-bullet/.codex-plugin/plugin.json"
printf '{"name":"silver-bullet","skills":"./agents/cursor"}\n' >"${bleed_root}/.cursor-plugin/plugin.json"
for d in agents/claude/sb host-bundles/codex/sb host-bundles/cursor/sb; do
  cat >"${bleed_root}/${d}/SKILL.md" <<'EOF'
---
name: silver
description: test
user-invocable: true
---
# test
EOF
done

if bash "$INSTALL_SURFACE" --repo-root "$bleed_root" --host claude >/dev/null 2>&1; then
  fail "bleed fixture with agents/codex should fail install-surface check"
else
  pass "bleed fixture with agents/codex fails install-surface check"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
