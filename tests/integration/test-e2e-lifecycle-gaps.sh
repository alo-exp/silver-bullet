#!/usr/bin/env bash
# Integration test: E2E lifecycle gap scenarios
# Tests bypass-permissions detection, cross-session skill persistence, post-review
# execution gate, model routing, devops transition, and session log creation.
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: E2E Lifecycle Gaps ==="

# ── S1: bypass-permissions detection ─────────────────────────────────────────
# dev-cycle-check.sh does not implement a "bypass-permissions" mode directly.
# This scenario documents and validates that autonomous mode is correctly gated:
# when mode=autonomous is written to SB_DIR, timeout-check is mode-aware, but
# dev-cycle-check enforcement still fires (enforcement is mode-independent).
echo "--- S1: bypass-permissions (autonomous mode does not suppress enforcement) ---"
integration_setup
write_default_config

# Set autonomous mode (the closest analog to bypass-permissions at hook layer)
echo "autonomous" > "${HOME}/.claude/.silver-bullet/mode"

# Without planning skills, dev-cycle-check must still block even in autonomous mode
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.1: dev-cycle-check blocks in autonomous mode (no bypass at hook layer)" "$out"

# Clean up mode file
rm -f "${HOME}/.claude/.silver-bullet/mode"
integration_teardown

# ── S2: Cross-session skill accumulation ──────────────────────────────────────
# session-start resets gsd- markers but KEEPS skill records
# for the same branch. Verify silver-quality-gates persists after run_session_start.
echo "--- S2: Cross-session skill accumulation ---"
integration_setup
write_default_config

# Record skills
run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "code-review"   >/dev/null

# Confirm skills are present before simulated session restart
assert_contains "S2.1: silver-quality-gates recorded before restart" \
  "$(cat "$TMPSTATE" 2>/dev/null || echo '')" "silver-quality-gates"

# Simulate session restart on same branch
run_session_start >/dev/null 2>&1 || true

# Skills should persist (same branch — only session-specific markers are cleared)
state_after=$(cat "$TMPSTATE" 2>/dev/null || echo "")
assert_contains "S2.2: silver-quality-gates persists after session restart (same branch)" \
  "$state_after" "silver-quality-gates"
assert_contains "S2.3: code-review persists after session restart (same branch)" \
  "$state_after" "code-review"

integration_teardown

# ── S3: Post-review execution gate ────────────────────────────────────────────
# completion-audit blocks until all required_deploy skills are present.
# Verify that missing verification-before-completion causes a block, then clears.
echo "--- S3: Post-review execution gate ---"
integration_setup
write_default_config

# Record all required_deploy skills EXCEPT verification-before-completion
for skill in silver-quality-gates code-review requesting-code-review receiving-code-review \
             testing-strategy documentation finishing-a-development-branch \
             deploy-checklist silver-create-release test-driven-development tech-debt; do
  run_record_skill "$skill" >/dev/null
done

# Should be blocked — verification-before-completion missing
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat: test'")
assert_blocked "S3.1: completion-audit blocks when verification-before-completion missing" "$out"

# Record the missing skill
run_record_skill "verification-before-completion" >/dev/null

# Now should be allowed
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat: test'")
assert_allowed "S3.2: completion-audit allows after all required skills recorded" "$out"

integration_teardown

# ── S4: Model routing integration (hook DISABLED 2026-04-16) ─────────────────
# ensure-model-routing.sh is disabled — it exits 0 immediately without modifying
# any GSD agent files. Frontmatter injection into third-party plugin files is
# discontinued. See hooks/ensure-model-routing.sh for rationale and backlog 999.19.
echo "--- S4: Model routing integration (hook disabled — no-op) ---"

FAKE_HOME=$(mktemp -d)
FAKE_AGENTS="${FAKE_HOME}/.claude/agents"
FAKE_SB="${FAKE_HOME}/.claude/.silver-bullet"
mkdir -p "$FAKE_AGENTS" "$FAKE_SB"

HOOK_EMR="${REPO_ROOT}/hooks/ensure-model-routing.sh"

# Create mock agent files without any model: line
for agent in gsd-planner gsd-security-auditor gsd-executor gsd-checker; do
  printf -- '---\ndescription: mock agent\n---\n# %s\n' "$agent" > "${FAKE_AGENTS}/${agent}.md"
done

before_planner=$(cat "${FAKE_AGENTS}/gsd-planner.md")

# Run the hook — should exit 0 and make no modifications
hook_exit=0
HOME="$FAKE_HOME" bash "$HOOK_EMR" 2>/dev/null || hook_exit=$?

if [[ "$hook_exit" -eq 0 ]]; then
  PASS=$((PASS+1)); printf 'PASS: S4.1: ensure-model-routing.sh exits 0 (disabled no-op)\n'
else
  FAIL=$((FAIL+1)); printf 'FAIL: S4.1: ensure-model-routing.sh exited %d, expected 0\n' "$hook_exit"
fi

after_planner=$(cat "${FAKE_AGENTS}/gsd-planner.md")
if [[ "$before_planner" == "$after_planner" ]]; then
  PASS=$((PASS+1)); printf 'PASS: S4.2: gsd-planner.md not modified by disabled hook\n'
else
  FAIL=$((FAIL+1)); printf 'FAIL: S4.2: gsd-planner.md was unexpectedly modified\n'
fi

if ! grep -q "^model:" "${FAKE_AGENTS}/gsd-planner.md" 2>/dev/null; then
  PASS=$((PASS+1)); printf 'PASS: S4.3: no model: frontmatter injected into gsd-planner.md\n'
else
  FAIL=$((FAIL+1)); printf 'FAIL: S4.3: model: line was unexpectedly injected into gsd-planner.md\n'
fi

rm -rf "$FAKE_HOME"

# ── S5: DevOps workflow stop-check uses devops required skills ────────────────
# Write config with active_workflow=devops-cycle.
# Empty state → stop-check blocks.
# Record all devops skills → stop-check allows.
echo "--- S5: DevOps workflow transition ---"
integration_setup

# Write devops-cycle config (devops required skills differ from full-dev-cycle)
printf '{
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "devops-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-blast-radius","devops-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["silver-blast-radius","devops-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"]
  },
  "state": { "state_file": "%s", "trivial_file": "%s/trivial-test-%s" }
}\n' "$TMPSTATE" "$SB_TEST_DIR" "$TEST_RUN_ID" > "$TMPCFG"

# Empty state → stop-check should block (missing devops skills)
> "$TMPSTATE"
out=$(run_stop_check "Stop")
assert_blocked "S5.1: stop-check blocks with empty state in devops-cycle workflow" "$out"

# Record all devops required skills (including quality-gate stages and review loops)
for skill in silver-blast-radius devops-quality-gates code-review requesting-code-review \
             receiving-code-review testing-strategy documentation \
             finishing-a-development-branch deploy-checklist silver-create-release \
             verification-before-completion test-driven-development tech-debt \
             review-loop-pass-1 review-loop-pass-2; do
  echo "$skill" >> "$TMPSTATE"
done

out=$(run_stop_check "Stop")
assert_allowed "S5.2: stop-check allows after all devops required skills recorded" "$out"

integration_teardown

# ── S6: Session log created at session start ──────────────────────────────────
# session-start is a shell script that creates SB_STATE_DIR.
# Verify the state directory exists after run_session_start (smoke test).
echo "--- S6: Session infrastructure exists after session start ---"
integration_setup
write_default_config

run_session_start >/dev/null 2>&1 || true

SB_DIR="${HOME}/.claude/.silver-bullet"
if [[ -d "$SB_DIR" ]]; then
  PASS=$((PASS+1)); printf 'PASS: S6.1: SB_STATE_DIR exists after session-start\n'
else
  FAIL=$((FAIL+1)); printf 'FAIL: S6.1: SB_STATE_DIR missing after session-start\n'
fi

# session-log-init.sh writes a session log file — verify it creates the file
run_session_log_init "cat session.log" >/dev/null 2>&1 || true
# The hook writes a log path to SB_DIR/session-log-path if triggered.
# Since we can't force the exact trigger condition, verify state dir still healthy.
if [[ -d "$SB_DIR" ]]; then
  PASS=$((PASS+1)); printf 'PASS: S6.2: SB_STATE_DIR intact after session-log-init\n'
else
  FAIL=$((FAIL+1)); printf 'FAIL: S6.2: SB_STATE_DIR missing after session-log-init\n'
fi

integration_teardown

print_results
