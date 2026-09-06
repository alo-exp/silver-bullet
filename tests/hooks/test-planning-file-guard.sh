#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/planning-file-guard.sh"
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

TRIVIAL_FILE="${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
# Use the real hook path so the EXIT trap crash-safely cleans it up (CR-02)
OVERRIDE_FILE="${SB_TEST_DIR}/planning-edit-override"

cleanup_all() {
  rm -f "$TRIVIAL_FILE" "$OVERRIDE_FILE" "${SB_TEST_DIR}/roadmap-edit-override" 2>/dev/null || true
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST" || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  cat > "${TMPDIR_TEST}/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "${TMPDIR_TEST}/.silver-bullet.json" << EOF
{
  "project": {},
  "state": { "trivial_file": "${TRIVIAL_FILE}" }
}
EOF
  mkdir -p "${TMPDIR_TEST}/.planning"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TRIVIAL_FILE" "$OVERRIDE_FILE"
  TMPDIR_TEST=""
}

run_hook_edit() {
  local file_path="$1"
  local input
  input=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$file_path")
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_write() {
  local file_path="$1"
  local input
  input=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$file_path")
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_apply_patch() {
  local patch="$1"
  local input
  input=$(jq -n --arg p "$patch" \
    '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"'; then
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
  if ! printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"'; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== planning-file-guard.sh tests ==="

echo "--- Group 1: Protected files are blocked ---"

for protected_file in ROADMAP.md STATE.md PROJECT.md RELEASE.md REQUIREMENTS.md UAT.md; do
  setup
  out=$(run_hook_edit "${TMPDIR_TEST}/.planning/${protected_file}")
  assert_blocks "blocks Edit on .planning/${protected_file}" "$out"
  out=$(run_hook_write "${TMPDIR_TEST}/.planning/${protected_file}")
  assert_blocks "blocks Write on .planning/${protected_file}" "$out"
  teardown
done

echo "--- Group 1b: SB-owned planning files are NOT blocked ---"

# SB-owned spec/quality artifacts are allowed; GSD lifecycle files above are protected.
for sb_managed_file in SPEC.md QUALITY-GATES.md; do
  setup
  out=$(run_hook_edit "${TMPDIR_TEST}/.planning/${sb_managed_file}")
  assert_passes "does not block SB-owned .planning/${sb_managed_file}" "$out"
  out=$(run_hook_write "${TMPDIR_TEST}/.planning/${sb_managed_file}")
  assert_passes "does not block SB-owned Write on .planning/${sb_managed_file}" "$out"
  teardown
done

# Milestone audit pattern
setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/v1.0.0-MILESTONE-AUDIT.md")
assert_blocks "blocks Edit on .planning/v*-MILESTONE-*.md" "$out"
teardown

echo "--- Group 1c: SB phase lifecycle artifacts are NOT blocked ---"

setup
mkdir -p "${TMPDIR_TEST}/.planning/phases/01-init"
for phase_file in PLAN.md VERIFICATION.md REVIEW.md SECURITY.md SUMMARY.md; do
  out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/01-init/${phase_file}")
  assert_passes "does not block SB phase .planning/phases/01-init/${phase_file}" "$out"
done
teardown

setup
mkdir -p "${TMPDIR_TEST}/.planning/phases/094-sb-alignment"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/094-sb-alignment/094-01-VERIFICATION.md")
assert_blocks "blocks nested numbered phase VERIFICATION artifacts" "$out"
teardown

echo "--- Group 2: Non-planning files are NOT blocked ---"

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/01-init/PLAN.md")
assert_passes "does not block phase directory files" "$out"
teardown

setup
mkdir -p "${TMPDIR_TEST}/.planning/phases/094-sb-alignment"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/094-sb-alignment/094-01-PLAN.md")
assert_blocks "blocks nested numbered GSD PLAN artifacts" "$out"
teardown

setup
out=$(run_hook_edit "${TMPDIR_TEST}/src/main.py")
assert_passes "does not block regular source files" "$out"
teardown

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/WORKFLOW.md")
assert_passes "does not block .planning/WORKFLOW.md (not protected)" "$out"
teardown

echo "--- Group 3: Bypasses ---"

# Trivial bypass: trivial file present → allow edit
setup
touch "$TRIVIAL_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "trivial bypass allows protected file edit" "$out"
teardown

# File-based override — uses $OVERRIDE_FILE so EXIT trap covers crash-safe cleanup
# M-03: override applies to PLAN.md only (not ROADMAP.md)
setup
mkdir -p "${TMPDIR_TEST}/.planning/phases/launch-remediation"
touch "$OVERRIDE_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/launch-remediation/PLAN.md")
assert_passes "planning-edit-override file allows PLAN.md edit" "$out"
rm -f "$OVERRIDE_FILE"
teardown

setup
touch "$OVERRIDE_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_blocks "planning-edit-override does not allow ROADMAP.md edit" "$out"
rm -f "$OVERRIDE_FILE"
teardown

# roadmap-edit-override allows ROADMAP.md and STATE.md for sb:phase / sb:undo
ROADMAP_OVERRIDE_FILE="${SB_TEST_DIR}/roadmap-edit-override"
setup
touch "$ROADMAP_OVERRIDE_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "roadmap-edit-override allows ROADMAP.md edit" "$out"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/STATE.md")
assert_passes "roadmap-edit-override allows STATE.md edit" "$out"
rm -f "$ROADMAP_OVERRIDE_FILE"
teardown

# Env-var bypass: SB_ALLOW_PLANNING_EDITS=1 → allow edit
setup
out=$(SB_ALLOW_PLANNING_EDITS=1 run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "SB_ALLOW_PLANNING_EDITS=1 allows protected file edit" "$out"
teardown

# No .silver-bullet.json → not a SB project → skip
setup_bare() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "${TMPDIR_TEST}/.planning"
}
setup_bare
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "no .silver-bullet.json → not a SB project → skip" "$out"
teardown

echo "--- Group 4: Block message contains skill hint ---"

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
if printf '%s' "$out" | grep -q "sb:phase\|sb:plan\|sb:add\|sb:release"; then
  echo "  ✅ ROADMAP block message mentions owning skills"
  PASS=$((PASS + 1))
else
  echo "  ❌ ROADMAP block message missing skill hint: $out"
  FAIL=$((FAIL + 1))
fi
teardown

echo "--- Group 5: MultiEdit tool is also blocked (IN-02) ---"

run_hook_multiedit() {
  local file_path="$1"
  local input
  input=$(printf '{"tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[]}}' "$file_path")
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

setup
out=$(run_hook_multiedit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_blocks "blocks MultiEdit on .planning/ROADMAP.md" "$out"
teardown

echo "--- Group 6: Path traversal bypass is blocked (IN-03) ---"

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/sub/../ROADMAP.md")
assert_blocks "path traversal .planning/sub/../ROADMAP.md is blocked" "$out"
teardown

setup
out=$(run_hook_apply_patch "*** Begin Patch
*** Update File: .planning/sub/../ROADMAP.md
@@
+forbidden planning edit
*** End Patch")
assert_blocks "apply_patch path traversal .planning/sub/../ROADMAP.md is blocked" "$out"
teardown

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/x/../STATE.md")
assert_blocks "path traversal .planning/x/../STATE.md is blocked" "$out"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
