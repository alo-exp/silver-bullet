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
**Plans**: TBD

Plans:
- [ ] 01-01: TBD
- [ ] 01-02: TBD

### Phase 2: silver-bullet.md Overhaul
**Goal**: Claude has internalized GSD process knowledge within silver-bullet.md so it can guide users through workflow transitions, suggest appropriate utility commands, and explain what is happening -- all without reading GSD plugin files
**Depends on**: Phase 1
**Requirements**: INST-01, INST-02, INST-03, INST-04
**Success Criteria** (what must be TRUE):
  1. Claude can explain what any GSD workflow step does and why it matters, using only silver-bullet.md as reference (no dependency on GSD's own docs at runtime)
  2. At each workflow transition (e.g., DISCUSS to PLAN, EXECUTE to VERIFY), Claude proactively tells the user what just completed, what comes next, and what to watch for
  3. Claude suggests utility commands based on context -- /gsd:debug when execution fails, /gsd:quick for trivial changes, /gsd:resume-work after session breaks
  4. All existing enforcement rules (sections 0 through 9) remain intact and functional in the restructured file
**Plans**: 1 plan

Plans:
- [ ] 02-01-PLAN.md -- Add GSD process knowledge, hand-holding instructions, utility awareness, and workflow transition guidance to silver-bullet.md; sync template

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
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Workflow File Rewrites | 0/2 | Not started | - |
| 2. silver-bullet.md Overhaul | 0/1 | Planned | - |
| 3. Skill Evolution | 0/1 | Not started | - |
| 4. Template Parity & Hook Verification | 0/1 | Not started | - |
| 5. Documentation & Public-Facing | 0/1 | Not started | - |
| 6. Enforcement Techniques | 0/2 | Planned | - |
| 7. Close Enforcement Audit Gaps | 0/4 | Planned | - |

### Phase 6: Implement Enforcement Techniques from AI-Native SDLC Playbook

**Goal:** Add the 4 missing enforcement mechanisms identified in the gap analysis (Stop hook, UserPromptSubmit hook, compactPrompt override, hook self-protection) and create a comprehensive reference document for all enforcement mechanisms in Silver Bullet
**Requirements**: ENF-01, ENF-02, ENF-03, ENF-04, ENF-05, ENF-06
**Depends on:** Phase 5
**Plans:** 2 plans

Plans:
- [ ] 06-01-PLAN.md -- Create Stop hook, UserPromptSubmit hook, register in hooks.json, add compactPrompt to config template
- [ ] 06-02-PLAN.md -- Extend dev-cycle-check.sh hook self-protection, add tests for new hooks, create enforcement techniques reference doc

### Phase 7: Close All Enforcement Audit Gaps

**Goal:** Close all 16 actionable enforcement gaps (F-01, F-03 through F-20 excluding F-02/F-10/F-12/F-14) from the adversarial audit. Convert bypass paths to hard or soft enforcement with tests for all new hook scripts.
**Requirements**: ENF-F01, ENF-F03, ENF-F04, ENF-F05, ENF-F06, ENF-F07, ENF-F08, ENF-F09, ENF-F11, ENF-F13, ENF-F15, ENF-F16, ENF-F17, ENF-F18, ENF-F19, ENF-F20, ENF-TESTS
**Depends on:** Phase 6
**Plans:** 4 plans

Plans:
- [ ] 07-01-PLAN.md -- New forbidden-skill-check.sh hook, SubagentStop registration, stop-check.sh quality-gate-stage check, completion-audit.sh gh pr merge, ci-status-check.sh extended patterns
- [ ] 07-02-PLAN.md -- dev-cycle-check.sh hardening: plugin cache Bash check, scripting language bypass, branch mismatch warning, generalized tamper regex, destructive command warning
- [ ] 07-03-PLAN.md -- Stage falsification prevention, stage-after-workflow ordering, compliance-status.sh mtime cache, session-log-init.sh mode fix, src_pattern update
- [ ] 07-04-PLAN.md -- Review loop proxy enforcement (F-01), test suites for all new enforcement code
