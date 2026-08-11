# RFL Review Prompt Preamble — Silver Bullet Overview (required)

Every adversarial architecture review cycle for plan `router_subagent_surfaces_85bf9f09` MUST begin by absorbing Silver Bullet product/architecture background. Do **not** review the plan in isolation.

## Read first (native/raw reads — no compressed lean-ctx as source of truth)

1. **Canonical instructions (full):** `/Users/shafqat/projects/silver-bullet/repo/silver-bullet.md`
2. **Repo operational guide:** `/Users/shafqat/projects/silver-bullet/repo/AGENTS.md`
3. **Architecture entry (skim):** `/Users/shafqat/projects/silver-bullet/repo/docs/ARCHITECTURE.md`
4. **Orchestrator / Process-router entry (skim if needed):** `/Users/shafqat/projects/silver-bullet/repo/docs/ORCHESTRATOR.md`

## Absorb before reviewing

From the above, understand at least:

- What Silver Bullet is (enforcement + workflow orchestration plugin for AI coding hosts)
- Process → Workflow → Atomic Flow (AF) → Step → Skill hierarchy
- Public `/silver` Process router vs `silver:<route>` Workflow/AF surfaces
- Hosts/adapters (Cursor, Codex, Claude Code; OpenCode deferred where applicable)
- Hooks, skills, templates, contracts/locks, and generated mirrors
- Quality loops naming: I-loop / A-loop / V-loop / Validation-loop (not obsolete RFL ceremony)
- Authorizer, migrate, Knowledge/Learnings, and subagent launch concepts as they appear in SB docs

## Then review the plan

Only after SB background is absorbed, adversarially review:

- Plan: `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
- Clarify brief (skim): `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`

Judge the plan against SB’s real product shape (hosts, Process/Workflow/AF, hooks/skills, enforcement), not as a freestanding design doc.
