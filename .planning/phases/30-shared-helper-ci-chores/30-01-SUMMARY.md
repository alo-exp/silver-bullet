---
phase: 30-shared-helper-ci-chores
plan: "01"
subsystem: hooks / ci
tags: [refactor, chore, shell, ci]
dependency_graph:
  requires: []
  provides:
    - hooks/lib/trivial-bypass.sh (sb_trivial_bypass function)
    - SessionStart umask 0077 alignment
    - CI non-blocking version-drift warning
  affects:
    - hooks/stop-check.sh
    - hooks/ci-status-check.sh
    - hooks/hooks.json
    - .github/workflows/ci.yml
tech_stack:
  added: []
  patterns:
    - Sourced shell library pattern (lib/*.sh)
    - GitHub Actions continue-on-error warning annotation
key_files:
  created:
    - hooks/lib/trivial-bypass.sh
  modified:
    - hooks/stop-check.sh
    - hooks/ci-status-check.sh
    - hooks/hooks.json
    - .github/workflows/ci.yml
decisions:
  - "sb_trivial_bypass accepts optional path arg so stop-check.sh can pass config-resolved path while ci-status-check.sh uses hardcoded default"
  - "Added # shellcheck shell=bash directive to trivial-bypass.sh (sourced library, no shebang) to satisfy SC2148"
  - "_lib_dir resolution moved from line 100 to before the trivial-bypass section in stop-check.sh; single assignment serves both helper sources"
metrics:
  duration: ~8 minutes
  completed: "2026-04-16"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 4
---

# Phase 30 Plan 01: Shared Helper & CI Chores Summary

**One-liner:** Extracted duplicated trivial-bypass shell guard into `hooks/lib/trivial-bypass.sh`, added `umask 0077` to SessionStart command, and added non-blocking CI version-drift warning step.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create shared trivial-bypass helper and update consumer scripts (REF-01) | 41a4d3b | hooks/lib/trivial-bypass.sh (created), hooks/stop-check.sh, hooks/ci-status-check.sh |
| 2 | Fix SessionStart umask in hooks.json (CI-01) | 61c42af | hooks/hooks.json |
| 3 | Add non-blocking CI version-drift warning step (CI-02) | 8fcea66 | .github/workflows/ci.yml |

## What Was Built

### REF-01: Shared trivial-bypass helper

`hooks/lib/trivial-bypass.sh` is a new sourced library defining `sb_trivial_bypass()`. The function accepts an optional path argument (defaulting to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial`) and exits 0 if the trivial file exists and is not a symlink — matching the previously inlined guard exactly.

- `hooks/stop-check.sh` now resolves `_lib_dir` before the trivial-bypass section (moved from its original location at line 100), sources the helper, and calls `sb_trivial_bypass "$trivial_file"` (passing the config-resolved path).
- `hooks/ci-status-check.sh` sources the helper and calls `sb_trivial_bypass` with no argument, using the default path — matching its previous hardcoded behaviour. The now-unused `SB_STATE_DIR` and `trivial_file` variable assignments were removed along with the inline guard.

### CI-01: SessionStart umask

The first SessionStart command in `hooks/hooks.json` now reads:
`"umask 0077 && mkdir -p ${SB_RUNTIME_HOME_ROOT}/.silver-bullet && touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial"`

This aligns the trivial-file creation with the `umask 0077` convention used by all other Silver Bullet hook scripts, ensuring the file is created owner-only from session start.

### CI-02: Non-blocking version-drift warning

A new CI step "Check plugin.json version vs latest git tag" was inserted in `.github/workflows/ci.yml` after "Validate JSON files" and before "Check hook executability". It:
- Extracts `version` from `.claude-plugin/plugin.json` via `jq`
- Finds the latest git tag via `git describe --tags --abbrev=0`
- Strips the leading `v` from the tag before comparing
- Emits a `::warning::` GitHub Actions annotation on mismatch
- Exits 0 gracefully when no tags exist (fresh clone, fork PR)
- Uses `continue-on-error: true` so the build never fails from this check

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added `# shellcheck shell=bash` directive to trivial-bypass.sh**
- **Found during:** Task 1 shellcheck verification
- **Issue:** SC2148 — shellcheck requires a shebang or shell directive for sourced files without a shebang
- **Fix:** Added `# shellcheck shell=bash` as the first line of `hooks/lib/trivial-bypass.sh`
- **Files modified:** hooks/lib/trivial-bypass.sh
- **Commit:** 41a4d3b (included in Task 1 commit)

## Verification Results

All plan verification checks passed:

1. `shellcheck --exclude=SC2317,SC1091 hooks/lib/trivial-bypass.sh hooks/stop-check.sh hooks/ci-status-check.sh` — PASS
2. `jq empty hooks/hooks.json` — PASS (valid JSON)
3. `bash tests/hooks/test-stop-check.sh` — PASS (6/6 tests including trivial bypass test)
4. `grep -c 'sb_trivial_bypass'` — 1 call in stop-check.sh, 1 call in ci-status-check.sh
5. `grep 'umask 0077' hooks/hooks.json` — SessionStart command confirmed
6. `grep 'continue-on-error: true' .github/workflows/ci.yml` — confirmed
7. No inline guards remain in either consumer script

## Known Stubs

None — all changes are wired and functional.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced beyond the plan's threat model (T-30-01 through T-30-04 all mitigated as designed).

## Self-Check: PASSED

- hooks/lib/trivial-bypass.sh: FOUND
- hooks/stop-check.sh (sources helper): FOUND
- hooks/ci-status-check.sh (sources helper): FOUND
- hooks/hooks.json (umask 0077): FOUND
- .github/workflows/ci.yml (continue-on-error step): FOUND
- Commit 41a4d3b: FOUND
- Commit 61c42af: FOUND
- Commit 8fcea66: FOUND
