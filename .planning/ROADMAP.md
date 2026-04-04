# Roadmap — Silver Bullet v0.7.0

## Phase 1: Separate silver-bullet.md from CLAUDE.md
**Goal:** Move all Silver Bullet enforcement instructions from CLAUDE.md into a dedicated silver-bullet.md file at project root. Update /using-silver-bullet skill for fresh setup, update mode, and conflict detection. Update the plugin's own project to eat its own dogfood.

**Requirements:** [R1]

**Plans:** 1 plan

Plans:
- [ ] 01-PLAN.md — Create silver-bullet.md template, simplify CLAUDE.md template, update setup skill, dogfood, update help site

**Scope:**
- Create `templates/silver-bullet.md.base` with all SB content from current CLAUDE.md.base
- Simplify `templates/CLAUDE.md.base` to reference silver-bullet.md
- Update `skills/using-silver-bullet/SKILL.md` — fresh setup writes both files, update mode overwrites silver-bullet.md only, conflict detection scans CLAUDE.md
- Update plugin's own CLAUDE.md + create silver-bullet.md (dogfood)
- Update help site references and search index
