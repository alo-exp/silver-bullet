# SDLC Coverage Map

Single-page view of which Silver Bullet skills, artifacts, and enforcement layers activate at each SDLC stage. This is SB's authoritative coverage matrix.

**Last updated:** 2026-06-08 (v0.37.16)

## Coverage Matrix

| SDLC Stage | SB Skills | Artifacts Produced | Enforcement Active | Coverage |
|------------|-----------|-------------------|-------------------|----------|
| **Ideation** | `silver-spec`, `silver-ingest` | SPEC.md, INGESTION_MANIFEST.md | Spec reviewer (2-pass), ingestion-manifest reviewer | Full |
| **Requirements** | `silver-spec` (derivation) | REQUIREMENTS.md | Requirements reviewer, cross-artifact reviewer | Full |
| **Architecture** | `gsd-discuss-phase`, `gsd-map-codebase` | CONTEXT.md, codebase intel | Context reviewer | Full |
| **Planning** | `gsd-plan-phase`, `silver-validate` | PLAN.md, VALIDATION.md | Plan-checker (goal-backward), dev-cycle gate Stage A+B | Full |
| **Implementation** | `gsd-execute-phase`, `gsd-autonomous` when selected | SUMMARY.md, code | Dev-cycle gate Stage B, TDD freshness invalidation, skill recording | Full |
| **Code Review** | `gsd-code-review`, `gsd-code-review-fix` | REVIEW.md | Code reviewer (2-pass), dev-cycle gate Stage C | Full |
| **Testing** | `gsd-verify-work`, `gsd-add-tests` | VERIFICATION.md | Verification-before-completion gate, completion audit | Full |
| **Security** | `gsd-secure-phase` | SECURITY.md | Security auditor (threat model verify) | Full |
| **UAT** | `gsd-audit-uat` | UAT.md | UAT gate (SPEC AC ↔ evidence mapping) | Full |
| **Quality Gates** | `silver:quality-gates`, 8 core dimension skills, conditional AI/LLM and DevOps gates | Per-dimension assessment | Dev-cycle gate Stage A (blocks code until quality review) | Full |
| **Release** | `silver-release` / `silver-create-release` | CHANGELOG, GitHub release | Pre-release quality gate (4-stage), completion audit | Full |
| **Observability** | `silver-review-stats` | review-analytics.jsonl | Analytics rotation at 1000 lines | Partial |
| **Maintenance** | `gsd-forensics`, `gsd-debug` | debug/ reports | Forensics skill | Partial |
| **Milestone Close** | `gsd-complete-milestone` | milestone archives | Phase archive hook, STATE.md reset | Full |

## Coverage Summary

- **Full coverage (11/14):** Ideation through Release + Milestone Close
- **Partial coverage (2/14):** Observability (metrics exist, no alerting), Maintenance (forensics exists, no proactive monitoring)
- **Not covered (1/14):** Post-deployment monitoring (outside SB's scope as a dev-time orchestrator)

## Artifact Flow

```
SPEC.md ──→ REQUIREMENTS.md ──→ ROADMAP.md phases
                                      │
                              ┌───────┼───────┐
                              ▼       ▼       ▼
                          CONTEXT  RESEARCH  PLAN
                              │       │       │
                              └───────┼───────┘
                                      ▼
                                  SUMMARY.md
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
                              Release / Ship
```

## Non-Redundancy Principle

This map documents what SB enforces. It does NOT document:
- GSD execution mechanics (see GSD reference docs)
- Superpowers helper boundaries selected by SB workflows
- Individual plugin skill behavior (see respective SKILL.md files)

SB's role is the enforcement and wiring layer — connecting plugins into a guaranteed-complete SDLC.

## Scalability

**Fixed** — updated per release when coverage changes. Matrix format prevents unbounded growth.
