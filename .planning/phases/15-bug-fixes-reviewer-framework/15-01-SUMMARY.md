---
phase: 15-bug-fixes-reviewer-framework
plan: "01"
subsystem: silver-ingest, hooks, templates
tags: [security, bug-fix, shell-injection, confluence, version-mismatch]
dependency_graph:
  requires: []
  provides: [BFIX-01, BFIX-02, BFIX-03, BFIX-04]
  affects: [skills/silver-ingest/SKILL.md, hooks/pr-traceability.sh, templates/silver-bullet.md.base]
tech_stack:
  added: []
  patterns: [printf-safe-string-building, regex-input-validation]
key_files:
  created: []
  modified:
    - skills/silver-ingest/SKILL.md
    - hooks/pr-traceability.sh
    - templates/silver-bullet.md.base
decisions:
  - "Use printf '%s' format string to prevent heredoc shell expansion of user-controlled warn_items content"
  - "Validate owner/repo with ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ before any gh api/curl invocation"
  - "Confluence failures insert [ARTIFACT MISSING] inline in SPEC.md section, not in Assumptions"
  - "Version mismatch fetches full remote SPEC.md and shows unified diff before blocking"
metrics:
  duration: ~5min
  completed: 2026-04-09
  tasks_completed: 2
  files_modified: 3
---

# Phase 15 Plan 01: Bug Fixes (BFIX-01..04) Summary

**One-liner:** Four v0.14.0 security and output-quality bugs fixed — shell injection guard via regex validation, heredoc injection eliminated via printf, Confluence failure surfaced inline, version mismatch shows unified content diff.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | BFIX-01 shell injection + BFIX-02 heredoc injection | e26b8a0 | skills/silver-ingest/SKILL.md, hooks/pr-traceability.sh |
| 2 | BFIX-03 Confluence failure path + BFIX-04 version mismatch diff | f634bac | skills/silver-ingest/SKILL.md, templates/silver-bullet.md.base |

## Changes Made

### BFIX-01 — Shell Injection in silver-ingest Step 5

Added explicit input validation block after owner/repo extraction in Step 5 of `skills/silver-ingest/SKILL.md`. The combined `{owner}/{repo}` string must match `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` before being passed to `gh api` or `curl`. On failure, records `status: failed` and skips to Step 7.

### BFIX-02 — Command Injection in pr-traceability.sh heredoc

Replaced the `cat <<TRACE` heredoc block in `hooks/pr-traceability.sh` with `printf '\n---\n...\n%s' ...` safe string building. The `$warn_items` variable (user-controlled content from VALIDATION.md) is now passed as a `%s` format argument, not interpolated inside a heredoc where backticks and `$()` would execute.

### BFIX-03 — Confluence Failure Path

Two locations fixed in `skills/silver-ingest/SKILL.md`:
1. Step 1 Confluence page resolution section now explicitly instructs: insert `[ARTIFACT MISSING: Confluence page fetch failed — {error}]` inline in the SPEC.md section that expected the content. Not in Assumptions.
2. Failure Handling Summary table row updated from "Skip page content; note in Assumptions" to the correct `[ARTIFACT MISSING]` inline behavior.

### BFIX-04 — Version Mismatch Display

`templates/silver-bullet.md.base` §0/5.5 mismatch block now:
1. Fetches the full remote SPEC.md via `gh api ... | base64 -d`
2. Runs `diff --unified=3` between local and remote
3. Displays `Content changes: {unified diff output}` in the mismatch block alongside version numbers

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — all security-relevant surface was covered by the plan's threat model (T-15-01, T-15-02, T-15-03).

## Self-Check: PASSED

- `grep -c 'a-zA-Z0-9._-' skills/silver-ingest/SKILL.md` → 1 (PASS)
- `grep -c 'printf' hooks/pr-traceability.sh` → 7 (PASS, >= 2)
- `grep -c 'cat <<TRACE' hooks/pr-traceability.sh` → 0 (PASS)
- `grep -c 'ARTIFACT MISSING.*Confluence' skills/silver-ingest/SKILL.md` → 2 (PASS)
- `grep -c 'diff --unified' templates/silver-bullet.md.base` → 1 (PASS)
- Commits e26b8a0 and f634bac verified in git log
