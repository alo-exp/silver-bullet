# Phase 2: silver-bullet.md Overhaul - Context

**Gathered:** 2026-04-05 (autonomous -- decisions locked from approved v0.9.0 plan)
**Status:** Ready for planning

<domain>
## Phase Boundary

Overhaul `silver-bullet.md` to add GSD process knowledge, hand-holding instructions, and utility command awareness -- so Claude can guide users through every workflow transition without reading GSD's own documentation. All 10 existing sections (§0-§9) remain intact. Update `templates/silver-bullet.md.base` to match.

Requirements covered: INST-01 through INST-04 (4 of 22 milestone requirements).

</domain>

<decisions>
## Implementation Decisions

### What to ADD

- **D-01:** Add a new section (between §2 and §3, or as §2a) containing GSD Process Knowledge -- concise descriptions of what each guided GSD command does, what it produces, and when to use it. Claude reads this once at session start and can explain any step to the user without consulting GSD's workflow files.
- **D-02:** Add hand-holding instructions to §2 (Active Workflow): at each workflow transition (DISCUSS→PLAN, PLAN→EXECUTE, EXECUTE→VERIFY, etc.), Claude should proactively tell the user what just completed, what comes next, and what to watch for.
- **D-03:** Add utility command awareness as a subsection of the new GSD Process Knowledge section: context-based triggers for suggesting /gsd:debug (execution fails), /gsd:quick (ad-hoc task), /gsd:resume-work (session break), /gsd:pause-work (graceful stop), /gsd:progress (status check).
- **D-04:** Add a brief "Workflow Transition" subsection covering dev-to-DevOps and DevOps-to-dev transitions, referencing the transition logic in the workflow files.

### What to KEEP (unchanged)

- **D-05:** §0 (Session Startup) -- unchanged
- **D-06:** §1 (Automated Enforcement) -- unchanged (7 layers)
- **D-07:** §3 (Non-Negotiable Rules) -- unchanged (anti-skip, mandatory Skill tool invocations)
- **D-08:** §3a (Review Loop Enforcement) -- unchanged (2 consecutive ✅)
- **D-09:** §3b (GSD Command Tracking) -- unchanged
- **D-10:** §4 (Session Mode) -- unchanged (interactive/autonomous, bypass-permissions)
- **D-11:** §5 (Model Routing) -- unchanged
- **D-12:** §6 (GSD/Superpowers Ownership Rules) -- unchanged
- **D-13:** §7 (File Safety Rules) -- unchanged
- **D-14:** §8 (Third-Party Plugin Boundary) -- unchanged
- **D-15:** §9 (Pre-Release Quality Gate) -- unchanged

### What to MODIFY

- **D-16:** §2 (Active Workflow) -- expand with hand-holding instructions (D-02). Currently just says "read the workflow file." Add transition narration guidance.
- **D-17:** §6 (Ownership Rules) -- may need minor update to reflect that SB now orchestrates GSD (not just wraps it). Currently says "GSD owns execution/planning" -- this remains true but the relationship is richer now.

### Template Parity

- **D-18:** `templates/silver-bullet.md.base` must be updated to match the new silver-bullet.md structure (with `{{PLACEHOLDER}}` substitutions where applicable). Currently uses `{{PROJECT_NAME}}` and `{{ACTIVE_WORKFLOW}}`.

### Claude's Discretion

- Exact section numbering (new section could be §2a or §2.5 or renumber existing sections)
- Exact wording of GSD process knowledge descriptions
- Level of detail in hand-holding instructions (enough for a GSD-naive user, not overwhelming)
- Whether utility command triggers are a table or prose

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current silver-bullet.md (being modified)
- `silver-bullet.md` -- All 10 sections (§0-§9), 367 lines, 17 headings
- `templates/silver-bullet.md.base` -- Template with placeholders

### New workflow files (source of GSD process knowledge)
- `docs/workflows/full-dev-cycle.md` -- Comprehensive orchestration guide (688 lines) -- Phase 1 output
- `docs/workflows/devops-cycle.md` -- DevOps orchestration guide (795 lines) -- Phase 1 output

### GSD reference (for process knowledge content)
- `~/.claude/get-shit-done/workflows/discuss-phase.md` -- GSD discuss internals
- `~/.claude/get-shit-done/workflows/plan-phase.md` -- GSD plan internals
- `~/.claude/get-shit-done/workflows/execute-phase.md` -- GSD execute internals
- `~/.claude/get-shit-done/workflows/verify-work.md` -- GSD verify internals

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- silver-bullet.md §6 already has ownership rules that define SB/GSD relationship
- Workflow files (Phase 1 output) already contain what/expect/fail descriptions for each GSD step -- silver-bullet.md can reference these rather than duplicating

### Established Patterns
- silver-bullet.md uses numbered sections (§0 through §9)
- Each section has a clear header and focused content
- Anti-skip rules use explicit "you are violating this rule if..." language
- Placeholders in .base template: `{{PROJECT_NAME}}`, `{{ACTIVE_WORKFLOW}}`

### Integration Points
- `hooks/compliance-status.sh` reads silver-bullet.md indirectly (via config)
- `skills/using-silver-bullet/SKILL.md` writes silver-bullet.md from template during setup
- `docs/workflows/*.md` are referenced by §2 (Active Workflow)

</code_context>

<specifics>
## Specific Ideas

- The GSD Process Knowledge section should be a concise lookup table, not a verbose guide -- the workflow files already have the detailed explanations
- Hand-holding instructions should be "at this transition, say X to the user" -- directive, not descriptive
- The file should remain under 500 lines to keep context window usage reasonable

</specifics>

<deferred>
## Deferred Ideas

- Forensics evolution -- Phase 3
- Template parity verification -- Phase 4
- README/site updates -- Phase 5

</deferred>

---

*Phase: 02-silver-bullet-md-overhaul*
*Context gathered: 2026-04-05*
