#!/usr/bin/env bash
# test-outcomes-check.sh — per-prompt outcome checklist (C-01)
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/outcomes-check.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"

setup() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.planning/workflows"
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<'JSON'
{"sb_initiated":true,"project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]}}
JSON
  cp "$REPO_ROOT/silver-bullet.md" "$TMPDIR_TEST/silver-bullet.md"
  export SILVER_BULLET_STATE_FILE="${SB_TEST_DIR}/state-$$"
  export SILVER_BULLET_BRANCH_FILE="${SB_TEST_DIR}/branch-$$"
  printf 'main\n' >"$SILVER_BULLET_BRANCH_FILE"
  : >"$SILVER_BULLET_STATE_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$SILVER_BULLET_STATE_FILE" "$SILVER_BULLET_BRANCH_FILE" \
    "${SB_TEST_DIR}/outcomes-session.json"
}

run_hook() {
  local event="$1" prompt="$2"
  jq -n --arg e "$event" --arg p "$prompt" '{hook_event_name:$e, prompt:$p}' \
    | ( cd "$TMPDIR_TEST" && bash "$HOOK" 2>/dev/null )
}

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "--- outcomes-check ---"
setup
out=$(run_hook "UserPromptSubmit" "fix the login bug")
assert_contains "UserPromptSubmit seeds outcomes context" "$out" "Outstanding per-prompt outcomes"
teardown

setup
run_hook "UserPromptSubmit" "add caching layer" >/dev/null
printf 'silver-quality-gates\n' >"$SILVER_BULLET_STATE_FILE"
out=$(run_hook "Stop" "")
if printf '%s' "$out" | grep -q '"decision":"block"'; then
  echo "  ok: Stop blocks when outcomes incomplete"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Stop should block incomplete outcomes"
  FAIL=$((FAIL + 1))
fi
teardown

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
