---
phase: 07-close-enforcement-audit-gaps
plan: "03"
subsystem: enforcement-hooks
tags: [enforcement, quality-gate, tamper-prevention, cache, mode-detection]
dependency_graph:
  requires: ["07-01", "07-02"]
  provides: [stage-ordering-enforcement, cache-mtime-invalidation, mode-file-detection, src-pattern-update]
  affects: [hooks/completion-audit.sh, hooks/dev-cycle-check.sh, hooks/compliance-status.sh, hooks/session-log-init.sh, .silver-bullet.json, templates/silver-bullet.md.base]
tech_stack:
  added: []
  patterns: [dual-write-state-markers, mtime-cache-invalidation, mode-file-ground-truth, pipe-alternation-pattern]
key_files:
  created: []
  modified:
    - hooks/completion-audit.sh
    - hooks/dev-cycle-check.sh
    - hooks/compliance-status.sh
    - hooks/session-log-init.sh
    - .silver-bullet.json
    - templates/silver-bullet.md.base
decisions:
  - "Stage ordering uses existing skill_line() function for line-number comparison"
  - "workflow_stage_warning is non-blocking (warning only) per plan spec"
  - "Mode file validation uses allowlist (interactive|autonomous) with symlink rejection"
  - "src_pattern validation regex extended to allow pipe | for alternation patterns"
metrics:
  duration: 15m
  completed: "2026-04-06T11:25:35Z"
  tasks_completed: 2
  files_changed: 6
---

# Phase 07 Plan 03: Ordering Checks, Cache Fix, Mode Detection, src_pattern Summary

Closed enforcement audit findings F-05, F-11, F-15, F-17, F-18: stage falsification prevention with dual-write markers, stage-after-workflow ordering warning, config cache mtime invalidation, mode detection reading ground-truth mode file, and src_pattern updated to cover silver-bullet's own source directories.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Stage falsification prevention + ordering (F-05, F-11) | d91492c | completion-audit.sh, dev-cycle-check.sh, silver-bullet.md.base |
| 2 | Cache mtime, mode detection, src_pattern (F-15, F-17, F-18) | 8db4880 | compliance-status.sh, session-log-init.sh, .silver-bullet.json, dev-cycle-check.sh |

## What Was Built

### F-05: Quality gate stage falsification prevention

Each `quality-gate-stage-N` marker now requires a preceding `verification-before-completion-stage-N` marker in the state file. Three changes made:

1. `templates/silver-bullet.md.base` §9: All 4 stage recording instructions updated to dual-write — `verification-before-completion-stage-N` must be written first, then `quality-gate-stage-N`.

2. `hooks/dev-cycle-check.sh` tamper whitelist: Extended to allow `verification-before-completion-stage-[1-4]` echo writes alongside `quality-gate-stage-[1-4]`.

3. `hooks/completion-audit.sh`: Added ordering check — for each `quality-gate-stage-N` present in state, verifies `verification-before-completion-stage-N` exists and has a lower line number. Missing or reversed ordering produces a warning (included in release block messages when blocking).

### F-11: Stage-after-workflow ordering

Added check in `hooks/completion-audit.sh`: if any `quality-gate-stage-*` marker is present, computes `min(stage line numbers)` vs `max(required skill line numbers)`. If stages were recorded before all workflow skills completed, emits a non-blocking warning: "Quality gate stages were recorded BEFORE all workflow skills completed."

### F-15: compliance-status.sh config cache mtime invalidation

Cache file now stores two lines: path on line 1, mtime on line 2. On cache read, current mtime is compared to stored mtime using `stat -f '%m'` (macOS) / `stat -c '%Y'` (Linux) with fallback to `"0"`. Mismatch invalidates cache and forces re-walk.

### F-17: session-log-init.sh mode detection

Replaced fragile `printf '%s' "$cmd" | grep -q "autonomous"` command-string parsing with reading the actual mode file at `${SB_DIR}/mode`. Mode is validated against an allowlist (interactive|autonomous) and symlink-rejected. Falls back to "interactive" if file absent or invalid.

### F-18: src_pattern update

Changed `"src_pattern": "/src/"` to `"src_pattern": "/hooks/|/skills/|/templates/"` in `.silver-bullet.json` so Silver Bullet's own source directories trigger the planning gate. Updated `dev-cycle-check.sh` src_pattern validation regex from `^/[a-zA-Z0-9/_.-]*/?$` to `^/[a-zA-Z0-9/_.|()-]*/?$` to allow pipe `|` for alternation patterns while blocking dangerous injection characters.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

```
bash -n hooks/completion-audit.sh  # PASS
bash -n hooks/dev-cycle-check.sh   # PASS
bash -n hooks/compliance-status.sh # PASS
bash -n hooks/session-log-init.sh  # PASS
grep -q 'verification-before-completion-stage' hooks/completion-audit.sh   # PASS
grep -q 'verification-before-completion-stage' hooks/dev-cycle-check.sh    # PASS
grep -q 'verification-before-completion-stage' templates/silver-bullet.md.base  # PASS
grep -q 'cached_mtime' hooks/compliance-status.sh  # PASS
grep -q 'mode_file' hooks/session-log-init.sh       # PASS
jq '.project.src_pattern' .silver-bullet.json       # "/hooks/|/skills/|/templates/"
```

## Known Stubs

None.

## Threat Flags

None — all changes are mitigations for threats already in the plan's threat model (T-07-05 through T-07-08).

## Self-Check: PASSED

- hooks/completion-audit.sh: FOUND
- hooks/dev-cycle-check.sh: FOUND
- hooks/compliance-status.sh: FOUND
- hooks/session-log-init.sh: FOUND
- .silver-bullet.json: FOUND
- templates/silver-bullet.md.base: FOUND
- Commit d91492c: FOUND
- Commit 8db4880: FOUND
