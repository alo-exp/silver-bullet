# Phase 26: Hook Alignment + silver:migrate - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from roadmap + prior context)

<domain>
## Phase Boundary

Modify 5 existing hook scripts to be WORKFLOW.md-aware with legacy fallback, and create a new silver:migrate skill that generates WORKFLOW.md for existing mid-milestone projects.

</domain>

<decisions>
## Implementation Decisions

### HOOK-01 + HOOK-02: dev-cycle-check.sh and completion-audit.sh
- **D-01:** Both hooks currently check for skill invocation markers and step completion. They must now FIRST check WORKFLOW.md for path completion status. If WORKFLOW.md exists, use path completion as the primary gate. If WORKFLOW.md does not exist, fall back to current legacy markers.
- **D-02:** WORKFLOW.md path completion check: parse the `## Path Log` section, count completed paths vs total paths in the composition. A phase is complete when all required paths show status "complete".
- **D-03:** Legacy fallback preserved exactly as-is — no changes to existing marker-based logic.

### HOOK-03: compliance-status.sh
- **D-04:** Currently shows skill count and enforcement status. Add a new line showing path progress: "PATH 5/12" format (completed/total from WORKFLOW.md).
- **D-05:** If WORKFLOW.md doesn't exist, show "PATH: N/A (legacy mode)" instead.

### HOOK-04: prompt-reminder.sh
- **D-06:** Currently includes skill count and phase context for post-compact recovery. Add WORKFLOW.md position: current path name, next path, and composition mode.
- **D-07:** If WORKFLOW.md doesn't exist, omit the path position line.

### HOOK-05: spec-floor-check.sh
- **D-08:** Currently blocks if SPEC.md doesn't meet minimum requirements. When WORKFLOW.md exists and PATH 4 (SPECIFY) is intentionally excluded from the composition (not in the path chain), downgrade spec-floor-check from blocking to advisory.
- **D-09:** Detection: read WORKFLOW.md composition section, check if PATH 4 appears. If absent, the user intentionally skipped specification (e.g., for trivial changes).

### HOOK-06: silver:migrate
- **D-10:** New skill file: `skills/silver-migrate/SKILL.md`. Scans .planning/STATE.md + existing artifacts (SPEC.md, PLAN.md, SUMMARY.md, VERIFICATION.md, SECURITY.md, REVIEW.md) to infer which paths have been completed.
- **D-11:** Generates WORKFLOW.md from template (templates/workflow.md.base) with inferred path statuses pre-filled.
- **D-12:** Presents the generated WORKFLOW.md to user for confirmation before writing. User can adjust path statuses.
- **D-13:** After confirmation, writes WORKFLOW.md and commits.

### Files Modified
- **D-14:** Hook scripts: `hooks/dev-cycle-check.sh`, `hooks/completion-audit.sh`, `hooks/compliance-status.sh`, `hooks/prompt-reminder.sh`, `hooks/spec-floor-check.sh`
- **D-15:** New skill: `skills/silver-migrate/SKILL.md`
- **D-16:** No changes to hooks.json (hook registration stays the same — only script content changes)

### Claude's Discretion
- WORKFLOW.md parsing approach (grep/sed vs node script in hooks/lib/)
- Exact format of path progress display in compliance-status.sh
- Artifact-to-path mapping logic in silver:migrate
- Error handling when WORKFLOW.md is malformed

</decisions>

<canonical_refs>
## Canonical References

### Hook Scripts (to be modified)
- `hooks/dev-cycle-check.sh`
- `hooks/completion-audit.sh`
- `hooks/compliance-status.sh`
- `hooks/prompt-reminder.sh`
- `hooks/spec-floor-check.sh`

### State Templates
- `templates/workflow.md.base` — WORKFLOW.md template with heartbeat fields (updated in Phase 25)

### Path Contracts
- `docs/composable-paths-contracts.md` — Path definitions for artifact-to-path mapping

### Requirements
- `.planning/ROADMAP.md` — Phase 26 success criteria (HOOK-01 through HOOK-06)

</canonical_refs>

<code_context>
## Existing Code Insights

### Hook Architecture
- All hooks are bash scripts in hooks/ directory
- hooks.json registers which hooks fire on which events
- hooks/lib/ contains shared utility functions
- Hooks use exit codes: 0=pass, 1=fail/block

### Integration Points
- WORKFLOW.md is at .planning/WORKFLOW.md (same directory as STATE.md)
- Hooks already read .planning/STATE.md — same pattern extends to WORKFLOW.md
- silver:migrate is a new skill file following existing skills/* pattern

</code_context>

<specifics>
## Specific Ideas

- The key pattern is: check WORKFLOW.md first, if missing fall back to legacy — every modified hook follows this pattern
- silver:migrate is the most complex new addition — it needs to map artifacts to paths correctly
- spec-floor-check.sh advisory downgrade is the most nuanced hook change — it changes enforcement behavior based on composition

</specifics>

<deferred>
## Deferred Ideas

None

</deferred>

---

*Phase: 26-hook-alignment-silver-migrate*
*Context gathered: 2026-04-15 via auto mode*
