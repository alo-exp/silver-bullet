#!/usr/bin/env bash
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/planning-file-guard.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

TRIVIAL_FILE="${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
# Use the real hook path so the EXIT trap crash-safely cleans it up (CR-02)
OVERRIDE_FILE="${SB_TEST_DIR}/planning-edit-override"

cleanup_all() {
  rm -f "$TRIVIAL_FILE" "$OVERRIDE_FILE" 2>/dev/null || true
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST" || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
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

for protected_file in ROADMAP.md STATE.md REQUIREMENTS.md PROJECT.md RELEASE.md UAT.md; do
  setup
  out=$(run_hook_edit "${TMPDIR_TEST}/.planning/${protected_file}")
  assert_blocks "blocks Edit on .planning/${protected_file}" "$out"
  out=$(run_hook_write "${TMPDIR_TEST}/.planning/${protected_file}")
  assert_blocks "blocks Write on .planning/${protected_file}" "$out"
  teardown
done

# Milestone audit pattern
setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/v1.0.0-MILESTONE-AUDIT.md")
assert_blocks "blocks Edit on .planning/v*-MILESTONE-*.md" "$out"
teardown

echo "--- Group 2: Non-planning files are NOT blocked ---"

setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/01-init/PLAN.md")
assert_passes "does not block phase directory files" "$out"
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
setup
touch "$OVERRIDE_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "planning-edit-override file allows protected file edit" "$out"
rm -f "$OVERRIDE_FILE"
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
if printf '%s' "$out" | grep -q "gsd-add-phase\|gsd-roadmapper"; then
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
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/x/../STATE.md")
assert_blocks "path traversal .planning/x/../STATE.md is blocked" "$out"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
