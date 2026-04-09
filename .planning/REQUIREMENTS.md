# Requirements: Silver Bullet v0.15.0

**Defined:** 2026-04-09
**Core Value:** Single enforced workflow — no artifact ships without structured quality validation

## v1 Requirements

Requirements for v0.15.0 milestone. Each maps to roadmap phases.

### Bug Fixes (carried from v0.14.0)

- [x] **BFIX-01**: Fix shell injection via unvalidated owner/repo in silver-ingest --source-url — validate against `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` before shell substitution
- [x] **BFIX-02**: Fix command injection via unescaped WARN findings in pr-traceability.sh heredoc — use `printf '%s'` instead of heredoc expansion for warn_items
- [x] **BFIX-03**: Fix Confluence failure path in silver-ingest to produce `[ARTIFACT MISSING: reason]` block instead of "note in Assumptions"
- [x] **BFIX-04**: Fix version mismatch block in silver-bullet.md.base §0/5.5 to show content diff (not just version numbers) when SPEC.main.md is stale

### Artifact Reviewer Framework

- [x] **ARFR-01**: A standard artifact reviewer interface is defined — each reviewer accepts an artifact path, validates against source inputs, and returns structured findings with severity (PASS / ISSUE) and finding descriptions
- [x] **ARFR-02**: The review round loop is implemented as a reusable mechanism — invoke reviewer, collect findings, if issues found → fix and re-review, continue until 2 consecutive clean passes
- [x] **ARFR-03**: Review round state is tracked per-artifact so partially completed rounds can be resumed across sessions
- [x] **ARFR-04**: Review round results are recorded in a `REVIEW-ROUNDS.md` artifact alongside the reviewed file for audit trail

### New Artifact Reviewers

- [x] **ARVW-01**: SPEC.md reviewer — validates completeness (all required sections present), assumption density (minimum threshold), acceptance criteria testability, user story format, and consistency with source inputs (JIRA ticket, Figma, Google Docs)
- [x] **ARVW-02**: DESIGN.md reviewer — validates screen/component/behavior/state coverage, consistency with SPEC.md user stories, no orphaned components, interaction flows complete
- [x] **ARVW-03**: REQUIREMENTS.md reviewer — validates REQ-ID format, uniqueness, testability, categorization, no duplicate requirements, traceability section populated
- [x] **ARVW-04**: ROADMAP.md reviewer — validates 100% requirement coverage, phase dependency correctness, success criteria derivation from requirements, no orphaned requirements
- [x] **ARVW-05**: CONTEXT.md reviewer — validates all gray areas have decisions (locked or Claude's discretion), decisions are specific not vague, no contradictions between decisions
- [x] **ARVW-06**: RESEARCH.md reviewer — validates research addresses the phase's key questions, findings are evidence-based not speculative, confidence levels are justified, pitfalls are actionable
- [x] **ARVW-07**: INGESTION_MANIFEST.md reviewer — validates all source artifacts accounted for, statuses are accurate (not falsely reporting success), failed artifacts have corresponding [ARTIFACT MISSING] blocks in SPEC.md
- [x] **ARVW-08**: UAT.md reviewer — validates every acceptance criterion from SPEC.md has a UAT row, pass/fail evidence is substantive (not "looks good"), spec-version matches

### Existing Reviewer Formalization

- [x] **EXRV-01**: plan-checker (gsd-plan-checker) is wired into the 2-consecutive-pass framework — plan-phase workflow invokes it iteratively until 2 clean passes, not just once
- [x] **EXRV-02**: code-reviewer (gsd-code-reviewer) is wired into the 2-consecutive-pass framework — execute-phase workflow invokes it iteratively with fix rounds between passes
- [x] **EXRV-03**: verifier (gsd-verifier) is wired into the 2-consecutive-pass framework — verification runs twice consecutively, second pass confirms first pass's results
- [x] **EXRV-04**: security-auditor (gsd-security-auditor) is wired into the 2-consecutive-pass framework — security audit runs twice, second pass validates mitigations from first

### Workflow Integration

- [x] **WFIN-01**: silver-spec workflow invokes SPEC.md reviewer after Step 7 (SPEC.md write) — step does not complete until 2 consecutive clean passes
- [x] **WFIN-02**: silver-spec workflow invokes DESIGN.md reviewer after Step 8 (DESIGN.md write) — step does not complete until 2 consecutive clean passes
- [x] **WFIN-03**: silver-spec workflow invokes REQUIREMENTS.md reviewer after Step 9 (REQUIREMENTS.md write) — step does not complete until 2 consecutive clean passes
- [x] **WFIN-04**: new-milestone workflow invokes ROADMAP.md reviewer after roadmapper completes — roadmap not approved until 2 consecutive clean passes
- [x] **WFIN-05**: new-milestone workflow invokes REQUIREMENTS.md reviewer after requirements definition — requirements not committed until 2 consecutive clean passes
- [x] **WFIN-06**: discuss-phase workflow invokes CONTEXT.md reviewer after context capture — context not committed until 2 consecutive clean passes
- [x] **WFIN-07**: plan-phase workflow invokes RESEARCH.md reviewer after researcher completes — research not committed until 2 consecutive clean passes
- [x] **WFIN-08**: silver-ingest workflow invokes INGESTION_MANIFEST.md reviewer after Step 7 — manifest not committed until 2 consecutive clean passes
- [x] **WFIN-09**: silver-feature Step 17.0 invokes UAT.md reviewer after UAT generation — UAT not committed until 2 consecutive clean passes
- [x] **WFIN-10**: §3a updated with complete artifact-reviewer mapping table covering all 12+ artifact types

## Validated (from previous milestones)

- ✓ 7-layer enforcement architecture — v0.7.0
- ✓ 8 quality dimension gates — v0.7.0
- ✓ full-dev-cycle / devops-cycle workflows — v0.7.0
- ✓ SENTINEL security hardening — v0.8.0
- ✓ GSD-mainstay orchestration — v0.13.0
- ✓ AI-driven spec creation, ingestion, validation — v0.14.0
- ✓ Spec floor, PR traceability, UAT gate — v0.14.0
- ✓ Step non-skip enforcement §3/§3a/§3d — v0.14.0

## v2 Requirements

Deferred to future release.

### Advanced Review

- **ARVW-09**: Cross-artifact consistency reviewer — validates SPEC.md ↔ DESIGN.md ↔ REQUIREMENTS.md are mutually consistent
- **ARVW-10**: Review round analytics — track review round counts, common finding patterns, time-to-clean-pass metrics
- **ARVW-11**: Configurable review depth (quick/standard/deep) per artifact type via .planning/config.json

## Out of Scope

| Feature | Reason |
|---------|--------|
| Modifying GSD plugin files | §8 plugin boundary — reviewers are SB skills, not GSD modifications |
| Replacing existing GSD plan-checker/code-reviewer | Formalize into framework, don't replace |
| Review rounds for non-artifact outputs (console output, git commits) | Artifacts only — measurable, file-based |
| Blocking on INFO-level findings | Only ISSUE-level blocks; INFO is advisory |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BFIX-01 | Phase 15 | Done |
| BFIX-02 | Phase 15 | Done |
| BFIX-03 | Phase 15 | Done |
| BFIX-04 | Phase 15 | Done |
| ARFR-01 | Phase 15 | Complete |
| ARFR-02 | Phase 15 | Complete |
| ARFR-03 | Phase 15 | Complete |
| ARFR-04 | Phase 15 | Complete |
| ARVW-01 | Phase 16 | Complete |
| ARVW-02 | Phase 16 | Complete |
| ARVW-03 | Phase 16 | Complete |
| ARVW-04 | Phase 16 | Complete |
| ARVW-05 | Phase 16 | Complete |
| ARVW-06 | Phase 16 | Complete |
| ARVW-07 | Phase 16 | Complete |
| ARVW-08 | Phase 16 | Complete |
| EXRV-01 | Phase 17 | Done |
| EXRV-02 | Phase 17 | Done |
| EXRV-03 | Phase 17 | Done |
| EXRV-04 | Phase 17 | Done |
| WFIN-01 | Phase 17 | Complete |
| WFIN-02 | Phase 17 | Complete |
| WFIN-03 | Phase 17 | Complete |
| WFIN-04 | Phase 17 | Complete |
| WFIN-05 | Phase 17 | Complete |
| WFIN-06 | Phase 17 | Complete |
| WFIN-07 | Phase 17 | Complete |
| WFIN-08 | Phase 17 | Complete |
| WFIN-09 | Phase 17 | Complete |
| WFIN-10 | Phase 17 | Done |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 after roadmap creation*
