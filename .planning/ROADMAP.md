# Roadmap: Silver Bullet

## Milestones

- :white_check_mark: **v0.9.0 GSD-Mainstay Retrofitting** - Phases 1-5 (shipped)
- :white_check_mark: **v0.11.0 Enforcement Hardening** - Phases 6-8 (shipped)
- :white_check_mark: **v0.13.0 Orchestration Skills** - Phases 9-11 (shipped)
- :white_check_mark: **v0.14.0 Spec-Driven Development** - Phases 12-14 (shipped)
- :white_check_mark: **v0.16.0 Artifact Review System** - Phases 15-20 (shipped)
- :white_check_mark: **v0.20.0 Composable Paths Architecture** - Phases 21-29 (shipped)
- :construction: **v0.21.0 Hook Quality & Docs** - Phases 30-33 (in progress)

## Phases

<details>
<summary>Completed milestones (Phases 1-29) -- shipped through v0.20.11</summary>

- [x] **Phase 1: Workflow File Rewrites** - Rewrite both workflow files as comprehensive orchestration guides
- [x] **Phase 2: silver-bullet.md Overhaul** - Add GSD process knowledge and hand-holding instructions
- [x] **Phase 3: Skill Evolution** - Evolve SB forensics to be GSD-aware
- [x] **Phase 4: Template Parity & Hook Verification** - Sync templates, verify hooks
- [x] **Phase 5: Documentation & Public-Facing** - README and site pages update
- [x] **Phase 6: Enforcement Techniques** - 4 missing enforcement mechanisms
- [x] **Phase 7: Close Enforcement Audit Gaps** - 16 actionable gaps closed
- [x] **Phase 8: Enforcement Test Harness** - Automated integration tests
- [x] **Phase 9: Silver Bullet Core Improvements** - silver:init, GSD state delegation, guided UX
- [x] **Phase 10: SB Orchestration Skill Files** - 7 named orchestration skills
- [x] **Phase 11: Website Content Refresh** - v0.13.0 site update
- [x] **Phase 12: Spec Foundation** - Canonical SPEC.md, silver-spec, spec floor enforcement
- [x] **Phase 13: Ingestion & Multi-Repo** - JIRA/Figma/Google Docs ingestion, cross-repo specs
- [x] **Phase 14: Validation, Traceability & UAT Gate** - Pre-build validation, PR traceability, UAT gate
- [x] **Phase 15: Bug Fixes & Reviewer Framework** - v0.14.0 bug fixes, reviewer interface + 2-pass loop
- [x] **Phase 16: New Artifact Reviewers** - 8 dedicated reviewer skills
- [x] **Phase 17: Existing Reviewer Formalization & Workflow Wiring** - 2-pass upgrade, workflow integration
- [x] **Phase 18: Configurable Review Depth** - Per-artifact depth config (deep/standard/quick)
- [x] **Phase 19: Review Analytics** - Structured metrics + silver-review-stats
- [x] **Phase 20: Cross-Artifact Consistency** - Cross-artifact reviewer, milestone completion gate
- [x] **Phase 21: Foundation** - Path contracts, WORKFLOW.md spec, artifact-review-assessor, doc-scheme update
- [x] **Phase 22: Core Paths** - 6 essential paths every composition uses
- [x] **Phase 23: Specialized Paths** - 6 context-triggered paths
- [x] **Phase 24: Cross-Cutting Paths + Quality Gate Dual-Mode** - 7 cross-cutting paths plus dual-mode quality gates
- [x] **Phase 25: Composer Redesign** - /silver as composer with supervision loop
- [x] **Phase 26: Hook Alignment + silver:migrate** - 5 hooks modified for WORKFLOW.md awareness plus migration skill
- [x] **Phase 27: silver-fast Redesign** - 3-tier complexity triage with gsd-quick flags
- [x] **Phase 28: Documentation Update** - silver-bullet.md, doc-scheme, ENFORCEMENT.md updates
- [x] **Phase 29: Help Center + Homepage** - Homepage refresh and help center rewrite

</details>

### v0.21.0 Hook Quality & Docs

- [x] **Phase 30: Shared Helper & CI Chores** - Extract trivial-bypass helper, fix umask, add version-drift CI warning (completed 2026-04-16)
- [x] **Phase 31: Hook Bug Fixes** - Fix false-positives in uat-gate and dev-cycle-check, fix ci-status-check deadlock (completed 2026-04-16)
- [x] **Phase 32: Hook Behavior Enhancements** - Session-intent awareness for stop-check, noise reduction for read-guard (completed 2026-04-16)
- [x] **Phase 33: Trivial-Session Bypass Documentation** - Document the bypass mechanism in user-facing docs (completed 2026-04-16)

## Phase Details

### Phase 30: Shared Helper & CI Chores
**Goal**: Duplicated trivial-bypass logic is consolidated into a single shared helper, and two CI/chore hygiene items are resolved
**Depends on**: Nothing (first phase of v0.21.0)
**Requirements**: REF-01, CI-01, CI-02
**Success Criteria** (what must be TRUE):
  1. A single shared helper file (e.g. `hooks/lib/trivial-bypass.sh`) exists and both `stop-check.sh` and `ci-status-check.sh` source it instead of inlining the trivial-bypass guard logic
  2. The `SessionStart` hook command that creates the trivial bypass file uses `umask 0077`, matching all other Silver Bullet hook scripts
  3. CI emits a visible, non-blocking warning when `plugin.json` version does not match the latest git tag -- the build does not fail, but the mismatch is surfaced
**Plans:** 1/1 plans complete
Plans:
- [x] 30-01-PLAN.md -- Extract shared trivial-bypass helper, fix SessionStart umask, add CI version-drift warning

### Phase 31: Hook Bug Fixes
**Goal**: Three hook correctness bugs are eliminated -- hooks no longer block users with false-positive errors or deadlock on CI failure
**Depends on**: Phase 30 (shared helper must exist before modifying ci-status-check)
**Requirements**: HOOK-01, HOOK-02, HOOK-03
**Success Criteria** (what must be TRUE):
  1. `uat-gate.sh` passes cleanly when a UAT.md summary table contains a FAIL column header in the header row -- only data rows with FAIL trigger the failure check
  2. `dev-cycle-check.sh` state-tamper detection does not false-positive when a heredoc body happens to contain a Silver Bullet state path string -- only actual write-destination arguments are checked
  3. After CI fails, the user can perform at least one `git commit` + `git push` cycle to fix the failing run without being deadlocked by `ci-status-check.sh` (via override flag, grace period, or explicit escape instruction)
**Plans:** 1/1 plans complete
Plans:
- [x] 31-01-PLAN.md -- Fix uat-gate FAIL header false-positive, dev-cycle-check heredoc false-positive, ci-status-check CI deadlock escape instruction

### Phase 32: Hook Behavior Enhancements
**Goal**: Advisory hooks stop firing in contexts where they add no value -- stop-check skips non-code sessions, read-guard suppresses redundant warnings
**Depends on**: Phase 30 (shared helper used by stop-check)
**Requirements**: HOOK-04, HOOK-05
**Success Criteria** (what must be TRUE):
  1. `stop-check.sh` dev-cycle skill checklist does not fire for sessions where no code-producing work occurred (e.g. backlog reviews, Q&A, documentation-only, housekeeping)
  2. `gsd-read-guard.js` does not emit the "will reject" advisory message when the file being edited was already read earlier in the same session -- the message only appears when a file genuinely has not been read yet
**Plans**: TBD

### Phase 33: Trivial-Session Bypass Documentation
**Goal**: Developers can find, understand, and manually invoke the trivial-session bypass mechanism from user-facing documentation
**Depends on**: Phase 31, Phase 32 (document the mechanism after all hook fixes are landed)
**Requirements**: DOC-01
**Success Criteria** (what must be TRUE):
  1. User-facing documentation (README.md or docs/ARCHITECTURE.md) explains what the trivial file is, how it is created automatically at session start, and how it is cleared when files are modified
  2. The documentation includes instructions for manually recreating the trivial file as an escape hatch when a hook blocks unexpectedly
**Plans**: TBD

## Progress

**Execution Order:**
Phases 30 -> 31 -> 32 -> 33

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-20 | v0.9.0-v0.16.0 | 46/46 | Complete | 2026-04-10 |
| 21-29 | v0.20.0 | 12/12 | Complete | 2026-04-15 |
| 30. Shared Helper & CI Chores | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 31. Hook Bug Fixes | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 32. Hook Behavior Enhancements | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 33. Trivial-Session Bypass Docs | v0.21.0 | 1/1 | Complete    | 2026-04-16 |

## Backlog

Items below are deferred, not yet scheduled to a milestone. Numbered 999.x.

| # | Item | Source | Priority | Effort | Status |
|---|------|--------|----------|--------|--------|
| 999.1 | `jq` CI assertions for `required_deploy`/`all_tracked` correctness (silent drift risk if arrays diverge) | docs/tech-debt.md Phase 2 | High | Low | Done |
| 999.2 | `diff` CI step for `docs/workflows/` vs `templates/workflows/` parity (template drift has caused bugs) | docs/tech-debt.md Phase 2 | High | Low | Done |
| 999.3 | Derive `finalization_skills` from `.silver-bullet.json` at hook runtime instead of hardcoded string in `hooks/dev-cycle-check.sh` line 371 | docs/tech-debt.md Phase 2 | Medium | Medium | Done |
| 999.4 | Investigate and fix T2-1 test failure in `tests/hooks/test-timeout-check.sh` ("expected 'Check-in', got: ") | forensics 2026-04-16 | Medium | Low | Done |
| 999.5 | Create or verify `docs/KNOWLEDGE.md` and `docs/LESSONS.md` -- referenced in session log but files are missing | forensics 2026-04-16 | Medium | Low | Done (exist as dirs) |
| 999.6 | Add test for roadmap-freshness hook: missing ROADMAP.md path edge case (deferred from aeda816 code review) | code review aeda816 | Medium | Low | Done |
| 999.7 | Fix regex convention drift in `hooks/roadmap-freshness.sh` that allows silent pass (deferred from aeda816 code review) | code review aeda816 | Medium | Low | Done |
| 999.8 | Create missing VERIFICATION.md for phases 25, 26, 27, 28, 29 (skipped during autonomous v0.20.0 execution) | forensics gsd-2026-04-16 | Low | Medium | Done |
| 999.9 | Reconcile STATE.md `completed_phases: 6` stale value + narrative section (shows Phase 21 active) | forensics gsd-2026-04-16 | Low | Low | Done |
| 999.10 | Investigate Phase 23 missing PLAN.md/CONTEXT.md artifacts (work completed, but planning artifacts absent) | forensics gsd-2026-04-16 | Low | Low | Done |
| 999.11 | PATH 9 layer parallelism: sequential invocation is current; true parallelism is a future optimization | Phase 24 CONTEXT.md | Low | High | Deferred |
| 999.12 | Post-work deferred-item capture step: add mechanism in SB composable flows to add deferred items to backlog after each flow's core work completes | user request 2026-04-16 | High | Medium | Done |
| 999.13 | During-work deferred-item capture: add instructions/mechanisms so that items deferred or ignored during execution are automatically added to GSD backlog | user request 2026-04-16 | High | Medium | Done |
| 999.14 | After-review backlog enforcement: after any review (code review, quality gates, security), low-priority/suggested items must be implemented immediately or added to backlog -- not silently dropped | user request 2026-04-16 | High | Low | Done |
| 999.15 | Analyze composable flows for atomicity: split non-atomic flows, eliminate redundancy from arbitrary compositions, fix ordering issues that cause work at wrong step | user request 2026-04-16 | High | High | Done |
| 999.16 | Document `SILVER_BULLET_STATE_FILE` env var override in ENFORCEMENT.md or README -- currently undocumented despite being used by hooks and tests | code review 2026-04-16 | Low | Low | Done |
| 999.17 | Add test for `hooks/session-start` security guard fallback path (invalid path outside `~/.claude/` falls back to default state file) | code review 2026-04-16 | Low | Low | Done |
| 999.18 | Ensure full implementation of `doc-scheme.base.md` is restored -- verify all sections from the base schema are present and correctly implemented in the live documentation scheme | user request 2026-04-16 | High | Medium | Done |
| 999.19 | If silver-bullet hooks become a public extension surface (third-party projects or CI pipelines), add formal API versioning to the hooks interface — currently internal-only so unversioned is acceptable, but extensibility skill flags it as a future risk | quality gates 2026-04-16 | Low | Medium | Deferred |
| 999.20 | Disable `hooks/ensure-model-routing.sh` model injection into GSD agent files; replace with GSD-native `model_overrides` config (e.g. `gsd-security-auditor: opus` in `.gsd/defaults.json`). SB must never patch third-party plugin source files. | audit 2026-04-16 | High | Low | Done |
