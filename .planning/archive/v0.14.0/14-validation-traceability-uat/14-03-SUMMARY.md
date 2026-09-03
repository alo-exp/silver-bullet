---
phase: 14-validation-traceability-uat
plan: "03"
subsystem: hooks
tags: [uat-gate, hooks, spec-lifecycle, documentation]
dependency_graph:
  requires: [14-01, 14-02]
  provides: [uat-gate-hook, spec-lifecycle-docs]
  affects: [hooks/hooks.json, silver-bullet.md, templates/silver-bullet.md.base]
tech_stack:
  added: []
  patterns: [PreToolUse-Skill-matcher, spec-version-pinning]
key_files:
  created:
    - hooks/uat-gate.sh
  modified:
    - hooks/hooks.json
    - templates/silver-bullet.md.base
    - silver-bullet.md
decisions:
  - "uat-gate.sh uses Skill matcher (not Bash) because gsd-complete-milestone is invoked via Skill tool"
  - "NOT-RUN emits advisory without blocking to avoid false positives on partially-run UAT"
  - "Spec Lifecycle section inserted before ## 3 (between workflow and enforcement sections)"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-09"
  tasks_completed: 2
  files_changed: 4
---

# Phase 14 Plan 03: UAT Gate Hook and Spec Lifecycle Docs Summary

UAT gate hook (uat-gate.sh) blocks gsd-complete-milestone when UAT.md is missing, has FAIL results, or spec-version is stale; Spec Lifecycle section added to both silver-bullet.md files.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create uat-gate.sh hook and register in hooks.json | 82a1b68 | hooks/uat-gate.sh (created), hooks/hooks.json |
| 2 | Add Spec Lifecycle docs to silver-bullet.md.base and silver-bullet.md | 342681f | templates/silver-bullet.md.base, silver-bullet.md |

## What Was Built

### hooks/uat-gate.sh

PreToolUse hook on Skill matcher. Intercepts `gsd-complete-milestone` (and `gsd:complete-milestone`). Enforces four checks in order:

1. **UATG-01/02:** `.planning/UAT.md` must exist — blocks with instruction to run `/silver:feature Step 17` if missing.
2. **UATG-03:** Any `| FAIL |` row in UAT.md blocks with failure count.
3. Advisory: `| NOT-RUN |` rows emit warning message without blocking.
4. **UATG-04:** `spec-version` in UAT.md frontmatter must match `spec-version` in `.planning/SPEC.md` — blocks if stale.

All checks pass → emits "UAT gate passed. Milestone completion allowed."

Hook registered in `hooks/hooks.json` under `PreToolUse` with `"matcher": "Skill"`, placed after `forbidden-skill-check.sh`.

### Spec Lifecycle Section

`## Spec Lifecycle` section added before `## 3. NON-NEGOTIABLE RULES` in both `templates/silver-bullet.md.base` and `silver-bullet.md`. Documents:
- Create (silver:spec / silver:ingest), artifacts produced
- Validate (silver:validate, BLOCK/WARN/INFO severity semantics)
- Trace (pr-traceability.sh, SPEC.md Implementations update)
- UAT Gate (uat-gate.sh enforcement)
- MCP Prerequisites (Atlassian, Figma, Google Drive)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — uat-gate.sh threat model (T-14-06, T-14-07, T-14-08) fully addressed: Skill name extracted via jq from trusted hook input, permissionDecision:deny prevents bypass.

## Self-Check

- hooks/uat-gate.sh: FOUND
- hooks/hooks.json: FOUND (uat-gate.sh registered)
- templates/silver-bullet.md.base: FOUND (Spec Lifecycle section present)
- silver-bullet.md: FOUND (Spec Lifecycle section present)
- Commit 82a1b68: Task 1
- Commit 342681f: Task 2

## Self-Check: PASSED
