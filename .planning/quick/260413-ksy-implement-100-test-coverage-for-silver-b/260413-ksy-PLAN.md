---
phase: quick
plan: 260413-ksy
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/hooks/test-phase-archive.sh
  - tests/hooks/test-uat-gate.sh
  - tests/hooks/test-spec-session-record.sh
  - tests/hooks/test-spec-floor-check.sh
  - tests/hooks/test-pr-traceability.sh
  - tests/integration/coverage-matrix.sh
autonomous: true
must_haves:
  truths:
    - "bash tests/run-all-tests.sh exits 0 with all tests passing"
    - "coverage-matrix.sh reports 17/17 hooks covered"
    - "Each new test file tests the REAL hook script behavior"
  artifacts:
    - path: "tests/hooks/test-phase-archive.sh"
      provides: "Unit tests for phase-archive.sh hook"
    - path: "tests/hooks/test-uat-gate.sh"
      provides: "Unit tests for uat-gate.sh hook"
    - path: "tests/hooks/test-spec-session-record.sh"
      provides: "Unit tests for spec-session-record.sh hook"
    - path: "tests/hooks/test-spec-floor-check.sh"
      provides: "Unit tests for spec-floor-check.sh hook"
    - path: "tests/hooks/test-pr-traceability.sh"
      provides: "Unit tests for pr-traceability.sh hook"
  key_links:
    - from: "tests/hooks/test-*.sh"
      to: "hooks/*.sh"
      via: "bash invocation piping JSON stdin"
---

<objective>
Add test coverage for the 5 uncovered hooks: phase-archive, uat-gate, spec-session-record, spec-floor-check, pr-traceability. After completion, coverage-matrix.sh must report 17/17 hooks covered and all tests must pass.

Purpose: Achieve 100% hook test coverage so run-all-tests.sh validates every hook in hooks.json.
Output: 5 new test files in tests/hooks/, all passing.
</objective>

<context>
@tests/hooks/test-completion-audit.sh (pattern to follow — setup/teardown/run_hook/assert helpers)
@tests/hooks/test-record-skill.sh (pattern to follow — simpler hook test)
@tests/integration/helpers/common.sh (shared helpers — assert_blocked/assert_allowed/assert_contains)
@hooks/phase-archive.sh (hook under test)
@hooks/uat-gate.sh (hook under test)
@hooks/spec-session-record.sh (hook under test)
@hooks/spec-floor-check.sh (hook under test)
@hooks/pr-traceability.sh (hook under test)
@hooks/hooks.json (hook registration — confirms matchers and event types)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create 5 hook unit test files</name>
  <files>
    tests/hooks/test-phase-archive.sh
    tests/hooks/test-uat-gate.sh
    tests/hooks/test-spec-session-record.sh
    tests/hooks/test-spec-floor-check.sh
    tests/hooks/test-pr-traceability.sh
  </files>
  <action>
Create 5 test files following EXACTLY the pattern in test-completion-audit.sh (set -euo pipefail, HOOK= path resolution, PASS/FAIL counters, setup/teardown functions, run_hook helper piping JSON stdin, assert_blocks/assert_passes/assert_contains helpers, cleanup trap, "Results: N passed, M failed" output format, exit 1 on failures).

Each test MUST pipe properly formatted JSON to the real hook script via stdin and check the JSON output.

**test-phase-archive.sh** (PreToolUse, matcher: Bash, hooks/phase-archive.sh):
- Test 1: Unrelated command (ls -la) passes silently
- Test 2: Non-gsd-tools command passes silently
- Test 3: `gsd-tools phases clear` with no .planning/PROJECT.md passes silently (no archive needed)
- Test 4: `gsd-tools phases clear` with PROJECT.md containing "Current Milestone: v1.0" and existing .planning/phases/01-foo/ directory — archives to .planning/archive/v1.0/ and outputs message containing "archive"
- Test 5: `gsd-tools phases clear` when archive already exists — outputs message containing "already exists" and does NOT overwrite
- Test 6: `gsd-tools phases clear` with no phases directory — passes silently
- Setup must: create TMPDIR_TEST with git init, create .planning/PROJECT.md with "Current Milestone:" line, create .planning/phases/01-test/ with a dummy file inside. run_hook must cd to TMPDIR_TEST and pipe JSON with tool_input.command.

**test-uat-gate.sh** (PreToolUse, matcher: Skill, hooks/uat-gate.sh):
- Test 1: Non-gsd-complete-milestone skill passes silently
- Test 2: gsd-complete-milestone blocked when .planning/UAT.md missing — output contains "UAT GATE" and "permissionDecision.*deny"
- Test 3: gsd-complete-milestone blocked when UAT.md contains "| FAIL |" — output contains "FAIL"
- Test 4: gsd-complete-milestone passes when UAT.md exists with only "| PASS |" results
- Test 5: gsd-complete-milestone with UAT.md containing "| NOT-RUN |" — NOT blocked (advisory only), output contains "NOT-RUN"
- Test 6: Spec version mismatch — UAT.md has spec-version:1.0, SPEC.md has spec-version:2.0 — blocked with version mismatch message
- Test 7: gsd:complete-milestone (colon variant) also triggers the gate
- Setup must: create TMPDIR_TEST, create .planning/ dir. run_hook must pipe JSON with tool_name: "Skill", tool_input.skill.

**test-spec-session-record.sh** (SessionStart, hooks/spec-session-record.sh):
- Test 1: No .planning/SPEC.md — exits silently (no output or empty)
- Test 2: SPEC.md with "spec-version: 1.2.0" and "jira-id: PROJ-42" — writes spec-session file to ~/.claude/.silver-bullet/spec-session with correct values, output contains "v1.2.0" and "PROJ-42"
- Test 3: SPEC.md with spec-version but no jira-id — writes spec-session with jira-id= empty, output contains "n/a"
- Test 4: SPEC.md with neither field — writes spec-session, output contains "unknown"
- Setup must: create TMPDIR_TEST, pipe SessionStart JSON. Cleanup must remove spec-session file.

**test-spec-floor-check.sh** (PreToolUse, matcher: Bash, hooks/spec-floor-check.sh):
- Test 1: Unrelated command passes silently
- Test 2: gsd-plan-phase blocked when no .planning/SPEC.md — output contains "SPEC FLOOR VIOLATION" and "permissionDecision.*deny"
- Test 3: gsd-plan-phase blocked when SPEC.md exists but missing "## Overview" section
- Test 4: gsd-plan-phase blocked when SPEC.md exists but missing "## Acceptance Criteria" section
- Test 5: gsd-plan-phase passes when SPEC.md has both "## Overview" and "## Acceptance Criteria"
- Test 6: gsd-fast without SPEC.md — NOT blocked, output contains "ADVISORY" (warning only)
- Test 7: gsd-quick without SPEC.md — NOT blocked, output contains "ADVISORY"
- Setup must: create TMPDIR_TEST, create .planning/ dir. run_hook pipes Bash tool JSON.

**test-pr-traceability.sh** (PostToolUse, matcher: Bash, hooks/pr-traceability.sh):
- Test 1: Non-gh-pr-create command passes silently
- Test 2: `gh pr create` without spec-session file — exits silently (no crash)
- Test 3: `gh pr create` with spec-session file but no gh CLI available — outputs "gh CLI not found" advisory
- For tests 2-3: Temporarily override PATH to remove gh. The hook does heavy gh CLI interaction (pr view, pr edit) so we can only test the early-exit paths without mocking gh. This is sufficient — the hook's early guards are the testable surface.
- Setup must: create TMPDIR_TEST, create ~/.claude/.silver-bullet/spec-session with test values.

All test files must be executable (chmod +x) and follow the exact output format: "Results: N passed, M failed" on the last line.
  </action>
  <verify>
    <automated>cd /Users/shafqat/Documents/Projects/silver-bullet && for f in tests/hooks/test-phase-archive.sh tests/hooks/test-uat-gate.sh tests/hooks/test-spec-session-record.sh tests/hooks/test-spec-floor-check.sh tests/hooks/test-pr-traceability.sh; do echo "--- $f ---"; bash "$f" || echo "FAILED: $f"; done</automated>
  </verify>
  <done>All 5 test files exist, are executable, and pass independently with 0 failures</done>
</task>

<task type="auto">
  <name>Task 2: Validate full test suite and coverage matrix</name>
  <files>tests/integration/coverage-matrix.sh</files>
  <action>
Run `bash tests/run-all-tests.sh` to confirm all existing + new tests pass together. Then run `bash tests/integration/coverage-matrix.sh` to confirm 17/17 hooks covered.

If coverage-matrix.sh still reports any MISSING hooks, investigate — the test file names must match the hook script names extracted by coverage-matrix.sh (it greps for the hook name in test-*.sh files under tests/hooks/ and tests/integration/).

If any test fails in the full suite, fix the failing test. Do NOT modify the hook scripts — only fix the test expectations.

No changes to coverage-matrix.sh should be needed — it already dynamically discovers hooks from hooks.json and checks for test files. But if the new test filenames don't match the grep pattern, adjust the test filenames (not the matrix script).
  </action>
  <verify>
    <automated>cd /Users/shafqat/Documents/Projects/silver-bullet && bash tests/run-all-tests.sh</automated>
  </verify>
  <done>run-all-tests.sh exits 0, coverage-matrix.sh reports 17/17 covered, all suites green</done>
</task>

</tasks>

<verification>
1. `bash tests/run-all-tests.sh` exits 0
2. `bash tests/integration/coverage-matrix.sh` reports "Coverage: 17/17 hooks covered" and exits 0
3. Each individual test file exits 0 when run standalone
</verification>

<success_criteria>
- 5 new test files in tests/hooks/ covering phase-archive, uat-gate, spec-session-record, spec-floor-check, pr-traceability
- All tests pass (0 failures across all suites)
- Coverage matrix reports 17/17 hooks covered
- No modifications to any hook script in hooks/
</success_criteria>

<output>
Commit the 5 new test files with message: "test: add unit tests for 5 uncovered hooks — 100% coverage"
</output>
