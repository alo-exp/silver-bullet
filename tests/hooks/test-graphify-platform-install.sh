#!/usr/bin/env bash
# Platform-specific Graphify install contract — upstream v8 alignment
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/recommended-tools.sh"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

# shellcheck source=hooks/lib/recommended-tools.sh
source "$LIB"

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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== graphify platform install contract tests ==="

# Template schema: pre_index / post_index per host
for host in claude codex cursor opencode goose hermes; do
  if jq -e --arg h "$host" '.recommended_tools.graphify.platform_install_commands[$h]' "$TEMPLATE" >/dev/null 2>&1; then
    pass "template has platform_install_commands.${host}"
  else
    fail "template has platform_install_commands.${host}"
  fi
done

cursor_post="$(jq -r '.recommended_tools.graphify.platform_install_commands.cursor.post_index[0]' "$TEMPLATE")"
[[ "$cursor_post" == "graphify cursor install" ]] && pass "cursor post_index is graphify cursor install" || fail "cursor post_index"

claude_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.claude.pre_index[0]' "$TEMPLATE")"
[[ "$claude_pre" == "graphify install --project" ]] && pass "claude pre_index skill install" || fail "claude pre_index"

codex_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.codex.pre_index[0]' "$TEMPLATE")"
[[ "$codex_pre" == "graphify install --project --platform codex" ]] && pass "codex pre_index skill install" || fail "codex pre_index"

opencode_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.opencode.pre_index[0]' "$TEMPLATE")"
[[ "$opencode_pre" == "graphify install --project --platform opencode" ]] && pass "opencode pre_index" || fail "opencode pre_index"

goose_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.goose.pre_index[0]' "$TEMPLATE")"
[[ "$goose_pre" == "graphify install --project --platform pi" ]] && pass "goose pre_index uses pi platform" || fail "goose pre_index"

hermes_pre="$(jq -r '.recommended_tools.graphify.platform_install_commands.hermes.pre_index[0]' "$TEMPLATE")"
[[ "$hermes_pre" == "graphify install --project --platform hermes" ]] && pass "hermes pre_index" || fail "hermes pre_index"

install_cmds="$(jq -r '.recommended_tools.graphify.install_commands[]' "$TEMPLATE")"
printf '%s' "$install_cmds" | grep -q "uv tool install 'graphifyy\[mcp\]'" && pass "template CLI uv install" || fail "template CLI uv install"
printf '%s' "$install_cmds" | grep -q "pipx install 'graphifyy\[mcp\]'" && pass "template CLI pipx install" || fail "template CLI pipx install"
! printf '%s' "$install_cmds" | grep -q 'pip install graphifyy' && pass "template avoids plain pip install" || fail "template avoids plain pip"

# Hook lib fallbacks
write_cfg() { printf '%s' "$1" >"$TMP/.silver-bullet.json"; }
write_cfg "{\"config_version\":\"0.46.0\"}"

pre="$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_pre_index_commands "$TMP/.silver-bullet.json" graphify)"
[[ "$pre" == "graphify install --project" ]] && pass "claude pre_index fallback" || fail "claude pre_index fallback"

post="$(SILVER_BULLET_RUNTIME=cursor sb_recommended_tool_platform_post_index_commands "$TMP/.silver-bullet.json" graphify)"
[[ "$post" == "graphify cursor install" ]] && pass "cursor post_index fallback" || fail "cursor post_index fallback"

codex_post="$(SILVER_BULLET_RUNTIME=codex sb_recommended_tool_platform_post_index_commands "$TMP/.silver-bullet.json" graphify)"
[[ "$codex_post" == "graphify codex install --project" ]] && pass "codex post_index fallback" || fail "codex post_index fallback"

# Legacy flat-array backward compat
write_cfg '{"recommended_tools":{"graphify":{"platform_install_commands":{"claude":["graphify install --project","graphify claude install --project"]}}}}'
legacy_pre="$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_pre_index_commands "$TMP/.silver-bullet.json" graphify)"
legacy_post="$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_post_index_commands "$TMP/.silver-bullet.json" graphify)"
[[ "$legacy_pre" == "graphify install --project" ]] && pass "legacy flat array pre_index" || fail "legacy flat array pre_index"
[[ "$legacy_post" == "graphify claude install --project" ]] && pass "legacy flat array post_index" || fail "legacy flat array post_index"

# Platform artifact paths
[[ "$(SILVER_BULLET_RUNTIME=cursor sb_graphify_platform_artifact_path "$TMP")" == "${TMP}/.cursor/rules/graphify.mdc" ]] && pass "cursor artifact path" || fail "cursor artifact path"
[[ "$(SILVER_BULLET_RUNTIME=codex sb_graphify_platform_artifact_path "$TMP")" == "${TMP}/.codex/hooks.json" ]] && pass "codex artifact path" || fail "codex artifact path"

mkdir -p "$TMP/.cursor/rules"
printf 'graphify query-first\n' >"$TMP/.cursor/rules/graphify.mdc"
sb_graphify_platform_artifact_present "$TMP" cursor && pass "cursor artifact detect" || fail "cursor artifact detect"

# Skill markdown contracts (Phase 1.1 content lives in reference doc after skill split)
INIT_RT_REF="$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md"
assert_grep "silver-init pre_index step" "$INIT_RT_REF" "Step 3b — Skill registration"
assert_grep "silver-init post_index step" "$INIT_RT_REF" "Step 3d — Platform always-on"
assert_grep "silver-init hook install optional" "$INIT_RT_REF" "graphify hook install"
assert_grep "silver-update pre_index retry" "$REPO_ROOT/skills/silver-update/SKILL.md" "Pre-index skill"
assert_grep "docs GRAPHIFY platform table" "$REPO_ROOT/docs/GRAPHIFY.md" "graphify cursor install"
assert_grep "silver-bullet platform order" "$REPO_ROOT/silver-bullet.md" "Pre-index skill"
assert_grep "core-rules platform order" "$REPO_ROOT/hooks/core-rules.md" "graphify cursor install"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
