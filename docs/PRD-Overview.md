# Product Requirements Overview

This document captures the **product vision and high-level requirements** for this project.
It is kept in sync with `.planning/REQUIREMENTS.md` — the authoritative, detailed requirements
source managed by SB workflows. Changes to requirements flow from `.planning/REQUIREMENTS.md` into this
document during the FINALIZATION step of each phase.

## Product Vision

Silver Bullet is a host coding-agent plugin for AI-native software engineers and DevOps practitioners
who need reliable, step-skipping-proof agentic workflows. It provides an SB-owned lifecycle with
quality/release gates and optional extension-plugin boundaries, enforced by layered hook, artifact,
dependency, completion, CI, documentation, live-matrix, and release gates so the runtime can never
silently skip planning, quality gates, testing, or review steps.

## Core Value

Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually
does" — layered technical enforcement, zero single-point-of-bypass.

## Requirement Areas

### SB-R1: Separate silver-bullet.md from CLAUDE.md *(Complete — Phase 1)*
All Silver Bullet enforcement instructions live in a dedicated `silver-bullet.md` at project root,
separate from the user's `CLAUDE.md`. Update mode overwrites only `silver-bullet.md`. Conflict
detection resolves contradictions between the two files interactively during setup.

### SB-R2: Skill Enforcement Expansion *(Complete — Phase 2)*
Gap-filling practices promoted from prose into explicit SB workflow gates:
- `silver-tdd` — REQUIRED when behavior-changing implementation needs test-first discipline
- `silver-completion-audit` — REQUIRED before completion claims and final delivery
- `silver-review-request`, `silver-review`, `silver-review-triage` — REQUIRED review loop markers
- `silver-secure`, `silver-validate`, and UI/accessibility-specific SB gates — REQUIRED when selected by scope
Legacy aliases remain recognized for migration, but new default tracked and required lists are SB-owned so `completion-audit.sh`
blocks delivery when current SB gates are skipped.

### SB-R3: Domain Quality Contract Packs *(Complete — Phase 3)*
SB provides a single specialized audit surface, `silver:domain-audit`, for
quality checks that are too domain-specific for the core 8-dimension sweep:
code health, test health, API contracts, data contracts, dependency and
supply-chain posture, performance, structure, CI, environment/secrets,
accessibility, content/search readiness, UI systems, architecture decisions,
runtime release evidence, incident/retro follow-up, and benchmark/eval evidence.
The route emits normalized findings that feed back into `silver:quality-gates`,
`silver:review`, `silver:verify`, `silver:devops`, and `silver:release`.

### SB-R4: Specialized Superset Routes *(Complete — Phase 4)*
SB exposes SB-owned routes for specialized capabilities that users expect from
modern AI software-engineering quality layers while preserving one lifecycle
authority: `silver:test`, `silver:refactor`, `silver:worktree`,
`silver:deploy`, `silver:canary`, `silver:incident`, `silver:retro`,
`silver:benchmark`, and `silver:content`. Each route writes an SB artifact and
feeds findings into the same review, verification, release, and backlog gates.

## Out of Scope

- Silver Bullet does not modify third-party plugin files. Optional extension plugins are called only
  at explicit SB-selected boundaries when they add a domain capability.
- Silver Bullet does not implement project-specific business logic. It enforces workflow process
  regardless of the underlying project type or tech stack.
- Silver Bullet does not replace project-specific production operations or monitoring systems. It
  requires deploy/canary/incident evidence and routes corrective actions, but the monitored system
  still owns alerts, SLOs, and runtime operations.
