# SB vs AS1 Analysis

**Date:** 2026-06-12
**Scope:** Public AS1 product site, public AS1 skill directory, public AS1 repository overview, and current SB repository state.
**Naming constraint:** This document uses the alias `AS1` for the external reference product. Implementation surfaces must not use the external product name.

## Executive Summary

AS1 is positioned as a broad, auto-routing quality layer for AI coding agents. Its strongest differentiator is breadth: many specialized skills, role-based multi-agent execution, detailed production/test quality gates, domain-specific audits, project memory, session recovery, and post-deploy monitoring surfaces.

SB is positioned as an agentic process orchestrator. Its strongest differentiator is enforceability: hook-backed workflow gates, spec-to-release artifact governance, completion audits, CI and UAT blocking, release discipline, documentation scheme enforcement, and package-boundary controls.

The most valuable direction for SB is not to clone AS1's many individual command surfaces. SB should remain the orchestrator and become a superset by adding explicit, SB-owned domain quality contracts that can be selected by `/silver` and enforced inside existing SB flows. This gives SB AS1-style breadth while preserving SB's stronger lifecycle, evidence, artifact, and release governance.

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
    AS1's full pipeline is easy to understand, but SB's 18-flow catalog can shape different paths for feature, bugfix, UI, DevOps, research, release, fast path, debug, docs, and forensics.

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
   SB's 18-flow catalog lets the orchestrator assemble only the flows required for the task.

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

1. **Specialized audit breadth is under-exposed.**
   SB has quality dimensions but lacks a single discoverable domain-audit matrix for API, DB, dependency, performance, structure, CI, env, SEO/GEO, content, accessibility, and architecture.

2. **File-level quality rule vocabulary is less concrete.**
   SB's quality gates are principled but not as visibly enumerated for production files and test files.

3. **Test ecosystem coverage is thinner.**
   SB lacks explicit mutation testing, test performance audit, E2E generation from route discovery, and test anti-pattern repair surfaces.

4. **Post-deploy monitoring is partial.**
   SB can require verification and DevOps evidence, but does not own a named canary/watch workflow.

5. **Backlog persistence is not as productized.**
   SB captures deferred work, but audit findings do not all flow into a unified deduplicated backlog with prioritization formula.

6. **Session recovery is less visibly packaged.**
   SB has handoff, workflow tracker, logs, and forensics, but not a simple user-facing "resume after compaction/crash" product story.

7. **Cross-provider adversarial review is optional and under-documented.**
   SB can allow second-opinion reviewers but has no first-class mode for provider diversity.

8. **Design-state persistence is weaker.**
   SB has UI contracts and reviews but not a persistent interface design system state artifact.

9. **Content/search readiness is narrower.**
   SB governs docs but not SEO, GEO, content migration, content optimization, article generation, and content fix workflows.

10. **Architecture review is not a first-class public skill.**
    SB handles architecture through context, research, plan, and quality gates, but lacks a named architecture review/ADR mode.

11. **Provider/runtime benchmarking is not a user-facing capability.**
    SB has live tests and release matrices, but not task-level model/provider benchmark reports.

12. **Stack-aware defaults are less explicit.**
    SB detects and verifies through tests/scripts, but user-facing stack rule packs are not as visible.

13. **Install story is heavier.**
    SB's safety and boundary controls make install docs more complex.

14. **Public docs still carry historical dependency language outside the cleaned website/help surfaces.**
    This makes SB's current positioning less crisp in the repository docs.

15. **Quality-gate output is less normalized across domains.**
    SB uses PASS/FAIL and BLOCK/WARN/INFO, but not a single scoring/evidence schema for all domain audits.

## Mutual Gaps And Opportunities

### 1. Domain Quality Contracts

**AS1 gap:** AS1's domain audits are broad, but they are many separate commands and may fragment lifecycle evidence.

**SB gap:** SB does not yet expose all comparable domain audits.

**Better SB direction:** Add an SB-owned `silver:domain-audit` contract layer that selects applicable packs inside existing workflows:

- code health
- test health
- API behavior
- database/data access
- dependency and supply-chain posture
- performance and resource use
- structure and maintainability
- CI/CD workflow health
- environment and secrets posture
- accessibility
- SEO and AI-search readiness
- content quality and migration
- architecture and ADR readiness
- release, deploy, canary, incident, retro evidence

### 2. Evidence Schema

**AS1 gap:** Evidence is visible, but route-specific commands can scatter reports.

**SB gap:** SB evidence exists in many artifacts but lacks one cross-domain schema.

**Better SB direction:** Standardize every SB quality finding as:

- scope
- domain
- severity
- confidence
- evidence pointer
- command output or artifact source
- owner workflow
- blocking status
- backlog decision

### 3. Critical-Gate Semantics

**AS1 gap:** Numeric scoring can look precise while still relying on subjective agent judgment.

**SB gap:** SB lacks a visible file-level critical gate catalog.

**Better SB direction:** Define SB "hard gates" as named invariants per domain and require evidence for every PASS. Use BLOCK/WARN/INFO plus confidence, not numeric theater.

### 4. Test Quality Depth

**AS1 gap:** Many testing commands can be expensive and tool-heavy.

**SB gap:** SB does not yet call out mutation, test runtime performance, test anti-patterns, route-to-E2E generation, or oracle independence as explicit surfaces.

**Better SB direction:** Extend `verify-tests`, `testability`, and `silver:verify` with test health packs:

- meaningful assertion review
- failure-mode and edge-case coverage
- mock boundary checks
- flake risk
- runner performance
- route/user-flow E2E discovery
- mutation-style challenge cases

### 5. Backlog And Deferred Work

**AS1 gap:** Backlog persistence can turn every advisory into noise.

**SB gap:** SB captures deferred work but lacks deduplication, scoring, and audit-wide rollups.

**Better SB direction:** Make `silver:add` accept structured audit findings and dedupe by fingerprint. Score by impact, risk, evidence strength, and effort.

### 6. Post-Deploy Confidence

**AS1 gap:** Canary workflows are useful but can become shallow if they only poll HTTP or screenshots.

**SB gap:** SB release and DevOps verification do not expose a named post-deploy watch stage.

**Better SB direction:** Add `silver:canary` or a RELEASE flow extension that verifies live routes, health endpoints, browser console, logs when available, rollback readiness, and release artifact evidence.

### 7. Incident And Retro Loops

**AS1 gap:** Incident and retro commands need integration with the delivery artifacts to be more than generated reports.

**SB gap:** SB has forensics but not a named incident/postmortem and periodic engineering retro surface.

**Better SB direction:** Extend `silver:forensics` and release docs with:

- incident timeline
- probable cause
- contributing process gap
- action items routed to `silver:add`
- release trend summary
- recurring risk patterns

### 8. Cross-Provider Review

**AS1 gap:** Multi-provider review adds cost and dependency complexity.

**SB gap:** SB does not expose a clear "when to use external review" policy.

**Better SB direction:** Keep SB-owned review authoritative, add optional adversarial enrichment modes:

- local SB review always required
- external reviewers only for high blast radius, security, public API, or release blockers
- all findings normalized into REVIEW.md and triaged by `silver:review-triage`

### 9. Code Intelligence

**AS1 gap:** Code-intelligence MCP can be a soft dependency.

**SB gap:** Graphify retrieval and semantic compression are not unified into a public "code intelligence contract."

**Better SB direction:** Define SB code intelligence as layered:

- fast shell discovery
- Graphify retrieval when present
- call/dependency graph evidence when available
- fallback quality levels recorded in artifacts

### 10. Design System State

**AS1 gap:** Dedicated design state can drift from implementation.

**SB gap:** SB UI contract/review does not yet define a durable interface state artifact.

**Better SB direction:** Add optional `.planning/interface/` artifacts generated by `silver:ui-contract` and verified by `silver:ui-review`.

### 11. Content And Search Readiness

**AS1 gap:** Content/SEO/GEO commands may exceed core engineering scope.

**SB gap:** SB's docs scheme does not cover public content quality, migration parity, search readiness, and AI-citation readiness.

**Better SB direction:** Treat these as SB domain quality packs, activated for public sites/docs/content changes and release workflows.

### 12. Installation And Update UX

**AS1 gap:** Simple installation may hide prerequisites and cache issues.

**SB gap:** SB installation can look heavy.

**Better SB direction:** Keep precise install safety, but add a concise "fast install" path plus a diagnostics command that verifies hooks, Graphify, jq, package version, and runtime support.

### 13. Runtime Compatibility

**AS1 gap:** Broad runtime support may produce different capabilities per host.

**SB gap:** SB has clear Claude/Codex support but less public stance for Cursor-like environments.

**Better SB direction:** Document runtime capability tiers: guidance-only, state-tracked, hook-enforced, live-tested.

### 14. Skill Catalog Discoverability

**AS1 gap:** A large catalog can overwhelm.

**SB gap:** SB's compact command set hides depth.

**Better SB direction:** Expose a capability matrix rather than one command per concern. `/silver` remains the entry point; reference docs show which domain packs activate by scope.

### 15. Auto-Activation Discipline

**AS1 gap:** Always-on routing can over-trigger.

**SB gap:** Explicit `/silver` requires user habit.

**Better SB direction:** Keep explicit routing, but improve session-start reminders and command suggestions. Never hijack non-SB tasks silently.

## SB Gap Closure Requirements

To become a clear superset without copying AS1:

1. Add an SB-owned domain audit capability that covers the specialized audit breadth through packs, not cloned commands.
2. Extend quality gates with domain pack selection and a normalized evidence schema.
3. Make test health deeper: test quality, E2E readiness, mutation-style challenge, test performance, and repair planning.
4. Add backlog fingerprinting and prioritization guidance for audit findings.
5. Add canary/post-deploy verification as an SB release/DevOps capability.
6. Add incident and retrospective artifacts as first-class SB forensics/release outputs.
7. Add optional external review policy while keeping SB review authoritative.
8. Add code-intelligence capability tiers.
9. Add UI/interface state artifacts for design continuity.
10. Add content/search-readiness packs for public docs/sites.
11. Improve install/update diagnostics and runtime capability documentation.
12. Preserve SB's key superiority: enforceability, artifact traceability, release governance, and no dependency-plugin ownership leakage.

