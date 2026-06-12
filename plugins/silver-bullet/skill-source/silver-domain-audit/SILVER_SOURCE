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
| `code-health` | business logic, shared modules, refactors | correctness edges, coupling, duplicated logic, error handling, maintainability |
| `test-health` | tests, coverage gaps, bugfixes, behavior changes | failing-test-first evidence, meaningful assertions, fixture realism, slow/flaky risk, mutation-style challenge where practical |
| `api-contract` | routes, controllers, OpenAPI, SDKs, webhooks | status codes, validation, auth, versioning, error shape, idempotency, compatibility |
| `data-contract` | schema, migrations, ORM, SQL, persistence | migration safety, rollback, indexes, constraints, data retention, concurrency, backfills |
| `dependency-supply` | package manifests, lockfiles, imports, toolchain | provenance, license/security posture, version pinning, transitive risk, removal plan |
| `performance-resource` | latency, memory, bundle size, caching, jobs | hot path, resource ceilings, cache correctness, load assumptions, measurement evidence |
| `structure-maintainability` | directory moves, boundaries, architecture drift | layering, naming, ownership, discoverability, circular dependency risk |
| `ci-workflow` | GitHub Actions, build scripts, release checks | required jobs, concurrency, cache invalidation, secrets use, artifact upload, failure visibility |
| `environment-secrets` | env vars, config, deployment manifests | secret exposure, default safety, environment parity, config validation, rotation notes |
| `accessibility` | UI, keyboard flows, forms, visual state | semantic HTML, keyboard reachability, focus, labels, contrast, reduced-motion and screen-reader evidence |
| `content-search` | public pages, docs, metadata, migrations | content accuracy, canonical metadata, headings, redirects, search snippets, AI-search extractability |
| `ui-system` | components, tokens, layouts, visual polish | design-token use, component reuse, responsive constraints, states, screenshots, browser verification |
| `architecture-adr` | major design choices, cross-cutting contracts | decision record, alternatives, reversibility, operational impact, extension boundary |
| `runtime-release` | deploy, canary, rollback, release readiness | deploy command safety, rollback, health checks, monitoring, smoke test, release evidence |
| `incident-retro` | incident response, postmortem, recurring failure | timeline, root cause, contributing factors, corrective actions, ownership, due dates |
| `benchmark-eval` | provider/model/tool comparisons, agent routing | repeatable fixture, scoring rubric, cost/latency, regression threshold, data retention |

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
