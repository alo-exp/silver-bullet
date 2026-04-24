## Summary

Port the Silver Bullet (SB) Claude Code plugin system to run natively in Forge (forgecode.dev), using only Forge's native primitives: AGENTS.md global/project instructions and `.forge/skills/` skill files with YAML frontmatter trigger keywords.

Silver Bullet is a 41-skill, 23-hook workflow system for Claude Code that implements:
- GSD (Get Shit Done) planning/execution methodology
- 9-dimension quality gates (modularity → AI/LLM safety)
- TDD iron law enforcement
- Multi-AI review orchestration
- Feature, bugfix, UI, DevOps, research, release workflows
- Pre-plan and pre-ship quality gate evaluation

**All SB dependencies must also be ported as part of this work:**
- `superpowers` plugin: TDD, brainstorming, writing-plans, code-review sub-skills
- `gsd` npm package: discuss-phase, plan-phase, execute-phase, verify-work, ship, code-review, secure-phase, etc.
- `design` plugin: UI spec, UI quality dimensions
- `multai` plugin: multi-AI review orchestration
- `episodic-memory` plugin: cross-session decision recording

## Motivation

Forge is a fast, cost-effective AI coding agent optimized for Rust/systems work. Power users want the same disciplined development workflow (quality gates, TDD, multi-phase planning) in Forge that SB provides in Claude Code. Forge's AGENTS.md + .forge/skills/ system can approximate most of SB's functionality without requiring any Claude Code infrastructure.

## Deliverables

```
forge/                            # New directory in this repo
  AGENTS.md.template              # Global ~/forge/AGENTS.md content
  AGENTS.project.template         # Project ./AGENTS.md template
  skills/
    silver/SKILL.md               # Master router
    silver-feature/SKILL.md       # Full feature development workflow
    silver-bugfix/SKILL.md        # Bug triage + fix workflow
    silver-ui/SKILL.md            # UI/frontend workflow
    silver-devops/SKILL.md        # Infra/CI/CD workflow
    silver-research/SKILL.md      # Technology decision/spike workflow
    quality-gates/SKILL.md        # 9-dimension master
    modularity/SKILL.md
    reusability/SKILL.md
    scalability/SKILL.md
    security/SKILL.md
    reliability/SKILL.md
    usability/SKILL.md
    testability/SKILL.md
    extensibility/SKILL.md
    ai-llm-safety/SKILL.md
    tdd/SKILL.md                  # TDD iron law
    brainstorming/SKILL.md        # Idea → design → spec
    writing-plans/SKILL.md        # Spec → implementation plan
    requesting-code-review/SKILL.md
    receiving-code-review/SKILL.md
    finishing-branch/SKILL.md
    gsd-discuss/SKILL.md
    gsd-plan/SKILL.md
    gsd-execute/SKILL.md
    gsd-verify/SKILL.md
    gsd-ship/SKILL.md
    gsd-review/SKILL.md
    gsd-review-fix/SKILL.md
    gsd-secure/SKILL.md
    gsd-validate/SKILL.md
    gsd-intel/SKILL.md
    gsd-progress/SKILL.md
    gsd-brainstorm/SKILL.md

forge-sb-install.sh               # Idempotent project bootstrapper (--dry-run flag)
tests/smoke-test.sh               # Verify all skills installed, trigger keywords present
docs/forge-sb-README.md           # Usage guide for Forge users
docs/mapping-table.md             # Claude Code primitive → Forge primitive mapping
```

## Scope (8 Phases)

### Phase 1: Architecture & Primitive Mapping
Map every SB/GSD/superpowers primitive to a Forge equivalent and document in `docs/mapping-table.md`:
- `Skill` tool invocation → trigger keywords in `.forge/skills/*/SKILL.md` YAML frontmatter
- `TodoWrite` → session log checkboxes (`docs/sessions/YYYY-MM-DD.md`)
- `AskUserQuestion` → inline prose questions in skill bodies
- PreToolUse/PostToolUse hooks → AGENTS.md standing instructions
- SessionStart hooks → AGENTS.md `## On Session Start` section
- Plugin MANIFEST.json → `forge-sb-install.sh` bootstrap script

### Phase 2: GSD Workflow Skills (12 sub-commands)
Port each GSD command as a `.forge/skills/` SKILL.md:
`gsd-discuss`, `gsd-plan`, `gsd-execute`, `gsd-verify`, `gsd-ship`, `gsd-review`, `gsd-review-fix`, `gsd-secure`, `gsd-validate`, `gsd-intel`, `gsd-progress`, `gsd-brainstorm`

### Phase 3: Quality Dimension Skills (9 + master)
Each quality dimension as a standalone skill plus the `quality-gates` master that runs all 9 in sequence with auto-detection of design-time vs. pre-ship mode.

### Phase 4: Superpowers Dependencies (7 skills)
`tdd`, `brainstorming`, `writing-plans`, `requesting-code-review`, `receiving-code-review`, `finishing-branch`, `testing-anti-patterns`

### Phase 5: AGENTS.md Orchestration Layer
- `forge/AGENTS.md.template`: global cross-project instructions with SB session startup behavior, quality gate triggers, workflow routing table, TDD iron law, git conventions
- `forge/AGENTS.project.template`: project-level instructions with GSD phase loop and Forge output format expectations

### Phase 6: Silver Orchestrator Skills (6 skills)
`silver` (router), `silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-research`

### Phase 7: Installer
`forge-sb-install.sh`: idempotent, `--dry-run` flag, copies global skills to `~/forge/skills/`, creates project `.forge/skills/` with GSD skills, writes project `AGENTS.md` from template (never overwrites existing)

### Phase 8: Tests & Docs
`tests/smoke-test.sh`: verify all skills installed, YAML frontmatter valid, no Claude Code tool names, trigger keywords present. `docs/forge-sb-README.md` and `docs/mapping-table.md`.

## Technical Constraints

All SKILL.md files must conform to Forge-compatible format:
- YAML frontmatter with: `id`, `title`, `description`, `trigger` (string or array of strings)
- Body: imperative prose only
- **No Claude Code tool names**: `Write` → "write file", `Bash` → "run command", `TodoWrite` → session log checkboxes, `AskUserQuestion` → inline prose question
- No plugin-system references (`Skill` tool, `MANIFEST.json`, etc.)
- Skill body ≤ 2000 tokens (Forge context budget)
- AGENTS.md ≤ 200 lines (Forge truncates beyond this in many contexts)

## Definition of Done

- [ ] All 33+ SKILL.md files exist at `forge/skills/*/SKILL.md`
- [ ] All SKILL.md files pass YAML frontmatter validation (`id`, `title`, `description`, `trigger` present)
- [ ] Zero Claude Code tool names in any SKILL.md (`TodoWrite`, `AskUserQuestion`, `Skill`, `NotebookEdit`)
- [ ] `forge-sb-install.sh --dry-run` runs without error and lists all files it would create
- [ ] `tests/smoke-test.sh` passes: all skills installed, all have trigger keywords, none have CC tool names
- [ ] A sample feature workflow triggered by "silver feature add logging" produces: BRAINSTORM.md, PLAN.md, implementation commits, VERIFICATION.md
- [ ] All commits DCO signed: `Signed-off-by: Shafqat Ullah <shafqat@sourcevo.com>`

## Labels

`enhancement`, `forge`, `cross-platform`, `workflow`
