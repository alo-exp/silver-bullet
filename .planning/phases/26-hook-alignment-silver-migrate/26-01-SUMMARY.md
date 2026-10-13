---
phase: 26-hook-alignment-silver-migrate
plan: "01"
subsystem: hooks
tags: [workflow, hooks, composable-paths, legacy-fallback]
dependency_graph:
  requires: []
  provides: [WORKFLOW.md-aware enforcement hooks]
  affects: [hooks/dev-cycle-check.sh, hooks/completion-audit.sh, hooks/compliance-status.sh, hooks/prompt-reminder.sh, hooks/spec-floor-check.sh]
tech_stack:
  added: []
  patterns: [WORKFLOW.md Path Log parsing via grep, legacy fallback conditional]
key_files:
  created: []
  modified:
    - hooks/dev-cycle-check.sh
    - hooks/completion-audit.sh
    - hooks/compliance-status.sh
    - hooks/prompt-reminder.sh
    - hooks/spec-floor-check.sh
decisions:
  - "Parse Path Log with grep -cE rather than awk for minimal dependency surface"
  - "Malformed WORKFLOW.md always falls through to legacy — never blocks (T-26-02)"
  - "spec-floor downgrade only when WORKFLOW.md present AND PATH 4 absent (T-26-03)"
metrics:
  duration: ~12min
  completed: "2026-04-15"
  tasks_completed: 2
  files_modified: 5
---

# Phase 26 Plan 01: Hook WORKFLOW.md Awareness Summary

## One-liner

All 5 enforcement hooks updated to check WORKFLOW.md Path Log completion as primary gate, falling back to legacy skill-marker logic when WORKFLOW.md is absent.

## What Was Built

### Task 1: dev-cycle-check.sh and completion-audit.sh

**dev-cycle-check.sh** — Added WORKFLOW.md check block before the legacy "Read state file" section:
- Resolves `$PWD/.planning/WORKFLOW.md`
- If present: parses Path Log via `grep -cE` to count completed and total paths
- All paths complete → exits 0 with "All workflow paths complete. Proceed freely."
- Partial completion → emits info message showing PATH X/Y, falls through to legacy gate
- Absent or malformed → falls through to legacy logic unchanged (D-03)

**completion-audit.sh** — Added WORKFLOW.md check block after trivial bypass, before branch detection:
- Intermediate commits: if any path complete → allow; otherwise fall through to legacy
- Final delivery (gh pr create/deploy/release): requires all paths complete; if not, emits `emit_block` with "WORKFLOW INCOMPLETE — X/Y paths done"
- Absent/malformed → falls through to legacy logic unchanged

### Task 2: compliance-status.sh, prompt-reminder.sh, spec-floor-check.sh

**compliance-status.sh** — Added path progress before state file read:
- WORKFLOW.md present: sets `path_progress="PATH X/Y"`
- WORKFLOW.md absent: sets `path_progress="PATH: N/A (legacy mode)"`
- Inserted into output message after Mode field

**prompt-reminder.sh** — Added WORKFLOW.md position extraction before additionalContext emit:
- Parses `## Heartbeat` → `Last-path:` value
- Parses `## Next Path` → next path name
- Parses `## Composition` → `Mode:` value
- Appends "Composable path: currently at PATH X, next: Y (Z mode)" to skill_status when present
- Omitted entirely when WORKFLOW.md absent (D-07)

**spec-floor-check.sh** — Added composition check after `is_plan_phase`/`is_fast` detection:
- When `is_plan_phase=true` and WORKFLOW.md present: checks if PATH 4 (SPECIFY) appears in Path Log
- PATH 4 absent from composition → advisory exit 0 (downgrade from blocking)
- PATH 4 present → continues with existing blocking logic unchanged
- WORKFLOW.md absent → existing blocking logic unchanged (T-26-03)

## Decisions Made

- Parse Path Log with `grep -cE` pattern matching rather than awk for minimal shell dependency surface and consistent behavior across macOS/Linux
- Malformed WORKFLOW.md (parse failure) always falls through to legacy — never blocks the hook from completing (T-26-02 mitigation)
- spec-floor downgrade only activates when WORKFLOW.md is explicitly present AND PATH 4 is absent — absence of WORKFLOW.md does NOT downgrade (T-26-03)

## Deviations from Plan

None — plan executed exactly as written.

## Verification

All 5 hooks pass `bash -n` syntax check:
- `bash -n hooks/dev-cycle-check.sh` → exit 0
- `bash -n hooks/completion-audit.sh` → exit 0
- `bash -n hooks/compliance-status.sh` → exit 0
- `bash -n hooks/prompt-reminder.sh` → exit 0
- `bash -n hooks/spec-floor-check.sh` → exit 0

All acceptance criteria met:
- `grep -c 'WORKFLOW.md' hooks/dev-cycle-check.sh` → 3
- `grep -c 'WORKFLOW.md' hooks/completion-audit.sh` → 6
- Legacy logic untouched in all 5 files

## Known Stubs

None.

## Threat Flags

None — all new surface covered by existing threat register (T-26-01, T-26-02, T-26-03).

## Self-Check: PASSED

- hooks/dev-cycle-check.sh: modified, commit 6ee40ff
- hooks/completion-audit.sh: modified, commit 6ee40ff
- hooks/compliance-status.sh: modified, commit f6803ff
- hooks/prompt-reminder.sh: modified, commit f6803ff
- hooks/spec-floor-check.sh: modified, commit f6803ff
