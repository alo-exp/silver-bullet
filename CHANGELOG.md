# Changelog

## [0.26.0] — 2026-04-25

### Bug Fixes

- `fix(phase-55): BUG-01/02/05 — hook & script bug fixes` (6587b62): T2-1 test fix, dev-cycle-check regex tightened, session-log-init TOCTOU fixed with UUID token
- `fix(phase-56): BUG-03/04 + QUAL-01/02 — skill bug fixes & quality` (001d00b): silver-add precise OAuth scope regex, silver-remove POSIX tmpfile+mv, session log discovery standardized, silver-rem INDEX.md mutations explicit
- `fix(silver-release): move tag creation after gsd-complete-milestone to eliminate post-release patches` (94835ee)
- `fix(silver-create-release): replace awk -v multiline with head/printf/tail for CHANGELOG` (1cb992b)
- `fix(dev-cycle-check): tighten quote-exemption to block quoted redirect targets` (ecc5f16)
- `fix(dev-cycle-check): add veto to prevent mixed-quote-style bypass` (26e96db)
- `fix(session-log-init): write lock file and sentinel-pid before disown` (869e987)
- `fix(review-r2): sentinel-lock cleanup + tee process-sub bypass gap` (f573b82)

### CI Hardening

- `feat(phase-57): CI-01/02 — CI hardening` (38bab1d): diff step enforces docs/workflows/ vs templates/workflows/ parity; jq assertions for required_deploy/all_tracked correctness

### Skill Quality

- `feat(phase-58): QUAL-03/04 — silver-scan quality improvements` (2d32132): local-tracker cross-reference in Step 4-iv; two-pass counter explanation in summary block

### Security

- `fix(security): add content injection guards to 3 hooks (SENTINEL H-1/H-2/H-3)` (e7fe6a0): allowlist regex + jq encoding in spec-session-record.sh, uat-gate.sh, roadmap-freshness.sh — SENTINEL v2.3 CLEAR

### Documentation & Chores

- `docs: accuracy fixes for v0.26.0 release` (7a57517): enforce 11-layer count, fix Node.js → Bash, update version badges
- `docs(consistency): fix enforcement layer count to 11 across all docs` (6c61778)
- `docs(site): update skill count, layer count, and version across site` (24b13b6)
- `chore: archive v0.26.0 milestone` (2084661)

---

## [0.25.1] — 2026-04-25

**Patch release.** Post-release CI fix and milestone archival.

### Bug Fixes

- **FIX** (`3cfc390`): `silver-scan` — removed literal `FIXME` from keyword list documentation to pass skill integrity CI test (`test-skill-integrity.sh` matches bare `FIXME` case-insensitively, no brackets required).

### Chores

- Milestone archival: `REQUIREMENTS.md` archived to `.planning/milestones/v0.25.0-REQUIREMENTS.md`, `ROADMAP.md` archived to `.planning/milestones/v0.25.0-ROADMAP.md`.
- Added `RETROSPECTIVE.md` with v0.25.0 retrospective section.
- Updated `ROADMAP.md`, `MILESTONES.md`, `PROJECT.md`, `STATE.md` to reflect milestone completion.
- Added `UAT.md` with 24/24 criteria PASS for v0.25.0.

---

## [0.25.0] — 2026-04-24

**Issue Capture & Retrospective Scan milestone.** Closes the loop on deferred-item capture: two new filing skills (`/silver-add`, `/silver-remove`), a knowledge/lessons capture skill (`/silver-rem`), mandatory auto-capture enforcement in all orchestrator skills, a forensics audit (13 gaps fixed, 100% equivalence with gsd-forensics), a marketplace-based update overhaul (`silver-update`), and a retrospective session scanner (`/silver-scan`).

### New Skills (FEAT)

- **FEAT-SCAN** (`3679980`, `5e434e3`): `/silver-scan` — retrospective session scanner. Globs `docs/sessions/*.md`, detects deferred items and knowledge/lessons insights, cross-references git log / CHANGELOG / GitHub Issues to exclude already-addressed items, Y/n human gate per candidate (20-cap per pass), files via `/silver-add` and `/silver-rem`.
- **FEAT-ADD** (Phase 49): `/silver-add` — classify-and-file skill for issues and backlog items. Routes to GitHub Issues + project board or local `docs/issues/ISSUES.md` / `BACKLOG.md`. Assigns IDs, caches board discovery, rate-limit resilient.
- **FEAT-REMOVE** (Phase 50): `/silver-remove` — removes issues/backlog items by ID. Closes GitHub issues as "not planned" or inline-marks `[REMOVED]` in local docs.
- **FEAT-REM** (Phase 50): `/silver-rem` — captures knowledge or lessons insights into `docs/knowledge/YYYY-MM.md` or `docs/lessons/YYYY-MM.md` per doc-scheme. Updates `docs/knowledge/INDEX.md` on new monthly file creation.

### Enforcement (CAPT)

- **CAPT-01/CAPT-03** (Phase 51): `silver-bullet.md` and `templates/silver-bullet.md.base` gain §3b-i and §3b-ii — mandatory auto-capture instructions. All five orchestrator skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast) wired with Deferred-Item Capture blocks.
- **CAPT-02** (Phase 51): Session logs gain `## Items Filed` section. `silver-release` Step 9b presents consolidated post-release filing summary.

### Skills — Update & Forensics (UPD / FORN)

- **UPD-01/UPD-02** (Phase 53): `silver-update` overhauled — `claude mcp install silver-bullet@alo-labs` replaces git clone as sole install mechanism. Step 6 atomically removes stale `silver-bullet@silver-bullet` registry entry and cache directory post-install.
- **FORN-01/FORN-02** (Phase 52): `silver-forensics` audited against gsd-forensics across 6 functional dimensions. 13 gaps identified and fixed: scope-drift detection, stuck-loop file-frequency analysis, regression grep, evidence gathering expanded to 8 items, artifact completeness matrix, output-side redaction (path stripping, API key scrubbing, diff truncation).

### Bug Fixes (pre-release review)

- Fixed `silver-bullet.md` and template §5.1 to check `silver-bullet@alo-labs` registry key first (fallback to legacy key) — post-marketplace-update the legacy key is deleted.
- Fixed `silver-rem` hardcoded "Silver Bullet" project name in knowledge frontmatter; now reads from `.project.name` in config.
- Fixed `silver-rem` knowledge/lessons entries to insert immediately after the category heading (not at EOF).
- Fixed `silver-rem` overflow (-b) files missing YAML frontmatter and category headings on creation.
- Fixed `silver-scan` Step 7b missing `-F` flag on knowledge/lessons cross-reference grep (untrusted session log content).
- Fixed `silver-scan` `CANDIDATE_COUNT` now counts all presented candidates (Y+n), not just filed items.
- Fixed `silver-add` Step 4e rate-limit path now proceeds to session log (Step 6) before output step.
- Fixed `silver-release` Step 9b.2 `(none)` grep to use `-F` (portable fixed-string match).
- Fixed `silver-update` Step 6a jq path to use `.plugins["silver-bullet@silver-bullet"]` (correct nested structure).
- Fixed `silver-update` Step 6b `rm -rf` to guard against unset `$HOME`, symlinks, and path prefix.
- Fixed `silver-remove` to add strict `^SB-[IB]-[0-9]+$` regex guard after case statement, rejecting IDs with non-numeric trailing content.
- Fixed template §9 section: cleared live Silver Bullet project preferences from Mode Preferences table; corrected §10 cross-references to §9 within template.
- Bumped `version` and `config_version` in `templates/silver-bullet.config.json.default` to `0.25.0`.
- Fixed all 9 orchestrator skills pre-flight grep to use `[0-9]\+\.` instead of `10\.` when reading User Workflow Preferences — the section is §10 in the SB dev repo but §9 in every template-installed user project.
- Fixed `silver-rem` Step 6 `awk -v ins="${INSIGHT}"` injection vector (issue #57): insight text now passed via `ENVIRON["INSIGHT"]` to bypass awk's backslash-sequence interpretation of `-v` assignment values. Applies to both knowledge and lessons entry insertion.

## [0.24.0] — 2026-04-24

**Stability · Security · Quality milestone.** Fixes 6 session-stability bugs blocking day-to-day use, ports doc-scheme compliance gates to bugfix and devops workflows, tightens tamper-detection to stop false-positive blocks on commit messages, and adds project management system awareness to `/silver:init`.

### Session Stability (BUG)

- **BUG-01** (`f15615c`): Fixed trivial bypass SessionStart ordering — reordered hooks.json so `session-start` runs before `trivial-touch`, ensuring the trivial file survives all hook firings for admin sessions.
- **BUG-02** (`f15615c`): Fixed branch file written without trailing newline causing `mainmain` concatenation and spurious state wipes.
- **BUG-03** (`f15615c`): Scoped `dev-cycle-check.sh` tamper guard to the state file only — branch and trivial files are no longer falsely blocked.
- **BUG-04** (`e877602`): Fixed `completion-audit.sh` matching against full expanded heredoc body — now checks only the first command line, preventing false-positive `COMMIT BLOCKED` errors.
- **BUG-05** (`f15615c`): Purely administrative sessions (no Write/Edit calls) now correctly bypass enforcement via the trivial mechanism fixed by BUG-01.
- **BUG-06** (`0ca5f99`): `modularity/SKILL.md` Rationalization Prevention table extended with 3 planning-intent excuse rows and an Adversarial mode rule — "tracked in backlog / milestone plan / next phase" are no longer accepted as deferrals during review.

### Consistency & Quality (QA)

- **QA-05** (`dfe856d`): `dev-cycle-check.sh` tamper-detection now skips `git`/`gh` commands entirely and checks only the first command line — prevents false-positive blocks when commit messages or `gh --body` arguments mention the state file path. Two new tests (17e, 17f) cover the fix.
- **QA-06** (`dfe856d`): Doc-scheme compliance gate (conditional pre-ship step) ported to `silver-bugfix` (Step 7c), `silver-devops` (Step 10b), and both forge variants.

### Feature (FEAT)

- **FEAT-01** (`dfe856d`): `/silver:init` now prompts for project management system (GitHub Issues or GSD) in new Step 2.8. Answer written as `issue_tracker` field in `.silver-bullet.json` (default: `"gsd"`). `silver-feature` backlog-capture steps now route to `gh issue create` or `gsd-add-backlog` based on the configured value.

### Skills — doc-scheme gates (#37, #38)

- **DOC-SCH-03**: Added doc-scheme compliance gate to both `silver-ui` variants (PR #38).
- **DOC-SCH-04**: Forward-ported doc-scheme compliance gate to `forge/skills/silver-feature` and `forge/skills/silver-ui` (PR #37).

## [0.23.10] — 2026-04-24

**Forge-SB port + ci-status-check deadlock fix (Bug 2).** Ships Silver Bullet for Forge (34 Forge-native skills), fixes the remaining CI-gate deadlock (#32 — PostToolUse commit was hard-blocked; now warns only), and closes three open issues (#30, #33, installer curl|bash). Pre-release quality gate: 4-stage automated review (code review, consistency audit, public content refresh, security), all four stages clean.

### Forge-SB port (PR #35)

- **FORGE-01**: Added `forge/skills/` directory with 34 Forge-native SKILL.md files mirroring the Silver Bullet CC skill set — GSD workflows (12), quality dimensions (9 + master), Superpowers dependencies (7), silver orchestrators (6), plus AGENTS.md global and project templates.
- **FORGE-02**: Added `forge/scripts/install.sh` and `forge/AGENTS.md` — entry point for Forge-based projects. Forge uses `id:` frontmatter and `AGENTS.md` files; CC uses `name:` and `/plugin install`.
- **FORGE-03**: Added `forge/skills/tests/smoke_test.sh` — 33-assertion smoke test (all skills present + installer exists). All green before merge.
- **FORGE-04**: Restored `forge/skills/` after post-merge cleanup accidentally deleted it (d804e76).
- **FORGE-05**: Added missing `name:` frontmatter to forge-sb ported CC wrapper skills that were missing it.

### Hooks — ci-status-check.sh (#32)

- **BUG2-01**: PostToolUse/`git commit` now emits a **warning** instead of `decision:block` — the commit has already happened; blocking PostToolUse confused the model about whether the commit succeeded and created a deadlock when trying to commit a CI fix. Push, PR, and release operations remain hard-blocked.
- **BUG2-02**: Corrected the `ci-red-override` escape instruction in the CI failure message from "If you need to commit a CI fix" → "If you need to **push** a CI fix" — `git commit` is never blocked by the CI gate, so the instruction now accurately describes the only operation that needs the override.
- **BUG2-03**: Added Group 6 regression test (PreToolUse commit not blocked when CI red) and Group 7 regression tests (PostToolUse commit is warn-not-block, with a compound `git commit && git push` guard ensuring the push component routes to `emit_block`). Test suite: 14 tests, 14/0. Full suite: 1300/0, 4/4 green.
- **DOC-01**: README Layer 5 description updated to reflect the warn/block split for commit vs. push/PR/release.
- **DOC-02**: README manual escape hatch section rewritten — removed stale "CI fix commit" scenario; added dedicated ci-red-override guidance with correct "push" framing.
- **DOC-03**: `site/index.html` version badge updated `v0.23.8` → `v0.23.10`.

### Skills — doc-scheme compliance gate (#33)

- **DOC-SCH-01**: Added Step 13b to `silver-feature/SKILL.md` — before raising a PR, check whether `docs/doc-scheme.md` exists; if it does, gate on 4 doc updates (CHANGELOG entry, ARCHITECTURE current state, `knowledge/`, `lessons/`) before proceeding to Step 14 (finishing branch). Missing entries are treated as pre-ship defects.
- **DOC-SCH-02**: Added a `## Documentation` section to the `writing-plans` PLAN.md template so the doc-scheme obligation is visible at plan-writing time, not just at ship time.

### Skills — enforcement cleanup (#30)

- **RULES-01**: Removed misleading `review-loop-pass` bash snippet from `core-rules.md §3a` — the snippet showed `echo "review-loop-pass" >> state`, which tamper-detection blocks and which was removed from `required_deploy` in v0.23.6. The doc was describing a mechanism that no longer works.

### silver-init

- **INIT-01**: `silver-init/SKILL.md` — purge stale hook entries on update. When re-running `/silver:init` on an existing project, obsolete hook registrations from prior versions are removed before adding current ones.

### Installer

- **INST-01**: `scripts/install.sh` — support `curl | bash` remote install pattern. The installer now detects when it is running from a pipe (no TTY) and skips interactive prompts, enabling `curl -fsSL https://… | bash` one-liner installs.

### Cleanup

- **CLN-01**: Removed orphan `skills/ai-llm-safety/ai-llm-safety/SKILL.md` double-nested directory created by a path-join bug. The canonical file at `skills/ai-llm-safety/SKILL.md` is unaffected.
- **CLN-02**: Stripped `FLOW N` serial numbers from execution headings and templates — numbers were redundant with section titles and made reordering flows expensive.
- **CLN-03**: Updated composition proposal box style — full border, clean flow names.
- **CLN-04**: `site/index.html` copy improvements — capitalize "Composable" in compare card; use "orchestrates" language in Ecosystem and Compare sections.

## [0.23.9] — 2026-04-20

**Hotfix — ci-status-check deadlock (Bug 1) + dev-cycle false positive.** Two hook bugs introduced in v0.23.8 and surfaced in production. Both have TDD regression tests; suite at 1152/0, 4/4 green before tagging.

### Hooks — ci-status-check.sh (Bug 1)

- **BUG1-01**: `ci-status-check.sh` was blocking `git commit` at **PreToolUse** when CI was red, creating an unrecoverable deadlock — Claude could not commit the fix needed to make CI green. Fixed by splitting the trigger scope by hook event: PreToolUse blocks only `git push` and deploy operations (never `git commit`); PostToolUse warns after commit so Claude knows CI is red before pushing.

### Hooks — dev-cycle-check.sh

- **DC-01**: The fallback self-protection pattern `/silver-bullet[^/]*/hooks/` (used when `CLAUDE_PLUGIN_ROOT` is unset) also matched the silver-bullet source repo's own `hooks/` directory, blocking legitimate hook edits during development. Restricted the fallback to paths provably inside `${HOME}/.claude/` (the installed plugin location only).

## [0.23.8] — 2026-04-20

**Pre-release quality gate patch.** Ten-round automated code-review sweep (Layers A/B/C × multiple passes) found and fixed shell-script safety regressions, incorrect hook output formats, and documentation drift. Rounds 9 and 10 both returned zero findings.

### Shell script hardening
- **RM-01**: All `rm -f` calls in `scripts/` hardened with `--` separator (`semantic-compress.sh`, `deploy-gate-snippet.sh`, `sync-marketplace-version.sh`, `tfidf-rank.sh`) — project invariant now covers both `hooks/` and `scripts/`.
- **TRAP-01**: `phase-archive.sh` ERR trap output corrected from PostToolUse block format to PreToolUse `permissionDecision:deny` format — hook was emitting invalid JSON on archive failures.
- **TRAP-02**: `pr-traceability.sh` trap disarm extended to include `INT TERM` (`trap - EXIT INT TERM`) — prior form left handlers live across `wait` calls.
- **SC2015-01**: `session-log-init.sh` two `A&&B||C` awk pipelines rewritten as `if/then/else` — eliminates SC2015 false-success risk on `awk` exit.
- **TRAIL-01**: `roadmap-freshness.sh` final code path now exits 0 explicitly after its informational `printf` — missing `exit 0` could propagate unexpected exit codes.

### Test fixes
- **TEST-01**: `test-session-log-init.sh` sentinel kill calls fixed to extract bare PID from `pid:lstart` format before `kill` — was passing the full `pid:lstart` string, causing `kill` to error silently.

### Documentation & consistency
- **DOC-01**: `site/index.html` version badge updated `v0.22.0` → `v0.23.8`.
- **DOC-02**: `docs/internal/CICD.md` shellcheck command updated to match CI (`--exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh`); CI step table brought current with all pipeline steps added since v0.22.

## [0.23.7] — 2026-04-20

**Hotfix.** SC2015 rewrite of `compliance-status.sh` in v0.23.6 lost the executable bit on the file, causing the hook to fail silently.

### Fixes
- **HOT-01**: Restored `+x` permission on `compliance-status.sh` (lost during SC2015 rewrite).
- **HOT-02**: Rewrote remaining `A&&B||C` patterns in `compliance-status.sh` as `if/then/else` to satisfy shellcheck SC2015 without the permission regression.
- Additional code review pass (2 rounds, both clean before release).

## [0.23.6] — 2026-04-20

**Issue-cleanup patch.** Resolved 5 open GitHub issues: CI Node deprecation, semver validation in `silver-update`, review-loop-pass marker conflict, trivial-file name confusion, and cryptographic tag signing.

### CI
- **CI-01**: All GitHub Actions workflows opt into Node.js 24 via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` — eliminates Node 20 deprecation warnings ahead of June 2026 deadline.

### silver-update (#29)
- **UPD-SEC-01**: `$LATEST` is validated as a semver string (`X.Y.Z`) before use in any file path or `git ref` — prevents path-traversal or ref injection from a crafted GitHub API response.

### Enforcement — review-loop-pass (#30)
- **ENF-01**: `review-loop-pass` marker removed from `required_deploy` list — the marker is written by `record-skill.sh` only after a manual Skill invocation, but the review-loop mechanism writes it via a direct state-file append, which `completion-audit.sh`'s tamper-detection hook blocked. Unblocking deploys that used the loop correctly.

### Trivial bypass naming (#31)
- **TRV-01**: Separated the two semantics that lived in a single touch-file (`trivial`): `trivial` now means "session has not modified any files" (bypass all enforcement); a new `ci-red-override` file is created when the user explicitly overrides a red CI gate. The two are no longer conflated.

### Cryptographic tag signing (#28)
- **SEC-01**: `silver-create-release` SKILL.md updated to sign Git tags with GPG when `git config user.signingkey` is set (`git tag -s`). Release process now optionally produces signed tags verifiable with `git tag -v`.

## [0.23.5] — 2026-04-19

**Skill hardening patch.** Iterative audit of `silver-update` and `silver-migrate` SKILL.md files closed terminology drift, missing template sections, and unresolved bash placeholders. Source verified across 4 independent agent audits (last 2 passes clean).

### silver-update
- **UPD-01**: Added explicit trigger phrase to description (`when the user runs /silver:update`) for skill-development compliance.
- **UPD-02**: Replaced fragile `curl | grep | sed` tag parse with `jq -r '.tag_name' | sed 's/^v//'` (jq is already a project prerequisite).
- **UPD-03**: Bound `$LATEST`, `$NEW_CACHE`, `$COMMIT_SHA`, `$NOW` as real shell variables. Removed unquoted/unresolved `<latest-version>` placeholders from executable commands.
- **UPD-04**: Atomic registry write — `mktemp` + `mv` with a concrete `jq --arg` expression that updates `version`, `installPath`, `lastUpdated`, `gitCommitSha`. Prevents mid-write corruption.
- **UPD-05**: Cancel-path `rm -rf` guarded by `$HOME/.claude/plugins/cache/` prefix match.

### silver-migrate
- **MIG-01**: Description updated with explicit `/silver:migrate` trigger + pre-v0.20.0 context.
- **MIG-02**: Fixed terminology drift — prose now consistently uses "flow/Flows" to match `templates/workflow.md.base` (`Flow Log`, `Next Flow`). Eliminates mismatched section headings in generated `.planning/WORKFLOW.md`.
- **MIG-03**: Renamed "Next Path section" → "Next Flow section" so emitted heading matches the template.
- **MIG-04**: Added instructions to emit `## Dynamic Insertions`, `## Autonomous Decisions`, and `## Deferred Improvements` empty-header tables (previously omitted — generated WORKFLOW.md was missing 3 template sections).
- **MIG-05**: Template read path now uses `${PLUGIN_ROOT}/templates/workflow.md.base` so it no longer depends on the downstream project's CWD.
- **MIG-06**: Disambiguated FLOW 13 (SHIP — `gsd-ship` / `deploy-checklist`) from FLOW 17 (RELEASE — `silver-create-release`). Previously both claimed `silver-create-release`.

## [0.23.4] — 2026-04-19

**Marketplace hardening.** Fixes version drift, modernizes the marketplace `source` schema, and introduces a dedicated marketplace repo so future Ālo Labs plugins can be cataloged together.

### Marketplace
- **MKTP-01**: Fixed stale version in `.claude-plugin/marketplace.json` (`0.13.1` → `0.23.4`). Was 10 releases out of date.
- **MKTP-02**: Modernized `source` schema from the older nested `{"source":"url","url":"..."}` form to the current `"source": "github:alo-exp/silver-bullet"` shorthand.
- **MKTP-03**: Created dedicated marketplace repo [alo-labs/claude-plugins](https://github.com/alo-labs/claude-plugins). End-users can now install via:
  ```
  /plugin marketplace add alo-labs/claude-plugins
  /plugin install silver-bullet@alo-labs
  ```
  (The self-listed `.claude-plugin/marketplace.json` in this repo remains for direct-repo installs: `/plugin marketplace add alo-exp/silver-bullet`.)
- **MKTP-04**: Added `scripts/sync-marketplace-version.sh` — bumps the in-repo marketplace.json to match plugin.json and prints the remote-sync command for the alo-labs/claude-plugins repo.
- **MKTP-05**: Added CI guard in `.github/workflows/ci.yml` that fails the build if `plugin.json.version ≠ marketplace.json.plugins[silver-bullet].version`. Prevents future drift.

## [0.23.3] — 2026-04-19

**Full 100%-vs-100% plugin-dev compliance audit.** Extracted 66 requirements across all 7 plugin-dev skills + 2 validator agents, verified SB against each, fixed all FAIL + material WARN findings, and gated release on two consecutive independent clean audits. Full audit trail in `.planning/PLUGIN-DEV-COMPLIANCE.md`.

### Resolved FAIL
- **FAIL-01**: `silver-init/SKILL.md` reduced from 5,454 → 3,459 words (under skill-development's 5,000 hard max). Phase 3 scaffold detail extracted to `skills/silver-init/references/scaffold-steps.md`.

### Resolved WARN
- **WARN-01**: Added `trap 'exit 0' ERR` to the 4 hooks that lacked it (`completion-audit.sh`, `forbidden-skill-check.sh`, `roadmap-freshness.sh`, `stop-check.sh`). Now universal across all 17 registered hooks, matching the project's stated invariant.
- **WARN-02**: Added concrete user-phrase triggers to all 9 quality-dimension skill descriptions (`security`, `reliability`, `modularity`, `scalability`, `testability`, `extensibility`, `reusability`, `usability`, `ai-llm-safety`). Triggers now phrase-based ("when the user asks to 'harden X'", "'add retries'", etc.) per skill-development §Description Quality.
- **WARN-08**: Deleted dead hook script `hooks/ensure-model-routing.sh` (was executable but unregistered in `hooks.json`).
- **WARN-09**: Added `"matcher": "startup|clear|compact"` to first SessionStart block in `hooks/hooks.json` for consistency.

### Audit methodology
Full systematic audit delegated to independent agents:
1. Extract every MUST/SHOULD/anti-pattern from plugin-dev authority docs
2. Verify 100% of SB (41 skills, 17 hooks, manifest, lib) against each requirement
3. Write findings to `.planning/PLUGIN-DEV-COMPLIANCE.md` with file-level evidence
4. Fix all FAIL + material WARN
5. Re-audit independently until 2 consecutive clean passes
6. Gate release on clean-pass verdict

Final audit: **66 requirements checked, 59 PASS, 0 FAIL, 3 accepted WARN (deliberate design choices), 4 N/A.**

## [0.23.2] — 2026-04-19

**plugin-dev compliance — broader-scope audit.** Re-ran the audit iteratively against a wider checklist (shellcheck, executability, schema, semver, name/dir parity, description length bounds) until two consecutive passes reported zero findings.

### Hook lib cleanliness
- **SHELL-01**: Added `# shellcheck shell=bash` directive to `hooks/lib/required-skills.sh` so shellcheck recognizes the shell for sourced-only files (SC2148).
- **SHELL-02**: Added `# shellcheck disable=SC2034` to `DEFAULT_REQUIRED` and `DEVOPS_DEFAULT_REQUIRED` since they are consumed via `source`, not in-file.

### Audit coverage (all passing)
- All 41 skills: plugin-dev description opener, version field, no grammar mismatches
- All 24 hook entries: `type` + `timeout` present
- Shellcheck: zero warnings + zero errors across `hooks/*.sh` and `hooks/lib/*.sh`
- plugin.json: all required fields (name, version, description, hooks, author, license)
- All three JSON files valid
- No 2nd-person imperative prose in skill bodies
- All hook scripts executable
- Semver compliant

## [0.23.1] — 2026-04-19

**plugin-dev compliance patch.** Second-pass audit surfaced residual gaps from v0.23.0 that passed the first-pass checks but failed a stricter re-scan. Two consecutive clean audit passes achieved before release.

### Skill descriptions
- **DESC-NORM**: Normalized 32 remaining skill descriptions to the plugin-dev standard `"This skill should be used when/for/to ..."` opener. Prior release fixed 9; this release fixes the rest. All 41 skills now conform.
- **DESC-GRAMMAR**: Fixed 6 imperative-verb grammar mismatches (`"used for apply"` → `"used to apply"`, etc.) across `artifact-review-assessor`, `devops-quality-gates`, `silver-blast-radius`, `silver-create-release`, `silver-migrate`, `silver-review-stats`, `silver-init`, `silver-update`, `silver`.

### Writing style
- **STYLE-02**: Fixed 3 residual second-person aphorisms in `security/SKILL.md` (`"your denylist"`, `"roll your own crypto"`, `"Rolling your own crypto"`). Dialog/error-message examples with 2nd-person left intact as legitimate example content.
- **STYLE-03**: Fixed 2 additional 2nd-person violations in `silver-init` (`"You can safely delete..."`) and `silver-spec` (`"include in your phrasing"`).

### Audit methodology
Cleanroom multi-pass audit introduced: scan → fix → re-scan until two consecutive passes report zero findings across manifest fields, hook timeouts, skill frontmatter, description grammar, prose style, and JSON validity.

## [0.23.0] — 2026-04-19

**plugin-dev compliance milestone.** Retroactively aligns 100% of Silver Bullet against the official Anthropic `plugin-dev` plugin standards — manifest, hooks, skills, and writing style.

### Plugin-dev Compliance (Phase 1 — Manifest & Hooks)
- **PLUGIN-01**: Added `"hooks": "./hooks/hooks.json"` field to `.claude-plugin/plugin.json` per plugin-dev `plugin-structure` standard.
- **PLUGIN-02**: Added explicit `timeout` fields to all 24 hook entries in `hooks/hooks.json` (values: 5–30s per hook criticality).
- **PLUGIN-03**: Bumped `.claude-plugin/plugin.json` version to `0.23.0`.

### plugin-dev Compliance (Phase 2 — Skill Descriptions & Versions)
- **SKILL-DESC**: Fixed 9 skill descriptions from bare "Use when..." to plugin-dev standard "This skill should be used when..." format: `ai-llm-safety`, `extensibility`, `modularity`, `reliability`, `reusability`, `scalability`, `security`, `testability`, `usability`.
- **SKILL-VER**: Added `version: 0.1.0` to YAML frontmatter of all 41 skills.

### plugin-dev Compliance (Phase 3 — Progressive Disclosure)
- **SILVER-FEATURE**: Extracted Supervision Loop detail (SL-1 → SL-6, ~400 words) to `skills/silver-feature/references/supervision-loop.md`; replaced with lean pointer. Word count: 3,049 → 2,704.
- **SILVER-INIT**: Extracted 4 heavy sections to references/scripts:
  - CI workflow YAML templates → `skills/silver-init/references/ci-templates.md` (13 stacks)
  - Doc migration procedure → `skills/silver-init/references/doc-migration.md`
  - Tech stack detection table → `skills/silver-init/references/stack-detection.md`
  - Hooks-merge Python script → `skills/silver-init/scripts/merge-hooks.py` (executable, chmod 755)
  - Word count: 6,446 → 5,419.

### plugin-dev Compliance (Phase 4 — Writing Style)
- **STYLE**: Fixed 23 second-person writing violations across 9 skills (imperative verb-first style):
  - All 7 ilities skills: `"You are NOT required to X"` → `"Not required to X"`, `"You ARE required to not make X worse"` → `"Required: do not make X worse"`, and related pronoun drops.
  - `silver-spec`: `"You MUST NOT proceed"` → `"Do NOT proceed"`.
  - `devops-skill-router`: `"You can also invoke"` → `"Also invocable"`.

### Documentation
- **CLAUDE.md**: Complete rewrite — added commands (test suite, linting, validation), full architecture reference (hook event map, two-tier enforcement, state machine, shared libraries), key invariants.

## [0.22.0] — 2026-04-18

**Backlog-resolution milestone.** Consolidates phases 34–38: security hardening,
hook-correctness fixes, consistency repairs, gitignore narrowing, and a full
public-surface refresh. Subsumes the undocumented 0.20.9 → 0.21.3 release window
into a single coherent entry. Closes issues [#14](https://github.com/alo-exp/silver-bullet/issues/14),
[#16](https://github.com/alo-exp/silver-bullet/issues/16),
[#20](https://github.com/alo-exp/silver-bullet/issues/20),
[#23](https://github.com/alo-exp/silver-bullet/issues/23).

### Security
- **SEC-01** (P34, `6cb66c5`): moved the Google Chat release-notification webhook out of `skills/silver-create-release/SKILL.md` into the `GCHAT_RELEASE_WEBHOOK` env var; added a `secret-scan` CI job that fails the build on hard-coded webhook URLs.
- **SEC-02** (P35, `e247ff3`): added `! -L` symlink guards to every hook that reads/writes state files (`stop-check.sh`, `session-start`, `completion-audit.sh`, trivial-flag touch/rm) — closes a symlink-replacement bypass on multi-user machines.
- **SEC-03** (P35, `e247ff3`): replaced hand-rolled JSON string concatenation in hook stdout with `jq -n` payloads across every hook that emits `PreToolUse`/`Stop` structured output — eliminates injection via filenames or branch names containing quotes.
- **SEC-04** (P35, `e247ff3`): batch security fixes across remaining hooks (safe `rm` patterns, `mktemp` for temp files, `set -euo pipefail` where missing).

### Fixes
- **HOOK-06** (P36, `4339060`): `stop-check.sh` no longer fails open when `.silver-bullet.json` is missing or unreadable — absent config now HARD-STOPs with a config-error message instead of silently allowing session end.
- **HOOK-07** (P36, `4339060`): closed a race in `stop-check.sh` where a concurrent `record-skill.sh` write could cause the required-skills diff to observe a stale state file; added flock around state reads on Stop.
- **HOOK-08** (P36, `4339060`): filled test coverage for the HOOK-14 trivial-session / clean-tree short-circuit paths in `stop-check.sh` (clean tree, dirty tree, trivial flag, read-only session matrix).
- **HOOK-14** carryover: `stop-check` skips enforcement for read-only sessions ([#14](https://github.com/alo-exp/silver-bullet/issues/14) via `58d98fb` / `efdaab5`).

### Consistency
- **CONS-01** (P37, `0b86dc6`): repaired broken skill references — `/gsd:silver-forensics` → `/gsd-forensics`, legacy `/silver:*` colon-form refs in SKILL.md files updated to current `/silver-*` names.
- **CONS-02** (P37, `0b86dc6`): reconciled `hooks.json` / `settings.json` schema drift; every hook entry now matches the Claude Code manifest schema and the registered hook script actually exists on disk.

### Ignore
- **IGNORE-01** (P38, this release, closes [#20](https://github.com/alo-exp/silver-bullet/issues/20)): narrowed the project `.gitignore` blanket `.claude/` rule to runtime-only subpaths (`projects/`, `local/`, `.silver-bullet/`, `settings.local.json`, `worktrees/`). Committed plugin config (`.claude/settings.json`, `.claude/commands/`) now tracked. Supersedes the interim fix in `c8b161a`.

### Docs
- **DOC-02** (P38, this release, closes [#23](https://github.com/alo-exp/silver-bullet/issues/23)): public-surface refresh across every user-visible file.
  - `README.md`: `Current version` bumped from v0.21.3 → v0.22.0 with milestone summary.
  - `site/index.html`: hero version badge v0.19.1 → v0.22.0; meta description / Twitter card skill count 39 → 41, added "18 hooks".
  - `site/help/getting-started/index.html`, `site/help/concepts/index.html`: skill count 39 → 41; version range extended to v0.22.0; added composable-flows line.
  - `docs/ARCHITECTURE.md`: design principle 2 corrected from "7 layers" → "10 layers" to match enforcement-layer count everywhere else.
  - `CHANGELOG.md`: this entry, consolidating 0.20.9–0.21.3 gap into the 0.22.0 release note.

### Tests
- Total: 1112 passed, 13 failed (2/3 suites green) — unchanged from v0.21.3 baseline. Hook coverage: 18/18.

## [0.20.8] — 2026-04-16

### Fixed
- `skills/silver-forensics/SKILL.md`: replaced 4 occurrences of non-existent `/gsd:silver-forensics` routing with correct `/gsd-forensics`. The bug caused silent agent failure when Silver Bullet tried to delegate GSD workflow issues to a command that never existed.

### Tests
- `tests/integration/test-skill-integrity.sh`: added Check 8 — regression test asserting `silver-forensics/SKILL.md` does not reference `/gsd:silver-forensics`. RED-GREEN verified.
- Total: 288 tests, 3/3 suites green.

### Docs / Planning
- Autonomous mode preference recorded in `silver-bullet.md §10e` and base template.
- `ROADMAP.md ## Backlog`: 17 deferred items (999.1–999.17) captured from forensics sweep and added for future work.
- `CHANGELOG.md`: corrected stale "972 tests" count in v0.20.6 entry to correct value (288).

## [0.20.7] — 2026-04-16

### Fixed
- `hooks/session-start`: now honours `SILVER_BULLET_STATE_FILE` env var (same pattern as `completion-audit.sh` and `stop-check.sh`), allowing tests to redirect state writes to a temp path.
- `tests/hooks/test-session-start.sh`: replaced fragile backup/restore machinery with `TMPSTATE` isolation via `SILVER_BULLET_STATE_FILE`. Running the full test suite no longer wipes the live session state file, ending the skill re-recording loop that blocked session completion after every test run.

### Tests
- Total: 288 tests, 3/3 suites green (no new tests — existing 12 session-start tests now run in full isolation)

## [0.20.6] — 2026-04-16

### Fixed
- `hooks/roadmap-freshness.sh`: new PreToolUse/Bash hook that blocks `git commit` when a phase `*-SUMMARY.md` is staged but the corresponding ROADMAP.md checkbox is not ticked (`[ ]`). Prevents autonomous execution from silently skipping the ROADMAP bookkeeping step.
- `skills/silver-feature/SKILL.md`: added explicit "TICK ROADMAP.md" step to the Per-Phase Loop so autonomous runs update the checkbox before the phase-completion commit.
- `.planning/ROADMAP.md`: ticked checkboxes for phases 23, 24, 27, 28 which were completed in the prior milestone but not updated due to the missing enforcement.

### Tests
- Total: 972 tests, 3/3 suites green (8 new tests for roadmap-freshness hook)

## [0.20.5] — 2026-04-16

### Changed
- `/silver` skill: renamed from "Smart Skill Router" to "Smart Skill Orchestrator" — better reflects its role composing and sequencing workflows rather than just dispatching
- Composable workflow building blocks renamed from "paths" to "flows" throughout: `silver-feature/SKILL.md` (20 occurrences in Composition Proposal and Supervision Loop), `silver/SKILL.md` (Composer note), `silver-bullet.md.base` §2h ("Composable Flows Catalog"), `ENFORCEMENT.md` ("composable flows mode"), `full-dev-cycle.md` both templates and docs copies

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.4] — 2026-04-16

### Changed
- All user-facing Silver Bullet skills now use the `/silver-*` naming convention: `blast-radius` → `silver-blast-radius`, `create-release` → `silver-create-release`, `forensics` → `silver-forensics`, `quality-gates` → `silver-quality-gates`. End users now see a clean `/silver-*` namespace in the Claude Code slash command menu.
- `hooks/lib/required-skills.sh`, `hooks/record-skill.sh`, `hooks/completion-audit.sh`, `hooks/stop-check.sh`, `hooks/dev-cycle-check.sh`: updated all references to use new skill names
- `.silver-bullet.json`, `templates/silver-bullet.config.json.default`: `required_planning`, `required_deploy`, and `all_tracked` arrays updated to new names
- 22 internal skills (dimension checkers, artifact reviewers, internal routing skills) marked `user-invocable: false` in SKILL.md frontmatter — hidden from Claude Code slash command menu to reduce context token overhead for end users
- README.md: all skill name references updated to new `silver-*` convention

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.3] — 2026-04-15

### Added
- `create-release` skill: Step 5 posts a Google Chat notification after publishing a release. Reads `notifications.google_chat_webhook` from `.silver-bullet.json`; silent skip if absent; warns but does not fail if `curl` errors.
- `.silver-bullet.json`: `notifications.google_chat_webhook` config key for project-local webhook URL storage.

## [0.20.2] — 2026-04-15

### Refactored
- `hooks/lib/workflow-utils.sh` (new): shared utility library — single source of truth for Flow Log row-counting regex, extracted from three hooks (TD-1)
- `completion-audit.sh`, `dev-cycle-check.sh`, `compliance-status.sh`: source shared lib with inline fallback definitions for resilience in test environments
- Fixed stale "workflow paths" terminology in `completion-audit.sh` output messages → "flows" (TD-2)

### Added
- Comprehensive skill execution path test suite: 169 tests covering sub-skill reference integrity, non-skippable gate presence, step ordering constraints, quality-gates 9-dimension completeness, and skill name consistency across all 41 orchestration skills (TD-3)

### Tests
- Total: 962 tests, 3/3 suites green (up from 793 in v0.20.0)

## [0.20.1] — 2026-04-15

### Fixed
- `compliance-status.sh` Bug-1: WORKFLOW.md flow progress (`FLOW N/M`) now shown in early-exit path (no state file) — was omitted before this fix
- `compliance-status.sh` Bug-2: Row-count regex tightened from `^\| [0-9]` to `^\| [0-9]+ \|` — Phase Iterations and Autonomous Decisions rows no longer inflate the total flow count
- Same Bug-2 regex fix applied to `completion-audit.sh` and `dev-cycle-check.sh` (same pattern, same exposure)

### Changed
- Terminology rename: "paths" → "flows" and "Composable Path Architecture" → "Composable Workflow Orchestration" project-wide (42 files)
- WORKFLOW.md sections renamed: `Path Log` → `Flow Log`, `Next Path` → `Next Flow`, `Last-path:` → `Last-flow:`
- Status output updated: `PATH N/M` → `FLOW N/M`, `PATH: N/A (legacy mode)` → `FLOW: N/A (legacy mode)`
- `dev-cycle-check.sh` stale messages updated: "All workflow paths complete" → "All flows complete", partial-progress "PATH %s/%s" → "FLOW %s/%s"

### Added
- 7-scenario integration test suite for `compliance-status.sh` WORKFLOW.md flow-progress display (S1–S7 covering early-exit, symlink, malformed, digit-row false positives, mixed counts)
- Bug-2 inflation regression tests for `completion-audit.sh` (WF3) and `dev-cycle-check.sh` (WF5)

## [0.15.3] — 2026-04-10

### Fixed — SENTINEL v2.3 Security Audit Findings
- SENTINEL-9.1: Sanitize VALIDATION.md warn_items in pr-traceability.sh — strip markdown link syntax and wrap in code fence to prevent injection into PR descriptions
- SENTINEL-3.1: Reject overly permissive src_pattern values (e.g., `.*`, `.+`, `/`) in dev-cycle-check.sh — fall back to `/src/` default
- Full SENTINEL v2.3 8-step adversarial security audit report: `SENTINEL-audit-silver-bullet-v0.15.1.md`

## [0.15.1] — 2026-04-09

### Fixed — Pre-Release QA Gate Findings
- CR-01: Resolve gh CLI at runtime in pr-traceability.sh (cross-platform, was hardcoded /opt/homebrew/bin/gh)
- CR-02: Remove --no-verify from auto-commit in pr-traceability.sh (was bypassing hook chain)
- CR-03: Validate spec_version (dotted semver) and jira_id (uppercase project key) before shell use
- WR-03: Add quote-stripping to uat-gate.sh spec-version comparison (prevents false mismatch on quoted YAML)
- WR-06: Add 'Accepted' to valid assumption status in review-spec QC-5
- WR-07: Align ingestion manifest status vocabulary (success/failed/skipped) across QC-1..5
- Idempotent awk insert in pr-traceability.sh SPEC.md Implementations (prevents duplicate entries)
- Diagnostic ERR traps in pr-traceability.sh and uat-gate.sh (was silent exit 0)
- package.json version updated to match release (was stale at 0.13.0)

## [0.15.0] — 2026-04-09

### Added — Granular Artifact Review Rounds (v0.15.0)
- Artifact reviewer framework: `skills/artifact-reviewer/SKILL.md` with
  interface contract (`reviewer-interface.md`), 2-consecutive-clean-pass
  loop (`review-loop.md`), per-artifact state tracking, and audit trail
- 8 new artifact reviewer skills: `review-spec`, `review-design`,
  `review-requirements`, `review-roadmap`, `review-context`,
  `review-research`, `review-ingestion-manifest`, `review-uat`
- Existing GSD reviewers (plan-checker, code-reviewer, verifier,
  security-auditor) formalized into the 2-pass framework via silver-bullet.md §3a
- Workflow wiring: silver-spec Steps 7a/8a/9a, silver-ingest Step 7a,
  silver-feature Step 17.0a — all NON-SKIPPABLE gates
- Post-command review gates in §3a-i for ROADMAP, REQUIREMENTS, CONTEXT, RESEARCH
- Complete artifact-reviewer mapping table in §3a (12 artifact types)

### Fixed — v0.14.0 Critical Bug Fixes
- BFIX-01: Shell injection via unvalidated owner/repo in `silver-ingest --source-url` — allowlist regex validation added
- BFIX-02: Command injection via unescaped WARN findings in `pr-traceability.sh` heredoc — replaced with `printf '%s'`
- BFIX-03: Confluence failure path now produces `[ARTIFACT MISSING: reason]` block (was buried in Assumptions)
- BFIX-04: Version mismatch block in §0/5.5 now shows content diff (was version numbers only)

## [0.14.0] — 2026-04-09

### Added — AI-Driven Spec & Multi-Repo Orchestration
- `skills/silver-spec/SKILL.md` — AI-driven Socratic elicitation skill (238 lines)
  guiding PM/BA through 9-domain requirements creation, producing SPEC.md + REQUIREMENTS.md
- `skills/silver-ingest/SKILL.md` — External artifact ingestion (428 lines) via
  JIRA (Atlassian MCP), Figma (Figma MCP), Google Docs (Workspace CLI with vision).
  Cross-repo spec fetch with version pinning. Resumable via INGESTION_MANIFEST.md
- `skills/silver-validate/SKILL.md` — Pre-build gap analysis (360 lines) with
  BLOCK/WARN/INFO findings. Hard-blocks gsd-plan-phase on BLOCK findings
- `hooks/spec-floor-check.sh` — PreToolUse hook that hard-blocks gsd-plan-phase
  without valid SPEC.md; advisory-only for gsd-fast/gsd-quick
- `hooks/spec-session-record.sh` — SessionStart hook capturing spec-id/version/JIRA ref
- `hooks/pr-traceability.sh` — PostToolUse hook auto-populating PR description with
  spec reference and updating SPEC.md Implementations section post-merge
- `hooks/uat-gate.sh` — PreToolUse hook blocking gsd-complete-milestone without UAT pass
- Canonical spec templates: `templates/specs/SPEC.md.template`, `DESIGN.md.template`,
  `REQUIREMENTS.md.template` with YAML frontmatter and standardized sections
- Multi-repo spec referencing: `silver-ingest --source-url` fetches + caches main repo
  SPEC.md with version pinning; session-start validation blocks on mismatch
- §3/§3a/§3d step non-skip enforcement: workflow steps cannot be bypassed, artifact
  existence required before phase advancement
- Spec Lifecycle section in silver-bullet.md.base
- MCP Connector Prerequisites (§2j) and Cross-Repo Conventions (§2k)

## [0.13.2] — 2026-04-09

### Fixed
- All hooks that used `set -euo pipefail` without an ERR trap now have
  `trap 'exit 0' ERR` added. Affected files: `hooks/session-start`,
  `hooks/compliance-status.sh`, `hooks/session-log-init.sh`,
  `hooks/ensure-model-routing.sh`, `hooks/semantic-compress.sh`,
  `hooks/record-skill.sh`, `hooks/ci-status-check.sh`,
  `hooks/dev-cycle-check.sh`. Prevents first-install failures from
  surfacing nonzero hook exits that cause Claude to reject the plugin.
- Restored `"hooks": "./hooks/hooks.json"` to `.claude-plugin/plugin.json`
  so the marketplace registers hooks automatically on install.

### Added
- `silver:init` Phase 3 step 3.7.5: after project scaffolding, merges SB
  hook entries from `hooks/hooks.json` into `~/.claude/settings.json` using
  `python3`. Hook commands are registered with the actual install path
  substituted for `${CLAUDE_PLUGIN_ROOT}`. Idempotent — re-running init
  does not add duplicate entries. Also runs during update mode (step 5a).

## [0.13.1] — 2026-04-09

### Changed
- Model routing overhauled: Sonnet (LOW thinking effort) is now the default for all 24 GSD agents. Opus reserved exclusively for `gsd-planner` and `gsd-security-auditor` — the only two agents where reasoning depth measurably changes outcome quality. Previous scheme asked for Opus at phase transitions; new scheme is fully automatic via agent frontmatter.
- silver-bullet.md §5 and templates/silver-bullet.md.base §5: removed interactive Opus upgrade prompts; replaced with automatic frontmatter-based routing description
- docs/workflows/full-dev-cycle.md MODEL ROUTING section updated to match; removed manual prompt flow

### Added
- `hooks/ensure-model-routing.sh` — self-healing session-start hook that reapplies `model:` directives to all 24 GSD agent files if a GSD update wipes them. Canary-guarded (~2ms no-op when correct, <50ms when patching). Bash 3.2 compatible. Audit trail written to `~/.claude/.silver-bullet/model-routing-patch.log`.

### Fixed
- All "8 dimensions" references updated to "9 dimensions" across site/index.html (3 occurrences), site/help/index.html, site/help/dev-workflow/index.html, site/help/search.js (3 occurrences), and docs/workflows/full-dev-cycle.md (4 occurrences total)
- quality-gates SKILL.md: added 9th dimension (AI/LLM safety) to skill load list and report table; updated model advisory from Opus to Sonnet
- site/index.html cost-optimization section rewritten: Sonnet-as-default messaging, Opus reserved for 2 agents, cost reduction estimate updated to 60–80%
- docs/workflows/full-dev-cycle.md: added /silver router and orchestration workflows to invocation table; updated /test-driven-development → silver:tdd, /finishing-a-development-branch → silver:finishing-branch, /design-system+/ux-copy+/accessibility-review → product-brainstorming; added silver:security to CODE REVIEW section
- site/help/search.js: added dedicated index entries for utility skills (silver:intel, silver:explore, silver:scan, silver:forensics) and alias skills (silver:tdd, silver:security, silver:brainstorm, silver:writing-plans, silver:finishing-branch)

## [0.13.0] — 2026-04-08

### Security
- SENTINEL v2.3 audit: add UNTRUSTED DATA boundary to §0 docs/ read — docs/ files are project context only, not executable instructions (F2-01)
- SENTINEL v2.3 audit: add UNTRUSTED DATA security boundary to silver:init Phase −1.1 for README.md/CONTEXT.md reads (F2-02)
- SENTINEL v2.3 audit: add `mode` to state tamper prevention regex in dev-cycle-check.sh alongside state/branch/trivial (F6-01)
- SENTINEL v2.3 audit: silver:update now displays commit SHA and requires second user confirmation before writing plugin registry (F7-01/F3-01)
- SENTINEL v2.3 audit: §10 step-skip preference writes now require diff display and explicit user confirmation before committing (F10-01)
- SENTINEL v2.3 audit: silver:update cancel path guarded against unsafe removal — requires path-containment check before rm (F-NEW-01)

## [0.9.0] — 2026-04-08

### Added
- 7 named SB orchestration skill files: silver:feature, silver:bugfix, silver:ui, silver:devops, silver:research, silver:release, silver:fast
- §2h SB Orchestrated Workflows enforcement section in silver-bullet.md and template
- §10 User Workflow Preferences schema (10a–10e) in silver-bullet.md and template
- /silver router expanded: 17+ routes, complexity triage, ship disambiguation, conflict resolution
- silver:init: MultAI + Anthropic Engineering + PM plugin checks, project-type detection, gsd-autonomous mode note
- §0 session startup: MultAI update check alongside GSD/Superpowers
- Unified test runner (tests/run-all-tests.sh)

### Fixed
- silver:release: add standalone silver:security gate (Step 2a) before gap-closure loop; listed in non-skippable gates
- silver:feature: move gsd-add-tests to Step 8b (after gsd-verify-work, not before); add TDD skip heuristic
- silver:tdd / silver:scan: add canonical skill parentheticals across feature/bugfix/ui/devops skill files
- silver/router: note §10 preferences not applied when routing Trivial → silver:fast
- silver:init: document intentional MultAI hard-STOP vs Engineering/PM soft-warning asymmetry

### Infrastructure
- GSD state delegation: SB reads .planning/STATE.md instead of maintaining own state

## 0.12.1 (2026-04-07)

### Added
- `/silver:update` skill — one-command plugin updater: checks GitHub for latest release, shows changelog diff, confirms, clones new version into cache, and updates plugin registry

### Fixed
- `/silver` skill: removed unsupported `allowed-tools` frontmatter field that prevented the skill from loading in Claude Desktop
- Architecture section: 10th enforcement layer card now flows in 2-column grid (removed erroneous `grid-column:1/-1`)

## 0.12.0 (2026-04-07)

### Added
- `/silver` router skill — freeform dispatcher that routes natural language to the right Silver Bullet or GSD skill; delegates GSD intent to `/gsd:do` automatically
- Ten-layer enforcement model now fully documented in `silver-bullet.md` section 1 (Stop hook, UserPromptSubmit reminder, and Forbidden skill gate layers were previously undocumented)

### Changed
- Renamed `/using-silver-bullet` skill to `/silver:init` — shorter namespaced name consistent with the `/silver:*` namespace; project-wide update across all docs, site, help center, README, and hooks

### Fixed
- `record-skill.sh`: greedy namespace stripping loop (mirrors `forbidden-skill-check.sh`) — double-namespaced invocations (e.g., `outer:inner:quality-gates`) were silently untracked (SENTINEL S6-001)
- `silver-bullet.md` section 1: enforcement layer count corrected from 7 to 10; Stop hook, UserPromptSubmit reminder, and Forbidden skill gate now listed explicitly
- `site/index.html`: all enforcement layer count references corrected from 7 to 10; architecture section updated with three missing layer cards
- `site/compare/index.html`: enforcement layer count corrected from 7 to 10

### Tech Debt
- `hooks/lib/required-skills.sh`: extracted `DEFAULT_REQUIRED` as single source of truth; sourced by `stop-check.sh`, `completion-audit.sh`, `prompt-reminder.sh` with inline fallback (TD-01)
- `stop-check.sh`: extracted `check_quality_gate_stages()` as testable pure function (TD-04)
- `templates/silver-bullet.config.json.default`: added `config_version` field (TD-07)
- Added 4 new tests: double-namespace bypass (forbidden-skill), main-branch filter (prompt-reminder), path traversal defense (prompt-reminder), double-namespace record (record-skill)

## 0.11.0 (2026-04-06)

### Added
- Stop hook (`stop-check.sh`) — blocks Claude from declaring task complete when required skills are missing; fires on `Stop` and `SubagentStop` events, survives compaction
- UserPromptSubmit hook (`prompt-reminder.sh`) — re-injects missing-skill list and core enforcement rules before every user message
- Forbidden skill gate (`forbidden-skill-check.sh`) — PreToolUse hook blocks deprecated/forbidden skills before they execute; configurable via `skills.forbidden` in `.silver-bullet.json`
- Review-loop proxy enforcement — `review-loop-pass-1`/`review-loop-pass-2` markers tracked in stop-check and completion-audit as proxy for F-01 compliance
- Stage ordering validation — prevents falsifying stage sequence (e.g. recording stage-3 before stage-2)
- Automatic model switching — agent definitions route to optimal Claude model tier (Sonnet/Haiku/Opus) based on task type
- 183-test comprehensive E2E harness (`tests/run-all-tests.sh`) — 129 unit tests + 54 integration scenario tests with 100% hook coverage

### Fixed
- 16 enforcement gaps closed from post-v0.10.0 audit: branch mismatch warning, plugin cache write blocking, scripting language bypass prevention, generalized tamper regex, destructive command warning, `gh pr merge` delivery gate, completion-audit missing `exit 0` (double-JSON bug), state JSON injection via stored branch name
- `DEFAULT_REQUIRED` skill list synchronized across `stop-check.sh`, `completion-audit.sh`, and `prompt-reminder.sh`
- `forbidden` key documented in `silver-bullet.config.json.default`

### Changed
- Enforcement layer count: 7 → 10 (Stop hook, UserPromptSubmit reminder, forbidden-skill gate added)

## 0.6.2 (2026-04-04)

### Fixed
- Enforcement layer count aligned to 7 across all surfaces (README, landing page, concepts page, compare page, search index, SENTINEL audit)
- Step counts 19/23 → 20/24 on landing page hero pills, workflow tabs, and compare page
- Landing page workflow tables completed: added missing step 20 (/create-release) for dev cycle and steps 22-24 for DevOps cycle
- Landing page layer cards now match CLAUDE.md canonical 7-layer list (was missing Skill Tracker, had Stage Enforcer split into two)
- Layer ordering aligned to CLAUDE.md canonical sequence across concepts page, search index, and README
- PreToolUse → PostToolUse in landing page HARD STOP gate description
- Broken relative link in compare page footer (help/ → ../help/)
- Stale /tmp/ references in help reference page, search index, and silver:init skill
- Test files updated from /tmp/.silver-bullet-* to ~/.claude/.silver-bullet/ paths
- session-log-init sentinel subshell fully detached from pipeline (fixes test hangs)
- session-log-init grep pattern updated to match new mode file path
- SENTINEL audit doc updated: 8→7 layers, post-remediation note added
- context.md updated: stale step counts, version, and branding
- Missing Required badge on step 9 (/requesting-code-review) in dev cycle table
- Stale worktree .claude/worktrees/agent-ad2bff3d removed
- mkdir -p defense-in-depth added to completion-audit.sh
- Plugin boundary check changed from substring grep to prefix match

## 0.6.1 (2026-04-03)

### Fix: Comprehensive cross-file consistency audit
- Regenerated `.silver-bullet.json` from v0.2.0 template (was stuck at v0.1.0 with 13 obsolete skill names)
- Synced `CLAUDE.md` with `templates/CLAUDE.md.base` (7 enforcement layers, GSD/Superpowers ownership rules, file safety rules)
- Updated all 8 quality dimension skills (`modularity`, `reusability`, `scalability`, `security`, `reliability`, `usability`, `testability`, `extensibility`) from Superpowers-era references to GSD terminology
- Updated `forensics` skill reference from `superpowers:systematic-debugging` to `/gsd:debug`

### Enhanced: DevOps workflow parity
- Added Step 0 (SESSION MODE) to `devops-cycle.md` with pre-answer template
- Added SKILL DISCOVERY section with DevOps-specific examples
- Added MODEL ROUTING section before DISCUSS phase
- Added post-plan skill gap check to Step 6
- Added forensics failure protocol to Step 8 verification
- Added KNOWLEDGE.md, CHANGELOG.md, and session log to Step 18 finalization
- Added worktree isolation rule for docs agents to Step 18
- Added autonomous completion cleanup after Step 24

### Fix: Help site completeness
- Added DevOps Step 0, code review, and skill discovery sections to help page
- Added dev-workflow init (Steps 1–2) and post-review (Steps 11–12) to search index
- Added DevOps Step 0 and code review search entries
- Fixed duplicate `hooks` anchor for trivial-changes section in concepts page
- Added `whats-next` search entry for getting-started page

### Fix: Hook and config alignment
- Reordered `finalization_skills` in `dev-cycle-check.sh` to match `compliance-status.sh` and `completion-audit.sh`
- Bumped `plugin.json` and `package.json` descriptions to "20-step (app) and 24-step (DevOps)"
- Fixed `CHANGELOG.md` DevOps step count from 23 to 24

## 0.6.0 (2026-04-03)

### Fix: `/create-release` skill rename (critical)
- Renamed `skills/release-notes/` → `skills/create-release/` to fix naming collision with Claude Code 2.1.3's built-in `/release-notes` command, which was hijacking invocations and showing Claude Code's own changelog instead of Silver Bullet's release skill
- Updated 16+ references across hooks, workflows, templates, config files, README, CLAUDE.md, and all help site pages

### Enhanced: Review loop enforcement — double approval required
- Review loops (spec review, plan review, code review, verification) must now iterate until the reviewer returns ✅ Approved **twice in a row** — a single clean pass is no longer sufficient
- Completely self-limiting: loop ends naturally on two consecutive clean passes; maximum iteration cap removed
- Updated `CLAUDE.md`, `templates/CLAUDE.md.base`, `docs/workflows/full-dev-cycle.md`, `templates/workflows/*.md`, and help site

### Enhanced: CI gate hook is now blocking
- `hooks/ci-status-check.sh` now emits `blockToolUse: true` on CI failure — Claude must stop all other work immediately and invoke `/gsd:debug`
- Previously emitted only an advisory warning that could be ignored

### Enhanced: Expanded CI stack detection in `/silver:init`
- Detects and generates CI workflow templates for 8 additional stacks: Java/Maven, Java/Gradle, Ruby/RSpec, PHP/Composer, .NET/C#, Elixir/Mix, Swift, Dart/Flutter
- Go template updated to use `go-version: stable`

## 0.5.0 (2026-04-03)

### New: Semantic context compression
- New PostToolUse hook (`hooks/semantic-compress.sh`) that fires on GSD phase transitions and injects ranked context into the next prompt via `hookSpecificOutput.additionalContext`
- TF-IDF ranking of source and doc file chunks against the active phase goal — highest-relevance chunks are injected, lowest are dropped, keeping context tight
- Pure shell implementation (awk + sort) — no external dependencies beyond standard POSIX tools
- Cache-backed: MD5 hash of file mtimes + phase goal used as cache key; repeated calls within the same phase are instant
- Source files prioritised over doc files in ranking; configurable score weighting
- Configurable via `.silver-bullet.json` `semantic_compression` block (enable/disable, chunk size, max chunks injected, min score threshold, include/exclude globs)
- New scripts: `scripts/extract-phase-goal.sh`, `scripts/tfidf-rank.sh`, `scripts/semantic-compress.sh`
- 31 tests across 5 test suites covering TF-IDF scoring, caching, phase-goal extraction, hook wiring, and end-to-end integration

### New: Help site
- Full documentation site at sb.alolabs.dev — Getting Started, Core Concepts, Dev Workflow, DevOps Workflow, Command Reference
- Full-text search across all help content (TF-IDF JS index, ~50 entries)
- Nav search on all sub-pages
- Dark mode support

### Fixes
- Enforcement count corrected: 8 total enforcement points (Silver Bullet installs 6, GSD adds 2) — was described as 7
- DevOps quality gates dimension count: 7 IaC-adapted (usability excluded) — was incorrectly described as 8 in some places
- GSD install command updated to `npx get-shit-done-cc@^1.30.0` in all documentation
- README: hooks architecture updated to document all 9 hooks (4 enforcement + 4 support + session-start)
- README: Built-in skills table now lists all 7 Silver Bullet skills (was 3)
- Help reference: clarified which skills are Silver Bullet's own vs. from Superpowers/Engineering plugins

## 0.2.0 (2026-04-01)

### Major: GSD integration as primary execution engine
- GSD (get-shit-done) is now the primary skill set — fresh 200K-token context per agent, wave-based parallel execution, dependency graphs, atomic per-task commits
- Workflows restructured: GSD commands drive DISCUSS → PLAN → EXECUTE → VERIFY; Silver Bullet skills fill gaps (quality gates, code review, testing, docs, deploy)
- 8 individual quality gate skills collapsed into `/quality-gates` aggregate (individual files kept for modularity)

### New: DevOps workflow
- `devops-cycle.md` — 24-step workflow for infrastructure/DevOps work
- `/blast-radius` skill — pre-change risk analysis with LOW/MEDIUM/HIGH/CRITICAL gate
- `/devops-quality-gates` skill — 7 IaC-adapted quality dimensions (usability excluded)
- Incident fast path for emergency production changes
- Environment promotion section (dev → staging → prod)
- `.yml`/`.yaml` files enforced as infrastructure code in devops-cycle

### New: Design plugin dependency
- Design plugin (anthropics/knowledge-work-plugins/design) added as required dependency
- Session-start hook injects Design plugin context alongside Superpowers

### New: Project type detection
- `/silver:init` Phase 2.6 asks application vs DevOps/infrastructure
- Sets `active_workflow` in config to `full-dev-cycle` or `devops-cycle`

### New: DevOps plugin integration
- `/devops-skill-router` skill — context-aware routing table mapping IaC toolchain + cloud provider to the best available plugin skill with fallback chains
- 5 optional DevOps plugins supported: hashicorp/agent-skills, awslabs/agent-plugins, pulumi/agent-skills, ahmedasmar/devops-claude-skills, wshobson/agents
- `/silver:init` Phase 2.7 auto-detects which DevOps plugins are installed
- `devops-cycle.md` contextual enrichment trigger points at DISCUSS, PLAN, EXECUTE, VERIFY, FINALIZATION
- `devops_plugins` section added to config for tracking installed plugins

### Hook updates
- All hooks updated to align with GSD-integrated workflow
- `record-skill.sh` — tracked skills list updated (removed GSD-replaced skills, added new skills)
- `dev-cycle-check.sh` — reads `active_workflow` from config; YAML files not auto-exempted in devops-cycle
- `compliance-status.sh` — phases updated: removed EXECUTION (now GSD), updated REVIEW and FINALIZATION skill lists
- `completion-audit.sh` — required deploy skills updated to match new workflow
- `deploy-gate-snippet.sh` — default required deploy skills updated

### Updated
- `full-dev-cycle.md` rewritten as 19-step GSD-primary workflow (down from 31)
- `CLAUDE.md.base` updated: 7 enforcement layers, trivial-change note clarifies DevOps YAML exception
- `silver-bullet.config.json.default` updated to v0.2.0 with new skill lists
- README rewritten for four-plugin ecosystem, two workflows, seven enforcement layers
- `plugin.json` updated to v0.2.0

## 0.1.0 (2026-03-31)

- Initial release
- Full dev cycle workflow (31-step enforced process)
- 8 quality-ility skills enforced during planning:
  - `/modularity` — file size limits, single responsibility, change locality
  - `/reusability` — DRY, composable components, Rule of Three
  - `/scalability` — stateless design, efficient data access, async processing
  - `/security` — OWASP top 10, input validation, secrets management, defense in depth
  - `/reliability` — fault tolerance, retries with backoff, circuit breakers, graceful degradation
  - `/usability` — intuitive APIs, actionable errors, progressive disclosure, accessibility
  - `/testability` — dependency injection, pure functions, test seams, deterministic behavior
  - `/extensibility` — open-closed principle, plugin architecture, versioned interfaces
- Six-layer compliance enforcement system
- `/silver:init` setup skill
- Superpowers + Engineering plugin dependency management
