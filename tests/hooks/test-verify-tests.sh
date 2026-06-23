#!/usr/bin/env bash
# Tests for scripts/verify-tests.sh
# Verifies configured verify_commands, stack-default fallback, marker creation,
# and failure-path behavior.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/scripts/verify-tests.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
VERIFY_MARKER="${SB_TEST_DIR}/verify-tests-marker-${TEST_RUN_ID}"

cleanup_all() {
  rm -rf "${TMP_REPO_CONFIGURED:-}" "${TMP_REPO_DEFAULT:-}" "${TMP_REPO_FAILING:-}" 2>/dev/null || true
  rm -f "$VERIFY_MARKER" 2>/dev/null || true
}
trap cleanup_all EXIT

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

run_hook() {
  local workdir="$1"
  HOOK_OUTPUT=""
  HOOK_EXIT=0
  set +e
  HOOK_OUTPUT=$(
    cd "$workdir" &&
    SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_MARKER" \
      bash "$HOOK" 2>&1
  )
  HOOK_EXIT=$?
  set -e
}

make_configured_repo() {
  TMP_REPO_CONFIGURED=$(mktemp -d)
  cat > "$TMP_REPO_CONFIGURED/.silver-bullet.json" <<'EOF'
{
  "verify_commands": [
    "echo configured-one >> verify.log",
    "echo configured-two >> verify.log"
  ]
}
EOF
}

make_default_repo() {
  TMP_REPO_DEFAULT=$(mktemp -d)
  cat > "$TMP_REPO_DEFAULT/.silver-bullet.json" <<'EOF'
{}
EOF
  mkdir -p "$TMP_REPO_DEFAULT/tests"
  cat > "$TMP_REPO_DEFAULT/tests/run-all-tests.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo default-ran > default.log
EOF
}

make_failing_repo() {
  TMP_REPO_FAILING=$(mktemp -d)
  cat > "$TMP_REPO_FAILING/.silver-bullet.json" <<'EOF'
{
  "verify_commands": [
    "false"
  ]
}
EOF
}

echo "=== verify-tests.sh tests ==="

# Test 1: configured verify_commands run in order and write the marker
echo "--- Test 1: configured verify_commands ---"
make_configured_repo
run_hook "$TMP_REPO_CONFIGURED"
if [[ $HOOK_EXIT -eq 0 ]]; then
  echo "  ✅ configured commands passed"
  PASS=$((PASS + 1))
else
  echo "  ❌ configured commands failed unexpectedly: $HOOK_OUTPUT"
  FAIL=$((FAIL + 1))
fi
assert_contains "configured gate reports config source" "$HOOK_OUTPUT" "Using verify_commands from .silver-bullet.json"
assert_contains "configured gate ran first command" "$(cat "$TMP_REPO_CONFIGURED/verify.log" 2>/dev/null || true)" "configured-one"
assert_contains "configured gate ran second command" "$(cat "$TMP_REPO_CONFIGURED/verify.log" 2>/dev/null || true)" "configured-two"
assert_file_exists "configured gate wrote freshness marker" "$VERIFY_MARKER"

rm -f "$VERIFY_MARKER"

# Test 2: stack-default fallback uses tests/run-all-tests.sh when no verify_commands exist
echo "--- Test 2: stack-default fallback ---"
make_default_repo
run_hook "$TMP_REPO_DEFAULT"
if [[ $HOOK_EXIT -eq 0 ]]; then
  echo "  ✅ default fallback passed"
  PASS=$((PASS + 1))
else
  echo "  ❌ default fallback failed unexpectedly: $HOOK_OUTPUT"
  FAIL=$((FAIL + 1))
fi
assert_contains "default gate reports fallback source" "$HOOK_OUTPUT" "Using stack default test command(s)"
assert_contains "default gate ran run-all-tests" "$HOOK_OUTPUT" "Running: bash tests/run-all-tests.sh"
assert_file_exists "default gate wrote freshness marker" "$VERIFY_MARKER"
assert_file_exists "default gate wrote default log" "$TMP_REPO_DEFAULT/default.log"

rm -f "$VERIFY_MARKER"

# Test 3: failure path does not write the marker
echo "--- Test 3: failure path ---"
make_failing_repo
run_hook "$TMP_REPO_FAILING"
if [[ $HOOK_EXIT -ne 0 ]]; then
  echo "  ✅ failing command returned non-zero"
  PASS=$((PASS + 1))
else
  echo "  ❌ failing command unexpectedly succeeded: $HOOK_OUTPUT"
  FAIL=$((FAIL + 1))
fi
assert_contains "failing gate reports command" "$HOOK_OUTPUT" "Running: false"
assert_file_missing "failing gate does not write freshness marker" "$VERIFY_MARKER"

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
