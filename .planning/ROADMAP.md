# Roadmap: Silver Bullet v0.9.0 -- GSD-Mainstay Retrofitting

## Overview

Transform Silver Bullet from an enforcement layer on top of GSD into a complete orchestration layer that owns the user experience. Workflow files become comprehensive guides covering 100% of the GSD process with user-facing explanations. silver-bullet.md gains GSD process knowledge so Claude can guide users without reading GSD docs. Forensics evolves to be GSD-aware. Templates and documentation reflect the new approach throughout.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Workflow File Rewrites** - Rewrite both workflow files as comprehensive orchestration guides covering all 20 guided GSD commands with error recovery, utility guidance, and dev-to-DevOps transition logic
- [ ] **Phase 2: silver-bullet.md Overhaul** - Add GSD process knowledge, hand-holding instructions, and utility command awareness to silver-bullet.md while preserving all enforcement rules
- [ ] **Phase 3: Skill Evolution** - Evolve SB forensics to route GSD-workflow issues to /gsd:forensics while retaining session-level capabilities; verify zero redundancy across all SB skills
- [ ] **Phase 4: Template Parity & Hook Verification** - Sync templates with updated workflow files and silver-bullet.md; verify all enforcement hooks fire correctly with restructured files
- [ ] **Phase 5: Documentation & Public-Facing** - Update README and site pages to reflect the new orchestration-first approach

## Phase Details

### Phase 1: Workflow File Rewrites
**Goal**: Users are guided through the entire SDLC by workflow files that explain every GSD step, handle errors, suggest utilities, integrate non-GSD skills, and manage dev-to-DevOps transitions
**Depends on**: Nothing (first phase)
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05, ORCH-06, TRANS-01, TRANS-02, TRANS-03
**Success Criteria** (what must be TRUE):
  1. User reading full-dev-cycle.md understands what each GSD step does, what to expect during execution, and what to do if it fails -- without consulting any GSD documentation
  2. User reading devops-cycle.md gets the same comprehensive treatment for infrastructure workflows
  3. All 20 guided GSD commands appear at their appropriate workflow points with context; utility commands (/gsd:debug, /gsd:quick, /gsd:resume-work, etc.) appear with "when to use" guidance
  4. After completing a release step, the workflow detects infrastructure needs and offers to switch between dev and DevOps cycles while preserving all planning artifacts
  5. Non-GSD skills (design-system, ux-copy, accessibility-review, etc.) are triggered at specific workflow points with clear conditions
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md -- Rewrite full-dev-cycle.md as comprehensive orchestration guide (wave 1)
- [ ] 01-02-PLAN.md -- Rewrite devops-cycle.md as comprehensive orchestration guide (wave 1)
- [ ] 01-03-PLAN.md -- Template parity: copy rewritten workflows to templates/ (wave 2)

### Phase 2: silver-bullet.md Overhaul
**Goal**: Claude has internalized GSD process knowledge within silver-bullet.md so it can guide users through workflow transitions, suggest appropriate utility commands, and explain what is happening -- all without reading GSD plugin files
**Depends on**: Phase 1
**Requirements**: INST-01, INST-02, INST-03, INST-04
**Success Criteria** (what must be TRUE):
  1. Claude can explain what any GSD workflow step does and why it matters, using only silver-bullet.md as reference (no dependency on GSD's own docs at runtime)
  2. At each workflow transition (e.g., DISCUSS to PLAN, EXECUTE to VERIFY), Claude proactively tells the user what just completed, what comes next, and what to watch for
  3. Claude suggests utility commands based on context -- /gsd:debug when execution fails, /gsd:quick for trivial changes, /gsd:resume-work after session breaks
  4. All existing enforcement rules (sections 0 through 9) remain intact and functional in the restructured file
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Skill Evolution
**Goal**: SB forensics becomes GSD-aware, routing workflow-level issues to GSD while retaining its unique session-level capabilities, with zero skill redundancy across the entire SB plugin
**Depends on**: Phase 2
**Requirements**: DEDUP-01, DEDUP-02, DEDUP-03
**Success Criteria** (what must be TRUE):
  1. When a user reports a workflow-level issue (plan drift, execution anomaly, stuck loop), SB forensics routes to /gsd:forensics with appropriate context
  2. SB forensics still handles session-level issues (timeout, stall, SB enforcement failures) that GSD forensics does not cover
  3. An audit of all SB skills confirms zero reimplementation of any GSD capability -- each SB skill either complements or orchestrates, never duplicates
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Template Parity & Hook Verification
**Goal**: All templates are synchronized with the rewritten source files, and every enforcement hook fires correctly with the restructured workflow files
**Depends on**: Phase 3
**Requirements**: TMPL-01, TMPL-02, TMPL-03, DOC-03
**Success Criteria** (what must be TRUE):
  1. docs/workflows/full-dev-cycle.md and templates/workflows/full-dev-cycle.md are byte-identical (verified by diff)
  2. docs/workflows/devops-cycle.md and templates/workflows/devops-cycle.md are byte-identical (verified by diff)
  3. silver-bullet.md structure matches templates/silver-bullet.md.base with only placeholder substitutions differing
  4. All 7 enforcement hooks fire correctly when tested against the restructured workflow files -- no hook fails due to changed section headers or reorganized content
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: Documentation & Public-Facing
**Goal**: README and site pages communicate the new orchestration-first approach so users understand SB guides them through GSD without needing any GSD knowledge
**Depends on**: Phase 4
**Requirements**: DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. A new user reading README.md understands that Silver Bullet provides complete SDLC guidance through GSD orchestration -- they do not need to learn GSD separately
  2. Site pages (index.html, help pages, search.js) reflect the updated workflow descriptions and orchestration terminology
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 05-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Workflow File Rewrites | 0/3 | Planned | - |
| 2. silver-bullet.md Overhaul | 0/1 | Not started | - |
| 3. Skill Evolution | 0/1 | Not started | - |
| 4. Template Parity & Hook Verification | 0/1 | Not started | - |
| 5. Documentation & Public-Facing | 0/1 | Not started | - |
