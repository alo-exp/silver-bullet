#!/usr/bin/env bash
# Integration test: Session-start hook scenarios
# Tests branch change state reset, same-branch marker cleanup, trivial file removal, core-rules injection
#
# NOTE: session-start reads state/branch via SILVER_BULLET_STATE_FILE and SILVER_BULLET_BRANCH_FILE
# env var overrides (set by integration_setup in helpers/common.sh). No live ~/.claude/ files are
# touched during these tests; save_real_state/restore_real_state are no longer needed.
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Session-Start Scenarios ==="

# Scenario 1: Branch change deletes state file
echo "--- Scenario 1: Branch change resets state ---"
integration_setup
write_default_config

# Pre-populate env-var-backed state with skills
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
EOF
# Set mock branch to "old-branch" so session-start detects a change.
# integration_setup created TMPBRANCH with "feature/test"; overwrite it here.
printf 'feature/old-branch' > "$TMPBRANCH"
# TMPDIR_TEST git repo is on "feature/test" → mismatch → full state reset

out=$(run_session_start)

# State file should be deleted/empty (branch mismatch triggers full reset)
if [[ ! -f "$TMPSTATE" ]] || [[ ! -s "$TMPSTATE" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: state deleted on branch change\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.1: state still exists after branch change (contents: %s)\n' "$(cat "$TMPSTATE")"
fi

integration_teardown

# Scenario 2: Same branch cleans session markers but keeps skills
echo "--- Scenario 2: Same branch cleans markers, keeps skills ---"
integration_setup
write_default_config

# TMPBRANCH already contains "feature/test" from integration_setup.
# Pre-populate env-var-backed state with skills AND session markers (gsd-*)
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
gsd-execute-phase
EOF

out=$(run_session_start)

# Skills should remain, markers should be cleaned (both in $TMPSTATE via env var)
if grep -q "silver-quality-gates" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: silver-quality-gates skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: silver-quality-gates skill was removed\n'
fi

if grep -q "code-review" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.2: code-review skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.2: code-review skill was removed\n'
fi

# gsd-* markers should be removed
if ! grep -q "gsd-" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.4: gsd- markers cleaned\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.4: gsd- markers still present\n'
fi

integration_teardown

# Scenario 3: Trivial file removed on session start
echo "--- Scenario 3: Trivial file removed ---"
integration_setup
write_default_config
# TMPBRANCH already contains "feature/test" from integration_setup.
# session-start follows SILVER_BULLET_BRANCH_FILE — no need to write real branch file.

# Create trivial file (using the path from config's state.trivial_file)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"

out=$(run_session_start)

if [[ ! -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S3.1: trivial file removed on session start\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.1: trivial file still exists after session start\n'
fi

integration_teardown

# Scenario 4: Core-rules injected in output (or silent if no sp/core-rules found)
echo "--- Scenario 4: Core-rules or silent output from session-start ---"
integration_setup
write_default_config
# TMPBRANCH already contains "feature/test" from integration_setup.

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

integration_teardown

print_results
