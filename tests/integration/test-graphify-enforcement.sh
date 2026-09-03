#!/usr/bin/env bash
# Integration: graphify gate + record + prompt-reminder + session-start branch reset
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/hooks/graphify-gate.sh"
RECORD="$REPO_ROOT/hooks/record-graphify-query.sh"
PROMPT="$REPO_ROOT/hooks/prompt-reminder.sh"
SESSION="$REPO_ROOT/hooks/session-start"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
MOCK_BIN=""

cleanup() {
  rm -rf "$TMP" "$MOCK_BIN" \
    "${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/branch-${TEST_RUN_ID}"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
GRAPHIFY_STATE="${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
BRANCH_FILE="${SB_TEST_DIR}/branch-${TEST_RUN_ID}"
MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/graphify" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/graphify"
export PATH="$MOCK_BIN:$PATH"

cat >"$TMP/silver-bullet.md" <<'EOF'
# SB
EOF
cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "graphify": {
      "enabled_by_user": true,
      "query_state_file": "${GRAPHIFY_STATE}"
    }
  },
  "skills": { "required_planning": ["silver-quality-gates"], "required_deploy": ["silver-quality-gates"] },
  "state": { "state_file": "${SB_TEST_DIR}/state-${TEST_RUN_ID}", "trivial_file": "${SB_TEST_DIR}/trivial-${TEST_RUN_ID}" }
}
EOF
mkdir -p "$TMP/graphify-out" "$TMP/src"
touch "$TMP/graphify-out/graph.json" "$TMP/src/main.sh"
git -C "$TMP" init -q
git -C "$TMP" config user.email "t@t.com"
git -C "$TMP" config user.name "T"
git -C "$TMP" checkout -q -b feature/a 2>/dev/null || true

export SILVER_BULLET_BRANCH_FILE="$BRANCH_FILE"
export SILVER_BULLET_STATE_FILE="${SB_TEST_DIR}/state-${TEST_RUN_ID}"
export SILVER_BULLET_PROJECT_ROOT="$TMP"
rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true

echo "=== graphify enforcement integration ==="

edit_in='{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"src/main.sh","old_string":"a","new_string":"b"}}'
deny="$(cd "$TMP" && printf '%s' "$edit_in" | bash "$GATE" 2>/dev/null)"
if printf '%s' "$deny" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null; then
  pass "integration: edit blocked without query"
else
  fail "integration: edit blocked without query"
fi

rec_in='{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"graphify query \"src main\" --graph graphify-out/graph.json"},"tool_response":{"exit_code":0}}'
(cd "$TMP" && printf '%s' "$rec_in" | bash "$RECORD" >/dev/null 2>&1)
allow="$(cd "$TMP" && printf '%s' "$edit_in" | bash "$GATE" 2>/dev/null)"
if [[ -z "$allow" ]] || ! printf '%s' "$allow" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then
  pass "integration: edit allowed after query recorded"
else
  fail "integration: edit allowed after query recorded"
fi

prompt_out="$(cd "$TMP" && export SILVER_BULLET_PROJECT_ROOT="$TMP" && jq -n '{hook_event_name:"UserPromptSubmit",prompt:"ship"}' | bash "$PROMPT" 2>/dev/null)"
ctx="$(printf '%s' "$prompt_out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null || true)"
if printf '%s' "$ctx" | grep -q 'fresh query recorded'; then
  pass "integration: prompt-reminder reports fresh query"
else
  fail "integration: prompt-reminder reports fresh query"
fi

printf 'feature/a\n' >"$BRANCH_FILE"
git -C "$TMP" checkout -q -b feature/b 2>/dev/null || git -C "$TMP" checkout -q feature/b
export SILVER_BULLET_SESSION_SOURCE=startup
(cd "$TMP" && export SILVER_BULLET_PROJECT_ROOT="$TMP" && printf '{"source":"startup"}' | bash "$SESSION" >/dev/null 2>&1 || true)
if [[ ! -f "$GRAPHIFY_STATE" ]]; then
  pass "integration: branch change clears graphify query state"
else
  fail "integration: branch change clears graphify query state"
fi

# Opted out: gate should not block
cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": { "graphify": { "enabled_by_user": false } },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": { "state_file": "${SB_TEST_DIR}/state-${TEST_RUN_ID}" }
}
EOF
rm -f "$GRAPHIFY_STATE"
allow_out="$(cd "$TMP" && printf '%s' "$edit_in" | bash "$GATE" 2>/dev/null)"
if [[ -z "$allow_out" ]] || ! printf '%s' "$allow_out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then
  pass "integration: opted out allows edit without query"
else
  fail "integration: opted out allows edit without query"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
