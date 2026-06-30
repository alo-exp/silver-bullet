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

assert_grep "silver-init hook install optional" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "graphify hook install"

assert_grep "template platform_install_commands cursor" \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" \
  '"cursor"'

jq -e '.recommended_tools.graphify.platform_install_commands.cursor.post_index[0] == "graphify cursor install"' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template cursor post_index command" || fail "template cursor post_index command"

jq -e '.recommended_tools.graphify.platform_install_commands.claude.pre_index[0] == "graphify install --project"' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template claude pre_index command" || fail "template claude pre_index command"

jq -e '.recommended_tools.graphify.install_commands | index("pipx install graphifyy") != null' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template uses pipx not plain pip" || fail "template uses pipx not plain pip"

template_suspended="$(jq -r '.recommended_tools.graphify.enforcement_suspended' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$template_suspended" == "false" ]] && pass "template enforcement_suspended defaults false" || fail "template enforcement_suspended defaults false"

cursor_cmd="$(jq -r '.recommended_tools.graphify.platform_install_commands.cursor.post_index[0]' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$cursor_cmd" == "graphify cursor install" ]] && pass "template cursor platform install" || fail "template cursor platform install"

claude_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.claude.pre_index[0]' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
claude_post="$(jq -r '.recommended_tools.graphify.platform_install_commands.claude.post_index[0]' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$claude_pre" == "graphify install --project" && "$claude_post" == "graphify claude install --project" ]] \
  && pass "template claude platform install" || fail "template claude platform install"

codex_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.codex.pre_index[0]' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
codex_post="$(jq -r '.recommended_tools.graphify.platform_install_commands.codex.post_index[0]' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$codex_pre" == "graphify install --project --platform codex" && "$codex_post" == "graphify codex install --project" ]] \
  && pass "template codex platform install" || fail "template codex platform install"

assert_grep "silver-init documents cursor platform install" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "graphify cursor install"

assert_grep "silver-init documents claude platform install" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "graphify claude install --project"

assert_grep "silver-init documents codex platform install" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "graphify codex install --project"

assert_grep "silver-init host detection" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "CURSOR_PLUGIN_ROOT"

assert_grep "GRAPHIFY.md platform table" \
  "$REPO_ROOT/docs/GRAPHIFY.md" \
  "graphify cursor install"

am_template_null="$(jq -r '.recommended_tools.agentmemory.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$am_template_null" == "null" ]] && pass "template agentmemory enabled_by_user is null" || fail "template agentmemory enabled_by_user is null"

assert_grep "silver-init agentmemory opt-in section" \
  "$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md" \
  "### 1.1b agentmemory"

assert_grep "silver-update agentmemory retry" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "Step 8b: agentmemory"

rtk_template_null="$(jq -r '.recommended_tools.rtk.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$rtk_template_null" == "null" ]] && pass "template rtk enabled_by_user is null" || fail "template rtk enabled_by_user is null"

cm_template_null="$(jq -r '.recommended_tools.context_mode.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$cm_template_null" == "null" ]] && pass "template context_mode enabled_by_user is null" || fail "template context_mode enabled_by_user is null"

assert_grep "silver-init RTK opt-in section" \
  "$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md" \
  "### 1.1e RTK"

assert_grep "silver-init Context Mode opt-in section" \
  "$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md" \
  "### 1.1f Context Mode"

assert_grep "silver-update RTK retry" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "Step 8c: RTK"

assert_grep "silver-init stack optimize step" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "sb-optimize-stack.sh --apply"

assert_grep "silver-update stack optimize step" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "Step 8d: Optimize Graphify + agentmemory stack"

assert_grep "silver-update Context Mode retry" \
  "$REPO_ROOT/skills/silver-update/SKILL.md" \
  "Step 8e: Context Mode"

assert_grep "RTK.md exists" \
  "$REPO_ROOT/docs/RTK.md" \
  "rtk-ai/rtk"

assert_grep "CONTEXT-MODE.md exists" \
  "$REPO_ROOT/docs/CONTEXT-MODE.md" \
  "ELv2"

assert_grep "ALUMNIUM.md exists" \
  "$REPO_ROOT/docs/ALUMNIUM.md" \
  "alumnium.ai"

assert_grep "silver-bullet 2g-ii token compression" \
  "$REPO_ROOT/templates/silver-bullet.md.base" \
  "### 2g-ii. Token Compression"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
