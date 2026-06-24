# SB vs AS1 Analysis

**Date:** 2026-06-14 (parity closure pass)
**Scope:** Public AS1 product site, public AS1 skill directory, public AS1 repository overview, and current SB repository state.
**Naming constraint:** This document uses the alias `AS1` for the external reference product. Implementation surfaces must not use the external product name.
**Runtime parity:** Phase 056 implemented — scripts, hook gates, and tests on `main` enforce structural contracts documented in v0.39.2.

**Parity status:** SB is a functional superset for the capability families in the ledger below. Structural parity contracts (evidence schema, backlog fingerprinting, interface state, external-review policy, code-intelligence tiers, install diagnostics) are **runtime-enforced** via phase 056 scripts and delivery gates — see [Parity Closure Evidence](#parity-closure-evidence).

## Executive Summary

AS1 is positioned as a broad, auto-routing quality layer for AI coding agents. Its strongest differentiator is breadth: many specialized skills, role-based multi-agent execution, detailed production/test quality gates, domain-specific audits, project memory, session recovery, and post-deploy monitoring surfaces.

SB is positioned as an agentic process orchestrator. Its strongest differentiator is enforceability: hook-backed workflow gates, spec-to-release artifact governance, completion audits, CI and UAT blocking, release discipline, documentation scheme enforcement, and package-boundary controls.

The most valuable direction for SB is not to clone AS1's many individual command surfaces. SB should remain the orchestrator and become a superset by adding explicit, SB-owned domain quality contracts that can be selected by `/silver` and enforced inside existing SB flows. This gives SB AS1-style breadth while preserving SB's stronger lifecycle, evidence, artifact, and release governance.

## Superset Parity Ledger

The stricter goal is that an AS1 user should not lose a feature, capability, or benefit when moving to SB. SB meets that goal by providing SB-owned routes and evidence artifacts rather than one-command-per-feature clones.

| AS1 capability family | SB-owned route or contract | Evidence artifact | Parity status |
|---|---|---|---|
| Brainstorm/problem exploration | `silver:clarify`, `silver:research`, `silver:scan` | `.planning/CLARIFY.md`, research/context artifacts | Superset: SB adds lifecycle handoff and traceability |
| Plan/TDD task decomposition | `silver:context`, `silver:plan`, `tdd`, `testability` | PLAN, context, TDD evidence | Superset: SB gates plan before execution |
| Execute with review gates | `silver:execute`, `silver:review`, `silver:review-triage`, `silver:verify` | SUMMARY, REVIEW, VERIFICATION | Superset: SB adds completion-audit and hook-backed markers |
| Worktree isolation and finish | `silver:worktree`, `silver:branch-finish`, `silver:ship` | `.planning/WORKTREE.md`, branch-finish/ship evidence | Covered by new SB route |
| Review feedback response | `silver:review-triage` | REVIEW triage notes | Superset: SB rejects weak findings and requires evidence |
| Scoped small feature build | `silver:fast`, `silver:feature` | fast/feature workflow artifacts | Covered |
| Refactoring with baseline proof | `silver:refactor`, `silver:test`, `silver:verify` | `.planning/REFACTOR.md`, test evidence | Covered by new SB route |
| Debug/root cause | `silver:debug`, `silver:bugfix`, `silver:forensics` | DEBUG/forensics/bugfix artifacts | Superset: SB includes session-level forensics |
| Test writing | `silver:test --mode write` | `.planning/TEST-ENGINEERING.md` | Covered by new SB route |
| E2E route discovery | `silver:test --mode e2e`, `silver:ui-review` | route inventory, Playwright/browser evidence | Covered by new SB route |
| Test repair | `silver:test --mode repair`, `silver:verify` | anti-pattern triage and verification | Covered by new SB route |
| Test audit | `silver:test --mode audit`, `silver:domain-audit --pack test-health` | DOMAIN-AUDIT / TEST-ENGINEERING | Superset: normalized SB findings feed ship gates |
| Test performance | `silver:test --mode performance`, `performance-resource` pack | timing baseline and compare evidence | Covered by new SB route |
| Mutation-style test challenge | `silver:test --mode mutation` | mutation plan/result/follow-up | Covered by new SB route |
| Application security audit | `silver:secure`, `security`, domain packs | `.planning/SECURITY.md`, DOMAIN-AUDIT | Superset: process and release security gates included |
| Penetration-test-style checks | `silver:secure` authorized live/static mode | SECURITY with exact command/evidence | Covered inside security contract |
| Accessibility audit | `silver:ui-review`, `silver:domain-audit --pack accessibility` | UI-REVIEW / DOMAIN-AUDIT | Covered |
| Code audit | `silver:domain-audit --pack code-health`, `silver:review` | DOMAIN-AUDIT / REVIEW | Superset: findings route to owning workflow |
| API audit | `silver:domain-audit --pack api-contract` | DOMAIN-AUDIT | Covered |
| Database/data audit | `silver:domain-audit --pack data-contract` | DOMAIN-AUDIT | Covered |
| Dependency audit | `silver:domain-audit --pack dependency-supply`, `silver:secure` | DOMAIN-AUDIT / SECURITY | Covered |
| Performance audit | `silver:domain-audit --pack performance-resource` | DOMAIN-AUDIT | Covered |
| Structure audit | `silver:domain-audit --pack structure-maintainability` | DOMAIN-AUDIT | Covered |
| CI audit | `silver:domain-audit --pack ci-workflow`, `devops-quality-gates` | DOMAIN-AUDIT / DevOps gate artifact | Superset for DevOps scope |
| Environment/secrets audit | `silver:domain-audit --pack environment-secrets`, `silver:secure` | DOMAIN-AUDIT / SECURITY | Covered |
| SEO/GEO/search audit and fixes | `silver:content`, `content-search` pack | `.planning/CONTENT.md`, DOMAIN-AUDIT | Covered by new SB route |
| Content audit/fix/migration/optimization | `silver:content` | CONTENT, docs/build/link evidence | Covered by new SB route |
| Article/help content writing | `silver:content --mode write` | CONTENT with sources/frontmatter/review | Covered by new SB route |
| Design and design review | `silver:ui`, `silver:ui-contract`, `silver:ui-review` | UI-SPEC, UI-REVIEW | Superset through UI lifecycle gates |
| Durable design/interface state | `silver:ui-contract`, `silver:ui-review` | `.planning/interface/STATE.md` | Covered by updated SB UI contract |
| Architecture review/ADR | `silver:research`, `silver:domain-audit --pack architecture-adr` | decision artifact / DOMAIN-AUDIT | Covered |
| Ship/pre-merge release path | `silver:ship`, `silver:release`, `silver:create-release` | ship/release artifacts and GitHub Release | Superset: stronger release governance |
| Platform-aware deployment | `silver:deploy`, `silver:devops` | `.planning/DEPLOYMENT.md` | Covered by new SB route |
| Post-deploy canary | `silver:canary` | `.planning/CANARY.md` | Covered by new SB route |
| Release documentation sync | `silver:ensure-docs`, `silver:release` | docs checklist, changelog, release summary | Superset: governed doc scheme |
| Engineering retrospective | `silver:retro` | `.planning/RETRO.md` | Covered by new SB route |
| Docs utility | `silver:ensure-docs`, `silver:content` | governed docs/content artifacts | Superset for project docs |
| Backlog/deferred work | `silver:add`, `silver:remove`, domain-audit backlog decisions | GitHub/local issue ID | Superset when configured with GitHub project |
| Incident workflow | `silver:incident`, `silver:forensics`, `silver:canary` | `.planning/INCIDENT.md` | Covered by new SB route |
| Provider/task benchmark | `silver:benchmark` | `.planning/BENCHMARK.md` | Covered by new SB route |
| Agent self-quality benchmark | `silver:benchmark`, `silver:review-fix-ladder` | BENCHMARK / review loop evidence | Covered |
| Knowledge store/project memory | docs/knowledge, docs/learnings, Graphify retrieval, session logs | monthly knowledge/learnings and graph evidence | Superset: SB separates project knowledge from portable learnings |
| Session recovery | `silver:handoff`, workflow tracker, session logs, `silver:forensics` | handoff and `.planning/workflows/` state | Superset: recovery tied to workflow evidence |
| Cross-provider adversarial review | `silver:review`, optional external enrichment, `silver:benchmark` | REVIEW / BENCHMARK | Superset when optional providers are installed; SB review remains authoritative |
| Code intelligence | `silver:scan`, Graphify retrieval, direct shell/file evidence | scan/context artifacts | Covered with explicit fallback tiers |
| Auto-routing benefit | `/silver` router plus prompt reminders and skill tracking | route banner, requested skill markers | Covered with more auditable activation discipline |
| Stack-aware rules | `silver:domain-audit`, `devops-quality-gates`, `verify-tests` | selected pack and command evidence | Covered |
| Evidence requirements | all SB workflows, completion audit, domain evidence schema | artifacts, command output, markers | Superset: completion remains unproven until audited |

## High-Level Strengths: AS1 Compared To SB

1. **Broader visible skill catalog.**
   AS1 exposes a large catalog across pipeline, development, testing, security, audits, release, design, and utility work. SB has broad lifecycle coverage, but many specialized checks are folded into generic review/security/quality gates and are less discoverable.

2. **Clear domain-specific audit taxonomy.**
   AS1 names discrete audit modes for API, database, dependency, performance, structure, CI, environment configuration, SEO, GEO, content quality, accessibility, design, and architecture. SB has comparable concerns scattered across quality dimensions, DevOps gates, docs, security, UI, and release workflows, but not a single domain-audit menu.

3. **Detailed production-code and test-code gate vocabulary.**
   AS1 advertises separate code-quality and test-quality gate catalogs, critical blockers, scoring thresholds, evidence rules, and anti-pattern families. SB has quality dimension skills and review gates, but fewer named file-level rules for production code and test code.

4. **Strong test-specialization surface.**
   AS1 separately covers test writing, E2E generation, test repair, test audit, test performance, and mutation testing. SB has TDD, verify-tests, verification, and testability gates, but lacks explicit mutation-test, test performance, and anti-pattern repair workflows.

5. **Multi-agent pipeline is simple to explain.**
   AS1 markets a three-phase pipeline with named agent roles for exploration, planning, and execution. SB has richer flow composition, but the mental model is more complex.

6. **Fast-path feature build command is explicit.**
   AS1 distinguishes small scoped build work from its full pipeline. SB has `silver:fast` and workflow composition, but the small-feature path is less visibly defined as "scoped build with bounded audits."

7. **Backlog persistence is first-class.**
   AS1 advertises a tech-debt backlog used by audit and review skills. SB has `silver:add`, issue/backlog capture, ROADMAP integration, and docs/issues, but the audit-to-backlog loop is less productized.

8. **Session recovery is a named product feature.**
   AS1 advertises persisted context and resume behavior. SB has session logs, handoff, workflow tracker files, anti-stall hooks, and forensics, but recovery is described as part of process governance rather than a user-facing feature.

9. **Cross-provider adversarial review is prominent.**
   AS1 explicitly advertises Codex, Gemini, Cursor Agent, and Claude review diversity. SB permits external second-opinion reviewers and MultiAI-like augmentation only when requested, but this is not exposed as a first-class review mode.

10. **Code intelligence dependency is concrete.**
    AS1 names semantic search, call-chain tracing, complexity analysis, module detection, duplicate detection, and community detection as optional code-intelligence enhancements. SB uses Graphify retrieval and semantic compression, but the current public/product story is less explicit about available code-intelligence operations.

11. **Platform support is presented as adaptive execution.**
    AS1 describes Claude Code, Codex, and Cursor support with different execution strategies. SB supports Claude Code, Codex, and Kay testing, but Cursor/opencode adaptation is not a core product surface.

12. **Release-to-production continuation is explicit.**
    AS1 connects ship, deploy, canary, release-docs, retro, and incident workflows. SB has stronger release gates and DevOps workflow discipline, but lacks a named post-deploy canary and periodic retrospective command.

13. **Content/SEO/GEO surface is broader.**
    AS1 includes content audit/fix, content migration, content optimization, article writing, SEO, and GEO. SB has documentation governance and docs update/ensure flows, but not a full content quality and search-readiness suite.

14. **Design system persistence is explicit.**
    AS1 has a dedicated design-system state directory and design review team. SB has UI contract, UI review, design-system audit expectations, and handoff, but no explicit persisted interface-design state artifact.

15. **Auto-routing is marketed as always-on.**
    AS1 positions routing as session-start behavior. SB routes through `/silver` and commands; hooks remind and enforce, but always-on natural language auto-activation is intentionally more conservative.

16. **Install story is very short.**
    AS1 markets a one-script install and marketplace install path. SB's install is more precise and safer, but the explanation includes more moving parts: jq, Graphify, marketplace/package modes, project init, optional DevOps plugins, and live-test tooling.

17. **Rules are branded by count and category.**
    AS1 uses visible counts for skills, agents, gates, stacks, checks, and categories. SB has a stronger SDLC map and enforcement layers but fewer memorable numeric product anchors.

18. **Runtime outputs are strongly standardized around scores.**
    AS1 advertises tiered grades, confidence bands, and thresholds. SB uses BLOCK/WARN/INFO, PASS/FAIL, and artifacts, but not a unified numeric scoring system across all audits.

19. **Domain-specific fix skills are paired with audits.**
    AS1 pairs several audits with fix modes. SB has review triage, execute loops, and gap closure, but fix automation is routed through lifecycle execution rather than named "audit-fix" commands for each domain.

20. **Benchmarking is a product surface.**
    AS1 includes provider benchmark and agent self-benchmark workflows. SB has live matrices and release verification, but not a user-facing benchmark command for comparing coding agents on a task.

## High-Level Weaknesses: AS1 Compared To SB

1. **Breadth risks fragmentation.**
   A large skill catalog can create overlapping routes, inconsistent artifacts, and route ambiguity. SB's smaller orchestration surface keeps lifecycle ownership centralized.

2. **Quality is broad but may be less mechanically enforced.**
   AS1 advertises quality gates and refusal behavior. SB has explicit hook-backed blocking for tool use, PR/deploy/release commands, UAT, CI, planning floors, completion claims, and unsafe instruction-file edits.

3. **Artifact governance appears narrower.**
   AS1 produces many outputs, but SB has a formal project documentation scheme, artifact reviewer/assessor loops, cross-artifact review, specs, requirements, validation, UAT, session logs, knowledge, learnings, and task doc checklists.

4. **Release gates appear less rigorous than SB's milestone release process.**
   AS1 ships/deploys/canaries, while SB gates releases through quality, UAT audit, milestone audit, security, docs, verification, ship, milestone archive, and release creation.

5. **Security of process is less visible.**
   AS1 emphasizes application security audits. SB adds process security: forbidden-skill checks, dependency-skill checks, instruction-file guards, planning-file guards, CI blockers, and completion-audit enforcement.

6. **Always-on routing may over-activate.**
   A session-start router that auto-selects skills can be convenient, but it can also intervene on trivial or exploratory requests. SB's explicit `/silver` entry point is more predictable and easier to audit.

7. **Model/provider complexity can become operational burden.**
   Cross-provider review improves coverage but increases installation, authentication, cost, and failure modes. SB treats external providers as optional enrichment rather than default lifecycle dependency.

8. **Extensive audit/fix modes may encourage tool-shaped work.**
   AS1's many named modes can optimize for running a specialized command instead of maintaining one coherent SDLC artifact chain. SB keeps work connected through SPEC, REQUIREMENTS, CONTEXT, PLAN, REVIEW, SECURITY, VERIFICATION, UAT, docs, and release artifacts.

9. **Quality gate claims depend on agents following instructions.**
   Unless every gate is backed by runtime hooks, an agent can technically skip or under-apply a rule. SB's major differentiator is that many required process steps are externally recorded and mechanically checked.

10. **Project mutation paths are broader.**
    AS1 writes backlog, design state, docs, content, specs, and context. SB is stricter about SB-owned planning artifacts, direct-edit guards, and controlled project scaffolding.

11. **Open-source maturity signals are mixed.**
    AS1 has visible commits and tags but a small public GitHub signal. SB has a longer local release/governance history and a deeper test/hook suite.

12. **DevOps governance is narrower than SB's blast-radius model.**
    AS1 deploy/canary flows are useful, but SB's DevOps lifecycle includes blast radius, IaC-specific quality gates, security, environment promotion, rollback, docs, CI, verification, and ship sequencing.

13. **Compatibility claims are broader than proven parity.**
    AS1 describes support across multiple runtimes with adaptive execution. SB's Codex support is narrower but backed by explicit package boundaries, native command packaging, install tests, and live harnesses.

14. **Task evidence may not equal requirement traceability.**
    AS1 demands evidence for claims. SB ties evidence back to accepted requirements, validation, UAT, review, and release artifacts.

15. **Pipeline is less composable than SB's flow catalog.**
    AS1's full pipeline is easy to understand, but SB's canonical AF-* catalog can shape different paths for feature, bugfix, UI, DevOps, research, release, fast path, debug, docs, and forensics.

16. **Domain fix automation can be risky.**
    Audit-to-fix flows need strong safety tiers and rollback. SB's stricter execute/verify/review/ship cycle is slower but safer for shared codebases.

17. **External code-intelligence dependency may become a soft requirement.**
    AS1 degrades without its code-intelligence MCP. SB's Graphify and shell-based scans are useful but SB is less dependent on one code-intelligence engine for core lifecycle enforcement.

18. **The product may be optimized for command breadth over process accountability.**
    SB's value proposition is accountability: every lifecycle claim should have a corresponding artifact, marker, command output, or gate.

## High-Level Strengths: SB Compared To AS1

1. **Stronger hook-backed enforcement.**
   SB records requested routes and completed skill markers, then blocks unsafe edits, PRs, deploys, releases, and completion claims when required evidence is missing.

2. **Spec-to-release traceability.**
   SB connects clarification, specs, requirements, validation, planning, execution, review, security, verification, UAT, docs, ship, and release.

3. **Composable workflow model.**
   SB's canonical AF-* catalog lets the orchestrator assemble only the flows required for the task.

4. **Release governance is deeper.**
   SB owns milestone audit, UAT audit, release gap closure, docs gates, ship readiness, milestone archive, changelog, tag, and GitHub Release creation.

5. **Documentation is a governed artifact.**
   SB ships a bounded documentation scheme, task documentation checklist, docs freshness checks, knowledge/learnings split, and docs recovery workflow.

6. **DevOps workflow is risk-first.**
   SB has a separate DevOps lifecycle with blast radius, IaC quality gates, security, rollback, promotion, observability, and release integration.

7. **Artifact review has assessor discipline.**
   SB separates artifact review from over-zealous finding triage, classifying findings by artifact contract.

8. **Completion claims are independently audited.**
   SB treats completion as unproven until evidence covers the actual objective.

9. **CI and PR traceability are first-class gates.**
   SB blocks red CI in critical paths and requires PR/release traceability.

10. **Instruction and planning files are protected.**
    SB has guards for direct edits to planning files and unsafe instruction-file creation.

11. **Project initialization is comprehensive.**
    SB bootstraps instructions, config, docs, hooks, templates, and project state.

12. **SB has a clear optional-extension boundary.**
    Optional plugins enrich domains but do not own the lifecycle.

13. **SB is less dependent on external provider routing.**
    Host model selection and optional provider tools stay outside SB's core lifecycle.

14. **Forensics and handoff are mature.**
    SB has explicit workflows for failed sessions, unclear state, and continuation.

15. **Packaging is boundary-aware.**
    SB's Codex package hides source internals, avoids vendoring dependency plugins, and keeps optional extensions separate.

16. **Live testing and release gates are strong.**
    SB includes release live matrices, e2e-live scenarios, hook tests, script tests, integration tests, and site/content freshness gates.

17. **SB has an explicit non-skippable gate doctrine.**
    Certain checks cannot be waived by preferences or step-skip requests.

18. **SB's process works across project types.**
    The same lifecycle governs applications, CLIs, plugins, docs-heavy projects, DevOps, and release work.

19. **SB favors evidence over agent confidence.**
    Verification checks artifacts and outputs rather than trusting the agent's own summary.

20. **SB's smaller public command set is easier to teach.**
    `/silver` plus task-specific SB commands is less intimidating than a very large skill menu.

## High-Level Weaknesses: SB Compared To AS1

Historical gaps from the 2026-06-12 analysis and their current SB posture:

1. **Specialized audit breadth is under-exposed.** Addressed — `silver:domain-audit` pack matrix and site capability matrix.
2. **File-level quality rule vocabulary is less concrete.** Addressed — domain critical gate catalog in `silver:domain-audit`.
3. **Test ecosystem coverage is thinner.** Addressed — `silver:test` modes (write, e2e, repair, audit, performance, mutation).
4. **Post-deploy monitoring is partial.** Addressed — `silver:canary` and `runtime-release` pack.
5. **Backlog persistence is not as productized.** Addressed — `silver:add` structured audit intake with fingerprint, dedup, and prioritization score (`skills/silver-add/SKILL.md`).
6. **Session recovery is less visibly packaged.** Addressed — `silver:handoff`, workflow tracker, `silver:scan`, `silver:forensics`; public help surfaces document recovery.
7. **Cross-provider adversarial review is optional and under-documented.** Addressed — `docs/external-review-policy.md`; SB review remains authoritative.
8. **Design-state persistence is weaker.** Addressed — `.planning/interface/STATE.md` via `silver:ui-contract` / `silver:ui-review` and `templates/interface/STATE.md.base`.
9. **Content/search readiness is narrower.** Addressed — `silver:content` and `content-search` pack.
10. **Architecture review is not a first-class public skill.** Addressed — `architecture-adr` pack and research/plan integration.
11. **Provider/runtime benchmarking is not a user-facing capability.** Addressed — `silver:benchmark` and `benchmark-eval` pack.
12. **Stack-aware defaults are less explicit.** Partially addressed — domain packs, `verify-tests`, and DevOps gates; stack rules remain host/project specific.
13. **Install story is heavier.** Addressed for diagnostics — `scripts/sb-diagnostics.sh` and runtime tier docs in `docs/RUNTIME-COMPATIBILITY.md`; install remains intentionally explicit for safety.
14. **Public docs still carry historical dependency language outside the cleaned website/help surfaces.** Ongoing hygiene — website/help are clean; repo docs may still mention legacy plugins in historical specs.
15. **Quality-gate output is less normalized across domains.** Addressed — `docs/evidence-schema.md` shared across domain audit, quality gates, review, test, and UI review.

## Parity Closure Evidence

| Structural contract | Runtime evidence in repository |
|---|---|
| Cross-domain evidence schema | `docs/evidence-schema.md`; `scripts/validate-evidence-findings.{py,sh}`; `hooks/lib/evidence-schema-gate.sh` + `completion-audit.sh` delivery gate; `tests/scripts/test-validate-evidence-findings.sh`; `tests/hooks/test-completion-audit.sh` (tests 24–25) |
| Backlog fingerprinting and prioritization | `scripts/lib/evidence_common.py`; `scripts/silver-add.sh` (`fingerprint`, `dedup`, `prioritize`); `scripts/silver-scan.py` shared `scan_fingerprint`; `tests/scripts/test-silver-add-fingerprint.sh` |
| Durable interface/design state | `templates/interface/STATE.md.base`; `scripts/stamp-interface-state.sh`; `silver:init` step 3.2.1; `tests/scripts/test-stamp-interface-state.sh` |
| External-review policy | `docs/external-review-policy.md`; `silver:review`, `silver-bullet.md` §6 |
| Code-intelligence contract | `docs/code-intelligence-contract.md`; `silver:scan`, Graphify docs |
| Install/update diagnostics and runtime tiers | `scripts/sb-diagnostics.sh`, `scripts/sb-bootstrap.sh`; `tests/scripts/test-sb-diagnostics.sh`, `tests/scripts/test-sb-bootstrap.sh`; `docs/RUNTIME-COMPATIBILITY.md` |

## Mutual Gaps And Opportunities (Historical Analysis)

The items below were the 2026-06-12 gap map. Each now has an SB-owned contract
or route; residual work is hygiene (doc drift, optional stack packs), not missing
capability families.

### 1. Domain Quality Contracts — **Closed**

SB exposes `silver:domain-audit` with sixteen packs inside existing workflows.

### 2. Evidence Schema — **Closed**

`docs/evidence-schema.md` standardizes findings across quality surfaces.

### 3. Critical-Gate Semantics — **Closed**

`silver:domain-audit` critical gate catalog uses BLOCK/WARN/INFO plus confidence.

### 4. Test Quality Depth — **Closed**

`silver:test` modes cover audit, E2E discovery, repair, performance, mutation.

### 5. Backlog And Deferred Work — **Closed**

`silver:add` structured audit intake: fingerprint, dedup, prioritization score.

### 6. Post-Deploy Confidence — **Closed**

`silver:canary` and `runtime-release` pack.

### 7. Incident And Retro Loops — **Closed**

`silver:incident`, `silver:retro`, `incident-retro` pack.

### 8. Cross-Provider Review — **Closed**

`docs/external-review-policy.md`; enrichment feeds `REVIEW.md`.

### 9. Code Intelligence — **Closed**

`docs/code-intelligence-contract.md` layered tiers 0–3.

### 10. Design System State — **Closed**

`.planning/interface/STATE.md` template and UI contract/review updates.

### 11. Content And Search Readiness — **Closed**

`silver:content` and `content-search` pack.

### 12. Installation And Update UX — **Closed**

`scripts/sb-diagnostics.sh`; fast path remains init + marketplace install.

### 13. Runtime Compatibility — **Closed**

`docs/RUNTIME-COMPATIBILITY.md` capability tiers 0–3.

### 14. Skill Catalog Discoverability — **Closed**

Site/help capability matrix; `/silver` entry point.

### 15. Auto-Activation Discipline — **By design**

SB keeps explicit `/silver` routing with session reminders rather than silent hijack.

## SB Gap Closure Requirements

Status as of 2026-06-14 — all items below have SB-owned implementation evidence:

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Domain audit capability via packs | Done | `skills/silver-domain-audit/SKILL.md` |
| 2 | Normalized evidence schema | Done | `docs/evidence-schema.md` |
| 3 | Deeper test health surfaces | Done | `skills/silver-test/SKILL.md` |
| 4 | Backlog fingerprinting and prioritization | Done | `skills/silver-add/SKILL.md` |
| 5 | Canary/post-deploy verification | Done | `skills/silver-canary/SKILL.md` |
| 6 | Incident and retrospective artifacts | Done | `skills/silver-incident/SKILL.md`, `skills/silver-retro/SKILL.md` |
| 7 | External review policy | Done | `docs/external-review-policy.md` |
| 8 | Code-intelligence capability tiers | Done | `docs/code-intelligence-contract.md` |
| 9 | UI/interface state artifacts | Done | `templates/interface/STATE.md.base` |
| 10 | Content/search-readiness packs | Done | `skills/silver-content/SKILL.md` |
| 11 | Install diagnostics and runtime docs | Done | `scripts/sb-diagnostics.sh`, `docs/RUNTIME-COMPATIBILITY.md` |
| 12 | Preserve SB enforceability and boundaries | Ongoing invariant | hooks, `silver-bullet.md` §8, completion audit |

SB superiority remains enforceability, artifact traceability, release governance,
and no dependency-plugin ownership leakage — not cloning AS1's per-concern command surface.
