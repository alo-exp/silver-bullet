# Phase 27: silver-fast Redesign — Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from roadmap + prior phase context)

<domain>
## Phase Boundary

Redesign silver-fast from a 2-tier system (trivial → gsd-fast, everything else → escalate) into a 3-tier complexity triage: trivial → gsd-fast, medium → gsd-quick with intelligent flag composition, complex → silver-feature escalation. Autonomous escalation detects scope expansion and re-routes without user intervention.

</domain>

<decisions>
## Implementation Decisions

### 3-Tier Complexity Triage
- **D-01:** Tier 1 (Trivial): ≤3 files AND no logic changes (typo, config, rename, comment, one-liner). Routes to gsd-fast. Unchanged from current behavior.
- **D-02:** Tier 2 (Medium): 4-10 files OR logic change in ≤3 files OR dependency update. Routes to gsd-quick with appropriate flags. This is the NEW tier.
- **D-03:** Tier 3 (Complex): >10 files OR cross-cutting concern OR schema change OR new capability. Escalates to silver-feature. This replaces the current catch-all escalation.

### gsd-quick Flag Selection (Tier 2)
- **D-04:** Flag selection based on signal detection from change description:
  - Ambiguity signals (unclear scope, "not sure", multiple approaches) → `--discuss`
  - Novel domain signals (new library, unfamiliar API, "investigate") → `--research`
  - Production code signals (modifies src/, app/, lib/ with logic) → `--validate`
  - All three signals present → `--full`
  - No signals detected → bare gsd-quick (fastest medium path)
- **D-05:** Flags are composable — any combination is valid (e.g., `--discuss --validate` without `--research`).

### Autonomous Escalation
- **D-06:** Escalation triggers during execution when scope expands beyond current tier:
  - gsd-fast scope expands beyond 3 files → check if Tier 2 applies, route to gsd-quick if so
  - gsd-quick scope expands beyond 10 files → escalate to silver-feature
- **D-07:** Escalation is autonomous — re-runs /silver classification with expanded scope description. No user prompt needed (aligns with anti-stall design from Phase 25).
- **D-08:** On escalation, display FAST PATH ESCALATION banner with reason and target workflow.

### Composition Integration
- **D-09:** silver-fast does NOT get a Composition Proposal section. It remains a lightweight bypass — no WORKFLOW.md tracking, no path chain. If escalated, the target workflow handles composition.
- **D-10:** silver-fast does NOT modify silver-bullet.md §10 preferences (unchanged from current).

### Files Modified
- **D-11:** Primary file: `skills/silver-fast/SKILL.md` — rewrite with 3-tier triage, gsd-quick routing, and autonomous escalation.
- **D-12:** No other files modified. The /silver router already routes to silver:fast — no routing changes needed.

### Claude's Discretion
- Exact signal detection heuristics for gsd-quick flag selection
- Banner formatting for escalation messages
- Whether to show a summary of detected signals before routing to gsd-quick
- Error handling when gsd-quick is not available

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Skill Files
- `skills/silver-fast/SKILL.md` — Current 2-tier implementation (to be rewritten)
- `skills/silver/SKILL.md` — Router with silver:fast routing entry

### GSD Skills
- `${SB_RUNTIME_HOME_ROOT}/skills/gsd-quick/SKILL.md` — gsd-quick with flag documentation
- `${SB_RUNTIME_HOME_ROOT}/skills/gsd-fast/SKILL.md` — gsd-fast execution

### Prior Phase Context
- `.planning/phases/25-composer-redesign/25-CONTEXT.md` — Composition Proposal pattern (D-03: router unchanged)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/silver-fast/SKILL.md` — Current 125-line skill with Step 0 triage, Step 1 gsd-fast execution, Step 2 scope expansion check, Step 3 verify, Step 4 confirm
- Existing AskUserQuestion escalation pattern (Step 0 and Step 2) — will be modified for 3-tier routing

### Established Patterns
- Banner display pattern: `━━━━━ SILVER BULLET ► FAST PATH ━━━━━`
- Scope expansion check (Step 2) already exists — needs enhancement for Tier 2 routing
- Escalation options (silver:feature, silver:bugfix, silver:devops) already exist in Step 0 and Step 2

### Integration Points
- /silver router routes to silver:fast based on complexity triage — this routing is unchanged
- gsd-quick is a GSD skill at ${SB_RUNTIME_HOME_ROOT}/skills/gsd-quick/ — invoked via Skill tool
- silver-feature is invoked via Skill tool on complex escalation

</code_context>

<specifics>
## Specific Ideas

- The key change is adding Tier 2 (medium) between the existing trivial and complex tiers
- gsd-quick flag selection should be lightweight — a few grep-like checks on the change description, not a full analysis
- The autonomous escalation from Phase 25's anti-stall design applies here — no blocking on user input during escalation
- Current Step 0 AskUserQuestion for complexity confirmation should be enhanced to detect medium tier automatically

</specifics>

<deferred>
## Deferred Ideas

None — scope is straightforward

</deferred>

---

*Phase: 27-silver-fast-redesign*
*Context gathered: 2026-04-15 via auto mode*
