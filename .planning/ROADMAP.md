# Roadmap — Silver Bullet v0.7.0

## Phase 1: Separate silver-bullet.md from CLAUDE.md
**Goal:** Move all Silver Bullet enforcement instructions from CLAUDE.md into a dedicated silver-bullet.md file at project root. Update /using-silver-bullet skill for fresh setup, update mode, and conflict detection. Update the plugin's own project to eat its own dogfood.

**Requirements:** [SB-R1]

**Plans:** 1 plan

Plans:
- [x] 01-PLAN.md — Create silver-bullet.md template, simplify CLAUDE.md template, update setup skill, dogfood, update help site

**Success Criteria:**
- `silver-bullet.md` exists at project root with all 10 sections (0-9)
- `CLAUDE.md` references silver-bullet.md with a mandatory enforcement line
- Update mode overwrites only silver-bullet.md, never CLAUDE.md
- Conflict detection resolves contradictions between CLAUDE.md and silver-bullet.md interactively

**Scope:**
- Create `templates/silver-bullet.md.base` with all SB content from current CLAUDE.md.base
- Simplify `templates/CLAUDE.md.base` to reference silver-bullet.md
- Update `skills/using-silver-bullet/SKILL.md` — fresh setup writes both files, update mode overwrites silver-bullet.md only, conflict detection scans CLAUDE.md
- Update plugin's own CLAUDE.md + create silver-bullet.md (dogfood)
- Update help site references and search index

---

## Phase 2: Skill Enforcement Expansion
**Goal:** Incorporate four gap-filling skills from installed dependency plugins as explicit workflow requirements with hook enforcement: `test-driven-development` (EXECUTE), `tech-debt` (FINALIZATION), `accessibility-review` (UI work conditional in DISCUSS), and `incident-response` (DevOps incident fast path). Update `.silver-bullet.json` to track and enforce the new skills. Release as v0.8.0.

**Requirements:** [SB-R2]

**Plans:** 2/2 plans complete

Plans:
- [x] 02-01-PLAN.md — full-dev-cycle workflow (3 skill gates) + .silver-bullet.json (4 skills added)
- [x] 02-02-PLAN.md — devops-cycle workflow (3 skill gates, incident-response step renumbering)

**Success Criteria:**
- `test-driven-development` is a REQUIRED step in EXECUTE for both full-dev-cycle and devops-cycle workflows
- `tech-debt` replaces the inline manual step in FINALIZATION for both workflows
- `accessibility-review` is required when UI work is present in the DISCUSS conditional
- `incident-response` is step 1 of the devops-cycle Incident Fast Path
- All 4 skills added to `all_tracked` in `.silver-bullet.json`
- `test-driven-development` and `tech-debt` added to `required_deploy` for hook enforcement
- `templates/` mirrors all workflow doc changes
- CI green, released as v0.8.0, local installation updated

**Scope:**
- `docs/workflows/full-dev-cycle.md` — add TDD in EXECUTE, tech-debt in FINALIZATION, accessibility-review in DISCUSS UI conditional
- `docs/workflows/devops-cycle.md` — add TDD in EXECUTE, tech-debt in FINALIZATION, incident-response in INCIDENT FAST PATH
- `templates/workflows/full-dev-cycle.md` — mirror of docs/ changes
- `templates/workflows/devops-cycle.md` — mirror of docs/ changes
- `.silver-bullet.json` — add 4 skills to `all_tracked`; add TDD + tech-debt to `required_deploy`
