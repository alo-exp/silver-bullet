# Phase 28: Documentation Update — Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from roadmap + codebase analysis)

<domain>
## Phase Boundary

Update all documentation to reflect the composable paths architecture implemented in Phases 21-27. Four files need updating: silver-bullet.md §2h, doc-scheme.md(.base), ENFORCEMENT.md, and full-dev-cycle.md.

</domain>

<decisions>
## Implementation Decisions

### silver-bullet.md §2h Rewrite
- **D-01:** Rewrite §2h to describe composable paths architecture. The 8-workflow table stays (it describes routing, which is unchanged) but add a new section describing how each workflow composes paths from the 18-path catalog.
- **D-02:** Add a composable paths overview paragraph before the workflow table explaining the architecture: paths are building blocks, /silver composes them into chains based on context, WORKFLOW.md tracks state.
- **D-03:** Update the silver:fast row to mention 3-tier triage (Tier 1→gsd-fast, Tier 2→gsd-quick, Tier 3→silver-feature).
- **D-04:** Add a "Composable Paths" subsection after the workflow table listing all 18 paths (PATH 0-17) with one-line descriptions and cross-reference to docs/composable-paths-contracts.md.
- **D-05:** templates/silver-bullet.md.base must be updated in lockstep with silver-bullet.md — same changes applied to both files.

### doc-scheme.md Updates
- **D-06:** doc-scheme.md already has WORKFLOW.md and VALIDATION.md from Phase 21. Verify it includes all new artifacts: WORKFLOW.md, VALIDATION.md, UI-SPEC.md, UI-REVIEW.md, SECURITY.md. Add any missing.
- **D-07:** templates/doc-scheme.md.base must be updated in lockstep with docs/doc-scheme.md.

### ENFORCEMENT.md Updates
- **D-08:** Update ENFORCEMENT.md to reflect Phase 26 hook modifications: dev-cycle-check.sh now checks WORKFLOW.md Path Log as primary gate with legacy fallback, completion-audit.sh uses same pattern, compliance-status.sh shows path progress, prompt-reminder.sh includes WORKFLOW.md position, spec-floor-check.sh downgrades to advisory when PATH 4 excluded.
- **D-09:** Add a section describing WORKFLOW.md-first enforcement pattern: hooks check WORKFLOW.md Path Log before falling back to legacy skill markers.

### full-dev-cycle.md Demotion
- **D-10:** Add a header notice to full-dev-cycle.md indicating it is now an example composition, not the primary workflow reference. Something like: "NOTE: This document shows a representative path composition for feature development. The actual workflow is dynamically composed by /silver. See silver-bullet.md §2h for the composable paths architecture."
- **D-11:** Do NOT delete or significantly modify full-dev-cycle.md — it remains a useful reference showing what a typical feature development composition looks like.

### Files Modified
- **D-12:** `silver-bullet.md` and `templates/silver-bullet.md.base` — §2h rewrite
- **D-13:** `docs/doc-scheme.md` and `templates/doc-scheme.md.base` — artifact additions
- **D-14:** `docs/ENFORCEMENT.md` — hook modification documentation
- **D-15:** `docs/workflows/full-dev-cycle.md` — demotion notice

### Claude's Discretion
- Exact wording of the composable paths overview paragraph
- Whether to list all 18 paths inline in §2h or just cross-reference the contracts doc
- Level of detail in ENFORCEMENT.md hook descriptions
- Formatting of the full-dev-cycle.md demotion notice

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Documentation Files (to be updated)
- `silver-bullet.md` — Main project doc, §2h needs rewrite (864 lines total)
- `templates/silver-bullet.md.base` — Template version, must match silver-bullet.md (745 lines)
- `docs/doc-scheme.md` — Artifact documentation scheme (105 lines)
- `templates/doc-scheme.md.base` — Template version
- `docs/ENFORCEMENT.md` — Hook enforcement documentation (62 lines)
- `docs/workflows/full-dev-cycle.md` — Full dev cycle reference (704 lines)

### Source of Truth for Changes
- `docs/composable-paths-contracts.md` — All 18 path contracts
- `hooks/dev-cycle-check.sh` — WORKFLOW.md-first pattern
- `hooks/completion-audit.sh` — Same pattern
- `hooks/compliance-status.sh` — Path progress display
- `hooks/prompt-reminder.sh` — WORKFLOW.md position inclusion
- `hooks/spec-floor-check.sh` — Advisory downgrade logic
- `templates/workflow.md.base` — WORKFLOW.md template with heartbeat
- `skills/silver-fast/SKILL.md` — Updated 3-tier triage

</canonical_refs>

<code_context>
## Existing Code Insights

### Current State
- silver-bullet.md §2h (lines 294-331): Describes 8 workflows in a table. Needs composable paths context added.
- doc-scheme.md: 105 lines. May already have Phase 21 updates (WORKFLOW.md, VALIDATION.md).
- ENFORCEMENT.md: 62 lines. Describes hooks but doesn't reflect Phase 26 WORKFLOW.md changes.
- full-dev-cycle.md: 704 lines. Still describes fixed pipeline — needs demotion notice.

### Template Sync Pattern
- silver-bullet.md ↔ templates/silver-bullet.md.base must stay in sync
- doc-scheme.md ↔ templates/doc-scheme.md.base must stay in sync
- Both files must be committed together

</code_context>

<specifics>
## Specific Ideas

- The §2h rewrite is the most impactful change — it's the primary reference for how Silver Bullet works
- doc-scheme.md changes may be minimal if Phase 21 already added the new artifacts
- ENFORCEMENT.md is small (62 lines) — the hook changes section should be concise
- full-dev-cycle.md demotion is a 2-3 line notice at the top — minimal change

</specifics>

<deferred>
## Deferred Ideas

None — scope is straightforward documentation updates

</deferred>

---

*Phase: 28-documentation-update*
*Context gathered: 2026-04-15 via auto mode*
