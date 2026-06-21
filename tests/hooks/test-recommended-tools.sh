#!/usr/bin/env bash
# Tests for hooks/lib/recommended-tools.sh — consent and enforcement gating
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/recommended-tools.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

# shellcheck source=hooks/lib/recommended-tools.sh
source "$LIB"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

write_cfg() {
  local body="$1"
  printf '%s' "$body" >"$TMP/.silver-bullet.json"
}

echo "=== recommended-tools.sh tests ==="

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":null}}}"
[[ "$(sb_recommended_tool_consent "$TMP/.silver-bullet.json" graphify)" == "pending" ]] && pass "null consent -> pending" || fail "null consent -> pending"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":true}}}"
[[ "$(sb_recommended_tool_consent "$TMP/.silver-bullet.json" graphify)" == "enabled" ]] && pass "true consent -> enabled" || fail "true consent -> enabled"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":false}}}"
[[ "$(sb_recommended_tool_consent "$TMP/.silver-bullet.json" graphify)" == "disabled" ]] && pass "false consent -> disabled" || fail "false consent -> disabled"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"graphify\":{\"required\":false}}"
[[ "$(sb_recommended_tool_consent "$TMP/.silver-bullet.json" graphify)" == "disabled" ]] && pass "legacy graphify.required false -> disabled" || fail "legacy graphify.required false"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"graphify\":{\"required\":true}}"
[[ "$(sb_recommended_tool_consent "$TMP/.silver-bullet.json" graphify)" == "enabled" ]] && pass "legacy graphify.required true -> enabled" || fail "legacy graphify.required true"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":true,\"required_when_enabled\":false}}}"
sb_recommended_tool_enforced "$TMP/.silver-bullet.json" graphify && fail "required_when_enabled false should not enforce" || pass "required_when_enabled false skips enforcement"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":true}}}"
sb_recommended_tool_enforced "$TMP/.silver-bullet.json" graphify && pass "enabled + required_when_enabled default enforces" || fail "enabled enforces"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":true,\"enforcement_suspended\":true}}}"
sb_recommended_tool_enforced "$TMP/.silver-bullet.json" graphify && fail "suspended should not enforce" || pass "suspended skips enforcement despite opt-in"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":true,\"enforcement_suspended\":true,\"install_status\":\"failed\",\"install_failure_reason\":\"uv install failed\"}}}"
block="$(sb_recommended_tool_consent_prompt_block "$TMP/.silver-bullet.json" graphify 2>/dev/null || true)"
printf '%s' "$block" | grep -q 'enforcement suspended' && pass "suspended prompt block" || fail "suspended prompt block"
printf '%s' "$block" | grep -q 'uv install failed' && pass "suspended prompt includes reason" || fail "suspended prompt includes reason"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":null}}}"
block="$(sb_recommended_tool_consent_prompt_block "$TMP/.silver-bullet.json" graphify 2>/dev/null || true)"
printf '%s' "$block" | grep -q 'CONSENT PENDING' && pass "pending prompt block" || fail "pending prompt block"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":false}}}"
block="$(sb_recommended_tool_consent_prompt_block "$TMP/.silver-bullet.json" graphify 2>/dev/null || true)"
printf '%s' "$block" | grep -q 'opted out' && pass "disabled prompt block" || fail "disabled prompt block"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"enabled_by_user\":false}}}"
benefits="$(sb_recommended_tool_benefits "$TMP/.silver-bullet.json" graphify)"
[[ -n "$benefits" ]] && pass "benefits summary non-empty" || fail "benefits summary non-empty"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"graphify\":{\"platform_install_commands\":{\"cursor\":{\"post_index\":[\"graphify cursor install\"]},\"claude\":{\"pre_index\":[\"graphify install --project\"],\"post_index\":[\"graphify claude install --project\"]}}}}}"
[[ "$(SILVER_BULLET_RUNTIME=cursor sb_recommended_tool_platform_post_index_commands "$TMP/.silver-bullet.json" graphify)" == "graphify cursor install" ]] && pass "cursor platform post_index from config" || fail "cursor platform post_index from config"
claude_cmds="$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_install_commands "$TMP/.silver-bullet.json" graphify)"
printf '%s' "$claude_cmds" | grep -q 'graphify install --project' && pass "claude platform install from config" || fail "claude platform install from config"
printf '%s' "$claude_cmds" | grep -q 'graphify claude install --project' && pass "claude always-on install from config" || fail "claude always-on install from config"
[[ "$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_pre_index_commands "$TMP/.silver-bullet.json" graphify)" == "graphify install --project" ]] && pass "claude pre_index from nested config" || fail "claude pre_index from nested config"

[[ "$(SILVER_BULLET_RUNTIME=cursor sb_runtime_host)" == "cursor" ]] && pass "sb_runtime_host cursor" || fail "sb_runtime_host cursor"
[[ "$(SILVER_BULLET_RUNTIME=codex sb_runtime_host)" == "codex" ]] && pass "sb_runtime_host codex" || fail "sb_runtime_host codex"
[[ "$(SILVER_BULLET_RUNTIME=claude sb_runtime_host)" == "claude" ]] && pass "sb_runtime_host claude" || fail "sb_runtime_host claude"
[[ "$( ( unset SILVER_BULLET_RUNTIME; CURSOR_PLUGIN_ROOT=/x/.cursor/plugins sb_runtime_host ) )" == "cursor" ]] && pass "CURSOR_PLUGIN_ROOT -> cursor" || fail "CURSOR_PLUGIN_ROOT -> cursor"

full="$(SILVER_BULLET_RUNTIME=cursor sb_recommended_tool_full_install_lines "$TMP/.silver-bullet.json" graphify)"
printf '%s' "$full" | grep -q 'uv tool install graphifyy' && pass "full install includes CLI" || fail "full install includes CLI"
printf '%s' "$full" | grep -q 'graphify cursor install' && pass "full install includes cursor platform cmd" || fail "full install includes cursor platform cmd"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\"}"
fallback="$(SILVER_BULLET_RUNTIME=codex sb_recommended_tool_platform_install_commands "$TMP/.silver-bullet.json" graphify)"
printf '%s' "$fallback" | grep -q 'graphify install --project --platform codex' && pass "codex fallback platform install" || fail "codex fallback platform install"
printf '%s' "$fallback" | grep -q 'graphify codex install --project' && pass "codex fallback always-on install" || fail "codex fallback always-on install"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
