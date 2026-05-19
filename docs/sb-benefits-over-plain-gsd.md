# Silver Bullet Benefits Over Plain GSD

**Date:** 2026-05-14  
**Scope:** Concrete benefits Silver Bullet provides when layered on top of GSD, based on the current Silver Bullet project documents and codebase surfaces: hooks, commands, and skills.  
**Short answer:** GSD is the planning and execution engine. Silver Bullet is the orchestration, enforcement, quality, release, and operating-discipline layer around that engine.

---

## Executive Summary

Silver Bullet does not replace GSD, and its strongest value is not duplicating GSD's planning or execution mechanics. Plain GSD already provides the core engineering engine: `.planning/` artifacts, roadmap and phase management, phase discussion, planning, wave-based execution, verification, subagents with fresh context, dependency-aware plans, and atomic per-task commits.

Silver Bullet's concrete benefit is that it turns GSD from a powerful toolkit into an enforced software-delivery process. It adds hooks, gates, dynamic workflow composition, cross-plugin sequencing, spec and UAT gates, artifact-review governance, release controls, DevOps risk controls, documentation governance, session continuity, and delivery traceability that plain GSD does not provide by itself.

In practical terms:

- **Plain GSD helps the agent do the work well.**
- **Silver Bullet helps ensure the agent actually follows the whole process before code, PRs, deploys, or releases happen.**

The strongest SB-over-GSD benefits are:

1. **Enforcement:** SB blocks skipped planning, review, verification, CI, docs, and release steps through host hooks.
2. **Dynamic workflow composition:** SB selects and composes the right flow chain for the task at hand, rather than forcing every request through a rigid pre-defined workflow.
3. **Cross-plugin orchestration:** SB sequences GSD with selected helper plugins for review, design, Product Management, DevOps enrichment, and SB-owned gates into one process.
4. **Spec and acceptance governance:** SB adds spec elicitation, artifact ingestion, pre-build validation, UAT freshness, and PR traceability around GSD's implementation lifecycle.
5. **Artifact review governance:** SB adds a generic reviewer framework, two-pass review loops, reviewer-assessor triage, and review analytics across planning artifacts.
6. **Quality gates:** SB adds product, security, test, release, and DevOps gates outside GSD's core execution loop.
7. **DevOps safety:** SB adds blast-radius analysis, incident paths, environment promotion, and deployment safeguards.
8. **Release governance:** SB adds release-gate architecture around GSD milestone completion; the full 4-stage gate is currently specific to this Claude/Codex plugin project and should be generalized later.
9. **Continuity and memory:** SB captures issues, deferred items, knowledge, lessons, handoffs, session logs, and session forensics.
10. **Boundary protection:** SB protects planning artifacts, SB state files, instruction files, third-party plugin files, and legacy bypass markers from unsafe edits.

---

## Definitions

### Plain GSD

In this report, **plain GSD** means using GSD by itself, without Silver Bullet's hooks, `/silver` router, composed workflow tracker, SB-owned quality gates, SB docs governance, and SB release gates.

Plain GSD includes:

- `.planning/` project artifacts
- project, milestone, roadmap, requirements, phase, and state management
- phase discussion and planning
- dependency-aware plan breakdown
- wave-based multi-agent execution
- fresh context per GSD agent
- atomic task commits
- GSD verification, review, debug, ship, and milestone completion commands

### Silver Bullet On Top Of GSD

Silver Bullet is the layer that sits above GSD. It reads and respects GSD state, calls GSD commands, and refuses to treat its own state as a replacement for `.planning/STATE.md`.

SB owns:

- host hook enforcement
- `/silver` classification and flow composition
- composed workflow tracking
- quality gates
- release gates
- DevOps safety gates
- spec, ingestion, validation, UAT, and PR traceability gates
- artifact-review orchestration and analytics
- docs governance
- issue, knowledge, lesson, and handoff capture
- session supervision and anti-stall checks
- cross-plugin sequencing

---

## Boundary: What Should Not Be Counted As An SB Benefit

Some documents and comparison tables mark SB as having GSD capabilities because SB integrates GSD. That is useful from a product-stack perspective, but it is not a clean answer to "what does SB provide over plain GSD?"

The following are **not** SB-over-GSD benefits by themselves:

| Capability | Owner | Why it is not an SB-over-GSD benefit |
|---|---|---|
| `.planning/` lifecycle | GSD | SB reads it; GSD writes and owns it. |
| ROADMAP, STATE, PROJECT artifacts | GSD | SB may gate around them, but does not replace their ownership. |
| Basic requirements storage | GSD | SB's benefit is not merely having a requirements file; it is the added spec elicitation, ingestion, validation, UAT, review, and traceability layer around requirements. |
| Phase discussion, planning, execution, verification | GSD | SB sequences these steps; GSD performs them. |
| Wave-based parallel execution | GSD | SB may invoke it, but GSD supplies the mechanism. |
| Fresh 200K-token agent context | GSD | This is GSD's core execution value. |
| Atomic per-task commits | GSD | SB permits them through two-tier enforcement; GSD creates them. |
| SUMMARY.md generation | GSD | SB can check freshness and release readiness, but GSD creates the summaries. |

This report counts only the behaviors SB adds or enforces beyond plain GSD.

---

## Core Difference

| Dimension | Plain GSD | Silver Bullet + GSD |
|---|---|---|
| Primary role | Planning and execution engine | Orchestration and enforcement layer around GSD |
| User entry point | `gsd:*` commands and `gsd:do` freeform delegation | `/silver` classifies intent and composes the appropriate SB/GSD workflow chain |
| Process discipline | Instructional and artifact-driven | Hook-enforced and state-tracked |
| Workflow shape | GSD lifecycle commands | Dynamic composition from 18 flows |
| Spec and acceptance lifecycle | Requirements and phase plans live in GSD artifacts | SB adds `SPEC.md`, ingestion manifests, pre-build validation findings, UAT gates, and PR traceability |
| Artifact review | GSD has reviewers for its own planning/execution artifacts | SB adds a general artifact-review framework for specs, requirements, design, roadmap, context, research, ingestion, UAT, and cross-artifact sets |
| Quality gates | GSD verification and review artifacts | Product, DevOps, security, review, test, docs, and release gates |
| Commit/PR/deploy/release safety | Mostly operator discipline plus GSD workflow | Mechanical gates on tool use and delivery commands |
| Delivery traceability | Can be represented manually in artifacts | PR descriptions and `SPEC.md` implementation links are updated from captured spec session state |
| Cross-plugin integration | Mostly outside GSD | Explicit sequencing of GSD, SB gates, and selected helper plugins |
| Session continuity | GSD state and artifacts | GSD state plus SB state, session logs, issue capture, knowledge, lessons, handoff, anti-stall warnings, and forensics |
| DevOps workflow | GSD can execute infra tasks | SB adds infra-specific risk, promotion, incident, and deploy gates |

---

## Benefit 1: SB Makes The Process Harder To Skip

### Plain GSD

Plain GSD gives the agent the right commands and artifacts, but it does not provide SB's host-level hook layer that fires on every file edit, Bash command, skill invocation, user prompt, stop event, and delivery operation.

An agent can still:

- edit source before quality gates
- commit before review
- create a PR before test freshness
- say "done" without invoking final verification
- update planning files directly instead of through owning GSD commands
- forget a required review or release step after context compaction

### Silver Bullet addition

SB adds a multi-layer enforcement system. Important layers include:

- `record-skill.sh`: records skill invocations
- `dev-cycle-check.sh`: blocks code edits before planning/quality gates
- `workflow-chain-guard.sh`: blocks source edits when a composed workflow is active but the required downstream dependency chain is not recorded
- `dependency-skill-check.sh`: fails closed when required GSD skills or selected helper dependencies are unavailable
- `planning-file-guard.sh`: blocks direct edits to GSD-owned planning artifacts
- `trivial-file-guard.sh`: blocks legacy trivial-marker bypass writes
- `instruction-file-guard.sh`: prevents SB from synthesizing new root instruction files during Codex initialization
- `completion-audit.sh`: blocks commit/push/deploy/release when required steps are missing
- `ci-status-check.sh`: blocks push, PR, and release when CI is red
- `compliance-status.sh`: displays progress on every tool call
- `stop-check.sh`: blocks task-complete declarations when gates are missing
- `spec-floor-check.sh`: blocks `gsd-plan-phase` when the minimum viable `SPEC.md` is missing
- `uat-gate.sh`: blocks milestone completion when UAT evidence is missing, failing, or stale against the current spec version
- `record-requested-skill.sh` and `prompt-reminder.sh`: record requested routes and re-inject missing skills before each prompt
- `forbidden-skill-check.sh`: blocks deprecated or forbidden execution paths
- `roadmap-freshness.sh`: blocks commits where phase summaries and roadmap checkboxes diverge
- `pr-traceability.sh`: appends spec traceability to PR descriptions and records implementation links in `SPEC.md`
- `phase-archive.sh`: archives phase directories before `gsd-tools phases clear`

### Practical benefit

SB changes the process from "the agent should remember" to "the environment blocks the next unsafe action." That is the central benefit over plain GSD.

---

## Benefit 2: SB Adds Dynamic Workflow Composition

### Plain GSD

Plain GSD already has `gsd:do`, so SB's benefit is not merely "natural language input." GSD can already accept freeform delegation into the GSD lifecycle.

The distinction is that plain GSD remains centered on GSD-owned lifecycle operations. It can route GSD work, but it does not dynamically compose a broader task-specific chain across SB gates, GSD phases, Superpowers review/TDD, Engineering docs/deploy skills, Design skills, DevOps enrichments, and release governance.

A feature, UI change, bugfix, DevOps task, research task, and release are not identical workflows. Plain GSD provides the lifecycle engine; it does not decide the full multi-plugin flow shape for every work type.

### Silver Bullet addition

SB provides `/silver`, which classifies the task and composes a workflow from 18 atomic flows:

- BOOTSTRAP
- ORIENT
- CLARIFY
- DECIDE
- SPECIFY
- PLAN
- DESIGN CONTRACT
- EXECUTE
- UI QUALITY
- REVIEW
- SECURE
- VERIFY
- QUALITY GATE
- SHIP
- DEBUG
- DESIGN HANDOFF
- DOCUMENT
- RELEASE

SB then chooses the relevant chain for the current task:

| Task type | Example composition difference |
|---|---|
| Feature | Clarify/decide, quality gate, GSD plan/execute/verify, review, secure, ship |
| Bugfix | Insert DEBUG first, then plan/execute/review/verify/ship |
| UI | Add DESIGN CONTRACT and UI QUALITY around GSD execution |
| DevOps | Use blast-radius, IaC quality gates, environment promotion, deploy checklist |
| Release | Run audit, docs, release gates, milestone completion, release creation |
| Fast path | Classify low-risk work and route to `gsd-fast` without full workflow overhead |

### Practical benefit

SB's value is task-shaped orchestration, not just freeform routing. It turns GSD commands into context-specific delivery flows that include the right gates and adjacent plugin work for the task at hand.

---

## Benefit 3: SB Adds Cross-Plugin Orchestration

### Plain GSD

GSD focuses on planning and execution. It does not own the full set of SB release gates, design/product enrichment, review helper, or optional DevOps plugin steps.

### Silver Bullet addition

SB explicitly sequences multiple plugins:

- **GSD:** planning, execution, verification, milestone lifecycle
- **Superpowers:** TDD, review framing/triage, verification-before-completion, branch finishing when SB explicitly selects those helper boundaries
- **Engineering:** testing strategy, documentation, deploy checklist, incident response, architecture
- **Design:** design system, UX copy, accessibility, design critique
- **Product Management:** spec and research enrichment where installed
- **DevOps plugins:** Terraform, AWS, Pulumi, Kubernetes, GitOps, CI/CD, monitoring enrichment

SB also enforces boundaries:

- GSD owns phase planning and execution
- Superpowers does not replace GSD execution
- Engineering and Design skills are triggered at workflow points
- SB wraps and gates rather than modifying third-party plugin files
- Required dependency plugins fail closed instead of silently degrading when the workflow says they are mandatory

### Practical benefit

SB is the integration layer. It lets a project use GSD as the execution engine while still getting review, design, testing, documentation, deployment, and release discipline from adjacent tools.

---

## Benefit 4: SB Adds Spec, Ingestion, Validation, And UAT Gates

### Plain GSD

GSD can manage requirements, phase plans, execution, verification, and milestone state, but plain GSD does not provide SB's spec-first contract around external artifacts, acceptance criteria, implementation coverage, UAT freshness, and PR traceability.

### Silver Bullet addition

SB adds a spec and acceptance-governance layer around GSD:

- `silver-spec`: Socratic spec elicitation that writes canonical `.planning/SPEC.md` and `.planning/REQUIREMENTS.md`
- `silver-ingest`: ingestion from JIRA, Figma, Google Docs, Confluence, and cross-repo specs into `.planning/SPEC.md`, `.planning/DESIGN.md`, `.planning/SPEC.main.md`, and `.planning/INGESTION_MANIFEST.md`
- `silver-validate`: pre-build gap analysis between `SPEC.md` acceptance criteria and phase `PLAN.md` coverage, producing machine-readable `.planning/VALIDATION.md`
- `spec-floor-check.sh`: a hard gate that blocks planning when `.planning/SPEC.md` is missing its minimum required sections
- `uat-gate.sh`: a milestone-completion gate that requires `.planning/UAT.md`, rejects failing criteria, and checks UAT against the current `spec-version`
- `spec-session-record.sh`: captures `spec-version` and JIRA ID at session start
- `pr-traceability.sh`: appends spec traceability and deferred validation warnings to the PR description, then records the PR URL in `SPEC.md`

### Practical benefit

SB makes requirements traceable across the full path from external artifact or elicited spec to plan coverage, UAT evidence, PR description, and implementation record. Plain GSD can execute a well-formed plan; SB adds the upstream and downstream checks that the plan actually covers the accepted product contract.

---

## Benefit 5: SB Adds Pre-Code Quality Gates

### Plain GSD

GSD can discuss, plan, execute, verify, review, and validate a phase, but plain GSD does not provide SB's cross-cutting pre-code quality-gate system.

### Silver Bullet addition

SB requires quality gates before planning and again before shipping. For product/software work, it checks 8 core dimensions plus conditional AI/LLM safety. For infrastructure work, it checks 7 IaC-adapted dimensions.

Product/software dimensions include:

- modularity
- reusability
- scalability
- security
- reliability
- usability
- testability
- extensibility
- AI/LLM safety where applicable

DevOps dimensions include:

- modularity
- reusability
- scalability
- security
- reliability
- testability
- extensibility

Failures are treated as hard stops, not advisory notes.

### Practical benefit

SB catches architecture and quality problems before implementation, not only after code exists. GSD's plan may be valid relative to requirements; SB asks whether the approach is safe, maintainable, testable, reusable, and operable.

---

## Benefit 6: SB Adds Test Freshness As A Delivery Gate

### Plain GSD

GSD verification is valuable because it checks work against requirements and acceptance criteria, but SB's docs distinguish that from mechanical test freshness at final delivery time.

### Silver Bullet addition

SB provides `/verify-tests`, which:

- runs project-configured `verify_commands` from `.silver-bullet.json`
- falls back to stack defaults such as `tests/run-all-tests.sh`, `npm test`, `pytest`, `cargo test`, or `go test ./...`
- writes a session-scoped freshness marker
- invalidates that marker when source changes land
- blocks PR/deploy/release if the marker is stale or missing

### Practical benefit

SB prevents a common failure mode: "tests were run earlier, then files changed, then delivery still proceeded." Plain GSD can verify work, but SB adds a delivery-time freshness check tied to the current session and source edits.

---

## Benefit 7: SB Adds A Stronger Release Process

### Plain GSD

GSD has phase-level shipping and milestone completion capabilities. It can prepare PRs, complete milestones, archive artifacts, and tag releases depending on the workflow.

### Silver Bullet addition

SB adds a release governance layer around GSD:

- code review triad
- big-picture consistency audit
- public-facing content refresh
- SENTINEL security audit
- mandatory full test rerun
- live Claude/Codex matrix markers
- live todo-app E2E markers
- GitHub Release creation
- release-note generation
- README/version/changelog checks
- CI blocking before release

Important scope note: the current 4-stage pre-release quality gate is specific to Silver Bullet's own Claude/Codex plugin release process. It is a real SB capability in this repository, but it should not be overstated as a generic downstream-project release benefit yet. The generic SB-over-GSD benefit is the release-gate architecture: SB has a place to enforce review, test freshness, CI, docs, release notes, and release markers around GSD milestone completion. Generalizing the full 4-stage gate beyond Claude/Codex plugin releases is future work.

### Practical benefit

Plain GSD can get work to a shippable milestone. SB adds a release-gating layer around that milestone. Today, the strongest full 4-stage release gate is proven for this plugin project; downstream generic release gating is the broader direction rather than a fully generalized claim.

---

## Benefit 8: SB Adds DevOps-Specific Risk Controls

### Plain GSD

GSD can plan and execute infrastructure work as project work. It can break tasks into phases, execute with agents, and verify the result.

### Silver Bullet addition

SB adds a dedicated DevOps workflow with controls that are not plain GSD's core concern:

- incident fast path
- required incident-response before emergency changes
- blast-radius assessment before infrastructure planning
- LOW/MEDIUM/HIGH/CRITICAL risk ratings
- explicit user approval and runbook requirements for HIGH risk
- CAB hard stop for CRITICAL risk
- IaC-specific quality gates
- environment promotion from lower environments to higher environments
- deployment checklist with rollback, on-call, change window, and monitoring checks
- production apply safeguards
- `devops-skill-router` and IaC plugin routing for Terraform, AWS, Pulumi, Kubernetes, GitOps, CI/CD, monitoring, and related tools

### Practical benefit

SB makes infrastructure work safer. It forces risk analysis and staged promotion before production changes, which plain GSD does not provide as a dedicated safety layer.

---

## Benefit 9: SB Protects Planning Artifacts And Workflow State From Unsafe Direct Edits

### Plain GSD

Planning artifacts and workflow state are files in the repo or user-scoped state directories. A user or agent can technically edit them directly unless a separate guard exists.

### Silver Bullet addition

SB's guard layer blocks direct edits to GSD-managed planning artifacts and related workflow state such as:

- ROADMAP.md
- STATE.md
- REQUIREMENTS.md
- phase plans
- other `.planning/` lifecycle files
- SB state markers under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet`
- legacy trivial bypass markers

The guard forces the user or agent to use the owning workflow or skill instead.

### Practical benefit

SB preserves planning and workflow state integrity. It reduces divergence between what the workflow thinks is true, what GSD artifacts say, and what the repo files contain.

---

## Benefit 10: SB Adds Traceability And Planning Artifact Preservation

### Plain GSD

GSD writes phase summaries, roadmap state, and phase artifacts, but plain GSD does not provide SB's separate commit-time freshness, PR traceability, and pre-clear archive safeguards.

### Silver Bullet addition

SB adds several traceability and preservation mechanisms:

- `roadmap-freshness.sh`: blocks commits where a phase `SUMMARY.md` is staged but the corresponding ROADMAP checkbox is not ticked
- `spec-session-record.sh`: records current `SPEC.md` version and JIRA ID at session start
- `pr-traceability.sh`: appends a spec traceability block to PR descriptions and updates `SPEC.md` with implementation PR links
- `.planning/VALIDATION.md` warnings: flow into PR descriptions as deferred items instead of disappearing from the review surface
- `phase-archive.sh`: copies phase directories to `.planning/archive/{milestone}/` before `gsd-tools phases clear`

### Practical benefit

SB reduces "artifact drift," where work was completed but planning, PR, and release state do not match. It also reduces data loss risk when phase directories are cleared after a milestone.

---

## Benefit 11: SB Adds Artifact Review Governance And Review Analytics

### Plain GSD

GSD includes review and verification mechanisms for its own lifecycle artifacts, but plain GSD does not provide SB's generic artifact-review framework across every planning and specification surface.

### Silver Bullet addition

SB adds an artifact-review framework with:

- `artifact-reviewer`: a common interface, reviewer auto-detection, state tracking, audit trail, and depth configuration
- two-consecutive-clean-pass loops for high-stakes artifacts such as `SPEC.md` and `REQUIREMENTS.md`
- `artifact-review-assessor`: triage of findings into MUST-FIX, NICE-TO-HAVE, and DISMISS so review loops do not turn every stylistic suggestion into a blocker
- reviewers for `SPEC.md`, `DESIGN.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `CONTEXT.md`, `RESEARCH.md`, `INGESTION_MANIFEST.md`, `UAT.md`, and cross-artifact sets
- `REVIEW-ROUNDS.md` audit trails
- `.planning/review-analytics.jsonl` metrics
- `silver-review-stats` summaries for pass rates, rounds-to-clean-pass, average findings, and active reviewers

### Practical benefit

SB gives planning and requirements artifacts the same kind of review discipline that code often receives. It makes artifact quality observable over time instead of treating reviews as one-off manual comments.

---

## Benefit 12: SB Adds Issue, Backlog, Knowledge, And Lesson Capture

### Plain GSD

GSD tracks project state and phase progress, but plain GSD does not provide SB's dedicated capture tools for session-level operational memory.

### Silver Bullet addition

SB adds:

- `/silver-add`: classify and file issue/backlog items
- `/silver-remove`: remove tracked items
- `/silver-rem`: capture project knowledge and portable lessons into monthly docs
- `/silver-scan`: retrospectively scan session logs for deferred items and unrecorded insights
- `/silver-handoff`: produce a reusable project continuation prompt

The documentation scheme distinguishes:

- `.planning/`: per-milestone planning artifacts
- `docs/`: durable project docs
- `README.md`: public project overview
- `docs/knowledge/`: project-specific intelligence
- `docs/lessons/`: portable lessons

### Practical benefit

SB turns session residue into durable project memory. Deferred items, decisions, gotchas, and lessons do not depend on the active agent remembering them.

---

## Benefit 13: SB Adds Session Forensics

### Plain GSD

GSD has forensics for plan drift, execution anomalies, stuck loops, and `.planning/` artifact issues.

### Silver Bullet addition

SB adds session-level forensics for:

- enforcement failures
- stalls
- timeouts
- abandoned sessions
- wrong output
- hook failures
- task-level drift between plan, diff, and test evidence
- hook payload debugging through opt-in `debug-dump.sh`

SB routes GSD-workflow-level anomalies to `gsd:forensics`, but handles SB/session-level issues directly.

### Practical benefit

SB gives the operator a post-mortem tool for failures outside GSD's artifact lifecycle. This matters because many agent failures are not bad plans; they are skipped gates, context drift, hook gaps, permissions issues, or stale session state.

---

## Benefit 14: SB Adds Prompt, Context, And Stall Reinforcement

### Plain GSD

GSD manages planning and execution context, but it does not re-inject SB's missing-skill list, workflow status, session status, and stall warnings before and during long-running work.

### Silver Bullet addition

SB's `UserPromptSubmit` hooks:

- record requested SB/GSD routes
- re-inject missing skills
- remind the active agent of core rules
- surface active workflow context

SB also adds:

- semantic compression hooks after skill invocations
- session-start context injection
- session log skeleton creation under `docs/sessions/`
- autonomous-mode timeout sentinels
- call-count anti-stall warnings when many tool calls happen without recorded workflow progress
- branch-mismatch and destructive-command warnings

### Practical benefit

SB fights long-session drift and runaway loops. It keeps process state visible to the active agent even after compaction or a long sequence of tool calls, and it surfaces stalls before they become silent abandonment.

---

## Benefit 15: SB Adds Compliance Visibility

### Plain GSD

GSD has state files and progress artifacts. Users can inspect them, but plain GSD does not show SB's live compliance score on every tool use.

### Silver Bullet addition

SB's compliance-status hook displays current progress continuously. In composed-workflow mode, it can show flow progress. In legacy mode, it shows required skill progress.

### Practical benefit

The active agent and user can see exactly what is missing before finalization. This reduces silent process drift.

---

## Benefit 16: SB Adds A Safer Fast Path

### Plain GSD

GSD has quick/fast capabilities, but choosing when to use them is still a matter of judgment.

### Silver Bullet addition

SB routes trivial work through `silver:fast`, which classifies the request and dispatches to `gsd-fast` instead of letting agents use legacy bypass markers.

SB also treats DevOps files such as `.yml`, `.yaml`, `.json`, and `.toml` as infrastructure code in the DevOps workflow, so they are not casually exempted just because they are declarative.

### Practical benefit

Small edits stay lightweight without opening a broad bypass around workflow enforcement.

---

## Benefit 17: SB Adds Multi-Runtime Coordination

### Plain GSD

Plain GSD's core lifecycle is project-scoped. It does not define SB's cross-runtime lock discipline for multiple host agents sharing one working tree.

### Silver Bullet addition

SB defines a phase lock model:

- one phase equals one runtime at a time
- Claude-SB, Forge-SB, future Codex-SB, and future OpenCode-SB use runtime identity tags
- locks live in `.planning/.phase-locks.json`
- phase claims, heartbeats, stale-lock handling, release, and delegation are explicit
- `/forge-delegate` is the controlled exception for child-runtime work under a parent lock

### Practical benefit

Two SB-bearing agents can work on different phases without accidentally modifying the same phase artifacts. This is operational coordination around GSD's phase model.

---

## Benefit 18: SB Adds Documentation Governance

### Plain GSD

GSD owns `.planning/` artifacts. It does not provide SB's complete docs governance scheme for durable project docs, public docs, knowledge, lessons, and task-level doc checklists.

### Silver Bullet addition

SB adds:

- `docs/doc-scheme.md`
- `docs/doc-scheme.json`
- `docs/task-doc-checklist.json`
- `/silver:ensure-docs`
- brownfield doc reconciliation
- archive-move policy
- mandatory doc update semantics for medium and large tasks
- hook-gap remediation path
- instruction-file creation guard, so SB does not create unnecessary root `CLAUDE.md` or `AGENTS.md` instruction surfaces during Codex initialization

### Practical benefit

SB makes documentation part of delivery, not an afterthought. This is especially useful when agentic work touches architecture, tests, deployment, public README content, release notes, or long-lived operational knowledge.

---

## Benefit 19: SB Adds Explicit Non-Skippable Gates

### Plain GSD

Plain GSD has required workflow steps in practice, but SB formalizes which gates cannot be waived through preferences or step-skip requests.

### Silver Bullet addition

SB marks these as non-skippable in its workflow model:

- security gates for relevant work
- quality gates before shipping
- GSD verification
- required review loops
- release quality gates
- UAT/spec gates before milestone completion
- artifact ingestion manifest review
- acceptance-criteria coverage validation

### Practical benefit

SB gives the operator a clear policy boundary. Some steps can be made lightweight; critical gates must still run.

---

## Near-Term Follow-Ups

### Generic Release Gate

The 4-stage pre-release quality gate should be generalized beyond Claude/Codex plugin releases. The current report treats it as a proven capability for this repository and a release-gate architecture pattern for downstream projects, not as a fully generic SB benefit yet.

### Contextual User Guidance

User-facing guidance should not be counted as a current SB-over-GSD benefit unless SB provides that guidance contextually while work proceeds.

Static workflow docs are useful reference material, but they are not enough. The stronger product behavior would be:

- At each workflow transition, explain what is happening now and why.
- Before invoking a major GSD or plugin step, explain what artifact or evidence it should produce.
- When a gate blocks, explain the missing requirement and the shortest safe recovery path.
- After a step completes, summarize what changed, what evidence was produced, and what the next step is.
- Adapt the explanation to the active composed workflow instead of printing a generic fixed workflow script.

This should be treated as immediate follow-up work after this report: add contextual, on-the-fly user guidance to SB's workflow execution rather than relying on users to read static workflow documentation.

---

## Codebase Gap Analysis Updates

The follow-up codebase pass found several SB capabilities that the earlier report either missed or mentioned too weakly. The report has been updated to account for these surfaces.

| Codebase surface | Gap in prior report | Report update |
|---|---|---|
| `skills/silver-spec`, `skills/silver-ingest`, `skills/silver-validate` | Requirements/spec work was treated as incidental to GSD rather than an SB-owned contract layer | Added Benefit 4 for spec elicitation, external artifact ingestion, pre-build validation, and machine-readable validation findings |
| `hooks/spec-floor-check.sh`, `hooks/uat-gate.sh` | Spec floor and UAT freshness were only implied under non-skippable gates | Added them to Benefit 4 and Benefit 19 as concrete hard gates |
| `hooks/spec-session-record.sh`, `hooks/pr-traceability.sh` | PR/spec traceability was missing | Added Benefit 10 for spec session capture, PR traceability blocks, deferred validation warnings, and `SPEC.md` implementation links |
| `hooks/phase-archive.sh` | Phase clearing data-loss protection was missing | Added Benefit 10 for planning artifact preservation before `gsd-tools phases clear` |
| `skills/artifact-reviewer`, `skills/artifact-review-assessor`, `skills/silver-review-stats` | Artifact review was collapsed into one sentence under artifact consistency | Added Benefit 11 for reviewer orchestration, two-pass loops, triage, audit trails, and review analytics |
| `hooks/workflow-chain-guard.sh`, `hooks/dependency-skill-check.sh` | Composed workflow dependency enforcement was underrepresented | Expanded Benefit 1 and Benefit 3 to cover admission/dependency gates and fail-closed plugin dependency behavior |
| `hooks/session-log-init.sh`, `hooks/timeout-check.sh`, `hooks/debug-dump.sh` | Session supervision was described conceptually but not tied to concrete hooks | Expanded Benefit 13 and Benefit 14 with session logs, timeout sentinels, anti-stall warnings, and hook-payload debugging |
| `hooks/trivial-file-guard.sh`, `hooks/instruction-file-guard.sh` | Legacy bypass and instruction-surface guards were missing | Expanded Benefit 9, Benefit 16, and Benefit 18 |
| `hooks/ensure-model-routing.sh` | Could be mistaken for an active runtime-routing benefit | Explicitly not counted: it is a disabled safe no-op stub and should not be used to claim an SB-over-GSD benefit |
| `skills/silver-init`, `skills/silver-migrate`, `skills/silver-update` | Setup/update ergonomics could be overstated as a runtime/packaging benefit | Not promoted as a main benefit because user value here is installation and migration support, not a distinct delivery advantage over plain GSD |

---

## Benefit Summary Table

| Benefit | Plain GSD limitation | SB addition | Operational value |
|---|---|---|---|
| Enforcement hooks | Relies more on agent/operator discipline | Blocks unsafe edits and delivery actions | Fewer skipped steps |
| Dynamic workflow composition | `gsd:do` handles GSD freeform delegation, but not full multi-plugin flow selection | `/silver` classifies intent and composes a task-specific flow chain | Right-sized process for each task |
| Cross-plugin orchestration | GSD does not own other plugins | Sequences SB gates and selected helper plugins around GSD | Full SDLC coverage |
| Spec, ingestion, validation, UAT | GSD can execute plans but does not own SB's spec-first traceability layer | `SPEC.md`, `REQUIREMENTS.md`, `INGESTION_MANIFEST.md`, `VALIDATION.md`, and `UAT.md` gates | Better requirements-to-implementation coverage |
| Quality gates | Not SB-style cross-cutting gates | 9 product dimensions, 7 IaC dimensions | Better design before code |
| Test freshness | Verification can become stale after edits | `/verify-tests` marker invalidated on source changes | Safer final delivery |
| Release governance | GSD can ship/complete milestones | Release-gate architecture; full 4-stage gate currently proven for this plugin project | Safer release readiness checks |
| DevOps safety | GSD can execute infra tasks | Blast radius, promotion, incident path | Lower production risk |
| Artifact protection | Files and state can be edited directly | Planning, state, trivial-bypass, instruction, and plugin-boundary guards | Less state corruption |
| Traceability and preservation | Artifact drift and phase-clear data loss are possible | Roadmap freshness, PR traceability, spec implementation links, phase archive | More reliable milestone and PR evidence |
| Artifact review governance | Artifact review is not a general analytics-backed framework | Reviewer orchestration, assessor triage, review rounds, review analytics | Higher-quality specs and planning artifacts |
| Knowledge capture | Planning memory is not session memory | Issues, lessons, knowledge, scans, handoff | Better continuity |
| Session forensics | GSD focuses on workflow artifacts | SB handles stalls, hooks, timeouts, wrong output | Better failure analysis |
| Prompt and stall reinforcement | Long sessions can drift or loop | Missing-skill reminders, semantic compression, session logs, anti-stall warnings | Better process recall and fewer abandoned sessions |
| Compliance visibility | Need to inspect state | Progress on every tool use | Clear next action |
| Safe fast path | Fast work can become bypass work | `silver:fast` route to `gsd-fast` | Lightweight but governed |
| Multi-runtime coordination | No SB phase-lock model | Phase locks and runtime identities | Safer parallel host use |
| Docs governance | `.planning/` is not durable docs policy | doc scheme, checklist, ensure-docs | Docs stay current |
| Explicit non-skippable gates | Waivers can blur critical boundaries | Hard policy gates for security, quality, validation, review, UAT, and release | Clear stop points |

---

## Persona-Level Benefits

### For The User Or Product Owner

SB means the user can ask for work at the task level and have SB compose the right workflow chain around GSD. It also gives confidence that review, testing, docs, release, and deployment gates have actually run.

Most valuable SB benefits:

- task-specific workflow composition
- spec, acceptance criteria, UAT, and PR traceability
- visible progress and missing-step reporting
- non-skippable verification
- issue/backlog capture
- release readiness checks and GitHub Release support

### For The Agent

SB reduces ambiguity. It tells the agent what workflow applies, which steps are next, which gates are missing, and which plugin owns each responsibility.

Most valuable SB benefits:

- composed workflow files
- prompt reminders
- compliance status
- forbidden-skill gate
- plugin ownership rules
- direct-edit guards for GSD artifacts
- workflow dependency/admission gates that explain which prerequisite is missing

### For The Maintainer

SB creates an audit trail and keeps project surfaces aligned.

Most valuable SB benefits:

- docs governance
- release-gate architecture
- cross-artifact reviews
- artifact-review analytics
- PR/spec traceability
- phase archive protection
- live runtime matrix for SB/plugin releases
- session forensics
- roadmap freshness

### For DevOps/Infrastructure Operators

SB adds production-safety practices around GSD execution.

Most valuable SB benefits:

- blast-radius assessment
- incident fast path
- environment promotion
- deployment checklist
- rollback/runbook/CAB gates
- CI-red blocking

---

## When Plain GSD Is Probably Enough

Plain GSD may be sufficient when:

- the user already knows the GSD workflow well
- the task is fully contained within normal GSD planning/execution/verification
- the repo does not need hook-enforced compliance
- the team is comfortable manually enforcing review, docs, release, and CI gates
- there is no DevOps production-risk component
- the work is exploratory or local-only and will not be shipped

In that case, SB adds process weight that may not be necessary.

---

## When SB Adds Clear Value

SB is materially useful when:

- the project is shipping user-facing software
- multiple agents or long sessions are involved
- process drift has caused skipped tests, review, or docs before
- a user wants task-specific workflow composition instead of manually choosing every lifecycle step
- requirements should trace from spec to plan, validation, UAT, PR, and implementation records
- release quality matters
- DevOps or production infrastructure is in scope
- spec, requirements, design, roadmap, UAT, or ingestion artifacts need formal review
- documentation freshness matters
- CI, PR, deploy, and release actions should be gated
- the team wants durable knowledge and session handoff capture
- the host runtime supports hooks

---

## Important Limitation: SB Depends On Hook-Capable Runtimes

SB's strongest benefits come from host runtime hooks. If the host environment does not fire `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStop`, and `UserPromptSubmit` hooks, SB loses much of its mechanical enforcement.

In those contexts, SB may still provide workflow guidance, but the hard gates become advisory or require manual marker handling. Releases should be run from a hook-capable CLI runtime.

This limitation matters because it narrows the environments where SB's "cannot silently skip" claim is fully true.

---

## Strategic Interpretation

The best positioning is:

> GSD is the engine. Silver Bullet is the enforced operating system around the engine.

More specifically:

- GSD decides how to break work down and execute it.
- SB decides which lifecycle route applies, which gates are required, and whether the session is allowed to proceed.
- GSD produces project execution artifacts.
- SB verifies that the expected process happened and adds adjacent SDLC artifacts.
- GSD prevents context rot in execution units.
- SB prevents process rot across the full session.

This makes SB valuable not because it is "better GSD," but because it solves a different problem: **workflow compliance for agentic software delivery.**

---

## Source Documents Consulted

Primary sources:

- [README.md](../README.md)
- [silver-bullet.md](../silver-bullet.md)
- [docs/sb-vs-gsd.md](sb-vs-gsd.md)
- [docs/gsd-vs-silver-bullet.md](gsd-vs-silver-bullet.md)
- [docs/sb-without-gsd.md](sb-without-gsd.md)
- [docs/ENFORCEMENT.md](ENFORCEMENT.md)
- [docs/composable-flows-contracts.md](composable-flows-contracts.md)
- [docs/PLUGIN-BOUNDARIES.md](PLUGIN-BOUNDARIES.md)
- [docs/SDLC-MAP.md](SDLC-MAP.md)
- [docs/workflows/full-dev-cycle.md](workflows/full-dev-cycle.md)
- [docs/workflows/devops-cycle.md](workflows/devops-cycle.md)
- [docs/doc-scheme.md](doc-scheme.md)
- [docs/TESTING.md](TESTING.md)
- [docs/RELEASE.md](RELEASE.md)
- [docs/RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md)
- [docs/multi-agent-coordination.md](multi-agent-coordination.md)
- [docs/internal/gsd2-vs-sb-gap-analysis.md](internal/gsd2-vs-sb-gap-analysis.md)
- [docs/internal/sdlc-gap-analysis.md](internal/sdlc-gap-analysis.md)
- [docs/internal/SDLC-Coverage-Roadmap.md](internal/SDLC-Coverage-Roadmap.md)
- [docs/internal/pre-release-quality-gate.md](internal/pre-release-quality-gate.md)

Supporting source:

- [docs/internal/sb-vs-gsd-vs-superpowers.xlsx](internal/sb-vs-gsd-vs-superpowers.xlsx)

Codebase surfaces consulted in the gap pass:

- [commands/silver.md](../commands/silver.md)
- [commands/feature.md](../commands/feature.md)
- [commands/quality-gates.md](../commands/quality-gates.md)
- [hooks/dev-cycle-check.sh](../hooks/dev-cycle-check.sh)
- [hooks/completion-audit.sh](../hooks/completion-audit.sh)
- [hooks/workflow-chain-guard.sh](../hooks/workflow-chain-guard.sh)
- [hooks/dependency-skill-check.sh](../hooks/dependency-skill-check.sh)
- [hooks/spec-floor-check.sh](../hooks/spec-floor-check.sh)
- [hooks/uat-gate.sh](../hooks/uat-gate.sh)
- [hooks/spec-session-record.sh](../hooks/spec-session-record.sh)
- [hooks/pr-traceability.sh](../hooks/pr-traceability.sh)
- [hooks/phase-archive.sh](../hooks/phase-archive.sh)
- [hooks/session-log-init.sh](../hooks/session-log-init.sh)
- [hooks/timeout-check.sh](../hooks/timeout-check.sh)
- [hooks/debug-dump.sh](../hooks/debug-dump.sh)
- [hooks/trivial-file-guard.sh](../hooks/trivial-file-guard.sh)
- [hooks/instruction-file-guard.sh](../hooks/instruction-file-guard.sh)
- [hooks/ensure-model-routing.sh](../hooks/ensure-model-routing.sh)
- [skills/silver-spec/SKILL.md](../skills/silver-spec/SKILL.md)
- [skills/silver-ingest/SKILL.md](../skills/silver-ingest/SKILL.md)
- [skills/silver-validate/SKILL.md](../skills/silver-validate/SKILL.md)
- [skills/artifact-reviewer/SKILL.md](../skills/artifact-reviewer/SKILL.md)
- [skills/artifact-review-assessor/SKILL.md](../skills/artifact-review-assessor/SKILL.md)
- [skills/silver-review-stats/SKILL.md](../skills/silver-review-stats/SKILL.md)
- [skills/ai-llm-safety/SKILL.md](../skills/ai-llm-safety/SKILL.md)

---

## Final Answer

Silver Bullet provides concrete benefits over plain GSD by enforcing and orchestrating the broader SDLC around GSD. The most defensible claim is not that SB executes better than GSD. It is that SB makes GSD-backed work safer, more traceable, more complete, more governed, more auditable, and harder to accidentally ship before the necessary spec, validation, UAT, quality, review, test, documentation, CI, DevOps, and release gates have run.
