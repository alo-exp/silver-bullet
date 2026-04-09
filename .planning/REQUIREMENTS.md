# Requirements: Silver Bullet v0.16.0

**Defined:** 2026-04-10
**Core Value:** Single enforced workflow — review intelligence that catches cross-artifact drift and adapts to project needs

## v1 Requirements

Requirements for v0.16.0 milestone. Each maps to roadmap phases.

### Cross-Artifact Consistency

- [ ] **ARVW-09a**: Cross-artifact reviewer skill exists at `skills/cross-artifact-reviewer/SKILL.md` — accepts a set of artifact paths and checks mutual consistency
- [ ] **ARVW-09b**: SPEC.md acceptance criteria IDs match ROADMAP.md phase requirements — no orphaned or missing IDs
- [ ] **ARVW-09c**: REQUIREMENTS.md REQ-IDs match ROADMAP.md phase requirement lists — 100% bidirectional coverage
- [ ] **ARVW-09d**: ROADMAP.md success criteria are derivable from SPEC.md acceptance criteria — no invented criteria
- [ ] **ARVW-09e**: Cross-artifact reviewer is wired into milestone transitions — runs after roadmapper completes, blocks approval on FAIL findings

### Review Analytics

- [ ] **ARVW-10a**: Review metrics collected after each review round — artifact type, pass/fail, finding count by severity, round number, timestamp
- [ ] **ARVW-10b**: Metrics stored in `~/.claude/.silver-bullet/review-analytics.json` — append-only JSON Lines format, one entry per round
- [ ] **ARVW-10c**: Markdown summary generated on demand at `.planning/REVIEW-ANALYTICS.md` — pass/fail rates per artifact type, top finding categories, average rounds to clean pass
- [ ] **ARVW-10d**: Analytics skill exists at `skills/review-analytics/SKILL.md` — invokable via `/silver:review-analytics` to generate the summary report
- [ ] **ARVW-10e**: Review loop (review-loop.md) updated to emit metrics after each round — no manual instrumentation needed

### Configurable Review Depth

- [ ] **ARVW-11a**: `.planning/config.json` supports `review_depth` object mapping artifact types to depth levels: `deep`, `standard`, `quick`
- [ ] **ARVW-11b**: `deep` depth = full QC checks + 2 consecutive clean passes (current behavior)
- [ ] **ARVW-11c**: `standard` depth = full QC checks + 1 clean pass (reduced from 2)
- [ ] **ARVW-11d**: `quick` depth = structural checks only (sections exist, format valid) + 1 pass
- [ ] **ARVW-11e**: Default depth is `standard` for all artifacts when no config specified
- [ ] **ARVW-11f**: Review loop reads depth from config and adjusts pass count and check set accordingly

## Validated (from previous milestones)

- ✓ 7-layer enforcement architecture — v0.7.0
- ✓ 8 quality dimension gates — v0.7.0
- ✓ full-dev-cycle / devops-cycle workflows — v0.7.0
- ✓ SENTINEL security hardening — v0.8.0
- ✓ GSD-mainstay orchestration — v0.13.0
- ✓ AI-driven spec creation, ingestion, validation — v0.14.0
- ✓ Spec floor, PR traceability, UAT gate — v0.14.0
- ✓ Step non-skip enforcement §3/§3a/§3d — v0.14.0
- ✓ Granular artifact review rounds (8 reviewers, 2-pass framework) — v0.15.0
- ✓ Existing reviewer formalization + workflow wiring — v0.15.0

## Future Requirements

- **ARVW-12**: Review finding auto-categorization using LLM classification
- **ARVW-13**: Review diff mode — only re-check sections that changed since last pass
- **ARVW-14**: Team-level analytics aggregation across projects

## Out of Scope

| Feature | Reason |
|---------|--------|
| Modifying GSD plugin files | §8 plugin boundary — all features are SB skills |
| Replacing existing reviewers | Enhance, don't replace — existing reviewers work |
| Real-time dashboard UI | CLI/markdown output sufficient for v0.16.0 |
| Cross-project consistency | Single-project scope for now (ARVW-14 is future) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARVW-09a | Phase 20 | Pending |
| ARVW-09b | Phase 20 | Pending |
| ARVW-09c | Phase 20 | Pending |
| ARVW-09d | Phase 20 | Pending |
| ARVW-09e | Phase 20 | Pending |
| ARVW-10a | Phase 19 | Pending |
| ARVW-10b | Phase 19 | Pending |
| ARVW-10c | Phase 19 | Pending |
| ARVW-10d | Phase 19 | Pending |
| ARVW-10e | Phase 19 | Pending |
| ARVW-11a | Phase 18 | Pending |
| ARVW-11b | Phase 18 | Pending |
| ARVW-11c | Phase 18 | Pending |
| ARVW-11d | Phase 18 | Pending |
| ARVW-11e | Phase 18 | Pending |
| ARVW-11f | Phase 18 | Pending |
