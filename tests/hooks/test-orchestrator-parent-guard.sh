#!/usr/bin/env bash
# Tests for orchestrator parent mode guard (parent blocks Edit/Bash, allows Task).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

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
  if grep -qF "$needle" <<<"$hay"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (missing: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_parent_block() { # name output: a worker may still be held to the directive, never to parent mode
  if grep -qF 'ORCHESTRATOR PARENT' <<<"$2"; then
    echo "FAIL: $1 (got a parent-mode block: $2)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $1"
    PASS=$((PASS + 1))
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

out_bash=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm run build"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks non-readonly Bash" "$out_bash" "ORCHESTRATOR PARENT"

# Bootstrap scaffold: template copied before sb_initiated is true — parent guard must stay inert
WORK_BOOT=$(mktemp -d)
git -C "$WORK_BOOT" init -q
echo '{"sb_initiated":false,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK_BOOT/.silver-bullet.json"
echo '# SB' >"$WORK_BOOT/silver-bullet.md"
out_boot=$(cd "$WORK_BOOT" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent guard inert during bootstrap when sb_initiated false" "$out_boot"
rm -rf "$WORK_BOOT" 2>/dev/null || true

out_task=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"description":"worker"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows Task" "$out_task"

out_agent=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"description":"worker"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows Agent (#229)" "$out_agent"

out_spawn=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"multi_agent_v1.spawn_agent","tool_input":{"description":"worker"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows Codex spawn_agent" "$out_spawn"

out_invoke=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"bash /path/to/silver-bullet invoke-skill sb '\''$silver ship readiness'\''"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows Codex invoke-skill sb adapter" "$out_invoke"

out_invoke_flow=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"silver-bullet invoke-skill sb:plan"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks invoke-skill flow skill" "$out_invoke_flow" "ORCHESTRATOR PARENT"

out_readonly=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat .silver-bullet/orchestrator-directive.json"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows read-only Bash" "$out_readonly"

out_graphify=$(cd "$WORK" && jq -n '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"graphify query \"parent friction 258\""}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows graphify query (#258)" "$out_graphify"

out_graphify_update=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"graphify update ."}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks graphify update" "$out_graphify_update" "ORCHESTRATOR PARENT"

out_resolve=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"bash scripts/resolve-instruction-ledger.sh list"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "parent allows resolve-instruction-ledger (#264)" "$out_resolve"

out_write_bash=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo test > foo.txt"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_RUNTIME=codex SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "parent blocks write Bash" "$out_write_bash" "ORCHESTRATOR PARENT"

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

# Worker identity is the payload's agent_id (R4-02); the spawn record file confers nothing.
WORK2=$(mktemp -d)
git -C "$WORK2" init -q
echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK2/.silver-bullet.json"
echo '# SB' >"$WORK2/silver-bullet.md"
mkdir -p "$WORK2/.planning/workflows"
run_guard() { # run_guard WORKDIR PAYLOAD
  (cd "$1" && printf '%s' "$2" | env -u SB_ORCHESTRATOR_PARENT -u SB_ORCHESTRATOR_WORKER \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
}
EDIT_PARENT='{"hook_event_name":"PreToolUse","tool_name":"Edit","session_id":"main","tool_input":{}}'
EDIT_WORKER='{"hook_event_name":"PreToolUse","tool_name":"Edit","session_id":"main","agent_id":"agent-A","agent_type":"general-purpose","tool_input":{}}'
BASH_WORKER='{"hook_event_name":"PreToolUse","tool_name":"Bash","agent_id":"agent-A","tool_input":{"command":"gh issue create"}}'
assert_contains "parent Edit is denied" "$(run_guard "$WORK2" "$EDIT_PARENT")" "ORCHESTRATOR PARENT"
assert_not_parent_block "payload with agent_id is a worker: no parent-mode block" "$(run_guard "$WORK2" "$EDIT_WORKER")"
out_worker_bash=$(run_guard "$WORK2" "$BASH_WORKER")
if grep -qF 'ORCHESTRATOR DIRECTIVE' <<<"$out_worker_bash"; then
  echo "FAIL: worker should allow Bash without directive skill recorded"
  FAIL=$((FAIL + 1))
else
  echo "PASS: worker allows Bash when directive pending"
  PASS=$((PASS + 1))
fi

# R4-02: a parent Agent spawn must not turn the parent into a worker.
run_guard "$WORK2" '{"hook_event_name":"PreToolUse","tool_name":"Agent","session_id":"main","tool_input":{"description":"look around"}}' >/dev/null
assert_contains "after spawning, the parent Edit is still denied" "$(run_guard "$WORK2" "$EDIT_PARENT")" "ORCHESTRATOR PARENT"
assert_contains "after spawning, the parent Bash is still denied" "$(run_guard "$WORK2" '{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"main","tool_input":{"command":"git commit -am x"}}')" "ORCHESTRATOR PARENT"
# A forged marker file confers nothing.
printf '{"spawned_at":"%s"}\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >"${SB_TEST_DIR}/orchestrator-worker-active.json"
assert_contains "forged marker: parent Edit still denied" "$(run_guard "$WORK2" "$EDIT_PARENT")" "ORCHESTRATOR PARENT"
# Pending blocking directive: a spawn does not open the parent's Bash either.
printf '{"next_skill":"silver-plan","blocking":true,"reason":"r"}\n' >"${SB_TEST_DIR}/orchestrator-directive.json"
assert_contains "pending directive + spawn: parent Bash denied" "$(run_guard "$WORK2" '{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"main","tool_input":{"command":"rm -rf src && git commit -am x"}}')" "ORCHESTRATOR PARENT"
# Two parallel workers: one worker finishing (SubagentStop) leaves the other classified as a worker.
STOP_A='{"hook_event_name":"SubagentStop","agent_id":"agent-A","session_id":"main"}'
(cd "$WORK2" && printf '%s' "$STOP_A" | SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$REPO_ROOT/hooks/stop-check.sh" >/dev/null 2>&1 || true)
EDIT_WORKER_B='{"hook_event_name":"PreToolUse","tool_name":"Edit","session_id":"main","agent_id":"agent-B","tool_input":{}}'
assert_not_parent_block "worker B still a worker after worker A stopped" "$(run_guard "$WORK2" "$EDIT_WORKER_B")"
assert_contains "the parent is still denied after worker A stopped" "$(run_guard "$WORK2" "$EDIT_PARENT")" "ORCHESTRATOR PARENT"
rm -f "${SB_TEST_DIR}/orchestrator-worker-active.json" "${SB_TEST_DIR}/orchestrator-directive.json"
rm -rf "$WORK2" 2>/dev/null || true

# Delegate wrapper: stage 6 requires DIRECT_FALLBACK (default-on V2)
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_DIRECT_FALLBACK
if sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-codex-delegate.sh --work-dir /tmp'; then
  echo "FAIL: unset V2 must block direct delegate without fallback"
  FAIL=$((FAIL + 1))
else
  echo "PASS: unset V2 blocks direct delegate without fallback (default-on)"
  PASS=$((PASS + 1))
fi
export SB_AGENT_DELEGATE_V2=1
unset SB_AGENT_DELEGATE_DIRECT_FALLBACK
if sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-codex-delegate.sh --work-dir /tmp'; then
  echo "FAIL: V2=1 must block direct delegate without fallback"
  FAIL=$((FAIL + 1))
else
  echo "PASS: V2=1 blocks direct delegate without fallback"
  PASS=$((PASS + 1))
fi
export SB_AGENT_DELEGATE_DIRECT_FALLBACK=1
if sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-cursor-delegate.sh --work-dir /tmp'; then
  echo "PASS: V2=1 allows cursor delegate with DIRECT_FALLBACK"
  PASS=$((PASS + 1))
else
  echo "FAIL: V2=1 should allow cursor delegate with DIRECT_FALLBACK"
  FAIL=$((FAIL + 1))
fi
if sb_orchestrator_parent_delegate_bash_allowed 'bash scripts/agent-claude-delegate.sh --work-dir /tmp'; then
  echo "PASS: V2=1 allows claude delegate with DIRECT_FALLBACK"
  PASS=$((PASS + 1))
else
  echo "FAIL: V2=1 should allow claude delegate with DIRECT_FALLBACK"
  FAIL=$((FAIL + 1))
fi
if sb_orchestrator_parent_delegate_bash_allowed 'echo fake agent-codex-delegate.sh'; then
  echo "FAIL: substring spoof must not allow delegate bash"
  FAIL=$((FAIL + 1))
else
  echo "PASS: substring spoof blocked for delegate bash"
  PASS=$((PASS + 1))
fi
unset SB_AGENT_DELEGATE_V2 SB_AGENT_DELEGATE_DIRECT_FALLBACK

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
