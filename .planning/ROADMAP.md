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
- :white_check_mark: **v0.24.0 Stability · Security · Quality** - Phases 44-48 (shipped)
- :construction: **v0.25.0 Issue Capture & Retrospective Scan** - Phases 49-54 (in progress)

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

### v0.25.0 Issue Capture & Retrospective Scan

- [x] **Phase 49: silver-add** - New /silver-add skill: classify, file to GitHub Issues+board or local docs/, cache board IDs, rate-limit resilience (completed 2026-04-24)
- [x] **Phase 50: silver-remove & silver-rem** - New /silver-remove and /silver-rem skills: remove issues by ID and capture knowledge/lessons per doc-scheme (completed 2026-04-24)
- [x] **Phase 51: Auto-Capture Enforcement** - Wire silver-add + silver-rem calls into silver-bullet.md §3b, all producing skill files, and session log template (completed 2026-04-24)
- [ ] **Phase 52: silver-forensics Audit** - Audit silver-forensics against gsd-forensics for 100% functional equivalence; fix all gaps before silver-scan
- [ ] **Phase 53: silver-update Overhaul** - Migrate /silver-update to marketplace install method; clean up stale legacy installations
- [ ] **Phase 54: silver-scan** - New /silver-scan retrospective scan skill: glob sessions, cross-reference history, human-gated filing via silver-add and silver-rem

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
**Goal**: All Stage 4 security findings are resolved -- state writes refuse symlinks, JSON/body payloads are jq-constructed, medium/low findings are resolved
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

### Phase 49: silver-add
**Goal**: Users and coding agents can file any deferred or identified work item to the correct PM destination with a stable, referenceable ID
**Depends on**: Phase 48 (FEAT-01 must be complete — `issue_tracker` field must exist in `.silver-bullet.json`)
**Requirements**: ADD-01, ADD-02, ADD-03, ADD-04, ADD-05
**Success Criteria** (what must be TRUE):
  1. User can invoke `/silver-add` with a plain-text description and receive back a stable ID (GitHub issue number or local `SB-I-N` / `SB-B-N`) after the item is classified and filed
  2. When `issue_tracker = "github"`, the filed item appears as a GitHub Issue with a `filed-by-silver-bullet` label AND is placed in the Backlog column of the project board — verified via `gh issue view` and `gh project item-list`
  3. When `issue_tracker` is absent or `"gsd"`, the item is appended with a sequential ID to `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` (directory created if absent) — no GitHub API calls are made
  4. On the second and subsequent GitHub invocations within a session, silver-add reads project board node ID, Status field ID, and Backlog option ID from `.silver-bullet.json` under `_github_project` rather than re-querying `gh project list`
  5. A GitHub secondary rate-limit response (HTTP 403/429) causes silver-add to retry with exponential backoff rather than failing immediately; the current session log's `## Items Filed` section gains one line per successful filing
**Plans:** 1 plan
Plans:
- [x] 049-01-PLAN.md — Write silver-add SKILL.md with GitHub + local routing, caching, rate limit retry, and session log recording; add silver-add to skills.all_tracked in both config files (completed 2026-04-24)

### Phase 50: silver-remove & silver-rem
**Goal**: Users can remove a tracked item by ID and capture knowledge or lessons insights into the correct monthly doc file
**Depends on**: Phase 49 (silver-remove needs the ID schema and file locations established by silver-add; silver-rem needs the doc-scheme knowledge directory structure to be understood before writing to it)
**Requirements**: REM-01, REM-02, MEM-01, MEM-02, MEM-03
**Success Criteria** (what must be TRUE):
  1. User can invoke `/silver-remove <id>` with a GitHub issue number; the issue is closed with reason `"not planned"` and a `removed-by-silver-bullet` label — or deleted if the user has `delete_repo` scope — and the skill always prints which action was taken
  2. User can invoke `/silver-remove SB-I-N` or `/silver-remove SB-B-N`; the matching entry in `docs/issues/ISSUES.md` or `docs/issues/BACKLOG.md` is marked `[REMOVED YYYY-MM-DD]` inline without deleting the line
  3. User can invoke `/silver-rem` with a knowledge insight; a formatted entry appears in `docs/knowledge/YYYY-MM.md` under the matching doc-scheme category (Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, or Open Questions)
  4. User can invoke `/silver-rem` with a lessons-learned insight; a formatted entry appears in `docs/lessons/YYYY-MM.md` under the matching doc-scheme category tag (`domain:`, `stack:`, `practice:`, `devops:`, or `design:`)
  5. When a new monthly `docs/knowledge/YYYY-MM.md` file is created for the first time, `docs/knowledge/INDEX.md` is updated with the new month entry and the file is created with the correct monthly header
**Plans:** 2 plans
Plans:
- [x] 050-01-PLAN.md — Write silver-remove SKILL.md (GitHub close + local inline removal); add silver-remove to all_tracked (completed 2026-04-24)
- [x] 050-02-PLAN.md — Write silver-rem SKILL.md (knowledge/lessons monthly append, INDEX.md management); add silver-rem to all_tracked (completed 2026-04-24)

### Phase 51: Auto-Capture Enforcement
**Goal**: The coding agent is instructed at every enforcement layer to file deferred items and knowledge/lessons insights in real time, and a post-release summary is generated after each milestone
**Depends on**: Phase 49 (enforcement references `/silver-add` by name; the skill must exist before instructions invoke it), Phase 50 (enforcement references `/silver-rem`; the skill must exist before instructions invoke it)
**Requirements**: CAPT-01, CAPT-02, CAPT-03, CAPT-04, CAPT-05
**Success Criteria** (what must be TRUE):
  1. `silver-bullet.md` §3b and `templates/silver-bullet.md.base` §3b (updated in the same commit) contain an explicit deferred-capture instruction block with a classification rubric distinguishing issue from backlog, and a separate instruction to call `/silver-rem` for knowledge and lessons insights
  2. Each of the five producing skill files (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-fast`) contains its own per-skill deferred-capture step calling `/silver-add` — not solely relying on `silver-bullet.md` for enforcement
  3. A new session log's `## Items Filed` section exists from the moment the log is initialized — `session-log-init.sh` (or the equivalent hook) creates this section in every new session log
  4. After `gsd-complete-milestone` succeeds, `silver-release` Step 9b reads all `## Items Filed` entries from session logs within the milestone window and presents a consolidated summary table of all items filed and knowledge/lessons recorded
**Plans:** 1+ plans
Plans:
- [x] 051-01-PLAN.md — Add §3b-i (deferred-item capture via /silver-add) and §3b-ii (knowledge/lessons capture via /silver-rem) to silver-bullet.md and templates/silver-bullet.md.base atomically (completed 2026-04-24)
- [x] 051-02-PLAN.md — Replace all gsd-add-backlog occurrences with silver-add in silver-feature/bugfix/ui; add Deferred-Item Capture blocks to all 5 producing skills (completed 2026-04-24)
- [x] 051-03-PLAN.md — Add ## Items Filed section to session-log-init.sh skeleton and idempotency block; add silver-rem session log recording step (CAPT-04) (completed 2026-04-24)
- [x] 051-04-PLAN.md — Add Step 9b post-release items summary to silver-release SKILL.md; reads ## Items Filed from milestone-window session logs after gsd-complete-milestone (CAPT-05) (completed 2026-04-24)

### Phase 52: silver-forensics Audit
**Goal**: silver-forensics is verified to be 100% functionally equivalent to gsd-forensics across all diagnostic dimensions, and any gaps are fixed before silver-scan is designed
**Depends on**: Phase 48 (no dependency on v0.25.0 phases; independent audit that must complete before Phase 54)
**Requirements**: FORN-01, FORN-02
**Success Criteria** (what must be TRUE):
  1. An audit report comparing `skills/silver-forensics/SKILL.md` against `gsd-forensics` across all six functional dimensions (session classification paths, evidence-gathering steps, GSD-awareness routing table, root-cause statement format, post-mortem report schema, UNTRUSTED DATA security boundary) is written to `.planning/` as evidence
  2. Every gap or divergence identified in the audit is fixed in `skills/silver-forensics/SKILL.md` before Phase 54 (silver-scan) begins; the audit report documents which gaps were found and what was changed
**Plans:** 2 plans
Plans:
- [x] 052-01-PLAN.md — Read both skill files and produce structured audit report at .planning/052-FORENSICS-AUDIT.md covering all six functional dimensions (FORN-01) (completed 2026-04-24)
- [ ] 052-02-PLAN.md — Apply all gaps from audit report to skills/silver-forensics/SKILL.md; append Fix Log to audit report (FORN-02)

### Phase 53: silver-update Overhaul
**Goal**: /silver-update installs updates exclusively via the Claude CLI marketplace method and removes any stale legacy installations automatically
**Depends on**: Phase 48 (independent of other v0.25.0 phases; can execute any time after v0.24.0)
**Requirements**: UPD-01, UPD-02
**Success Criteria** (what must be TRUE):
  1. User can invoke `/silver-update` and the update is performed via `claude mcp install silver-bullet@alo-labs` (or equivalent marketplace CLI command) — no manual `git clone` steps appear in the skill instructions; version check and changelog display still occur before the install step
  2. After a successful marketplace install, `/silver-update` scans `~/.claude/plugins/cache/` and `~/.claude/plugins/installed_plugins.json` for stale silver-bullet entries (including those under the legacy `silver-bullet@silver-bullet` key) and removes them, leaving only the newly installed version registered
**Plans**: TBD

### Phase 54: silver-scan
**Goal**: Users can retrospectively scan all project session logs to surface unaddressed deferred items and unrecorded knowledge/lessons insights, then file them with human approval
**Depends on**: Phase 49 (silver-add must exist for silver-scan to call it), Phase 52 (forensics audit must confirm the session-log evidence model before silver-scan is implemented)
**Requirements**: SCAN-01, SCAN-02, SCAN-03, SCAN-04, SCAN-05
**Success Criteria** (what must be TRUE):
  1. User can invoke `/silver-scan` and the skill globs `docs/sessions/*.md`, reads each file for deferred-item signals (structured sections and keyword grep), and presents only unresolved candidates — items confirmed as addressed by git history, CHANGELOG, or open-issue cross-reference are automatically excluded as stale
  2. For each unresolved candidate, silver-scan presents the item with context and a Y/n prompt before calling `/silver-add` — no item is filed without explicit user approval; the run stops at 20 candidates to prevent context overload
  3. silver-scan also detects knowledge/lessons insights in session logs not yet recorded in `docs/knowledge/` or `docs/lessons/`, presents them with Y/n, and calls `/silver-rem` for approved ones
  4. After the scan completes, a summary is displayed: total sessions scanned, deferred items found vs. filed (with assigned IDs) vs. skipped as stale or rejected, and knowledge/lessons entries recorded
**Pre-release gate**: Before CI and releasing this phase, execute the 4-stage `docs/internal/pre-release-quality-gate.md`
**Plans**: TBD

## Progress

**Execution Order:**
Phases 30 -> 31 -> 32 -> 33 -> 34 -> 35 -> 36 -> 37 -> 38 -> 39 -> 40 -> 41 -> 42 -> 43 -> 44 -> 45 -> 46 -> 47 -> 48 -> 49 -> 50 -> 51 -> 52 -> 53 -> 54

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
| 38. Gitignore & Docs Refresh | v0.22.0 | 1/1 | Complete    | 2026-04-24 |
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
| 49. silver-add | v0.25.0 | 1/1 | Complete    | 2026-04-24 |
| 50. silver-remove & silver-rem | v0.25.0 | 2/2 | Complete    | 2026-04-24 |
| 51. Auto-Capture Enforcement | v0.25.0 | 4/4 | Complete    | 2026-04-24 |
| 52. silver-forensics Audit | v0.25.0 | 1/2 | In progress | 2026-04-24 |
| 53. silver-update Overhaul | v0.25.0 | 0/0 | Not started | - |
| 54. silver-scan | v0.25.0 | 0/0 | Not started | - |
