#!/usr/bin/env bash
# Tests for hooks/lib/agentmemory-gate.sh helpers
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/agentmemory-gate.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

# shellcheck source=hooks/lib/agentmemory-gate.sh
source "$LIB"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

write_cfg() {
  printf '%s' "$1" >"$TMP/.silver-bullet.json"
}

echo "=== agentmemory-gate lib tests ==="

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":true}}}"
sb_agentmemory_command_is_retrieval 'curl -s -X POST http://localhost:3111/agentmemory/smart-search -d "{}"' && pass "curl smart-search is retrieval" || fail "curl smart-search is retrieval"

sb_agentmemory_command_is_retrieval 'git status' && fail "git status not retrieval" || pass "git status not retrieval"

sb_agentmemory_command_is_exempt 'npm install -g @agentmemory/agentmemory' && pass "npm install exempt" || fail "npm install exempt"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":true,\"export_root\":\".agentmemory\"}}}"
mkdir -p "$TMP/.agentmemory/memory"
sb_agentmemory_export_exists "$TMP" "$TMP/.silver-bullet.json" && pass "export root detect" || fail "export root detect"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":true,\"export_root\":\"../../tmp/am-traversal-$$\"}}}"
! sb_agentmemory_scaffold_export_root "$TMP" "$TMP/.silver-bullet.json" 2>/dev/null \
  && pass "export scaffold blocks traversal" || fail "export scaffold blocks traversal"
[[ ! -d "/tmp/am-traversal-$$" ]] && pass "traversal target not created" || fail "traversal target not created"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":true,\"export_root\":\".agentmemory\"}}}"

sb_agentmemory_edit_path_is_exempt ".agentmemory/memory/foo.md" "$TMP/.silver-bullet.json" && pass "edit path exempt under export" || fail "edit path exempt"

benefits="$(sb_recommended_tool_benefits "$TMP/.silver-bullet.json" agentmemory)"
printf '%s' "$benefits" | grep -q 'Graphify' && pass "agentmemory benefits mention Graphify" || fail "agentmemory benefits"

write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":null}}}"
block="$(sb_recommended_tool_consent_prompt_block "$TMP/.silver-bullet.json" agentmemory 2>/dev/null || true)"
printf '%s' "$block" | grep -q 'CONSENT PENDING' && pass "agentmemory pending prompt" || fail "agentmemory pending prompt"

# #276: usage_state_file with ${SB_RUNTIME_HOME_ROOT} must expand to an absolute path
export SB_RUNTIME_HOME_ROOT="${TMP}/runtime-home"
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_RUNTIME_STATE_DIR"
write_cfg "{\"config_version\":\"${CURRENT_CONFIG_VERSION}\",\"recommended_tools\":{\"agentmemory\":{\"enabled_by_user\":true,\"usage_state_file\":\"\${SB_RUNTIME_HOME_ROOT}/.silver-bullet/agentmemory-usage\"}}}"
resolved="$(sb_agentmemory_usage_state_path "$TMP/.silver-bullet.json")"
if [[ "$resolved" == /* && "$resolved" != *'${'* ]]; then
  pass "usage_state_path expands SB_RUNTIME_HOME_ROOT (#276)"
else
  fail "usage_state_path expands SB_RUNTIME_HOME_ROOT (#276) got: $resolved"
fi
if [[ "$resolved" == "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/agentmemory-usage" ]]; then
  pass "usage_state_path resolves to runtime home agentmemory-usage (#276)"
else
  fail "usage_state_path resolves to runtime home agentmemory-usage (#276) got: $resolved"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
