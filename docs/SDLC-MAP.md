# SDLC Coverage Map

Single-page view of which Silver Bullet skills, artifacts, and enforcement layers
activate at each SDLC stage. This is SB's authoritative coverage matrix.

**Last updated:** 2026-06-11

## Coverage Matrix

| SDLC Stage | SB Skills | Artifacts Produced | Enforcement Active | Coverage |
|------------|-----------|-------------------|--------------------|----------|
| **Ideation** | `silver:clarify`, `silver:research`, `silver:spec` | Clarification brief, research notes, SPEC.md | Spec reviewer, artifact reviewers | Full |
| **Requirements** | `silver:spec`, `silver:ingest`, `silver:validate` | REQUIREMENTS.md, INGESTION_MANIFEST.md, VALIDATION.md | Requirements reviewer, cross-artifact reviewer, spec floor gate | Full |
| **Architecture** | `silver:context`, `silver:research`, `silver:plan` | CONTEXT.md, decision notes, PLAN.md | Context reviewer, plan checker | Full |
| **Planning** | `silver:context`, `silver:plan`, `silver:validate`, `silver:quality-gates` | PLAN.md, assumptions, dependency notes, quality gaps | Dev-cycle gate Stage A/B, artifact review | Full |
| **Implementation** | `tdd`, `silver:execute` | Code, tests, implementation summary | Dev-cycle gate, TDD freshness invalidation, skill recording | Full |
| **Code Review** | `silver:review-request`, `silver:review`, `silver:review-triage` | REVIEW.md, triage notes, fix commits | Code reviewer, dev-cycle gate Stage C, completion audit | Full |
| **Testing** | `silver:verify`, `verify-tests`, `silver:completion-audit` | VERIFICATION.md, UAT.md, test freshness marker | Completion audit, stop gate, test freshness gate | Full |
| **Security** | `security`, `silver:secure`, `silver:validate` | SECURITY.md, validation findings | Security auditor, forbidden-skill checks, delivery gate | Full |
| **UAT** | `silver:verify`, `silver:release` | UAT.md, release evidence | UAT gate and release audit | Full |
| **Quality Gates** | `silver:quality-gates`, 8 core dimension skills, conditional AI/LLM and DevOps gates | Per-dimension assessment | Dev-cycle gate Stage A, completion audit | Full |
| **Ship** | `silver:branch-finish`, `silver:ship` | PR, CI status, ship summary | CI status check, PR traceability, completion audit | Full |
| **Release** | `silver:release`, `silver:create-release` | CHANGELOG, tag, GitHub release | Pre-release quality gate, completion audit | Full |
| **Observability** | `silver:review-stats`, `silver:scan` | review-analytics.jsonl, deferred-item notes | Analytics rotation at 1000 lines | Partial |
| **Maintenance** | `silver:debug`, `silver:forensics` | debug reports, root-cause notes | Forensics workflow, follow-up issue capture | Partial |

## Coverage Summary

- **Full coverage (12/14):** Ideation through Release.
- **Partial coverage (2/14):** Observability and Maintenance exist but do not replace production monitoring.
- **Outside scope:** Runtime production monitoring after deployment; SB can require evidence, but the monitored system owns alerts and SLOs.

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
