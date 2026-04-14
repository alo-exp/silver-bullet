# Composable Paths — Contract Reference

> Derived from [design spec](superpowers/specs/2026-04-14-composable-paths-design.md). The spec is the source of truth.

---

## Contract Schema

Every path contract contains these 7 required fields:

| Field | Description |
|-------|-------------|
| **Prerequisites** | Artifacts that MUST exist before this path runs |
| **Trigger** | Context signals that cause /silver to include this path |
| **Steps** | Ordered skill invocations — mandatory vs as-needed |
| **Produces** | Artifacts created or modified |
| **Review Cycle** | Artifact → reviewer → artifact-review-assessor → fix → 2-pass (or "None") |
| **GSD Impact** | Which GSD state fields are read/written |
| **Exit Condition** | What makes this path "complete" |

---

### PATH 0: BOOTSTRAP

| Field | Value |
|-------|-------|
| **Prerequisites** | None (entry point) |
| **Trigger** | No .planning/ exists, OR prior milestone complete, OR user says "new project/milestone" |
| **Steps** | 1. episodic-memory:remembering-conversations (Always) · 2. gsd-new-project (As-needed — no .planning/ exists) · 3. gsd-map-codebase (As-needed — codebase exists, no .planning/) · 4. gsd-new-milestone (As-needed — prior milestone complete) · 5. gsd-resume-work (As-needed — continuing prior session) · 6. gsd-progress (As-needed — check current state) |
| **Produces** | PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md |
| **Review Cycle** | ROADMAP.md → review-roadmap → artifact-review-assessor → 2-pass; REQUIREMENTS.md → review-requirements → artifact-review-assessor → 2-pass |
| **GSD Impact** | Reads: nothing. Writes: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md (all via GSD internally) |
| **Exit Condition** | STATE.md exists with valid Current Position |

---

### PATH 1: ORIENT

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 0 completed (STATE.md exists) |
| **Trigger** | Always included for non-trivial work |
| **Steps** | 1. gsd-intel (Always) · 2. gsd-scan (As-needed — brownfield, no intel files) · 3. gsd-map-codebase (As-needed — first time, deep analysis) |
| **Produces** | Intel files in .planning/intel/ |
| **Review Cycle** | None |
| **GSD Impact** | None |
| **Exit Condition** | Intel files exist or scan complete |

---

### PATH 2: EXPLORE

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 1 completed |
| **Trigger** | Fuzzy intent, unclear scope, user uncertainty, OR always for complex work |
| **Steps** | 1. gsd-explore (Always) · 2. product-management:product-brainstorming (Always) · 3. design:user-research (As-needed — user-facing work) · 4. product-management:synthesize-research (As-needed — prior research exists) · 5. product-management:competitive-brief (As-needed — competitive landscape relevant) |
| **Produces** | Scope summary, problem space documentation |
| **Review Cycle** | None |
| **GSD Impact** | None |
| **Exit Condition** | Problem space clarified, scope boundaries established |

---

### PATH 3: IDEATE

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 2 completed |
| **Trigger** | Always for complex work; skipped for simple/clear-scope |
| **Steps** | 1. superpowers:brainstorming (Always) · 2. engineering:architecture (As-needed — new service, cross-cutting concern, ADR-worthy) · 3. engineering:system-design (As-needed — new service boundary, major component) · 4. design:design-system (As-needed — UI phase, new component type) |
| **Produces** | ADR, design-system tokens, system-design diagram, or brainstorming spec doc |
| **Review Cycle** | None |
| **GSD Impact** | None |
| **Exit Condition** | Architectural direction chosen, design approach locked |

---

### PATH 4: SPECIFY

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 3 completed, OR user has external spec to ingest |
| **Trigger** | No SPEC.md exists, OR spec refresh needed, OR external artifacts to ingest. May be skipped ONLY when REQUIREMENTS.md already exists (from PATH 0). |
| **Steps** | 1. silver-ingest (As-needed — JIRA/Figma/Google Docs) · 2. product-management:write-spec (As-needed — scaffold) · 3. silver-spec (Always — Socratic elicitation) · 4. silver-validate (Always — gap analysis) |
| **Produces** | SPEC.md, REQUIREMENTS.md |
| **Review Cycle** | SPEC.md → review-spec → artifact-review-assessor → 2-pass; REQUIREMENTS.md → review-requirements → artifact-review-assessor → 2-pass; DESIGN.md → review-design → artifact-review-assessor → 2-pass (if exists); INGESTION_MANIFEST.md → review-ingestion-manifest → artifact-review-assessor → 2-pass (if ingest) |
| **GSD Impact** | None — SPEC.md/REQUIREMENTS.md are SB artifacts |
| **Exit Condition** | SPEC.md + REQUIREMENTS.md exist, silver-validate shows zero BLOCK findings |

---

### PATH 5: PLAN

| Field | Value |
|-------|-------|
| **Prerequisites** | ROADMAP.md exists, REQUIREMENTS.md exists, phase directory exists |
| **Trigger** | Always for every phase |
| **Steps** | 1. gsd-discuss-phase (Always) · 2. superpowers:writing-plans (Always — spec-to-plan bridge) · 3. engineering:testing-strategy (Always) · 4. gsd-list-phase-assumptions (As-needed) · 5. gsd-analyze-dependencies (Always) · 6. gsd-plan-phase (Always) |
| **Produces** | CONTEXT.md, RESEARCH.md, PLAN.md |
| **Review Cycle** | CONTEXT.md → review-context → artifact-review-assessor → 2-pass; RESEARCH.md → review-research → artifact-review-assessor → 2-pass; PLAN.md → gsd-plan-checker → artifact-review-assessor → 2-pass (max 3 iterations) |
| **GSD Impact** | Reads: STATE.md, REQUIREMENTS.md, ROADMAP.md, PROJECT.md, prior CONTEXT.md, prior SUMMARY.md. Writes: CONTEXT.md, RESEARCH.md, PLAN.md (via GSD internally). Does NOT advance state position. |
| **Exit Condition** | PLAN.md exists with plan-checker PASS (2 consecutive clean passes) |

---

### PATH 6: DESIGN CONTRACT

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 5 completed (PLAN.md exists) |
| **Trigger** | Phase involves UI (keywords, file types, DESIGN.md existence) |
| **Steps** | 1. design:design-system (Always in this path) · 2. design:ux-copy (As-needed) · 3. gsd-ui-phase (Always in this path) · 4. design:accessibility-review (As-needed — WCAG 2.1 AA) |
| **Produces** | UI-SPEC.md |
| **Review Cycle** | Iterative: user can loop steps 1-4. Claude suggests when solid; user decides exit. |
| **GSD Impact** | gsd-ui-phase produces UI-SPEC.md, does not touch STATE.md |
| **Exit Condition** | UI-SPEC.md exists, user accepts design contract |

---

### PATH 7: EXECUTE

| Field | Value |
|-------|-------|
| **Prerequisites** | PLAN.md exists, STATE.md position matches phase |
| **Trigger** | Always |
| **Steps** | 1. superpowers:test-driven-development (As-needed — implementation plans only) · 2. gsd-execute-phase OR gsd-autonomous (Always) · 3. context7-plugin:context7-mcp (Ambient — available during execution) |
| **Produces** | SUMMARY.md (per plan), code changes |
| **Review Cycle** | Failure path: Insert PATH 14 (DEBUG) dynamically |
| **GSD Impact** | Heavy — reads/writes STATE.md, ROADMAP.md, REQUIREMENTS.md. Advances state position. All 10 GSD assumptions apply. |
| **Exit Condition** | All PLAN.md files have SUMMARY.md, STATE.md advanced |

---

### PATH 8: UI QUALITY

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 7 completed with UI deliverables |
| **Trigger** | PATH 6 was in composition, OR SUMMARY.md contains UI file types |
| **Steps** | 1. design:design-critique (Always in this path) · 2. gsd-ui-review (Always in this path — 6-pillar audit) · 3. design:accessibility-review (Always in this path) |
| **Produces** | UI-REVIEW.md |
| **Review Cycle** | UI-REVIEW.md → artifact-review-assessor → fix critical via GSD → re-audit |
| **GSD Impact** | None. Fixes route through gsd-execute-phase --gaps-only |
| **Exit Condition** | UI-REVIEW.md with no critical findings, or user accepts |

---

### PATH 9: REVIEW

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 7 completed |
| **Trigger** | Always for any composition with PATH 7 |
| **Steps** | Layer A: gsd-code-review → superpowers:receiving-code-review → gsd-code-review-fix (automated). Layer B: superpowers:requesting-code-review → superpowers:receiving-code-review → gsd-code-review-fix (re-review). Layer C: engineering:code-review → superpowers:receiving-code-review → gsd-code-review-fix (engineering). Layer D (As-needed): gsd-review --multi-ai → superpowers:receiving-code-review → gsd-code-review-fix (cross-AI). |
| **Produces** | REVIEW.md |
| **Review Cycle** | Entire cycle iterates until 2 consecutive clean passes across all layers |
| **GSD Impact** | gsd-code-review produces REVIEW.md. gsd-code-review-fix applies fixes. Neither modifies STATE.md. |
| **Exit Condition** | 2 consecutive clean passes across all layers |

---

### PATH 10: SECURE

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 9 completed |
| **Trigger** | Always — scope varies by project type |
| **Steps** | 1. security (SENTINEL) (As-needed — software is Claude/AI Plugin or Skill) · 2. gsd-secure-phase (Always) · 3. gsd-validate-phase (Always) · 4. ai-llm-safety (As-needed — LLM agents/prompts/AI content) |
| **Produces** | SECURITY.md |
| **Review Cycle** | 2 consecutive clean passes |
| **GSD Impact** | gsd-secure-phase verifies threat mitigations. gsd-validate-phase fills gaps. Neither modifies STATE.md. |
| **Exit Condition** | Security findings resolved (2 consecutive clean passes), validation gaps filled |

---

### PATH 11: VERIFY

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 7 completed (SUMMARY.md exists) |
| **Trigger** | Always — NON-SKIPPABLE |
| **Steps** | 1. gsd-verify-work (Always — NON-SKIPPABLE) · 2. gsd-add-tests (As-needed — coverage gaps) · 3. superpowers:verification-before-completion (Always) |
| **Produces** | UAT.md, VERIFICATION.md |
| **Review Cycle** | UAT.md → review-uat → artifact-review-assessor → 2-pass |
| **GSD Impact** | Reads: STATE.md, SUMMARY.md. Writes: UAT.md, VERIFICATION.md. Does NOT advance position. Internal gap-closure flow. |
| **Exit Condition** | VERIFICATION.md with status: passed (2 consecutive clean passes) |

---

### PATH 12: QUALITY GATE

| Field | Value |
|-------|-------|
| **Prerequisites** | Pre-plan: CONTEXT.md exists. Pre-ship: PATH 11 completed. |
| **Trigger** | Always — appears TWICE (pre-plan + pre-ship) |
| **Steps** | 1. quality-gates (9 dimensions) for standard projects OR devops-quality-gates (7 dimensions) for IaC/infra · 2. Individual dimension deep-dive (As-needed — specific failure) |
| **Produces** | Quality assessment (design-time checklist pre-plan; adversarial audit pre-ship) |
| **Review Cycle** | None — gate itself is the review. All dimensions must pass. |
| **GSD Impact** | None |
| **Exit Condition** | All dimensions pass |

---

### PATH 13: SHIP

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 12 pre-ship passed, PATH 11 completed, clean tree, feature branch |
| **Trigger** | Always |
| **Steps** | 1. gsd-pr-branch (As-needed) · 2. engineering:deploy-checklist (As-needed — production) · 3. gsd-ship (Always) |
| **Produces** | PR |
| **Review Cycle** | None |
| **GSD Impact** | gsd-ship reads STATE.md, creates PR, updates STATE.md (Status, Last Activity) |
| **Exit Condition** | PR created, CI green |

---

### PATH 14: DEBUG

| Field | Value |
|-------|-------|
| **Prerequisites** | None — inserted on failure |
| **Trigger** | Execution failure, CI red, verification failure, unknown error |
| **Steps** | 1. superpowers:systematic-debugging (Always) · 2. gsd-debug (Always) · 3. engineering:debug (As-needed) · 4. forensics (As-needed — unknown root cause) · 5. gsd-forensics (As-needed — failed GSD workflow) · 6. engineering:incident-response (As-needed — production incident) |
| **Produces** | Fix plan, root cause analysis |
| **Review Cycle** | None |
| **GSD Impact** | None. Fixes route through gsd-execute-phase --gaps-only |
| **Exit Condition** | Root cause identified, fix plan validated |

---

### PATH 15: DESIGN HANDOFF

| Field | Value |
|-------|-------|
| **Prerequisites** | All UI phases verified |
| **Trigger** | Milestone has UI phases AND in release flow. Runs inside PATH 17 only (between milestone audit and gap closure — never in per-phase sequence). |
| **Steps** | 1. design:design-handoff (Always in this path) · 2. design:design-system (As-needed — final component inventory) |
| **Produces** | Handoff package |
| **Review Cycle** | None |
| **GSD Impact** | None |
| **Exit Condition** | Handoff package produced |

---

### PATH 16: DOCUMENT

| Field | Value |
|-------|-------|
| **Prerequisites** | PATH 13 completed |
| **Trigger** | Always post-ship |
| **Steps** | 1. gsd-docs-update (Always) · 2. engineering:documentation (Always) · 3. engineering:tech-debt (Always) · 4. gsd-milestone-summary (As-needed — milestone narrative) · 5. episodic-memory:remembering-conversations (Always) · 6. gsd-session-report (As-needed) |
| **Produces** | Updated docs/, session log |
| **Review Cycle** | None |
| **GSD Impact** | gsd-docs-update verifies docs. Neither modifies STATE.md. |
| **Exit Condition** | docs/ updated, session log completed |

---

### PATH 17: RELEASE

| Field | Value |
|-------|-------|
| **Prerequisites** | All phases shipped |
| **Trigger** | User signals milestone complete, or last phase shipped |
| **Steps** | 1. gsd-audit-uat (Always) · 2. gsd-audit-milestone (Always) · 3. PATH 15 DESIGN HANDOFF (As-needed — if milestone has UI phases, inserted here between steps 2 and 3) · 4. gsd-plan-milestone-gaps (As-needed — gaps found) · 5. create-release (Always) · 6. gsd-complete-milestone (Always) |
| **Produces** | GitHub Release, archived .planning/ |
| **Review Cycle** | Cross-artifact review → artifact-review-assessor → fix → pass (before create-release). Gap closure recursion: Claude-suggested, user-decided depth. |
| **GSD Impact** | gsd-complete-milestone archives .planning/, resets STATE.md |
| **Exit Condition** | GitHub Release created, milestone archived |

---

> This document is generated for quick reference. For full details including GSD compatibility guarantees, anti-stall tiers, and composition templates, see the design spec.
