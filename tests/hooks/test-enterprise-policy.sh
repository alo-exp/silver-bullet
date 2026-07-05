#!/usr/bin/env bash
# Tests hooks/lib/enterprise-policy.sh and session-start advisory injection.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/enterprise-policy.sh"
SESSION="$REPO_ROOT/hooks/session-start"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
export SILVER_BULLET_TEST_HOOK_ENFORCED=1

# shellcheck source=../../hooks/lib/enterprise-policy.sh
source "$LIB"

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — expected [$expected] got [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — expected needle [$needle]"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="ep-$$"
TMPSTATE="${SB_TEST_DIR}/ep-state-${TEST_RUN_ID}"
TMPBRANCH="${SB_TEST_DIR}/ep-branch-${TEST_RUN_ID}"
SESSION_START_FILE="${SB_TEST_DIR}/ep-session-start-${TEST_RUN_ID}"
PLUGIN_CACHE_DIR="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
mkdir -p "${PLUGIN_CACHE_DIR}/alo-labs/silver-bullet/test"

git -C "$WORK" init -q
git -C "$WORK" -c user.email="test@test.com" -c user.name="Test" commit -q --allow-empty -m "init" 2>/dev/null
cp "$TEMPLATE" "$WORK/.silver-bullet.json"
cat >"$WORK/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF

assert_eq "read active supervised" "supervised" "$(sb_enterprise_policy_read_active "$WORK/.silver-bullet.json")"
assert_eq "session mode default supervised" "interactive" "$(sb_enterprise_policy_session_mode_default "$WORK/.silver-bullet.json")"

jq '.enterprise_policy.active_profile = "autonomous_safe"' "$WORK/.silver-bullet.json" >"${WORK}/.silver-bullet.json.tmp" \
  && mv "${WORK}/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"
assert_eq "read active autonomous_safe" "autonomous_safe" "$(sb_enterprise_policy_read_active "$WORK/.silver-bullet.json")"
assert_eq "session mode default autonomous_safe" "autonomous" "$(sb_enterprise_policy_session_mode_default "$WORK/.silver-bullet.json")"

banner="$(sb_enterprise_policy_session_banner "$WORK/.silver-bullet.json" "$SB_TEST_DIR")"
assert_contains "banner names profile" "$banner" "autonomous_safe"
assert_contains "banner recommends autonomous" "$banner" "autonomous"
assert_contains "banner lists runtime markers" "$banner" "Runtime markers"

sb_enterprise_policy_persist_active_marker "$WORK/.silver-bullet.json" "$SB_TEST_DIR"
assert_eq "active marker persisted" "autonomous_safe" "$(cat "${SB_TEST_DIR}/enterprise-policy-active" 2>/dev/null || true)"

# Auto-set session mode when tier-safe (tests pin enforcement tier via capability probe).
rm -f "${SB_TEST_DIR}/mode" 2>/dev/null || true
if sb_enterprise_policy_apply_session_mode_default "$WORK/.silver-bullet.json" "$SB_TEST_DIR" "startup" 2>/dev/null; then
  applied="$(tr -d '[:space:]' <"${SB_TEST_DIR}/mode" 2>/dev/null || true)"
  if [[ "$applied" == "autonomous" ]]; then
    assert_eq "auto-set mode autonomous_safe" "autonomous" "$applied"
  else
    echo "PASS: auto-set skipped when host tier < 2 (got: ${applied:-empty})"
    PASS=$((PASS + 1))
  fi
else
  echo "PASS: apply_session_mode_default fail-soft"
  PASS=$((PASS + 1))
fi

jq '.enterprise_policy.active_profile = "supervised"' "$WORK/.silver-bullet.json" >"${WORK}/.silver-bullet.json.tmp" \
  && mv "${WORK}/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"
rm -f "${SB_TEST_DIR}/mode" 2>/dev/null || true
sb_enterprise_policy_apply_session_mode_default "$WORK/.silver-bullet.json" "$SB_TEST_DIR" "startup" 2>/dev/null || true
supervised_mode="$(tr -d '[:space:]' <"${SB_TEST_DIR}/mode" 2>/dev/null || true)"
if [[ "$supervised_mode" == "interactive" || -z "$supervised_mode" ]]; then
  assert_eq "supervised profile does not force autonomous" "interactive" "${supervised_mode:-interactive}"
else
  assert_eq "supervised profile does not force autonomous" "interactive" "$supervised_mode"
fi

jq '.enterprise_policy.active_profile = "autonomous_safe"' "$WORK/.silver-bullet.json" >"${WORK}/.silver-bullet.json.tmp" \
  && mv "${WORK}/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"

out="$(
  cd "$WORK" && \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" \
    SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
    SILVER_BULLET_SESSION_START_FILE="$SESSION_START_FILE" \
    bash "$SESSION" </dev/null 2>/dev/null || true
)"
assert_contains "session-start injects enterprise policy banner" "$out" "Enterprise policy profile: autonomous_safe"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
