# Requirements: Silver Bullet v0.9.0

**Defined:** 2026-04-05
**Core Value:** Complete orchestration layer that owns the user experience, delegates execution to GSD, and guides users through 100% of the SDLC with zero prior tool knowledge.

## v1 Requirements

### Orchestration Guides (ORCH)

- [ ] **ORCH-01**: Workflow file (full-dev-cycle.md) explains every GSD step with user-facing context — what it does, what to expect, what to do if it fails
- [ ] **ORCH-02**: Workflow file (devops-cycle.md) provides the same comprehensive orchestration treatment for DevOps workflows
- [ ] **ORCH-03**: Workflow files cover all 20 guided GSD commands at appropriate points (new-project, discuss, plan, execute, verify, ship, debug, quick, fast, resume-work, pause-work, progress, next, add-phase, insert-phase, review, autonomous, complete-milestone, audit-milestone, map-codebase)
- [ ] **ORCH-04**: Each per-phase step (DISCUSS → QUALITY GATES → PLAN → EXECUTE → VERIFY → REVIEW) includes error recovery instructions (what to do when the step fails)
- [ ] **ORCH-05**: Utility commands (/gsd:debug, /gsd:quick, /gsd:resume-work, etc.) are documented with "when to use" guidance in the workflow file
- [ ] **ORCH-06**: Non-GSD skills are inserted at specific workflow points with clear trigger conditions (e.g., "if UI work → /design-system + /ux-copy + /accessibility-review")

### Instruction Overhaul (INST)

- [x] **INST-01**: silver-bullet.md contains GSD process knowledge — Claude understands what each GSD step does without reading GSD's own docs
- [x] **INST-02**: silver-bullet.md includes hand-holding instructions — what Claude should say/show the user at each workflow transition
- [x] **INST-03**: silver-bullet.md includes utility command awareness — when to suggest /gsd:debug, /gsd:quick, etc. based on context
- [x] **INST-04**: All existing enforcement rules (§0-§9) remain intact and functional in the restructured silver-bullet.md

### Deduplication (DEDUP)

- [ ] **DEDUP-01**: SB forensics skill routes to /gsd:forensics for GSD-workflow-level issues (plan drift, execution anomalies, stuck loops)
- [ ] **DEDUP-02**: SB forensics retains session-level investigation capabilities (timeout, stall, SB enforcement failures) that GSD forensics does not cover
- [ ] **DEDUP-03**: No SB skill reimplements a GSD capability ��� zero redundant implementations

### Transition (TRANS)

- [ ] **TRANS-01**: After full-dev-cycle release step, SB detects when infrastructure work is needed and offers to switch to devops-cycle
- [ ] **TRANS-02**: After devops-cycle completes, SB offers to switch back to full-dev-cycle for the next milestone
- [ ] **TRANS-03**: Workflow transitions preserve all project context (planning artifacts, state, config)

### Template Parity (TMPL)

- [ ] **TMPL-01**: docs/workflows/full-dev-cycle.md and templates/workflows/full-dev-cycle.md are byte-identical
- [ ] **TMPL-02**: docs/workflows/devops-cycle.md and templates/workflows/devops-cycle.md are byte-identical
- [ ] **TMPL-03**: silver-bullet.md structure matches templates/silver-bullet.md.base (with placeholder substitutions)

### Documentation (DOC)

- [ ] **DOC-01**: README.md reflects the new orchestration approach — users understand SB guides them through GSD without needing GSD knowledge
- [ ] **DOC-02**: Site pages (index.html, help pages, search.js) updated to reflect new workflow descriptions
- [ ] **DOC-03**: Existing enforcement hooks continue to fire correctly with the restructured workflow files

## Validated (from previous milestones)

- ✓ **SB-R1**: Separate silver-bullet.md from CLAUDE.md — v0.7.0
- ✓ 7-layer enforcement architecture — v0.7.0
- ✓ 8 quality dimension gates — v0.7.0
- ✓ full-dev-cycle / devops-cycle workflows — v0.7.0
- ✓ Pre-release quality gate §9 — v0.7.4
- ✓ 4 gap-filling skills as enforced gates — v0.8.0
- ✓ SENTINEL security hardening — v0.8.0

## v2 Requirements

### Advanced Orchestration

- **ORCH-V2-01**: SB auto-detects project type (greenfield vs brownfield) and routes to appropriate GSD initialization
- **ORCH-V2-02**: SB implements its own complete process steps replacing GSD/Superpowers (future vision per goal #7)
- **ORCH-V2-03**: SB installs required dependencies (CLIs, MCPs, skills) automatically when needed

### Operations

- **OPS-V2-01**: Post-deployment monitoring integration
- **OPS-V2-02**: Incident → postmortem → learning → backlog feedback loop
- **OPS-V2-03**: Cost tracking and budget enforcement

## Out of Scope

| Feature | Reason |
|---------|--------|
| Replacing GSD execution engine | GSD owns execution (goal #7 is future vision, not v0.9.0) |
| Guiding admin GSD commands (gsd-manager, gsd-settings, etc.) | Not part of SDLC workflow |
| Modifying GSD/Superpowers/Engineering/Design plugin files | §8 boundary — never modify third-party plugins |
| Automated dependency installation | v2 feature (ORCH-V2-03) |
| Post-deployment monitoring | v2 feature (OPS-V2-01) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORCH-01 | Phase 1 | Pending |
| ORCH-02 | Phase 1 | Pending |
| ORCH-03 | Phase 1 | Pending |
| ORCH-04 | Phase 1 | Pending |
| ORCH-05 | Phase 1 | Pending |
| ORCH-06 | Phase 1 | Pending |
| INST-01 | Phase 2 | Complete |
| INST-02 | Phase 2 | Complete |
| INST-03 | Phase 2 | Complete |
| INST-04 | Phase 2 | Complete |
| DEDUP-01 | Phase 3 | Pending |
| DEDUP-02 | Phase 3 | Pending |
| DEDUP-03 | Phase 3 | Pending |
| TRANS-01 | Phase 1 | Pending |
| TRANS-02 | Phase 1 | Pending |
| TRANS-03 | Phase 1 | Pending |
| TMPL-01 | Phase 4 | Pending |
| TMPL-02 | Phase 4 | Pending |
| TMPL-03 | Phase 4 | Pending |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 5 | Pending |
| DOC-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-05*
*Last updated: 2026-04-05 after milestone v0.9.0 initialization*
