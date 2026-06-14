# SDLC Coverage Map

Single-page view of which Silver Bullet skills, artifacts, and enforcement layers
activate at each SDLC stage. This is SB's authoritative coverage matrix.

**Last updated:** 2026-06-12

## Coverage Matrix

| SDLC Stage | SB Skills | Artifacts Produced | Enforcement Active | Coverage |
|------------|-----------|-------------------|--------------------|----------|
| **Ideation** | `silver:clarify`, `silver:research`, `silver:spec` | Clarification brief, research notes, SPEC.md | Spec reviewer, artifact reviewers | Full |
| **Requirements** | `silver:spec`, `silver:ingest`, `silver:validate` | REQUIREMENTS.md, INGESTION_MANIFEST.md, VALIDATION.md | Requirements reviewer, cross-artifact reviewer, spec floor gate | Full |
| **Architecture** | `silver:context`, `silver:research`, `silver:plan`, `silver:domain-audit` | CONTEXT.md, decision notes, PLAN.md, DOMAIN-AUDIT.md | Context reviewer, plan checker, architecture/domain pack | Full |
| **Planning** | `silver:context`, `silver:plan`, `silver:validate`, `silver:quality-gates` | PLAN.md, assumptions, dependency notes, quality gaps | Dev-cycle gate Stage A/B, artifact review | Full |
| **Implementation** | `tdd`, `silver:execute`, `silver:refactor`, `silver:worktree` | Code, tests, implementation summary, REFACTOR.md, WORKTREE.md | Dev-cycle gate, TDD freshness invalidation, skill recording | Full |
| **Code Review** | `silver:review-request`, `silver:review`, `silver:review-triage` | REVIEW.md, triage notes, fix commits | Code reviewer, dev-cycle gate Stage C, completion audit | Full |
| **Testing** | `silver:test`, `silver:verify`, `verify-tests`, `silver:completion-audit`, `silver:domain-audit` | TEST-ENGINEERING.md, VERIFICATION.md, UAT.md, test freshness marker, DOMAIN-AUDIT.md | Completion audit, stop gate (planning floor), test freshness gate, test-health pack | **Partial** — UAT hook on release/ship when SPEC exists; intermediate plan verify (VFY-01) |
| **Security** | `security`, `silver:secure`, `silver:validate` | SECURITY.md, validation findings | Security auditor, forbidden-skill checks, delivery gate | Full |
| **UAT** | `silver:verify`, `silver:release` | UAT.md, release evidence | UAT gate and release audit | Full |
| **Quality Gates** | `silver:quality-gates`, `silver:domain-audit`, 8 core dimension skills, conditional AI/LLM and DevOps gates | Per-dimension assessment, DOMAIN-AUDIT.md | Dev-cycle gate Stage A, completion audit, domain pack blockers | Full |
| **Ship** | `silver:branch-finish`, `silver:ship`, `silver:deploy` | PR, CI status, ship summary, DEPLOYMENT.md | CI status check, PR traceability, completion audit, deploy evidence | Full |
| **Release** | `silver:release`, `silver:domain-audit`, `silver:create-release`, `silver:canary`, `silver:retro` | CHANGELOG, tag, GitHub release, release-domain audit, CANARY.md, RETRO.md | Pre-release quality gate, domain release packs, completion audit, canary evidence | Full |
| **Observability** | `silver:review-stats`, `silver:scan`, `silver:canary`, `silver:benchmark` | review-analytics.jsonl, deferred-item notes, CANARY.md, BENCHMARK.md | Analytics rotation at 1000 lines, runtime watch evidence | Full |
| **Maintenance** | `silver:debug`, `silver:forensics`, `silver:incident`, `silver:retro`, `silver:content` | debug reports, root-cause notes, INCIDENT.md, RETRO.md, CONTENT.md | Forensics workflow, incident action capture, content/search gates | Full |

## Coverage Summary

- **Full hook-enforced coverage:** Planning through Ship for tier-2 hosts running composed workflows end-to-end.
- **Skill-available, not always required:** Observability packs (`silver:canary`, `silver:benchmark`), incident/retro loops, and optional domain packs — invoke per workflow; not in default `required_deploy`.
- **Host-dependent:** Tier 0–1 runtimes receive skills and docs without mechanical gates — see `docs/RUNTIME-COMPATIBILITY.md`.
- **Outside scope:** SB does not become the production monitoring system. It requires and records runtime evidence, while the deployed system owns alerts and SLOs.

## Artifact Flow

```
Clarification ──→ SPEC.md ──→ REQUIREMENTS.md
                                      │
                                      ▼
                              CONTEXT / PLAN
                                      │
                                      ▼
                              Code / Tests / Summary
                                      │
                          ┌───────────┼───────────┐
                          ▼           ▼           ▼
                      REVIEW.md  VERIFICATION  SECURITY
                          │           │           │
                          └───────────┼───────────┘
                                      ▼
                                  UAT.md
                                      │
                                      ▼
                              Ship / Release
```

## Non-Redundancy Principle

This map documents what SB enforces and owns. It does not claim ownership over
optional external provider behavior, project-specific deployment platforms, or
production monitoring systems. Optional plugins may enrich a stage, but SB's core
lifecycle gates remain SB-owned.

## Scalability

**Fixed** — updated per release when coverage changes. Matrix format prevents
unbounded growth.
