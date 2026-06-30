#!/usr/bin/env bash
# Platform-specific agentmemory install contract
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

echo "=== agentmemory platform install contract tests ==="

for host in claude codex cursor opencode goose hermes; do
  if jq -e --arg h "$host" '.recommended_tools.agentmemory.platform_install_commands[$h]' "$TEMPLATE" >/dev/null 2>&1; then
    pass "template has platform_install_commands.${host}"
  else
    fail "template has platform_install_commands.${host}"
  fi
done

claude_post="$(jq -r '.recommended_tools.agentmemory.platform_install_commands.claude.post_index[0]' "$TEMPLATE")"
[[ "$claude_post" == "agentmemory connect claude-code" ]] && pass "claude post_index connect" || fail "claude post_index connect"

codex_pre="$(jq -r '.recommended_tools.agentmemory.platform_install_commands.codex.pre_index[0]' "$TEMPLATE")"
[[ "$codex_pre" == "codex plugin marketplace add rohitg00/agentmemory" ]] && pass "codex pre_index marketplace" || fail "codex pre_index marketplace"

install_cmds="$(jq -r '.recommended_tools.agentmemory.install_commands[]' "$TEMPLATE")"
printf '%s' "$install_cmds" | grep -q 'npm install -g @agentmemory/agentmemory' && pass "template npm install" || fail "template npm install"

write_cfg() { printf '%s' "$1" >"$TMP/.silver-bullet.json"; }
write_cfg "{\"config_version\":\"0.47.1\"}"

post="$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_post_index_commands "$TMP/.silver-bullet.json" agentmemory)"
[[ "$post" == "agentmemory connect claude-code" ]] && pass "claude post_index fallback" || fail "claude post_index fallback"

codex_cmds="$(SILVER_BULLET_RUNTIME=codex sb_recommended_tool_platform_install_commands "$TMP/.silver-bullet.json" agentmemory)"
printf '%s' "$codex_cmds" | grep -q 'codex plugin marketplace add rohitg00/agentmemory' && pass "codex pre_index fallback" || fail "codex pre_index fallback"
printf '%s' "$codex_cmds" | grep -q 'agentmemory connect codex --with-hooks' && pass "codex post_index fallback" || fail "codex post_index fallback"

# shellcheck source=hooks/lib/agentmemory-gate.sh
source "$REPO_ROOT/hooks/lib/agentmemory-gate.sh"
[[ "$(SILVER_BULLET_RUNTIME=cursor sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.cursor/mcp.json" ]] && pass "cursor artifact path" || fail "cursor artifact path"
[[ "$(SILVER_BULLET_RUNTIME=claude sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.claude.json" ]] && pass "claude artifact path" || fail "claude artifact path"
[[ "$(SILVER_BULLET_RUNTIME=codex sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.codex/config.toml" ]] && pass "codex artifact path" || fail "codex artifact path"
[[ "$(SILVER_BULLET_RUNTIME=opencode sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.config/opencode/opencode.json" ]] && pass "opencode artifact path" || fail "opencode artifact path"
[[ "$(SILVER_BULLET_RUNTIME=hermes sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.hermes/config.yaml" ]] && pass "hermes artifact path" || fail "hermes artifact path"
[[ "$(SILVER_BULLET_RUNTIME=goose sb_agentmemory_platform_artifact_path "$TMP")" == "${HOME}/.config/goose/config.yaml" ]] && pass "goose artifact path" || fail "goose artifact path"

assert_grep "silver-init agentmemory section" "$REPO_ROOT/skills/silver-init/references/recommended-tools-opt-in.md" "### 1.1b agentmemory"
assert_grep "silver-update agentmemory retry" "$REPO_ROOT/skills/silver-update/SKILL.md" "Step 8b: agentmemory"
assert_grep "docs AGENTMEMORY" "$REPO_ROOT/docs/AGENTMEMORY.md" "Graphify Synergy"
assert_grep "GRAPHIFY synergy section" "$REPO_ROOT/docs/GRAPHIFY.md" "agentmemory Synergy"
assert_grep "silver-bullet agentmemory mention" "$REPO_ROOT/silver-bullet.md" "docs/AGENTMEMORY.md"
assert_grep "core-rules agentmemory gate" "$REPO_ROOT/hooks/core-rules.md" "agentmemory capture gate"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
