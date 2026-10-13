---
phase: 064-verification-init-improvements
plan: "02"
subsystem: docs-internal
tags: [bug-06, permissions, hooks, investigation]
provides:
  - docs/internal/bug-06-permissions-reprompt.md
affects: []
key-files:
  created:
    - docs/internal/bug-06-permissions-reprompt.md
  modified: []
key-decisions:
  - "Root cause: permissionDecision:deny from PreToolUse hooks (completion-audit.sh, forbidden-skill-check.sh) may interact with Bypass Permissions at the Claude Code platform level"
  - "Disposition: platform issue — SB cannot change the hook output format without losing enforcement capability"
  - "Action: update GitHub issue #64 with findings; platform fix needed"
requirements-completed:
  - BUG-06
duration: "4 min"
completed: "2026-04-26"
---

# Phase 064 Plan 02: BUG-06 Permissions Re-Prompting Investigation Summary

Root cause investigation of Claude Code re-prompting for permissions after Bypass Permissions is set. Reviewed all 6 SB hooks. Two are candidates; root cause is a platform behavior issue, not an SB bug.

**Duration:** ~4 min | **Tasks:** 1 | **Files:** 1 created, 0 modified

## What Was Built

**Investigation doc** (`docs/internal/bug-06-permissions-reprompt.md`):

All 6 SB hooks reviewed:

| Hook | Event | Output Format | Permission Relevance |
|------|-------|---------------|---------------------|
| session-start | SessionStart | additionalContext | None |
| prompt-reminder.sh | UserPromptSubmit | additionalContext | None |
| stop-check.sh | Stop/SubagentStop | decision:block | None (Stop format, not PreToolUse) |
| completion-audit.sh | PreToolUse+PostToolUse/Bash | **permissionDecision:deny** (PreToolUse) | ⚠️ Candidate |
| forbidden-skill-check.sh | PreToolUse/Skill | **permissionDecision:deny** | ⚠️ Candidate |
| uat-gate.sh | PreToolUse/Skill | Investigated | Secondary candidate |

**Root cause:** `permissionDecision:"deny"` is the protocol-correct format for PreToolUse hook blocking. If Claude Code conflates hook-based denials with general permission system state, Bypass Permissions would re-prompt after any hook denial — that is a platform bug, not an SB bug.

**Disposition:** Platform issue. No hook files modified. GitHub issue #64 should be updated: hook-based denials are the likely trigger; fix requires platform-level separation of hook denials from the permission system state.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- [x] docs/internal/bug-06-permissions-reprompt.md exists
- [x] All 6 hooks investigated and named
- [x] Root cause verdict stated (platform issue)
- [x] Disposition stated ("No SB fix possible")
- [x] GitHub issue #64 referenced with full URL
- [x] bash -n hooks/forbidden-skill-check.sh: PASS
- [x] bash -n hooks/completion-audit.sh: PASS
