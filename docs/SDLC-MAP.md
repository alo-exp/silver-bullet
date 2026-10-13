# SDLC Coverage Map

Single-page view of which Silver Bullet skills, artifacts, and enforcement layers
activate at each SDLC stage. This is SB's authoritative coverage matrix.

**Last updated:** 2026-06-12

## Coverage Matrix

| SDLC Stage | SB Skills | Artifacts Produced | Enforcement Active | Coverage |
|------------|-----------|-------------------|--------------------|----------|
| **Ideation** | `sb:clarify`, `sb:deep-research`, `sb:spec` | Clarification brief, research notes, SPEC.md | Spec reviewer, artifact reviewers | Full |
| **Requirements** | `sb:spec`, `sb:ingest`, `sb:validate` | REQUIREMENTS.md, INGESTION_MANIFEST.md, VALIDATION.md | Requirements reviewer, cross-artifact reviewer, spec floor gate | Full |
| **Architecture** | `sb:context`, `sb:deep-research`, `sb:plan`, `sb:domain-audit` | CONTEXT.md, decision notes, PLAN.md, DOMAIN-AUDIT.md | Context reviewer, plan checker, architecture/domain pack | Full |
| **Planning** | `sb:context`, `sb:plan`, `sb:validate`, `sb:quality-gates` | PLAN.md, assumptions, dependency notes, quality gaps | Dev-cycle gate Stage A/B, artifact review | Full |
| **Implementation** | `tdd`, `sb:execute`, `sb:refactor`, `sb:worktree` | Code, tests, implementation summary, REFACTOR.md, WORKTREE.md | Dev-cycle gate, TDD freshness invalidation, skill recording | Full |
| **Code Review** | `sb:review-request`, `sb:review`, `sb:review-triage` | REVIEW.md, triage notes, fix commits | Code reviewer, dev-cycle gate Stage C, completion audit | Full |
| **Testing** | `sb:test`, `sb:verify`, `verify-tests`, `sb:completion-audit`, `sb:domain-audit` | TEST-ENGINEERING.md, VERIFICATION.md, UAT.md, test freshness marker, DOMAIN-AUDIT.md | Completion audit, stop gate (planning floor), test freshness gate, test-health pack | **Partial** — UAT hook on release/ship when SPEC exists; intermediate plan verify (VFY-01) |
| **Security** | `security`, `sb:secure`, `sb:validate` | SECURITY.md, validation findings | Security auditor, forbidden-skill checks, delivery gate | Full |
| **UAT** | `sb:verify`, `sb:release` | UAT.md, release evidence | UAT gate and release audit | Full |
| **Quality Gates** | `sb:quality-gates`, `sb:domain-audit`, 8 core dimension skills, conditional AI/LLM and DevOps gates | Per-dimension assessment, DOMAIN-AUDIT.md | Dev-cycle gate Stage A, completion audit, domain pack blockers | Full |
| **Ship** | `sb:branch-finish`, `sb:ship`, `sb:deploy` | PR, CI status, ship summary, DEPLOYMENT.md | CI status check, PR traceability, completion audit, deploy evidence | Full |
| **Release** | `sb:release`, `sb:domain-audit`, `sb:create-release`, `sb:canary`, `sb:retro` | CHANGELOG, tag, GitHub release, release-domain audit, CANARY.md, RETRO.md | Pre-release quality gate, domain release packs, completion audit, canary evidence | Full |
| **Observability** | `sb:review-stats`, `sb:scan`, `sb:canary`, `sb:benchmark` | review-analytics.jsonl, deferred-item notes, CANARY.md, BENCHMARK.md | Analytics rotation at 1000 lines, runtime watch evidence | Full |
| **Maintenance** | `sb:debug`, `sb:forensics`, `sb:incident`, `sb:retro`, `sb:content` | debug reports, root-cause notes, INCIDENT.md, RETRO.md, CONTENT.md | Forensics workflow, incident action capture, content/search gates | Full |

## Coverage Summary

- **Full hook-enforced coverage:** Planning through Ship for tier-2 hosts running composed workflows end-to-end.
- **Skill-available, not always required:** Observability packs (`sb:canary`, `sb:benchmark`), incident/retro loops, and optional domain packs — invoke per workflow; not in default `required_deploy`.
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
