# Product Requirements Overview

This document captures the **product vision and high-level requirements** for this project.
It is kept in sync with `.planning/REQUIREMENTS.md` — the authoritative, detailed requirements
source managed by GSD. Changes to requirements flow from `.planning/REQUIREMENTS.md` into this
document during the FINALIZATION step of each phase.

## Product Vision

Silver Bullet is a host coding-agent plugin for AI-native software engineers and DevOps practitioners
who need reliable, step-skipping-proof agentic workflows. It combines GSD with SB-owned
quality/release gates and selected helper plugins into one Agentic Process Orchestrator enforced
by layered hook, artifact, dependency, completion, CI, documentation, live-matrix, and release gates
so the runtime can never silently skip planning, quality gates, testing, or review steps.

## Core Value

Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually
does" — layered technical enforcement, zero single-point-of-bypass.

## Requirement Areas

### SB-R1: Separate silver-bullet.md from CLAUDE.md *(Complete — Phase 1)*
All Silver Bullet enforcement instructions live in a dedicated `silver-bullet.md` at project root,
separate from the user's `CLAUDE.md`. Update mode overwrites only `silver-bullet.md`. Conflict
detection resolves contradictions between the two files interactively during setup.

### SB-R2: Skill Enforcement Expansion *(Complete — Phase 2)*
Four gap-filling skills promoted from informal or absent to explicitly enforced workflow gates:
- `test-driven-development` — REQUIRED in EXECUTE for both full-dev and DevOps workflows
- `tech-debt` — REQUIRED in FINALIZATION for both workflows (replaces inline prose note)
- `accessibility-review` — REQUIRED when UI work is present in DISCUSS (WCAG 2.1 AA)
- `incident-response` — Step 1 of the DevOps Incident Fast Path
All four skills tracked in `all_tracked`; `test-driven-development` and `tech-debt` enforced via
`required_deploy` so `completion-audit.sh` blocks commits if they are skipped.

## Out of Scope

- Silver Bullet does not replace GSD or helper plugins — it orchestrates them, with GSD as the
  lifecycle authority and helper plugins called only at explicit SB-selected boundaries.
  It never modifies third-party plugin files.
- Silver Bullet does not implement project-specific business logic. It enforces workflow process
  regardless of the underlying project type or tech stack.
- Silver Bullet does not provide its own multi-agent execution engine — it delegates to GSD.
