# Roadmap: Silver Bullet

## Milestones

- :white_check_mark: **v0.9.0 GSD-Mainstay Retrofitting** - Phases 1-5 (shipped)
- :white_check_mark: **v0.11.0 Enforcement Hardening** - Phases 6-8 (shipped)
- :white_check_mark: **v0.13.0 Orchestration Skills** - Phases 9-11 (shipped)
- :white_check_mark: **v0.14.0 Spec-Driven Development** - Phases 12-14 (shipped)
- :white_check_mark: **v0.16.0 Artifact Review System** - Phases 15-20 (shipped)
- :white_check_mark: **v0.20.0 Composable Paths Architecture** - Phases 21-29 (shipped)
- :white_check_mark: **v0.21.0 Hook Quality & Docs** - Phases 30-33 (shipped)
- :white_check_mark: **v0.22.0 Backlog Resolution** - Phases 34-38 (shipped)
- :white_check_mark: **v0.23.8 Patch: Issue Cleanup** - Phases 39-43 (shipped)
- :construction: **v0.24.0 Stability · Security · Quality** - Phases 44-48 (in progress)

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

### v0.22.0 Backlog Resolution

- [x] **Phase 34: Security P0 Remediation** - Rotate leaked Google Chat webhook token, scrub git history, add secret-scan guard (GitHub #24) (completed 2026-04-19)
- [x] **Phase 35: Stage 4 Security Hardening** - Symlink-refusing state writes, jq-based JSON/body construction, medium/low hardening batch (GitHub #25, #26, #27) (completed 2026-04-19)
- [x] **Phase 36: HOOK-14 Stop-Check Hardening** - Close fail-open edge cases, fill test coverage gaps, apply code quality polish (GitHub #17, #18, #19) (completed 2026-04-19)
- [x] **Phase 37: Stage 2 Consistency Audit** - Fix broken upstream skill references, eliminate hooks+config duplication and schema drift (GitHub #21, #22) (completed 2026-04-19)
- [x] **Phase 38: Gitignore & Docs Refresh** - Narrow `.claude/` gitignore rule, refresh stale versions/counts/CHANGELOG across public surfaces (GitHub #20, #23) (completed 2026-04-19)

### v0.23.8 Patch: Issue Cleanup

- [x] **Phase 39: CI Node.js 20 Deprecation Fix** - Upgrade GitHub Actions workflows to Node 24 (actions/checkout deprecation warning) (completed 2026-04-24)
- [x] **Phase 40: Silver-Update Semver Validation** - Validate $LATEST as semver before use in paths/git refs (GitHub #29) (completed 2026-04-24)
- [x] **Phase 41: Review-Loop-Pass Marker Fix** - Fix review-loop-pass marker mechanism blocked by tamper-detection hook (GitHub #30) (completed 2026-04-24)
- [x] **Phase 42: Trivial Bypass-File Semantics** - Rename/clarify trivial file that conflates two distinct semantics (GitHub #31) (completed 2026-04-24)
- [x] **Phase 43: Cryptographic Tag Signing** - Sign release tags cryptographically (GitHub #28) (completed 2026-04-24)

### v0.24.0 Stability · Security · Quality

- [x] **Phase 44: Session Stability Bugs + Open PRs** - Fix 6 critical session-stability bugs blocking day-to-day use; merge 2 open doc-scheme PRs
- [x] **Phase 45: Security Hardening** - Stage 4 security pass: symlink writes, jq sanitizers, medium/low batch, semver validation
- [x] **Phase 46: HOOK-14 Closure** - Close fail-open edges in stop-check.sh, fill test coverage gaps, apply code polish
- [x] **Phase 47: Consistency & Quality** - Cross-cutting improvements: gitignore, skill refs, hook dedup, doc-scheme, tamper regex
- [x] **Phase 48: Content Refresh & PM Feature** - Refresh stale public-facing content; add PM system awareness to /silver:init

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

### Phase 34: Security P0 Remediation
**Goal**: The leaked Google Chat webhook token is rotated and scrubbed from git history, and future re-introduction is automatically blocked
**Depends on**: Nothing (first phase of v0.22.0; urgent -- must ship first)
**Requirements**: SEC-01
**Success Criteria** (what must be TRUE):
  1. The currently-committed webhook token is revoked at the provider and a new token is issued; the new token lives only in a secrets manager / env var, never in source
  2. Git history is rewritten (via `git filter-repo` or BFG) to remove the token from all past commits; collaborators are notified to re-clone
  3. A pre-commit / CI secret-scan gate (gitleaks or equivalent) is active and would have caught the original leak
**Plans**: TBD

### Phase 35: Stage 4 Security Hardening
**Goal**: All Stage 4 security findings are resolved -- state writes refuse symlinks, JSON/body payloads are jq-constructed, medium/low hardening batch is landed
**Depends on**: Phase 34 (secret scrubbed before touching hooks that write state)
**Requirements**: SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. Every hook write under `~/.claude/.silver-bullet/` uses `O_NOFOLLOW` / `test -L` pre-check or equivalent; tests prove writes to symlinked state paths fail fast
  2. All JSON payloads and HTTP bodies in hooks are constructed via `jq -n ... | curl -d @-` (or equivalent); hand-rolled sanitizer functions are deleted
  3. Medium/low hardening items (umask on state reads, TOCTOU on state-file reads, safer `rm` patterns, `set -euo pipefail` audit) are applied across all hooks
**Plans**: TBD

### Phase 36: HOOK-14 Stop-Check Hardening
**Goal**: `stop-check.sh` is closed to fail-open edge cases, fully covered by tests, and consistently styled
**Depends on**: Phase 35 (security hardening may touch same files; land stop-check polish after)
**Requirements**: HOOK-06, HOOK-07, HOOK-08
**Success Criteria** (what must be TRUE):
  1. No code path in `stop-check.sh` silently exits 0 on malformed input, missing config, or unexpected JSON shape -- every such path logs the reason and fails closed (or is explicitly marked fail-open with justification)
  2. `tests/hooks/test-stop-check.sh` has positive + negative cases for every branch introduced in HOOK-14 and HOOK-06; line/branch coverage meets project floor
  3. Comment style, variable naming, numeric vs. string compares, and HOOK-* numbering in `stop-check.sh` are normalized and consistent with sibling hooks
**Plans**: TBD

### Phase 37: Stage 2 Consistency Audit
**Goal**: Broken skill references are fixed and hooks+config duplication/schema drift is eliminated
**Depends on**: Phases 35 and 36 (hooks stable before dedup refactor)
**Requirements**: CONS-01, CONS-02
**Success Criteria** (what must be TRUE):
  1. Every `Skill(skill="...")` invocation and every cross-skill path reference across the plugin resolves to an existing skill file; a CI check prevents regressions
  2. Required-skill lists, config keys, and state-file paths have a single source of truth; `lib/required-skills.sh`, `silver-bullet.config.json.default`, and per-hook arrays cannot diverge (enforced by a lint or unit test)
**Plans**: TBD

### Phase 38: Gitignore & Docs Refresh
**Goal**: The `.claude/` gitignore rule is narrowed to runtime-only paths, and all public-facing docs/site content consistently reflect v0.22.0 state
**Depends on**: Phases 34-37 (docs refresh must reflect the landed changes)
**Requirements**: IGNORE-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. `.gitignore` ignores only session/state paths under `.claude/` (e.g. `.claude/projects/`, `.claude/local/`); committed config like `.claude/settings.json` and `.claude/commands/` is tracked
  2. README.md, site/index.html, site/help/*.html, docs/ARCHITECTURE.md, and CHANGELOG.md all reflect the v0.22.0 release state -- no stale versions, skill/hook/flow counts, or missing changelog entries
**Plans**: TBD

### Phase 39: CI Node.js 20 Deprecation Fix
**Goal**: GitHub Actions workflows no longer run on the deprecated Node.js 20 runtime
**Depends on**: Nothing (first phase of v0.23.8)
**Requirements**: CI-NODE-01
**Success Criteria** (what must be TRUE):
  1. `.github/workflows/*.yml` files set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` env var or pin actions to Node 24-compatible versions; CI runs clean with no Node.js 20 deprecation annotations
**Plans:** 1/1 plans complete
Plans:
- [x] 39-01-PLAN.md -- Upgrade GitHub Actions to Node 24 (shipped in v0.23.8, 2026-04-24)

### Phase 40: Silver-Update Semver Validation
**Goal**: `silver-update` validates `$LATEST` is a valid semver string before using it in file paths or git refs, preventing silent corruption from malformed version strings
**Depends on**: Phase 39
**Requirements**: VALID-01
**Success Criteria** (what must be TRUE):
  1. `skills/silver-update/SKILL.md` contains explicit instruction to validate `$LATEST` matches `^v?[0-9]+\.[0-9]+\.[0-9]+` before using it in any path or git ref; malformed values produce a clear error and abort
**Plans:** 1/1 plans complete
Plans:
- [x] 40-01-PLAN.md -- Add semver validation to silver-update (shipped in v0.23.8, 2026-04-24)

### Phase 41: Review-Loop-Pass Marker Fix
**Goal**: The review-loop-pass marker mechanism works correctly -- markers can be written without being blocked by the tamper-detection hook
**Depends on**: Phase 39
**Requirements**: HOOK-09
**Success Criteria** (what must be TRUE):
  1. The review-loop-pass marker write path is whitelisted in `dev-cycle-check.sh` tamper detection (or the marker mechanism is redesigned to not write directly to the state file); review-loop completion can be recorded without hook interference
**Plans:** 1/1 plans complete
Plans:
- [x] 41-01-PLAN.md -- Fix review-loop-pass marker tamper-detection conflict (shipped in v0.23.8, 2026-04-24)

### Phase 42: Trivial Bypass-File Semantics
**Goal**: The `~/.claude/.silver-bullet/trivial` file name and semantics are clarified -- it currently conflates CI-red commit override with trivial-session bypass
**Depends on**: Phase 41
**Requirements**: SEM-01
**Success Criteria** (what must be TRUE):
  1. The trivial bypass file is either renamed to reflect its actual purpose, or documentation/comments clearly distinguish the two uses; hook code and user-facing docs are consistent
**Plans:** 1/1 plans complete
Plans:
- [x] 42-01-PLAN.md -- Clarify/rename trivial bypass-file semantics (shipped in v0.23.8, 2026-04-24)

### Phase 43: Cryptographic Tag Signing
**Goal**: Release tags are cryptographically signed so users can verify authenticity
**Depends on**: Phases 39-42
**Requirements**: SEC-05
**Success Criteria** (what must be TRUE):
  1. `git tag` commands in the release workflow use `-s` (GPG) or equivalent sigstore/SSH signing; `git verify-tag v0.23.8` succeeds; signing key is documented
**Plans:** 1/1 plans complete
Plans:
- [x] 43-01-PLAN.md -- Add cryptographic signing to release tags (shipped in v0.23.8, 2026-04-24)

### Phase 44: Session Stability Bugs + Open PRs
**Goal**: All 6 critical session-stability bugs are fixed and the 2 open doc-scheme PRs are merged -- hooks no longer corrupt state, emit false-positive blocks, or bypass enforcement for admin sessions
**Depends on**: Phase 43 (first phase of v0.24.0)
**Requirements**: BUG-01, BUG-02, BUG-03, BUG-04, BUG-05, BUG-06, PR-01, PR-02
**Success Criteria** (what must be TRUE):
  1. A session starting with the trivial bypass active is not broken by subsequent hook firings -- the `trivial` file survives all SessionStart hook events in the correct order
  2. The branch tracking file always ends with exactly one newline; reading it back never yields `mainmain` or similar concatenated strings; no spurious state wipes occur when switching branches
  3. `dev-cycle-check.sh` tamper guard targets only the state file path -- writing to the branch file or trivial file does not trigger a tamper-detection block
  4. `completion-audit.sh` does not emit a false-positive `COMMIT BLOCKED` when the heredoc body happens to contain a Silver Bullet state path literal
  5. `stop-check.sh` correctly skips enforcement for purely administrative sessions (no Write/Edit calls, no git diff output) without requiring trivial bypass
  6. The quality-gates Modularity dimension does not pass silently when the current milestone plan addresses a violation; the gate fires on code structure, not planning intent
  7. PR #37 (forge doc-scheme gate) and PR #38 (silver-ui doc-scheme gate) are merged and their changes are present on main
**Plans:** 4 plans
Plans:
- [ ] 044-01-PLAN.md -- Fix BUG-01 (SessionStart ordering), BUG-02 (branch newline), BUG-03 (tamper guard scope)
- [ ] 044-02-PLAN.md -- Fix BUG-04 (completion-audit heredoc), BUG-05 (stop-check admin bypass)
- [ ] 044-03-PLAN.md -- Fix BUG-06 (modularity planning-intent rationalization)
- [ ] 044-04-PLAN.md -- Merge PR-01 (PR #37 forge doc-scheme) and PR-02 (PR #38 silver-ui doc-scheme)

### Phase 45: Security Hardening
**Goal**: Stage 4 security hardening is complete -- all state file writes are symlink-safe, JSON/body payloads are jq-constructed, medium/low findings are resolved, and silver-update validates semver
**Depends on**: Phase 44 (stability bugs fixed before touching the same hook files for security)
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. Every write to `~/.claude/.silver-bullet/` state paths goes through `sb_safe_write()` (from `hooks/lib/nofollow-guard.sh`); a test proves that a symlinked state path causes the write to fail with a clear error rather than silently following the symlink
  2. Hand-rolled sanitizer strings in `pr-traceability.sh` and `silver-create-release/SKILL.md` are replaced with jq-based construction; the old sanitizer functions are removed
  3. Medium/low hardening items from the audit batch are applied: TOCTOU kill fix, phase-archive slug filter, ReDoS-safe regex, M8 core-rules tamper conflict resolved, plugin cache integrity check, tmpfile trap cleanup
  4. `silver-update/SKILL.md` rejects any `$LATEST` value that does not match `^v?[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$`; the skill aborts with a user-visible error on malformed input
**Plans**: TBD

### Phase 46: HOOK-14 Closure
**Goal**: `stop-check.sh` is hardened against all identified fail-open edge cases, comprehensively tested, and consistently styled
**Depends on**: Phase 45 (security pass may touch stop-check.sh; land polish after)
**Requirements**: HOOK-01, HOOK-02, HOOK-03
**Success Criteria** (what must be TRUE):
  1. All six identified edge cases in `stop-check.sh` (rev-list failure, gitignored untracked files, stale upstream ref, local-main fallback, detached HEAD, `--git-dir` guard) are handled explicitly -- no path silently exits 0 without logging
  2. `tests/hooks/test-stop-check.sh` covers every branch introduced by HOOK-14 including: real upstream zero-ahead scenario (Test 7b), setup-error swallowing prevention, non-git-dir path handling, and all baseline audit cases (Tests 1, 2, 4, 5, 6 confirmed passing without false negatives)
  3. Variable names, comment style, arithmetic comparisons, and HOOK-NN convention markers in `stop-check.sh` are consistent with sibling hook scripts; `--is-inside-work-tree` guard is present where required
**Plans**: TBD

### Phase 47: Consistency & Quality
**Goal**: Cross-cutting inconsistencies across hooks, skills, and config are resolved -- gitignore is narrowed, skill references resolve, duplication is eliminated, doc-scheme gates are ported, and tamper regex is tightened
**Depends on**: Phase 46 (hook changes stabilized before broad consistency sweep)
**Requirements**: QA-01, QA-02, QA-03, QA-04, QA-05, QA-06
**Success Criteria** (what must be TRUE):
  1. `.gitignore` no longer ignores the entire `.claude/` directory -- only the three runtime-only subpaths are excluded (`.claude/.silver-bullet/`, `.claude/.forge-delegation-active`, `.claude/worktrees/`); a CI check verifies the rule does not widen again
  2. Every `Skill(skill="...")` reference across the plugin resolves to a real file; `--multi-ai` is replaced with `--all`; `/tech-debt` and `/deploy-checklist` dependencies are resolved or documented
  3. Config-walk logic is extracted to `hooks/lib/find-config.sh` and used by all 6 hooks that currently duplicate it; trivial-bypass is consistently applied across all blocking hooks
  4. `superpowers:executing-plans` (step 15), `silver-feature` (PATH 13), and `superpowers:writing-plans` include explicit doc-scheme compliance instructions; `silver-devops` and `silver-bugfix` carry the Step 13b / PATH 10b doc-scheme gate
  5. `dev-cycle-check.sh` tamper-detection regex matches only leading command tokens -- heredoc bodies and commit message content no longer trigger false positives
**Plans**: TBD

### Phase 48: Content Refresh & PM Feature
**Goal**: All public-facing content accurately reflects current state, and `/silver:init` captures the project's issue tracker preference for use by backlog-filing skills
**Depends on**: Phase 47 (content refresh must reflect all v0.24.0 changes)
**Requirements**: DOC-01, FEAT-01
**Success Criteria** (what must be TRUE):
  1. The site version badge, README compliance-layer count, site meta skill/workflow counts, and search index entries are updated to reflect v0.24.0 state; CHANGELOG entries for v0.21 through v0.23 releases are filled in
  2. `/silver:init` prompts the user for their project management system (GitHub Issues, Linear, Jira, or none) and writes an `issue_tracker` field to `.silver-bullet.json`
  3. Skills that file backlog items (e.g. `silver-feature`, `silver-bugfix`, `silver-devops`) read `issue_tracker` from `.silver-bullet.json` and route issue creation to the configured system rather than defaulting to GitHub Issues unconditionally
**UI hint**: yes
**Plans**: TBD

## Progress

**Execution Order:**
Phases 30 -> 31 -> 32 -> 33 -> 34 -> 35 -> 36 -> 37 -> 38 -> 39 -> 40 -> 41 -> 42 -> 43 -> 44 -> 45 -> 46 -> 47 -> 48

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-20 | v0.9.0-v0.16.0 | 46/46 | Complete | 2026-04-10 |
| 21-29 | v0.20.0 | 12/12 | Complete | 2026-04-15 |
| 30. Shared Helper & CI Chores | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 31. Hook Bug Fixes | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 32. Hook Behavior Enhancements | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 33. Trivial-Session Bypass Docs | v0.21.0 | 1/1 | Complete    | 2026-04-16 |
| 34. Security P0 Remediation | v0.22.0 | 1/1 | Complete    | 2026-04-19 |
| 35. Stage 4 Security Hardening | v0.22.0 | 1/1 | Complete    | 2026-04-19 |
| 36. HOOK-14 Stop-Check Hardening | v0.22.0 | 1/1 | Complete    | 2026-04-19 |
| 37. Stage 2 Consistency Audit | v0.22.0 | 1/1 | Complete    | 2026-04-19 |
| 38. Gitignore & Docs Refresh | v0.22.0 | 1/1 | Complete    | 2026-04-19 |
| 39. CI Node.js 20 Deprecation Fix | v0.23.8 | 1/1 | Complete    | 2026-04-24 |
| 40. Silver-Update Semver Validation | v0.23.8 | 1/1 | Complete    | 2026-04-24 |
| 41. Review-Loop-Pass Marker Fix | v0.23.8 | 1/1 | Complete    | 2026-04-24 |
| 42. Trivial Bypass-File Semantics | v0.23.8 | 1/1 | Complete    | 2026-04-24 |
| 43. Cryptographic Tag Signing | v0.23.8 | 1/1 | Complete    | 2026-04-24 |
| 44. Session Stability Bugs + Open PRs | v0.24.0 | 4/4 | Complete    | 2026-04-24 |
| 45. Security Hardening | v0.24.0 | 1/1 | Complete    | 2026-04-24 |
| 46. HOOK-14 Closure | v0.24.0 | 1/1 | Complete    | 2026-04-24 |
| 47. Consistency & Quality | v0.24.0 | 1/1 | Complete    | 2026-04-24 |
| 48. Content Refresh & PM Feature | v0.24.0 | 1/1 | Complete    | 2026-04-24 |

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
| 999.19 | If silver-bullet hooks become a public extension surface (third-party projects or CI pipelines), add formal API versioning to the hooks interface -- currently internal-only so unversioned is acceptable, but extensibility skill flags it as a future risk | quality gates 2026-04-16 | Low | Medium | Deferred |
| 999.20 | Disable `hooks/ensure-model-routing.sh` model injection into GSD agent files; replace with GSD-native `model_overrides` config (e.g. `gsd-security-auditor: opus` in `.gsd/defaults.json`). SB must never patch third-party plugin source files. | audit 2026-04-16 | High | Low | Done |
| 999.21 | Split `tests/hooks/test-session-start.sh` into focused suites -- file is ~343 lines, above the 200-line soft limit for test files (hard limit 400). Suggested split: branch-scoped-state tests, trivial-file tests, output/injection tests, security tests. Pre-existing violation, not introduced by session-start branch-file fix. | quality gates 2026-04-16 | Low | Low | Deferred |
| 999.22 | Fix Test 8 in `tests/hooks/test-session-start.sh` deleting live `~/.claude/.silver-bullet/state` without restoring -- `rm -f "$REAL_STATE_FILE"` wipes the real state file on every test run, breaking stop-hook skill tracking. Fix: add `save_state`/`restore_state` helpers analogous to `save_branch`/`restore_branch`. | tech-debt 2026-04-16 | Medium | Medium | Deferred |
| 999.23 | Extract `lib/config-walk.sh` shared helper -- config file discovery logic is duplicated across 6 hooks (stop-check.sh, forbidden-skill-check.sh, compliance-status.sh, prompt-reminder.sh, session-start, dev-cycle-check.sh). Violates Reusability Rule 1 (Single Source of Truth). Extract walk logic into `sb_find_config_file()` function in new `lib/config-walk.sh`; update all 6 hooks to use it. Reduces ~50 LOC duplication; simplifies maintenance. | quality gates 2026-04-18 | High | Medium | Deferred |
| 999.24 | Add trivial-bypass to `forbidden-skill-check.sh` and `spec-session-record.sh` -- these hooks currently skip trivial-session bypass logic (8 hooks total skip it). forbidden-skill-check fires on every Skill PreToolUse (high frequency); spec-session-record fires on SessionStart. Both should exit early in trivial sessions. Source `lib/trivial-bypass.sh` and call `sb_trivial_bypass()` in both. Performance optimization for read-only turns. | quality gates 2026-04-18 | Medium | Low | Deferred |
| 999.25 | Audit and resolve `lib/required-skills.sh` vs. `silver-bullet.config.json.default` schema drift -- required-deploy includes `review-loop-pass-1 review-loop-pass-2` in lib but template default does NOT include them. Hooks will enforce these entries only if project lacks explicit `.silver-bullet.json`; projects with config won't see them. Either remove from lib or add to template default. Resolve inconsistency. | quality gates 2026-04-18 | Medium | Low | Deferred |
| 999.26 | Document `active_workflow` valid values and schema in silver-bullet.md or README -- `.silver-bullet.json` config accepts `"active_workflow": "devops-cycle"` (switches enforcement from silver-quality-gates to silver-blast-radius+devops-quality-gates), but valid values are undocumented. Add documentation of both values and their semantics. | quality gates 2026-04-18 | Low | Low | Deferred |
| 999.27 | Delete or formally disable `hooks/ensure-model-routing.sh` -- file is present, marked disabled (exit 0 at line 25), with code preserved for reference only (lines 27-114 never execute). Clean up: either delete the file entirely, or move to `.disabled/` directory if reference is needed. Reduces maintenance burden. Relates to 999.20 (already completed via GSD-native config). | quality gates 2026-04-18 | Low | Low | Deferred |
| 999.28 | `skills/silver-feature/SKILL.md` is at 450 lines -- over the documentation soft limit of 300 lines (hard limit 500). Pre-existing, not introduced in v0.23.10. Consider splitting into a slim orchestrator file + per-path appendix when the file approaches 480+ lines to stay within the hard limit. | quality gates 2026-04-24 | Low | Medium | Deferred |
| 999.29 | Normalize frontmatter schema in `skills/` CC wrapper skills added by forge-sb port -- brainstorming, finishing-branch, gsd-brainstorm, gsd-discuss, gsd-execute, gsd-intel, gsd-plan, gsd-progress, gsd-review, gsd-review-fix, gsd-secure, gsd-ship, gsd-validate, gsd-verify, tdd, writing-plans currently carry Forge-native fields (`id:`, `title:`, `trigger:`) alongside CC-native `name:` and `description:`. CC plugin loader ignores unknown fields (no functional regression), but creates schema inconsistency. Normalize these skills to CC-only frontmatter (`name:`, `description:`) in a follow-up cleanup pass. | code review 2026-04-24 | Low | Low | Deferred |
| 999.30 | Add CI lint step to verify frontmatter schema invariants: `skills/**/SKILL.md` must have `name:` field; `forge/skills/**/SKILL.md` must have `id:` but NOT `name:`. Prevents recurrence of the cf0d0d2-class bug where a skill was copied without schema adaptation. Integrate into the syntax-check target documented in CLAUDE.md. | code review 2026-04-24 | Medium | Low | Deferred |
| 999.31 | `run_hook` helper in `tests/hooks/test-ci-status-check.sh` (line 37) omits `hook_event_name` field, relying on the hook's `// "PostToolUse"` default. If that default changes, all Groups 1-5 silently change behavior. Add `"hook_event_name":"PostToolUse"` explicitly to the `run_hook` JSON template to make intent clear and tests resilient. | code review 2026-04-24 | Low | Low | Deferred |
| 999.32 | `docs/internal/pre-release-quality-gate.md` claims `completion-audit.sh` blocks `gh release create` until `quality-gate-stage-N` markers are in the state file -- but this enforcement is NOT implemented in `completion-audit.sh` (grepped, no matches). Additionally, the `echo "quality-gate-stage-N" >> ~/.claude/.silver-bullet/state` recording instruction is blocked by the tamper-detection hook at `dev-cycle-check.sh` line 143. Either: (a) implement the marker check in `completion-audit.sh` and whitelist the append via `is_whitelisted_append`, or (b) update the gate spec to reflect actual enforcement (skill invocations via `record-skill.sh`). Current gate is process-discipline only, not hook-enforced. | quality gate audit 2026-04-24 | Medium | Medium | Deferred |
| 999.33 | Split `hooks/dev-cycle-check.sh` (416 lines, hard limit 300) -- extract tamper-detection block (~35 lines) into `hooks/lib/tamper-check.sh` and plugin-boundary block (~45 lines) into `hooks/lib/plugin-boundary.sh`; source both from the main hook. Flagged by modularity quality gate v0.24.0 (file was over limit at time of modification). | quality gates 2026-04-24 | Medium | Medium | Deferred |
| 999.34 | Split `tests/hooks/test-dev-cycle-check.sh` (512 lines, hard limit 400) -- suggested split: Group 1-8 (state tamper + plugin boundary) into `test-dev-cycle-tamper.sh`, Group 9-11 (F-07 execution vs write) into `test-dev-cycle-plugin.sh`, Groups 12+ (workflow gate) into `test-dev-cycle-workflow.sh`. Flagged by modularity quality gate v0.24.0. | quality gates 2026-04-24 | Low | Medium | Deferred |
| 999.36 | `silver-init` Step 2.8 PM prompt is skipped in update mode (Phase 0 → Phase 3 direct jump) — when `.silver-bullet.json` already exists Phase 2 is bypassed, so `issue_tracker_value` is never set and Step 3.4 silently preserves the stale or absent value. Fix: in update mode, read existing `issue_tracker` from `.silver-bullet.json` and either preserve it silently or add a lightweight re-prompt when the field is absent. | code review v0.24.0 | Low | Low | Deferred |
| 999.35 | Split `skills/silver-init/SKILL.md` (577 lines, hard limit 500) -- extract Phase 1 dependency checks into `references/dependency-checks.md` and Phase 1.5 version freshness checks into `references/version-freshness.md`; slim Phase 1 in main skill to overview + delegate to references. Flagged by modularity quality gate v0.24.0. | quality gates 2026-04-24 | Low | Low | Deferred |
| 999.37 | Add integration test for SessionStart hook ordering invariant (BUG-01): fire all three SessionStart hooks in their declared hooks.json order (session-start → trivial-touch → spec-session-record), verify trivial file exists after all three complete, then fire a Write PostToolUse hook and verify trivial file is removed. Currently no test proves the ordering invariant holds — only end-to-end enforcement tests cover the bypass mechanism indirectly. | testing-strategy v0.24.0 | Medium | Low | Deferred |
| 999.38 | `record-skill.sh` DEFAULT_TRACKED is missing 3 skills that `stop-check.sh` DEFAULT_REQUIRED mandates: `verification-before-completion`, `test-driven-development`, `tech-debt`. Any project that does NOT override `skills.all_tracked` in `.silver-bullet.json` will find these skills are never recorded, making the stop hook permanently unsatisfiable. Fix: add the 3 missing skills to DEFAULT_TRACKED in `hooks/record-skill.sh` and sync DEFAULT_TRACKED with DEFAULT_REQUIRED in `hooks/stop-check.sh` as a consistency invariant. | bug 2026-04-24 | High | Low | Deferred |
| 999.40 | Release allowed before required review skills are completed — in agent-mode sessions hooks don't fire, so `completion-audit.sh` never gates `gh release create`, and the release is published before quality-gates / code-review / verification steps are invoked. The stop hook then blocks *after* the release is already public. Fix depends on resolving #48 (agent-mode hook firing). See issue #50. | bug 2026-04-24 | High | Medium | Deferred |
| 999.39 | Silver Bullet hooks do not fire in Claude Agent SDK / claude.ai/code web session contexts — `PostToolUse/Skill` events are not emitted by the runtime, so `record-skill.sh` is never invoked and no skills are ever recorded to state. The stop hook still fires and blocks every session. Workaround: manually pipe hook-format JSON to `record-skill.sh` via Bash. Fix options: (a) detect agent-session context in `stop-check.sh` and fail-open with a warning, (b) expose a `sb-record-skill <name>` CLI helper that agents can call from Bash instead of relying on the Skill PostToolUse hook, (c) document the workaround in `silver-bullet.md` for agent-mode sessions. | bug 2026-04-24 | High | Medium | Deferred |
