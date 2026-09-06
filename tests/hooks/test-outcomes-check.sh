#!/usr/bin/env bash
# test-outcomes-check.sh — per-prompt outcome checklist (C-01)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/outcomes-check-${TEST_RUN_ID}"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
mkdir -p "$SB_TEST_DIR"

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/outcomes-check.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

setup() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.planning/workflows"
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<'JSON'
{"sb_initiated":true,"project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]}}
JSON
  cp "$REPO_ROOT/silver-bullet.md" "$TMPDIR_TEST/silver-bullet.md"
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
  export SILVER_BULLET_STATE_FILE="${SB_TEST_DIR}/state-$$"
  export SILVER_BULLET_BRANCH_FILE="${SB_TEST_DIR}/branch-$$"
  printf 'main\n' >"$SILVER_BULLET_BRANCH_FILE"
  : >"$SILVER_BULLET_STATE_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$SILVER_BULLET_STATE_FILE" "$SILVER_BULLET_BRANCH_FILE" \
    "${SB_TEST_DIR}/outcomes-session.json" "${SB_TEST_DIR}/orchestrator-directive.json" \
    "${SB_TEST_DIR}/orchestrator-intent.txt" "${SB_TEST_DIR}/project-root" \
    "${SB_TEST_DIR}/stop-coalesce-block" "${SB_TEST_DIR}/trivial"
}

trap 'rm -rf "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/outcomes-check-${TEST_RUN_ID}" 2>/dev/null || true' EXIT

run_hook() {
  local event="$1" prompt="$2"
  jq -n --arg e "$event" --arg p "$prompt" '{hook_event_name:$e, prompt:$p}' \
    | ( cd "$TMPDIR_TEST" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="${SB_RUNTIME_STATE_DIR}" \
        SILVER_BULLET_STATE_FILE="${SILVER_BULLET_STATE_FILE:-}" bash "$HOOK" 2>/dev/null )
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
composer: /sb:fast
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

setup
printf 'silver-feature\n' >"$SILVER_BULLET_STATE_FILE"
cat >"${SB_TEST_DIR}/outcomes-session.json" <<'JSON'
{"prompt_id":"abc","outcomes":[{"id":"route","status":"pending"},{"id":"scope","status":"pending"},{"id":"verify","status":"pending"}]}
JSON
FAKE_BIN=$(mktemp -d)
cat >"$FAKE_BIN/jq" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$FAKE_BIN/jq"
out=$(cd "$TMPDIR_TEST" && printf '{"hook_event_name":"Stop","prompt":""}' \
  | env PATH="$FAKE_BIN:$PATH" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" SILVER_BULLET_STATE_FILE="$SILVER_BULLET_STATE_FILE" bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q '"decision":"block"'; then
  echo "  ok: outcomes-check Stop fails closed without jq when pending"
  PASS=$((PASS + 1))
else
  echo "  FAIL: outcomes-check Stop should block without jq when pending"
  FAIL=$((FAIL + 1))
fi
rm -rf "$FAKE_BIN"
teardown

setup
# Isolated state dir — preserve pin so runtime-paths.sh does not reset to ~/.codex/.silver-bullet.
RACE_DIR=$(mktemp -d)
export SB_RUNTIME_STATE_DIR="$RACE_DIR"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
run_hook "UserPromptSubmit" "atomic write regression" >/dev/null
source "$REPO_ROOT/hooks/lib/outcomes-gate.sh"
for _ in $(seq 1 20); do
  sb_outcomes_auto_evaluate "silver-feature" "${RACE_DIR}/trivial-missing" 2>&1 || true
done
if ls "${RACE_DIR}/outcomes-session.json.tmp" >/dev/null 2>&1; then
  echo "  FAIL: stale outcomes-session.json.tmp left behind after updates"
  FAIL=$((FAIL + 1))
else
  echo "  ok: outcomes updates avoid fixed .tmp mv race"
  PASS=$((PASS + 1))
fi
route_status=$(jq -r '.outcomes[] | select(.id=="route") | .status' "${RACE_DIR}/outcomes-session.json" 2>/dev/null || echo pending)
if [[ "$route_status" == "done" ]]; then
  echo "  ok: auto-evaluate still marks route outcome done"
  PASS=$((PASS + 1))
else
  echo "  FAIL: route outcome should be done after auto-evaluate (got: $route_status)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$RACE_DIR"
unset SB_RUNTIME_PRESERVE_STATE_DIR
teardown

setup
run_hook "UserPromptSubmit" "What are the remaining deliverables?" >/dev/null
out=$(run_hook "Stop" "")
if printf '%s' "$out" | grep -q '"decision":"block"'; then
  echo "  FAIL: informational query should not block Stop"
  FAIL=$((FAIL + 1))
else
  echo "  ok: informational query does not block Stop"
  PASS=$((PASS + 1))
fi
teardown

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
