#!/usr/bin/env bash
# Regression coverage for Codex/Kay hook processes that do not pre-seed
# SB_RUNTIME_* env vars before invoking Silver Bullet hooks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if ! printf '%s' "$output" | grep -Fq "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — unexpected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Codex runtime bootstrap tests ==="

TMP_HOME="$(mktemp -d)"
TMP_PROJECT="$(mktemp -d)"
TMP_KAY_HOME=""
cleanup() {
  rm -rf "$TMP_HOME" "$TMP_PROJECT" "${TMP_KAY_HOME:-}"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0"
rsync -a "$REPO_ROOT/hooks" "$TMP_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0/"

cat > "$TMP_PROJECT/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
cat > "$TMP_PROJECT/.silver-bullet.json" <<EOF
{
  "project": { "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates"]
  },
  "state": {
    "state_file": "$TMP_HOME/.codex/.silver-bullet/state",
    "trivial_file": "$TMP_HOME/.codex/.silver-bullet/trivial"
  }
}
EOF
git -C "$TMP_PROJECT" init -q
git -C "$TMP_PROJECT" config user.email "test@test.com"
git -C "$TMP_PROJECT" config user.name "Test"
git -C "$TMP_PROJECT" add silver-bullet.md .silver-bullet.json
git -C "$TMP_PROJECT" commit -q -m "init"
printf 'change\n' > "$TMP_PROJECT/work.txt"

RUNTIME_OUT=$(
  env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_NAME -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PLUGIN_CACHE_ROOT \
    HOME="$TMP_HOME" \
    bash -c 'source "$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0/hooks/lib/runtime-paths.sh"; printf "%s|%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_HOME_ROOT" "$SB_RUNTIME_STATE_DIR"'
)
assert_eq "runtime-paths infers Codex from installed .codex path" "codex|$TMP_HOME/.codex|$TMP_HOME/.codex/.silver-bullet" "$RUNTIME_OUT"

TMP_KAY_HOME="$(mktemp -d)"
KAY_RUNTIME_OUT=$(
  env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_NAME -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PLUGIN_CACHE_ROOT \
    HOME="$TMP_HOME" \
    KAY_HOME="$TMP_KAY_HOME" \
    SILVER_BULLET_RUNTIME=codex \
    bash -c 'source "'"$REPO_ROOT"'/hooks/lib/runtime-paths.sh"; printf "%s|%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_HOME_ROOT" "$SB_RUNTIME_STATE_DIR"'
)
assert_eq "runtime-paths prefers KAY_HOME for isolated Codex runs" "codex|$TMP_KAY_HOME/.codex|$TMP_KAY_HOME/.codex/.silver-bullet" "$KAY_RUNTIME_OUT"

STOP_OUT=$(
  cd "$TMP_PROJECT"
  env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_NAME -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PLUGIN_CACHE_ROOT \
    HOME="$TMP_HOME" \
    bash "$TMP_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0/hooks/stop-check.sh" 2>&1 <<< '{"hook_event_name":"Stop"}'
)
assert_not_contains "stop-check bootstraps runtime vars" "$STOP_OUT" "unbound variable"

AUDIT_OUT=$(
  cd "$TMP_PROJECT"
  env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_NAME -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PLUGIN_CACHE_ROOT \
    HOME="$TMP_HOME" \
    bash "$TMP_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0/hooks/completion-audit.sh" 2>&1 <<< '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
)
assert_not_contains "completion-audit bootstraps runtime vars" "$AUDIT_OUT" "unbound variable"

DEV_OUT=$(
  cd "$TMP_PROJECT"
  env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_NAME -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PLUGIN_CACHE_ROOT \
    HOME="$TMP_HOME" \
    bash "$TMP_HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/0.0.0/hooks/dev-cycle-check.sh" 2>&1 <<< '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf test"}}'
)
assert_not_contains "dev-cycle-check bootstraps runtime vars" "$DEV_OUT" "unbound variable"

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
