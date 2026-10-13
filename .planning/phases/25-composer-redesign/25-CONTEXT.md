# Phase 25: Composer Redesign - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from roadmap + prior context from Phases 21-24)

<domain>
## Phase Boundary

Redesign /silver from a simple router (match intent → invoke skill) into a composer that: classifies context, selects and orders paths from the 18-path catalog, proposes compositions to the user (or auto-confirms in autonomous mode), supervises end-to-end execution with anti-stall mechanisms, and supports dynamic path insertion. Create composition templates for all silver-* workflows as shortcut compositions.

</domain>

<decisions>
## Implementation Decisions

### COMP-01: Context Classification + Path Selection
- **D-01:** /silver's Step 2 (classify intent and complexity) is enhanced to also classify which PATHS are needed. After routing to a silver-* workflow, the workflow itself becomes a composition template that proposes a path chain.
- **D-02:** Context classification signals: existing artifacts (.planning/SPEC.md, PLAN.md, VERIFICATION.md), user intent keywords, phase state, file types mentioned. These determine which paths to include/skip.
- **D-03:** The /silver router (skills/silver/SKILL.md) stays as the entry point. The composer logic lives in the silver-* workflow files (silver-feature, silver-ui, etc.) which already contain the path sections from Phases 22-24.

### COMP-02: Composition Templates
- **D-04:** Each silver-* workflow file IS a composition template. They already contain PATH sections in order. The change is adding a composition proposal step at the top that reads context and proposes which paths to include.
- **D-05:** Templates to update: silver-feature (full chain), silver-ui (UI-focused chain), silver-bugfix (triage chain), silver-devops (infra chain), silver-research (exploration chain), silver-release (milestone chain).
- **D-06:** Each template gets a new "## Composition Proposal" section after Pre-flight that: reads existing artifacts, determines which PATHs to include/skip, proposes the chain to user (or auto-confirms), then executes sequentially.

### COMP-03: End-to-End Supervision Loop
- **D-07:** After each PATH completes, the workflow checks: (1) exit condition met? (2) should composition change based on new context? (3) stall detected? (4) advance to next path. This is the supervision loop.
- **D-08:** Supervision is implemented as logic BETWEEN path sections in each workflow file. Not a separate skill — it's inline orchestration within silver-feature etc.
- **D-09:** Progress reporting: after each path, display `PATH N/M: [name] ✓` with elapsed context and remaining paths.
- **D-10:** WORKFLOW.md is updated after each path completion (write path status, timestamp). This is the persistent composition state.

### COMP-04: Dynamic Insertion
- **D-11:** Dynamic insertion means adding paths to the composition at runtime based on context changes. Example: PATH 14 (DEBUG) inserted when execution fails, PATH 6 (DESIGN CONTRACT) inserted when UI files are discovered.
- **D-12:** Implementation: each PATH's exit check includes a "context evaluation" that can trigger insertion. The inserted path runs before advancing to the next planned path.
- **D-13:** All insertions are recorded in WORKFLOW.md with reason and timestamp.

### COMP-05: Per-Phase Looping
- **D-14:** The composed workflow loops over phases. For each phase: PATH 5 (PLAN) → PATH 7 (EXECUTE) → PATH 11 (VERIFY) → PATH 13 (SHIP) with optional paths inserted per phase.
- **D-15:** Phase advancement uses GSD's STATE.md. The composer reads STATE.md to know which phase is current, executes paths for that phase, then advances.

### COMP-06: 4-Tier Anti-Stall
- **D-16:** Tier 1 (Progress-based): if no WORKFLOW.md path advancement in 10 minutes of execution, warn user.
- **D-17:** Tier 2 (Permission-stall): if workflow is blocked waiting for user input for >5 minutes in autonomous mode, auto-select recommended option and log.
- **D-18:** Tier 3 (Context exhaustion): if context window is >80% full, trigger /compact recommendation. If >90%, force compact.
- **D-19:** Tier 4 (Heartbeat sentinel): each path invocation logs a heartbeat to WORKFLOW.md. If heartbeat gap >15 minutes, the supervision loop assumes the path stalled and offers: retry, skip, or debug.
- **D-20:** Anti-stall is implemented as checks within the supervision loop (D-07/D-08), not as a separate mechanism.

### Files Modified
- **D-21:** Primary files: `skills/silver-feature/SKILL.md` (composition proposal + supervision loop), `skills/silver-ui/SKILL.md`, `skills/silver-bugfix/SKILL.md`, `skills/silver-devops/SKILL.md`, `skills/silver-research/SKILL.md`, `skills/silver-release/SKILL.md` (composition proposals).
- **D-22:** Supporting: `templates/workflow.md.base` (may need heartbeat fields), `skills/silver/SKILL.md` (minor — ensure routing still works with composer).

### Claude's Discretion
- Exact format of composition proposal display to user
- Heartbeat implementation details (timestamp format, field names)
- How to detect "UI files discovered" for dynamic PATH 6 insertion
- Context exhaustion percentage thresholds (approximate values given)
- Whether anti-stall timers are wall-clock or execution-time based

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Path Contracts
- `docs/composable-paths-contracts.md` — Quick-lookup reference for all 18 path contracts

### Skill Files (to be updated)
- `skills/silver-feature/SKILL.md` — Primary workflow; needs composition proposal + supervision loop
- `skills/silver-ui/SKILL.md` — UI workflow; needs composition proposal
- `skills/silver-bugfix/SKILL.md` — Bugfix workflow; needs composition proposal
- `skills/silver-devops/SKILL.md` — DevOps workflow; needs composition proposal
- `skills/silver-research/SKILL.md` — Research workflow; needs composition proposal
- `skills/silver-release/SKILL.md` — Release workflow; needs composition proposal
- `skills/silver/SKILL.md` — Router; verify compatibility

### State Templates
- `templates/workflow.md.base` — WORKFLOW.md template (may need heartbeat fields)

### Requirements
- `.planning/ROADMAP.md` — Phase 25 success criteria (COMP-01 through COMP-06)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All silver-* workflow files already contain PATH sections from Phases 22-24
- silver-feature/SKILL.md has the most complete set: PATH 0 through PATH 17
- WORKFLOW.md template exists in templates/workflow.md.base with composition tracking fields

### Established Patterns
- PATH sections use `## PATH N: NAME` → prerequisite check → numbered steps → exit condition
- Skills invoke other skills via `Skill(skill="skill-name", args="...")` tool
- silver-feature already has Pre-flight → Complexity Triage → sequential steps pattern
- Autonomous mode auto-selects recommended options (established in discuss-phase --auto)

### Integration Points
- Composition proposal goes AFTER Pre-flight, BEFORE Step 0 (Complexity Triage)
- Supervision loop is logic BETWEEN existing PATH sections
- WORKFLOW.md updates happen at PATH boundaries (not within paths)
- Anti-stall checks happen in the supervision loop between paths

</code_context>

<specifics>
## Specific Ideas

- The key insight is that silver-* workflow files already ARE composition templates — they just need a proposal step and supervision wrapper
- The supervision loop is the most architecturally significant addition — it turns sequential skill invocation into a managed execution pipeline
- Anti-stall is critical for autonomous mode — without it, workflows can hang indefinitely on permission prompts or context exhaustion
- WORKFLOW.md heartbeat prevents silent failures where a path appears to be running but is actually stalled

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-composer-redesign*
*Context gathered: 2026-04-15 via auto mode*
