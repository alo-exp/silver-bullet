# Requirements: Silver Bullet v0.16.0

**Defined:** 2026-04-10
**Core Value:** Single enforced workflow — no artifact ships without structured quality validation

## v1 Requirements

Requirements for v0.16.0 milestone. Each maps to roadmap phases.

### Configurable Review Depth (from v0.15.0 ARVW-11)

- [x] **ARVW-11a**: Review depth config schema added to `.planning/config.json` with per-artifact-type mapping (deep/standard/quick)
- [x] **ARVW-11b**: `resolve_depth()` function in review-loop.md reads config at loop start, determines required_passes and check_mode
- [x] **ARVW-11c**: `check_mode` parameter added to reviewer interface (full vs structural)
- [x] **ARVW-11d**: Review loop display messages and audit trail updated to show depth context
- [x] **ARVW-11e**: Default depth is "standard" when no config entry exists (backward compatible)
- [x] **ARVW-11f**: Orchestration steps in SKILL.md updated to be depth-aware

### Review Analytics (from v0.15.0 ARVW-10)

- [x] **ARVW-10a**: Review loop emits per-round metrics (artifact, round number, finding count, pass/fail, duration) at loop completion
- [x] **ARVW-10b**: Metrics stored as JSON Lines in `.planning/review-analytics.jsonl` — append-only, one JSON object per review round
- [x] **ARVW-10c**: `silver-review-stats` skill reads analytics file and produces summary table (pass rates, avg rounds, common findings by artifact type)
- [x] **ARVW-10d**: Review loop instrumented to record timestamps for round duration calculation
- [x] **ARVW-10e**: Analytics file rotation — when file exceeds 1000 lines, archive to `.planning/archive/review-analytics-{date}.jsonl`

### Cross-Artifact Consistency (from v0.15.0 ARVW-09)

- [x] **ARVW-09a**: Cross-artifact reviewer skill created — accepts list of artifacts, checks consistency across them
- [x] **ARVW-09b**: SPEC.md ↔ REQUIREMENTS.md alignment: every AC maps to a requirement, every requirement has a source AC
- [x] **ARVW-09c**: REQUIREMENTS.md ↔ ROADMAP.md alignment: every requirement maps to a phase, every phase requirement exists
- [x] **ARVW-09d**: SPEC.md ↔ DESIGN.md alignment: every user story has design coverage, no orphaned components
- [x] **ARVW-09e**: Cross-artifact review wired into milestone transition (gsd-complete-milestone) — blocks completion if inconsistencies found

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARVW-11a | Phase 18 | Done |
| ARVW-11b | Phase 18 | Done |
| ARVW-11c | Phase 18 | Done |
| ARVW-11d | Phase 18 | Done |
| ARVW-11e | Phase 18 | Done |
| ARVW-11f | Phase 18 | Done |
| ARVW-10a | Phase 19 | Complete |
| ARVW-10b | Phase 19 | Complete |
| ARVW-10c | Phase 19 | Complete |
| ARVW-10d | Phase 19 | Complete |
| ARVW-10e | Phase 19 | Complete |
| ARVW-09a | Phase 20 | Complete |
| ARVW-09b | Phase 20 | Complete |
| ARVW-09c | Phase 20 | Complete |
| ARVW-09d | Phase 20 | Complete |
| ARVW-09e | Phase 20 | Complete |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

## Validated (from previous milestones)

- ✓ 7-layer enforcement architecture — v0.7.0
- ✓ 8 quality dimension gates — v0.7.0
- ✓ full-dev-cycle / devops-cycle workflows — v0.7.0
- ✓ SENTINEL security hardening — v0.8.0
- ✓ GSD-mainstay orchestration — v0.13.0
- ✓ AI-driven spec creation, ingestion, validation — v0.14.0
- ✓ Spec floor, PR traceability, UAT gate — v0.14.0
- ✓ Step non-skip enforcement §3/§3a/§3d — v0.14.0
- ✓ Granular artifact review rounds with 2-consecutive-clean-pass enforcement — v0.15.0
- ✓ 8 new artifact reviewers + existing reviewer formalization — v0.15.0
- ✓ Workflow integration: all producing steps wired to invoke reviewer — v0.15.0
- ✓ v0.14.0 critical bug fixes — v0.15.0

## Out of Scope

| Feature | Reason |
|---------|--------|
| Modifying GSD plugin files | §8 plugin boundary — reviewers are SB skills, not GSD modifications |
| Replacing existing GSD plan-checker/code-reviewer | Formalize into framework, don't replace |
| Review rounds for non-artifact outputs (console output, git commits) | Artifacts only — measurable, file-based |
| Blocking on INFO-level findings | Only ISSUE-level blocks; INFO is advisory |

## v2 Requirements

Deferred to future release.

### Advanced Review (beyond v0.16.0)

- **ARVW-12**: Review round learning — reviewers adapt finding thresholds based on historical pass rates per artifact type
- **ARVW-13**: Multi-reviewer orchestration — run multiple reviewers in parallel and merge findings

---
*Requirements defined: 2026-04-10*
*Last updated: 2026-04-10 after v0.16.0 milestone start*
