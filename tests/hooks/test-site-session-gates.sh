#!/usr/bin/env bash
# test-site-session-gates.sh — Wave 1 site session hooks (instruction ledger + site gates).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SB_RUNTIME_PRESERVE_STATE_DIR=1

LEDGER_HOOK="$REPO_ROOT/hooks/instruction-ledger-gate.sh"
SITE_REG_HOOK="$REPO_ROOT/hooks/site-regression-gate.sh"
LIVE_HOOK="$REPO_ROOT/hooks/live-publish-evidence-gate.sh"
SUBAGENT_HOOK="$REPO_ROOT/hooks/subagent-stop-enforcement.sh"
SUBAGENT_START_HOOK="$REPO_ROOT/hooks/subagent-start.sh"
OUTCOMES_HOOK="$REPO_ROOT/hooks/outcomes-check.sh"
VLOOP_HOOK="$REPO_ROOT/hooks/v-loop-rollup-gate.sh"
VISUAL_HOOK="$REPO_ROOT/hooks/site-visual-evidence-gate.sh"
RECORD_VISUAL_HOOK="$REPO_ROOT/hooks/record-site-visual-evidence.sh"
RECORD_HOOK="$REPO_ROOT/hooks/record-site-session.sh"
PREVIEW_HOOK="$REPO_ROOT/hooks/site-preview-preflight.sh"
CHROME_HOOK="$REPO_ROOT/hooks/site-chrome-guard.sh"
MCP_RECORD_HOOK="$REPO_ROOT/hooks/record-recommended-mcp.sh"

PASS=0
FAIL=0

setup() {
  TMPDIR_TEST=$(mktemp -d)
  SB_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sb-site-gates.XXXXXX")
  export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<'JSON'
{"sb_initiated":true,"orchestrator_mode":"parent","project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]}}
JSON
  cp "$REPO_ROOT/silver-bullet.md" "$TMPDIR_TEST/silver-bullet.md"
  export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
  export SILVER_BULLET_STATE_FILE="${SB_TEST_DIR}/state-$$"
  export SILVER_BULLET_BRANCH_FILE="${SB_TEST_DIR}/branch-$$"
  printf 'main\n' >"$SILVER_BULLET_BRANCH_FILE"
  : >"$SILVER_BULLET_STATE_FILE"
  rm -f "${SB_TEST_DIR}/instruction-ledger.json" \
    "${SB_TEST_DIR}/site-session.json" \
    "${SB_TEST_DIR}/live-publish-evidence.json" \
    "${SB_TEST_DIR}/subagent-spawns.jsonl" \
    "${SB_TEST_DIR}/orchestrator-worker-active.json" 2>/dev/null || true
}

teardown() {
  [[ -n "${PREVIEW_PID:-}" ]] && kill "$PREVIEW_PID" 2>/dev/null || true
  PREVIEW_PID=""
  rm -rf "$TMPDIR_TEST" "$SB_TEST_DIR"
  rm -f "$SILVER_BULLET_STATE_FILE" "$SILVER_BULLET_BRANCH_FILE"
}

setup_with_agentmemory() {
  setup
  AM_STATE="${SB_TEST_DIR}/agentmemory-usage-$$"
  CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<EOF
{"sb_initiated":true,"config_version":"${CURRENT_CONFIG_VERSION}","orchestrator_mode":"parent","project":{"name":"test","active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"]},"recommended_tools":{"agentmemory":{"enabled_by_user":true,"usage_state_file":"${AM_STATE}"}}}
EOF
}

run_hook() {
  local hook="$1" event="$2" payload="$3"
  printf '%s' "$payload" | ( cd "$TMPDIR_TEST" && SB_RUNTIME_PRESERVE_STATE_DIR=1 bash "$hook" 2>/dev/null )
}

run_hook_worker() {
  local hook="$1" event="$2" payload="$3"
  printf '%s' "$payload" | ( cd "$TMPDIR_TEST" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_ORCHESTRATOR_PARENT=0 bash "$hook" 2>/dev/null )
}

assert_block() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -q '"decision":"block"'; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_deny() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -qE '"permissionDecision":"deny"|"decision":"block"'; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_allow() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -q '"decision":"block"'; then
    echo "  FAIL: $label (unexpected block)"
    FAIL=$((FAIL + 1))
  else
    echo "  ok: $label"
    PASS=$((PASS + 1))
  fi
}

assert_permit() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -qE '"decision":"block"|"permissionDecision":"deny"'; then
    echo "  FAIL: $label (unexpected deny/block)"
    FAIL=$((FAIL + 1))
  else
    echo "  ok: $label"
    PASS=$((PASS + 1))
  fi
}

echo "--- instruction-ledger-gate ---"
setup
prompt=$'- fix header overlap\n- unify card hover\n- remove duplicate callout'
out=$(run_hook "$LEDGER_HOOK" UserPromptSubmit "$(jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit",prompt:$p}')")
if printf '%s' "$out" | grep -qiE 'instruction ledger|unresolved'; then
  echo "  ok: seeds ledger context for multi-bullet prompt"
  PASS=$((PASS + 1))
else
  echo "  FAIL: seeds ledger context"
  FAIL=$((FAIL + 1))
fi
out=$(run_hook "$LEDGER_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks with unresolved ledger items" "$out"
teardown

echo "--- site-regression-gate ---"
setup
jq -n '{active:true,started_at:"2026-01-01T00:00:00Z",last_touch_at:"2026-06-28T12:00:00Z",regression_passed_at:null,push_intent:false,touch_reason:"edit:site/index.html"}' \
  >"${SB_TEST_DIR}/site-session.json"
out=$(run_hook "$SITE_REG_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks active site session without regression pass" "$out"
jq '.regression_passed_at = "2026-06-28T13:00:00Z"' "${SB_TEST_DIR}/site-session.json" >"${SB_TEST_DIR}/site-session.json.tmp" \
  && mv "${SB_TEST_DIR}/site-session.json.tmp" "${SB_TEST_DIR}/site-session.json"
out=$(run_hook "$SITE_REG_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "Stop allows when regression_passed_at >= last_touch_at" "$out"
teardown

echo "--- live-publish-evidence-gate ---"
setup
jq -n '{active:true,push_intent:true,live_claim_pending:false,last_touch_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/site-session.json"
out=$(run_hook "$LIVE_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks site push intent without live evidence" "$out"
jq -n '{commit_sha:"abc123",urls:["https://sb.alolabs.dev/"],markers_matched:["hero"],status:"LIVE",verified_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/live-publish-evidence.json"
out=$(run_hook "$LIVE_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "Stop allows with valid live-publish-evidence.json" "$out"
teardown

echo "--- subagent-stop-enforcement ---"
setup
printf '{"spawned_at":"2026-06-28T12:00:00Z","site_related":true}\n' >"${SB_TEST_DIR}/subagent-spawns.jsonl"
out=$(run_hook "$SUBAGENT_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks when subagents spawned without completion-audit" "$out"
printf 'silver-completion-audit\n' >"$SILVER_BULLET_STATE_FILE"
out=$(run_hook "$SUBAGENT_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "Stop allows when silver-completion-audit recorded" "$out"
teardown

echo "--- subagent per-task completion-audit ---"
setup
run_hook "$SUBAGENT_HOOK" PostToolUse "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"Task",tool_input:{description:"test"}}')" >/dev/null
out=$(run_hook "$SUBAGENT_HOOK" PreToolUse "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"src/foo.ts"}}')")
assert_deny "PreToolUse Edit blocked after Task return without completion-audit" "$out"
printf 'silver-completion-audit\n' >"$SILVER_BULLET_STATE_FILE"
run_hook "$SUBAGENT_HOOK" PreToolUse "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:"silver-completion-audit"}}')" >/dev/null
out=$(run_hook "$SUBAGENT_HOOK" PreToolUse "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"src/foo.ts"}}')")
assert_allow "PreToolUse Edit allowed after completion-audit skill" "$out"
teardown

echo "--- subagent-start ---"
setup
out=$(run_hook "$SUBAGENT_START_HOOK" SubagentStart "$(jq -n '{hook_event_name:"SubagentStart",subagent_type:"generalPurpose",prompt:"invoke silver:execute"}')")
if printf '%s' "$out" | grep -qiE 'graphify|agentmemory|evidence'; then
  echo "  ok: subagentStart injects worker tooling banner"
  PASS=$((PASS + 1))
else
  echo "  FAIL: subagentStart banner"
  FAIL=$((FAIL + 1))
fi
if [[ -f "${SB_TEST_DIR}/orchestrator-worker-active.json" ]]; then
  echo "  ok: subagentStart writes worker marker"
  PASS=$((PASS + 1))
else
  echo "  FAIL: worker marker missing"
  FAIL=$((FAIL + 1))
fi
teardown

echo "--- outcomes-check worker skip ---"
setup
printf '{"items":[{"id":"route","status":"pending"}]}' >"${SB_TEST_DIR}/outcomes-session.json"
printf '{"spawned_at":"2026-06-28T12:00:00Z"}' >"${SB_TEST_DIR}/orchestrator-worker-active.json"
out=$(run_hook "$OUTCOMES_HOOK" SubagentStop "$(jq -n '{hook_event_name:"SubagentStop"}')")
assert_allow "SubagentStop skips outcomes-check for worker session" "$out"
teardown

echo "--- v-loop-rollup-gate ---"
setup
jq -n '{active:true,started_at:"2026-01-01T00:00:00Z",last_touch_at:"2026-06-28T12:00:00Z",touch_reason:"edit:site/index.html"}' >"${SB_TEST_DIR}/site-session.json"
source "$REPO_ROOT/hooks/lib/site-session.sh"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
sb_site_session_init_vloops
out=$(run_hook "$VLOOP_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks active site session with incomplete V-loops" "$out"
sb_site_session_sync_vloops_from_state
sb_site_session_mark_visual_evidence "/tmp/screenshot.png"
jq '.regression_passed_at = "2026-06-28T13:00:00Z"' "${SB_TEST_DIR}/site-session.json" >"${SB_TEST_DIR}/site-session.json.tmp" && mv "${SB_TEST_DIR}/site-session.json.tmp" "${SB_TEST_DIR}/site-session.json"
sb_site_session_sync_vloops_from_state
out=$(run_hook "$VLOOP_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "Stop allows when site V-loops synced" "$out"
teardown

echo "--- site-visual-evidence-gate ---"
setup
jq -n '{active:true,last_touch_at:"2026-06-28T12:00:00Z",touch_reason:"site-intent"}' >"${SB_TEST_DIR}/site-session.json"
out=$(run_hook "$VISUAL_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_block "Stop blocks site session without visual evidence" "$out"
jq -n '{captured_at:"2026-06-28T12:00:00Z",paths:["/tmp/x.png"]}' >"${SB_TEST_DIR}/site-visual-evidence.json"
out=$(run_hook "$VISUAL_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "Stop allows with site-visual-evidence.json" "$out"
teardown

echo "--- record-site-visual-evidence ---"
setup
run_hook "$RECORD_VISUAL_HOOK" PostToolUse "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"browser_take_screenshot",tool_response:{path:"/tmp/site-shot.png"}}')" >/dev/null
if [[ -f "${SB_TEST_DIR}/site-visual-evidence.json" ]]; then
  echo "  ok: records screenshot path for visual V-loop"
  PASS=$((PASS + 1))
else
  echo "  FAIL: visual evidence not recorded"
  FAIL=$((FAIL + 1))
fi
teardown

echo "--- chrome regression integration ---"
if bash "$REPO_ROOT/tests/scripts/test-site-chrome-regression.sh" >/dev/null 2>&1; then
  echo "  ok: test-site-chrome-regression.sh passes"
  PASS=$((PASS + 1))
else
  echo "  FAIL: test-site-chrome-regression.sh"
  FAIL=$((FAIL + 1))
fi

echo "--- record-site-session ---"
setup
run_hook "$RECORD_HOOK" PostToolUse "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:"site/index.html"}}')" >/dev/null
if [[ -f "${SB_TEST_DIR}/site-session.json" ]] && jq -e '.active == true' "${SB_TEST_DIR}/site-session.json" >/dev/null; then
  echo "  ok: records site/** edit as active site session"
  PASS=$((PASS + 1))
else
  echo "  FAIL: record site edit"
  FAIL=$((FAIL + 1))
fi
teardown

echo "--- site-preview-preflight ---"
setup
SB_SITE_PREVIEW_PORT=59991
export SB_SITE_PREVIEW_PORT
out=$(run_hook_worker "$PREVIEW_HOOK" PreToolUse "$(jq -n --arg fp "site/index.html" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp}}')")
assert_deny "PreToolUse Edit site/** denied when preview unhealthy" "$out"
printf '<html><body>preview</body></html>\n' >"$TMPDIR_TEST/index.html"
python3 -m http.server "$SB_SITE_PREVIEW_PORT" --directory "$TMPDIR_TEST" >/dev/null 2>&1 &
PREVIEW_PID=$!
sleep 0.5
out=$(run_hook_worker "$PREVIEW_HOOK" PreToolUse "$(jq -n --arg fp "site/index.html" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp}}')")
assert_permit "PreToolUse Edit site/** allowed when preview healthy" "$out"
teardown

echo "--- site-chrome-guard ---"
setup
out=$(run_hook "$CHROME_HOOK" PreToolUse "$(jq -n --arg fp "site/help/test.html" --arg ns '<nav class="nav-inner">bad</nav>' '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp,new_string:$ns}}')")
assert_deny "PreToolUse denies inline nav chrome in site/help HTML" "$out"
out=$(run_hook "$CHROME_HOOK" PreToolUse "$(jq -n --arg fp "site/tokens.css" --arg ns '@font-face { font-family: Bad; }' '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp,new_string:$ns}}')")
assert_deny "PreToolUse denies tokens.css font-face without override marker" "$out"
out=$(run_hook "$CHROME_HOOK" PreToolUse "$(jq -n --arg fp "site/tokens.css" --arg ns '/* SB FONT TOKEN OVERRIDE */ @font-face { font-family: Bad; }' '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp,new_string:$ns}}')")
assert_permit "PreToolUse allows tokens.css with SB FONT TOKEN OVERRIDE" "$out"
teardown

echo "--- record-recommended-mcp ---"
setup_with_agentmemory
EXPECTED_AM_STATE="${SB_TEST_DIR}/agentmemory-usage"
out=$(run_hook "$MCP_RECORD_HOOK" PostToolUse "$(jq -n '{hook_event_name:"PostToolUse",tool_name:"CallMcpTool",tool_input:{server:"user-agentmemory",toolName:"save_memory"}}')")
if [[ -f "$EXPECTED_AM_STATE" ]] && grep -qE '^[0-9]+$' "$EXPECTED_AM_STATE"; then
  echo "  ok: records agentmemory MCP usage"
  PASS=$((PASS + 1))
else
  echo "  FAIL: agentmemory MCP usage not recorded"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$out" | grep -q 'recommended MCP usage recorded'; then
  echo "  ok: emits recorded confirmation message"
  PASS=$((PASS + 1))
else
  echo "  FAIL: missing recorded confirmation"
  FAIL=$((FAIL + 1))
fi
teardown

echo "--- site-session gate scoping (#244/#245) ---"
setup
jq -n '{active:true,started_at:"2026-01-01T00:00:00Z",last_touch_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/site-session.json"
out=$(run_hook "$VISUAL_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "active without site work — visual gate allows Stop" "$out"
out=$(run_hook "$VLOOP_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "active without site work — vloop gate allows Stop" "$out"
out=$(run_hook "$SITE_REG_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "active without site work — regression gate allows Stop" "$out"
teardown

setup
jq -n '{active:true,touch_reason:"edit:site/index.html",last_touch_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/site-session.json"
jq -n '{active:true,host:"opencode",task_id:"t1",work_dir:"/tmp",ownership_scope:[]}' \
  >"${SB_TEST_DIR}/agent-delegation-active.json"
out=$(run_hook "$VISUAL_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "site work + agent delegation — visual gate allows Stop" "$out"
out=$(run_hook "$VLOOP_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "site work + agent delegation — vloop gate allows Stop" "$out"
out=$(run_hook "$SITE_REG_HOOK" Stop "$(jq -n '{hook_event_name:"Stop"}')")
assert_allow "site work + agent delegation — regression gate allows Stop" "$out"
teardown

setup
jq -n '{active:true,touch_reason:"site-intent",last_touch_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/site-session.json"
source "$REPO_ROOT/hooks/lib/site-session.sh"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
sb_site_session_record_subagent_spawn '{"description":"silver-agent-opencode pi TUI delegation"}'
if [[ -f "${SB_TEST_DIR}/site-session.json" ]] && jq -e '.touch_reason == "site-intent"' "${SB_TEST_DIR}/site-session.json" >/dev/null; then
  echo "  ok: silver-agent-opencode spawn does not mark site session"
  PASS=$((PASS + 1))
else
  echo "  FAIL: silver-agent-opencode spawn marked site session"
  FAIL=$((FAIL + 1))
fi
teardown

setup
jq -n '{active:true,touch_reason:"edit:site/index.html",last_touch_at:"2026-06-28T12:00:00Z"}' \
  >"${SB_TEST_DIR}/site-session.json"
run_hook "$RECORD_HOOK" UserPromptSubmit "$(jq -n --arg p 'invoke silver-agent-opencode for pi TUI delegation' '{hook_event_name:"UserPromptSubmit",prompt:$p}')" >/dev/null
if [[ ! -f "${SB_TEST_DIR}/site-session.json" ]]; then
  echo "  ok: agent delegation prompt clears stale site session"
  PASS=$((PASS + 1))
else
  echo "  FAIL: agent delegation prompt did not clear site session"
  FAIL=$((FAIL + 1))
fi
teardown


echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
