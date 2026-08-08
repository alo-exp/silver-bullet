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

HOST_CURSOR_GUIDE="$REPO_ROOT/scripts/lib/host-install-guides/cursor.md"
HOST_CLAUDE_GUIDE="$REPO_ROOT/scripts/lib/host-install-guides/claude.md"
HOST_CODEX_GUIDE="$REPO_ROOT/scripts/lib/host-install-guides/codex.md"

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

jq -e '.recommended_tools.graphify.install_commands | index("pipx install '\''graphifyy[mcp]'\''") != null' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template graphify pipx uses graphifyy[mcp]" || fail "template graphify pipx uses graphifyy[mcp]"

jq -e '.recommended_tools.graphify.install_commands | index("uv tool install '\''graphifyy[mcp]'\''") != null' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template graphify uv uses graphifyy[mcp]" || fail "template graphify uv uses graphifyy[mcp]"

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
  "$HOST_CURSOR_GUIDE" \
  "graphify cursor install"

assert_grep "silver-init documents claude platform install" \
  "$HOST_CLAUDE_GUIDE" \
  "graphify claude install --project"

assert_grep "silver-init documents codex platform install" \
  "$HOST_CODEX_GUIDE" \
  "graphify codex install --project"

assert_grep "silver-init host detection" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "hooks/lib/runtime-paths.sh"

assert_grep "GRAPHIFY.md platform table" \
  "$REPO_ROOT/docs/GRAPHIFY.md" \
  "graphify cursor install"

am_template_null="$(jq -r '.recommended_tools.agentmemory.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$am_template_null" == "null" ]] && pass "template agentmemory enabled_by_user is null" || fail "template agentmemory enabled_by_user is null"

assert_grep "silver-init agentmemory opt-in section" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
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
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
  "### 1.1e RTK"

assert_grep "silver-init Context Mode opt-in section" \
  "$REPO_ROOT/skills/silver-init/SKILL.md" \
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

assert_grep "silver-bullet 2g-iii leanctx routing" \
  "$REPO_ROOT/templates/silver-bullet.md.base" \
  "### 2g-iii. Five-Tool Parallel Routing (LeanCTX)"

leanctx_template_null="$(jq -r '.recommended_tools.leanctx.enabled_by_user' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$leanctx_template_null" == "null" ]] && pass "template leanctx enabled_by_user is null" || fail "template leanctx enabled_by_user is null"

jq -e '.recommended_tools.leanctx.stack_mode == "parallel_routed"' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx stack_mode parallel_routed" || fail "template leanctx stack_mode parallel_routed"

jq -e '.recommended_tools.leanctx.mcp_tool_prefix == "lctx_"' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx mcp_tool_prefix lctx_" || fail "template leanctx mcp_tool_prefix lctx_"

leanctx_project_root='bash scripts/install-leanctx-sb.sh --host cursor --project-root "$(pwd)"'
jq -e --arg cmd "$leanctx_project_root" \
  '.recommended_tools.leanctx.platform_install_commands.cursor.pre_index[0] == $cmd' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx cursor platform install" || fail "template leanctx cursor platform install"

jq -e '.recommended_tools.leanctx.platform_install_commands.claude.pre_index[0] == "bash scripts/install-leanctx-sb.sh --host claude --project-root \"$(pwd)\""' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx claude platform install" || fail "template leanctx claude platform install"

jq -e '.recommended_tools.leanctx.platform_install_commands.codex.pre_index[0] == "bash scripts/install-leanctx-sb.sh --host codex --project-root \"$(pwd)\""' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx codex platform install" || fail "template leanctx codex platform install"

jq -e '.recommended_tools.leanctx.platform_install_commands.opencode.pre_index[0] == "bash scripts/install-leanctx-sb.sh --host opencode --project-root \"$(pwd)\""' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template leanctx opencode platform install" || fail "template leanctx opencode platform install"

# shellcheck source=../../hooks/lib/recommended-tools.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/hooks/lib/recommended-tools.sh"
export SILVER_BULLET_RUNTIME=cursor
leanctx_install_lines="$(sb_recommended_tool_platform_install_commands \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" leanctx cursor)"
leanctx_install_count="$(printf '%s\n' "$leanctx_install_lines" | sed '/^$/d' | wc -l | tr -d ' ')"
[[ "$leanctx_install_count" -eq 1 ]] \
  && pass "recommended-tools leanctx emits single platform install line" \
  || fail "recommended-tools leanctx emits single platform install line"
printf '%s' "$leanctx_install_lines" | grep -qF -- '--project-root "$(pwd)"' \
  && pass "recommended-tools leanctx platform install includes --project-root" \
  || fail "recommended-tools leanctx platform install includes --project-root"

jq -e '.optimization_profiles.five_tool_routed.routes | keys | length == 10' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template five_tool_routed has 10 routes" || fail "template five_tool_routed has 10 routes"

jq -e '.optimization_profiles.five_tool_routed.routes.sb_read == "leanctx" and .optimization_profiles.five_tool_routed.routes.sb_shell == "rtk" and .optimization_profiles.five_tool_routed.routes.sb_webfetch == "context_mode"' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template five_tool_routed route owners" || fail "template five_tool_routed route owners"

# Template parity: leanctx block matches between live config and template.
# Consent and install state are per-project, not contract: the template ships
# enabled_by_user: null to preserve the opt-in step for all five tools, and
# install_status / install_failure_reason / enforcement_suspended are written at
# runtime. Diffing those would fail on every project that granted consent, so
# parity covers the contract only: min_version, mcp_tool_prefix, stack_mode,
# primary_fts, install_commands, routes.
LEANCTX_PARITY_FILTER='.recommended_tools.leanctx | del(.enabled_by_user, .install_status, .install_failure_reason, .enforcement_suspended)'
jq -S "$LEANCTX_PARITY_FILTER" "$REPO_ROOT/templates/silver-bullet.config.json.default" > /tmp/sb-leanctx-template.json
jq -S "$LEANCTX_PARITY_FILTER" "$REPO_ROOT/.silver-bullet.json" > /tmp/sb-leanctx-live.json
diff -q /tmp/sb-leanctx-template.json /tmp/sb-leanctx-live.json >/dev/null \
  && pass "leanctx block parity template vs live" || fail "leanctx block parity template vs live"

assert_grep "LEANCTX.md exists" \
  "$REPO_ROOT/docs/LEANCTX.md" \
  "five_tool_routed"

assert_grep "recommended-tools-opt-in leanctx section" \
  "$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md" \
  "### 1.1g LeanCTX"

assert_grep "registry leanctx compression stack helper" \
  "$REPO_ROOT/hooks/lib/recommended-tools-registry.sh" \
  "sb_recommended_tool_is_compression_stack"

assert_grep "recommended-tools stack surface owner" \
  "$REPO_ROOT/hooks/lib/recommended-tools.sh" \
  "sb_stack_surface_owner"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1

