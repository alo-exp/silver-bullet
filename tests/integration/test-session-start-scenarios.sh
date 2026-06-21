#!/usr/bin/env bash
# Integration test: Session-start hook scenarios
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Session-Start Scenarios ==="

echo "--- Scenario 1: Branch change resets state ---"
integration_setup
write_default_config
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
EOF
printf 'feature/old-branch' > "$TMPBRANCH"
out=$(run_session_start)
if [[ ! -f "$TMPSTATE" ]] || [[ ! -s "$TMPSTATE" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: state deleted on branch change\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.1: state still exists after branch change (contents: %s)\n' "$(cat "$TMPSTATE")"
fi
integration_teardown

echo "--- Scenario 2: Same branch preserves lifecycle markers ---"
integration_setup
write_default_config
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
silver-execute
custom-marker-1
EOF
out=$(run_session_start)
if grep -q "silver-quality-gates" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: silver-quality-gates skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: silver-quality-gates skill was removed\n'
fi
if grep -qx "silver-review" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.2: silver-review skill retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.2: silver-review skill was removed\n'
fi
if grep -qx "silver-execute" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.3: SB lifecycle markers retained\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.3: SB lifecycle markers were removed\n'
fi
if grep -q "custom-marker-1" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.4: custom marker preserved on same-branch restart\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.4: custom marker was incorrectly wiped on same-branch restart\n'
fi
integration_teardown

echo "--- Scenario 3: Trivial file removed ---"
integration_setup
write_default_config
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_session_start)
if [[ ! -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S3.1: trivial file removed on session start\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.1: trivial file still exists after session start\n'
fi
integration_teardown

echo "--- Scenario 4: Core-rules or silent output from session-start ---"
integration_setup
write_default_config
out=$(run_session_start)
if printf '%s' "$out" | jq -e '.' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: session-start produces valid JSON output\n'
elif [[ -z "$out" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: session-start silent (no SP/core-rules configured)\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.1: session-start output is neither valid JSON nor empty: %s\n' "$out"
fi
integration_teardown

print_results
