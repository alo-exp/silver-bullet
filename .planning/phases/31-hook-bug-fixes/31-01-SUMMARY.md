---
phase: 31-hook-bug-fixes
plan: "01"
subsystem: hooks
tags: [bug-fix, hooks, uat-gate, dev-cycle-check, ci-status-check, test-coverage]
dependency_graph:
  requires: []
  provides: [HOOK-01, HOOK-02, HOOK-03]
  affects: [hooks/uat-gate.sh, hooks/dev-cycle-check.sh, hooks/ci-status-check.sh]
tech_stack:
  added: []
  patterns: [two-pipe-grep-exclusion, combined-regex-bridge, escape-instruction-in-block-message]
key_files:
  created: []
  modified:
    - hooks/uat-gate.sh
    - hooks/dev-cycle-check.sh
    - hooks/ci-status-check.sh
    - tests/hooks/test-uat-gate.sh
    - tests/hooks/test-dev-cycle-check.sh
    - tests/hooks/test-ci-status-check.sh
decisions:
  - "HOOK-01: Two-pipe grep approach (grep -E | grep -qvE) chosen over single complex regex for clarity"
  - "HOOK-02: Combined [^<]* bridge pattern chosen over heredoc-stripping pre-pass for minimal change"
  - "HOOK-03: Message-only change — no new bypass mechanism, escape instruction is informational only"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-16T09:45:23Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 6
---

# Phase 31 Plan 01: Hook Bug Fixes Summary

**One-liner:** Three hook correctness fixes — uat-gate header-aware FAIL check, dev-cycle-check combined write-op+path grep, ci-status-check trivial file escape instruction.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix uat-gate FAIL header false-positive (HOOK-01) | 58976e7 | hooks/uat-gate.sh, tests/hooks/test-uat-gate.sh |
| 2 | Fix dev-cycle-check heredoc false-positive (HOOK-02) | f5c362c | hooks/dev-cycle-check.sh, tests/hooks/test-dev-cycle-check.sh |
| 3 | Add escape instruction to ci-status-check (HOOK-03) | 8c0ceb4 | hooks/ci-status-check.sh, tests/hooks/test-ci-status-check.sh |

## What Was Built

### HOOK-01: uat-gate header-aware FAIL detection

Replaced single `grep -qE '\| FAIL \|'` with a two-pipe approach:
```bash
grep -E '\| FAIL \|' "$UAT" | grep -qvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|'
```
Header rows (containing column labels like `#`, `PASS`, `Total`, `NOT-RUN`, `Status`, `Result`) are excluded from the FAIL check. Data rows with `| FAIL |` still trigger the block. The `fail_count` calculation uses the same two-pipe treatment for an accurate count.

Added Group 8 tests (Tests 8-10) covering: FAIL in header only (must pass), FAIL header + FAIL data row (must block), Status/Result header with FAIL (must pass).

### HOOK-02: dev-cycle-check combined write-op+path grep

Replaced two independent grep checks (state path anywhere + write op anywhere) with a single combined pattern:
```bash
grep -qE '(>>|\s>[^>&=]|\btee\b)[^<]*\.claude/[^/]+/(state|branch|trivial|mode)'
```
The `[^<]*` bridge allows matching from write operator to state path, but stops at `<` (heredoc delimiters). Commands like `cat > /tmp/foo << 'EOF'\n${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state\nEOF` no longer false-positive because the `<` in `<<` breaks the bridge. Direct writes (`echo >>`, `printf >`, `tee`) still match correctly.

Added Tests 17/17b/17c: heredoc body pass, direct write block, tee block.

### HOOK-03: ci-status-check escape instruction

Appended escape instruction to the CI failure block message:
```
If you need to commit a CI fix: recreate the bypass file in your terminal (not in Claude):
  touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial
This re-enables commits for the current session so you can push your fix.
```
Both `failure` and `cancelled` conclusions show this instruction. No logic changes.

Added Group 4 tests (Tests 6-7) for both failure and cancelled conclusions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test isolation bug in test-ci-status-check.sh teardown**
- **Found during:** Task 3 test execution (Tests 6 and 7 returned empty output)
- **Issue:** `teardown()` removed `trivial-test-${TEST_RUN_ID}` but NOT `$TRIVIAL_FILE` (`${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial`). Test 5 (trivial bypass) created `$TRIVIAL_FILE`, and `teardown` left it in place, causing the trivial bypass to fire silently in subsequent tests.
- **Fix:** Added `"$TRIVIAL_FILE"` to `teardown`'s `rm -f` call — consistent with `cleanup_all` which already removed it on EXIT.
- **Files modified:** tests/hooks/test-ci-status-check.sh
- **Commit:** 8c0ceb4 (included with Task 3 changes)

## Verification Results

All three hook test suites pass with zero failures:
- `bash tests/hooks/test-uat-gate.sh` — 16/16 passed
- `bash tests/hooks/test-dev-cycle-check.sh` — 38/38 passed
- `bash tests/hooks/test-ci-status-check.sh` — 7/7 passed
- Total: 61/61 tests passed

Acceptance criteria verified:
- `grep -c 'grep -qvE' hooks/uat-gate.sh` → 1
- `grep -c 'grep -cvE' hooks/uat-gate.sh` → 1
- `grep -c 'HOOK-01' tests/hooks/test-uat-gate.sh` → 4
- `grep -c 'touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial' hooks/ci-status-check.sh` → 1
- `grep -c 'recreate the bypass file' hooks/ci-status-check.sh` → 1
- `grep -c 'HOOK-03' tests/hooks/test-ci-status-check.sh` → 3

## Known Stubs

None.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. The combined grep pattern (HOOK-02) and header exclusion (HOOK-01) are purely defensive — they reduce false positives without widening the attack surface. The escape instruction (HOOK-03) is informational text in a block message; the trivial file mechanism itself is unchanged.

## Self-Check: PASSED

Files exist:
- hooks/uat-gate.sh — FOUND
- hooks/dev-cycle-check.sh — FOUND
- hooks/ci-status-check.sh — FOUND
- tests/hooks/test-uat-gate.sh — FOUND
- tests/hooks/test-dev-cycle-check.sh — FOUND
- tests/hooks/test-ci-status-check.sh — FOUND

Commits exist:
- 58976e7 — FOUND (fix uat-gate HOOK-01)
- f5c362c — FOUND (fix dev-cycle-check HOOK-02)
- 8c0ceb4 — FOUND (fix ci-status-check HOOK-03)
