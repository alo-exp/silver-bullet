# Full Dev Cycle Workflow

> **ENFORCED** — Every skill invocation is tracked by PostToolUse hooks.
> HARD STOP fires if you edit source without completing planning.
> Completion audit BLOCKS git commit/push if required skills are missing.
> Compliance score is shown after EVERY tool use.

## Steps

### PLANNING (must complete before ANY src/ edit — HARD STOP enforced)

1.  `/using-superpowers`              — Establish available skills                 **REQUIRED** <- DO NOT SKIP
2.  `/using-git-worktrees`            — ASK user: "Should I use a git worktree?"
3.  `/brainstorming`                  — Explore intent, constraints, approaches    **REQUIRED** <- DO NOT SKIP
                                        Point to spec directory: `docs/specs/`
4.  `/write-spec`                     — Write or update spec in `docs/specs/`;     **REQUIRED** <- DO NOT SKIP
                                        update `Master-PRD.md`
5.  `/design-system`      (if needed) — Visual/UI design
6.  `/ux-copy`            (if needed) — Review UX copy
7.  `/architecture`       (if needed) — ADR for architectural decisions
8.  `/system-design`      (if needed) — Service/component design
9.  `/modularity`                     — Verify modular design before planning       **REQUIRED** <- DO NOT SKIP
10. `/writing-plans`                  — Detailed implementation plan               **REQUIRED** <- DO NOT SKIP

### EXECUTION

11. `/executing-plans`                — Execute using BOTH:                        **REQUIRED** <- DO NOT SKIP
                                          `/test-driven-development` (TDD)
                                          `/subagent-driven-development` (parallel)

### REVIEW (must complete before deploy — deploy gate enforced)

12. `/code-review`                    — Round 1 self-review                        **REQUIRED** <- DO NOT SKIP
    `superpowers:code-reviewer agent` — Run code-reviewer subagent
13. `/requesting-code-review`         — Request external/peer review
14. `/receiving-code-review`          — Accept/reject all items from 12-13         **REQUIRED** <- DO NOT SKIP
15. `/writing-plans`                  — Plan to address accepted review items
16. `/executing-plans`                — Implement the review-driven plan
17. `/testing-strategy`               — Define best test strategy                  **REQUIRED** <- DO NOT SKIP
18. `/systematic-debugging` + `/debug` — Use BOTH for any bug encountered

### FINALIZATION (must complete before deploy — deploy gate enforced)

19. `/tech-debt`                      — Identify and document technical debt
20. `/documentation`                  — Update/create all project docs              **REQUIRED** <- DO NOT SKIP
                                        Minimum: `Master-PRD.md`,
                                        `Architecture-and-Design.md`,
                                        `Testing-Strategy-and-Plan.md`, `CICD.md`
21. `/verification-before-completion` — Produce evidence before claiming done      **REQUIRED** <- DO NOT SKIP
22. `/finishing-a-development-branch` — If on dev branch: merge prep + cleanup     **REQUIRED** <- DO NOT SKIP

### DEPLOYMENT

23. CICD pipeline                     — Use existing or set up before deploying    **REQUIRED** <- DO NOT SKIP
                                        GitHub repos: use GitHub Actions
24. `/deploy-checklist`               — Pre-deployment verification gate           **REQUIRED** <- DO NOT SKIP

---

## Enforcement Rules

- Each REQUIRED skill MUST be explicitly invoked via the Skill tool
- "I already covered this" is NOT valid — hooks track Skill tool invocations, not judgment
- Phase order MUST be followed: PLANNING -> EXECUTION -> REVIEW -> FINALIZATION -> DEPLOYMENT
- Do NOT skip to a later phase before completing the current phase
- For trivial changes (typos, copy fixes): `touch /tmp/.dev-workflows-trivial`
