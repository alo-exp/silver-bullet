# Requirements: Silver Bullet v0.20.0

**Defined:** 2026-04-14
**Core Value:** Single enforced workflow — no artifact ships without structured quality validation
**Design Spec:** docs/superpowers/specs/2026-04-14-composable-paths-design.md

## v1 Requirements

Requirements for v0.20.0 milestone. Each maps to roadmap phases.

### Foundation (CPA-01 through CPA-04)

- [ ] **FOUND-01**: Path contract schema defined — every composable path has prerequisites, trigger, steps, produces, review cycle, GSD impact, and exit condition documented
- [ ] **FOUND-02**: WORKFLOW.md specification implemented — persistent composition state file with path log, phase iterations, dynamic insertions, autonomous decisions, deferred improvements, and next path sections; 100-line size cap enforced
- [ ] **FOUND-03**: artifact-review-assessor skill created — triages reviewer findings into MUST-FIX / NICE-TO-HAVE / DISMISS based on artifact contract; no review loop on assessor itself
- [ ] **FOUND-04**: doc-scheme.md.base updated — WORKFLOW.md, VALIDATION.md, UI-SPEC.md, UI-REVIEW.md, SECURITY.md added to artifact tables; non-redundancy rule 6 added (WORKFLOW.md vs STATE.md separation)

### Core Paths (CPA-01)

- [ ] **CORE-01**: PATH 0 (BOOTSTRAP) implemented — episodic memory, new-project, map-codebase, new-milestone, resume-work, progress; produces PROJECT.md + ROADMAP.md + REQUIREMENTS.md + STATE.md
- [ ] **CORE-02**: PATH 1 (ORIENT) implemented — gsd-intel, gsd-scan, gsd-map-codebase; prerequisite: PATH 0 completed
- [ ] **CORE-03**: PATH 5 (PLAN) implemented — gsd-discuss-phase, writing-plans, testing-strategy, list-phase-assumptions, analyze-dependencies, gsd-plan-phase; produces CONTEXT.md + RESEARCH.md + PLAN.md
- [ ] **CORE-04**: PATH 7 (EXECUTE) implemented — TDD (as-needed), gsd-execute-phase/gsd-autonomous; sole execution engine, all 10 GSD assumptions preserved
- [ ] **CORE-05**: PATH 11 (VERIFY) implemented — gsd-verify-work (non-skippable), gsd-add-tests (as-needed), verification-before-completion; produces UAT.md + VERIFICATION.md
- [ ] **CORE-06**: PATH 13 (SHIP) implemented — gsd-pr-branch (as-needed), deploy-checklist (as-needed), gsd-ship; produces PR with CI verification

### Specialized Paths (CPA-01)

- [ ] **SPEC-01**: PATH 2 (EXPLORE) implemented — gsd-explore, product-brainstorming, user-research (as-needed), synthesize-research (as-needed), competitive-brief (as-needed)
- [ ] **SPEC-02**: PATH 3 (IDEATE) implemented — brainstorming, architecture (as-needed), system-design (as-needed), design-system (as-needed)
- [ ] **SPEC-03**: PATH 4 (SPECIFY) implemented — silver-ingest (as-needed), write-spec (as-needed), silver-spec, silver-validate; skip condition enforced (REQUIREMENTS.md must exist)
- [ ] **SPEC-04**: PATH 6 (DESIGN CONTRACT) implemented — design-system, ux-copy (as-needed), gsd-ui-phase, accessibility-review (as-needed); iterative; triggered by UI phase detection
- [ ] **SPEC-05**: PATH 8 (UI QUALITY) implemented — design-critique, gsd-ui-review (6-pillar), accessibility-review; triggered by PATH 6 or UI file types in SUMMARY.md
- [ ] **SPEC-06**: PATH 15 (DESIGN HANDOFF) implemented — design-handoff, design-system (as-needed); runs inside PATH 17 only

### Cross-Cutting Paths + Quality Gate Dual-Mode (CPA-01, CPA-06)

- [ ] **CROSS-01**: PATH 9 (REVIEW) implemented — three parallel layers (gsd-code-review, requesting-code-review, engineering:code-review), each with receiving-code-review triage + gsd-code-review-fix; iterates until 2 consecutive clean passes
- [ ] **CROSS-02**: PATH 10 (SECURE) implemented — security/SENTINEL (as-needed for AI plugins), gsd-secure-phase, gsd-validate-phase, ai-llm-safety (as-needed)
- [ ] **CROSS-03**: PATH 12 (QUALITY GATE) implemented — quality-gates (9 dims) or devops-quality-gates (7 dims); dual-mode with 4-state disambiguation table; appears twice in compositions
- [ ] **CROSS-04**: PATH 14 (DEBUG) implemented — systematic-debugging, gsd-debug, engineering:debug (as-needed), forensics (as-needed), gsd-forensics (as-needed), incident-response (as-needed); resume semantics defined for all interrupted paths
- [ ] **CROSS-05**: PATH 16 (DOCUMENT) implemented — gsd-docs-update, documentation, tech-debt, milestone-summary (as-needed), episodic-memory, session-report (as-needed)
- [ ] **CROSS-06**: PATH 17 (RELEASE) implemented — gsd-audit-uat, gsd-audit-milestone, gsd-plan-milestone-gaps (as-needed), create-release, gsd-complete-milestone; PATH 15 insertion point for UI milestones
- [ ] **CROSS-07**: All 9 quality dimension skills operate in dual mode — design-time checklist (pre-plan) + adversarial audit (pre-ship); mode detected from artifact state

### Composer Redesign (CPA-02, CPA-05)

- [ ] **COMP-01**: /silver redesigned from router to composer — classifies context, selects paths, orders chain, proposes to user (or auto-confirms in autonomous)
- [ ] **COMP-02**: Composition templates defined for all silver-* workflows — silver-feature, silver-ui, silver-bugfix, silver-devops, silver-research, silver-release as shortcut compositions
- [ ] **COMP-03**: End-to-end supervision loop — after each path: verify exit, evaluate composition changes, stall check, advance, report progress
- [ ] **COMP-04**: Dynamic insertion — PATH 14 inserted on failure; new paths inserted when context discovered mid-execution; recorded in WORKFLOW.md
- [ ] **COMP-05**: Per-phase looping — PATHs 5-13 repeat per phase with tracking in WORKFLOW.md Phase Iterations table
- [ ] **COMP-06**: 4-tier anti-stall — Tier 1 progress-based detection, Tier 2 permission-stall prevention, Tier 3 context exhaustion prevention, Tier 4 heartbeat sentinel

### Hook Alignment + silver:migrate (CPA-08, CPA-09)

- [ ] **HOOK-01**: dev-cycle-check.sh modified — WORKFLOW.md path completion as alternative gate (fallback to legacy markers when WORKFLOW.md absent)
- [ ] **HOOK-02**: completion-audit.sh modified — path-based completion check alongside skill markers
- [ ] **HOOK-03**: compliance-status.sh enhanced — shows path progress (PATH 5/12) alongside skill count
- [ ] **HOOK-04**: prompt-reminder.sh enhanced — includes WORKFLOW.md position in context injection for post-compact recovery
- [ ] **HOOK-05**: spec-floor-check.sh reviewed — downgrades to advisory when PATH 4 intentionally excluded from composition
- [ ] **HOOK-06**: silver:migrate skill created — scans STATE.md + artifacts, infers path completion, generates WORKFLOW.md, user confirms

### silver-fast Redesign (CPA-07)

- [ ] **FAST-01**: 3-tier complexity triage — trivial (gsd-fast) / medium (gsd-quick with flags) / escalation (route to silver-feature)
- [ ] **FAST-02**: gsd-quick flag composition — --discuss, --research, --validate, --full based on detected need
- [ ] **FAST-03**: Autonomous escalation target selection — re-runs /silver classification against expanded scope

### Documentation (CPA-10)

- [ ] **DOCS-01**: silver-bullet.md §2h updated — composable paths architecture replaces fixed pipeline
- [ ] **DOCS-02**: doc-scheme.md.base finalized — all new artifacts documented
- [ ] **DOCS-03**: ENFORCEMENT.md updated — reflects hook modifications
- [ ] **DOCS-04**: full-dev-cycle.md demoted — becomes example composition, not primary reference

### Help Center + Homepage (CPA-10)

- [ ] **SITE-01**: Homepage updated — meta tags, hero, workflow section, feature cards reflect composable architecture
- [ ] **SITE-02**: Help Center concept pages created/updated — composable-paths, artifact-review-assessor, routing-logic rewrite, verification update, documentation update
- [ ] **SITE-03**: Help Center workflow pages rewritten — silver-feature, silver-ui, silver-fast as composable; silver-bugfix, silver-devops, silver-release, silver-research updated
- [ ] **SITE-04**: Reference page updated — assessor, WORKFLOW.md, path contracts
- [ ] **SITE-05**: search.js updated — indexes new pages

## Future Requirements

- WORKFLOW.md visual dashboard (web-based composition progress viewer)
- Cross-AI composition (multi-model path execution)
- Composition templates marketplace (shareable path compositions)

## Out of Scope

- Modifying GSD plugin files — §8 boundary maintained
- Replacing GSD execution engine — GSD owns execution
- Custom path creation UI — paths defined in skill files
- Real-time collaboration (multi-user compositions)

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01..04 | Phase 1 | Pending |
| CORE-01..06 | Phase 2 | Pending |
| SPEC-01..06 | Phase 3 | Pending |
| CROSS-01..07 | Phase 4 | Pending |
| COMP-01..06 | Phase 5 | Pending |
| HOOK-01..06 | Phase 6 | Pending |
| FAST-01..03 | Phase 7 | Pending |
| DOCS-01..04 | Phase 8 | Pending |
| SITE-01..05 | Phase 9 | Pending |
