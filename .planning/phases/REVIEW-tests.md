---
phase: tests-deep-review
reviewed: 2026-04-20T00:00:00Z
depth: deep
files_reviewed: 11
files_reviewed_list:
  - tests/run-all-tests.sh
  - tests/hooks/test-completion-audit.sh
  - tests/hooks/test-dev-cycle-check.sh
  - tests/hooks/test-record-skill.sh
  - tests/hooks/test-required-skills-consistency.sh
  - tests/hooks/test-session-start.sh
  - tests/hooks/test-stop-check.sh
  - tests/hooks/test-timeout-check.sh
  - tests/integration/test-e2e-enforcement-gates.sh
  - tests/integration/test-skill-refs.sh
  - tests/scripts/test-semantic-compress.sh
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Test Suite: Deep Code Review Report

**Reviewed:** 2026-04-20
**Depth:** deep
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed all listed test files against production hook source code at HEAD (v0.23.6). The three most impactful v0.23.6 changes were: (1) removal of `review-loop-pass-1/2` from `required_deploy` in the template config, (2) introduction of `ci-red-override` as a dedicated flag split from the `trivial` bypass, and (3) the fallback hardcoded skill lists in `stop-check.sh`, `completion-audit.sh`, and `prompt-reminder.sh` still containing `review-loop-pass-1/2`.

Three critical issues were found: the `ci-status-check` test asserts the old escape instruction (`touch ...trivial`) rather than the new one (`touch ...ci-red-override`), the hardcoded fallback lists in `stop-check.sh` and `completion-audit.sh` still include the removed markers making those fallback paths deadlock-capable, and `test-completion-audit.sh` Test 17 carries misleading state that implies review-loop markers are still required (they are not, but the test gives a false confidence signal). Additionally, `test-dev-cycle-check.sh` has zero coverage of the `ci-red-override` path, and `test-timeout-check.sh` does not emit a `Results: N passed, N failed` line, causing `run-all-tests.sh` to silently count it as 0 passed / 0 failed.

---

## Critical Issues

### CR-01: Hardcoded fallback lists in stop-check.sh and completion-audit.sh still contain review-loop-pass-1/2

**File:** `hooks/stop-check.sh:200-201` and `hooks/completion-audit.sh:255-256`
**Issue:** Commit `7d2653b` removed `review-loop-pass-1` and `review-loop-pass-2` from `templates/silver-bullet.config.json.default` and from `hooks/lib/required-skills.sh` (which reads from that config). However, the hardcoded fallback string literals at these lines — reached only when `required-skills.sh` cannot be sourced — still include those two markers. If the lib is unavailable (corrupted install, race condition, CI path issue), the fallback engages and demands markers that `record-skill.sh` never writes and the tamper guard blocks from being written. This is the exact deadlock that commit `7d2653b` was intended to fix, reintroduced in the fallback path.

**Fix:**
```bash
# hooks/stop-check.sh line 200-201 — remove review-loop-pass-1 and review-loop-pass-2
DEFAULT_REQUIRED="silver-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"
DEVOPS_DEFAULT_REQUIRED="silver-blast-radius devops-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"

# Apply the same fix to hooks/completion-audit.sh lines 255-256.
```

---

### CR-02: test-ci-status-check.sh Tests 6 and 7 assert the old escape instruction

**File:** `tests/hooks/test-ci-status-check.sh:117` and `tests/hooks/test-ci-status-check.sh:123`
**Issue:** After commit `5f8b0d6`, the CI failure message in `ci-status-check.sh` now instructs the user to `touch ~/.claude/.silver-bullet/ci-red-override`. Tests 6 and 7 still assert `touch ~/.claude/.silver-bullet/trivial`, which is the old, now-deprecated path. These tests will pass for now only because the production hook still outputs both paths in different contexts (the failure message mentions `ci-red-override`; the trivial backward-compat branch outputs `trivial` again). But Test 6 actually sends a CI-failure payload that triggers the primary block path, which now says `ci-red-override` — meaning these tests are asserting a string that is NOT present in the current block output. They are effectively FAILING right now if run against the current hook.

**Verify:**
```bash
bash tests/hooks/test-ci-status-check.sh
```

The hook's block message at line 116 of `ci-status-check.sh` reads:
```
touch ~/.claude/.silver-bullet/ci-red-override
```
Tests 6 and 7 grep for:
```
touch ~/.claude/.silver-bullet/trivial
```
That substring no longer appears in the primary block path. Both test assertions will fail.

**Fix:**
```bash
# tests/hooks/test-ci-status-check.sh line 117 and 123
# Change:
assert_contains "..." "$out" "touch ~/.claude/.silver-bullet/trivial"
# To:
assert_contains "..." "$out" "touch ~/.claude/.silver-bullet/ci-red-override"
```

Also add a new test covering the `ci-red-override` file bypass:
```bash
# New Test 8: ci-red-override bypass
setup
CI_OVERRIDE_FILE="${SB_TEST_DIR}/ci-red-override"
touch "$CI_OVERRIDE_FILE"
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "ci-red-override bypass suppresses CI block" "$out"
rm -f "$CI_OVERRIDE_FILE"
teardown
```

---

### CR-03: Test 17 in test-completion-audit.sh creates misleading signal about review-loop-pass markers

**File:** `tests/hooks/test-completion-audit.sh:318-337`
**Issue:** Test 17 is titled "gh pr merge passes when all skills present (including review-loop-pass markers)". It writes `review-loop-pass-1` and `review-loop-pass-2` into the state file. This test DOES pass correctly at runtime because `write_cfg` (line 27) hardcodes `required_deploy` without the review-loop markers, so the hook ignores the extra state entries. However, the test comment and label assert the opposite of the v0.23.6 intent: they imply review-loop markers are a required part of passing. This is a semantic inversion — it will mislead anyone reading the test or future reviewers into believing the markers are still required. More importantly, if a developer reads this test as documentation and adds review-loop markers back to `required_deploy`, the CI gate will deadlock again.

**Fix:**
```bash
# Remove review-loop-pass-1 and review-loop-pass-2 from the state file in Test 17.
# Rename the test to reflect the v0.23.6 intent:
# "gh pr merge passes with all required skills (review-loop-pass markers not required)"
# Replace EOF block:
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh pr merge --squash")
assert_passes "gh pr merge passes with all required skills (review-loop-pass markers NOT required)" "$out"
```

---

## Warnings

### WR-01: test-dev-cycle-check.sh has zero coverage of the ci-red-override path

**File:** `tests/hooks/test-dev-cycle-check.sh` (entire file)
**Issue:** Commit `5f8b0d6` introduced `~/.claude/.silver-bullet/ci-red-override` as a separate bypass flag in `ci-status-check.sh`. Neither `test-dev-cycle-check.sh` nor `test-ci-status-check.sh` tests the new bypass flag. `test-ci-status-check.sh` Tests 5 tests the old `trivial` bypass, but no test verifies that `ci-red-override` (the new canonical flag) actually bypasses the CI gate. This leaves the primary documented escape hatch for users entirely untested.

**Fix:** Add to `tests/hooks/test-ci-status-check.sh`:
```bash
echo "--- Group 5b: ci-red-override bypass ---"
setup
CI_OVERRIDE_FILE="${SB_TEST_DIR}/ci-red-override"
touch "$CI_OVERRIDE_FILE"
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "ci-red-override bypass suppresses CI block" "$out"
rm -f "$CI_OVERRIDE_FILE"
teardown
```

---

### WR-02: test-timeout-check.sh does not emit a "Results: N passed, N failed" line — invisible to run-all-tests.sh

**File:** `tests/hooks/test-timeout-check.sh:202`
**Issue:** `run-all-tests.sh` (line 34) extracts pass/fail counts by parsing `Results: N passed, M failed`. `test-timeout-check.sh` emits only `All tests passed.` at line 202 (or exits 1 on failure). The runner will parse `p=0` and `f=0` regardless of actual outcome. This means all 10+ timeout-check test assertions are invisible to the aggregate totals — they do not contribute to the TOTAL_PASS / TOTAL_FAIL counters. A regression in `timeout-check.sh` that causes 4 of these tests to fail will still show "0 failed" in the suite summary.

**Fix:**
```bash
# Add at the end of tests/hooks/test-timeout-check.sh, replacing:
printf 'All tests passed.\n'
# With a PASS/FAIL counter pattern matching all other test files:
PASS=0; FAIL=0
# ... increment in each test block using: PASS=$((PASS + 1)) or FAIL=$((FAIL + 1)) ...
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

---

### WR-03: test-required-skills-consistency.sh does not validate that required_deploy skills are a subset of all_tracked

**File:** `tests/hooks/test-required-skills-consistency.sh` (entire file)
**Issue:** The test validates that `DEFAULT_REQUIRED` (from `required-skills.sh`) matches `required_deploy` from the template config, and that `DEVOPS_DEFAULT_REQUIRED` matches `required_deploy_devops`. It does NOT validate that every skill in `required_deploy` is also present in `all_tracked`. If a skill is added to `required_deploy` but not to `all_tracked`, `record-skill.sh` will silently refuse to record it (it only records skills in `all_tracked`), creating an unresolvable gate. This was the root cause pattern of the review-loop-pass deadlock — markers were referenced without being in `all_tracked` OR being recordable.

**Fix:**
```bash
# Add after the existing checks in test-required-skills-consistency.sh:
CFG_ALL_TRACKED=$(jq -r '.skills.all_tracked | .[]' "$CONFIG" | sort -u)

# Every required_deploy skill must appear in all_tracked
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  if printf '%s' "$CFG_ALL_TRACKED" | grep -qx "$skill"; then
    PASS=$((PASS + 1))
    echo "  ok: required_deploy skill '$skill' present in all_tracked"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: required_deploy skill '$skill' NOT in all_tracked — record-skill.sh will never record it"
  fi
done <<< "$CFG_REQUIRED_DEPLOY"
```

---

### WR-04: test-stop-check.sh required_deploy config does not match the current template default

**File:** `tests/hooks/test-stop-check.sh:27-30` (write_cfg function)
**Issue:** The `write_cfg` function sets `required_deploy` to 6 skills: `silver-quality-gates, code-review, testing-strategy, documentation, finishing-a-development-branch, deploy-checklist`. The current template default has 12 skills. Tests that pass with 6 skills present would fail against a real project config. More critically, `write_cfg_with_release` adds only `silver-create-release` as a 7th. The gap means the stop-check tests verify a much smaller skill set than what real projects require, creating a false confidence that the gate works correctly for the full required_deploy list. (This is a pre-existing issue, not a v0.23.6 regression, but still material.)

**Fix:**
```bash
# Update write_cfg in test-stop-check.sh to match the current template:
write_cfg() {
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["silver-quality-gates","code-review"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}
```
Update the passing state blocks in Tests 2 and 5 to include the full 12-skill set accordingly.

---

## Info

### IN-01: test-skill-refs.sh does not validate that reviewed files listed in skill refs are reachable after v0.23.6

**File:** `tests/integration/test-skill-refs.sh:41-70`
**Issue:** The `EXTERNAL_SKILLS` whitelist includes skills like `gsd-review`, `gsd-code-review`, `gsd-code-review-fix`. If v0.23.6 introduced new Silver Bullet skills that reference these, or if any SKILL.md was updated to reference a skill not yet in `EXTERNAL_SKILLS`, the test would catch it. No gap was found in the current skill references, but the test has no mechanism to detect when a skill is removed from the external plugins list — it only checks that referenced skills are in the whitelist, not whether the whitelist itself is stale.

**Suggestion:** Add a comment documenting the manual update process when a GSD/superpowers skill is renamed or removed upstream.

---

### IN-02: test-timeout-check.sh uses sleep calls that could cause CI flakiness

**File:** `tests/hooks/test-timeout-check.sh:29`, `65`, `81`, `101`
**Issue:** Four `sleep 1` calls are used to ensure file mtime ordering for stale-flag detection tests (macOS-only). These are not removable without redesigning the tests, but they add 4 seconds of mandatory wall-clock time on macOS. On a heavily loaded CI runner where mtime granularity or process scheduling is coarse, 1-second gaps may be insufficient. This is informational only — the tests are correctly structured for the feature they're testing.

**Suggestion:** Document the macOS-only sleep rationale with a comment to prevent future developers from removing the sleeps.

---

### IN-03: core-rules.md still documents review-loop-pass markers as required

**File:** `hooks/core-rules.md:35-38`
**Issue:** After commit `7d2653b`, `core-rules.md` still contains instructions to `echo "review-loop-pass-1" >> ~/.claude/.silver-bullet/state` after each clean review pass. This documentation contradicts the fix: (1) the tamper-detection hook blocks that echo command, and (2) the markers were removed from `required_deploy`. Any agent following `core-rules.md` instructions will encounter a STATE TAMPER BLOCKED error, which is confusing. This is a source file issue (not a test issue), included here because no other review covers it and it directly affects test-session behavior.

**Fix:** Remove the review-loop-pass marker instructions from `hooks/core-rules.md` lines 35-38.

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
