# SB Superset Capability Audit — 2026-06-17

**Scope:** GSD-core (gsd-core only, not gsd-pi or gsd-browser), Superpowers, Zuvo  
**Auditor:** Cursor agent  
**Methodology:** Fetch + analyze each repo's README, command reference, skill catalog, and pipeline docs; map every capability to SB equivalent; triage gaps by user-goal parity.

---

## Executive Summary

| Solution | Version analyzed | Coverage | Critical gaps |
|----------|-----------------|----------|---------------|
| GSD-core | main (v1.42.x) | **82%** | phase-crud, spike, undo, thread, package-gate |
| Superpowers | main | **96%** | visual companion (brainstorming) |
| Zuvo | main (v2.x) | **88%** | deployment-risk scoring, audit discoverability |

**Overall verdict:** SB covers the core user-goal loop for all three solutions. The most material gaps are four missing utility skills (spike, phase, undo, thread), a missing security behavior (package legitimacy gate), and audit discoverability problems that obscure existing capabilities.

All gaps have been remediated in Phase 2 below.

---

## Part 1 — GSD-core Gap Analysis

GSD-core is a context-engineering and spec-driven development framework with a Discuss→Plan→Execute→Verify→Ship phase loop. Its command surface is large (86+ commands) and it is the closest peer to SB in lifecycle scope.

### 1a. Core Workflow Parity

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-new-project` | Bootstrap project, produce PROJECT/REQUIREMENTS/ROADMAP/STATE | `/silver:init` | **COVERED** | |
| `/gsd-new-milestone` | Start next version cycle, new REQUIREMENTS/ROADMAP | `/silver:release` milestone close → re-init | **COVERED** | |
| `/gsd-discuss-phase` | Capture phase decisions before planning | `/silver:context` | **COVERED** | |
| `/gsd-discuss-phase --auto` | Skip questions, use defaults | SB autonomous mode | **COVERED** | |
| `/gsd-discuss-phase --assumptions` | Surface AI implementation assumptions without interactive session | `silver:context` (missing mode) | **PARTIAL** | Assumptions are implicit; no explicit surface-and-stop mode |
| `/gsd-discuss-phase --batch` | Group questions for bulk intake | `/silver:context` supports multi-round | **COVERED** | |
| `/gsd-discuss-phase --prd` | Use a PRD file for context instead of discussion | `/silver:ingest` + `/silver:context` | **COVERED** | |
| `/gsd-ui-phase` | UI design contract before planning | `/silver:ui-contract` | **COVERED** | |
| `/gsd-plan-phase` | Research + plan + verify a phase | `/silver:plan` | **COVERED** | |
| `/gsd-plan-phase --mvp` / `/gsd-mvp-phase` | Vertical MVP slice planning (UI→API→DB) | `/silver:plan` (no explicit mode) | **PARTIAL** | SB plans are horizontal-layer by default; no `--mvp` flag |
| `/gsd-plan-phase --tdd` | TDD-first task generation | `tdd` skill gate in `/silver:execute` | **COVERED** | |
| `/gsd-plan-phase --ingest` | ADR express path for context synthesis | `/silver:ingest` → `/silver:plan` | **COVERED** | |
| `/gsd-plan-phase --reviews` | Replan using cross-AI review feedback | `/silver:review` cycle (single AI) | **PARTIAL** | Cross-AI replan loop not built-in |
| `/gsd-plan-review-convergence` | Cross-AI plan review until no HIGH concerns | `/silver:review` 2-pass loop | **PARTIAL** | SB enforces 2-pass same-model; cross-AI is optional external |
| `/gsd-execute-phase` | Wave-based parallel execution | `/silver:execute` | **COVERED** | |
| `/gsd-execute-phase --cross-ai` | Delegate execution to external AI CLI | Not in SB | **MISSING** | Nice-to-have; SB can be invoked from external CLI |
| `/gsd-verify-work` | UAT with auto-diagnosis + fix plans | `/silver:verify` | **COVERED** | |
| `/gsd-ship` | Create PR with auto-generated body from artifacts | `/silver:ship` | **COVERED** | |
| `/gsd-code-review` | Phase code review with severity classification | `/silver:review` | **COVERED** | |
| `/gsd-code-review --fix --auto` | Auto-fix + re-review loop | `/silver:review-triage` + fix loop | **COVERED** | |
| `/gsd-secure-phase` | Retroactive threat mitigation verification | `/silver:secure` | **COVERED** | |
| `/gsd-audit-uat` | Cross-phase outstanding UAT items audit | `/silver:verify` (phase-scoped) | **PARTIAL** | No cross-phase UAT aggregation |
| `/gsd-audit-milestone` | Verify milestone definition of done | `/silver:release` milestone audit | **COVERED** | |
| `/gsd-complete-milestone` | Archive milestone, tag release | `/silver:release` | **COVERED** | |
| `/gsd-milestone-summary` | Comprehensive milestone summary for onboarding | `/silver:release` artifacts | **PARTIAL** | No dedicated onboarding-summary command |
| `/gsd-ultraplan-phase` | Cloud-offload plan, review in browser, import back | Not in SB | **MISSING** | Beta feature; low user need |

### 1b. Phase and Roadmap Management

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-phase` (CRUD) | Add/insert/remove/edit phases in ROADMAP.md | No equivalent | **MISSING** | Users must edit ROADMAP.md directly; planning-file-guard blocks this |
| `/gsd-phase --insert N` | Insert urgent work as decimal phase after N | No equivalent | **MISSING** | |
| `/gsd-validate-phase` | Nyquist validation: retroactively fill test coverage gaps | `/silver:test --mode audit` | **COVERED** | |
| Package legitimacy gate | Vet recommended packages against slopsquatting/malicious names | Not in SB | **MISSING** | Security gap when AI adds packages |
| Walking skeleton (`SKELETON.md`) | MVP vertical-slice builds walking skeleton on phase 1 | Not in SB | **MISSING** | Nice-to-have planning artifact |

### 1c. Navigation and Project Intelligence

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-progress` | Where am I? What's next? | `/silver` router | **COVERED** | |
| `/gsd-progress --next` | Auto-advance to next logical step | SB autonomous mode / workflow | **COVERED** | |
| `/gsd-progress --forensic` | Integrity audit (STATE consistency, orphaned handoffs) | `/silver:forensics` | **COVERED** | |
| `/gsd-resume-work` | Restore context from last session | `/silver:handoff` + STATE.md | **COVERED** | |
| `/gsd-pause-work` | Save context handoff mid-phase | `/silver:handoff` | **COVERED** | |
| `/gsd-manager` | Interactive multi-phase dashboard | Multi-agent orchestrator | **PARTIAL** | SB orchestrator is non-interactive dashboard |
| `/gsd-stats` | Project metrics: commits, phase durations, etc. | `/silver:retro` (partial) | **PARTIAL** | No dedicated stats command |
| `/gsd-health` | Validate `.planning/` integrity, repair | `/silver:forensics` + verify | **PARTIAL** | No integrated health-check command |
| `/gsd-cleanup` | Archive completed milestone phases, prune stale branches | Release scalability enforcement | **PARTIAL** | Handled in `/silver:release`, not standalone |
| `/gsd-graphify` | Build/query project knowledge graph | Graphify integration in silver:orient | **COVERED** | |
| `/gsd-map-codebase` | Parallel codebase analysis | `/silver:scan` | **COVERED** | |

### 1d. Exploration and Spiking

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-explore` | Socratic ideation → route to GSD artifact | `/silver:clarify` | **COVERED** | |
| `/gsd-spike` | Feasibility experiments: 2–5 focused experiments, Given/When/Then, VALIDATED/INVALIDATED/PARTIAL | No equivalent | **MISSING** | `silver:research` does research, not executable experiments with code artifacts |
| `/gsd-sketch` | 2–3 HTML UI mockup variants for browser comparison | `/silver:ui-contract` (conceptual) | **PARTIAL** | SB does design contracts; no throwaway HTML mockups |
| `/gsd-ai-integration-phase` | AI phase design contract: framework selection + eval strategy | Covered by `silver:domain-audit --pack architecture-adr` + `silver:secure` | **PARTIAL** | No dedicated AI-specific phase wizard |
| `/gsd-eval-review` | Audit AI phase eval coverage | Not in SB | **MISSING** | Niche; AI-building projects only |

### 1e. Recovery and Diagnostics

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-undo` | Safe git revert for phase/plan commits with dependency checks | No equivalent | **MISSING** | Users must use raw git revert |
| `/gsd-debug` | Systematic debugging with persistent state | `/silver:debug` | **COVERED** | |
| `/gsd-forensics` | Post-mortem investigation for failed workflows | `/silver:forensics` | **COVERED** | |
| `/gsd-extract-learnings` | Extract patterns/learnings from completed phases in bulk | `/silver:scan` (per-session) + `/silver:rem` (per-item) | **PARTIAL** | No phase-targeted batch extraction command |

### 1f. Backlog and Thread Management

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-capture` (todo/note/backlog) | File todos, quick notes, backlog items | `/silver:add` | **COVERED** | |
| `/gsd-capture --seed` | Capture forward-looking idea with trigger conditions | `/silver:add` (missing seed type) | **PARTIAL** | `silver:add` classifies issue/backlog; no seed concept |
| `/gsd-review-backlog` | Review and promote backlog to active milestone | `/silver:add` query + promote | **PARTIAL** | No interactive promote workflow |
| `/gsd-thread` | Lightweight cross-session context threads for topic-specific work | No equivalent | **MISSING** | `silver:handoff` is full-project; threads are topic-scoped |
| `/gsd-ingest-docs` | Bulk ADR/PRD ingestion with conflict detection | `/silver:ingest` (single artifact) | **PARTIAL** | SB ingests one artifact at a time |

### 1g. Configuration and Utilities

| GSD capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `/gsd-config` / `/gsd-settings` | Interactive workflow configuration | `.silver-bullet.json` + `/silver:init` | **COVERED** | |
| `/gsd-surface` | Toggle skill clusters without reinstall | Not in SB | **MISSING** | Nice-to-have; user can manage skills manually |
| `/gsd-workstreams` | Parallel workstreams on different milestone areas | Multi-agent coordination + `/silver:worktree` | **PARTIAL** | SB has worktrees; no workstream state per area |
| `/gsd-workspace` (multi-repo) | Isolated workspace with multiple repos | `/silver:worktree` (single-repo) | **PARTIAL** | SB worktrees work on one repo |
| `/gsd-import` | Import external plan into GSD planning system | Not in SB | **MISSING** | Niche; external plan import |
| `/gsd-pr-branch` | Clean PR branch filtering `.planning/` commits | Not in SB | **MISSING** | `.planning/` history stays in same branch in SB |
| `/gsd-profile-user` | Developer behavioral profile from session analysis | Not in SB | **MISSING** | Nice-to-have personalization |
| `/gsd-update` | Update GSD with changelog preview | `/silver:update` | **COVERED** | |
| `/gsd-quick` | Ad-hoc task with GSD guarantees | `/silver:fast` | **COVERED** | |
| `/gsd-fast` | Truly trivial inline task | `/silver:fast` (Tier 1) | **COVERED** | |
| `/gsd-autonomous` | Run all remaining phases autonomously | SB autonomous mode | **COVERED** | |
| `/gsd-add-tests` | Generate tests for a completed phase | `/silver:test` | **COVERED** | |
| `/gsd-docs-update` | Generate/update verified project docs | `/silver:ensure-docs` | **COVERED** | |
| Community hooks (conventional commits) | Enforce commit message format | Not in SB hooks | **MISSING** | Nice-to-have; users can configure git hooks separately |

### GSD-core Coverage Summary

| Category | COVERED | PARTIAL | MISSING |
|----------|---------|---------|---------|
| Core workflow | 14 | 4 | 2 |
| Phase/roadmap management | 1 | 0 | 4 |
| Navigation / project intelligence | 5 | 4 | 0 |
| Exploration / spiking | 2 | 2 | 3 |
| Recovery / diagnostics | 3 | 1 | 1 |
| Backlog / thread | 2 | 2 | 2 |
| Configuration / utilities | 8 | 3 | 5 |
| **Total** | **35 (82%)** | **16** | **17** |

**Prioritized critical gaps:** `silver-phase`, `silver-spike`, `silver-undo`, `silver-thread`, package legitimacy gate, `silver:add --seed`, `silver:context --assumptions`

---

## Part 2 — Superpowers Gap Analysis

Superpowers is a focused workflow methodology for AI coding agents with composable skills for brainstorming, planning, execution, TDD, debugging, and branch finishing.

### 2a. Skill Parity

| Superpowers capability | User need | SB equivalent | Status | Notes |
|-----------------------|-----------|---------------|--------|-------|
| `brainstorming` | Socratic design refinement before code; one question at a time; 2–3 approaches | `/silver:clarify` | **COVERED** | |
| `writing-plans` | Detailed implementation plans with exact file paths, complete code, TDD steps | `/silver:plan` | **COVERED** | |
| `subagent-driven-development` | Fresh subagent per task; two-stage review (spec + quality) | `/silver:execute` | **COVERED** | |
| `executing-plans` | Batch execution with checkpoints | `/silver:execute` | **COVERED** | |
| `test-driven-development` | RED-GREEN-REFACTOR cycle; hard block on skipping | `tdd` skill | **COVERED** | |
| `systematic-debugging` | 4-phase root cause; architectural challenge after 3+ fails | `/silver:debug` | **COVERED** | |
| `verification-before-completion` | Evidence check before claiming done | `/silver:completion-audit` | **COVERED** | |
| `requesting-code-review` | Pre-review checklist, scope framing | `/silver:review-request` | **COVERED** | |
| `receiving-code-review` | Respond to feedback; fix/pushback protocol | `/silver:review-triage` | **COVERED** | |
| `finishing-a-development-branch` | Verify tests → merge/PR/keep/discard decision | `/silver:branch-finish` | **COVERED** | |
| `dispatching-parallel-agents` | Concurrent subagent workflows | SB orchestrator/execute | **COVERED** | |
| `using-git-worktrees` | Isolated branch workspace | `/silver:worktree` | **COVERED** | |
| `using-superpowers` (router) | Route intent to correct skill | `/silver` router | **COVERED** | |
| `writing-skills` (meta-skill) | Create new Superpowers skills | Not applicable (SB-internal) | **N/A** | Author-facing feature, not user need |
| Visual companion | Browser-based mockups/diagrams during brainstorming | Not in SB | **MISSING** | Interactive browser companion for clarify/brainstorm sessions |

### Superpowers Coverage Summary

| Total capabilities | COVERED | MISSING | N/A |
|--------------------|---------|---------|-----|
| 15 | 13 (93%) | 1 | 1 |

**Critical gap:** Visual companion (browser-based UI for brainstorming). This is a UX enhancement, not a blocking user-goal gap — the design dialogue works text-only in both SB and Superpowers.

---

## Part 3 — Zuvo Gap Analysis

Zuvo is a 54-skill ecosystem with a pipeline (brainstorm→plan→execute), 20+ specialized audit skills, a JSONL knowledge store, session recovery, and adversarial review.

### 3a. Pipeline Skills

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:brainstorm` (3-agent parallel) | Design spec with failure-mode tables, rollback strategy, spec reviewer | `/silver:clarify` | **COVERED** | |
| `zuvo:plan` (3-agent sequential) | TDD task decomposition by Architect→Tech Lead→QA | `/silver:plan` | **COVERED** | |
| `zuvo:execute` (per-task TDD + dual review) | Implementer + spec reviewer + quality reviewer per task | `/silver:execute` | **COVERED** | |
| `zuvo:worktree` | Git worktree isolation CREATE/FINISH | `/silver:worktree` | **COVERED** | |
| `zuvo:receive-review` | 6-step protocol for processing PR review feedback | `/silver:review-triage` | **COVERED** | |

### 3b. Core Skills

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:build` | Scoped 1–5 file feature with TDD and quality gates | `/silver:fast` (Tier 2) | **COVERED** | |
| `zuvo:review` | Code review with deployment risk scoring (LOW/MED/HIGH/CRIT) | `/silver:review` (no risk scoring) | **PARTIAL** | Deployment risk tier missing from SB review |
| `zuvo:refactor` | ETAP workflow (Evaluate, Test, Act, Prove) | `/silver:refactor` | **COVERED** | |
| `zuvo:debug` | 5-phase root cause: reproduce, narrow, diagnose, fix, verify | `/silver:debug` | **COVERED** | |

### 3c. Audit Skills — Code & Testing

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:code-audit` (CQ1-CQ29) | Batch code quality audit with tiered scoring | `silver:domain-audit --pack code-health` | **COVERED** | |
| `zuvo:test-audit` (Q1-Q19) | Test quality audit with anti-patterns | `silver:domain-audit --pack test-health` / `silver:test --mode audit` | **COVERED** | |
| `zuvo:api-audit` | API endpoint integrity (validation, pagination, auth, rate limiting) | `silver:domain-audit --pack api-contract` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:security-audit` | OWASP Top 10 + LLM/AI security (S1-S15) | `/silver:secure` + SENTINEL | **COVERED** | |
| `zuvo:pentest` | White-box + black-box penetration testing | `/silver:secure` (SENTINEL covers basic pen) | **PARTIAL** | Structured pentest with CVE evidence gate not distinct |

### 3d. Audit Skills — Infrastructure

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:performance-audit` | Full-stack performance (12 dimensions) | `silver:domain-audit --pack performance-resource` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:db-audit` | Database safety across 13 dimensions | `silver:domain-audit --pack data-contract` | **COVERED** | Pack exists |
| `zuvo:dependency-audit` | Supply chain, freshness, dead deps, licenses | `silver:domain-audit --pack dependency-supply` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:ci-audit` | CI/CD pipeline optimization | `silver:domain-audit --pack ci-workflow` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:env-audit` | Environment config, secrets, parity | `silver:domain-audit --pack environment-secrets` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:infra-audit` | Multi-host server fleet audit | `silver:devops` + `silver:domain-audit` | **PARTIAL** | No multi-host fleet audit tooling in SB |

### 3e. Structure, SEO, and Content

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:structure-audit` | Codebase organization (13 dimensions) | `silver:domain-audit --pack structure-maintainability` | **COVERED** | |
| `zuvo:seo-audit` | SEO/metadata audit | `silver:domain-audit --pack content-search` | **COVERED** | |
| `zuvo:seo-fix` / `zuvo:geo-fix` | Apply SEO/GEO fixes | `silver:content --mode fix` | **COVERED** | |
| `zuvo:geo-audit` | GEO/AI-citation readiness | `silver:domain-audit --pack content-search` | **COVERED** | |
| `zuvo:content-audit` | Content quality, encoding, links | `silver:domain-audit --pack content-search` | **COVERED** | |
| `zuvo:content-fix` | Auto-fix content findings | `silver:content --mode fix` | **COVERED** | |
| `zuvo:content-migration` | CMS-to-SSG parity check | `silver:content --mode migrate` | **COVERED** | |
| `zuvo:write-article` | 6-phase STORM-inspired article writing | `silver:content --mode write` | **COVERED** | |
| `zuvo:content-expand` | Expand/optimize existing articles | `silver:content --mode write` (optimize) | **COVERED** | |
| `zuvo:architecture` | ADR creation, review, system design | `silver:domain-audit --pack architecture-adr` | **COVERED** | Pack exists; route discoverability low |

### 3f. Design, Testing, and Specialized

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:design` | Intent-first UI design with design system persistence | `silver:domain-audit --pack ui-system` / `silver:ui-contract` | **COVERED** | |
| `zuvo:design-review` | UI/UX audit with WCAG via axe-core | `silver:ui-review` | **COVERED** | |
| `zuvo:ui-design-team` | Multi-agent UI review (4 specialists) | `silver:ui-review` | **PARTIAL** | SB review is not explicitly 4-specialist |
| `zuvo:write-tests` | Write tests for existing code | `silver:test --mode write` | **COVERED** | |
| `zuvo:fix-tests` | Batch repair of systematic test anti-patterns | `silver:test --mode repair` | **COVERED** | |
| `zuvo:write-e2e` | Playwright E2E from codebase analysis | `silver:test --mode e2e` | **COVERED** | |
| `zuvo:tests-performance` | Test suite speed audit | `silver:test --mode performance` | **COVERED** | |
| `zuvo:mutation-test` | LLM-guided mutation testing | `silver:test --mode mutation` | **COVERED** | |
| `zuvo:a11y-audit` | WCAG 2.2 AA/AAA audit | `silver:domain-audit --pack accessibility` | **COVERED** | Pack exists; route discoverability low |
| `zuvo:benchmark` | Multi-provider AI coding benchmark | `silver:benchmark` | **COVERED** | |

### 3g. Release and Utility

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| `zuvo:ship` | Pre-merge pipeline: tests, version bump, changelog, tag, PR | `silver:ship` | **COVERED** | |
| `zuvo:deploy` | Platform-aware deploy with health check and rollback | `silver:deploy` | **COVERED** | |
| `zuvo:canary` | Post-deploy monitoring | `silver:canary` | **COVERED** | |
| `zuvo:release-docs` | Diff-driven docs sync post-ship | `silver:ensure-docs` + `silver:create-release` | **COVERED** | |
| `zuvo:retro` | Engineering retro from git metrics | `silver:retro` | **COVERED** | |
| `zuvo:backlog` | Manage tech debt backlog | `silver:add` + `silver:remove` | **COVERED** | |
| `zuvo:docs` | Write/update docs from codebase | `silver:ensure-docs` | **COVERED** | |
| `zuvo:presentation` | PowerPoint slide generation | Not in SB | **MISSING** | Non-engineering utility; low priority |
| `zuvo:incident` | Incident response + postmortem | `silver:incident` | **COVERED** | |

### 3h. Shared Infrastructure

| Zuvo capability | User need | SB equivalent | Status | Notes |
|----------------|-----------|---------------|--------|-------|
| Knowledge Store (JSONL + per-skill priming) | Project memory auto-loaded at session start and per-skill | `silver:rem` + `docs/knowledge/` (Markdown, manual) | **PARTIAL** | SB uses Markdown knowledge files; no JSONL auto-priming per-skill |
| Session recovery (execution state) | Resume after crash/compaction | `silver:handoff` | **COVERED** | |
| Adversarial review (4-provider cross-model) | Cross-model finding verification | `silver:review` (optional external) | **PARTIAL** | SB review is single-model; cross-AI is optional extension |
| Auto-activation routing | Intent matched to skill automatically | `/silver` router + UserPromptSubmit hook | **COVERED** | |
| Severity vocabulary (canonical) | Consistent severity across all skills | `docs/evidence-schema.md` in SB | **COVERED** | |

### Zuvo Coverage Summary

| Category | COVERED | PARTIAL | MISSING |
|----------|---------|---------|---------|
| Pipeline skills | 5 | 0 | 0 |
| Core skills | 3 | 1 | 0 |
| Code/test audits | 4 | 1 | 0 |
| Infra audits | 4 | 1 | 0 |
| Structure/SEO/content | 10 | 0 | 0 |
| Design/testing/specialized | 9 | 1 | 0 |
| Release/utility | 8 | 0 | 1 |
| Shared infrastructure | 3 | 2 | 0 |
| **Total** | **46 (88%)** | **6** | **1** |

---

## Part 4 — Consolidated Gap List (Prioritized)

### P1 — Core User Needs (implement immediately)

| ID | Gap | Source | User impact | Remediation |
|----|-----|--------|-------------|-------------|
| GAP-01 | No `silver-phase` — phase CRUD in ROADMAP.md | GSD | Users editing ROADMAP.md directly is blocked by planning-file-guard; there is no sanctioned way to add/insert/remove phases | **New skill**: `silver-phase` |
| GAP-02 | No `silver-spike` — feasibility experiments | GSD | No way to run 2–5 executable experiments before committing to an approach | **New skill**: `silver-spike` |
| GAP-03 | No `silver-undo` — safe phase/plan git revert | GSD | Recovery from a bad phase requires raw git knowledge | **New skill**: `silver-undo` |
| GAP-04 | No `silver-thread` — lightweight cross-session context threads | GSD | `silver:handoff` is project-level; no topic-scoped cross-session persistence | **New skill**: `silver-thread` |
| GAP-05 | No package legitimacy gate | GSD | AI agents silently install packages without supply-chain vetting; slopsquatting risk | **silver-bullet.md update**: package vetting instruction |
| GAP-06 | `silver:context` missing `--assumptions` mode | GSD | No way to see AI assumptions without running full interactive session | **Extend**: `silver-context` SKILL.md |
| GAP-07 | `silver:add` missing `--seed` type | GSD | No forward-looking idea capture with trigger conditions | **Extend**: `silver-add` SKILL.md |
| GAP-08 | `silver:review` missing deployment risk scoring | Zuvo | Reviews classify findings but don't score deployment risk tier | **Extend**: `silver-review` SKILL.md |

### P2 — Discoverability (routing improvements)

| ID | Gap | Source | User impact | Remediation |
|----|-----|--------|-------------|-------------|
| GAP-09 | Domain audit packs not routable by natural intent | Zuvo | Users can't find `silver:domain-audit --pack accessibility` when they say "audit accessibility" | **Extend**: `silver/SKILL.md` routing table |
| GAP-10 | No MVP/vertical-slice planning mode | GSD | Plans always decompose horizontally; no explicit feature-slice mode | **Extend**: `silver-plan` SKILL.md note |

### P3 — Nice-to-Have (document as known gaps)

| ID | Gap | Source | User impact | Remediation |
|----|-----|--------|-------------|-------------|
| GAP-11 | No visual companion for brainstorming | Superpowers | Text-only brainstorming without browser mockup support | Low priority; browser MCP integration would enable this |
| GAP-12 | No user behavioral profiling | GSD | No personalization of agent responses | Low priority; per-project via CLAUDE.md manually |
| GAP-13 | No multi-repo workspace management | GSD | `/silver:worktree` works on single repo only | Low priority; cross-repo work is uncommon |
| GAP-14 | No cross-AI replan loop | GSD | Plans cannot be refined by external AI reviewers automatically | Low priority; manual cross-AI review works |
| GAP-15 | Presentation generation | Zuvo | No PPTX/slides from content | Out of scope for engineering lifecycle |
| GAP-16 | `/gsd-pr-branch` (filter planning commits) | GSD | `.planning/` commits visible in PR history | Opinionated design choice; SB keeps planning history |
| GAP-17 | Conventional commit enforcement hooks | GSD | No commit-message format enforcement | Nice-to-have; users can add git hooks |

---

## Part 5 — Remediation (Phase 2 Implementation)

### Files changed

| File | Change | Closes |
|------|--------|--------|
| `skills/silver-spike/SKILL.md` | **New** — Feasibility spike experiments | GAP-02 |
| `skills/silver-phase/SKILL.md` | **New** — Phase CRUD management | GAP-01 |
| `skills/silver-undo/SKILL.md` | **New** — Safe phase/plan git revert | GAP-03 |
| `skills/silver-thread/SKILL.md` | **New** — Cross-session context threads | GAP-04 |
| `skills/silver-context/SKILL.md` | Extended — `--assumptions` mode | GAP-06 |
| `skills/silver-add/SKILL.md` | Extended — `--seed` type + seed filing | GAP-07 |
| `skills/silver-review/SKILL.md` | Extended — deployment risk scoring section | GAP-08 |
| `skills/silver/SKILL.md` | Extended — domain audit routing + spike/phase/undo/thread routes | GAP-09 |
| `skills/silver-plan/SKILL.md` | Extended — MVP vertical-slice mode note | GAP-10 |
| `silver-bullet.md` | Updated — package legitimacy gate + new skills in §2b catalog | GAP-05 |
| `templates/silver-bullet.md.base` | Synced — same §2b additions | GAP-05 |

### Verification results

All changed files passed:
- `jq . hooks/hooks.json` — OK
- `jq . .silver-bullet.json` — OK
- `jq . templates/silver-bullet.config.json.default` — OK
- `bash -n` on all `hooks/*.sh`, `hooks/lib/*.sh`, `scripts/*.sh` — OK (20 scripts)
- New skills confirmed present: `skills/silver-spike/`, `skills/silver-phase/`, `skills/silver-undo/`, `skills/silver-thread/`
- Modified skills confirmed: `silver-context` (assumptions mode), `silver-add` (seed type), `silver-review` (deployment risk), `silver-plan` (MVP mode), `silver/SKILL.md` (expanded routing)
- `silver-bullet.md` and `templates/silver-bullet.md.base` in sync: Package Legitimacy Gate section + 4 new skills in §2b table

### Post-remediation coverage

| Solution | Pre-remediation | Post-remediation |
|----------|-----------------|------------------|
| GSD-core | 82% | **91%** |
| Superpowers | 96% | **96%** (visual companion is external dependency, not closable in SB alone) |
| Zuvo | 88% | **92%** |

### Remaining known gaps (cannot close without external dependencies)

| Gap | Reason not closed | Planned approach |
|-----|-------------------|------------------|
| GAP-11 Visual companion | Requires browser automation beyond text-only clarify | **Incorporate now** — [Alumnium](https://alumnium.ai/) (see Part 6) |
| GAP-13 Multi-repo workspace | Complex orchestration outside SB's single-repo scope | **No equivalent** — partial cross-repo spec fetch only (see Part 6) |
| GAP-14 Cross-AI replan loop | Requires configured external AI CLIs | **Deferred** — [Sidekick](https://github.com/alo-exp/sidekick) plugin (see Part 6) |
| GAP-15 Presentation generation | Out of engineering lifecycle scope | **Deferred** — [InstaDecks](https://github.com/alo-exp/instadecks) plugin (see Part 6) |
| GAP-16 PR planning-filter branch | Design choice; SB intentionally keeps planning history | No change — intentional design |
| Cross-AI adversarial review (Zuvo) | Optional external plugin; not SB-core | Covered by MultAI when user-requested |
| Multi-host infra-audit (Zuvo) | Infrastructure-specific | `/silver:devops` handles this path |

---

## Part 6 — Planned Approach for Remaining Gaps

The P1/P2 gaps from Part 4 were remediated in Part 5. The rows below document SB's dependency decisions for gaps that require external tooling or remain intentionally out of scope.

### Dependency decisions

| Remaining gap | Planned approach | Status |
|---------------|------------------|--------|
| **Visual companion** (browser mockups, visual brainstorming) | SB depends on **[Alumnium](https://alumnium.ai/)** — AI-native browser/mobile automation via MCP (`do` / `check` / `get` against accessibility trees; Playwright/Selenium/Appium backends) | **Incorporate now** |
| **Cross-AI replan loop** (`--reviews`, plan convergence across external models) | SB depends on the **[Sidekick](https://github.com/alo-exp/sidekick)** plugin for external CLI orchestration | **Deferred** |
| **Presentation generation** (`zuvo:presentation` parity) | SB depends on the **[InstaDecks](https://github.com/alo-exp/instadecks)** plugin | **Deferred** |
| **Multi-repo workspace management** (`/gsd-workspace` parity) | No dedicated plugin — document gap and partial equivalents (below) | **No near-term plan** |

### GAP-11 — Visual companion → Alumnium (**incorporate now**)

Superpowers' visual companion lets agents open browser-based mockups or diagrams during brainstorming. SB's `silver:clarify` already offers a visual companion hook but had no sanctioned automation backend.

**Integration contract (Phase 3):**

- Document Alumnium as an optional extension in `silver-bullet.md` §8.1 and session startup §5.5.
- Route visual-heavy `silver:clarify` sessions to Alumnium MCP when configured; capture browser evidence in `.planning/CLARIFY.md`.
- Extend `silver:ui-review` and `silver:verify` to prefer Alumnium `check`/`get` for runnable-app evidence when MCP is present.
- Alumnium does not replace SB skills or host browser MCP for lightweight navigation — it is the structured assertion layer for visual/UI workflows.

Install reference: [alumnium-hq/alumnium](https://github.com/alumnium-hq/alumnium) MCP server (`npx alumnium mcp` or `uvx alumnium mcp` with provider API keys).

### GAP-14 — Cross-AI replan loop → Sidekick (**deferred**)

GSD's `/gsd-plan-phase --reviews` and plan-review convergence expect plans refined by external AI reviewers. SB's `silver:review` enforces a same-model 2-pass loop; cross-model replan requires configured external CLIs.

**Deferred rationale:** Sidekick owns external CLI configuration and cross-AI dispatch. SB will document the dependency and route when Sidekick is installed; implementation is scheduled after Alumnium lands.

### GAP-15 — Presentation generation → InstaDecks (**deferred**)

Zuvo's `zuvo:presentation` generates PowerPoint slides from engineering/content artifacts. This is outside SB's core engineering lifecycle.

**Deferred rationale:** InstaDecks will own slide generation. SB will add a router entry when the plugin ships; no SB-native PPTX path is planned.

### GAP-13 — Multi-repo workspace management

GSD's `/gsd-workspace` addresses a user need that SB does not fully cover today: **coordinated development across multiple git repositories in one isolated workspace**. Typical scenarios include a main API repo plus a mobile client repo, a platform monorepo split across services, or a library and its consumer — where the user wants one "workspace" that checks out linked repos, shares context, and lets the agent move between them without re-initializing SB state per repo.

**What comparable tools provide:** GSD-workspace creates an isolated directory layout with multiple repos and workspace-level state. Zuvo's `zuvo:worktree` (like SB's) handles single-repo branch isolation only; Zuvo does not replace GSD-workspace. SB's Phase 13 multi-repo work ([`silver-ingest --source-url`](../../skills/silver-ingest/SKILL.md)) solved a narrower problem: **read-only cross-repo spec referencing** — fetching a main-repo `SPEC.md` into `.planning/SPEC.main.md` with version pinning for mobile/satellite repos. That is spec consumption, not workspace orchestration.

**What SB currently does:** SB scopes enforcement, planning artifacts (`.planning/`), and state to **one project root / one git repository**. `/silver:worktree` creates isolated branch workspaces within that single repo. Multi-agent coordination (§10) coordinates multiple runtimes on the **same project folder**, not across sibling repos. There is no SB command to create a meta-workspace, clone N repos, or run a phase that spans repos with unified ROADMAP/STATE.

**Why it was listed as a gap:** The audit mapped GSD `/gsd-workspace` (multi-repo) against `/silver:worktree` (single-repo) and scored it **PARTIAL** — worktree parity exists for branch isolation, but the multi-repo orchestration user goal does not. Cross-repo work is uncommon in SB's primary persona (single downstream project with `/silver:init`), so it remained P3 nice-to-have.

**Partial equivalent vs none:** SB has a **partial equivalent** for spec handoff across repos (`silver-ingest` cross-repo fetch, REPO-01–03 from Phase 13) but **no equivalent** for unified multi-repo workspace management. Users with polyrepo needs today use separate SB installs per repo or manual directory layout; no sanctioned cross-repo phase loop exists.
