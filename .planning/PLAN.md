# Silver Bullet for Forge — Implementation Plan

## Overview

Port the Silver Bullet development workflow system from Claude Code plugin format to Forge-native primitives:
- AGENTS.md files (global + project)
- `.forge/skills/` SKILL.md files with YAML frontmatter trigger keywords

## Phases

### Phase 1: Branch + Smoke Test Stubs (RED)
- [x] Create feature branch `feat/forge-sb-native-port`
- [x] Create `tests/smoke-test.sh` with stub assertions
- [ ] Commit: `[RED] test(forge-sb): smoke tests — 33 skills + templates + installer (all stubs)`

### Phase 2: Directory Structure + Architecture Docs
- [ ] Create `forge/` directory with `forge/skills/` subdirectory
- [ ] Write `docs/mapping-table.md` with Claude Code → Forge primitive mapping
- [ ] Write `forge-sb-install.sh` skeleton with `--dry-run` flag
- [ ] Commit: `feat(forge-sb): Phase 1 — directory structure, mapping table, installer skeleton`

### Phase 3: GSD Workflow Skills (12 skills)
- [ ] gsd-discuss
- [ ] gsd-plan
- [ ] gsd-execute
- [ ] gsd-verify
- [ ] gsd-ship
- [ ] gsd-review
- [ ] gsd-review-fix
- [ ] gsd-secure
- [ ] gsd-validate
- [ ] gsd-intel
- [ ] gsd-progress
- [ ] gsd-brainstorm
- [ ] Commit: `feat(forge-sb): Phase 2 — GSD workflow skills (12 skills)`

### Phase 4: Quality Dimension Skills (9 + master)
- [ ] quality-gates (master)
- [ ] modularity
- [ ] reusability
- [ ] scalability
- [ ] security
- [ ] reliability
- [ ] usability
- [ ] testability
- [ ] extensibility
- [ ] ai-llm-safety
- [ ] Commit: `feat(forge-sb): Phase 3 — quality dimension skills (9 + master)`

### Phase 5: Superpowers Dependencies (7 skills)
- [ ] tdd
- [ ] brainstorming
- [ ] writing-plans
- [ ] requesting-code-review
- [ ] receiving-code-review
- [ ] finishing-branch
- [ ] Commit: `feat(forge-sb): Phase 4 — superpowers dependencies (7 skills)`

### Phase 6: AGENTS.md Templates
- [ ] forge/AGENTS.md.template (global)
- [ ] forge/AGENTS.project.template
- [ ] Commit: `feat(forge-sb): Phase 5 — AGENTS.md global and project templates`

### Phase 7: Silver Orchestrator Skills (6 skills)
- [ ] silver (router)
- [ ] silver-feature
- [ ] silver-bugfix
- [ ] silver-ui
- [ ] silver-devops
- [ ] silver-research
- [ ] Commit: `feat(forge-sb): Phase 6 — silver orchestrator skills (6 skills)`

### Phase 8: Final Assembly + GREEN
- [ ] Validate all skills
- [ ] Run smoke-test.sh — must pass
- [ ] Write docs/forge-sb-README.md
- [ ] Commit: `[GREEN] feat(forge-sb): all smoke tests pass — Silver Bullet for Forge complete`
- [ ] Push branch
- [ ] Create PR

## Success Criteria

- [ ] `tests/smoke-test.sh` exits 0 with "All smoke tests passed!"
- [ ] `forge-sb-install.sh --dry-run` runs without error
- [ ] All SKILL.md files have `id:`, `title:`, `description:`, `trigger:` in YAML frontmatter
- [ ] Zero occurrences of `TodoWrite`, `AskUserQuestion`, `NotebookEdit` in `forge/skills/`
- [ ] `forge/AGENTS.md.template` has all 7 sections
- [ ] `forge/AGENTS.md.template` is ≤ 200 lines
- [ ] All commits have DCO sign-off
- [ ] PR created against `alo-exp/silver-bullet` repo

## Quality Gates (9 Dimensions)

### 1. Modularity
- [ ] Each SKILL.md has one clear purpose
- [ ] No skill depends on another skill's internal state
- [ ] AGENTS.md sections are clearly separated

### 2. Reusability
- [ ] Quality dimension skills are usable standalone
- [ ] GSD skills work standalone and as steps
- [ ] No copy-paste content > 10 lines

### 3. Scalability
- [ ] Adding new skill = 1 new SKILL.md + 1 routing entry
- [ ] AGENTS.md stays ≤ 200 lines
- [ ] Skill bodies stay ≤ 2000 tokens

### 4. Security
- [ ] No skills write to credential stores
- [ ] Installer is idempotent
- [ ] No API keys in any SKILL.md or AGENTS.md

### 5. Reliability
- [ ] Every skill has defined trigger condition
- [ ] Every skill has defined exit condition
- [ ] Skills degrade gracefully if files are absent

### 6. Usability
- [ ] User can start workflow by typing trigger phrase
- [ ] Each skill provides progress signals
- [ ] Error messages tell user what to do

### 7. Testability
- [ ] smoke-test.sh verifies all skills installed
- [ ] Quality gate checklist items are binary

### 8. Extensibility
- [ ] New skill = create SKILL.md + no other changes
- [ ] Trigger keyword system is open

### 9. AI/LLM Safety
- [ ] AGENTS.md never instructs to skip security reviews
- [ ] TDD skill includes iron law verbatim
- [ ] No skill instructs to use `--no-verify`
