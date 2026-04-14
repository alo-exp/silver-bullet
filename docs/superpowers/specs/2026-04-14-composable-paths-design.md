# Composable Paths Architecture — Design Specification

**Date:** 2026-04-14
**Status:** Draft
**Milestone:** v0.20.0 (proposed)

---

## 1. Problem Statement

Silver Bullet's current workflow architecture is a fixed sequential pipeline (`full-dev-cycle.md`) with conditional branches scattered throughout. This creates three problems:

1. **Skill islands** — installed skills (engineering:architecture, design:design-system, design:design-critique, design:design-handoff, gsd-ui-phase, gsd-ui-review) have no wiring into the workflow
2. **Missing brainstorm chain** — the exploration sequence (product-brainstorming → gsd-explore → brainstorming → discuss-phase) exists only in silver-brainstorm-idea, not in the per-phase loop
3. **Rigid composition** — every feature goes through the same loop regardless of whether it's UI-dominant, backend-only, infrastructure, or research

## 2. Solution: Dynamically Composable Paths

Replace the fixed pipeline with 17 composable paths that `/silver` dynamically chains based on context. Each path is a self-contained sequence of skill invocations with defined prerequisites, artifacts, and exit conditions.

### 2.1 Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Execution engine | GSD exclusively | All code-producing work through gsd-execute-phase. No Superpowers execution agents. |
| Composition state | WORKFLOW.md (persistent file) | Survives session breaks, hooks can read it, human-inspectable |
| Composition model | Hybrid — up-front proposal + dynamic insertion | User sees proposed chain, can adjust. Failures insert DEBUG dynamically. |
| Review reality-check | New artifact-review-assessor skill | Prevents over-zealous reviews; mirrors receiving-code-review for artifacts |
| Quality gates | Dual-mode (design-time + adversarial audit) | Same 9 skills, different depth depending on invocation point |
| Iteration termination | Claude-suggested, user-decided | No hard caps on recursion or iteration |
| Hook migration | Big-bang in Phase 6 | All hook changes applied atomically after all skills are ready |
| User migration | Explicit /silver:migrate | Infers WORKFLOW.md from existing artifacts + STATE.md |
| Anti-stall | 4-tier system | Progress-based + permission-stall + context exhaustion + heartbeat |
| silver-fast scope | Encompasses gsd-quick | Single entry for all sub-complex work with 3-tier triage |

### 2.2 GSD Compatibility Guarantees

The composable paths architecture preserves all 10 GSD execution assumptions:

| Assumption | Guarantee |
|---|---|
| Serial state reads | WORKFLOW.md is separate from STATE.md. No parallel STATE.md contention. |
| Artifact existence gates | Every path checks prerequisites on entry. WORKFLOW.md ordering ensures producers before consumers. |
| Blocking anti-patterns | PATH 5, PATH 7, and PATH 14 (when routing fixes through gsd-execute-phase --gaps-only) respect .continue-here.md checks. |
| Wave sequencing | PATH 7 delegates entirely to gsd-execute-phase. No external wave manipulation. |
| Worktree branch isolation | PATH 7 delegates worktree management to gsd-execute-phase. |
| State advance after completion | Only GSD skills write STATE.md (gsd-execute-phase advances position, gsd-new-project/gsd-ship/gsd-complete-milestone update status fields). No SB orchestration path writes STATE.md directly. |
| Gap closure sequencing | PATH 11 delegates to gsd-verify-work's internal diagnosis/planning/execution flow. |
| Context persistence | PATH 5 ensures discuss-phase reads prior CONTEXT.md files. |
| Subagent completion detection | All subagent spawning inside GSD workflows. SB invokes via Skill tool. |
| Commit atomicity | All commits inside GSD execution. No external commits except WORKFLOW.md tracking (docs-only). |

---

## 3. Path Contract Schema

Every path follows this contract:

```
PATH: {NAME}
  Prerequisites: [artifacts that MUST exist before this path runs]
  Trigger: [context signals that cause /silver to include this path]
  Steps: [ordered skill invocations — mandatory vs as-needed]
  Produces: [artifacts created/modified]
  Review Cycle: [artifact → reviewer → artifact-review-assessor → fix → 2-pass]
  GSD Impact: [which GSD state fields are read/written]
  Exit Condition: [what makes this path "complete"]
```

---

## 4. WORKFLOW.md Specification

**Location:** `.planning/WORKFLOW.md`
**Size cap:** 100 lines (per doc-scheme)
**Lifecycle:** Created by /silver composer, updated by supervision loop, archived on milestone completion

```markdown
# Workflow Manifest

## Composition
Intent: "{user's original request}"
Composed: {ISO timestamp}
Composer: /silver

## Path Log
| # | Path | Status | Artifacts Produced | Exit Condition Met |
|---|------|--------|-------------------|--------------------|
| 1 | BOOTSTRAP | complete | PROJECT.md, ROADMAP.md | Milestone scaffolded |
| 2 | ORIENT | complete | .planning/intel/* | Intel refreshed |
| 3 | PLAN | in progress | CONTEXT.md (written) | Awaiting PLAN.md |

## Phase Iterations
| Phase | Paths 5-13 Status |
|-------|-------------------|
| 01-auth | complete |
| 02-api | PATH 7 in progress |

## Dynamic Insertions
| After | Inserted | Reason |
|-------|----------|--------|

## Autonomous Decisions
| Timestamp | Decision | Rationale |
|-----------|----------|-----------|

## Deferred Improvements
| Source Path | Finding | Classification |
|-------------|---------|----------------|

## Next Path
PLAN (step 6: gsd-plan-phase)
```

**GSD isolation rule:** GSD workflows never read WORKFLOW.md. SB orchestration never writes STATE.md **directly** — it does so indirectly by invoking GSD skills (gsd-new-project, gsd-ship, gsd-complete-milestone) which manage STATE.md internally. The only bridge is /silver:migrate which reads STATE.md to generate WORKFLOW.md.

---

## 5. The 17 Composable Paths

### PATH 0: BOOTSTRAP — Project/milestone lifecycle

| | |
|---|---|
| Prerequisites | None (entry point) |
| Trigger | No .planning/ exists, OR prior milestone complete, OR user says "new project/milestone" |
| GSD Impact | Reads: nothing. Writes: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md (all via GSD internally) |
| Exit Condition | STATE.md exists with valid Current Position |

| Step | Skill | When |
|---|---|---|
| 1 | episodic-memory:remembering-conversations | Always |
| 2 | gsd-new-project | As-needed — no .planning/ exists |
| 3 | gsd-map-codebase | As-needed — codebase exists, no .planning/ |
| 4 | gsd-new-milestone | As-needed — prior milestone complete |
| 5 | gsd-resume-work | As-needed — continuing prior session |
| 6 | gsd-progress | As-needed — check current state |

Review cycle: ROADMAP.md → review-roadmap → artifact-review-assessor → 2-pass; REQUIREMENTS.md → review-requirements → artifact-review-assessor → 2-pass

### PATH 1: ORIENT — Codebase awareness

| | |
|---|---|
| Prerequisites | PATH 0 completed (STATE.md exists) |
| Trigger | Always included for non-trivial work |
| GSD Impact | None |
| Exit Condition | Intel files exist or scan complete |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-intel | Always |
| 2 | gsd-scan | As-needed — brownfield, no intel files |
| 3 | gsd-map-codebase | As-needed — first time, deep analysis |

No review cycle.

### PATH 2: EXPLORE — Problem space understanding

| | |
|---|---|
| Prerequisites | PATH 1 completed |
| Trigger | Fuzzy intent, unclear scope, user uncertainty, OR always for complex work |
| GSD Impact | None |
| Exit Condition | Problem space clarified, scope boundaries established. Verification: the next path (IDEATE or SPECIFY) can begin without Claude asking "what are we building?" — if the next path's first step immediately requests problem clarification, EXPLORE did not complete. In autonomous mode, supervision loop marks EXPLORE complete when gsd-explore outputs a scope summary. |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-explore | Always |
| 2 | product-management:product-brainstorming | Always |
| 3 | design:user-research | As-needed — user-facing work |
| 4 | product-management:synthesize-research | As-needed — prior research exists |
| 5 | product-management:competitive-brief | As-needed — competitive landscape relevant |

No review cycle.

### PATH 3: IDEATE — Convergent ideation + structural shaping

| | |
|---|---|
| Prerequisites | PATH 2 completed |
| Trigger | Always for complex work; skipped for simple/clear-scope |
| GSD Impact | None |
| Exit Condition | Architectural direction chosen, design approach locked. Verification: at least one concrete output exists — ADR written, design-system tokens defined, system-design diagram produced, OR brainstorming spec doc committed. For simple ideation with no formal artifact, the supervision loop marks IDEATE complete when the next path (SPECIFY or PLAN) successfully consumes ideation decisions. |

| Step | Skill | When |
|---|---|---|
| 1 | superpowers:brainstorming | Always |
| 2 | engineering:architecture | As-needed — new service, cross-cutting concern, ADR-worthy |
| 3 | engineering:system-design | As-needed — new service boundary, major component |
| 4 | design:design-system | As-needed — UI phase, new component type |

No review cycle.

### PATH 4: SPECIFY — Requirements convergence

| | |
|---|---|
| Prerequisites | PATH 3 completed, OR user has external spec to ingest |
| Trigger | No SPEC.md exists, OR spec refresh needed, OR external artifacts to ingest |
| Skip condition | PATH 4 may be skipped ONLY when REQUIREMENTS.md already exists (produced by PATH 0 via gsd-new-project or gsd-new-milestone). If REQUIREMENTS.md does not exist and PATH 4 is excluded from composition, the composer MUST insert it — REQUIREMENTS.md is a hard prerequisite for PATH 5 (PLAN). |
| GSD Impact | None — SPEC.md/REQUIREMENTS.md are SB artifacts |
| Exit Condition | SPEC.md + REQUIREMENTS.md exist, silver-validate shows zero BLOCK findings |

| Step | Skill | When |
|---|---|---|
| 1 | silver-ingest | As-needed — JIRA/Figma/Google Docs |
| 2 | product-management:write-spec | As-needed — scaffold |
| 3 | silver-spec | Always — Socratic elicitation |
| 4 | silver-validate | Always — gap analysis |

Review cycle: SPEC.md → review-spec → artifact-review-assessor → 2-pass; REQUIREMENTS.md → review-requirements → artifact-review-assessor → 2-pass; DESIGN.md → review-design → artifact-review-assessor → 2-pass (if exists); INGESTION_MANIFEST.md → review-ingestion-manifest → artifact-review-assessor → 2-pass (if ingest)

### PATH 5: PLAN — Execution planning

| | |
|---|---|
| Prerequisites | ROADMAP.md exists, REQUIREMENTS.md exists, phase directory exists |
| Trigger | Always for every phase |
| GSD Impact | Reads: STATE.md, REQUIREMENTS.md, ROADMAP.md, PROJECT.md, prior CONTEXT.md, prior SUMMARY.md. Writes: CONTEXT.md, RESEARCH.md, PLAN.md (via GSD internally). Does NOT advance state position. |
| Exit Condition | PLAN.md exists with plan-checker PASS (2 consecutive clean passes) |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-discuss-phase | Always |
| 2 | superpowers:writing-plans | Always — spec-to-plan bridge |
| 3 | engineering:testing-strategy | Always |
| 4 | gsd-list-phase-assumptions | As-needed |
| 5 | gsd-analyze-dependencies | Always |
| 6 | gsd-plan-phase | Always |

Review cycle: CONTEXT.md → review-context → artifact-review-assessor → 2-pass; RESEARCH.md → review-research → artifact-review-assessor → 2-pass; PLAN.md → gsd-plan-checker → artifact-review-assessor → 2-pass (max 3 iterations)

### PATH 6: DESIGN CONTRACT — UI specification (iterative)

| | |
|---|---|
| Prerequisites | PATH 5 completed (PLAN.md exists) |
| Trigger | Phase involves UI (keywords, file types, DESIGN.md existence) |
| GSD Impact | gsd-ui-phase produces UI-SPEC.md, does not touch STATE.md |
| Exit Condition | UI-SPEC.md exists, user accepts design contract |

| Step | Skill | When |
|---|---|---|
| 1 | design:design-system | Always in this path |
| 2 | design:ux-copy | As-needed |
| 3 | gsd-ui-phase | Always in this path |
| 4 | design:accessibility-review | As-needed — WCAG 2.1 AA |

Iterative: User can loop steps 1-4. Claude suggests when solid; user decides exit.

### PATH 7: EXECUTE — GSD wave-based implementation

| | |
|---|---|
| Prerequisites | PLAN.md exists, STATE.md position matches phase |
| Trigger | Always |
| GSD Impact | Heavy — reads/writes STATE.md, ROADMAP.md, REQUIREMENTS.md. Advances state position. All 10 GSD assumptions apply. |
| Exit Condition | All PLAN.md files have SUMMARY.md, STATE.md advanced |

| Step | Skill | When |
|---|---|---|
| 1 | superpowers:test-driven-development | As-needed — implementation plans only |
| 2 | gsd-execute-phase OR gsd-autonomous | Always |
| 3 | context7-plugin:context7-mcp | Ambient — available during execution |

Failure path: Insert PATH 14 (DEBUG) dynamically.

### PATH 8: UI QUALITY — Post-execution visual/UX (iterative)

| | |
|---|---|
| Prerequisites | PATH 7 completed with UI deliverables |
| Trigger | PATH 6 was in composition, OR SUMMARY.md contains UI file types |
| GSD Impact | None. Fixes route through gsd-execute-phase --gaps-only |
| Exit Condition | UI-REVIEW.md with no critical findings, or user accepts |

| Step | Skill | When |
|---|---|---|
| 1 | design:design-critique | Always in this path |
| 2 | gsd-ui-review | Always in this path — 6-pillar audit |
| 3 | design:accessibility-review | Always in this path |

Review cycle: UI-REVIEW.md → artifact-review-assessor → fix critical via GSD → re-audit

### PATH 9: REVIEW — Code quality (three parallel layers)

| | |
|---|---|
| Prerequisites | PATH 7 completed |
| Trigger | Always for any composition with PATH 7 |
| GSD Impact | gsd-code-review produces REVIEW.md. gsd-code-review-fix applies fixes. Neither modifies STATE.md. |
| Exit Condition | 2 consecutive clean passes across all layers |

Three independent parallel layers:

| Layer | Review | Triage | Fix |
|---|---|---|---|
| A (automated) | gsd-code-review | superpowers:receiving-code-review | gsd-code-review-fix |
| B (re-review) | superpowers:requesting-code-review | superpowers:receiving-code-review | gsd-code-review-fix |
| C (engineering) | engineering:code-review | superpowers:receiving-code-review | gsd-code-review-fix |
| D (cross-AI, as-needed) | gsd-review --multi-ai | superpowers:receiving-code-review | gsd-code-review-fix |

Entire cycle iterates until 2 consecutive clean passes across all layers.

### PATH 10: SECURE — Security + hardening

| | |
|---|---|
| Prerequisites | PATH 9 completed |
| Trigger | Always — scope varies by project type |
| GSD Impact | gsd-secure-phase verifies threat mitigations. gsd-validate-phase fills gaps. Neither modifies STATE.md. |
| Exit Condition | Security findings resolved (2 consecutive clean passes), validation gaps filled |

| Step | Skill | When |
|---|---|---|
| 1 | security (SENTINEL) | As-needed — software is Claude/AI Plugin or Skill |
| 2 | gsd-secure-phase | Always |
| 3 | gsd-validate-phase | Always |
| 4 | ai-llm-safety | As-needed — LLM agents/prompts/AI content |

### PATH 11: VERIFY — Acceptance testing

| | |
|---|---|
| Prerequisites | PATH 7 completed (SUMMARY.md exists) |
| Trigger | Always — NON-SKIPPABLE |
| GSD Impact | Reads: STATE.md, SUMMARY.md. Writes: UAT.md, VERIFICATION.md. Does NOT advance position. Internal gap-closure flow. |
| Exit Condition | VERIFICATION.md with status: passed (2 consecutive clean passes) |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-verify-work | Always — NON-SKIPPABLE |
| 2 | gsd-add-tests | As-needed — coverage gaps |
| 3 | superpowers:verification-before-completion | Always |

Review cycle: UAT.md → review-uat → artifact-review-assessor → 2-pass

### PATH 12: QUALITY GATE — Dual-mode dimensional assessment

| | |
|---|---|
| Prerequisites | Pre-plan: CONTEXT.md exists. Pre-ship: PATH 11 completed. |
| Trigger | Always — appears TWICE (pre-plan + pre-ship) |
| GSD Impact | None |
| Exit Condition | All dimensions pass |

| Step | Skill | When |
|---|---|---|
| 1 | quality-gates (9 dimensions) | Standard projects |
| 1-alt | devops-quality-gates (7 dimensions) | IaC/infra |
| 2 | Individual dimension deep-dive | As-needed — specific failure |

Dual-mode: Pre-plan = design-time checklist. Pre-ship = adversarial audit. Each dimension skill detects mode from artifact context:

| Artifact state | Mode | Rationale |
|---|---|---|
| No PLAN.md in phase | Design-time checklist | Evaluating approach before planning |
| PLAN.md exists, no SUMMARY.md | Design-time checklist | Plan written but not executed — still design phase |
| SUMMARY.md + VERIFICATION.md exist | Adversarial audit | Implementation complete — stress-test the code |
| SUMMARY.md exists, no VERIFICATION.md | Adversarial audit | Executed but not yet verified — audit the implementation |

### PATH 13: SHIP — Delivery

| | |
|---|---|
| Prerequisites | PATH 12 pre-ship passed, PATH 11 completed, clean tree, feature branch |
| Trigger | Always |
| GSD Impact | gsd-ship reads STATE.md, creates PR, updates STATE.md (Status, Last Activity) |
| Exit Condition | PR created, CI green |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-pr-branch | As-needed |
| 2 | engineering:deploy-checklist | As-needed — production |
| 3 | gsd-ship | Always |

### PATH 14: DEBUG — Failure recovery (dynamically insertable)

| | |
|---|---|
| Prerequisites | None — inserted on failure |
| Trigger | Execution failure, CI red, verification failure, unknown error |
| GSD Impact | None. Fixes route through gsd-execute-phase --gaps-only |
| Exit Condition | Root cause identified, fix plan validated |

| Step | Skill | When |
|---|---|---|
| 1 | superpowers:systematic-debugging | Always |
| 2 | gsd-debug | Always |
| 3 | engineering:debug | As-needed |
| 4 | forensics | As-needed — unknown root cause |
| 5 | gsd-forensics | As-needed — failed GSD workflow |
| 6 | engineering:incident-response | As-needed — production incident |

**Resume semantics after PATH 14 completes:**

1. Read WORKFLOW.md to identify which path was interrupted and at which step
2. If interrupted path was PATH 7 (EXECUTE): resume via `gsd-execute-phase --gaps-only` for the failed wave. Completed waves are not re-run (SUMMARY.md existence = wave done).
3. If interrupted path was PATH 11 (VERIFY): re-run gsd-verify-work from the beginning (UAT.md persists — only failed/pending tests re-run).
4. If interrupted path was PATH 9 (REVIEW) or PATH 10 (SECURE): re-run the interrupted path from step 1 (review/security cycles are idempotent).
5. If interrupted during any other path: re-run the interrupted path from step 1.
6. WORKFLOW.md records: "PATH 14 complete — resumed {interrupted path} at {step}. Fix applied via {method}."
7. If PATH 14 cannot resolve (debug exhausted, user escalation needed): mark interrupted path as BLOCKED in WORKFLOW.md, surface to user with diagnosis summary.

### PATH 15: DESIGN HANDOFF — UI finalization

| | |
|---|---|
| Prerequisites | All UI phases verified |
| Trigger | Milestone has UI phases AND in release flow |
| GSD Impact | None |
| Exit Condition | Handoff package produced |

| Step | Skill | When |
|---|---|---|
| 1 | design:design-handoff | Always in this path |
| 2 | design:design-system | As-needed — final component inventory |

### PATH 16: DOCUMENT — Knowledge capture

| | |
|---|---|
| Prerequisites | PATH 13 completed |
| Trigger | Always post-ship |
| GSD Impact | gsd-docs-update verifies docs. Neither modifies STATE.md. |
| Exit Condition | docs/ updated, session log completed |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-docs-update | Always |
| 2 | engineering:documentation | Always |
| 3 | engineering:tech-debt | Always |
| 4 | gsd-milestone-summary | As-needed — milestone narrative |
| 5 | episodic-memory:remembering-conversations | Always |
| 6 | gsd-session-report | As-needed |

### PATH 17: RELEASE — Milestone publish

| | |
|---|---|
| Prerequisites | All phases shipped |
| Trigger | User signals milestone complete, or last phase shipped |
| GSD Impact | gsd-complete-milestone archives .planning/, resets STATE.md |
| Exit Condition | GitHub Release created, milestone archived |

| Step | Skill | When |
|---|---|---|
| 1 | gsd-audit-uat | Always |
| 2 | gsd-audit-milestone | Always |
| 3 | gsd-plan-milestone-gaps | As-needed — gaps found |
| 4 | create-release | Always |
| 5 | gsd-complete-milestone | Always |

PATH 15 (DESIGN HANDOFF) inserts between steps 2 and 3 if milestone has UI phases. Review cycle: cross-artifact review → artifact-review-assessor → fix → pass (before step 4). Gap closure recursion: Claude-suggested, user-decided depth.

---

## 6. artifact-review-assessor

**Purpose:** Reality-check artifact reviewer findings before fixing. Prevent over-zealous reviews from causing unnecessary work.

**Location:** `skills/artifact-review-assessor/SKILL.md`

**Invocation pattern:**
```
artifact-reviewer (path-specific) → artifact-review-assessor (triage) → fix MUST-FIX only → re-review → repeat until 2 clean passes
```

**Decision criteria — judges against artifact CONTRACT:**

| Classification | Criterion |
|---|---|
| MUST-FIX | Contract violation: required section missing, factual inconsistency, untraceable criterion, security/correctness issue |
| NICE-TO-HAVE | Genuine improvement: clarity, detail, structure — logged in WORKFLOW.md "Deferred Improvements" but does not block 2-pass gate |
| DISMISS | Extraneous: stylistic preference, "could be more detailed" without specific gap, contradicts locked CONTEXT.md decision, duplicate |

**Contract sources:**

| Artifact | Contract defined by |
|---|---|
| SPEC.md | silver-spec SKILL.md step 7 template |
| REQUIREMENTS.md | REQ-XX format rules in silver-spec SKILL.md step 8 |
| CONTEXT.md | Locked decisions format in gsd-discuss-phase workflow |
| PLAN.md | Wave structure + task format in gsd-plan-phase workflow |
| RESEARCH.md | Evidence + confidence format in gsd-phase-researcher agent |
| DESIGN.md | SB design template in silver-spec SKILL.md step 9 |
| UI-SPEC.md | Design contract format in gsd-ui-phase workflow |
| REVIEW.md | Code quality finding format in gsd-code-reviewer agent |
| UAT.md | Criterion + Result + Evidence format in gsd-verify-work workflow |
| INGESTION_MANIFEST.md | Source artifact listing in silver-ingest SKILL.md step 7 |
| SECURITY.md | Threat model format in gsd-secure-phase workflow |

**No review loop on the assessor itself.** Assessor triages once per reviewer invocation. Reviewer → assessor → fix → reviewer again (not assessor again).

---

## 7. /silver Composer

### 7.1 Composition Algorithm

```
1. CLASSIFY context:
   - Artifact existence (SPEC.md? DESIGN.md? .planning/? STATE.md?)
   - Work type (feature / UI / bug / infra / research / release / trivial)
   - Phase position (ideation / planning / execution / verification / shipping)
   - File types in scope

2. SELECT paths:
   Always (non-trivial): 0?, 1, 5, 7, 9, 10, 11, 12(x2), 13
   Conditional: 2, 3, 4, 6, 8, 15, 16, 17
   Dynamic: 14

3. ORDER (fixed sequence when present):
   0 → 1 → 2 → 3 → 4 → 12(pre-plan) → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12(pre-ship) → 13 → 16 → 17
   
   PATH 15 (DESIGN HANDOFF) is NOT in the per-phase sequence. It runs inside PATH 17 (RELEASE), between the milestone audit (step 2) and gap closure (step 3), only when the milestone contains UI phases. This avoids producing handoff packages for phases that might change during gap closure.

4. PROPOSE to user (or auto-confirm in autonomous mode)

5. Write WORKFLOW.md → begin execution
```

### 7.2 Composition Templates (shortcuts for common intents)

| Workflow | Composition |
|---|---|
| silver-feature | 0?→1→2→3→4?→12→5→7→9→10→11→12→13→16→17? |
| silver-ui | 0?→1→2→3→4?→12→5→6→7→8→9→10→11→12→13→15→16→17? |
| silver-bugfix | 0?→1→14→5(light)→7→9→10→11→12→13 |
| silver-devops | 1→12(devops-qg, pre-plan)→5→7→9→10(devops)→11→12(devops-qg, pre-ship)→13 |
| silver-research | 1→2→3 (terminal) |
| silver-fast | Bypasses composer → gsd-fast or gsd-quick |
| silver-release | 12(pre-ship, reads prior phase artifacts)→16→17(with PATH 15 inserted if UI) |

### 7.3 Supervision Loop

After each path completes:
1. READ WORKFLOW.md
2. VERIFY exit condition met
3. EVALUATE composition changes needed
4. STALL CHECK (4 tiers)
5. ADVANCE — update WORKFLOW.md, begin next path
6. REPORT progress

Loop until all paths complete or user stops.

**Autonomous mode:** Path proposals auto-confirmed, dynamic insertions auto-accepted, iteration decisions by Claude (logged in WORKFLOW.md "Autonomous Decisions"). Only stops for hard failures DEBUG can't resolve.

### 7.4 Anti-Stall (4 Tiers)

**Tier 1: Progress-based detection**
Track meaningful progress signals (file changes, artifacts, commits, skill recordings). Stall = 20+ tool calls with zero signals, or same error 3+ times, or edit-revert loop. Action: self-recovery attempt, then PATH 14, then escalate.

**Tier 2: Permission-stall prevention**
When bypass-permissions active: suppress all confirmations, pre-authorize known safe operations, skip unanswerable MCP confirmations (log + alternative approach), never stall waiting for input.

**Tier 3: Context exhaustion prevention**
At each path transition: if >70% context consumed → /compact → reload WORKFLOW.md → resume. If >85% mid-path → complete current step → compact → resume. WORKFLOW.md is the recovery mechanism.

**Tier 4: Heartbeat sentinel**
Background process checks WORKFLOW.md + .planning/ + git freshness every 60s. All three stale for 5 minutes → write alert → triggers Tier 1. Sentinel PID tracked, relaunched if dead.

---

## 8. silver-fast Redesign

Three-tier complexity triage:

**Tier 1: Trivial** (≤3 files, no logic/schema changes) → gsd-fast → verify → commit

**Tier 2: Medium** (clear scope, some planning) → gsd-quick with composed flags (--discuss, --research, --validate, --full) → verify → commit. Artifacts in .planning/quick/.

**Tier 3: Escalation** (scope grows beyond quick) → STOP → route to silver-feature (auto-escalate in autonomous mode)

No WORKFLOW.md. No supervision loop. No review cycles for Tier 1. Quick tasks are atomic and independent of composition system.

**Autonomous escalation target selection:** When scope expands in autonomous mode, silver-fast selects the escalation target by re-running /silver's classification logic against the expanded scope description. If the task involves UI file types → silver-ui. If infra/IaC → silver-devops. If bug symptoms → silver-bugfix. Default fallback → silver-feature. The chosen target is logged as an autonomous decision.

---

## 9. /silver:migrate

**Purpose:** Transition mid-milestone projects from legacy workflow to composable paths.

**Algorithm:**

1. SCAN: Read STATE.md (position, status), state file (skill markers), .planning/phases/ (artifact existence)
2. INFER: Map artifact existence to path completion (CONTEXT.md → PATH 5 step 1, PLAN.md → PATH 5 complete, SUMMARY.md → PATH 7 complete, etc.)
3. DETERMINE: Next path based on STATE.md status
4. PRESENT: Show inferred state, flag non-inferrable paths (EXPLORE, IDEATE — no artifacts)
5. CONFIRM: User validates → write WORKFLOW.md → supervision loop takes over

Edge cases: No .planning/ → "nothing to migrate"; milestone complete → "run /silver:release or /gsd:new-milestone"; conflicting signals → flag anomaly for user.

---

## 10. Hook Modifications (Phase 6 Big-Bang)

All changes applied atomically. Every modified hook has WORKFLOW.md-present and WORKFLOW.md-absent code paths. Legacy projects unaffected.

| Hook | Change | Impact |
|---|---|---|
| dev-cycle-check.sh | MODIFY — WORKFLOW.md path completion as alternative gate | Additive: new code path when WORKFLOW.md exists |
| completion-audit.sh | MODIFY — path-based completion check alongside skill markers | Additive: same two-tier structure, different evidence source |
| compliance-status.sh | ENHANCE — show path progress alongside skill count | Additive: additional output |
| prompt-reminder.sh | ENHANCE — include WORKFLOW.md position in context injection | Additive: critical for post-compact recovery |
| spec-floor-check.sh | REVIEW — downgrade to advisory when PATH 4 intentionally excluded | Behavior change only when WORKFLOW.md exists and PATH 4 absent |

**13 hooks preserved as-is:** session-start, record-skill.sh, ci-status-check.sh, forbidden-skill-check.sh, phase-archive.sh, pr-traceability.sh, session-log-init.sh, semantic-compress.sh, spec-session-record.sh, uat-gate.sh, timeout-check.sh, stop-check.sh, ensure-model-routing.sh

---

## 11. Documentation Scheme Alignment

### doc-scheme.md.base additions:

| Artifact | Layer | Description |
|---|---|---|
| WORKFLOW.md | .planning/ | Composition manifest: paths ran, artifacts produced, dynamic insertions |
| VALIDATION.md | .planning/ | Pre-build gap analysis findings (BLOCK/WARN/INFO) |
| UI-SPEC.md | .planning/phases/ | Design contract for UI phases (gsd-ui-phase) |
| UI-REVIEW.md | .planning/phases/ | 6-pillar visual audit results (gsd-ui-review) |
| SECURITY.md | .planning/phases/ | Threat model and mitigation verification (gsd-secure-phase) |

### New non-redundancy rule:

Rule 6: "WORKFLOW.md tracks composition state — STATE.md tracks GSD execution state. These are separate concerns. GSD never reads WORKFLOW.md; SB orchestration never writes STATE.md."

### Size cap addition:

WORKFLOW.md: 100 lines max.

---

## 12. Help Center + Homepage Updates

### Help Center pages:

| Page | Action |
|---|---|
| concepts/composable-paths.html | CREATE — 17 paths, contracts, triggers |
| concepts/artifact-review-assessor.html | CREATE — reality-check pattern |
| concepts/routing-logic.html | REWRITE — /silver as composer |
| concepts/verification.html | UPDATE — add assessor to review cycle |
| concepts/documentation.html | UPDATE — add WORKFLOW.md |
| workflows/index.html | REWRITE — composable, not fixed |
| workflows/silver-feature.html | REWRITE — path composition example |
| workflows/silver-ui.html | REWRITE — UI paths (6, 8, 15) |
| workflows/silver-bugfix.html | UPDATE — PATH 14 integration |
| workflows/silver-fast.html | REWRITE — gsd-quick integration |
| workflows/silver-devops.html | UPDATE — devops variant |
| workflows/silver-release.html | UPDATE — PATH 17 |
| workflows/silver-research.html | UPDATE — PATH 2+3 |
| reference/index.html | UPDATE — assessor, WORKFLOW.md, path contracts |
| search.js | UPDATE — index new pages |
| getting-started/index.html | UPDATE — composable approach |
| dev-workflow/index.html | UPDATE — align with paths |

### Homepage (site/index.html):

Update: title/meta tag counts, hero section, workflow section, feature cards, architecture visual. Reflect composable paths, dynamic composition, artifact-review-assessor.

---

## 13. 9-Phase Milestone

| Phase | Scope | Dependencies | Risk |
|---|---|---|---|
| 1: Foundation | Path contracts, WORKFLOW.md spec, artifact-review-assessor skill, doc-scheme | None | Low |
| 2: Core Paths | PATHs 0, 1, 5, 7, 11, 13 | Phase 1 | Medium |
| 3: Specialized Paths | PATHs 2, 3, 4, 6, 8, 15 | Phase 2 | Medium |
| 4: Cross-Cutting + Quality Gate Dual-Mode | PATHs 9, 10, 12, 14, 16, 17 + 9 dimension skills | Phases 2-3 | Medium-High |
| 5: Composer Redesign | /silver rewrite, supervision loop, anti-stall | Phases 1-4 | High |
| 6: Hook Alignment + silver:migrate | 5 hook changes, migrate skill | Phase 5 | High |
| 7: silver-fast Redesign | gsd-quick integration, 3-tier triage | Phase 5 | Low |
| 8: Documentation | silver-bullet.md, doc-scheme, ENFORCEMENT.md, full-dev-cycle.md | Phases 1-7 | Low |
| 9: Help Center + Homepage | ~15 HTML pages, search.js, meta tags | Phase 8 | Low |

**Implementation approach:** Forward-compatible building (Approach B). Phases 1-5 build skills designed for new system that also work under old hooks. Phase 6 big-bang updates hooks. Old hooks don't gate .md skill file edits.

**Dependency chain:** 1 → 2 → 3 → 4 → 5 → 6 → 7 (parallel with 8) → 8 → 9
