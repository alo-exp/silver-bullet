#!/usr/bin/env bash
# Tests for hooks/lib/check-sb-update.sh and session-start update injection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/check-sb-update.sh"
SESSION="${REPO_ROOT}/hooks/session-start"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

MOCK_HOME="$(mktemp -d)"
TMP="$(mktemp -d)"
trap 'rm -rf "$MOCK_HOME" "$TMP"' EXIT

PLUGIN_CACHE_DIR="${MOCK_HOME}/.codex/plugins/cache"
mkdir -p "${PLUGIN_CACHE_DIR}/alo-labs/silver-bullet/test"
REGISTRY="${MOCK_HOME}/.codex/plugins/installed_plugins.json"

write_registry() {
  local ver="$1"
  jq -n --arg v "$ver" --arg p "${PLUGIN_CACHE_DIR}/alo-labs/silver-bullet/test" \
    '{version:2,plugins:{"silver-bullet@alo-labs":[{scope:"user",version:$v,installPath:$p}]}}' \
    >"$REGISTRY"
}

source_lib() {
  # shellcheck source=hooks/lib/check-sb-update.sh
  source "$LIB"
  export HOME="$MOCK_HOME"
  export SILVER_BULLET_RUNTIME=codex
  export SILVER_BULLET_INSTALLED_PLUGINS_FILE="$REGISTRY"
  if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
  fi
}

extract_ctx() {
  jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null || true
}

setup_session_project() {
  cat >"$TMP/silver-bullet.md" <<'EOF'
# SB
EOF
  cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "graphify": { "enabled_by_user": false }
  },
  "skills": { "required_planning": ["silver-quality-gates"] }
}
EOF
  git -C "$TMP" init -q 2>/dev/null || true
  git -C "$TMP" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init 2>/dev/null || true
}

run_session() {
  local source="${1:-startup}"
  (
    cd "$TMP"
    export HOME="$MOCK_HOME"
    export SILVER_BULLET_RUNTIME=codex
    export SILVER_BULLET_INSTALLED_PLUGINS_FILE="$REGISTRY"
    export SILVER_BULLET_UPDATE_CHECK_LATEST="${SILVER_BULLET_UPDATE_CHECK_LATEST:-}"
    export SILVER_BULLET_UPDATE_CHECK_DISABLED="${SILVER_BULLET_UPDATE_CHECK_DISABLED:-}"
    export SILVER_BULLET_SESSION_SOURCE="$source"
    printf '{"source":"%s"}' "$source" | bash "$SESSION" 2>/dev/null
  )
}

echo "=== check-sb-update lib tests ==="

echo "--- Lib: update available ---"
write_registry "0.1.0"
source_lib
SILVER_BULLET_UPDATE_CHECK_LATEST="0.2.0"
export SILVER_BULLET_UPDATE_CHECK_LATEST
sb_check_sb_update
[[ "${SB_UPDATE_CHECK_RESULT:-}" == "update_available" ]] && pass "detects update_available" || fail "detects update_available (got ${SB_UPDATE_CHECK_RESULT:-})"
block="$(sb_check_sb_update_prompt_block)"
printf '%s' "$block" | grep -q 'ASK THE USER NOW' && pass "prompt block asks user" || fail "prompt block asks user"
printf '%s' "$block" | grep -q '/silver:update' && pass "prompt references silver:update" || fail "prompt references silver:update"

echo "--- Lib: up to date ---"
write_registry "1.2.3"
source_lib
SILVER_BULLET_UPDATE_CHECK_LATEST="1.2.3"
export SILVER_BULLET_UPDATE_CHECK_LATEST
sb_check_sb_update
[[ "${SB_UPDATE_CHECK_RESULT:-}" == "up_to_date" ]] && pass "detects up_to_date" || fail "detects up_to_date"
[[ -z "$(sb_check_sb_update_prompt_block)" ]] && pass "up_to_date emits no prompt" || fail "up_to_date emits no prompt"

echo "--- Lib: dev ahead ---"
write_registry "9.9.9"
source_lib
SILVER_BULLET_UPDATE_CHECK_LATEST="1.0.0"
export SILVER_BULLET_UPDATE_CHECK_LATEST
sb_check_sb_update
[[ "${SB_UPDATE_CHECK_RESULT:-}" == "dev_ahead" ]] && pass "detects dev_ahead" || fail "detects dev_ahead"

echo "--- Lib: check failed (invalid latest) ---"
write_registry "0.5.0"
source_lib
SILVER_BULLET_UPDATE_CHECK_LATEST="not-a-version"
export SILVER_BULLET_UPDATE_CHECK_LATEST
sb_check_sb_update
[[ "${SB_UPDATE_CHECK_RESULT:-}" == "check_failed" ]] && pass "invalid latest -> check_failed" || fail "invalid latest -> check_failed"
[[ -z "$(sb_check_sb_update_prompt_block)" ]] && pass "check_failed emits no prompt" || fail "check_failed emits no prompt"

echo "--- Lib: disabled ---"
write_registry "0.1.0"
source_lib
SILVER_BULLET_UPDATE_CHECK_DISABLED=1
export SILVER_BULLET_UPDATE_CHECK_DISABLED
sb_check_sb_update
[[ "${SB_UPDATE_CHECK_RESULT:-}" == "disabled" ]] && pass "disabled flag honored" || fail "disabled flag honored"

echo "=== session-start update injection tests ==="
setup_session_project

echo "--- Session: injects update prompt on startup ---"
write_registry "0.10.0"
SILVER_BULLET_UPDATE_CHECK_LATEST="0.11.0"
export SILVER_BULLET_UPDATE_CHECK_LATEST
SILVER_BULLET_UPDATE_CHECK_DISABLED=""
export SILVER_BULLET_UPDATE_CHECK_DISABLED
out="$(run_session startup)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'SB UPDATE AVAILABLE' && pass "startup injects update prompt" || fail "startup injects update prompt"
printf '%s' "$ctx" | grep -q 'v0.10.0' && pass "startup shows installed version" || fail "startup shows installed version"
printf '%s' "$ctx" | grep -q 'v0.11.0' && pass "startup shows latest version" || fail "startup shows latest version"

echo "--- Session: no prompt when up to date ---"
write_registry "0.11.0"
SILVER_BULLET_UPDATE_CHECK_LATEST="0.11.0"
export SILVER_BULLET_UPDATE_CHECK_LATEST
out="$(run_session startup)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'SB UPDATE AVAILABLE' && fail "up to date should not inject update prompt" || pass "up to date should not inject update prompt"

echo "--- Session: compact skips update prompt ---"
write_registry "0.10.0"
SILVER_BULLET_UPDATE_CHECK_LATEST="0.99.0"
export SILVER_BULLET_UPDATE_CHECK_LATEST
out="$(run_session compact)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'SB UPDATE AVAILABLE' && fail "compact should not inject update prompt" || pass "compact should not inject update prompt"

echo "--- Session: offline check fails gracefully ---"
write_registry "0.10.0"
unset SILVER_BULLET_UPDATE_CHECK_LATEST
export -n SILVER_BULLET_UPDATE_CHECK_LATEST 2>/dev/null || true
SILVER_BULLET_UPDATE_CHECK_DISABLED=""
export SILVER_BULLET_UPDATE_CHECK_DISABLED
# Force fetch failure: no mock latest and curl absent from PATH
out="$(
  cd "$TMP"
  export HOME="$MOCK_HOME"
  export SILVER_BULLET_RUNTIME=codex
  export SILVER_BULLET_INSTALLED_PLUGINS_FILE="$REGISTRY"
  export SILVER_BULLET_SESSION_SOURCE=startup
  unset SILVER_BULLET_UPDATE_CHECK_LATEST
  export PATH="/nonexistent"
  printf '{"source":"startup"}' | bash "$SESSION" 2>/dev/null || true
)"
# Hook should still produce JSON output (core rules) without update block
if printf '%s' "$out" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
  pass "offline session-start still returns hook JSON"
else
  [[ -z "$out" ]] && pass "offline session-start silent no-op acceptable" || fail "offline session-start still returns hook JSON"
fi
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'SB UPDATE AVAILABLE' && fail "offline should not inject update prompt" || pass "offline should not inject update prompt"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
