# Roadmap: Silver Bullet

## Milestones

- :white_check_mark: **v0.9.0 GSD-Mainstay Retrofitting** - Phases 1-5 (shipped)
- :white_check_mark: **v0.11.0 Enforcement Hardening** - Phases 6-8 (shipped)
- :white_check_mark: **v0.13.0 Orchestration Skills** - Phases 9-11 (shipped)
- :white_check_mark: **v0.14.0 Spec-Driven Development** - Phases 12-14 (shipped)
- :white_check_mark: **v0.16.0 Artifact Review System** - Phases 15-20 (shipped)
- :construction: **v0.20.0 Composable Paths Architecture** - Phases 21-29 (in progress)

## Phases

<details>
<summary>Completed milestones (Phases 1-20) -- shipped through v0.19.1</summary>

- [x] **Phase 1: Workflow File Rewrites** - Rewrite both workflow files as comprehensive orchestration guides
- [x] **Phase 2: silver-bullet.md Overhaul** - Add GSD process knowledge and hand-holding instructions
- [x] **Phase 3: Skill Evolution** - Evolve SB forensics to be GSD-aware
- [x] **Phase 4: Template Parity & Hook Verification** - Sync templates, verify hooks
- [x] **Phase 5: Documentation & Public-Facing** - README and site pages update
- [x] **Phase 6: Enforcement Techniques** - 4 missing enforcement mechanisms
- [x] **Phase 7: Close Enforcement Audit Gaps** - 16 actionable gaps closed
- [x] **Phase 8: Enforcement Test Harness** - Automated integration tests
- [x] **Phase 9: Silver Bullet Core Improvements** - silver:init, GSD state delegation, guided UX
- [x] **Phase 10: SB Orchestration Skill Files** - 7 named orchestration skills
- [x] **Phase 11: Website Content Refresh** - v0.13.0 site update
- [x] **Phase 12: Spec Foundation** - Canonical SPEC.md, silver-spec, spec floor enforcement
- [x] **Phase 13: Ingestion & Multi-Repo** - JIRA/Figma/Google Docs ingestion, cross-repo specs
- [x] **Phase 14: Validation, Traceability & UAT Gate** - Pre-build validation, PR traceability, UAT gate
- [x] **Phase 15: Bug Fixes & Reviewer Framework** - v0.14.0 bug fixes, reviewer interface + 2-pass loop
- [x] **Phase 16: New Artifact Reviewers** - 8 dedicated reviewer skills
- [x] **Phase 17: Existing Reviewer Formalization & Workflow Wiring** - 2-pass upgrade, workflow integration
- [x] **Phase 18: Configurable Review Depth** - Per-artifact depth config (deep/standard/quick)
- [x] **Phase 19: Review Analytics** - Structured metrics + silver-review-stats
- [x] **Phase 20: Cross-Artifact Consistency** - Cross-artifact reviewer, milestone completion gate

</details>

### v0.20.0 Composable Paths Architecture

- [x] **Phase 21: Foundation** - Path contracts, WORKFLOW.md spec, artifact-review-assessor, doc-scheme update (completed 2026-04-14)
- [x] **Phase 22: Core Paths** - 6 essential paths every composition uses (BOOTSTRAP, ORIENT, PLAN, EXECUTE, VERIFY, SHIP) (completed 2026-04-14)
- [ ] **Phase 23: Specialized Paths** - 6 context-triggered paths (EXPLORE, IDEATE, SPECIFY, DESIGN CONTRACT, UI QUALITY, DESIGN HANDOFF)
- [ ] **Phase 24: Cross-Cutting Paths + Quality Gate Dual-Mode** - 7 cross-cutting paths plus dual-mode quality gates
- [x] **Phase 25: Composer Redesign** - /silver as composer with supervision loop, dynamic insertion, anti-stall (completed 2026-04-14)
- [x] **Phase 26: Hook Alignment + silver:migrate** - 5 hooks modified for WORKFLOW.md awareness plus migration skill (completed 2026-04-14)
- [ ] **Phase 27: silver-fast Redesign** - 3-tier complexity triage with gsd-quick flags and autonomous escalation
- [ ] **Phase 28: Documentation Update** - silver-bullet.md, doc-scheme, ENFORCEMENT.md, full-dev-cycle demotion
- [ ] **Phase 29: Help Center + Homepage** - Homepage refresh and help center rewrite for composable architecture

## Phase Details

### Phase 21: Foundation
**Goal**: All building blocks exist for composable paths -- contracts defined, state tracking specified, review assessment available, artifact documentation updated
**Depends on**: Nothing (first phase of v0.20.0)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04
**Success Criteria** (what must be TRUE):
  1. Every composable path has a documented contract with prerequisites, trigger, steps, produces, review cycle, GSD impact, and exit condition
  2. WORKFLOW.md can be created and tracks path log, phase iterations, dynamic insertions, autonomous decisions, deferred improvements, and next path -- stays under 100 lines
  3. artifact-review-assessor skill triages reviewer findings into MUST-FIX / NICE-TO-HAVE / DISMISS based on artifact contract, with no review loop on itself
  4. doc-scheme.md.base includes WORKFLOW.md, VALIDATION.md, UI-SPEC.md, UI-REVIEW.md, SECURITY.md in artifact tables and enforces non-redundancy rule 6
**Plans**: 2 plans
Plans:
- [x] 21-01-PLAN.md — Path contracts summary + WORKFLOW.md template
- [x] 21-02-PLAN.md — artifact-review-assessor skill + doc-scheme update

### Phase 22: Core Paths
**Goal**: The 6 paths that form the backbone of every composition are implemented and can execute end-to-end
**Depends on**: Phase 21
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06
**Success Criteria** (what must be TRUE):
  1. PATH 0 (BOOTSTRAP) produces PROJECT.md + ROADMAP.md + REQUIREMENTS.md + STATE.md and includes episodic memory, new-project, map-codebase, new-milestone, resume-work, progress
  2. PATH 1 (ORIENT) runs gsd-intel, gsd-scan, gsd-map-codebase and requires PATH 0 completed
  3. PATH 5 (PLAN) produces CONTEXT.md + RESEARCH.md + PLAN.md using discuss-phase, writing-plans, testing-strategy, list-phase-assumptions, analyze-dependencies, gsd-plan-phase
  4. PATH 7 (EXECUTE) uses TDD as-needed and gsd-execute-phase/gsd-autonomous as sole execution engine with all 10 GSD assumptions preserved
  5. PATH 11 (VERIFY) and PATH 13 (SHIP) produce their expected artifacts and enforce non-skippable verification before shipping
**Plans**: 2 plans
Plans:
- [x] 22-01-PLAN.md — Restructure silver-feature with 6 core path sections
- [x] 22-02-PLAN.md — Restructure silver-bugfix with core path sections

### Phase 23: Specialized Paths
**Goal**: All 6 context-triggered paths are implemented -- each activates only when its trigger condition is met
**Depends on**: Phase 22
**Requirements**: SPEC-01, SPEC-02, SPEC-03, SPEC-04, SPEC-05, SPEC-06
**Success Criteria** (what must be TRUE):
  1. PATH 2 (EXPLORE) and PATH 3 (IDEATE) run their respective skill chains and produce research/design artifacts
  2. PATH 4 (SPECIFY) enforces skip condition (REQUIREMENTS.md must exist) and runs silver-ingest, write-spec, silver-spec, silver-validate
  3. PATH 6 (DESIGN CONTRACT) triggers on UI phase detection and runs design-system, ux-copy, gsd-ui-phase, accessibility-review iteratively
  4. PATH 8 (UI QUALITY) triggers from PATH 6 or UI file types in SUMMARY.md and runs design-critique, gsd-ui-review (6-pillar), accessibility-review
  5. PATH 15 (DESIGN HANDOFF) runs inside PATH 17 only, not in the per-phase sequence
**Plans**: 2 plans
Plans:
- [ ] 23-01-PLAN.md — Add PATHs 2, 3, 4, 6, 8 to silver-feature
- [ ] 23-02-PLAN.md — Add PATHs 6, 8 to silver-ui + PATH 15 to silver-release
**UI hint**: yes

### Phase 24: Cross-Cutting Paths + Quality Gate Dual-Mode
**Goal**: All cross-cutting paths that can insert at any point in a composition are implemented, and quality gates operate in dual mode
**Depends on**: Phase 23
**Requirements**: CROSS-01, CROSS-02, CROSS-03, CROSS-04, CROSS-05, CROSS-06, CROSS-07
**Success Criteria** (what must be TRUE):
  1. PATH 9 (REVIEW) runs three parallel review layers, each with triage + fix, iterating until 2 consecutive clean passes
  2. PATH 10 (SECURE) and PATH 12 (QUALITY GATE) operate correctly -- quality gate uses 4-state disambiguation table and appears twice in compositions
  3. PATH 14 (DEBUG) has resume semantics defined for all interrupted paths and chains debugging skills appropriately
  4. PATH 16 (DOCUMENT) and PATH 17 (RELEASE) complete their skill chains, with PATH 17 including the PATH 15 insertion point for UI milestones
  5. All 9 quality dimension skills operate in dual mode -- design-time checklist (pre-plan) and adversarial audit (pre-ship) with mode detected from artifact state
**Plans**: 2 plans
Plans:
- [ ] 24-01-PLAN.md — Add PATHs 9, 10, 12, 14, 16, 17 to silver-feature
- [ ] 24-02-PLAN.md — Quality gate dual-mode detection in quality-gates orchestrator

### Phase 25: Composer Redesign
**Goal**: /silver works as a composer -- classifying context, selecting and ordering paths, proposing compositions, supervising execution with anti-stall
**Depends on**: Phase 24
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04, COMP-05, COMP-06
**Success Criteria** (what must be TRUE):
  1. /silver classifies context, selects paths, orders chain, and proposes to user (or auto-confirms in autonomous mode)
  2. Composition templates exist for silver-feature, silver-ui, silver-bugfix, silver-devops, silver-research, silver-release as shortcut compositions
  3. End-to-end supervision loop works -- after each path: verify exit, evaluate composition changes, stall check, advance, report progress
  4. Dynamic insertion works -- PATH 14 inserted on failure, new paths inserted on context discovery, all recorded in WORKFLOW.md
  5. 4-tier anti-stall operates -- progress-based detection, permission-stall prevention, context exhaustion prevention, heartbeat sentinel
**Plans**: 2 plans
Plans:
- [x] 25-01-PLAN.md — Composition proposal + supervision loop + anti-stall in silver-feature + workflow.md.base heartbeat
- [x] 25-02-PLAN.md — Composition proposals in 5 remaining silver-* workflows + /silver router compatibility

### Phase 26: Hook Alignment + silver:migrate
**Goal**: All hooks are WORKFLOW.md-aware with legacy fallback, and existing mid-milestone users can migrate to composable paths
**Depends on**: Phase 25
**Requirements**: HOOK-01, HOOK-02, HOOK-03, HOOK-04, HOOK-05, HOOK-06
**Success Criteria** (what must be TRUE):
  1. dev-cycle-check.sh and completion-audit.sh use WORKFLOW.md path completion as primary gate, falling back to legacy markers when WORKFLOW.md absent
  2. compliance-status.sh shows path progress (PATH 5/12) alongside skill count, and prompt-reminder.sh includes WORKFLOW.md position for post-compact recovery
  3. spec-floor-check.sh downgrades to advisory when PATH 4 is intentionally excluded from composition
  4. silver:migrate scans STATE.md + artifacts, infers path completion, generates WORKFLOW.md, and user confirms before applying
**Plans**: 2 plans
Plans:
- [x] 26-01-PLAN.md — WORKFLOW.md awareness in 5 hook scripts with legacy fallback
- [x] 26-02-PLAN.md — silver:migrate skill with artifact-to-path inference

### Phase 27: silver-fast Redesign
**Goal**: silver-fast triages work into 3 complexity tiers with appropriate routing and autonomous escalation
**Depends on**: Phase 26
**Requirements**: FAST-01, FAST-02, FAST-03
**Success Criteria** (what must be TRUE):
  1. Trivial changes route to gsd-fast, medium changes route to gsd-quick with appropriate flags, complex changes escalate to silver-feature
  2. gsd-quick flag composition (--discuss, --research, --validate, --full) is selected based on detected need
  3. Autonomous escalation re-runs /silver classification against expanded scope when complexity exceeds silver-fast tier
**Plans**: 1 plan
Plans:
- [ ] 27-01-PLAN.md — Rewrite SKILL.md with 3-tier triage, gsd-quick flags, and autonomous escalation

### Phase 28: Documentation Update
**Goal**: All documentation reflects the composable paths architecture -- silver-bullet.md, doc-scheme, enforcement docs, and dev-cycle reference updated
**Depends on**: Phase 26
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. silver-bullet.md section 2h describes composable paths architecture instead of fixed pipeline
  2. doc-scheme.md.base is finalized with all new artifacts documented
  3. ENFORCEMENT.md reflects all hook modifications from Phase 26
  4. full-dev-cycle.md is demoted to example composition, not primary reference
**Plans**: 2 plans
Plans:
- [ ] 28-01-PLAN.md — silver-bullet.md §2h rewrite with composable paths architecture
- [ ] 28-02-PLAN.md — doc-scheme, ENFORCEMENT.md, full-dev-cycle.md updates

### Phase 29: Help Center + Homepage
**Goal**: Website and help center fully reflect composable paths architecture for new and existing users
**Depends on**: Phase 28
**Requirements**: SITE-01, SITE-02, SITE-03, SITE-04, SITE-05
**Success Criteria** (what must be TRUE):
  1. Homepage meta tags, hero section, workflow section, and feature cards reflect composable architecture
  2. Help center concept pages exist for composable-paths, artifact-review-assessor, routing-logic, verification, and documentation
  3. Help center workflow pages describe silver-feature, silver-ui, silver-fast as composable and silver-bugfix, silver-devops, silver-release, silver-research are updated
  4. Reference page documents assessor, WORKFLOW.md, path contracts, and search.js indexes all new pages
**Plans**: 2 plans
Plans:
- [ ] 29-01-PLAN.md — Homepage updates + help center concept pages (new and updated)
- [x] 29-02-PLAN.md — Workflow pages + reference page + search index updates
**UI hint**: yes

## Progress

**Execution Order:**
Phases 21 -> 22 -> 23 -> 24 -> 25 -> 26 -> 27 + 28 (parallel possible) -> 29

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-20 | v0.9.0-v0.16.0 | 46/46 | Complete | 2026-04-10 |
| 21. Foundation | v0.20.0 | 2/2 | Complete    | 2026-04-14 |
| 22. Core Paths | v0.20.0 | 2/2 | Complete    | 2026-04-14 |
| 23. Specialized Paths | v0.20.0 | 0/2 | Not started | - |
| 24. Cross-Cutting + Quality Gates | v0.20.0 | 0/2 | Not started | - |
| 25. Composer Redesign | v0.20.0 | 2/2 | Complete   | 2026-04-14 |
| 26. Hook Alignment + Migrate | v0.20.0 | 2/2 | Complete   | 2026-04-14 |
| 27. silver-fast Redesign | v0.20.0 | 0/1 | Not started | - |
| 28. Documentation Update | v0.20.0 | 0/2 | Not started | - |
| 29. Help Center + Homepage | v0.20.0 | 1/2 | In Progress|  |
