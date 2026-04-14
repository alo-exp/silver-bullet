#!/usr/bin/env bash
# Integration test: Session-start hook scenarios
# Tests branch change state reset, same-branch marker cleanup, trivial file removal, core-rules injection
#
# NOTE: session-start uses hardcoded SB_STATE_DIR/state and SB_STATE_DIR/branch paths,
# not the SILVER_BULLET_STATE_FILE env var. Tests save/restore these files around each scenario.
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

SB_REAL_STATE="${SB_TEST_DIR}/state"
SB_REAL_BRANCH="${SB_TEST_DIR}/branch"

# Save and restore actual state/branch around each scenario
save_real_state() {
  cp -f "$SB_REAL_STATE" "${SB_REAL_STATE}.scenario-bak" 2>/dev/null || true
  cp -f "$SB_REAL_BRANCH" "${SB_REAL_BRANCH}.scenario-bak" 2>/dev/null || true
}
restore_real_state() {
  if [[ -f "${SB_REAL_STATE}.scenario-bak" ]]; then
    mv "${SB_REAL_STATE}.scenario-bak" "$SB_REAL_STATE"
  else
    rm -f "$SB_REAL_STATE"
  fi
  if [[ -f "${SB_REAL_BRANCH}.scenario-bak" ]]; then
    mv "${SB_REAL_BRANCH}.scenario-bak" "$SB_REAL_BRANCH"
  else
    rm -f "$SB_REAL_BRANCH"
  fi
}

echo "=== Integration: Session-Start Scenarios ==="

# Scenario 1: Branch change deletes state file
echo "--- Scenario 1: Branch change resets state ---"
integration_setup
write_default_config
save_real_state

# Pre-populate real state with skills
cat > "$SB_REAL_STATE" << 'EOF'
quality-gates
code-review
EOF
# Record a different branch in branch file to trigger reset
echo "feature/old-branch" > "$SB_REAL_BRANCH"

# Run session-start from TMPDIR_TEST which is on feature/test branch
out=$(run_session_start)

# State file should be deleted (branch mismatch triggers full reset)
if [[ ! -f "$SB_REAL_STATE" ]] || [[ ! -s "$SB_REAL_STATE" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: state deleted on branch change\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.1: state still exists after branch change (contents: %s)\n' "$(cat "$SB_REAL_STATE")"
fi

restore_real_state
integration_teardown

# Scenario 2: Same branch cleans session markers but keeps skills
echo "--- Scenario 2: Same branch cleans markers, keeps skills ---"
integration_setup
write_default_config
save_real_state

# Store current branch (feature/test matches what integration_setup creates)
echo "feature/test" > "$SB_REAL_BRANCH"

# Pre-populate state with skills AND session markers (gsd-*)
cat > "$SB_REAL_STATE" << 'EOF'
quality-gates
code-review
gsd-execute-phase
EOF

out=$(run_session_start)

# Skills should remain, markers should be cleaned
if grep -q "quality-gates" "$SB_REAL_STATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: quality-gates skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: quality-gates skill was removed\n'
fi

if grep -q "code-review" "$SB_REAL_STATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.2: code-review skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.2: code-review skill was removed\n'
fi

# gsd-* markers should be removed
if ! grep -q "gsd-" "$SB_REAL_STATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.4: gsd- markers cleaned\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.4: gsd- markers still present\n'
fi

restore_real_state
integration_teardown

# Scenario 3: Trivial file removed on session start
echo "--- Scenario 3: Trivial file removed ---"
integration_setup
write_default_config
save_real_state

# Store matching branch
echo "feature/test" > "$SB_REAL_BRANCH"

# Create trivial file (using the path from config's state.trivial_file)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"

out=$(run_session_start)

if [[ ! -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S3.1: trivial file removed on session start\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.1: trivial file still exists after session start\n'
fi

restore_real_state
integration_teardown

# Scenario 4: Core-rules injected in output (or silent if no sp/core-rules found)
echo "--- Scenario 4: Core-rules or silent output from session-start ---"
integration_setup
write_default_config
save_real_state

# Store matching branch
echo "feature/test" > "$SB_REAL_BRANCH"

out=$(run_session_start)

# session-start should either produce valid JSON with additionalContext (if core-rules/SP found)
# or silent (no SP plugin or core-rules). Both are acceptable — the key check is no crash.
if printf '%s' "$out" | jq -e '.' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: session-start produces valid JSON output\n'
elif [[ -z "$out" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: session-start silent (no SP/core-rules configured)\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.1: session-start output is neither valid JSON nor empty: %s\n' "$out"
fi

restore_real_state
integration_teardown

print_results
