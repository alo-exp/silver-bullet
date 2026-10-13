# RFL Review Prompt Preamble — required read order

Every adversarial architecture review cycle for plan `router_subagent_surfaces_85bf9f09` MUST follow this order.

## 1. Product / architecture / inner workings (mandatory first)

Read in full (native/raw):

`/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`

This is the **product briefing** (what SB is, Process/Workflow/AF, orchestrator parent/worker, hosts, hooks/skills, quality loops as product behavior, Authorizer/migrate).  
**Do not** treat `silver-bullet.md` as a rules dump substitute for this overview.

Optional deepeners only if needed after the overview:

- `docs/ARCHITECTURE.md`
- `docs/PRD-Overview.md`
- `docs/ORCHESTRATOR.md`
- `AGENTS.md` (repo shape)

## 2. Plan under review

`/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`

## 3. Clarify brief (skim)

`/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`

## 4. Then review

Adversarially review the plan for fit with the product architecture in the overview: contradictions, gaps vs locked decisions (P/I/A/V/Val, Authorizer, routes, migrate, Knowledge/Learnings, launch prompt+spec, WBS, on-demand Advisor), state-machine holes, traceability orphans, executability.

Ignore obsolete RFL ceremony (`verify_1`/`verify_2`, charter-signal grep, orchestrator grep, PM filing).

End with exactly one line: `VERDICT: CLEAN` or `VERDICT: NEEDS_FIXES` (plus numbered material findings if NEEDS_FIXES).
