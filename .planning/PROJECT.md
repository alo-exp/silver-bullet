# Silver Bullet

## What This Is

Agentic Process Orchestrator for AI-native Software Engineering & DevOps. Silver Bullet combines GSD, Superpowers, Engineering, and Design plugins into enforced workflows with 11 layers of compliance — guiding users from idea to deployed software without requiring any prior knowledge of the underlying tools.

## Core Value

Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually does" — 11 compliance layers, zero single-point-of-bypass, complete user hand-holding from start to finish.

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
- ✓ /silver-add skill: classify item as issue/backlog, file to GitHub Issues+board or local docs/issues/, cache board IDs, rate-limit resilience — v0.25.0 Phase 49
- ✓ /silver-remove skill: close GitHub issue as "not planned" or inline-mark [REMOVED] in local docs/ — v0.25.0 Phase 50
- ✓ /silver-rem skill: classify and append knowledge/lessons insights to monthly docs/ files, INDEX.md managed — v0.25.0 Phase 50
- ✓ Auto-capture enforcement: §3b-i (/silver-add) and §3b-ii (/silver-rem) mandatory capture instructions in silver-bullet.md + template; all 5 producing skills wired; session logs gain ## Items Filed; silver-release Step 9b post-release summary — v0.25.0 Phase 51
- ✓ /silver-forensics audit: 13 gaps identified and fixed across all 6 functional dimensions; 100% functional equivalence with gsd-forensics confirmed — v0.25.0 Phase 52
- ✓ /silver-update overhaul: marketplace install via `claude mcp install silver-bullet@alo-labs` replaces git clone; stale legacy entries cleaned up atomically post-install — v0.25.0 Phase 53
- ✓ /silver-scan skill: retrospective session scan globs docs/sessions/*.md, detects deferred items + knowledge/lessons insights, cross-references git/CHANGELOG/GitHub for stale exclusion, Y/n human gate per item (cap 20), files via /silver-add and /silver-rem — v0.25.0 Phase 54
- ✓ Bug fixes: timeout-check T2-1, dev-cycle-check regex (quality-gate conflict), silver-add gh auth scope, silver-remove sed portability, session-log-init TOCTOU (UUID token) — v0.26.0
- ✓ CI hardening: workflow template parity diff step, jq assertions for required_deploy/all_tracked correctness — v0.26.0
- ✓ Skill quality: session log discovery standardized (find), silver-rem INDEX.md mutations explicit, silver-scan local-tracker cross-reference (Step 4-iv), silver-scan two-pass counter documentation — v0.26.0
- ✓ Security hardening: content injection guards (allowlist regex + jq encoding) in spec-session-record.sh, uat-gate.sh, roadmap-freshness.sh — SENTINEL v2.3 CLEAR — v0.26.0
- ✓ Release ordering fix: silver-create-release runs after gsd-complete-milestone (tag placed last, eliminates mandatory post-release patch) — v0.26.0

### Active

- [ ] Review round analytics — track review round counts, common finding patterns (ARVW-10)
- [ ] Configurable review depth (quick/standard/deep) per artifact type via .planning/config.json (ARVW-11)

### Out of Scope

- Replacing GSD's execution engine — GSD owns execution, SB orchestrates
- Admin/utility GSD commands (gsd-manager, gsd-settings, gsd-stats, gsd-note, etc.) — accessible but not guided
- Modifying third-party plugin files — §8 boundary enforced
- Building custom integrations for external tools — use Claude Desktop MCP connectors / CLIs
- Nomadic Care-specific naming conventions or file structures — SB provides generic patterns

## Completed Milestone: v0.26.0 Bug Fixes, CI Hardening & Skill Quality (shipped 2026-04-25)

**Goal:** Close 12 actionable GitHub issues — bug fixes in hooks and skills, CI parity/correctness checks, skill quality improvements, and security hardening (SENTINEL v2.3).

**Shipped:** All 12 requirements satisfied across 4 phases (55-58). Release: https://github.com/alo-exp/silver-bullet/releases/tag/v0.26.0

## Completed Milestone: v0.25.0 Issue Capture & Retrospective Scan (shipped 2026-04-24)

**Goal:** Give Silver Bullet a closed-loop deferred-item capture system — automatic on-the-fly filing to the user's PM/issue tracker during execution, two new skills for adding/removing items, a forensics audit, and a retrospective session scan.

**Shipped:** All 24 requirements satisfied across 6 phases (49-54). Release: https://github.com/alo-exp/silver-bullet/releases/tag/v0.25.0

## Context

- Stack: Bash (18 hook scripts, lib helpers), Markdown (61 skills), JSON (config, hooks manifest), HTML (help site)
- Repository: https://github.com/alo-exp/silver-bullet.git
- GSD version: 1.32.0 (~60 commands, wave-based parallel execution)
- Superpowers version: 5.0.5 (14 skills — code review, TDD, debugging, branch mgmt)
- Engineering/Design: Anthropic knowledge-work-plugins (6+6 skills)
- Current version: v0.26.0

## Constraints

- **Plugin boundary**: Must not modify GSD/Superpowers/Engineering/Design plugin files (§8)
- **Enforcement integrity**: All 11 enforcement layers must remain functional during and after restructuring
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
| UUID token file for sentinel TOCTOU (BUG-05) | Platform-independent; eliminates locale-sensitive lstart | ✓ Good |
| tmpfile+mv replaces sed -i '' (BUG-04) | POSIX-portable on macOS and Linux/CI | ✓ Good |
| Content injection guards in 3 hooks (SENTINEL H-1/H-2/H-3) | Allowlist regex + jq encoding; SENTINEL v2.3 CLEAR | ✓ Good |
| CI jq assertions for required_deploy/all_tracked (CI-02) | Automation catches skill list drift on every PR | ✓ Good |
| Tag placed last in release workflow (REL-01) | Archival commits must precede the tag | ✓ Good |

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
*Last updated: 2026-04-25 — v0.26.0 milestone complete and shipped*
