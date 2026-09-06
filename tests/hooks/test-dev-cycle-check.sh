#!/usr/bin/env bash
# Tests for hooks/dev-cycle-check.sh
# Tests the workflow gate: A blocks before planning, B allows implementation
# after planning, C continues after review, D allows once finalization is done.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/dev-cycle-check.sh"
WORKFLOWS_SCRIPT="$REPO_ROOT/scripts/workflows.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ${SB_RUNTIME_HOME_ROOT}/ due to security path validation in hooks.
SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"

cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" "$VERIFY_TESTS_FILE"; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPBRANCH_FILE="${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  rm -f "$TMPSTATE"
  rm -f "$TMPBRANCH_FILE"
  rm -f "$VERIFY_TESTS_FILE"
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  mkdir -p "$(dirname "$TMPFILE")"
  touch "$TMPFILE"
  cat > "$TMPCFG" << EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\\\.test\\\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
  }
EOF
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE"
  printf 'feature/test\n' > "$TMPBRANCH_FILE"
  export SILVER_BULLET_BRANCH_FILE="$TMPBRANCH_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  rm -f "$TMPBRANCH_FILE"
  rm -f "$VERIFY_TESTS_FILE"
  unset SILVER_BULLET_BRANCH_FILE
}

create_active_workflow() {
  local composer="${1:-silver-feature}"
  local intent="${2:-admission-control-test}"
  local flows="${3:-bootstrap,execute,ship}"
  mkdir -p "$TMPDIR_TEST/.planning"
  ( cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "$composer" "$intent" "$flows" )
}

run_hook_edit() {
  local event="$1"
  local filepath="$2"
  local old_str="${3:-old content}"
  local new_str="${4:-new content}"
  local input
  input=$(jq -n \
    --arg e "$event" \
    --arg f "$filepath" \
    --arg o "$old_str" \
    --arg n "$new_str" \
    '{hook_event_name: $e, tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_write() {
  local event="$1"
  local filepath="$2"
  local input
  input=$(jq -n --arg e "$event" --arg f "$filepath" \
    '{hook_event_name: $e, tool_name: "Write", tool_input: {file_path: $f}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_multiedit() {
  local event="$1"
  local filepath="$2"
  local input
  input=$(jq -n --arg e "$event" --arg f "$filepath" \
    '{hook_event_name: $e, tool_name: "MultiEdit", tool_input: {file_path: $f}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_apply_patch() {
  local event="$1"
  local patch="$2"
  local input
  input=$(jq -n --arg e "$event" --arg p "$patch" \
    '{hook_event_name: $e, tool_name: "apply_patch", tool_input: {patch: $p}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_bash() {
  local event="$1"
  local cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_exec_command() {
  local event="$1"
  local shell_cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$shell_cmd" \
    '{hook_event_name: $e, tool_name: "exec_command", tool_input: {command: ["bash", "-lc", $c]}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_exec_array() {
  local event="$1"
  local command_json="$2"
  local input
  input=$(jq -n --arg e "$event" --argjson c "$command_json" \
    '{hook_event_name: $e, tool_name: "exec_command", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}


assert_decoded_message_real_newlines() {
  # SB-BUG-B / #248: gate reason/message must decode to real newlines, not literal \n.
  local label="$1"
  local output="$2"
  local decoded
  decoded=$(printf '%s' "$output" | jq -r '
    .reason
    // .permissionDecisionReason
    // .hookSpecificOutput.permissionDecisionReason
    // .hookSpecificOutput.message
    // empty
  ' 2>/dev/null || true)
  if [[ -z "$decoded" ]]; then
    echo "  FAIL: $label — could not decode reason/message from: $output"
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ "$decoded" != *$'\n'* ]]; then
    echo "  FAIL: $label — decoded text has no real newline characters"
    FAIL=$((FAIL + 1))
    return
  fi
  if printf '%s' "$decoded" | grep -qF '\n'; then
    echo "  FAIL: $label — decoded text still contains literal backslash-n"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "  PASS: $label"
  PASS=$((PASS + 1))
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if ! printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — unexpected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected file to exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected file to be absent: $path"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== dev-cycle-check.sh tests ==="

# Test 1: Stage A — no planning skills → HARD STOP on src edit
echo "--- Group 1: Stage A (no planning) ---"
setup
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "Stage A: source edit blocked without silver-quality-gates" "$out"
assert_contains "Stage A block message mentions HARD STOP" "$out" "HARD STOP"
assert_decoded_message_real_newlines "NEWLINE: Stage A HARD STOP uses real newlines not literal \\n" "$out"
teardown

# Test 2: Stage A — no planning → HARD STOP on Write to src
setup
out=$(run_hook_write "PreToolUse" "$TMPFILE")
assert_blocks "Stage A: Write to src blocked without silver-quality-gates" "$out"
teardown

# Test 2a: Stage A — native Codex apply_patch to src is blocked before planning
setup
out=$(run_hook_apply_patch "PreToolUse" "*** Begin Patch
*** Update File: src/app.js
@@
+console.log('blocked before planning')
*** End Patch")
assert_blocks "Stage A: apply_patch source edit blocked without silver-quality-gates" "$out"
teardown

# Test 2b: Stage A — missing skill that is not installed anywhere invocable warns and allows
setup
cat > "$TMPCFG" << 'EOF'
{
  "config_version": "CURRENT_CONFIG_VERSION",
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": { "required_planning": ["not-a-real-skill"] },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|CURRENT_CONFIG_VERSION|${CURRENT_CONFIG_VERSION}|g; s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage A: uninstalled planning skill warns and allows source edit" "$out"
assert_contains "Stage A warning mentions uninstalled skill" "$out" "not installed anywhere invocable"
assert_decoded_message_real_newlines "NEWLINE: Stage A uninstalled warning uses real newlines not literal \\n" "$out"
teardown

# Test 3: Stage A — non-src file passes even without planning
setup
out=$(run_hook_edit "PreToolUse" "${TMPDIR_TEST}/README.md" "old" "new")
assert_passes "non-src file passes without silver-quality-gates" "$out"
teardown

setup
out=$(run_hook_apply_patch "PreToolUse" "*** Begin Patch
*** Update File: README.md
@@
+Documentation-only patch
*** End Patch")
assert_passes "non-src apply_patch passes without silver-quality-gates" "$out"
teardown

setup
out=$(run_hook_apply_patch "PreToolUse" "*** Begin Patch
*** Update File: README.md
@@
+Documentation change
*** Update File: src/app.js
@@
+console.log('blocked multi-file source edit')
*** End Patch")
assert_blocks "multi-file apply_patch blocks when any path is source" "$out"
teardown

# Test 4: Stage A — test file passes even without planning
setup
TEST_FILE="${TMPDIR_TEST}/src/app.test.js"
mkdir -p "$(dirname "$TEST_FILE")"
touch "$TEST_FILE"
out=$(run_hook_edit "PreToolUse" "$TEST_FILE" "old content" "new content")
assert_passes "test file passes without planning (excluded by src_exclude_pattern)" "$out"
teardown

# Test 4a: Stage A — relative Bash write to src/ is blocked without planning
setup
out=$(run_hook_bash "PreToolUse" "cat > src/app.js <<'EOF'
console.log('hello')
EOF")
assert_blocks "relative Bash write to src/ blocked without silver-quality-gates" "$out"
teardown

# Test 4aa: Stage A — exec_command array write to src/ is blocked without planning
setup
out=$(run_hook_exec_command "PreToolUse" "printf 'console.log(1)\n' > src/app.js")
assert_blocks "exec_command array write to src/ blocked without silver-quality-gates" "$out"
teardown

# Test 4aaa: Stage A — direct exec_command argv redirect attempt is blocked without planning
setup
out=$(run_hook_exec_array "PreToolUse" '["printf","console.log(1)\n",">>","src/app.js"]')
assert_blocks "direct exec_command argv redirect to src/ is blocked without silver-quality-gates" "$out"
teardown

# Test 4aab: Stage A — direct exec_command echo argv redirect attempt is blocked without planning
setup
out=$(run_hook_exec_array "PreToolUse" '["echo","","// probe","",">>","src/app.js"]')
assert_blocks "direct exec_command echo argv redirect to src/ is blocked without silver-quality-gates" "$out"
teardown

# Test 4aac: Stage A — read-only exec_command search for literal >> stays allowed
setup
out=$(run_hook_exec_array "PreToolUse" '["rg",">>","src/app.js"]')
assert_passes "direct exec_command literal >> search stays read-only" "$out"
teardown

# Test 4ab: Stage A — scaffold/config write with /src/ literal stays outside source gate
setup
out=$(run_hook_bash "PreToolUse" "cat > .silver-bullet.json <<'EOF'
{\"project\":{\"src_pattern\":\"/src/\"}}
EOF")
assert_passes "Bash write to SB config with /src/ literal is not treated as a source edit" "$out"
teardown

# Test 4ac: Stage A — Bash write to excluded src test file passes without planning
setup
out=$(run_hook_bash "PreToolUse" "cat > src/app.test.js <<'EOF'
console.log('test-only')
EOF")
assert_passes "Bash write to excluded src test file passes without planning" "$out"
teardown

# Test 4ad: Stage A — read-only src inspection via Bash passes without planning
setup
out=$(run_hook_bash "PreToolUse" "sed -n '1,40p' src/app.js")
assert_passes "read-only Bash inspection of src file passes without planning" "$out"
teardown

# Test 4ae: Stage A — read-only git show of src file passes without planning
setup
out=$(run_hook_bash "PreToolUse" "git show HEAD:src/app.js | sed -n '1,40p'")
assert_passes "read-only git show of src file passes without planning" "$out"
teardown

# Test 4ae2: Stage A — git grep in src passes without planning (#227 grep false positive)
setup
out=$(run_hook_bash "PreToolUse" "git grep -n forwarder -- src/app.js")
assert_passes "read-only git grep of src file passes without planning" "$out"
teardown

# Test 4ae3: Stage A — grep in src passes without planning
setup
out=$(run_hook_bash "PreToolUse" "grep -n forwarder src/app.js")
assert_passes "read-only grep of src file passes without planning" "$out"
teardown

# Test 4ae4: Stage A — ls under src-tauri/src with 2>/dev/null passes without planning
setup
PROXY_DIR="${TMPDIR_TEST}/src-tauri/src/proxy"
mkdir -p "$PROXY_DIR"
touch "${PROXY_DIR}/forwarder.rs"
out=$(run_hook_bash "PreToolUse" "ls -la ${PROXY_DIR}/ 2>/dev/null")
assert_passes "read-only ls of src-tauri/src path with stderr discard passes" "$out"
teardown

# Test 4ae5: Stage A — compound ls with || and src-tauri paths passes without planning
setup
PROXY_DIR="${TMPDIR_TEST}/src-tauri/src/proxy"
mkdir -p "$PROXY_DIR"
touch "${PROXY_DIR}/forwarder.rs"
out=$(run_hook_bash "PreToolUse" "ls -la ${TMPDIR_TEST}/.planning/quality-gates/ 2>/dev/null || echo \"no quality-gates dir yet\"; ls -la ${PROXY_DIR}/ 2>/dev/null")
assert_passes "read-only compound ls with stderr discard and src-tauri path passes" "$out"
teardown

# Test 4ae6: Stage A — grep with alternation in quotes piped to head passes without planning
setup
PROXY_DIR="${TMPDIR_TEST}/src-tauri/src/proxy"
mkdir -p "$PROXY_DIR"
touch "${PROXY_DIR}/forwarder.rs"
out=$(run_hook_bash "PreToolUse" "grep -n \"log::info\\|tracing::info\" ${PROXY_DIR}/forwarder.rs | head -10")
assert_passes "read-only grep with quoted alternation piped to head passes" "$out"
teardown

# Test 4ae7: Stage A — gh issue create mentioning src path in args is not planning-gated (#231)
setup
out=$(run_hook_bash "PreToolUse" "gh issue create --repo alo-exp/silver-bullet --title \"bug in src-tauri/src/proxy/forwarder.rs\" --body \"mentions src/app.js in prose only\"")
assert_passes "gh issue create with src path mentions in args is not planning-gated" "$out"
teardown

# Test 4ae8: Stage A — planning block uses real newlines in missing skill list (#230)
setup
out=$(run_hook_bash "PreToolUse" "touch src/new-file.js")
assert_blocks "touch inside src still blocked without planning" "$out"
reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true)
if printf '%s' "$reason" | grep -q $'silver-quality-gates\n'; then
  echo "  ✅ planning block uses real newlines in skill list"
  PASS=$((PASS + 1))
else
  echo "  ❌ planning block must use real newlines between missing skills"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 4af: Stage A — touch inside src is blocked without planning
setup
out=$(run_hook_bash "PreToolUse" "touch src/new-file.js")
assert_blocks "touch inside src is blocked without silver-quality-gates" "$out"
teardown

# Test 4ag: Stage A — tee append inside shell wrapper is blocked without planning
setup
out=$(run_hook_bash "PreToolUse" "bash -c \"printf 'console.log(1)\n' | tee -a src/app.js > /dev/null\"")
assert_blocks "tee append inside bash -c is blocked without silver-quality-gates" "$out"
teardown

# Test 4ah: Stage A — exec_command tee append inside shell wrapper is blocked without planning
setup
out=$(run_hook_exec_command "PreToolUse" "printf 'console.log(1)\n' | tee -a src/app.js > /dev/null")
assert_blocks "exec_command tee append inside shell wrapper is blocked without silver-quality-gates" "$out"
teardown

# Test 4ahh: Stage A — direct python exec_command write is blocked without planning
setup
out=$(run_hook_exec_array "PreToolUse" '["python3","-c","from pathlib import Path; Path(\"src/app.js\").open(\"a\", encoding=\"utf-8\").write(\"\\n# probe\\n\")"]')
assert_blocks "direct python exec_command write inside src is blocked without silver-quality-gates" "$out"
teardown

# Test 4ahi: Stage A — direct node exec_command write is blocked without planning
setup
out=$(run_hook_exec_array "PreToolUse" '["node","-e","require(\"fs\").appendFileSync(\"src/app.js\",\"\\n// probe\\n\")"]')
assert_blocks "direct node exec_command write inside src is blocked without silver-quality-gates" "$out"
teardown

# Test 4ai: Stage A — mkdir outside src stays outside the planning gate
setup
out=$(run_hook_bash "PreToolUse" "mkdir -p docs/workflows")
assert_passes "mkdir outside src passes without planning" "$out"
teardown

# Test 4b: PostToolUse write invalidates verify-tests freshness marker
setup
echo "silver-quality-gates" > "$TMPSTATE"
echo "silver-review" >> "$TMPSTATE"
mkdir -p "$(dirname "$VERIFY_TESTS_FILE")"
printf 'verified_at=2026-05-10T00:00:00Z\n' > "$VERIFY_TESTS_FILE"
out=$(run_hook_write "PreToolUse" "$TMPFILE")
assert_passes "PreToolUse write leaves verify-tests marker intact" "$out"
assert_file_exists "PreToolUse write keeps verify-tests marker" "$VERIFY_TESTS_FILE"
out=$(run_hook_write "PostToolUse" "$TMPFILE")
assert_passes "PostToolUse write still passes with planning complete" "$out"
assert_file_missing "PostToolUse write invalidates verify-tests freshness" "$VERIFY_TESTS_FILE"
teardown

setup
echo "silver-quality-gates" > "$TMPSTATE"
echo "silver-review" >> "$TMPSTATE"
mkdir -p "$(dirname "$VERIFY_TESTS_FILE")"
printf 'verified_at=2026-05-10T00:00:00Z\n' > "$VERIFY_TESTS_FILE"
out=$(run_hook_apply_patch "PostToolUse" "*** Begin Patch
*** Update File: src/app.js
@@
+console.log('post patch invalidates freshness')
*** End Patch")
assert_passes "PostToolUse apply_patch passes with planning complete" "$out"
assert_file_missing "PostToolUse apply_patch invalidates verify-tests freshness" "$VERIFY_TESTS_FILE"
teardown

# Test 4ba: PostToolUse non-src Bash write does not invalidate verify-tests freshness
setup
echo "silver-quality-gates" > "$TMPSTATE"
echo "silver-review" >> "$TMPSTATE"
mkdir -p "$(dirname "$VERIFY_TESTS_FILE")"
printf 'verified_at=2026-05-10T00:00:00Z\n' > "$VERIFY_TESTS_FILE"
out=$(run_hook_bash "PostToolUse" "cat > .silver-bullet.json <<'EOF'
{\"project\":{\"src_pattern\":\"/src/\"}}
EOF")
assert_passes "PostToolUse non-src Bash write still passes with planning complete" "$out"
assert_file_exists "PostToolUse non-src Bash write keeps verify-tests freshness" "$VERIFY_TESTS_FILE"
teardown

# Test 5: Stage B — planning done but no code-review → ALLOW with final-delivery reminder
echo "--- Group 2: Stage B (planning done, no silver-review) ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage B: src edit allowed after planning, before silver-review" "$out"
assert_contains "Stage B reminder mentions code review" "$out" "Code review"
teardown

setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook_apply_patch "PreToolUse" "*** Begin Patch
*** Update File: src/app.js
@@
+console.log('allowed after planning')
*** End Patch")
assert_passes "Stage B: apply_patch source edit allowed after planning" "$out"
teardown

# Test 6: Phase-skip detection — finalization before silver-review warns but allows fixes
setup
echo "silver-quality-gates" > "$TMPSTATE"
echo "finishing-a-development-branch" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
# Source edits remain open so review/verification fixes can proceed, but final delivery stays blocked.
assert_passes "Phase-skip: finalization before silver-review allows source fixes" "$out"
assert_contains "Phase-skip warning mentions final delivery remains blocked" "$out" "final delivery remains blocked"
teardown

# Test 7: Stage C — silver-review done, finalization remaining → ALLOW with hint
echo "--- Group 3: Stage C (silver-review done) ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
echo "silver-review" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage C: src edit allowed after silver-review (finalization remaining)" "$out"
assert_contains "Stage C hint mentions finalization" "$out" "finalization"
out=$(run_hook_bash "PreToolUse" "cat > src/app.js <<'EOF'
console.log('hello')
EOF")
assert_passes "Stage C: relative Bash write allowed after silver-review" "$out"
teardown

# Test 8: Stage D — all phases complete → ALLOW
echo "--- Group 4: Stage D (all complete) ---"
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
requesting-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
EOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage D: src edit allowed when all phases complete" "$out"
teardown

# Test 9: Small edit bypass (< 100 chars combined)
echo "--- Group 5: Trivial bypass ---"
setup
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "typo" "typoo")  # 10 chars combined
assert_passes "small edit (<100 chars) bypasses enforcement" "$out"
teardown

# Test 10: Large edit does NOT bypass enforcement (>= 100 chars combined)
setup
old_str="this is old content that is long enough to exceed the threshold value for sure"
new_str="this is new content that is long enough to exceed the threshold value for sure too"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "$old_str" "$new_str")
assert_blocks "large edit (>=100 chars) enforces gate normally" "$out"
teardown

# Test 11: Non-logic file extension bypasses enforcement
setup
CSS_FILE="${TMPDIR_TEST}/src/styles.css"
touch "$CSS_FILE"
out=$(run_hook_edit "PreToolUse" "$CSS_FILE" "old" "new")
assert_passes "CSS file bypasses enforcement (non-logic extension)" "$out"
teardown

# Test 12: Trivial file bypass
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "trivial file bypass works" "$out"
teardown

# Test 13: Plugin cache boundary — blocks edits to ${SB_RUNTIME_HOME_ROOT}/plugins/cache
echo "--- Group 6: Plugin boundary ---"
setup
# Simulate a path within the plugin cache
PLUGIN_PATH="${SB_RUNTIME_HOME_ROOT}/plugins/cache/test-plugin/skill/SKILL.md"
out=$(run_hook_edit "PreToolUse" "$PLUGIN_PATH" "old" "new")
assert_blocks "plugin cache edit is blocked (§8 boundary)" "$out"
assert_contains "boundary block mentions THIRD-PARTY PLUGIN" "$out" "THIRD-PARTY PLUGIN BOUNDARY"
teardown

# Test 14: DevOps workflow uses silver-blast-radius as required_planning
echo "--- Group 7: DevOps workflow ---"
setup
cat > "$TMPCFG" << 'EOF'
{
  "config_version": "CURRENT_CONFIG_VERSION",
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "devops-cycle"
  },
  "skills": {
    "required_planning": ["silver-blast-radius","devops-quality-gates"],
    "required_deploy": ["silver-blast-radius","devops-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"],
    "all_tracked": ["silver-blast-radius","devops-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"]
  },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|CURRENT_CONFIG_VERSION|${CURRENT_CONFIG_VERSION}|g; s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
# Only silver-quality-gates in state (wrong for devops)
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "devops: edit blocked with silver-quality-gates (need silver-blast-radius+devops-quality-gates)" "$out"
teardown

# Test 15: DevOps workflow allows implementation with silver-blast-radius + devops-quality-gates
setup
cat > "$TMPCFG" << 'EOF'
{
  "config_version": "CURRENT_CONFIG_VERSION",
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "devops-cycle"
  },
  "skills": {
    "required_planning": ["silver-blast-radius","devops-quality-gates"],
    "required_deploy": ["silver-blast-radius","devops-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"],
    "all_tracked": ["silver-blast-radius","devops-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"]
  },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|CURRENT_CONFIG_VERSION|${CURRENT_CONFIG_VERSION}|g; s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
echo "silver-blast-radius" > "$TMPSTATE"
echo "devops-quality-gates" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "devops: Stage B — implementation allowed with devops planning complete" "$out"
assert_contains "devops: Stage B reminder mentions finalization" "$out" "finalization"
teardown

# Tests 16-17: State file tamper detection
echo "--- Group 8: State tamper detection ---"
setup
# Test 16: General write to state file is blocked
out=$(run_hook_bash "PreToolUse" "echo 'fake-skill' >> ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state")
assert_blocks "tamper: arbitrary state write is blocked" "$out"
teardown

# Test 17: Heredoc body containing state path should NOT be blocked (HOOK-02 regression)
setup
out=$(run_hook_bash "PreToolUse" "cat > /tmp/instructions.md << 'EOF'
To reset state, remove ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state
EOF")
assert_passes "tamper: heredoc body with state path is NOT blocked (HOOK-02)" "$out"
teardown

# Test 17b: Direct write to state path is STILL blocked after HOOK-02 fix
setup
out=$(run_hook_bash "PreToolUse" "printf 'fake' > ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state")
assert_blocks "tamper: direct write to state path is still blocked (HOOK-02)" "$out"
teardown

# Test 17c: tee to state file is STILL blocked (BUG-03: only state is guarded, not trivial/branch)
setup
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state")
assert_blocks "tamper: tee to state file is still blocked (BUG-03)" "$out"
teardown

# Test 17ca: script indirection through a symlink to the state file is blocked
setup
mkdir -p "$TMPDIR_TEST/.hook-probes"
ln -s "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state" "$TMPDIR_TEST/.hook-probes/state-link"
cat > "$TMPDIR_TEST/.hook-probes/probe.sh" <<'EOF'
printf 'fake-skill\n' >> .hook-probes/state-link
EOF
chmod +x "$TMPDIR_TEST/.hook-probes/probe.sh"
out=$(run_hook_bash "PreToolUse" "bash .hook-probes/probe.sh")
assert_blocks "tamper: script write through symlinked state file is blocked" "$out"
teardown

# Test 17cb: wrapped shell script indirection to the state file is blocked
setup
mkdir -p "$TMPDIR_TEST/.hook-probes"
ln -s "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state" "$TMPDIR_TEST/.hook-probes/state-link"
cat > "$TMPDIR_TEST/.hook-probes/probe.sh" <<'EOF'
printf 'fake-skill\n' >> .hook-probes/state-link
EOF
chmod +x "$TMPDIR_TEST/.hook-probes/probe.sh"
out=$(run_hook_bash "PreToolUse" "/bin/zsh -lc 'bash .hook-probes/probe.sh'")
assert_blocks "tamper: wrapped shell script write through symlinked state file is blocked" "$out"
teardown

# Test 17d: tee to trivial file is now ALLOWED (BUG-03 fix — trivial is not state-managed)
setup
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial")
assert_passes "tamper: tee to trivial file is allowed (BUG-03 fix)" "$out"
teardown

# Test 17e: git commit mentioning state path in -m is NOT blocked (QA-05)
setup
out=$(run_hook_bash "PreToolUse" "git commit -m \"fix: removes >> ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state pattern from docs\"")
assert_passes "tamper: git commit -m with state path in message is NOT blocked (QA-05)" "$out"
teardown

# Test 17f: gh issue create mentioning state path in --body is NOT blocked (QA-05)
setup
out=$(run_hook_bash "PreToolUse" "gh issue create --title 'test' --body 'writes to > ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state'")
assert_passes "tamper: gh issue create with state path in body is NOT blocked (QA-05)" "$out"
teardown

# Test 17g: state path inside a quoted non-redirect argument is NOT blocked (quote-literal exemption)
setup
out=$(run_hook_bash "PreToolUse" "echo \"path is ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state\"")
assert_passes "tamper: state path in quoted echo argument is NOT blocked (quote-literal exemption)" "$out"
teardown

# Test 17g2: same as 17g but with $HOME-expanded path (real session form)
setup
out=$(run_hook_bash "PreToolUse" "echo \"path is ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state\"")
assert_passes "tamper: expanded-path in quoted echo argument is NOT blocked (quote-literal exemption)" "$out"
teardown

# Test 17h: tee with quoted state path IS still blocked (exemption abuse — redirect target)
setup
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee \"${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state\"")
assert_blocks "tamper: tee with quoted state path is still blocked (exemption abuse)" "$out"
teardown

# Test 17h2: same as 17h but with $HOME-expanded path (real session form)
setup
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee \"${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state\"")
assert_blocks "tamper: tee with expanded quoted state path is still blocked (exemption abuse)" "$out"
teardown

# Test 17i: planning-edit-override sentinel via touch is ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "touch ${SB_RUNTIME_STATE_DIR}/planning-edit-override")
assert_passes "tamper: touch planning-edit-override sentinel is allowed" "$out"
teardown

# Test 17j: planning-edit-override sentinel via Write is ALLOWED
setup
out=$(run_hook_write "PreToolUse" "${SB_RUNTIME_STATE_DIR}/planning-edit-override")
assert_passes "tamper: Write planning-edit-override sentinel is allowed" "$out"
teardown

# Test 17k: direct Write to state file is still BLOCKED
setup
out=$(run_hook_write "PreToolUse" "${SB_RUNTIME_STATE_DIR}/state")
assert_blocks "tamper: Write to state file is still blocked" "$out"
teardown

# Tests 18-22: F-07 plugin boundary — execution vs write distinction
# Use expanded $HOME path so the plugin_cache grep actually fires in the hook
PLUGIN_CACHE_PATH="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
echo "--- Group 9: F-07 execution vs write (plugin binary) ---"

# Test 18: Running a plugin binary with node should be ALLOWED (execution, not write)
setup
out=$(run_hook_bash "PreToolUse" "node ${PLUGIN_CACHE_PATH}/some-plugin/index.js --run")
assert_passes "F-07: node execution of plugin binary is allowed" "$out"
teardown

# Test 19: node with a redirect into the plugin cache should be BLOCKED (write)
setup
out=$(run_hook_bash "PreToolUse" "node ${PLUGIN_CACHE_PATH}/some-plugin/build.js > ${PLUGIN_CACHE_PATH}/some-plugin/out.js")
assert_blocks "F-07: node with redirect into plugin cache is blocked" "$out"
teardown

# Test 19b: reading a template from plugin cache while writing elsewhere should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "cat ${PLUGIN_CACHE_PATH}/some-plugin/template.md | sed 's/foo/bar/' > /tmp/template.out")
assert_passes "F-07: read from plugin cache with workspace redirect is allowed" "$out"
teardown

# Test 19c: cp from plugin cache template into project workspace is ALLOWED (#227)
setup
out=$(run_hook_bash "PreToolUse" "cp ${PLUGIN_CACHE_PATH}/some-plugin/template.md ${TMPDIR_TEST}/silver-bullet.md")
assert_passes "F-07: cp from plugin cache into project workspace is allowed" "$out"
teardown

# Test 20: python3 execution of plugin binary should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "python3 ${PLUGIN_CACHE_PATH}/some-plugin/tool.py")
assert_passes "F-07: python3 execution of plugin binary is allowed" "$out"
teardown

# Test 21: ruby execution of plugin binary should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "ruby ${PLUGIN_CACHE_PATH}/some-plugin/tool.rb")
assert_passes "F-07: ruby execution of plugin binary is allowed" "$out"
teardown

# Test 22: cp into plugin cache should still be BLOCKED (write op)
setup
out=$(run_hook_bash "PreToolUse" "cp /tmp/patch.js ${PLUGIN_CACHE_PATH}/some-plugin/index.js")
assert_blocks "F-07: cp into plugin cache is still blocked" "$out"
teardown

# Test 22-uninstall: rm uninstalled plugin cache allowed when registry has no installPath (#222)
setup
UNINSTALL_CACHE="${PLUGIN_CACHE_PATH}/superpowers-marketplace"
mkdir -p "$UNINSTALL_CACHE"
REGISTRY="${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json"
mkdir -p "$(dirname "$REGISTRY")"
cat > "$REGISTRY" <<'EOF'
{
  "plugins": {
    "silver-bullet@alo-labs": [
      {
        "version": "0.43.0",
        "installPath": "REPLACE_SB_CACHE/alo-labs/silver-bullet/current"
      }
    ]
  }
}
EOF
python3 - "$REGISTRY" "${PLUGIN_CACHE_PATH}/alo-labs/silver-bullet/current" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["plugins"]["silver-bullet@alo-labs"][0]["installPath"] = sys.argv[2]
path.write_text(json.dumps(data, indent=2) + "\n")
PY
out=$(run_hook_bash "PreToolUse" "rm -rf ${UNINSTALL_CACHE}")
assert_passes "F-07: rm uninstalled plugin cache dir allowed when registry omits it" "$out"
teardown

# Test 22-uninstall-block: rm still blocked when installPath references cache subtree
setup
INSTALLED_CACHE="${PLUGIN_CACHE_PATH}/episodic-memory-dev/episodic-memory/1.2.3"
mkdir -p "$INSTALLED_CACHE"
REGISTRY="${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json"
mkdir -p "$(dirname "$REGISTRY")"
cat > "$REGISTRY" <<EOF
{
  "plugins": {
    "episodic-memory@episodic-memory-dev": [
      {
        "version": "1.2.3",
        "installPath": "${INSTALLED_CACHE}"
      }
    ]
  }
}
EOF
out=$(run_hook_bash "PreToolUse" "rm -rf ${INSTALLED_CACHE}")
assert_blocks "F-07: rm installed plugin cache dir still blocked when registry references it" "$out"
teardown

# Test 22a: script indirection through a symlink into plugin cache is blocked
setup
mkdir -p "$TMPDIR_TEST/.hook-probes"
PLUGIN_CACHE_TARGET="${PLUGIN_CACHE_PATH}/some-plugin/index.js"
mkdir -p "$(dirname "$PLUGIN_CACHE_TARGET")"
touch "$PLUGIN_CACHE_TARGET"
ln -s "$PLUGIN_CACHE_TARGET" "$TMPDIR_TEST/.hook-probes/plugin-link"
cat > "$TMPDIR_TEST/.hook-probes/probe.sh" <<'EOF'
printf '// plugin tamper\n' >> .hook-probes/plugin-link
EOF
chmod +x "$TMPDIR_TEST/.hook-probes/probe.sh"
out=$(run_hook_bash "PreToolUse" "bash .hook-probes/probe.sh")
assert_blocks "F-07: script write through symlinked plugin cache target is blocked" "$out"
teardown

# Test 22b: wrapped shell script indirection into plugin cache is blocked
setup
mkdir -p "$TMPDIR_TEST/.hook-probes"
PLUGIN_CACHE_TARGET="${PLUGIN_CACHE_PATH}/some-plugin/index.js"
mkdir -p "$(dirname "$PLUGIN_CACHE_TARGET")"
touch "$PLUGIN_CACHE_TARGET"
ln -s "$PLUGIN_CACHE_TARGET" "$TMPDIR_TEST/.hook-probes/plugin-link"
cat > "$TMPDIR_TEST/.hook-probes/probe.sh" <<'EOF'
printf '// plugin tamper\n' >> .hook-probes/plugin-link
EOF
chmod +x "$TMPDIR_TEST/.hook-probes/probe.sh"
out=$(run_hook_bash "PreToolUse" "/bin/zsh -lc 'bash .hook-probes/probe.sh'")
assert_blocks "F-07: wrapped shell script write through symlinked plugin cache target is blocked" "$out"
teardown

# Tests 23-27: Hooks self-protection — execution vs write (fallback path, no CLAUDE_PLUGIN_ROOT)
# After Bug 2 fix: fallback only blocks paths inside ${SB_RUNTIME_HOME_ROOT}/ (the installed plugin
# location). Use the real installed plugin hooks path for write-blocking tests.
echo "--- Group 10: Hooks self-protection execution vs write ---"
SB_INSTALLED_HOOKS="${SB_RUNTIME_HOME_ROOT}/plugins/cache/alo-labs/silver-bullet/hooks"

# Test 23: node execution of something in installed hooks dir should be ALLOWED (no write op)
setup
out=$(run_hook_bash "PreToolUse" "node ${SB_INSTALLED_HOOKS}/some-util.js --check")
assert_passes "hooks-protect: node execution in installed hooks dir is allowed" "$out"
teardown

# Test 24: node with redirect into installed hooks dir should be BLOCKED (write under ${SB_RUNTIME_HOME_ROOT}/)
setup
out=$(run_hook_bash "PreToolUse" "node ${SB_INSTALLED_HOOKS}/build.js > ${SB_INSTALLED_HOOKS}/out.js")
assert_blocks "hooks-protect: node with redirect into installed hooks dir is blocked" "$out"
teardown

# Test 25: python3 execution in installed hooks dir should be ALLOWED (no write op)
setup
out=$(run_hook_bash "PreToolUse" "python3 ${SB_INSTALLED_HOOKS}/util.py --dry-run")
assert_passes "hooks-protect: python3 execution in installed hooks dir is allowed" "$out"
teardown

# Test 26: ruby execution in installed hooks dir should be ALLOWED (no write op)
setup
out=$(run_hook_bash "PreToolUse" "ruby ${SB_INSTALLED_HOOKS}/util.rb --check")
assert_passes "hooks-protect: ruby execution in installed hooks dir is allowed" "$out"
teardown

# Test 27: cp into installed hooks dir should be BLOCKED (write under ${SB_RUNTIME_HOME_ROOT}/)
setup
out=$(run_hook_bash "PreToolUse" "cp /tmp/evil.sh ${SB_INSTALLED_HOOKS}/dev-cycle-check.sh")
assert_blocks "hooks-protect: cp into installed hooks dir is still blocked" "$out"
teardown

# Test 27b: read-only inspection of installed hooks dir should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "sed -n '1,5p' ${SB_INSTALLED_HOOKS}/dev-cycle-check.sh")
assert_passes "hooks-protect: read-only sed inspection in installed hooks dir is allowed" "$out"
teardown

# Bug 2 regression: source repo hooks/ (outside ${SB_RUNTIME_HOME_ROOT}/) must NOT be falsely blocked.
# Before the fix the fallback used /silver-bullet[^/]*/hooks/ which caught both the
# installed plugin AND the source repo, preventing legitimate hook edits in dev.
echo "--- Group 11: Bug 2 regression — source repo hooks/ not falsely blocked ---"
SB_SOURCE_HOOKS_DIR="$(dirname "$HOOK")"  # absolute path to this repo's hooks/ dir

# Test 28: cp to source repo hooks/ is NOT blocked (path outside ${SB_RUNTIME_HOME_ROOT}/)
setup
out=$(run_hook_bash "PreToolUse" "cp /tmp/patch.sh ${SB_SOURCE_HOOKS_DIR}/dev-cycle-check.sh")
assert_passes "Bug2: cp into source repo hooks/ not blocked (not under ${SB_RUNTIME_HOME_ROOT}/)" "$out"
teardown

# Test 29: Edit to source repo hooks/ file is NOT blocked (path outside ${SB_RUNTIME_HOME_ROOT}/)
setup
out=$(run_hook_edit "PreToolUse" "${SB_SOURCE_HOOKS_DIR}/dev-cycle-check.sh" "old content long enough to pass threshold" "new content long enough to pass threshold too")
assert_passes "Bug2: Edit to source repo hooks/ not blocked (not under ${SB_RUNTIME_HOME_ROOT}/)" "$out"
teardown

# ── Composed-workflow gate (Pass 1: deferred — gate falls through to legacy) ──
# v0.29.x retired the legacy single-file `.planning/WORKFLOW.md` gate; see
# completion-audit.sh for full rationale. Until Pass 2 lands, both
# WORKFLOW.md and `.planning/workflows/<id>.md` files are ignored, and the
# dev-cycle gate falls through to the legacy required-skills check.
echo ""
echo "=== Composed-workflow gate (Pass 1: WORKFLOW.md ignored) ==="

# WF-PASS1-A: a stale WORKFLOW.md with all paths complete must NOT bypass
# the legacy required-skills gate when state has no silver-quality-gates.
echo "--- WF-PASS1-A: stale WORKFLOW.md does not bypass legacy gate ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 13 | SHIP | complete |
WFEOF
# Empty state -> legacy gate must block
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS1-A: stale WORKFLOW.md doesn't override legacy block" "$out"
teardown

# WF-PASS1-B: existing-but-empty `.planning/workflows/` dir must also fall
# through to legacy gate.
echo "--- WF-PASS1-B: workflows/ dir does not bypass legacy gate ---"
setup
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md" << 'WFEOF'
**Composer:** /sb:feature
**Status:** active
### Flow Log
| # | Flow | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
WFEOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS1-B: workflows/ dir doesn't override legacy block" "$out"
teardown

# WF-PASS1-C: no .planning at all -> legacy gate fires (sanity baseline)
echo "--- WF-PASS1-C: no composition state at all -> legacy gate ---"
setup
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS1-C: no .planning + no skills -> block" "$out"
teardown

# ── Composed-workflow gate (Pass 2: active workflows require SB_WORKFLOW_ID) ──
echo ""
echo "=== Composed-workflow gate (Pass 2: SB_WORKFLOW_ID admission control) ==="

# WF-PASS2-A: active composed workflow with no SB_WORKFLOW_ID is blocked
echo "--- WF-PASS2-A: active workflow without SB_WORKFLOW_ID is blocked ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS2-A: active workflow requires SB_WORKFLOW_ID" "$out"
assert_contains "WF-PASS2-A: block mentions SB_WORKFLOW_ID" "$out" "SB_WORKFLOW_ID"
teardown

# WF-PASS2-B: mismatched SB_WORKFLOW_ID is blocked
echo "--- WF-PASS2-B: mismatched SB_WORKFLOW_ID is blocked ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(SB_WORKFLOW_ID="20260510T000000Z-abc123-silver-feature" run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS2-B: mismatched SB_WORKFLOW_ID blocks source edit" "$out"
assert_contains "WF-PASS2-B: block mentions no active workflow match" "$out" "no active workflow file matches"
teardown

# WF-PASS2-C: active workflow admission applies to MultiEdit too
echo "--- WF-PASS2-C: active workflow admission applies to MultiEdit too ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_multiedit "PreToolUse" "$TMPFILE")
assert_blocks "WF-PASS2-C: MultiEdit is gated the same as Edit/Write" "$out"
assert_contains "WF-PASS2-C: MultiEdit block mentions SB_WORKFLOW_ID" "$out" "SB_WORKFLOW_ID"
teardown

# WF-PASS2-D: matching SB_WORKFLOW_ID allows the edit to reach the legacy gate
echo "--- WF-PASS2-D: matching SB_WORKFLOW_ID reaches legacy gate ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
finishing-a-development-branch
EOF
out=$(SB_WORKFLOW_ID="$workflow_id" run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "WF-PASS2-D: matching SB_WORKFLOW_ID allows source edit" "$out"
assert_contains "WF-PASS2-D: output references workflow completion" "$out" "All workflow phases complete"
teardown

# WF-PASS2-E: active workflow does not block read-only source inspection
echo "--- WF-PASS2-E: active workflow allows read-only source inspection ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_bash "PreToolUse" "nl -ba src/app.js | tail -20")
assert_passes "WF-PASS2-E: read-only nl/tail inspection is not gated by SB_WORKFLOW_ID" "$out"
teardown

# WF-PASS2-F: active workflow does not block test commands that mention source paths
echo "--- WF-PASS2-F: active workflow allows validation test commands ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_bash "PreToolUse" "npm test -- src/app.js")
assert_passes "WF-PASS2-F: npm test command is not treated as a source edit" "$out"
teardown

# WF-PASS2-G: active workflow does not block the SB adapter skill invocation path
echo "--- WF-PASS2-G: active workflow allows SB adapter skill invocation ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_bash "PreToolUse" "${SB_RUNTIME_HOME_ROOT}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/scripts/silver-bullet invoke-skill security 'review src/app.js'")
assert_passes "WF-PASS2-G: silver-bullet invoke-skill adapter can continue workflows" "$out"
teardown

# WF-PASS2-G2: quoted shell punctuation in adapter arguments is still a plain adapter invocation
echo "--- WF-PASS2-G2: adapter arguments may contain quoted punctuation ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
out=$(run_hook_bash "PreToolUse" "${SB_RUNTIME_HOME_ROOT}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/scripts/silver-bullet invoke-skill security 'review src/app.js; do not edit directly'")
assert_passes "WF-PASS2-G2: quoted semicolon in adapter argument does not trigger admission gate" "$out"
teardown

# WF-PASS2-H: inline SB_WORKFLOW_ID assignment admits Bash source edits
echo "--- WF-PASS2-H: inline SB_WORKFLOW_ID assignment admits Bash source edits ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
finishing-a-development-branch
EOF
out=$(run_hook_bash "PreToolUse" "SB_WORKFLOW_ID=$workflow_id perl -0pi -e 's/old/new/' src/app.js")
assert_passes "WF-PASS2-H: inline matching SB_WORKFLOW_ID allows Bash source edit" "$out"
teardown

# WF-PASS2-I: inline mismatched SB_WORKFLOW_ID still blocks Bash source edits
echo "--- WF-PASS2-I: inline mismatched SB_WORKFLOW_ID still blocks ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
finishing-a-development-branch
EOF
out=$(run_hook_bash "PreToolUse" "SB_WORKFLOW_ID=20260510T000000Z-abc123-silver-feature perl -0pi -e 's/old/new/' src/app.js")
assert_blocks "WF-PASS2-I: inline mismatched SB_WORKFLOW_ID blocks Bash source edit" "$out"
assert_contains "WF-PASS2-I: block mentions no active workflow match" "$out" "no active workflow file matches"
teardown

# WF-PASS2-J: export-style inline SB_WORKFLOW_ID admits Bash source edits
echo "--- WF-PASS2-J: export-style SB_WORKFLOW_ID assignment admits Bash source edits ---"
setup
workflow_id=$(create_active_workflow silver-feature "admission control" "bootstrap,execute,ship")
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
finishing-a-development-branch
EOF
out=$(run_hook_bash "PreToolUse" "export SB_WORKFLOW_ID=$workflow_id; perl -0pi -e 's/old/new/' src/app.js")
assert_passes "WF-PASS2-J: export-style matching SB_WORKFLOW_ID allows Bash source edit" "$out"
teardown

# WF-PASS2-K: orchestrator-seeded flow CSV labels + SB_WORKFLOW_ID admission
echo "--- WF-PASS2-K: orchestrator-seeded flow CSV workflow ---"
setup
ORCH_LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
# shellcheck source=/dev/null
source "$ORCH_LIB"
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/SPEC.md" <<'EOF'
spec-version: 1.0
# admission test spec
EOF
orch_flows="$(sb_orchestrator_flow_csv_for_workflows silver-feature)"
workflow_id=$(cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "/sb:feature" "orchestrator-seeded flows" "$orch_flows")
wf_body="$(cat "$TMPDIR_TEST/.planning/workflows/${workflow_id}.md")"
assert_contains "WF-PASS2-K: workflow uses QUALITY GATE label" "$wf_body" "QUALITY GATE"
assert_contains "WF-PASS2-K: workflow uses EXECUTE label" "$wf_body" "EXECUTE"
assert_not_contains "WF-PASS2-K: workflow avoids legacy bootstrap label" "$wf_body" "bootstrap"
out=$(SB_WORKFLOW_ID="$workflow_id" run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF-PASS2-K: orchestrator-seeded workflow still blocks without planning skills" "$out"
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
finishing-a-development-branch
EOF
out=$(SB_WORKFLOW_ID="$workflow_id" run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "WF-PASS2-K: matching SB_WORKFLOW_ID admits edit on orchestrator-seeded workflow" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
