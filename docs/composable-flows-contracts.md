# Composable Flows — Contract Reference

This is the canonical contract reference for `/silver` dynamic composition.

Silver Bullet owns the default software-engineering lifecycle: routing, context,
clarification, planning, execution, review, security, verification, shipping,
release, documentation, and hook enforcement. Optional provider, DevOps, design,
research, or issue-tracker plugins may extend a flow, but they do not own the
workflow contract.

## Naming And Availability

Contracts use SB logical skill names. At invocation time, use the host-exposed
equivalent:

| Family | Examples | Notes |
|--------|----------|-------|
| SB lifecycle | `silver:context`, `silver:plan`, `silver:execute`, `silver:verify`, `silver:ship` | Required core workflow surface. |
| SB quality | `silver:quality-gates`, `security`, `silver:secure`, `verify-tests` | Required gates selected by the active workflow. |
| SB release/docs | `silver:completion-audit`, `silver:branch-finish`, `silver:release`, `silver:create-release`, `silver:ensure-docs` | Finalization, release, and durable project documentation. |
| Optional extensions | DevOps providers, design systems, research connectors, issue trackers | Used only when the selected flow needs their external capability. |
| Legacy aliases | Historical lifecycle marker names | Normalized by SB for old projects; not required dependencies for new work. |

Do not replace a missing required SB gate with ad hoc shell work. Stop, report the
missing skill, and use an explicitly approved degraded path only when policy allows it.

## Contract Schema

Every flow contract has these fields:

| Field | Description |
|-------|-------------|
| Prerequisites | Artifacts or state that must exist before this flow runs |
| Trigger | Context signals that cause `/silver` to include this flow |
| Steps | Ordered skill invocations, marked Always or As-needed |
| Produces | Artifacts created or modified |
| Review Cycle | Artifact review or fix loop required for this flow |
| State Impact | SB-owned state, project artifacts, or external extension state read or written |
| Exit Condition | What makes this flow complete |

## Post-execution sequencing (composer canonical order)

Flow **numbers** in the catalog (FLOW 10–14) are stable identifiers — they are not always the runtime execution order for post-implementation gates.

For `silver:feature`, `silver:ui`, `silver:devops`, and `silver:bugfix`, the **mandatory post-execute order** after FLOW 8 (EXECUTE) is:

1. FLOW 9 (UI QUALITY: `silver:ui-review`) — **always** for `silver:ui`; for `silver:feature` only when UI scope is detected
2. FLOW 10 (REVIEW triad: `silver:review-request` → `silver:review` → `silver:review-triage`)
3. FLOW 12 (VERIFY: `silver:verify` + `verify-tests`)
4. FLOW 11 (SECURE: `security` + `silver:secure`, with `silver:validate` as needed)
5. FLOW 13 (QUALITY GATE, pre-ship)
6. FLOW 14 (SHIP: `silver:branch-finish` → `silver:completion-audit` → `silver:ship`)

The autonomous orchestrator (`hooks/lib/orchestrator-state.sh`) and composer skills use this order. Delivery hooks enforce artifact and marker presence regardless of flow numbering.

## Runtime Queue Tokens (orchestrator enforcement)

The autonomous orchestrator (`hooks/lib/orchestrator-state.sh`) seeds **enforcement queues**
with skill tokens and a few synthetic labels. These are not separate catalog flows — they
map to atomic flows or sub-steps below.

| Queue token | Maps to | Role |
|-------------|---------|------|
| `FLOW-QUALITY-GATE` | FLOW 13 (pre-plan) | Orchestrator label → `silver:quality-gates` or `devops-quality-gates` |
| `FLOW-QUALITY-GATE-PRESHIP` | FLOW 13 (pre-ship) | Product pre-ship quality gate |
| `FLOW-DEVOPS-QUALITY-GATE-PRESHIP` | FLOW 13 (pre-ship, DevOps) | IaC pre-ship quality gate |
| `silver:blast-radius` | FLOW 6 extension (DevOps) | Pre-plan blast-radius assessment before PLAN |
| `devops-skill-router` | FLOW 6 extension (DevOps) | IaC toolchain routing before PLAN |
| `silver:validate` | FLOW 5 / 6 / 11 sub-step | Pre-build or pre-ship gap analysis |
| `silver:branch-finish` | FLOW 14 sub-step | Branch hygiene before ship |
| `silver:completion-audit` | FLOW 12 sub-step | Completion evidence before ship/release claim |
| `ROUTER` | `/silver` router skill | Intent classification (worker template only) |

**Composition vs enforcement:** Composer skills (`silver:feature`, `silver:ui`, …) declare
full FLOW 1–18 **composition chains** (including conditional FLOW 2 ORIENT, FLOW 3 CLARIFY,
FLOW 4 DECIDE, FLOW 1 BOOTSTRAP). The orchestrator **enforcement queue** omits optional
orientation/clarify/decide atoms by default — hooks only block edits on the mandatory
pre-execution skill markers for each composer. Parent orchestrators insert skipped flows
when context scan flags require them.

Worker templates under `templates/orchestrator-workers/` implement one catalog flow each.
Per-flow skill steps, produces, and exit conditions live in this file — not in composer
`SKILL.md` files.

## Atomic Flow Catalog

| Flow | Name | Primary Owner | Purpose |
|------|------|---------------|---------|
| FLOW 1 | BOOTSTRAP | SB | Project setup and workflow initialization |
| FLOW 2 | ORIENT | SB | Codebase and project-state orientation |
| FLOW 3 | CLARIFY | SB | Problem framing, scope boundaries, and a decision-ready brief |
| FLOW 4 | DECIDE | SB | Architecture, product, or technical choice |
| FLOW 5 | SPECIFY | SB | SPEC.md and requirements creation/refinement |
| FLOW 6 | PLAN | SB | Context, assumptions, dependencies, and plans |
| FLOW 7 | DESIGN CONTRACT | SB | UI/UX contract where UI scope exists |
| FLOW 8 | EXECUTE | SB | Implementation through SB-owned execution discipline |
| FLOW 9 | UI QUALITY | SB | UI-specific audit and gap closure |
| FLOW 10 | REVIEW | SB | Code review, findings triage, and fixes |
| FLOW 11 | SECURE | SB | Security and safety verification |
| FLOW 12 | VERIFY | SB | UAT, tests, and must-have verification |
| FLOW 13 | QUALITY GATE | SB | Cross-cutting quality dimensions |
| FLOW 14 | SHIP | SB | Branch, PR, CI, and ship work |
| FLOW 15 | DEBUG | SB | Dynamic failure investigation |
| FLOW 16 | DESIGN HANDOFF | SB | Milestone-level UI handoff |
| FLOW 17 | DOCUMENT | SB | Durable docs and session knowledge |
| FLOW 18 | RELEASE | SB | Milestone audit, semver release, archive |

## Flow Contracts

### FLOW 1: BOOTSTRAP

| Field | Value |
|-------|-------|
| Prerequisites | None |
| Trigger | No `.planning/`; new project; new milestone; prior milestone complete |
| Steps | 1. `silver:init` (Always) · 2. `silver:context` (As-needed brownfield orientation) · 3. `silver:plan` (As-needed milestone or phase setup) |
| Produces | `.silver-bullet.json`, `silver-bullet.md`, workflow docs, `.planning/` starter artifacts when requested |
| Review Cycle | Project docs and planning artifacts reviewed when created or substantially changed |
| State Impact | Initializes SB config, runtime state location, and project workflow surface |
| Exit Condition | SB config exists and the current workflow position is known |

### FLOW 2: ORIENT

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 1 complete, or existing project artifacts present |
| Trigger | Included for non-trivial work unless current intel is already sufficient |
| Steps | 1. `silver:scan` (As-needed rapid scan) · 2. `silver:context` (Always for non-trivial work) · 3. `silver:review-stats` (As-needed review history) |
| Produces | Context summary, codebase map, current workflow position |
| Review Cycle | None |
| State Impact | Reads project docs, `.planning/`, git state, and SB runtime state |
| Exit Condition | Current codebase/project position is known well enough to choose the next flow |

### FLOW 3: CLARIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 1 complete for project work; none for pure ideation |
| Trigger | Fuzzy intent, unclear scope, complex work, new idea, user uncertainty |
| Steps | 1. `silver:clarify` (Always) · 2. optional product/research connector (As-needed) |
| Produces | Scope summary, assumptions, boundaries, framing, and next lifecycle route |
| Review Cycle | None |
| State Impact | May feed SPEC, CONTEXT, or backlog artifacts; no direct delivery gate mutation |
| Exit Condition | Scope and next lifecycle route are explicit |

### FLOW 4: DECIDE

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 2 complete or a crisp decision question exists |
| Trigger | Architecture choice, stack selection, major tradeoff, API/data-model impact |
| Steps | 1. `silver:research` (Always for unknown/novel decisions) · 2. `silver:context` (As-needed codebase impact) · 3. optional spike or external research connector (As-needed) |
| Produces | Research artifact, ADR-style decision summary, selected option, known risks |
| Review Cycle | Research artifact review when used as implementation input |
| State Impact | Writes durable decision evidence when the decision affects future work |
| Exit Condition | A named option is selected with rationale and known risks |

### FLOW 5: SPECIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 3/4 complete, or external artifact exists to ingest |
| Trigger | Missing/stale SPEC.md, new requirements, external JIRA/Figma/Google Docs/cross-repo spec |
| Steps | 1. `silver:ingest` (As-needed) · 2. `silver:spec` (Always) · 3. `silver:validate` (Always) |
| Produces | `.planning/SPEC.md`, `.planning/REQUIREMENTS.md`, optional `.planning/INGESTION_MANIFEST.md` |
| Review Cycle | SPEC, REQUIREMENTS, DESIGN, and INGESTION_MANIFEST review where present |
| State Impact | Updates project requirements evidence used by planning and verification gates |
| Exit Condition | Requirements are clear enough for planning and no blocking validation gaps remain |

### FLOW 6: PLAN

| Field | Value |
|-------|-------|
| Prerequisites | Requirements or accepted task scope exists |
| Trigger | Always before execution for non-trivial codebase work |
| Steps | 1. `silver:context` (Always) · 2. `silver:plan` (Always) · 3. `silver:validate` (As-needed dependency/gap check) |
| Produces | CONTEXT, PLAN, assumptions, dependency notes, acceptance mapping |
| Review Cycle | CONTEXT/PLAN review; plan-checker must pass for implementation work |
| State Impact | Records SB planning markers required by edit and delivery gates |
| Exit Condition | PLAN exists for the current scope and is accepted for execution |

### FLOW 7: DESIGN CONTRACT

| Field | Value |
|-------|-------|
| Prerequisites | PLAN exists or UI scope is known enough to design |
| Trigger | UI/frontend/design scope, UI files, Figma/design artifact, accessibility-sensitive change |
| Steps | 1. `silver:ui-contract` (Always) · 2. optional design-system/UX/accessibility connector (As-needed) · 3. `silver:quality-gates` (As-needed pre-plan quality check) |
| Produces | UI-SPEC or equivalent design contract |
| Review Cycle | UI/design review when artifact exists |
| State Impact | Adds UI contract evidence consumed by implementation and UI review |
| Exit Condition | UI contract exists or user explicitly accepts no-UI-contract rationale |

### FLOW 8: EXECUTE

| Field | Value |
|-------|-------|
| Prerequisites | PLAN exists; required planning gate markers are recorded |
| Trigger | Always for implementation work |
| Steps | 1. `tdd` (As-needed behavior-changing implementation) · 2. `silver:execute` (Always) |
| Produces | Code changes, tests, implementation summary |
| Review Cycle | Insert FLOW 15 DEBUG on execution/test failure |
| State Impact | Records execution markers and invalidates stale verification markers after source edits |
| Exit Condition | Planned implementation tasks are complete and summarized |

### FLOW 9: UI QUALITY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 7 complete with UI deliverables |
| Trigger | UI flow included, UI files changed, or implementation summary references UI deliverables |
| Steps | 1. `silver:ui-review` (Always) · 2. optional design critique/accessibility connector (As-needed) |
| Produces | UI-REVIEW or equivalent findings |
| Review Cycle | Critical findings route to gap closure and re-review |
| State Impact | Updates UI review evidence consumed by release and completion audit |
| Exit Condition | No blocking UI findings remain, or user accepts documented residual risk |

### FLOW 10: REVIEW

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 8 complete |
| Trigger | Always for implementation work |
| Steps | 1. `silver:review-request` (Always) · 2. `silver:review` (Always) · 3. `silver:review-triage` (Always when findings exist) |
| Produces | REVIEW files, findings, and fix commits when needed |
| Review Cycle | Iterate until required clean-pass threshold is met |
| State Impact | Records review markers required by final delivery gates |
| Exit Condition | Review gate passes or accepted residual risks are captured |

### FLOW 11: SECURE

| Field | Value |
|-------|-------|
| Prerequisites | PLAN or implementation scope known |
| Trigger | Always for software changes; especially agents, hooks, prompts, infra, auth, data, release |
| Steps | 1. `security` (Always for SB/plugin/agent safety) · 2. `silver:secure` (Always) · 3. `silver:validate` (As-needed gap filling) · 4. `silver:ai-llm-safety` (As-needed LLM/agent behavior) |
| Produces | SECURITY and validation artifacts |
| Review Cycle | Security findings must be resolved or explicitly accepted before ship/release |
| State Impact | Records security and validation evidence consumed by ship/release gates |
| Exit Condition | No blocking security/validation findings remain |

### FLOW 12: VERIFY

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 8 complete; implementation summary exists |
| Trigger | Always; non-skippable |
| Steps | 1. `silver:verify` (Always) · 2. `verify-tests` (Always when tests are runnable) · 3. `silver:completion-audit` (Always before completion claim) |
| Produces | UAT, VERIFICATION, test freshness marker |
| Review Cycle | Verification gaps route to gap closure and re-verify |
| State Impact | Records verification markers and test freshness evidence |
| Exit Condition | Verification passes and required tests are fresh |

### FLOW 13: QUALITY GATE

| Field | Value |
|-------|-------|
| Prerequisites | Pre-plan: context exists. Pre-ship: implementation and verification exist. |
| Trigger | Always pre-plan and pre-ship for non-trivial workflows |
| Steps | 1. `silver:quality-gates` for product/software work or `devops-quality-gates` for infra/IaC · 2. dimension-specific SB skills (As-needed) |
| Produces | Quality assessment and gap list |
| Review Cycle | Gate itself is the review; blocking dimensions must be addressed |
| State Impact | Records quality gate markers consumed by edit and delivery gates |
| Exit Condition | Blocking quality findings are resolved or formally accepted when policy permits |

### FLOW 14: SHIP

| Field | Value |
|-------|-------|
| Prerequisites | FLOW 10/11/12/13 gates satisfied; clean tree or intentional PR branch |
| Trigger | Phase-level ship/PR/CI step |
| Steps | 1. `silver:branch-finish` (As-needed) · 2. `silver:ship` (Always) |
| Produces | PR, CI status, ship updates |
| Review Cycle | CI failures insert FLOW 15 DEBUG |
| State Impact | Records branch/ship markers and checks CI before final delivery |
| Exit Condition | PR/ship step complete and CI/deploy gates are green or explicitly blocked |

### FLOW 15: DEBUG

| Field | Value |
|-------|-------|
| Prerequisites | None; dynamically inserted on failure |
| Trigger | Execution failure, failing tests, CI red, verification failure, unknown regression, broken workflow |
| Steps | 1. `silver:debug` (Always) · 2. `silver:forensics` (As-needed unknown cause/session reconstruction) |
| Produces | Root cause, fix plan, diagnostic report |
| Review Cycle | Fixes route back through PLAN/EXECUTE/VERIFY as needed |
| State Impact | Adds diagnostic evidence and may create follow-up gap work |
| Exit Condition | Root cause and next fix route are known |

### FLOW 16: DESIGN HANDOFF

| Field | Value |
|-------|-------|
| Prerequisites | UI phases verified |
| Trigger | Milestone release includes UI/design deliverables |
| Steps | 1. optional design handoff/design-system connector (As-needed) · 2. `silver:handoff` (As-needed project continuation) |
| Produces | Handoff package or release handoff notes |
| Review Cycle | None unless handoff artifact requires review |
| State Impact | Adds continuity evidence consumed by release flow |
| Exit Condition | UI handoff notes exist or no UI handoff is needed |

### FLOW 17: DOCUMENT

| Field | Value |
|-------|-------|
| Prerequisites | Implementation or release context exists |
| Trigger | Post-ship, pre-release, docs drift, user asks for docs |
| Steps | 1. `silver:ensure-docs` (Always for doc scheme) · 2. `silver:handoff` (As-needed session continuity) · 3. `silver:scan` (As-needed deferred insights) |
| Produces | Updated docs, milestone/session summaries, knowledge and learning entries |
| Review Cycle | Docs semantic/structural checks as configured |
| State Impact | Updates durable project docs and monthly knowledge/learning logs |
| Exit Condition | Required docs are current and no doc gate is blocking |

### FLOW 18: RELEASE

| Field | Value |
|-------|-------|
| Prerequisites | All release-blocking phases complete; verification and review gates satisfied |
| Trigger | Milestone complete, version/release intent, public ship |
| Steps | 1. `silver:release` (Always) · 2. FLOW 16 DESIGN HANDOFF (As-needed) · 3. FLOW 17 DOCUMENT (Always) · 4. `silver:create-release` (Always last) |
| Produces | Archived milestone, changelog, tag, GitHub Release |
| Review Cycle | Cross-artifact and pre-release quality gates must pass before release creation |
| State Impact | Records release markers, updates release docs, and preserves milestone evidence |
| Exit Condition | Release tag and GitHub Release exist and point at the fully verified release commit |

**FLOW 18 sub-steps (release composition vocabulary):**

| Sub-step | FLOW | Purpose |
|----------|------|---------|
| Pre-release quality gate | FLOW 13 | `silver:quality-gates` + domain audit |
| UAT audit | FLOW 12 | Cross-phase UAT evidence → `.planning/RELEASE-UAT-AUDIT.md` |
| Milestone audit | FLOW 18 | Scope vs evidence → `.planning/RELEASE-MILESTONE-AUDIT.md` |
| Gap closure | FLOW 8 + FLOW 15 | Max 2 iterations via nested `silver:feature` / `silver:bugfix` / … |
| Design handoff | FLOW 16 | UI milestone handoff when UI phases exist |
| Document | FLOW 17 | `silver:ensure-docs`, milestone summary |
| Ship prep | FLOW 14 | `silver:branch-finish` → `silver:completion-audit` → `silver:ship` |
| Create release | FLOW 18 | `silver:create-release` (always last) |
