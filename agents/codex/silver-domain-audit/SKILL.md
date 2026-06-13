---
name: "silver:domain-audit"
title: "Domain Audit"
description: >
  This skill should be used for SB-owned domain quality contract packs across code, tests, API, data, dependency, performance, structure, CI, environment, accessibility, content/search, UI, architecture, runtime release, incident, retro, and benchmark evidence.
argument-hint: "<scope> [--pack <pack>] [--mode quick|full|release]"
version: 0.1.0
---

# /silver:domain-audit - Domain Quality Contracts

SB-owned domain audit layer for specialized quality checks. It complements
`silver:quality-gates`; it does not replace the 8 core quality dimensions,
DevOps gates, security, review, or verification.

Use this skill when the work touches a specialized surface where generic
quality dimensions are not specific enough: APIs, data models, dependency
changes, performance, repository structure, CI/CD, environment configuration,
accessibility, SEO/AI-search readiness, content migration, UI systems,
architecture decisions, deployment/canary evidence, incidents, retrospectives,
or provider/agent benchmark evidence.

## Output

Write or update the nearest scoped audit artifact:

- `.planning/phases/<phase>/DOMAIN-AUDIT.md` for phase work
- `.planning/DOMAIN-AUDIT.md` for project-level or release work

The report must include:

```markdown
# Domain Audit

Scope:
Mode:
Selected packs:

## Findings

| Pack | Severity | Confidence | Evidence | Finding | Required action | Backlog |
|------|----------|------------|----------|---------|-----------------|---------|

## Pack Results

| Pack | Result | Notes |
|------|--------|-------|

## Overall

PASS / PASS_WITH_WARNINGS / BLOCK
```

## Evidence Schema

Every finding must be normalized to this shape:

| Field | Required content |
|---|---|
| `domain` | One selected pack name |
| `scope` | File, route, service, workflow, command, or artifact under review |
| `severity` | `BLOCK`, `WARN`, or `INFO` |
| `confidence` | `HIGH`, `MEDIUM`, or `LOW` based on direct evidence quality |
| `evidence` | File path with line, command output, screenshot, trace, log, or artifact pointer |
| `owner_workflow` | `silver:feature`, `silver:bugfix`, `silver:ui`, `silver:devops`, `silver:release`, or utility route |
| `blocking_status` | `blocks ship`, `blocks release`, `does not block`, or `needs user decision` |
| `backlog_decision` | `fixed now`, `filed via silver:add`, `accepted risk`, or `not applicable` |

Do not accept generic claims such as "looks good" or "tests pass" without the
specific evidence pointer that made the claim true.

## Pack Selection

Select packs by changed files, user intent, and release scope. Use `--pack all`
only for release candidates or broad audits.

| Pack | Trigger signals | Required checks |
|---|---|---|
| `code-health` | business logic, shared modules, refactors | correctness edges, typed/explicit return contracts, error strategy, secret-safe comparisons, nullability, idempotency, auth/data filtering, resource bounds, cleanup, duplicated guards, maintainability |
| `test-health` | tests, coverage gaps, bugfixes, behavior changes | failing-test-first evidence, branch/error/edge coverage, assertion strength, mock boundaries, oracle independence, fixture realism, flake risk, cleanup, mutation-style challenge where practical |
| `api-contract` | routes, controllers, OpenAPI, SDKs, webhooks | status codes, input validation, payload shape, pagination, error shape, caching, HTTP semantics, rate limiting, auth, idempotency, versioning, compatibility |
| `data-contract` | schema, migrations, ORM, SQL, persistence | migration safety, rollback, indexes, constraints, query bounds, transactions, connection management, retention, concurrency, backfills, data/security posture |
| `dependency-supply` | package manifests, lockfiles, imports, toolchain | provenance, vulnerability/license posture, version pinning, dead deps, bundle weight, internal coupling, circular dependencies, lock-in/removal plan |
| `performance-resource` | latency, memory, bundle size, caching, jobs | hot path, rendering/bundle/assets, API/network, algorithmic complexity, memory, DB/cache behavior, concurrency, resource ceilings, measurement evidence |
| `structure-maintainability` | directory moves, boundaries, architecture drift | directory consistency, naming, folder depth, colocation, file size, dead code, complexity, duplication, ownership, documentation, circular dependency risk, churn hotspots |
| `ci-workflow` | GitHub Actions, build scripts, release checks | required jobs, caching, parallelism, conditional execution, artifact upload, action pinning, secrets use, timeouts, test integration, speed/failure visibility |
| `environment-secrets` | env vars, config, deployment manifests | variable completeness, unused vars, startup validation, secret exposure, environment parity, type safety, safe defaults, documentation, rotation notes |
| `accessibility` | UI, keyboard flows, forms, visual state | semantic HTML, keyboard reachability, focus, labels, ARIA, contrast, media alternatives, zoom/responsive behavior, motion controls, screen-reader evidence |
| `content-search` | public pages, docs, metadata, migrations | content accuracy, encoding artifacts, markdown/frontmatter quality, link/image health, canonical metadata, structured data, redirects, snippets, AI-search extractability, freshness, chunkability |
| `ui-system` | components, tokens, layouts, visual polish | design-token use, component reuse, persistent interface state, responsive constraints, states, copy, screenshots, browser verification, performance and rendering stability |
| `architecture-adr` | major design choices, cross-cutting contracts | decision record, alternatives, reversibility, operational impact, extension boundary, coupling, migration path, threat model, rollout and observability implications |
| `runtime-release` | deploy, canary, rollback, release readiness | deploy command safety, artifact/tag match, rollback, health checks, browser/runtime smoke, monitoring, alert ownership, canary watch, release evidence |
| `incident-retro` | incident response, postmortem, recurring failure | impact, timeline, containment, root cause, contributing factors, corrective actions, ownership, due dates, recurrence signals, release/process feedback |
| `benchmark-eval` | provider/model/tool comparisons, agent routing | repeatable fixture, scoring rubric, correctness, evidence quality, safety, cost, latency, self-eval bias, regression threshold, data retention |

## SB-Owned Capability Routes

These specialized workflows are the user-facing entry points for common domain
requests. They all write their own artifacts and feed normalized findings back
into this audit schema:

| Capability request | Route | Domain packs |
|---|---|---|
| Test writing, E2E route discovery, test repair, test audit, test runtime, mutation challenge | `silver:test` | `test-health`, plus affected API/data/UI/performance packs |
| Behavior-preserving refactors | `silver:refactor` | `code-health`, `structure-maintainability`, `test-health`, affected contract packs |
| Worktree create/finish safety | `silver:worktree` | `structure-maintainability`, `ci-workflow`, `runtime-release` when shipping |
| Deployment | `silver:deploy` | `ci-workflow`, `environment-secrets`, `runtime-release` |
| Post-deploy canary/runtime watch | `silver:canary` | `runtime-release`, affected API/UI/performance packs |
| Incident response and postmortem | `silver:incident` | `incident-retro`, affected runtime/API/data/security packs |
| Engineering retrospective | `silver:retro` | `incident-retro`, `benchmark-eval` when tool/provider performance matters |
| Agent/model/provider/approach evaluation | `silver:benchmark` | `benchmark-eval` |
| Content, SEO, AI-search, migration, optimization, article work | `silver:content` | `content-search`, plus accessibility/UI/performance where rendered |

## Critical Gate Catalog

Use these as named invariants. A critical gate with missing or contradictory
evidence is a `BLOCK`; do not convert it to a warning without user acceptance
and a tracked follow-up.

### Code Critical Gates

- errors are narrowed and handled at the boundary that can recover;
- secrets and credentials are never compared, logged, or serialized unsafely;
- queries, loops, jobs, and frontend requests have bounded work/time behavior;
- auth and tenant/data filters cannot be bypassed by caller-controlled input;
- external input is validated before crossing trust boundaries;
- PII and sensitive internals are not leaked through logs or API responses.

### Test Critical Gates

- required behavior has failing-test-first or equivalent baseline evidence;
- error paths, permissions, and edge cases are covered for changed behavior;
- assertions prove externally observable behavior, not only implementation calls;
- mocks do not replace the behavior being tested;
- test oracles are independent of the implementation under test;
- flaky timing, cleanup, and shared-state risks are controlled.

### Runtime Critical Gates

- deploy artifact maps to the reviewed commit, tag, or build output;
- health checks cover user-critical paths, not just process liveness;
- rollback path is known and usable before production exposure;
- production-impacting failures become `silver:incident`, not hidden warnings.

## Process

1. Display `SILVER BULLET > DOMAIN AUDIT`.
2. Identify scope from `$ARGUMENTS`, changed files, active phase artifacts, and
   release intent.
3. Select the smallest pack set that covers the touched domain. If uncertain,
   include the stricter pack and record the assumption.
4. Gather evidence before judging: file/line reads, test output, CI logs,
   screenshots, docs, release artifacts, or command results.
5. Apply each selected pack. Convert every material gap into the normalized
   finding schema.
6. Classify findings:
   - `BLOCK`: can break users, data, security, release correctness, CI, or an
     explicit acceptance criterion.
   - `WARN`: real risk that can ship only with conscious acceptance or tracked
     follow-up.
   - `INFO`: useful observation with no current delivery risk.
7. File every deferred `WARN` or accepted-risk `BLOCK` through `silver:add`.
   Record the issue/backlog ID in `backlog_decision`.
8. Feed the result back into the owning workflow:
   - `silver:quality-gates` consumes selected domain pack results as conditional
     gate rows.
   - `silver:review` consumes code/API/data/structure findings.
   - `silver:verify` consumes test, runtime, and benchmark evidence.
   - `silver:release` consumes runtime-release, content-search, incident-retro,
     and benchmark-eval findings.

## Pack Result Rules

| Result | Meaning |
|---|---|
| `PASS` | No `BLOCK` findings and all required evidence is present |
| `PASS_WITH_WARNINGS` | No unresolved `BLOCK` findings, but tracked `WARN` or accepted risk remains |
| `BLOCK` | One or more unresolved `BLOCK` findings remain |

## Exit Gate

The domain audit passes only when all selected packs have a result and every
deferred item has a `silver:add` ID or an explicit "fixed now" decision.

Do not proceed to ship or release with a `BLOCK` result unless the owning
workflow explicitly supports a documented known-issue release decision and the
user accepts that decision.
