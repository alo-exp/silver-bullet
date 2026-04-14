# Silver Bullet

## What This Is

Agentic Process Orchestrator for AI-native Software Engineering & DevOps. Silver Bullet combines GSD, Superpowers, Engineering, and Design plugins into enforced workflows with 7 layers of compliance — guiding users from idea to deployed software without requiring any prior knowledge of the underlying tools.

## Core Value

Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually does" — 7 compliance layers, zero single-point-of-bypass, complete user hand-holding from start to finish.

## Requirements

### Validated

- ✓ 7-layer enforcement (hooks fire automatically) — v0.7.0
- ✓ 8 quality dimension gates (modularity through extensibility) — v0.7.0
- ✓ full-dev-cycle workflow (20 steps, app dev) — v0.7.0
- ✓ devops-cycle workflow (24 steps, infrastructure) — v0.7.0
- ✓ Blast radius assessment for DevOps changes — v0.7.0
- ✓ IaC-adapted quality gates (7 dimensions) — v0.7.0
- ✓ DevOps skill router for vendor plugin selection — v0.7.0
- ✓ Pre-release quality gate (§9 four-stage) — v0.7.4
- ✓ 4 gap-filling skills promoted to enforced gates — v0.8.0
- ✓ SENTINEL security hardening (P-1 through P-7) — v0.8.0
- ✓ GSD-mainstay orchestration: workflow files guide 100% of GSD process — v0.13.0
- ✓ silver-bullet.md overhaul: GSD process knowledge, hand-holding instructions — v0.13.0
- ✓ /silver smart router: routes freeform input to best SB or GSD skill — v0.13.0
- ✓ SB orchestration skill files (silver-feature/bugfix/ui/devops/research/release/fast) — v0.13.0
- ✓ Website content refresh — v0.13.0
- ✓ AI-driven spec creation (silver-spec skill) — v0.14.0
- ✓ JIRA/Figma/Google Docs ingestion (silver-ingest skill) — v0.14.0
- ✓ Pre-build spec validation (silver-validate skill) — v0.14.0
- ✓ Spec floor enforcement (spec-floor-check.sh hook) — v0.14.0
- ✓ PR → spec traceability (pr-traceability.sh hook) — v0.14.0
- ✓ UAT pipeline gate (uat-gate.sh hook) — v0.14.0
- ✓ Multi-repo spec referencing with version pinning — v0.14.0
- ✓ Step non-skip enforcement §3/§3a/§3d — v0.14.0
- ✓ Granular artifact review rounds with 2-consecutive-clean-pass enforcement — v0.15.0
- ✓ 8 new artifact reviewer skills (SPEC, DESIGN, REQUIREMENTS, ROADMAP, CONTEXT, RESEARCH, INGESTION_MANIFEST, UAT) — v0.15.0
- ✓ Existing reviewers formalized into 2-pass framework (plan-checker, code-reviewer, verifier, security-auditor) — v0.15.0
- ✓ Workflow integration: all producing steps wired to invoke reviewer before completing — v0.15.0
- ✓ v0.14.0 critical bug fixes: shell injection, heredoc injection, Confluence failure path, version mismatch display — v0.15.0

### Active

- [ ] Cross-artifact consistency reviewer — validates SPEC.md ↔ DESIGN.md ↔ REQUIREMENTS.md are mutually consistent (ARVW-09)
- [ ] Review round analytics — track review round counts, common finding patterns, time-to-clean-pass metrics (ARVW-10)
- [ ] Configurable review depth (quick/standard/deep) per artifact type via .planning/config.json (ARVW-11)

### Out of Scope

- Replacing GSD's execution engine — GSD owns execution, SB orchestrates
- Admin/utility GSD commands (gsd-manager, gsd-settings, gsd-stats, gsd-note, etc.) — accessible but not guided
- Modifying third-party plugin files — §8 boundary enforced
- Building custom integrations for external tools — use Claude Desktop MCP connectors / CLIs
- Nomadic Care-specific naming conventions or file structures — SB provides generic patterns

## Current Milestone: v0.16.0 Advanced Review Intelligence

**Goal:** Review depth is configurable per artifact type, review rounds emit structured analytics, and a cross-artifact consistency reviewer validates alignment across SPEC/REQUIREMENTS/ROADMAP/DESIGN — building on the v0.15.0 reviewer framework.

**Target features:**
- A: Configurable review depth (deep/standard/quick) per artifact type via .planning/config.json (ARVW-11)
- B: Review analytics — structured metrics per review round, JSON Lines storage, summary reporting skill (ARVW-10)
- C: Cross-artifact consistency reviewer — validates alignment across SPEC.md ↔ REQUIREMENTS.md ↔ ROADMAP.md ↔ DESIGN.md, wired into milestone completion (ARVW-09)

## Context

- Stack: Node.js (shell hooks, markdown skills, HTML site)
- Repository: https://github.com/alo-exp/silver-bullet.git
- GSD version: 1.32.0 (~60 commands, wave-based parallel execution)
- Superpowers version: 5.0.5 (14 skills — code review, TDD, debugging, branch mgmt)
- Engineering/Design: Anthropic knowledge-work-plugins (6+6 skills)
- Current version: v0.15.3

## Constraints

- **Plugin boundary**: Must not modify GSD/Superpowers/Engineering/Design plugin files (§8)
- **Enforcement integrity**: All 7 enforcement layers must remain functional during and after restructuring
- **Template parity**: docs/workflows/ must always match templates/workflows/
- **Backward compatibility**: Existing .silver-bullet.json configs must continue to work

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| silver-bullet.md.base is single source for enforcement §0-9 | One template, no drift | ✓ Good |
| CLAUDE.md.base reduced to minimal scaffold | User owns CLAUDE.md, SB owns silver-bullet.md | ✓ Good |
| Update mode overwrites silver-bullet.md without confirmation | SB-owned file | ✓ Good |
| GSD owns execution, SB owns orchestration + enforcement | Clean separation of concerns | ✓ Good |
| Forensics: evolve (GSD-aware routing), don't remove | SB forensics handles session-level issues GSD doesn't | — Pending |
| 20 GSD commands guided, ~40 unguided | Core SDLC + select utilities only | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-10 after milestone v0.16.0 start*
