# Composable Flows — Contract Reference

This is the canonical contract reference for `/silver` dynamic composition.

SB composes flows. GSD owns the project lifecycle. Any semver-relevant change must pass through GSD milestone/phase management, planning, execution, verification, and release gates. FLOW 3's `silver:clarify` is the merged clarification front-end: it absorbs PM framing and Superpowers brainstorming non-redundantly before any GSD handoff.

## Naming And Availability

Contracts use logical skill names. At invocation time, use the host-exposed equivalent:

| Logical family | Examples | Notes |
|----------------|----------|-------|
| SB | `silver:feature`, `silver:quality-gates`, `verify-tests` | Codex exposes SB through the native `/Silver:` picker and `silver-bullet invoke-skill`; source dirs may use `silver-feature`. |
| GSD | `gsd:do`, `gsd:plan-phase`, `gsd:execute-phase` | Prefer `gsd:do` for freeform GSD delegation. Use exact GSD skill only when a flow contract names it. |
| Superpowers | SB wrapper skills such as `tdd`, `requesting-code-review`, and `receiving-code-review` | Required only when a selected SB flow marks them Always. |
| Product Management | `product-management:write-spec`, `product-management:competitive-brief` | Optional unless the flow says Always. |

Do not replace a missing Always dependency with ad hoc shell work. Stop, report the missing skill, and offer install-and-retry or an explicitly approved degraded path.

## Atomic Flow Catalog

Each workflow composes from these 18 atomic flows:

| Flow | Name | Primary Owner | Purpose |
|------|------|---------------|---------|
| FLOW 1 | BOOTSTRAP | GSD | Project/milestone setup |
| FLOW 2 | ORIENT | GSD/SB | Codebase and project-state orientation |
| FLOW 3 | CLARIFY | SB | Problem framing, scope boundaries, and a decision-ready brief |
| FLOW 4 | DECIDE | SB/GSD | Architecture, product, or technical choice |
| FLOW 5 | SPECIFY | SB/Product Management | SPEC.md and REQUIREMENTS.md creation/refinement |
| FLOW 6 | PLAN | GSD | Phase discussion, assumptions, dependency analysis, and plans |
| FLOW 7 | DESIGN CONTRACT | GSD/SB | UI/UX contract where UI scope exists |
| FLOW 8 | EXECUTE | GSD | Implementation through GSD execution |
| FLOW 9 | UI QUALITY | GSD/SB | UI-specific audit and gap closure |
| FLOW 10 | REVIEW | GSD/Superpowers | Code review, findings triage, and fixes |
| FLOW 11 | SECURE | GSD/SB | Security and safety verification |
| FLOW 12 | VERIFY | GSD | UAT, tests, and must-have verification |
| FLOW 13 | QUALITY GATE | SB | Cross-cutting quality dimensions |
| FLOW 14 | SHIP | GSD | Phase-level PR/CI/ship work |
| FLOW 15 | DEBUG | GSD/Superpowers/SB | Dynamic failure investigation |
| FLOW 16 | DESIGN HANDOFF | SB/optional design skills | Milestone-level UI handoff |
| FLOW 17 | DOCUMENT | GSD/SB | Durable docs and session knowledge |
| FLOW 18 | RELEASE | GSD/SB | Milestone audit, semver release, archive |

## Contract Schema

Every flow contract contains these required fields:

| Field | Description |
|-------|-------------|
| Prerequisites | Artifacts or state that must exist before this flow runs |
| Trigger | Context signals that cause `/silver` to include this flow |
| Steps | Ordered skill invocations, marked Always or As-needed |
| Produces | Artifacts created or modified |
| Review Cycle | Artifact review or fix loop required for this flow |
| GSD Impact | Which GSD-owned state/artifacts are read or written |
| Exit Condition | What makes this flow complete |

---

## FLOW 1: BOOTSTRAP

| Field | Value |
|-------|-------|
| Prerequisites | None |
| Trigger | No `.planning/`; new project; new milestone; prior milestone complete |
| Steps | 1. `gsd:new-project` (As-needed, no `.planning/`) · 2. `gsd:map-codebase` (As-needed, brownfield) · 3. `gsd:new-milestone` (As-needed, prior milestone complete) · 4. `gsd:resume-work` (As-needed, existing interrupted work) · 5. `gsd:progress` (As-needed, status check) |
| Produces | `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` |
| Review Cycle | ROADMAP and REQUIREMENTS review when created or substantially changed |
| GSD Impact | GSD writes all bootstrap artifacts |
| Exit Condition | `STATE.md` exists and identifies current milestone/phase state |

## FLOW 2: ORIENT

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 1 complete, or existing project artifacts present |
| Trigger | Included for non-trivial work unless current intel is already sufficient |
| Steps | 1. `gsd-scan` (As-needed, rapid codebase scan) · 2. `gsd:map-codebase` (As-needed, deeper brownfield mapping) · 3. `gsd:progress` (As-needed, current GSD position) |
| Produces | `.planning/intel/` or `.planning/codebase/` files when GSD mapping runs; scan summary when SB scan runs |
| Review Cycle | None |
| GSD Impact | Reads GSD state; writes only through GSD mapping skills |
| Exit Condition | Current codebase/project position is known well enough to choose the next flow |

## FLOW 3: CLARIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 1 complete for project work; none for pure ideation |
| Trigger | Fuzzy intent, unclear scope, complex work, new idea, user uncertainty |
| Steps | 1. `silver:clarify` (Always, merged PM framing + Superpowers brainstorming absorbed internally) · 2. `product-management:synthesize-research` (As-needed, prior research exists) · 3. `product-management:competitive-brief` (As-needed, market/competitive context needed) |
| Produces | Scope summary, assumptions, boundaries, PM framing when relevant, decision-ready brief |
| Review Cycle | None |
| GSD Impact | None directly; handoff feeds GSD discussion/planning |
| Exit Condition | Scope and next lifecycle route are explicit |

## FLOW 4: DECIDE

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 2 complete or a crisp decision question exists |
| Trigger | Architecture choice, stack selection, major tradeoff, API/data-model impact |
| Steps | 1. `silver:research` (Always for unknown/novel decisions) · 2. `gsd:spike` (As-needed, experimental proof) · 3. `gsd:discuss-phase` (As-needed, phase decision capture) |
| Produces | Research artifact, spike result, ADR-style decision summary, or locked decision in CONTEXT.md |
| Review Cycle | Research artifact review when used as implementation input |
| GSD Impact | GSD records phase decisions when `gsd:discuss-phase` runs |
| Exit Condition | A named option is selected with rationale and known risks |

## FLOW 5: SPECIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 3/4 complete, or external artifact exists to ingest |
| Trigger | Missing/stale SPEC.md, new requirements, external JIRA/Figma/Google Docs/cross-repo spec |
| Steps | 1. `silver:ingest` (As-needed) · 2. `product-management:write-spec` (As-needed scaffold) · 3. `silver:spec` (Always for human-facing spec elicitation) · 4. `silver:validate` (Always for gap analysis) |
| Produces | `.planning/SPEC.md`, `.planning/REQUIREMENTS.md`, optional `.planning/INGESTION_MANIFEST.md` |
| Review Cycle | SPEC, REQUIREMENTS, DESIGN, and INGESTION_MANIFEST review where present |
| GSD Impact | GSD consumes REQUIREMENTS/ROADMAP later; SB does not directly advance GSD state here |
| Exit Condition | Requirements are clear enough for GSD phase planning and no blocking validation gaps remain |

## FLOW 6: PLAN

| Field | Value |
|-------|-------|
| Prerequisites | ROADMAP and REQUIREMENTS exist; target phase exists |
| Trigger | Always before execution for non-trivial codebase work |
| Steps | 1. `gsd:discuss-phase` (Always) · 2. `writing-plans` (As-needed local bridge from spec/design to plan) · 3. `gsd:list-phase-assumptions` (As-needed) · 4. `gsd:analyze-dependencies` (As-needed/when available) · 5. `gsd:plan-phase` (Always) |
| Produces | Phase CONTEXT, RESEARCH, PLAN files |
| Review Cycle | CONTEXT/RESEARCH/PLAN review; plan-checker must pass for implementation work |
| GSD Impact | GSD reads/writes all planning artifacts and owns phase plan validity |
| Exit Condition | PLAN files exist for the current phase and are accepted for execution |

## FLOW 7: DESIGN CONTRACT

| Field | Value |
|-------|-------|
| Prerequisites | PLAN exists or UI scope is known enough to design |
| Trigger | UI/frontend/design scope, UI files, Figma/design artifact, accessibility-sensitive change |
| Steps | 1. `gsd:ui-phase` (Always when available) · 2. optional design-system/UX/accessibility skills (As-needed if installed) · 3. `silver:quality-gates` (As-needed pre-plan quality check) |
| Produces | UI-SPEC or equivalent design contract |
| Review Cycle | UI/design review when artifact exists |
| GSD Impact | `gsd:ui-phase` owns UI-SPEC creation |
| Exit Condition | UI contract exists or user explicitly accepts no-UI-contract rationale |

## FLOW 8: EXECUTE

| Field | Value |
|-------|-------|
| Prerequisites | PLAN exists; STATE position matches phase |
| Trigger | Always for implementation work |
| Steps | 1. `tdd` -> `superpowers:test-driven-development` (As-needed, behavior-changing implementation) · 2. `gsd:execute-phase` or `gsd:autonomous` (Always) |
| Produces | Code changes, task commits, SUMMARY files |
| Review Cycle | Insert FLOW 15 DEBUG on execution/test failure |
| GSD Impact | GSD reads/writes STATE, ROADMAP, plans, summaries, and commits |
| Exit Condition | All planned tasks complete and SUMMARY artifacts exist |

## FLOW 9: UI QUALITY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 7 complete with UI deliverables |
| Trigger | UI flow included, UI files changed, or SUMMARY references UI deliverables |
| Steps | 1. `gsd:ui-review` (Always when available) · 2. optional design critique/accessibility skills (As-needed if installed) |
| Produces | UI-REVIEW or equivalent findings |
| Review Cycle | Critical findings route to GSD gap closure and re-review |
| GSD Impact | Fixes route through `gsd:execute-phase --gaps-only` or GSD-created gap plans |
| Exit Condition | No blocking UI findings remain, or user accepts documented residual risk |

## FLOW 10: REVIEW

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 8 complete |
| Trigger | Always for implementation work |
| Steps | 1. `superpowers:requesting-code-review` (Always) · 2. `gsd:code-review` (Always) · 3. `gsd:code-review-fix` (As-needed) · 4. `superpowers:receiving-code-review` (Always when findings exist) · 5. `gsd:review` or cross-AI review (As-needed, architecturally significant changes) |
| Produces | REVIEW files and fix commits |
| Review Cycle | Iterate until required clean-pass threshold is met |
| GSD Impact | GSD review/fix skills own review artifacts and changes |
| Exit Condition | Review gate passes or accepted residual risks are captured |

## FLOW 11: SECURE

| Field | Value |
|-------|-------|
| Prerequisites | PLAN or implementation scope known |
| Trigger | Always for software changes; especially agents, hooks, prompts, infra, auth, data, release |
| Steps | 1. `security` (Always for SB/plugin/agent safety) · 2. `gsd:secure-phase` (Always for phase security) · 3. `gsd:validate-phase` (As-needed gap filling) · 4. `silver:ai-llm-safety` (As-needed LLM/agent behavior) |
| Produces | SECURITY and validation artifacts |
| Review Cycle | Security findings must be resolved or explicitly accepted before ship/release |
| GSD Impact | GSD secure/validate skills verify mitigations and create gap work |
| Exit Condition | No blocking security/validation findings remain |

## FLOW 12: VERIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 8 complete; SUMMARY exists |
| Trigger | Always; non-skippable |
| Steps | 1. `gsd:verify-work` (Always) · 2. `gsd:add-tests` (As-needed coverage gaps) · 3. `verify-tests` (As-needed fresh suite marker) · 4. `superpowers:verification-before-completion` (Always before completion claim) |
| Produces | UAT, VERIFICATION, test freshness marker |
| Review Cycle | Verification gaps route to GSD gap closure and re-verify |
| GSD Impact | GSD owns verification artifacts and gap creation |
| Exit Condition | VERIFICATION passes and required tests are fresh |

## FLOW 13: QUALITY GATE

| Field | Value |
|-------|-------|
| Prerequisites | Pre-plan: context exists. Pre-ship: implementation and verification exist. |
| Trigger | Always pre-plan and pre-ship for non-trivial workflows |
| Steps | 1. `silver:quality-gates` for product/software work or `devops-quality-gates` for infra/IaC · 2. dimension-specific SB skills (As-needed) |
| Produces | Quality assessment and gap list |
| Review Cycle | Gate itself is the review; blocking dimensions must be addressed |
| GSD Impact | Gaps route into GSD planning/execution |
| Exit Condition | Blocking quality findings are resolved or formally accepted when policy permits |

## FLOW 14: SHIP

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 10/11/12/13 gates satisfied; clean tree or intentional PR branch |
| Trigger | Phase-level ship/PR/CI step |
| Steps | 1. `gsd:pr-branch` (As-needed) · 2. `gsd:ship` (Always) |
| Produces | PR, CI status, phase ship updates |
| Review Cycle | CI failures insert FLOW 15 DEBUG |
| GSD Impact | GSD owns phase shipping, PR body, and state updates |
| Exit Condition | PR/ship step complete and CI/deploy gates are green or explicitly blocked |

## FLOW 15: DEBUG

| Field | Value |
|-------|-------|
| Prerequisites | None; dynamically inserted on failure |
| Trigger | Execution failure, failing tests, CI red, verification failure, unknown regression, broken GSD workflow |
| Steps | 1. `superpowers:systematic-debugging` (Always) · 2. `gsd:debug` (Always for code/workflow failures) · 3. `silver:forensics` (As-needed unknown cause/session reconstruction) · 4. `gsd:forensics` (As-needed failed GSD workflow) |
| Produces | Root cause, fix plan, diagnostic report |
| Review Cycle | Fixes route back through PLAN/EXECUTE/VERIFY as needed |
| GSD Impact | GSD owns debug execution and any gap closure work |
| Exit Condition | Root cause and next fix route are known |

## FLOW 16: DESIGN HANDOFF

| Field | Value |
|-------|-------|
| Prerequisites | UI phases verified |
| Trigger | Milestone release includes UI/design deliverables |
| Steps | 1. optional design handoff/design-system skills if installed · 2. `silver:handoff` (As-needed project continuation) |
| Produces | Handoff package or release handoff notes |
| Review Cycle | None unless handoff artifact requires review |
| GSD Impact | None directly; release flow consumes output |
| Exit Condition | UI handoff notes exist or no UI handoff is needed |

## FLOW 17: DOCUMENT

| Field | Value |
|-------|-------|
| Prerequisites | Implementation or release context exists |
| Trigger | Post-ship, pre-release, docs drift, user asks for docs |
| Steps | 1. `gsd:docs-update` (Always for codebase docs accuracy) · 2. `silver:ensure-docs` (As-needed doc scheme) · 3. `gsd:milestone-summary` (As-needed milestone narrative) · 4. `gsd:session-report` or `silver:handoff` (As-needed session continuity) |
| Produces | Updated docs, milestone/session summaries |
| Review Cycle | Docs semantic/structural checks as configured |
| GSD Impact | GSD owns docs-update artifacts where applicable |
| Exit Condition | Required docs are current and no doc gate is blocking |

## FLOW 18: RELEASE

| Field | Value |
|-------|-------|
| Prerequisites | All release-blocking phases complete; verification and review gates satisfied |
| Trigger | Milestone complete, version/release intent, public ship |
| Steps | 1. `gsd:audit-uat` (Always) · 2. `gsd:audit-milestone` (Always) · 3. `gsd:plan-milestone-gaps` (As-needed) · 4. FLOW 16 DESIGN HANDOFF (As-needed) · 5. FLOW 17 DOCUMENT (Always) · 6. `gsd:complete-milestone` (Always before tag) · 7. `silver:create-release` (Always last) |
| Produces | Archived milestone, changelog, tag, GitHub Release |
| Review Cycle | Cross-artifact and pre-release quality gates must pass before release creation |
| GSD Impact | GSD owns milestone completion, archive, and semver lifecycle; SB creates final release artifact only after GSD completion |
| Exit Condition | Release tag and GitHub Release exist and point at the fully archived milestone commit |
