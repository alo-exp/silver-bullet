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
  export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
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

setup
run_hook "UserPromptSubmit" "ship the feature" >/dev/null
printf 'silver-feature\nsilver-quality-gates\n' >"$SILVER_BULLET_STATE_FILE"
out=$(run_hook "Stop" "")
if printf '%s' "$out" | grep -q '"decision":"block"'; then
  echo "  ok: route via composer alone does not auto-complete outcomes without scope/verify"
  PASS=$((PASS + 1))
else
  echo "  FAIL: composer marker without scope/verify should still block"
  FAIL=$((FAIL + 1))
fi
teardown

setup
run_hook "UserPromptSubmit" "define caching scope" >/dev/null
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat >"$TMPDIR_TEST/.planning/workflows/wf-1.md" <<'MD'
# Workflow
composer: /silver:fast
args: add redis cache
MD
# shellcheck source=../../hooks/lib/outcomes-gate.sh
source "$REPO_ROOT/hooks/lib/outcomes-gate.sh"
(
  cd "$TMPDIR_TEST"
  sb_outcomes_auto_evaluate "silver-fast" "${SB_TEST_DIR}/trivial-missing"
)
scope_status=$(jq -r '.outcomes[] | select(.id=="scope") | .status' "${SB_TEST_DIR}/outcomes-session.json")
if [[ "$scope_status" == "done" ]]; then
  echo "  ok: composed workflow metadata satisfies scope outcome"
  PASS=$((PASS + 1))
else
  echo "  FAIL: composed workflow metadata should satisfy scope outcome (got: $scope_status)"
  FAIL=$((FAIL + 1))
fi
teardown

setup
run_hook "UserPromptSubmit" "quick typo fix" >/dev/null
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/PLAN.md" <<'MD'
# Plan
Just some notes without structured scope.
MD
source "$REPO_ROOT/hooks/lib/outcomes-gate.sh"
(
  cd "$TMPDIR_TEST"
  sb_outcomes_auto_evaluate "noop" "${SB_TEST_DIR}/trivial-missing"
)
scope_status=$(jq -r '.outcomes[] | select(.id=="scope") | .status' "${SB_TEST_DIR}/outcomes-session.json")
if [[ "$scope_status" != "done" ]]; then
  echo "  ok: hollow PLAN.md does not satisfy scope outcome"
  PASS=$((PASS + 1))
else
  echo "  FAIL: hollow PLAN.md should not satisfy scope outcome"
  FAIL=$((FAIL + 1))
fi
teardown

setup
cat >"${SB_TEST_DIR}/outcomes-session.json" <<'JSON'
{"prompt_id":"abc","outcomes":[{"id":"route","status":"pending"},{"id":"scope","status":"pending"},{"id":"verify","status":"pending"}]}
JSON
source "$REPO_ROOT/hooks/lib/outcomes-gate.sh"
FAKE_BIN=$(mktemp -d)
cat >"$FAKE_BIN/jq" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$FAKE_BIN/jq"
PATH="$FAKE_BIN:$PATH"
export PATH
if sb_outcomes_all_done; then
  echo "  FAIL: outcomes gate should block without jq when pending outcomes exist"
  FAIL=$((FAIL + 1))
else
  echo "  ok: outcomes gate fails closed without jq when session has pending items"
  PASS=$((PASS + 1))
fi
rm -rf "$FAKE_BIN"
teardown

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
