#!/usr/bin/env bash
# Tests for orchestrator parent mode guard (parent blocks Edit, allows Task).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO_ROOT/hooks/orchestrator-directive-guard.sh"
LIB_PARENT="$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
LIB_OD="$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME

TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/orchestrator-guard-${TEST_RUN_ID}"
SB_TEST_DIR="$SB_RUNTIME_STATE_DIR"
mkdir -p "$SB_TEST_DIR"
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
export SB_ORCHESTRATOR_PARENT=1
unset SB_ORCHESTRATOR_WORKER 2>/dev/null || true

cleanup() {
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/orchestrator-directive.json" "${SB_TEST_DIR}/orchestrator-worker-active.json" 2>/dev/null || true
  rm -rf "$WORK" 2>/dev/null || true
  rm -rf "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/orchestrator-guard-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup EXIT

assert_contains() {
  local name="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (missing: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

assert_empty() {
  local name="$1" hay="$2"
  if [[ -z "$hay" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected empty, got: $hay)"
    FAIL=$((FAIL + 1))
  fi
}

# shellcheck source=../../hooks/lib/orchestrator-directive.sh
source "$LIB_OD"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$LIB_PARENT"

make_repo() {
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK/.silver-bullet.json"
  echo '# SB' >"$WORK/silver-bullet.md"
  mkdir -p "$WORK/.planning/workflows"
}

sb_orchestrator_directive_write "silver-plan" "intent" "parent test" true "PLAN"

make_repo
out=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks Edit" "$out" "ORCHESTRATOR PARENT"

out_task=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"description":"worker"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows Task" "$out_task"

assert_true_marker=false
[[ -f "${SB_TEST_DIR}/orchestrator-worker-active.json" ]] && assert_true_marker=true
if $assert_true_marker; then
  echo "PASS: Task spawn writes worker marker"
  PASS=$((PASS + 1))
else
  echo "FAIL: Task spawn writes worker marker"
  FAIL=$((FAIL + 1))
fi

out_skill=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-plan"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks direct flow skill" "$out_skill" "ORCHESTRATOR PARENT"

# Worker detected via marker file without SB_ORCHESTRATOR_WORKER env
WORK2=$(mktemp -d)
git -C "$WORK2" init -q
echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK2/.silver-bullet.json"
echo '# SB' >"$WORK2/silver-bullet.md"
mkdir -p "$WORK2/.planning/workflows"
jq -n --arg at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '{skill:"silver-plan",template:"PLAN",spawned_at:$at}' \
  >"${SB_TEST_DIR}/orchestrator-worker-active.json"
out_worker=$(cd "$WORK2" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | env -u SB_ORCHESTRATOR_PARENT -u SB_ORCHESTRATOR_WORKER \
  SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
if printf '%s' "$out_worker" | grep -qF 'ORCHESTRATOR PARENT'; then
  echo "FAIL: worker marker without env should not get parent block"
  FAIL=$((FAIL + 1))
else
  echo "PASS: worker marker without env treated as worker"
  PASS=$((PASS + 1))
fi
rm -rf "$WORK2" 2>/dev/null || true

# Worker marker readable without jq on PATH
WORK3=$(mktemp -d)
git -C "$WORK3" init -q
echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK3/.silver-bullet.json"
echo '# SB' >"$WORK3/silver-bullet.md"
printf '{"skill":"silver-plan","template":"PLAN","spawned_at":"%s"}\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  >"${SB_TEST_DIR}/orchestrator-worker-active.json"
FAKE_BIN=$(mktemp -d)
cat >"$FAKE_BIN/jq" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$FAKE_BIN/jq"
PATH="$FAKE_BIN:$PATH"
export PATH
unset SB_ORCHESTRATOR_PARENT SB_ORCHESTRATOR_WORKER 2>/dev/null || true
if sb_orchestrator_is_worker_session; then
  echo "PASS: worker marker detected without jq"
  PASS=$((PASS + 1))
else
  echo "FAIL: worker marker should be detected without jq"
  FAIL=$((FAIL + 1))
fi
rm -rf "$FAKE_BIN"
rm -rf "$WORK3" 2>/dev/null || true

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
