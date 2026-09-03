#!/usr/bin/env bash
# Tests for hooks/workflow-chain-guard.sh
# Verifies composed Silver Bullet workflows block implementation edits until
# the downstream dependency markers are actually recorded.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/workflow-chain-guard.sh"
WORKFLOWS_SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/workflows.sh"
PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.planning"
  mkdir -p "$TMPDIR_TEST/src"
  cat > "$TMPDIR_TEST/.planning/SPEC.md" <<'EOF'
spec-version: 1.0
# Test spec (skips conditional silver-spec gate)
EOF
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "sb_initiated": true,
  "state": { "state_file": "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" }
}
EOF
  touch "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
}

teardown() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" 2>/dev/null || true
}

start_workflow() {
  local composer="$1"
  local intent="$2"
  local flows="$3"
  ( cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "$composer" "$intent" "$flows" >/dev/null )
}

write_state_markers() {
  local markers=("$@")
  : > "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
  for marker in "${markers[@]}"; do
    printf '%s\n' "$marker" >> "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
  done
}

run_hook_edit() {
  local file_path="$1"
  local input
  input=$(jq -n --arg f "$file_path" '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old", new_string:"new"}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_apply_patch() {
  local patch="$1"
  local input
  input=$(jq -n --arg p "$patch" '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_denied() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"|"decision"\s*:\s*"block"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== workflow-chain-guard.sh tests ==="

# Feature workflow: missing pre-execution SB markers should block implementation edits.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "feature gate test" "bootstrap,design,execute,verify"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature blocks without SB pre-execution markers" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature passes after SB-owned pre-execution markers exist" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature legacy markers satisfy SB-owned aliases" "$out"
teardown

# UI workflow: UI-specific pre-execution SB markers must be present.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:ui" "ui gate test" "orient,design,plan,execute,review,verify"
write_state_markers silver-context silver-ui-contract silver-plan
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui blocks until UI pre-execution markers are present" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui passes after SB-owned UI pre-execution markers exist" "$out"
write_state_markers silver-quality-gates silver-context silver-ui-contract silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui legacy UI markers satisfy SB-owned aliases" "$out"
teardown

# Deep research workflow: clarify + deep-research markers are required.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:deep-research" "research gate test" "clarify,research,hand-off"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:deep-research blocks without clarify marker" "$out"
write_state_markers silver-clarify
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:deep-research blocks with only clarify marker (research missing)" "$out"
write_state_markers silver-clarify silver-deep-research
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:deep-research passes after clarify + research markers exist" "$out"
teardown

# Multiple active workflows: SB_WORKFLOW_ID scopes the guard to one workflow file.
setup
touch "$TMPDIR_TEST/src/app.js"
wf_a=$( cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "/silver:feature" "wf-a" "plan,execute" )
wf_b=$( cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "/silver:bugfix" "wf-b" "debug,plan" )
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
input=$(jq -n --arg f "$TMPDIR_TEST/src/app.js" '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old", new_string:"new"}}')
out=$( cd "$TMPDIR_TEST" && export SB_WORKFLOW_ID="$wf_a" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
assert_passes "multiple active workflows pass when SB_WORKFLOW_ID scopes to prepared workflow" "$out"
teardown

# silver-fast Tier 2: quality-gates + plan + validate before edits (context optional).
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:fast" "fast gate test" "context,plan,execute,verify"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:fast blocks without quality-gates/plan/validate markers" "$out"
write_state_markers silver-quality-gates-design silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:fast passes after Tier 2 pre-execution markers exist" "$out"
teardown

# silver-fast Tier 1: no active workflow tracker — edits are not chain-guarded.
setup
touch "$TMPDIR_TEST/src/app.js"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:fast Tier 1 without workflow tracker does not block edits" "$out"
teardown

# silver-devops: full pre-execution chain including validate (plan-only when no SPEC).
setup
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
touch "$TMPDIR_TEST/infra.tf"
start_workflow "/silver:devops" "devops gate test" "blast-radius,plan,execute,verify"
out=$(run_hook_edit "$TMPDIR_TEST/infra.tf")
assert_blocks "silver:devops blocks without pre-execution markers" "$out"
write_state_markers silver-blast-radius devops-skill-router devops-quality-gates security silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/infra.tf")
assert_passes "silver:devops passes after full pre-execution chain (no SPEC — plan-only validate)" "$out"
teardown

# Feature without SPEC.md requires silver-clarify then silver-spec markers.
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:feature" "feature no spec" "plan,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature without SPEC.md blocks until clarify+spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature without SPEC.md still blocks with spec but no clarify" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-clarify silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature without SPEC.md passes after clarify+spec markers" "$out"
teardown

# Feature with existing SPEC.md skips silver-spec requirement.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "feature with spec" "plan,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature with SPEC.md skips silver-spec marker" "$out"
teardown

# UI without SPEC.md requires silver-clarify then silver-spec (same as feature).
setup
touch "$TMPDIR_TEST/src/app.js"
rm -f "$TMPDIR_TEST/.planning/SPEC.md"
start_workflow "/silver:ui" "ui no spec" "plan,design,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui without SPEC.md blocks until clarify+spec recorded" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui without SPEC.md still blocks with spec but no clarify" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-clarify silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui without SPEC.md passes after clarify+spec markers" "$out"
teardown

# Bugfix workflow: diagnosis-first pre-execution chain is DEBUG → PLAN (B1).
# Quality-gates/context are NOT part of the bugfix pre-execution chain.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:bugfix" "bugfix gate test" "orient,debug,plan,execute,review,verify"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:bugfix blocks without DEBUG/PLAN markers" "$out"
write_state_markers silver-debug
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:bugfix still blocks with only DEBUG marker (PLAN missing)" "$out"
write_state_markers silver-debug silver-plan
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:bugfix passes after DEBUG + PLAN markers exist" "$out"
write_state_markers silver-debug silver-plan
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:bugfix legacy GSD debug/plan markers satisfy SB-owned aliases" "$out"
teardown

# silver-release: quality-gates must be recorded before release artifact edits.
setup
mkdir -p "$TMPDIR_TEST/docs"
touch "$TMPDIR_TEST/docs/CHANGELOG.md"
start_workflow "/silver:release" "release gate test" "quality-gate,audit,ship,create-release"
out=$(run_hook_edit "$TMPDIR_TEST/docs/CHANGELOG.md")
assert_blocks "silver:release blocks without silver-quality-gates marker" "$out"
write_state_markers silver-quality-gates-design
out=$(run_hook_edit "$TMPDIR_TEST/docs/CHANGELOG.md")
assert_passes "silver:release passes after pre-plan quality-gates marker exists" "$out"
teardown

# apply_patch must honor the same pre-execution chain as Edit (Codex parity).
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "apply_patch gate" "plan,execute"
out=$(run_hook_apply_patch "*** Begin Patch
*** Update File: src/app.js
@@
-old
+new
*** End Patch")
assert_blocks "apply_patch blocked without SB pre-execution markers" "$out"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_apply_patch "*** Begin Patch
*** Update File: src/app.js
@@
-old
+new
*** End Patch")
assert_passes "apply_patch passes after SB pre-execution markers exist" "$out"
teardown

# Post-exec markers alone must not satisfy the pre-execution chain guard.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "post-exec only gate" "plan,execute"
write_state_markers silver-execute silver-review-request silver-verify security silver-ship
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature blocks when only post-exec markers recorded" "$out"
teardown

# Pre-exec markers without post-exec markers must allow edits.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "pre-exec only gate" "plan,execute"
write_state_markers silver-quality-gates silver-context silver-plan silver-spec silver-validate
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature passes with pre-exec markers only (post-exec absent)" "$out"
teardown

# Only silver-execute recorded (plan missing) must block.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "execute without plan" "plan,execute"
write_state_markers silver-execute
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature blocks with only silver-execute marker (plan missing)" "$out"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
